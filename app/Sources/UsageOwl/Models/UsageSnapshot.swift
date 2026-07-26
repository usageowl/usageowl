import Foundation
import SwiftUI

/// One quota window for a provider, e.g. "5-hour", "Weekly", "Monthly".
struct UsageWindow: Identifiable, Hashable {
    let id = UUID()
    var label: String
    var usedPercent: Double   // 0...100
    var resetDate: Date?
}

/// Provider-agnostic usage snapshot shown in the menu bar popup.
struct UsageSnapshot: Identifiable {
    var id: String            // provider id
    var displayName: String
    var planLabel: String?
    var windows: [UsageWindow]
    var balanceText: String?
    /// API-equivalent value and any real charges. Separate from `balanceText`,
    /// which is a provider-supplied display string.
    var spend: SpendSummary?
    var fetchedAt: Date
    var error: String?

    var worstPercent: Double? { windows.map(\.usedPercent).max() }

    /// The shortest-lived window (soonest reset) — the one shown in the menu bar.
    var primaryWindow: UsageWindow? {
        windows.min { ($0.resetDate ?? .distantFuture) < ($1.resetDate ?? .distantFuture) }
    }
}

enum GaugeColor {
    static func color(for percent: Double) -> Color {
        switch percent {
        case ..<50: return .green
        case ..<80: return .orange
        default: return .red
        }
    }
}
