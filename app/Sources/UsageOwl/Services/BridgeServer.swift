import Foundation
import Network

extension Notification.Name {
    static let bridgeUsageReceived = Notification.Name("usageowl.bridgeUsageReceived")
}

/// Tiny loopback bridge. The UsageOwl Bridge browser extension POSTs the
/// claude.ai usage JSON here; the app merges the windows the OAuth endpoint
/// doesn't return (e.g. Fable). Bound to 127.0.0.1 only — nothing is exposed
/// to the network, and no cookie ever reaches the app.
final class BridgeServer: @unchecked Sendable {
    static let shared = BridgeServer()
    static let port: UInt16 = 18347

    nonisolated static var cacheURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("UsageOwl", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("claude-org-usage.json")
    }

    /// Last sync timestamp from the bridge, if any.
    nonisolated static var lastSync: Date? {
        try? FileManager.default.attributesOfItem(atPath: cacheURL.path)[.modificationDate] as? Date
    }

    private let queue = DispatchQueue(label: "usageowl.bridge")
    private var listener: NWListener?

    func start() {
        queue.async {
            guard self.listener == nil else { return }
            let params = NWParameters.tcp
            params.requiredInterfaceType = .loopback
            self.listener = try? NWListener(using: params, on: NWEndpoint.Port(rawValue: Self.port)!)
            self.listener?.newConnectionHandler = { [weak self] conn in self?.handle(conn) }
            self.listener?.start(queue: self.queue)
        }
    }

    private func handle(_ conn: NWConnection) {
        conn.start(queue: queue)
        receive(conn, into: Data())
    }

    private func receive(_ conn: NWConnection, into buffer: Data) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 1 << 20) { [weak self] data, _, isComplete, _ in
            guard let self else { conn.cancel(); return }
            var buffer = buffer
            if let data { buffer.append(data) }
            if let response = self.responseIfComplete(buffer) {
                conn.send(content: response, completion: .contentProcessed { _ in conn.cancel() })
            } else if isComplete {
                conn.cancel()
            } else {
                self.receive(conn, into: buffer)
            }
        }
    }

    private func responseIfComplete(_ buffer: Data) -> Data? {
        guard let headerEnd = buffer.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let head = String(decoding: buffer[..<headerEnd.lowerBound], as: UTF8.self)
        let lines = head.split(separator: "\r\n", omittingEmptySubsequences: false)
        let parts = (lines.first ?? "").split(separator: " ")
        let method = parts.count > 0 ? String(parts[0]) : ""
        let path = parts.count > 1 ? String(parts[1]) : ""
        let contentLength = lines
            .first(where: { $0.lowercased().hasPrefix("content-length:") })
            .flatMap { Int($0.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces)) } ?? 0
        let bodyStart = headerEnd.upperBound
        guard buffer.count >= bodyStart + contentLength else { return nil }
        let body = buffer[bodyStart ..< bodyStart + contentLength]

        if method == "OPTIONS" { return Self.http(status: 204, body: Data()) }
        if method == "GET", path.hasPrefix("/connect") {
            return Self.redirect(to: "https://claude.ai/settings/usage")
        }
        if method == "GET", path == "/status" {
            return Self.http(status: 200, body: Data(#"{"ok":true,"app":"usageowl"}"#.utf8), type: "application/json")
        }
        if method == "POST", path == "/claude-usage", !body.isEmpty {
            try? body.write(to: Self.cacheURL)
            NotificationCenter.default.post(name: .bridgeUsageReceived, object: nil)
            return Self.http(status: 200, body: Data(#"{"ok":true}"#.utf8), type: "application/json")
        }
        return Self.http(status: 404, body: Data())
    }

    private static func redirect(to location: String) -> Data {
        var out = "HTTP/1.1 302 Found\r\nLocation: \(location)\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
        return Data(out.utf8)
    }

    private static func http(status: Int, body: Data, type: String = "text/plain") -> Data {
        let text = status == 204 ? "No Content" : status == 200 ? "OK" : "Not Found"
        var head = "HTTP/1.1 \(status) \(text)\r\n"
        head += "Content-Type: \(type)\r\nContent-Length: \(body.count)\r\nConnection: close\r\n"
        // The extension's worker context needs no CORS, but the claude.ai page
        // origin gets it for any page-side beacons.
        head += "Access-Control-Allow-Origin: https://claude.ai\r\n"
        head += "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\nAccess-Control-Allow-Headers: Content-Type\r\n"
        head += "\r\n"
        return Data(head.utf8) + body
    }
}
