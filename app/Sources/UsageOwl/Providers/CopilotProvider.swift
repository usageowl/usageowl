import Foundation
import SwiftUI

/// GitHub Copilot quota via the copilot_internal API.
struct CopilotProvider: AIProvider {
    let id = "copilot"
    let name = "Copilot"
    let brandColor = Color(red: 0.54, green: 0.36, blue: 0.96)
    let setupHint = "Paste a GitHub token in Settings, or sign in to Copilot in VS Code"

    static let tokenService = "UsageOwl-github-token"

    private var appsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/github-copilot/apps.json")
    }

    func isAvailable() -> Bool { token() != nil }

    /// Manual Keychain token first, then any oauth_token in github-copilot's apps.json.
    private func token() -> String? {
        if let t = KeychainHelper.read(service: Self.tokenService), !t.isEmpty { return t }
        guard let data = try? Data(contentsOf: appsURL),
              let json = try? JSONSerialization.jsonObject(with: data),
              let found = deepFind("oauth_token", in: json) as? String, !found.isEmpty else { return nil }
        return found
    }

    func fetchUsage() async -> UsageSnapshot {
        guard let token = token() else {
            return errorSnapshot("No GitHub token — \(setupHint)")
        }
        do {
            let (data, response) = try await HTTP.get("https://api.github.com/copilot_internal/user", headers: [
                "Authorization": "token \(token)",
                "Accept": "application/json",
                "Editor-Version": "vscode/1.96.2",
                "Editor-Plugin-Version": "copilot-chat/0.26.7",
                "User-Agent": "GitHubCopilotChat/0.26.7",
                "X-Github-Api-Version": "2025-04-01",
            ])
            switch response.statusCode {
            case 200: return parse(data)
            case 401, 403: return errorSnapshot("GitHub token rejected — update it in Settings")
            default: return errorSnapshot("GitHub API returned HTTP \(response.statusCode)")
            }
        } catch {
            return errorSnapshot("Network error: \(error.localizedDescription)")
        }
    }

    private func parse(_ data: Data) -> UsageSnapshot {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return errorSnapshot("Unexpected response from GitHub API")
        }
        let plan = (root["copilot_plan"] as? String).map(Self.planLabel)
        let reset = Format.date(from: root["quota_reset_date"] as? String)
        var windows: [UsageWindow] = []
        let snapshots = root["quota_snapshots"] as? [String: Any]
        for (key, label) in [("premium_interactions", "Premium requests"),
                             ("chat", "Chat"),
                             ("completions", "Completions")] {
            guard let quota = snapshots?[key] as? [String: Any],
                  (quota["unlimited"] as? Bool) != true,
                  let entitlement = flexibleDouble(quota["entitlement"]), entitlement > 0,
                  let remaining = flexibleDouble(quota["remaining"]) else { continue }
            let used = max(0, entitlement - remaining) / entitlement * 100
            windows.append(UsageWindow(label: label, usedPercent: min(used, 100), resetDate: reset))
        }
        return snapshot(plan: plan, windows: windows,
                        error: windows.isEmpty ? "No quota data in GitHub response" : nil)
    }

    private static func planLabel(_ raw: String) -> String {
        switch raw.lowercased() {
        case "pro": return "Copilot Pro"
        case "pro_plus": return "Copilot Pro+"
        case "business": return "Copilot Business"
        case "enterprise": return "Copilot Enterprise"
        case "free": return "Copilot Free"
        case "individual", "individual_pro": return "Copilot Individual"
        default: return "Copilot \(Format.prettyLabel(raw))"
        }
    }
}
