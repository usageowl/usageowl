import Foundation
import Security

/// Thin wrapper over Security.framework for storing small secrets and reading
/// credential items created by other tools (e.g. Claude Code).
///
/// Reads go through a process-lifetime cache: every Keychain item is read at
/// most ONCE per launch (including misses/denials, which are cached as nil),
/// so macOS can show at most one ACL prompt per item per launch instead of
/// one per refresh cycle. Writes are write-through (Keychain + cache).
enum KeychainHelper {
    private enum Cached {
        case value(Data)
        case missing  // not found OR access denied — don't re-prompt this launch
    }

    private static var cache: [String: Cached] = [:]
    private static let lock = NSLock()

    private static func cacheKey(service: String, account: String?) -> String {
        "\(service)\u{1F}\(account ?? "*")"
    }

    // MARK: Reads (cached)

    static func read(service: String, account: String? = "UsageOwl") -> String? {
        guard let data = readData(service: service, account: account) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func readData(service: String, account: String? = "UsageOwl") -> Data? {
        lock.lock()
        defer { lock.unlock() }
        let key = cacheKey(service: service, account: account)
        if let cached = cache[key] {
            switch cached {
            case .value(let data): return data
            case .missing: return nil
            }
        }
        var query = baseQuery(service: service, account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data {
            cache[key] = .value(data)
            return data
        }
        cache[key] = .missing
        return nil
    }

    static func exists(service: String, account: String? = "UsageOwl") -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let key = cacheKey(service: service, account: account)
        if let cached = cache[key] {
            switch cached {
            case .value: return true
            case .missing: return false
            }
        }
        // Attribute-only query (no data access -> no ACL prompt).
        return SecItemCopyMatching(baseQuery(service: service, account: account) as CFDictionary, nil) == errSecSuccess
    }

    // MARK: Writes (write-through)

    @discardableResult
    static func save(_ value: String, service: String, account: String = "UsageOwl") -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let query = baseQuery(service: service, account: account)
        SecItemDelete(query as CFDictionary)
        var attrs = query
        let data = Data(value.utf8)
        attrs[kSecValueData as String] = data
        attrs[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let ok = SecItemAdd(attrs as CFDictionary, nil) == errSecSuccess
        cache[cacheKey(service: service, account: account)] = ok ? .value(data) : .missing
        return ok
    }

    @discardableResult
    static func delete(service: String, account: String? = "UsageOwl") -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let ok = SecItemDelete(baseQuery(service: service, account: account) as CFDictionary) == errSecSuccess
        cache[cacheKey(service: service, account: account)] = .missing
        return ok
    }

    @discardableResult
    static func updateData(_ data: Data, service: String, account: String? = "UsageOwl") -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let ok = SecItemUpdate(baseQuery(service: service, account: account) as CFDictionary,
                               [kSecValueData as String: data] as CFDictionary) == errSecSuccess
        if ok { cache[cacheKey(service: service, account: account)] = .value(data) }
        return ok
    }

    /// `account == nil` matches any account for the given service.
    private static func baseQuery(service: String, account: String?) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        if let account { query[kSecAttrAccount as String] = account }
        return query
    }
}
