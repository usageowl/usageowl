import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: UsageStore
    @State private var refreshID = UUID()

    var body: some View {
        Form {
            Section("Providers") {
                DetectionRow(name: "Kimi",
                             detail: "~/.kimi-code/credentials/kimi-code.json",
                             detected: KimiProvider().isAvailable())
                WebConnectRow(service: .chatGPT,
                              detail: "Adds rate windows and credits. Sign in once — it stays signed in.",
                              onUpdate: reload)
                DetectionRow(name: "ChatGPT (Codex CLI fallback)",
                             detail: "~/.codex/auth.json",
                             detected: FileManager.default.fileExists(
                                atPath: NSHomeDirectory() + "/.codex/auth.json"))
                DetectionRow(name: "Claude (Claude Code OAuth)",
                             detail: "Keychain item “Claude Code-credentials”",
                             detected: KeychainHelper.exists(service: ClaudeProvider.oauthService, account: nil))
                WebConnectRow(service: .claude,
                              detail: "Adds extra windows like Fable, plus extra-usage spend. Sign in once — it stays signed in.",
                              onUpdate: reload)
                DetectionRow(name: "Copilot (VS Code)",
                             detail: "~/.config/github-copilot/apps.json",
                             detected: CopilotProvider().isAvailable())
                KeychainSecretRow(name: "GitHub Copilot token",
                                  detail: "GitHub OAuth token",
                                  service: CopilotProvider.tokenService,
                                  onUpdate: reload)
                KeychainSecretRow(name: "Moonshot API key",
                                  detail: "platform.moonshot.ai API key",
                                  service: MoonshotProvider.keyService,
                                  onUpdate: reload)
            }
            .id(refreshID)

            Section("General") {
                Picker("Refresh interval", selection: $store.refreshInterval) {
                    Text("30 seconds").tag(30)
                    Text("1 minute").tag(60)
                    Text("5 minutes").tag(300)
                }
                Toggle("Threshold notifications (25 / 50 / 75 / 90%)", isOn: $store.notificationsEnabled)
                Toggle("Owl logo in menu bar", isOn: $store.showOwlLogo)
                Toggle("Launch at login", isOn: $store.launchAtLogin)
            }

            Section("Updates") {
                UpdateRow()
            }
        }
        .formStyle(.grouped)
        .frame(width: 540, height: 560)
    }

    private func reload() {
        refreshID = UUID()
        Task { await store.refresh() }
    }
}

/// Connect / disconnect row for any `WebService`, driving the shared sign-in sheet.
private struct WebConnectRow: View {
    let service: WebService
    let detail: String
    var onUpdate: () -> Void = {}

    @State private var connected: Bool = false
    @State private var synced = false
    @State private var showLogin = false
    @State private var working = false

    /// The browser-extension bridge only exists for claude.ai.
    private var watchesBridge: Bool { service.id == WebService.claude.id }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(service.displayName) account")
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if connected || synced {
                Label(connected ? "Connected" : "Synced", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                if watchesBridge, let date = BridgeServer.lastSync {
                    Text(date, format: .dateTime.hour().minute())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Button("Disconnect") { disconnect() }
                    .disabled(working)
            } else {
                Button("Connect \(service.displayName)") { showLogin = true }
            }
        }
        .onAppear {
            connected = WebConnection.isConnected(service.id)
            synced = watchesBridge && BridgeServer.lastSync != nil
        }
        .sheet(isPresented: $showLogin) {
            // The sheet owns the fallbacks (email code, browser + paste), so
            // this row stays a single button.
            WebLoginView(service: service) {
                connected = true
                onUpdate()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .bridgeUsageReceived)) { _ in
            guard watchesBridge else { return }
            synced = true
            onUpdate()
        }
    }

    private func disconnect() {
        working = true
        Task {
            await WebSession.session(for: service).signOut()
            if watchesBridge { try? FileManager.default.removeItem(at: BridgeServer.cacheURL) }
            await MainActor.run {
                connected = false
                synced = false
                working = false
                onUpdate()
            }
        }
    }
}

private struct DetectionRow: View {
    let name: String
    let detail: String
    let detected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Label(detected ? "Detected" : "Not found",
                  systemImage: detected ? "checkmark.circle.fill" : "xmark.circle")
                .font(.caption)
                .foregroundStyle(detected ? .green : .secondary)
        }
    }
}

/// Shows the running version and a manual check. The automatic daily check
/// runs whether or not this row is ever opened; this is for the user who wants
/// to know *now*, and for making the current version easy to quote in a bug report.
private struct UpdateRow: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Version \(Self.bundleVersion)")
                Text("Checks GitHub Releases once a day. You're always asked before anything downloads.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button("Check Now") { UpdateChecker.shared.checkNow() }
        }
    }

    private static var bundleVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "—"
    }
}

private struct KeychainSecretRow: View {
    @EnvironmentObject private var store: UsageStore

    let name: String
    let detail: String
    let service: String
    var onUpdate: () -> Void = {}

    @State private var text = ""
    @State private var stored = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Label(stored ? "Saved" : "Not set",
                      systemImage: stored ? "checkmark.circle.fill" : "circle")
                    .font(.caption)
                    .foregroundStyle(stored ? .green : .secondary)
            }
            HStack {
                SecureField("Paste value…", text: $text)
                    .textFieldStyle(.roundedBorder)
                Button("Save") {
                    KeychainHelper.save(text.trimmingCharacters(in: .whitespacesAndNewlines), service: service)
                    text = ""
                    stored = true
                    onUpdate()
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if stored {
                    Button("Remove") {
                        KeychainHelper.delete(service: service)
                        stored = false
                        onUpdate()
                    }
                }
            }
        }
        .onAppear { stored = KeychainHelper.exists(service: service) }
    }
}
