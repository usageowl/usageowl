import SwiftUI

@main
struct UsageOwlApp: App {
    @StateObject private var store: UsageStore
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        if CommandLine.arguments.contains("--dump-spend") { Self.dumpSpendAndExit() }
        let store = UsageStore()
        _store = StateObject(wrappedValue: store)
        AppDelegate.store = store
    }

    /// `swift run UsageOwl --dump-spend` — scans the transcripts and prints the
    /// totals without bringing up the menu bar. The spend figures are derived
    /// from ~2,000 files, so being able to check them from a terminal beats
    /// reading them off a popover.
    private static func dumpSpendAndExit() -> Never {
        let done = DispatchSemaphore(value: 0)
        // Detached: `App.init()` is main-actor isolated, so a plain `Task`
        // inherits that isolation and deadlocks against the semaphore below.
        Task.detached {
            let reader = ClaudeCodeUsageReader.shared
            let started = Date()
            await reader.refresh()
            let today = await reader.summary(.today)
            let month = await reader.summary(.month)
            print(String(format: "scanned in %.1fs", Date().timeIntervalSince(started)))
            for summary in [today, month] {
                print("""

                \(summary.periodLabel):
                  API value        \(Format.usd(summary.apiEquivalentUSD))
                  input            \(summary.tokens.input)
                  output           \(summary.tokens.output)
                  cache write 5m   \(summary.tokens.cacheWrite5m)
                  cache write 1h   \(summary.tokens.cacheWrite1h)
                  cache read       \(summary.tokens.cacheRead)
                  total tokens     \(summary.tokens.total)
                  unpriced tokens  \(summary.unpricedTokens)
                """)
            }
            done.signal()
        }
        done.wait()
        exit(0)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuPopover()
                .environmentObject(store)
        } label: {
            MenuBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(store)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor static weak var store: UsageStore?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)  // belt and braces — LSUIElement is also set
        if CommandLine.arguments.contains("--probe-claude") {
            Task { @MainActor in await Self.probeClaudeAndExit() }
            return
        }
        if CommandLine.arguments.contains("--probe-chatgpt") {
            Task { @MainActor in await Self.probeChatGPTAndExit() }
            return
        }
        Notifier.shared.requestAuthorization()
        Task { @MainActor in Self.store?.start() }
        Task { @MainActor in UpdateChecker.shared.checkInBackgroundAfterLaunch() }
    }

    /// `--probe-claude` — exercises the WebKit transport end to end and reports
    /// what came back. A 401 is a *pass*: it means the offscreen webview loaded
    /// claude.ai and ran the fetch, and the account simply isn't signed in.
    /// A timeout or an unexpected-response error means the transport is broken.
    @MainActor
    private static func probeClaudeAndExit() async {
        print("connected flag: \(WebConnection.isConnected(WebService.claude.id))")
        do {
            let (status, body) = try await WebSession.claude.request(path: "/api/organizations")
            print("GET /api/organizations -> HTTP \(status)")
            print("  body[0..<400]: \(body.prefix(400))")
            guard status == 200,
                  let data = body.data(using: .utf8),
                  let orgs = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let orgId = orgs.first.flatMap({ ($0["uuid"] ?? $0["id"]) as? String }) else {
                print("stopping: no org id")
                exit(0)
            }
            print("  org: \(orgId)")
            let (usageStatus, usageBody) = try await WebSession.claude.request(
                path: "/api/organizations/\(orgId)/usage")
            print("GET /api/organizations/{org}/usage -> HTTP \(usageStatus)")
            if let data = usageBody.data(using: .utf8),
               let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                for key in ["spend", "extra_usage"] {
                    print("  \(key): \(root[key].map { "\($0)" } ?? "absent")")
                }
            }
        } catch {
            print("transport: FAIL — \(error.localizedDescription)")
        }

        // The parsed result — what the popover will actually render.
        let snapshot = await ClaudeProvider().fetchUsage()
        print("\n--- parsed snapshot ---")
        print("plan:  \(snapshot.planLabel ?? "—")")
        print("error: \(snapshot.error ?? "none")")
        if snapshot.windows.isEmpty { print("windows: NONE") }
        for window in snapshot.windows {
            let reset = window.resetDate.map { "resets \($0)" } ?? "no reset date"
            print(String(format: "window: %-18@ %5.1f%%  %@",
                         window.label as NSString, window.usedPercent, reset))
        }
        if let spend = snapshot.spend {
            print("spend: API value \(Format.usd(spend.apiEquivalentUSD)) \(spend.periodLabel)")
            if let charged = spend.chargedUSD {
                let limit = spend.chargeLimitUSD.map { " / \(Format.usd($0, cents: true))" } ?? ""
                let percent = spend.chargePercent.map { String(format: " (%.0f%%)", $0) } ?? ""
                print("spend: charged  \(Format.usd(charged, cents: true))\(limit)\(percent)")
            } else {
                print("spend: charged  not reported")
            }
            print("spend: tokens \(spend.tokens.total), unpriced \(spend.unpricedTokens)")
        } else {
            print("spend: nil")
        }
        exit(0)
    }

    /// `--probe-chatgpt` — walks candidate endpoints and reports which actually
    /// answer, so the provider's chain is chosen from evidence rather than a
    /// guess at ChatGPT's undocumented internal API. Never prints a token.
    @MainActor
    private static func probeChatGPTAndExit() async {
        let session = WebSession.chatGPT
        print("connected flag: \(WebConnection.isConnected(WebService.chatGPT.id))")

        var bearer: String?
        if let (status, body) = try? await session.request(path: ChatGPTProvider.sessionPath) {
            print("GET \(ChatGPTProvider.sessionPath) -> HTTP \(status)")
            if let data = body.data(using: .utf8),
               let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("  keys: \(root.keys.sorted())")
                if let token = root["accessToken"] as? String {
                    bearer = token
                    print("  accessToken: present (\(token.count) chars)")
                } else {
                    print("  accessToken: ABSENT — likely signed out")
                }
                for key in ["account_id", "accountId", "chatgpt_account_id"] {
                    if let value = deepFind(key, in: root) as? String {
                        print("  \(key): \(value)")
                    }
                }
            } else {
                print("  body[0..<200]: \(body.prefix(200))")
            }
        } else {
            print("GET \(ChatGPTProvider.sessionPath) -> transport failure")
        }

        // Which auth does the usage endpoint actually accept?
        var attempts: [(String, [String: String])] = [
            ("cookies only", [:]),
        ]
        if let bearer { attempts.append(("bearer", ["Authorization": "Bearer \(bearer)"])) }
        for (label, headers) in attempts {
            guard let (status, body) = try? await session.request(
                path: ChatGPTProvider.usagePath, headers: headers) else {
                print("GET \(ChatGPTProvider.usagePath) [\(label)] -> transport failure")
                continue
            }
            print("GET \(ChatGPTProvider.usagePath) [\(label)] -> HTTP \(status)")
            print("  body[0..<700]: \(body.prefix(700))")
            if status == 200 { break }
        }

        print("\n--- parsed snapshot ---")
        let snapshot = await ChatGPTProvider().fetchUsage()
        print("plan:  \(snapshot.planLabel ?? "—")")
        print("error: \(snapshot.error ?? "none")")
        if snapshot.windows.isEmpty { print("windows: NONE") }
        for window in snapshot.windows {
            let reset = window.resetDate.map { "resets \($0)" } ?? "no reset date"
            print(String(format: "window: %-18@ %5.1f%%  %@",
                         window.label as NSString, window.usedPercent, reset))
        }
        print("balance: \(snapshot.balanceText ?? "—")")
        exit(0)
    }
}
