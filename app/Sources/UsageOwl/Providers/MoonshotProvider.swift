import Foundation
import SwiftUI

/// Moonshot AI platform pay-as-you-go balance (manual API key; no % gauge).
struct MoonshotProvider: AIProvider {
    let id = "moonshot"
    let name = "Moonshot"
    let brandColor = Color(red: 0.96, green: 0.62, blue: 0.12)
    let setupHint = "Paste a Moonshot platform API key in Settings"

    static let keyService = "UsageOwl-moonshot-key"

    func isAvailable() -> Bool {
        guard let key = KeychainHelper.read(service: Self.keyService) else { return false }
        return !key.isEmpty
    }

    func fetchUsage() async -> UsageSnapshot {
        guard let key = KeychainHelper.read(service: Self.keyService), !key.isEmpty else {
            return errorSnapshot("No API key — \(setupHint)")
        }
        do {
            let (data, response) = try await HTTP.get(
                "https://api.moonshot.ai/v1/users/me/balance",
                headers: ["Authorization": "Bearer \(key)"])
            switch response.statusCode {
            case 200: break
            case 401, 403: return errorSnapshot("API key rejected — update it in Settings")
            default: return errorSnapshot("Moonshot API returned HTTP \(response.statusCode)")
            }
            guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let available = flexibleDouble(deepFind("available_balance", in: root)) else {
                return errorSnapshot("Unexpected response from Moonshot API")
            }
            var text = "Balance: \(Format.balance(available))"
            let cash = flexibleDouble(deepFind("cash_balance", in: root))
            let voucher = flexibleDouble(deepFind("voucher_balance", in: root))
            var parts: [String] = []
            if let cash { parts.append("cash \(Format.balance(cash))") }
            if let voucher { parts.append("voucher \(Format.balance(voucher))") }
            if !parts.isEmpty { text += " (\(parts.joined(separator: " · ")))" }
            return snapshot(plan: "Pay-as-you-go", balance: text)
        } catch {
            return errorSnapshot("Network error: \(error.localizedDescription)")
        }
    }
}
