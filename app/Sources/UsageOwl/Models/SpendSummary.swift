import Foundation

/// Token counts for one bucket, split the way the API bills them.
struct TokenTotals: Codable, Hashable {
    var input = 0
    var output = 0
    var cacheWrite5m = 0
    var cacheWrite1h = 0
    var cacheRead = 0

    var total: Int { input + output + cacheWrite5m + cacheWrite1h + cacheRead }

    static func += (lhs: inout TokenTotals, rhs: TokenTotals) {
        lhs.input += rhs.input
        lhs.output += rhs.output
        lhs.cacheWrite5m += rhs.cacheWrite5m
        lhs.cacheWrite1h += rhs.cacheWrite1h
        lhs.cacheRead += rhs.cacheRead
    }

    func cost(at rates: ModelRates) -> Double {
        let perToken = 1_000_000.0
        return Double(input) / perToken * rates.input
            + Double(output) / perToken * rates.output
            + Double(cacheWrite5m) / perToken * rates.cacheWrite5m
            + Double(cacheWrite1h) / perToken * rates.cacheWrite1h
            + Double(cacheRead) / perToken * rates.cacheRead
    }
}

/// What a provider's usage is worth, and what it actually cost.
///
/// The two are deliberately separate. On a flat-rate subscription
/// `apiEquivalentUSD` is value received, not money owed — the figure that says
/// "this month would have cost $340 on the API". `chargedUSD` is real money:
/// overage, credits, pay-as-you-go balances. Showing one as the other would
/// misrepresent a bill.
struct SpendSummary: Hashable {
    /// e.g. "today", "this month".
    var periodLabel: String
    /// Value of the work at the provider's public API rates.
    var apiEquivalentUSD: Double
    /// Money genuinely charged beyond the subscription, when the provider
    /// reports it. `nil` means "not reported", never "zero".
    var chargedUSD: Double?
    /// The cap that charge counts against, when reported.
    var chargeLimitUSD: Double?
    /// Provider-reported percentage of the cap used — kept rather than derived,
    /// so it stays right if the cap is reported in a different unit.
    var chargePercent: Double?
    var tokens: TokenTotals
    /// Tokens from Claude models with no rate in the table — surfaced rather
    /// than silently counted as free.
    var unpricedTokens: Int

    var hasUnpriced: Bool { unpricedTokens > 0 }
}
