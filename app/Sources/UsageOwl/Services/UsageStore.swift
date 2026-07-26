import Foundation
import ServiceManagement
import SwiftUI
import AppKit

/// Holds the latest snapshots, drives periodic refresh and threshold alerts.
@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshots: [String: UsageSnapshot] = [:]
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastUpdated: Date?
    /// providerID -> shown in menu bar. Persisted as `showInMenuBar.<id>` in UserDefaults.
    @Published private(set) var menuBarSelection: [String: Bool] = [:]
    /// The whole menu bar label as ONE template image (see MenuBarImageRenderer).
    @Published private(set) var menuBarImage = NSImage()

    @Published var refreshInterval: Int {
        didSet { UserDefaults.standard.set(refreshInterval, forKey: Self.intervalKey); scheduleTimer() }
    }
    @Published var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: Self.notificationsKey) }
    }
    @Published var launchAtLogin: Bool {
        didSet { applyLaunchAtLogin() }
    }
    /// Leading owl mark + divider in the menu bar label. Persisted, default on.
    @Published var showOwlLogo: Bool {
        didSet { UserDefaults.standard.set(showOwlLogo, forKey: Self.owlLogoKey); regenerateMenuBarImage() }
    }

    private static let intervalKey = "refreshInterval"
    private static let notificationsKey = "notificationsEnabled"
    private static let menuBarKey = "showInMenuBar."
    private static let owlLogoKey = "showOwlLogoInMenuBar"
    private var timer: Timer?

    /// Worst quota across providers — drives the menu bar label.
    var worstPercent: Double? {
        snapshots.values.filter { $0.error == nil }.compactMap(\.worstPercent).max()
    }

    init(previewSnapshots: [UsageSnapshot] = []) {
        let defaults = UserDefaults.standard
        let stored = defaults.integer(forKey: Self.intervalKey)
        refreshInterval = [30, 60, 300].contains(stored) ? stored : 60
        notificationsEnabled = defaults.object(forKey: Self.notificationsKey) as? Bool ?? true
        launchAtLogin = SMAppService.mainApp.status == .enabled
        showOwlLogo = defaults.object(forKey: Self.owlLogoKey) as? Bool ?? true
        for snapshot in previewSnapshots { snapshots[snapshot.id] = snapshot }
        loadMenuBarSelection()
        regenerateMenuBarImage()
    }

    func isShownInMenuBar(_ providerID: String) -> Bool {
        menuBarSelection[providerID] ?? false
    }

    func setShownInMenuBar(_ providerID: String, _ shown: Bool) {
        menuBarSelection[providerID] = shown
        UserDefaults.standard.set(shown, forKey: Self.menuBarKey + providerID)
        regenerateMenuBarImage()
    }

    /// Rebuilds the single composed menu bar image from toggles + snapshots.
    /// Called from init, the refresh pipeline, and toggle writes — no timer.
    private func regenerateMenuBarImage() {
        let items: [MenuBarImageRenderer.Item] = ProviderRegistry.all
            .filter { isShownInMenuBar($0.id) }
            .map { provider in
                let glyph = ProviderGlyph.Images.template(for: ProviderGlyph.Kind(providerID: provider.id))
                if let snapshot = snapshots[provider.id], snapshot.error == nil,
                   let window = snapshot.primaryWindow {
                    return MenuBarImageRenderer.Item(glyph: glyph,
                                                     text: Format.percent(window.usedPercent),
                                                     dimmed: false)
                }
                return MenuBarImageRenderer.Item(glyph: glyph, text: "--", dimmed: true)
            }
        if items.isEmpty {
            // Nothing enabled: owl fallback + worst-case % across providers.
            let worst = worstPercent
            menuBarImage = MenuBarImageRenderer.render(items: [
                MenuBarImageRenderer.Item(glyph: ProviderGlyph.Images.template(for: .owl),
                                          text: worst.map(Format.percent) ?? "--",
                                          dimmed: worst == nil),
            ])
        } else {
            menuBarImage = MenuBarImageRenderer.render(items: items, leadingOwl: showOwlLogo)
        }
    }

    /// Load persisted choices at launch; providers without an explicit choice
    /// default to shown iff credentials exist.
    private func loadMenuBarSelection() {
        for provider in ProviderRegistry.all {
            let key = Self.menuBarKey + provider.id
            menuBarSelection[provider.id] =
                (UserDefaults.standard.object(forKey: key) as? Bool) ?? provider.isAvailable()
        }
    }

    /// After each refresh, (re)default only providers the user never toggled,
    /// so newly configured providers appear automatically.
    private func applyMenuBarDefaults() {
        for provider in ProviderRegistry.all
        where UserDefaults.standard.object(forKey: Self.menuBarKey + provider.id) == nil {
            menuBarSelection[provider.id] = provider.isAvailable()
        }
    }

    func start() {
        scheduleTimer()
        BridgeServer.shared.start()
        NotificationCenter.default.addObserver(forName: .bridgeUsageReceived, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        // Pre-WebKit-transport cookie item: a cookie replayed through URLSession
        // is refused by Cloudflare, so leaving it in the Keychain only invites
        // an access prompt for something unusable.
        KeychainHelper.delete(service: ClaudeProvider.legacyCookieService)
        // One refresh at launch, after the first transcript scan. Two separate
        // launch refreshes hit the OAuth usage endpoint twice for nothing, and
        // that endpoint rate-limits (429).
        Task {
            await ClaudeCodeUsageReader.shared.refresh()
            await refresh()
        }
    }

    /// Refresh when the popup opens, unless data is fresh.
    func refreshIfStale(maxAge: TimeInterval = 15) {
        guard let last = lastUpdated, Date().timeIntervalSince(last) < maxAge else {
            Task { await refresh() }
            return
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        await ClaudeCodeUsageReader.shared.refreshIfStale()
        let providers = ProviderRegistry.all.filter { $0.isAvailable() }
        let results = await withTaskGroup(of: UsageSnapshot.self) { group in
            for provider in providers {
                group.addTask { await provider.fetchUsage() }
            }
            var collected: [UsageSnapshot] = []
            for await snap in group { collected.append(snap) }
            return collected
        }
        for snap in results {
            snapshots[snap.id] = snap
            if notificationsEnabled { Notifier.shared.check(snapshot: snap) }
        }
        applyMenuBarDefaults()
        regenerateMenuBarImage()
        lastUpdated = Date()
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(refreshInterval), repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    private func applyLaunchAtLogin() {
        do {
            if launchAtLogin { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            // Revert on failure (e.g. running unbundled during development).
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
