import Foundation

enum HTTPError: LocalizedError {
    case invalidURL(String)
    case notHTTP

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url): return "Invalid URL: \(url)"
        case .notHTTP: return "Not an HTTP response"
        }
    }
}

/// Minimal shared URLSession wrapper.
enum HTTP {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        return URLSession(configuration: config)
    }()

    @discardableResult
    static func get(_ urlString: String, headers: [String: String] = [:]) async throws -> (Data, HTTPURLResponse) {
        try await send(urlString, method: "GET", headers: headers)
    }

    @discardableResult
    static func postJSON(_ urlString: String, headers: [String: String] = [:], body: [String: Any]) async throws -> (Data, HTTPURLResponse) {
        var h = headers
        h["Content-Type"] = "application/json"
        return try await send(urlString, method: "POST", headers: h, body: JSONSerialization.data(withJSONObject: body))
    }

    private static func send(_ urlString: String, method: String, headers: [String: String], body: Data? = nil) async throws -> (Data, HTTPURLResponse) {
        guard let url = URL(string: urlString) else { throw HTTPError.invalidURL(urlString) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw HTTPError.notHTTP }
        return (data, http)
    }
}
