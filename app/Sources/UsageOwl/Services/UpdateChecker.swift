import AppKit
import Foundation

/// A semantic version, compared numerically rather than as a string.
///
/// String comparison gets this wrong in the way that matters most: "1.10.0"
/// sorts *before* "1.9.0" lexicographically, so a user on 1.9.0 would never be
/// offered 1.10.0 — the exact release where they've waited longest for a fix.
struct SemVer: Comparable, CustomStringConvertible {
    let major: Int
    let minor: Int
    let patch: Int

    /// Accepts "1.2.3", "v1.2.3", "1.2", "1". Anything with a non-numeric
    /// component is rejected rather than coerced, so a malformed tag on the
    /// release can never read as "newer" and nag every user.
    init?(_ raw: String) {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("v") || text.hasPrefix("V") { text.removeFirst() }
        // Drop any pre-release/build suffix: 1.2.3-beta.1 -> 1.2.3
        if let cut = text.firstIndex(where: { $0 == "-" || $0 == "+" }) {
            text = String(text[text.startIndex..<cut])
        }
        guard !text.isEmpty else { return nil }
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 3 else { return nil }
        var numbers: [Int] = []
        for part in parts {
            guard let value = Int(part), value >= 0 else { return nil }
            numbers.append(value)
        }
        major = numbers.count > 0 ? numbers[0] : 0
        minor = numbers.count > 1 ? numbers[1] : 0
        patch = numbers.count > 2 ? numbers[2] : 0
    }

    static func < (a: SemVer, b: SemVer) -> Bool {
        (a.major, a.minor, a.patch) < (b.major, b.minor, b.patch)
    }

    var description: String { "\(major).\(minor).\(patch)" }
}

/// Checks GitHub Releases for a newer build and offers it to the user.
///
/// Deliberately not Sparkle: this is one anonymous unauthenticated GET against
/// a public JSON endpoint, no framework, no appcast to keep in sync, and no
/// signing key to guard. It matches what the app promises — no servers, no
/// telemetry — because nothing identifying is ever sent. GitHub sees an
/// ordinary API request with no token and no user agent beyond URLSession's.
///
/// The user is always asked. Nothing downloads or installs on its own.
@MainActor
final class UpdateChecker {
    static let shared = UpdateChecker()

    /// Public releases feed for the repo the app actually ships from.
    private static let latestReleaseURL = URL(
        string: "https://api.github.com/repos/usageowl/usageowl/releases/latest")!

    private static let lastCheckKey = "update.lastCheck"
    private static let skippedVersionKey = "update.skippedVersion"
    private static let checkInterval: TimeInterval = 60 * 60 * 24  // once a day

    /// Delay before the launch check so it never competes with the first
    /// provider refresh for the network or the main thread.
    private static let launchDelay: TimeInterval = 8

    private var checking = false

    private init() {}

    /// Version from the bundle, or nil when running as a bare binary
    /// (`swift run`), where there is no Info.plist and no update to offer.
    var currentVersion: SemVer? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        else { return nil }
        return SemVer(raw)
    }

    // MARK: - Entry points

    /// Called once at launch. Silent: reports nothing if up to date, and stays
    /// quiet on network failure — a background check is not worth an alert.
    func checkInBackgroundAfterLaunch() {
        guard currentVersion != nil else { return }
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.launchDelay))
            await self?.checkIfDue()
        }
    }

    /// Honours the daily interval. Used by the launch check and the timer.
    func checkIfDue() async {
        let last = UserDefaults.standard.object(forKey: Self.lastCheckKey) as? Date
        if let last, Date().timeIntervalSince(last) < Self.checkInterval { return }
        await check(userInitiated: false)
    }

    /// "Check for Updates…" — always reports, including "you're up to date"
    /// and any error, because silence in response to a click reads as a bug.
    func checkNow() {
        Task { await check(userInitiated: true) }
    }

    // MARK: - Core

    private func check(userInitiated: Bool) async {
        guard !checking, let current = currentVersion else { return }
        checking = true
        defer { checking = false }

        do {
            let release = try await fetchLatest()
            UserDefaults.standard.set(Date(), forKey: Self.lastCheckKey)

            guard let latest = SemVer(release.tagName) else {
                if userInitiated {
                    presentError("Could not read the version number of the latest release.")
                }
                return
            }

            guard latest > current else {
                if userInitiated { presentUpToDate(current: current) }
                return
            }

            // A skipped version stays skipped until something newer appears.
            if !userInitiated,
               let skipped = UserDefaults.standard.string(forKey: Self.skippedVersionKey),
               let skippedVersion = SemVer(skipped),
               latest <= skippedVersion {
                return
            }

            presentUpdate(current: current, latest: latest, release: release)
        } catch {
            if userInitiated {
                presentError(error.localizedDescription)
            }
        }
    }

    private struct Release {
        let tagName: String
        let htmlURL: URL
        let notes: String?
    }

    private func fetchLatest() async throws -> Release {
        var request = URLRequest(url: Self.latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        // Never serve this from cache: a stale 24h-old body would hide a release.
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw UpdateError.message("No response from GitHub.")
        }
        guard http.statusCode == 200 else {
            // 404 is the normal state before the first release is published.
            if http.statusCode == 404 {
                throw UpdateError.message("No releases have been published yet.")
            }
            throw UpdateError.message("GitHub returned HTTP \(http.statusCode).")
        }
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = root["tag_name"] as? String,
              let urlString = root["html_url"] as? String,
              let url = URL(string: urlString) else {
            throw UpdateError.message("Unexpected response from GitHub.")
        }
        let notes = (root["body"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return Release(tagName: tag, htmlURL: url, notes: notes?.isEmpty == false ? notes : nil)
    }

    // MARK: - Alerts

    /// An accessory (LSUIElement) app has no Dock presence, so an alert can be
    /// buried behind whatever the user is actually working in. Activate first.
    private func activate() {
        NSApp.activate(ignoringOtherApps: true)
    }

    private func presentUpdate(current: SemVer, latest: SemVer, release: Release) {
        activate()
        let alert = NSAlert()
        alert.messageText = "UsageOwl \(latest) is available"
        var body = "You have \(current)."
        if let notes = release.notes {
            let trimmed = notes.count > 600 ? String(notes.prefix(600)) + "…" : notes
            body += "\n\n\(trimmed)"
        }
        alert.informativeText = body
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Later")
        alert.addButton(withTitle: "Skip This Version")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            NSWorkspace.shared.open(release.htmlURL)
        case .alertThirdButtonReturn:
            UserDefaults.standard.set(latest.description, forKey: Self.skippedVersionKey)
        default:
            break  // Later: ask again at the next daily check
        }
    }

    private func presentUpToDate(current: SemVer) {
        activate()
        let alert = NSAlert()
        alert.messageText = "You're up to date"
        alert.informativeText = "UsageOwl \(current) is the latest version."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func presentError(_ message: String) {
        activate()
        let alert = NSAlert()
        alert.messageText = "Couldn't check for updates"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private enum UpdateError: LocalizedError {
        case message(String)
        var errorDescription: String? {
            switch self {
            case .message(let text): return text
            }
        }
    }
}
