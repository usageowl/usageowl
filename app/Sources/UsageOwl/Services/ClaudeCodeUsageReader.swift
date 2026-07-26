import Foundation

/// Turns Claude Code's own transcripts into spend.
///
/// This is the only complete per-request token source on the machine. Both
/// claude.ai's usage endpoint and the OAuth usage endpoint report rate-limit
/// window utilisation — percentages, not tokens — so neither can produce a
/// dollar figure. `~/.claude/projects/**/*.jsonl` records exact per-request
/// usage, needs no credentials, and isn't behind Cloudflare.
///
/// Three details separate a correct total from an approximate one:
///
/// - Every content block of one API response is written as its own record
///   carrying the *same* usage object. Deduping on `(requestId, message.id)` is
///   what keeps the total from roughly doubling.
/// - Subagent transcripts live in `<session>/subagents/` and carry their own
///   usage; skipping them drops every Task-tool call.
/// - Claude Code prunes old transcripts on its own schedule, so day totals are
///   rolled up and persisted here instead of being recomputed from the tree.
actor ClaudeCodeUsageReader {
    static let shared = ClaudeCodeUsageReader()

    enum Period {
        case today
        case month
    }

    private struct FileCursor: Codable {
        var offset: UInt64
        var size: UInt64
    }

    private struct Ledger: Codable {
        var version = 1
        /// Transcript path -> how much of it has been rolled up.
        var files: [String: FileCursor] = [:]
        /// Local day ("2026-07-25") -> model -> tokens.
        var days: [String: [String: TokenTotals]] = [:]
    }

    private struct Record {
        let key: String
        let model: String
        let day: String
        let tokens: TokenTotals
        /// Byte offset of this record's line within the chunk just read.
        let lineStart: Int
    }

    private var ledger = Ledger()
    private var loaded = false
    private var scanning = false
    private(set) var lastScan: Date?

    /// Distinctive to assistant records — lets us skip full JSON parsing on the
    /// ~95% of lines (user turns, attachments, file snapshots) that carry no usage.
    private static let markerBytes: [UInt8] = Array("\"requestId\"".utf8)
    private static let newline = UInt8(0x0A)

    /// Actor-local formatters: `Format`'s are shared with the main actor and
    /// `ISO8601DateFormatter` is not safe for concurrent use.
    private let iso: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private let isoPlain = ISO8601DateFormatter()
    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static var ledgerURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("UsageOwl", isDirectory: true)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        return support.appendingPathComponent("claude-spend.json")
    }

    private static var transcriptRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects", isDirectory: true)
    }

    // MARK: Reading

    var hasData: Bool {
        loadIfNeeded()
        return !ledger.days.isEmpty
    }

    func summary(_ period: Period) -> SpendSummary {
        loadIfNeeded()
        let label: String
        let matches: (String) -> Bool
        switch period {
        case .today:
            let key = dayFormatter.string(from: Date())
            label = "today"
            matches = { $0 == key }
        case .month:
            let prefix = String(dayFormatter.string(from: Date()).prefix(7))
            label = "this month"
            matches = { $0.hasPrefix(prefix) }
        }

        var tokens = TokenTotals()
        var cost = 0.0
        var unpriced = 0
        for (day, models) in ledger.days where matches(day) {
            _ = day
            for (model, totals) in models {
                tokens += totals
                if let rates = Pricing.rates(for: model) {
                    cost += totals.cost(at: rates)
                } else {
                    unpriced += totals.total
                }
            }
        }
        return SpendSummary(periodLabel: label,
                            apiEquivalentUSD: cost,
                            chargedUSD: nil,
                            tokens: tokens,
                            unpricedTokens: unpriced)
    }

    // MARK: Scanning

    /// Incremental rescans only read appended bytes, but they still stat every
    /// transcript — once a minute is plenty for a figure that moves per request.
    func refreshIfStale(maxAge: TimeInterval = 60) async {
        if let lastScan, Date().timeIntervalSince(lastScan) < maxAge { return }
        await refresh()
    }

    /// Walks every transcript and rolls up whatever is new since last time.
    ///
    /// The first pass reads the whole tree (which can be gigabytes); every pass
    /// after that reads only bytes appended since.
    func refresh() async {
        guard !scanning else { return }
        scanning = true
        defer { scanning = false }
        loadIfNeeded()

        var present = Set<String>()
        for url in Self.transcriptURLs() {
            present.insert(url.path)
            ingest(url)
        }
        // Forget cursors for transcripts Claude Code has pruned. Their rolled-up
        // day totals stay — that history no longer exists anywhere else.
        ledger.files = ledger.files.filter { present.contains($0.key) }
        lastScan = Date()
        save()
    }

    /// Enumerated synchronously: `FileManager.enumerator` can't be iterated from
    /// an async context (a hard error in Swift 6). Recursive, so the
    /// `<session>/subagents/` transcripts come along — they hold every
    /// Task-tool call's usage and nothing else records it.
    private static func transcriptURLs() -> [URL] {
        let manager = FileManager.default
        guard manager.fileExists(atPath: transcriptRoot.path),
              let walker = manager.enumerator(
                at: transcriptRoot,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]) else { return [] }
        var urls: [URL] = []
        for case let url as URL in walker where url.pathExtension == "jsonl" {
            urls.append(url)
        }
        return urls
    }

    private func ingest(_ url: URL) {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attributes?[.size] as? NSNumber)?.uint64Value ?? 0
        let modified = (attributes?[.modificationDate] as? Date) ?? .distantPast

        var cursor = ledger.files[url.path] ?? FileCursor(offset: 0, size: 0)
        // Shorter than where we stopped means the file was replaced or rewritten;
        // reading from a stale offset would land mid-record.
        if size < cursor.offset { cursor = FileCursor(offset: 0, size: 0) }
        guard size > cursor.offset else { return }

        guard let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? handle.close() }
        try? handle.seek(toOffset: cursor.offset)
        guard let chunk = try? handle.readToEnd(), !chunk.isEmpty else { return }

        var records: [Record] = []
        var consumed = 0  // bytes through the end of the last complete line

        // `memchr`/`memmem` rather than a Swift byte loop and `Data.range(of:)`:
        // the first pass walks well over a gigabyte, and only the handful of
        // lines carrying usage are worth copying out and decoding.
        chunk.withUnsafeBytes { raw in
            guard let bufferBase = raw.baseAddress else { return }
            let total = raw.count
            Self.markerBytes.withUnsafeBufferPointer { needle in
                guard let needleBase = needle.baseAddress else { return }
                var start = 0
                while start < total {
                    guard let hit = memchr(bufferBase + start, Int32(Self.newline), total - start) else { break }
                    let index = UnsafeRawPointer(hit) - bufferBase
                    let length = index - start
                    consumed = index + 1
                    if length > 0,
                       memmem(bufferBase + start, length, needleBase, needle.count) != nil {
                        let line = Data(bytes: bufferBase + start, count: length)
                        if let record = parse(line, lineStart: start) { records.append(record) }
                    }
                    start = index + 1
                }
            }
        }
        guard consumed > 0 else { return }  // no complete line yet

        // Duplicate records for one response are written contiguously. While the
        // file is still being appended to, hold back the trailing run sharing the
        // last message id so a group split across two scans isn't counted twice.
        if modified.timeIntervalSinceNow > -60, let lastKey = records.last?.key {
            var cut = records.count
            while cut > 0, records[cut - 1].key == lastKey { cut -= 1 }
            guard cut > 0 else { return }
            consumed = records[cut].lineStart
            records = Array(records[0..<cut])
        }

        var seen = Set<String>()
        for record in records where seen.insert(record.key).inserted {
            ledger.days[record.day, default: [:]][record.model, default: TokenTotals()] += record.tokens
        }

        cursor.offset += UInt64(consumed)
        cursor.size = size
        ledger.files[url.path] = cursor
    }

    private func parse(_ line: Data, lineStart: Int) -> Record? {
        guard let root = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              root["type"] as? String == "assistant",
              let requestId = root["requestId"] as? String,
              let message = root["message"] as? [String: Any],
              let messageId = message["id"] as? String,
              let usage = message["usage"] as? [String: Any] else { return nil }

        // `<synthetic>` records are API-error placeholders; MCP-provided models
        // (image and video generators) aren't billed as Claude.
        let model = Pricing.normalize((message["model"] as? String) ?? "")
        guard Pricing.isClaudeModel(model) else { return nil }

        guard let stamp = root["timestamp"] as? String,
              let date = iso.date(from: stamp) ?? isoPlain.date(from: stamp) else { return nil }

        var tokens = TokenTotals()
        tokens.input = Self.int(usage["input_tokens"])
        tokens.output = Self.int(usage["output_tokens"])
        tokens.cacheRead = Self.int(usage["cache_read_input_tokens"])
        if let split = usage["cache_creation"] as? [String: Any] {
            tokens.cacheWrite5m = Self.int(split["ephemeral_5m_input_tokens"])
            tokens.cacheWrite1h = Self.int(split["ephemeral_1h_input_tokens"])
        }
        // Older records carry only the flat total; 5 minutes is the default TTL.
        if tokens.cacheWrite5m == 0, tokens.cacheWrite1h == 0 {
            tokens.cacheWrite5m = Self.int(usage["cache_creation_input_tokens"])
        }
        guard tokens.total > 0 else { return nil }

        return Record(key: "\(requestId)\u{1F}\(messageId)",
                      model: model,
                      day: dayFormatter.string(from: date),
                      tokens: tokens,
                      lineStart: lineStart)
    }

    private static func int(_ any: Any?) -> Int {
        (any as? NSNumber)?.intValue ?? 0
    }

    // MARK: Persistence

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        guard let data = try? Data(contentsOf: Self.ledgerURL),
              let stored = try? JSONDecoder().decode(Ledger.self, from: data) else { return }
        ledger = stored
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(ledger) else { return }
        try? data.write(to: Self.ledgerURL, options: .atomic)
    }
}
