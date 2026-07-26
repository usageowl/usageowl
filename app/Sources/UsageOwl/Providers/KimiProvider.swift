import Foundation
import SwiftUI

/// Kimi Code CLI subscription — reads OAuth tokens written by the CLI.
struct KimiProvider: AIProvider {
    let id = "kimi"
    let name = "Kimi"
    let brandColor = Color(red: 0.12, green: 0.39, blue: 0.94)
    let setupHint = "Install Kimi Code CLI and run /login"

    private var credentialsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".kimi-code/credentials/kimi-code.json")
    }

    func isAvailable() -> Bool {
        FileManager.default.fileExists(atPath: credentialsURL.path)
    }

    func fetchUsage() async -> UsageSnapshot {
        guard let data = try? Data(contentsOf: credentialsURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String, !accessToken.isEmpty else {
            return errorSnapshot("Unreadable credentials — open Kimi CLI and run /login")
        }
        do {
            var (body, response) = try await usageRequest(accessToken: accessToken)
            if response.statusCode == 401, let newToken = await refresh(using: json) {
                (body, response) = try await usageRequest(accessToken: newToken)
            }
            switch response.statusCode {
            case 200: return parse(body)
            case 401: return errorSnapshot("Session expired — open Kimi CLI and run /login")
            default: return errorSnapshot("Kimi API returned HTTP \(response.statusCode)")
            }
        } catch {
            return errorSnapshot("Network error: \(error.localizedDescription)")
        }
    }

    private func usageRequest(accessToken: String) async throws -> (Data, HTTPURLResponse) {
        try await HTTP.get("https://api.kimi.com/coding/v1/usages",
                           headers: ["Authorization": "Bearer \(accessToken)"])
    }

    /// Refresh the OAuth token and persist the new pair back into the CLI's file.
    private func refresh(using creds: [String: Any]) async -> String? {
        guard let refreshToken = creds["refresh_token"] as? String, !refreshToken.isEmpty else { return nil }
        guard let (data, response) = try? await HTTP.postJSON(
            "https://auth.kimi.com/v1/oauth/token",
            body: ["grant_type": "refresh_token", "refresh_token": refreshToken]),
            response.statusCode == 200,
            let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let access = dict["access_token"] as? String else { return nil }

        var updated = creds
        updated["access_token"] = access
        if let r = dict["refresh_token"] as? String { updated["refresh_token"] = r }
        if let expiresIn = flexibleDouble(dict["expires_in"]) {
            let expiry = Date().timeIntervalSince1970 + expiresIn
            // Keep the original magnitude of expires_at (seconds vs milliseconds).
            let inMillis = (flexibleDouble(creds["expires_at"]) ?? 0) > 1e11
            updated["expires_at"] = inMillis ? Int64(expiry * 1000) : Int64(expiry)
        }
        if let out = try? JSONSerialization.data(withJSONObject: updated, options: [.prettyPrinted, .sortedKeys]) {
            try? out.write(to: credentialsURL, options: .atomic)
        }
        return access
    }

    private func parse(_ data: Data) -> UsageSnapshot {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return errorSnapshot("Unexpected response from Kimi API")
        }
        let level = ((root["user"] as? [String: Any])?["membership"] as? [String: Any])?["level"] as? String
        let plan = level.map { Format.prettyLabel($0, stripPrefix: "LEVEL_") }

        var windows: [UsageWindow] = []
        if let usage = root["usage"] as? [String: Any], let w = quotaWindow(usage, label: "Weekly") {
            windows.append(w)
        }
        for entry in root["limits"] as? [[String: Any]] ?? [] {
            guard let detail = entry["detail"] as? [String: Any] else { continue }
            if let w = quotaWindow(detail, label: rateWindowLabel(entry["window"] as? [String: Any])) {
                windows.append(w)
            }
        }
        return snapshot(plan: plan, windows: windows,
                        error: windows.isEmpty ? "No quota data in Kimi response" : nil)
    }

    private func quotaWindow(_ dict: [String: Any], label: String) -> UsageWindow? {
        guard let limit = flexibleDouble(dict["limit"]), limit > 0,
              let used = flexibleDouble(dict["used"]) else { return nil }
        return UsageWindow(label: label,
                           usedPercent: min(used / limit * 100, 100),
                           resetDate: Format.date(from: dict["resetTime"] as? String))
    }

    private func rateWindowLabel(_ window: [String: Any]?) -> String {
        guard let duration = flexibleDouble(window?["duration"]),
              let unit = window?["timeUnit"] as? String else { return "Rate window" }
        switch unit {
        case "TIME_UNIT_MINUTE": return Format.windowLabel(seconds: Int(duration) * 60)
        case "TIME_UNIT_HOUR": return Format.windowLabel(seconds: Int(duration) * 3600)
        case "TIME_UNIT_DAY": return Format.windowLabel(seconds: Int(duration) * 86400)
        default: return "Rate window"
        }
    }
}
