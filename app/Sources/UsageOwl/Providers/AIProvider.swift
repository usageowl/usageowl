import Foundation
import SwiftUI

/// A usage data source for one AI subscription.
protocol AIProvider: Sendable {
    var id: String { get }
    var name: String { get }
    var brandColor: Color { get }
    /// True when credentials exist locally and a fetch is worth attempting.
    func isAvailable() -> Bool
    /// Guidance shown in the popup when the provider isn't configured.
    var setupHint: String { get }
    func fetchUsage() async -> UsageSnapshot
}

extension AIProvider {
    func snapshot(plan: String? = nil, windows: [UsageWindow] = [], balance: String? = nil,
                  spend: SpendSummary? = nil, error: String? = nil) -> UsageSnapshot {
        UsageSnapshot(id: id, displayName: name, planLabel: plan,
                      windows: windows, balanceText: balance, spend: spend,
                      fetchedAt: Date(), error: error)
    }

    func errorSnapshot(_ message: String) -> UsageSnapshot { snapshot(error: message) }
}

enum ProviderRegistry {
    static let all: [any AIProvider] = [
        KimiProvider(),
        ChatGPTProvider(),
        ClaudeProvider(),
        CopilotProvider(),
        MoonshotProvider(),
    ]
}
