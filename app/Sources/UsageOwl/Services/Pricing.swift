import Foundation

/// Public API list rates for one model, in USD per million tokens.
///
/// Cache rates are derived, not tabulated: a 5-minute cache write costs 1.25x
/// base input, a 1-hour write 2x, and a cache read 0.1x. Cache reads dominate
/// real Claude Code traffic by roughly 1000:1 over fresh input, so that 0.1x is
/// the single biggest factor in whether a total is right.
struct ModelRates {
    let input: Double
    let output: Double

    var cacheWrite5m: Double { input * 1.25 }
    var cacheWrite1h: Double { input * 2.0 }
    var cacheRead: Double { input * 0.1 }
}

/// Maps a model id from a Claude Code transcript to its list rates.
enum Pricing {
    /// Per-model rates. Current models are exact; the `-4-5`/`-4-1`/`-4-0`
    /// entries are the same tier rate their family has carried since.
    private static let table: [String: ModelRates] = [
        "claude-fable-5": ModelRates(input: 10, output: 50),
        "claude-mythos-5": ModelRates(input: 10, output: 50),
        "claude-opus-5": ModelRates(input: 5, output: 25),
        "claude-opus-4-8": ModelRates(input: 5, output: 25),
        "claude-opus-4-7": ModelRates(input: 5, output: 25),
        "claude-opus-4-6": ModelRates(input: 5, output: 25),
        "claude-opus-4-5": ModelRates(input: 5, output: 25),
        "claude-opus-4-1": ModelRates(input: 5, output: 25),
        "claude-opus-4-0": ModelRates(input: 5, output: 25),
        "claude-sonnet-5": ModelRates(input: 3, output: 15),
        "claude-sonnet-4-6": ModelRates(input: 3, output: 15),
        "claude-sonnet-4-5": ModelRates(input: 3, output: 15),
        "claude-sonnet-4-0": ModelRates(input: 3, output: 15),
        "claude-haiku-4-5": ModelRates(input: 1, output: 5),
    ]

    /// Tier fallback for bare aliases (`opus`, `sonnet`) and versions released
    /// after this table was written. Every model in a family has shared one
    /// input/output rate, so the tier is exact even when the version isn't known.
    private static let tiers: [(needle: String, rates: ModelRates)] = [
        ("fable", ModelRates(input: 10, output: 50)),
        ("mythos", ModelRates(input: 10, output: 50)),
        ("opus", ModelRates(input: 5, output: 25)),
        ("sonnet", ModelRates(input: 3, output: 15)),
        ("haiku", ModelRates(input: 1, output: 5)),
    ]

    /// Canonical form of a transcript model id.
    ///
    /// Strips the `[1m]` context selector — Opus 4.7 and later, Sonnet 5, and
    /// Sonnet 4.6 all carry a 1M window at standard rates, so there is no
    /// long-context premium to apply — and any trailing date snapshot.
    static func normalize(_ raw: String) -> String {
        var id = raw.lowercased().trimmingCharacters(in: .whitespaces)
        if let bracket = id.firstIndex(of: "[") { id = String(id[id.startIndex..<bracket]) }
        // "claude-haiku-4-5-20251001" -> "claude-haiku-4-5"
        let parts = id.split(separator: "-")
        if let last = parts.last, last.count == 8, last.allSatisfy(\.isNumber) {
            id = parts.dropLast().joined(separator: "-")
        }
        return id
    }

    /// True for anything billed as a Claude model. Filters out MCP-provided
    /// models that appear in transcripts (image/video generators and the like),
    /// which would otherwise be reported as untracked Claude spend.
    static func isClaudeModel(_ normalized: String) -> Bool {
        if normalized.hasPrefix("claude") { return true }
        return tiers.contains { normalized == $0.needle }
    }

    static func rates(for normalized: String) -> ModelRates? {
        if let exact = table[normalized] { return exact }
        return tiers.first { normalized.contains($0.needle) }?.rates
    }
}
