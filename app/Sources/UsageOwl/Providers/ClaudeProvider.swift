import Foundation
import SwiftUI

/// Claude Code OAuth usage, with a claude.ai session-cookie fallback.
struct ClaudeProvider: AIProvider {
    let id = "claude"
    let name = "Claude"
    let brandColor = Color(red: 0.85, green: 0.47, blue: 0.34)
    let setupHint = "Sign in to Claude Code, or connect claude.ai in Settings"

    static let oauthService = "Claude Code-credentials"
    /// Pre-WebKit-transport cookie item. Only referenced to delete it — a cookie
    /// replayed through URLSession is refused by Cloudflare, so it was dead
    /// weight (see WebSession).
    static let legacyCookieService = "UsageOwl-claude-cookie"
    private let clientId = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"

    private var hasOAuth: Bool { KeychainHelper.exists(service: Self.oauthService, account: nil) }
    private var hasWeb: Bool { WebConnection.isConnected(WebService.claude.id) }

    func isAvailable() -> Bool { hasOAuth || hasWeb }

    func fetchUsage() async -> UsageSnapshot {
        var result: UsageSnapshot?
        var errors: [String] = []

        // claude.ai first when connected. It returns strictly more than the
        // OAuth endpoint — every window including model-scoped ones like Fable,
        // plus the real extra-usage charge — and it isn't subject to the OAuth
        // usage endpoint's rate limit, which returns 429 under repeated refreshes.
        if hasWeb {
            let snap = await fetchViaWeb()
            if snap.error == nil { result = snap } else if let error = snap.error { errors.append(error) }
        }
        if result == nil, hasOAuth {
            let snap = await fetchViaOAuth()
            if snap.error == nil { result = snap } else if let error = snap.error { errors.append(error) }
        }

        var out = result ?? errorSnapshot(errors.first ?? "Not signed in — \(setupHint)")
        // Plan comes from Claude Code's Keychain item, so it's available on the
        // claude.ai path too without spending an OAuth request on it.
        if out.planLabel == nil { out.planLabel = Self.planLabelFromKeychain() }
        out = mergeBridgeWindows(into: out)
        out.spend = await spendSummary(reported: out.spend)
        return out
    }

    /// Combines the two halves of spend: API-equivalent value, which only the
    /// local transcripts can supply (neither usage endpoint reports tokens), and
    /// the real charge, which only claude.ai reports.
    private func spendSummary(reported: SpendSummary?) async -> SpendSummary? {
        let local = await ClaudeCodeUsageReader.shared.summary(.month)
        var out = reported ?? local
        out.apiEquivalentUSD = local.apiEquivalentUSD
        out.tokens = local.tokens
        out.unpricedTokens = local.unpricedTokens
        guard out.tokens.total > 0 || out.chargedUSD != nil else { return nil }
        return out
    }

    private static func planLabelFromKeychain() -> String? {
        guard let data = KeychainHelper.readData(service: oauthService, account: nil),
              let creds = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = creds["claudeAiOauth"] as? [String: Any] else { return nil }
        return planLabel(oauth["subscriptionType"] as? String)
    }

    private func merge(extra: UsageSnapshot, into base: UsageSnapshot) -> UsageSnapshot {
        var merged = base
        for window in extra.windows
        where !base.windows.contains(where: { $0.label == window.label }) {
            merged.windows.append(window)
        }
        return merged
    }

    /// Windows pushed by the UsageOwl Bridge extension (claude.ai org usage).
    private func mergeBridgeWindows(into base: UsageSnapshot) -> UsageSnapshot {
        guard let data = try? Data(contentsOf: BridgeServer.cacheURL) else { return base }
        let snap = parseWindows(data)
        guard snap.error == nil else { return base }
        return merge(extra: snap, into: base)
    }

    // MARK: OAuth path (Claude Code keychain item)

    private func fetchViaOAuth() async -> UsageSnapshot {
        guard let credsData = KeychainHelper.readData(service: Self.oauthService, account: nil),
              let creds = try? JSONSerialization.jsonObject(with: credsData) as? [String: Any],
              let oauth = creds["claudeAiOauth"] as? [String: Any],
              let accessToken = oauth["accessToken"] as? String, !accessToken.isEmpty else {
            return errorSnapshot("Claude Code credentials unreadable")
        }
        let plan = Self.planLabel(oauth["subscriptionType"] as? String)
        do {
            var (data, response) = try await usageRequest(accessToken: accessToken)
            if response.statusCode == 401,
               let newToken = await refresh(oauth: oauth, creds: creds) {
                (data, response) = try await usageRequest(accessToken: newToken)
            }
            switch response.statusCode {
            case 200:
                var snap = parseWindows(data)
                if snap.planLabel == nil { snap.planLabel = plan }
                return snap
            case 401:
                return errorSnapshot("Token expired — open Claude Code to sign in again")
            case 429:
                // The usage endpoint rate-limits under repeated refreshes; this
                // is transient, not a broken credential.
                return errorSnapshot("Anthropic rate-limited the usage endpoint — retrying shortly")
            default:
                return errorSnapshot("Anthropic API returned HTTP \(response.statusCode)")
            }
        } catch {
            return errorSnapshot("Network error: \(error.localizedDescription)")
        }
    }

    private func usageRequest(accessToken: String) async throws -> (Data, HTTPURLResponse) {
        try await HTTP.get("https://api.anthropic.com/api/oauth/usage", headers: [
            "Authorization": "Bearer \(accessToken)",
            "anthropic-beta": "oauth-2025-04-20",
        ])
    }

    /// Refresh the OAuth token and write it back into the Claude Code keychain item.
    private func refresh(oauth: [String: Any], creds: [String: Any]) async -> String? {
        guard let refreshToken = oauth["refreshToken"] as? String, !refreshToken.isEmpty else { return nil }
        guard let (data, response) = try? await HTTP.postJSON(
            "https://console.anthropic.com/v1/oauth/token",
            body: ["grant_type": "refresh_token", "refresh_token": refreshToken, "client_id": clientId]),
            response.statusCode == 200,
            let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let access = dict["access_token"] as? String else { return nil }

        var updatedOauth = oauth
        updatedOauth["accessToken"] = access
        if let r = dict["refresh_token"] as? String { updatedOauth["refreshToken"] = r }
        if let expiresIn = flexibleDouble(dict["expires_in"]) {
            updatedOauth["expiresAt"] = Int64((Date().timeIntervalSince1970 + expiresIn) * 1000)
        }
        var updatedCreds = creds
        updatedCreds["claudeAiOauth"] = updatedOauth
        if let out = try? JSONSerialization.data(withJSONObject: updatedCreds) {
            KeychainHelper.updateData(out, service: Self.oauthService, account: nil)
        }
        return access
    }

    // MARK: claude.ai path (WebKit transport)

    /// Reads claude.ai's own usage endpoints through `WebSession`.
    ///
    /// Every request runs inside WebKit deliberately: the same call made with a
    /// `URLSession` carrying the same cookie is challenged by Cloudflare with a
    /// 403, because `cf_clearance` is bound to the client's TLS fingerprint and
    /// a spoofed User-Agent doesn't change that.
    private func fetchViaWeb() async -> UsageSnapshot {
        guard hasWeb else { return errorSnapshot("Not signed in — \(setupHint)") }
        do {
            let orgData = try await WebSession.claude.json(path: "/api/organizations")
            guard let orgs = try? JSONSerialization.jsonObject(with: orgData) as? [[String: Any]],
                  let orgId = orgs.first.flatMap({ ($0["uuid"] ?? $0["id"]) as? String }) else {
                return errorSnapshot("Couldn't read claude.ai organizations")
            }
            let data = try await WebSession.claude.json(
                path: "/api/organizations/\(orgId)/usage")
            return parseWindows(data)
        } catch {
            return errorSnapshot(error.localizedDescription)
        }
    }

    // MARK: Tolerant parsing (both API shapes)

    private func parseWindows(_ data: Data) -> UsageSnapshot {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return errorSnapshot("Unexpected Claude response")
        }

        // claude.ai returns a `limits` array that supersedes the individual
        // `five_hour` / `seven_day_*` keys. Verified shape:
        //   {kind: "session",       group: "session", percent: 4, resets_at: "…"}
        //   {kind: "weekly_all",    group: "weekly",  percent: 2, resets_at: "…"}
        //   {kind: "weekly_scoped", group: "weekly",  percent: 0, resets_at: null,
        //    scope: {model: {display_name: "Fable"}}}
        // The model-scoped entry is the *only* place Fable appears — every
        // `seven_day_opus` / `seven_day_sonnet` / codename key is null — so
        // scanning keys for "fable" (the previous approach) can never find it.
        if let limits = root["limits"] as? [[String: Any]], !limits.isEmpty {
            var windows: [UsageWindow] = []
            for limit in limits {
                guard let raw = flexibleDouble(limit["percent"] ?? limit["utilization"]) else { continue }
                windows.append(UsageWindow(label: Self.limitLabel(limit),
                                           usedPercent: min(raw <= 1.0 ? raw * 100 : raw, 100),
                                           resetDate: Format.date(from: limit["resets_at"] as? String)))
            }
            if !windows.isEmpty {
                return snapshot(windows: windows, spend: chargedSpend(in: root))
            }
        }

        let candidates: [([String], String)] = [
            (["five_hour", "fiveHour", "five-hour", "5h"], "5-hour"),
            (["seven_day", "sevenDay", "seven-day", "weekly", "7d"], "Weekly"),
            (["seven_day_opus", "sevenDayOpus"], "Opus weekly"),
            (["seven_day_sonnet", "sevenDaySonnet"], "Sonnet weekly"),
            (["monthly", "thirty_day"], "Monthly"),
        ]
        var windows: [UsageWindow] = []
        for (keys, label) in candidates {
            for key in keys {
                guard let dict = root[key] as? [String: Any] else { continue }
                let raw = flexibleDouble(dict["utilization"] ?? dict["used_percent"]
                    ?? dict["usedPercent"] ?? dict["percent"])
                guard let raw else { break }
                let pct = raw <= 1.0 ? raw * 100 : raw  // tolerate 0–1 or 0–100 scales
                let resetString = (dict["resets_at"] ?? dict["reset_at"]
                    ?? dict["resetAt"] ?? dict["reset"]) as? String
                windows.append(UsageWindow(label: label, usedPercent: min(pct, 100),
                                           resetDate: Format.date(from: resetString)))
                break
            }
        }
        // Model-specific limits (e.g. Fable): pick up any key containing the
        // model name that carries a utilization object — the API's exact key
        // ("fable", "seven_day_fable", …) is not documented anywhere public.
        for (key, value) in root {
            guard key.lowercased().contains("fable"),
                  let dict = value as? [String: Any],
                  let raw = flexibleDouble(dict["utilization"] ?? dict["used_percent"]
                      ?? dict["usedPercent"] ?? dict["percent"]) else { continue }
            let pct = raw <= 1.0 ? raw * 100 : raw
            let resetString = (dict["resets_at"] ?? dict["reset_at"]
                ?? dict["resetAt"] ?? dict["reset"]) as? String
            let window = UsageWindow(label: "Fable (7 day)", usedPercent: min(pct, 100),
                                     resetDate: Format.date(from: resetString))
            if let weekly = windows.firstIndex(where: { $0.label == "Weekly" }) {
                windows.insert(window, at: weekly + 1)
            } else {
                windows.append(window)
            }
            break
        }
        return snapshot(windows: windows,
                        spend: chargedSpend(in: root),
                        error: windows.isEmpty ? "No quota data in Claude response" : nil)
    }

    /// Human label for one `limits` entry.
    private static func limitLabel(_ limit: [String: Any]) -> String {
        // A model-scoped window is named after its model, which is how Fable and
        // any future per-model limit arrive.
        if let scope = limit["scope"] as? [String: Any],
           let model = scope["model"] as? [String: Any],
           let name = model["display_name"] as? String, !name.isEmpty {
            return "\(name) weekly"
        }
        switch limit["kind"] as? String {
        case "session": return "5-hour"
        case "weekly_all": return "Weekly"
        case "weekly_scoped": return "Weekly (scoped)"
        case let kind?: return Format.prettyLabel(kind)
        default: return "Window"
        }
    }

    /// Real money charged on top of the subscription.
    ///
    /// Verified shape — `spend` is the authoritative form, `extra_usage` the
    /// same figures in credit units:
    ///   spend: {used: {amount_minor: 29341, currency: "USD", exponent: 2},
    ///           limit: {amount_minor: 33000, …}, percent: 89, enabled: true}
    ///   extra_usage: {used_credits: 29341, monthly_limit: 33000,
    ///                 decimal_places: 2, utilization: 88.91, is_enabled: true}
    /// Absent means "not reported" and must never render as $0.00.
    private func chargedSpend(in root: [String: Any]) -> SpendSummary? {
        var charged: Double?
        var limit: Double?
        var percent: Double?

        // Turning extra usage off zeroes `used` and nulls `limit`, so a naive
        // read renders "$0.00 (0%)" — which says "you spent nothing" when the
        // truth is "nothing is being metered". Absent must mean not-reported.
        let enabled = (root["spend"] as? [String: Any])?["enabled"]
            ?? (root["extra_usage"] as? [String: Any])?["is_enabled"]
        if let enabled, let on = flexibleDouble(enabled), on == 0 { return nil }

        if let spend = root["spend"] as? [String: Any] {
            charged = Self.money(spend["used"])
            limit = Self.money(spend["limit"])
            percent = flexibleDouble(spend["percent"])
        }
        if charged == nil, let extra = root["extra_usage"] as? [String: Any] {
            let places = flexibleDouble(extra["decimal_places"]) ?? 2
            let divisor = pow(10.0, places)
            charged = flexibleDouble(extra["used_credits"]).map { $0 / divisor }
            limit = flexibleDouble(extra["monthly_limit"]).map { $0 / divisor }
            percent = flexibleDouble(extra["utilization"])
        }
        guard let charged else { return nil }

        return SpendSummary(periodLabel: "this month",
                            apiEquivalentUSD: 0,
                            chargedUSD: charged,
                            chargeLimitUSD: limit,
                            chargePercent: percent,
                            tokens: TokenTotals(),
                            unpricedTokens: 0)
    }

    /// `{amount_minor: 29341, exponent: 2}` -> 293.41
    private static func money(_ any: Any?) -> Double? {
        guard let dict = any as? [String: Any],
              let minor = flexibleDouble(dict["amount_minor"]) else { return nil }
        let exponent = flexibleDouble(dict["exponent"]) ?? 2
        return minor / pow(10.0, exponent)
    }

    private static func planLabel(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        switch raw.lowercased() {
        case "max": return "Claude Max"
        case "pro": return "Claude Pro"
        case "team": return "Claude Team"
        case "enterprise": return "Claude Enterprise"
        case "free": return "Claude Free"
        default: return "Claude \(Format.prettyLabel(raw))"
        }
    }
}
