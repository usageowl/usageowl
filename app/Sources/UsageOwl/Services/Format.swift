import Foundation

/// Shared formatting and tolerant parsing helpers.
enum Format {
    private static let isoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let iso = ISO8601DateFormatter()

    /// Parses ISO-8601 (with or without fractional seconds) and plain "yyyy-MM-dd".
    static func date(from string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        if let d = isoFrac.date(from: string) ?? iso.date(from: string) { return d }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: string)
    }

    static func percent(_ value: Double) -> String {
        "\(Int(min(max(value, 0), 100).rounded()))%"
    }

    /// "resets in 3h 12m" style countdown.
    static func countdown(to date: Date?) -> String? {
        guard let date else { return nil }
        let interval = date.timeIntervalSinceNow
        if interval <= 0 { return "resetting…" }
        let minutes = Int(interval / 60)
        let d = minutes / 1440, h = (minutes % 1440) / 60, m = minutes % 60
        if d > 0 { return "resets in \(d)d \(h)h" }
        if h > 0 { return "resets in \(h)h \(m)m" }
        return "resets in \(max(m, 1))m"
    }

    /// "Resets at 14:09" (same day) or "Resets on 24 Jul at 11:59 PM" (later).
    static func resetText(_ date: Date?) -> String? {
        guard let date else { return nil }
        if date.timeIntervalSinceNow <= 0 { return "Resetting…" }
        if Calendar.current.isDateInToday(date) {
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            return "Resets at \(f.string(from: date))"
        }
        let f = DateFormatter()
        f.dateFormat = "d MMM 'at' h:mm a"
        return "Resets on \(f.string(from: date))"
    }

    /// Card display label: "5-hour" -> "Session (5 hour)", "Weekly" -> "Weekly (7 day)".
    static func displayLabel(_ windowLabel: String) -> String {
        switch windowLabel {
        case "Weekly": return "Weekly (7 day)"
        case "Daily": return "Daily (24 hour)"
        case "Monthly": return "Monthly (30 day)"
        default:
            if windowLabel.hasSuffix("-hour") {
                return "Session (\(windowLabel.dropLast(5)) hour)"
            }
            return windowLabel
        }
    }

    static func relative(_ date: Date) -> String {
        RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
    }

    /// Human label for a window length in seconds (604800 -> "Weekly").
    static func windowLabel(seconds: Int) -> String {
        if seconds == 604800 { return "Weekly" }
        if seconds == 86400 { return "Daily" }
        if seconds > 0, seconds % 604800 == 0 { return "\(seconds / 604800)-week" }
        if seconds > 0, seconds % 86400 == 0 { return "\(seconds / 86400)-day" }
        if seconds > 0, seconds % 3600 == 0 { return "\(seconds / 3600)-hour" }
        if seconds > 0, seconds % 60 == 0 { return "\(seconds / 60)-min" }
        return "Window"
    }

    /// "LEVEL_INTERMEDIATE" -> "Intermediate", "pro_plus" -> "Pro Plus".
    static func prettyLabel(_ raw: String, stripPrefix: String? = nil) -> String {
        var s = raw
        if let stripPrefix, s.hasPrefix(stripPrefix) { s.removeFirst(stripPrefix.count) }
        return s.lowercased().split(separator: "_").map(\.capitalized).joined(separator: " ")
    }

    static func balance(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    /// "$0.42", "$12.30", "$1,204". Cents are dropped above $100 by default,
    /// where they're noise — pass `cents: true` for amounts actually billed,
    /// where they aren't.
    static func usd(_ value: Double, cents: Bool? = nil) -> String {
        let digits = (cents ?? (value < 100)) ? 2 : 0
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.locale = Locale(identifier: "en_US")
        formatter.maximumFractionDigits = digits
        formatter.minimumFractionDigits = digits
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "$%.2f", value)
    }

    /// "1.2M", "48.3K" — token counts, where exact digits don't help.
    static func compactTokens(_ value: Int) -> String {
        switch value {
        case 1_000_000...: return String(format: "%.1fM", Double(value) / 1_000_000)
        case 1_000...: return String(format: "%.0fK", Double(value) / 1_000)
        default: return "\(value)"
        }
    }
}

/// Tolerant number extraction: NSNumber, numeric String, etc.
func flexibleDouble(_ any: Any?) -> Double? {
    switch any {
    case let n as NSNumber: return n.doubleValue
    case let s as String: return Double(s.trimmingCharacters(in: .whitespaces))
    default: return nil
    }
}

/// Depth-first search for a key inside nested JSON dictionaries/arrays.
func deepFind(_ key: String, in any: Any?) -> Any? {
    guard let any else { return nil }
    if let dict = any as? [String: Any] {
        if let hit = dict[key] { return hit }
        for value in dict.values {
            if let found = deepFind(key, in: value) { return found }
        }
    } else if let array = any as? [Any] {
        for value in array {
            if let found = deepFind(key, in: value) { return found }
        }
    }
    return nil
}
