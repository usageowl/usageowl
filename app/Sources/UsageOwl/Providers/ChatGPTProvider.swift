import Foundation
import SwiftUI

/// ChatGPT Plus/Pro usage.
///
/// Two credential routes, preferring the friendlier one: a one-click chatgpt.com
/// sign-in (read through WebKit, same mechanism as claude.ai), falling back to
/// the Codex CLI's tokens at `~/.codex/auth.json` when they're present.
struct ChatGPTProvider: AIProvider {
    /// Deliberately still "codex": the id keys `showInMenuBar.<id>` in
    /// UserDefaults and selects the menu-bar glyph, so changing it would
    /// silently reset the user's toggles.
    let id = "codex"
    let name = "ChatGPT"
    let brandColor = Color(red: 0.06, green: 0.64, blue: 0.51)
    let setupHint = "Connect ChatGPT in Settings, or sign in to the Codex CLI"

    static let usagePath = "/backend-api/wham/usage"
    static let sessionPath = "/api/auth/session"

    private var authURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/auth.json")
    }

    private var hasCLI: Bool { FileManager.default.fileExists(atPath: authURL.path) }
    private var hasWeb: Bool { WebConnection.isConnected(WebService.chatGPT.id) }

    func isAvailable() -> Bool { hasWeb || hasCLI }

    func fetchUsage() async -> UsageSnapshot {
        var errors: [String] = []
        if hasWeb {
            let snap = await fetchViaWeb()
            if snap.error == nil { return snap }
            if let error = snap.error { errors.append(error) }
        }
        if hasCLI {
            let snap = await fetchViaCLI()
            if snap.error == nil { return snap }
            if let error = snap.error { errors.append(error) }
        }
        return errorSnapshot(errors.first ?? "Not signed in — \(setupHint)")
    }

    // MARK: chatgpt.com path (WebKit transport)

    /// The browser session authenticates with cookies, but `/backend-api/*`
    /// expects a bearer token — the web app itself reads one from
    /// `/api/auth/session` and forwards it. Both hops run inside WebKit, so
    /// Cloudflare sees ordinary page traffic.
    private func fetchViaWeb() async -> UsageSnapshot {
        do {
            let sessionData = try await WebSession.chatGPT.json(path: Self.sessionPath)
            guard let root = try? JSONSerialization.jsonObject(with: sessionData) as? [String: Any] else {
                return errorSnapshot("Unexpected ChatGPT session response")
            }
            guard let token = root["accessToken"] as? String, !token.isEmpty else {
                // 200 with no token means signed out — ChatGPT returns `{}`
                // rather than a 401 here.
                WebConnection.mark(WebService.chatGPT.id, connected: false)
                return errorSnapshot("ChatGPT session expired — reconnect in Settings")
            }
            var headers = ["Authorization": "Bearer \(token)"]
            if let accountId = Self.accountId(in: root) {
                headers["ChatGPT-Account-Id"] = accountId
            }
            let usage = try await WebSession.chatGPT.json(path: Self.usagePath, headers: headers)
            return parse(usage)
        } catch {
            return errorSnapshot(error.localizedDescription)
        }
    }

    /// The account id isn't at a documented path in the session payload, so look
    /// for it by name at any depth.
    private static func accountId(in root: [String: Any]) -> String? {
        for key in ["account_id", "accountId", "chatgpt_account_id"] {
            if let value = deepFind(key, in: root) as? String, !value.isEmpty { return value }
        }
        return nil
    }

    // MARK: Codex CLI path

    private func fetchViaCLI() async -> UsageSnapshot {
        guard let data = try? Data(contentsOf: authURL),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = root["tokens"] as? [String: Any],
              let accessToken = tokens["access_token"] as? String, !accessToken.isEmpty else {
            return errorSnapshot("No Codex tokens — run `codex` to sign in")
        }
        var headers = ["Authorization": "Bearer \(accessToken)"]
        if let accountId = tokens["account_id"] as? String, !accountId.isEmpty {
            headers["ChatGPT-Account-Id"] = accountId
        }
        do {
            let (body, response) = try await HTTP.get(
                "https://chatgpt.com" + Self.usagePath, headers: headers)
            switch response.statusCode {
            case 200: return parse(body)
            case 401, 403: return errorSnapshot("Session expired — run `codex` to re-authenticate")
            case 429: return errorSnapshot("ChatGPT rate-limited the usage endpoint — retrying shortly")
            default: return errorSnapshot("ChatGPT API returned HTTP \(response.statusCode)")
            }
        } catch {
            return errorSnapshot("Network error: \(error.localizedDescription)")
        }
    }

    // MARK: Parsing

    private func parse(_ data: Data) -> UsageSnapshot {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return errorSnapshot("Unexpected response from ChatGPT API")
        }
        let plan = (root["plan_type"] as? String).map(Self.planLabel)
        var windows: [UsageWindow] = []
        let rateLimit = root["rate_limit"] as? [String: Any]
        for key in ["primary_window", "secondary_window"] {
            guard let w = rateLimit?[key] as? [String: Any],
                  let used = flexibleDouble(w["used_percent"]) else { continue }
            let seconds = Int(flexibleDouble(w["limit_window_seconds"]) ?? 0)
            let reset = flexibleDouble(w["reset_at"]).map { Date(timeIntervalSince1970: $0) }
            windows.append(UsageWindow(label: Format.windowLabel(seconds: seconds),
                                       usedPercent: min(used, 100), resetDate: reset))
        }
        var balance: String?
        if let credits = root["credits"] as? [String: Any],
           let value = flexibleDouble(credits["balance"]) {
            balance = "Credits: \(Format.balance(value))"
        }
        return snapshot(plan: plan, windows: windows, balance: balance,
                        error: windows.isEmpty && balance == nil ? "No quota data in response" : nil)
    }

    private static func planLabel(_ raw: String) -> String {
        switch raw.lowercased() {
        case "plus": return "ChatGPT Plus"
        case "pro": return "ChatGPT Pro"
        case "team": return "ChatGPT Team"
        case "business": return "ChatGPT Business"
        case "enterprise": return "ChatGPT Enterprise"
        case "free": return "ChatGPT Free"
        default: return "ChatGPT \(Format.prettyLabel(raw))"
        }
    }
}
