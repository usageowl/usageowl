import AppKit
import Foundation
import WebKit

/// A site UsageOwl can sign in to and read usage from.
struct WebService {
    let id: String
    /// Shown in Settings and the sign-in sheet.
    let displayName: String
    let origin: URL
    let loginURL: URL
    /// Fetched to decide whether a live session exists.
    let verifyPath: String
    /// True when this response proves a live session. A status check alone isn't
    /// always enough — ChatGPT answers `/api/auth/session` with 200 and an empty
    /// object when signed out.
    let verify: (Int, String) -> Bool
    /// Cookie name accepted by the manual paste fallback.
    let sessionCookieName: String

    static let claude = WebService(
        id: "claude",
        displayName: "claude.ai",
        origin: URL(string: "https://claude.ai/")!,
        loginURL: URL(string: "https://claude.ai/login")!,
        verifyPath: "/api/organizations",
        verify: { status, _ in status == 200 },
        sessionCookieName: "sessionKey")

    static let chatGPT = WebService(
        id: "codex",  // unchanged: the id keys menu-bar prefs and the glyph
        displayName: "ChatGPT",
        origin: URL(string: "https://chatgpt.com/")!,
        loginURL: URL(string: "https://chatgpt.com/auth/login")!,
        verifyPath: "/api/auth/session",
        verify: { status, body in status == 200 && body.contains("accessToken") },
        sessionCookieName: "__Secure-next-auth.session-token")
}

/// Whether a sign-in has completed in the persistent WebKit store, per service.
///
/// Lives in UserDefaults because `AIProvider.isAvailable()` is synchronous and
/// called off the main actor, while `WebSession` is main-actor isolated.
enum WebConnection {
    private static func key(_ id: String) -> String { "\(id)WebConnected" }

    static func isConnected(_ id: String) -> Bool {
        UserDefaults.standard.bool(forKey: key(id))
    }

    static func mark(_ id: String, connected: Bool) {
        UserDefaults.standard.set(connected, forKey: key(id))
    }
}

/// The transport: one persistent, offscreen `WKWebView` per service, acting as
/// the HTTP client for that site.
///
/// `fetch` runs *inside* WebKit, so the request carries the page's own cookie
/// jar and TLS fingerprint. That is the only thing that gets past Cloudflare's
/// bot check — a `URLSession` presenting the same cookie is challenged with a
/// 403 no matter which User-Agent it claims, which is why the earlier
/// capture-the-cookie-then-use-URLSession design could never work.
///
/// The store is WebKit's persistent per-app store, so one sign-in survives
/// quit/relaunch and Cloudflare keeps `cf_clearance` fresh on its own. Session
/// cookies never leave WebKit: never read, never copied, never in the Keychain.
@MainActor
final class WebSession: NSObject {
    static let claude = WebSession(service: .claude)
    static let chatGPT = WebSession(service: .chatGPT)

    static func session(for service: WebService) -> WebSession {
        service.id == WebService.claude.id ? .claude : .chatGPT
    }

    enum Failure: LocalizedError {
        case needsLogin(String)
        case busy
        case timedOut
        case http(Int)
        case badResponse

        var errorDescription: String? {
            switch self {
            case .needsLogin(let name): return "\(name) not connected — connect in Settings"
            case .busy: return "Request already in flight"
            case .timedOut: return "Request timed out"
            case .http(let code): return "Returned HTTP \(code)"
            case .badResponse: return "Unexpected response"
            }
        }
    }

    /// Safari's UA. Google refuses OAuth to anything it recognises as an
    /// embedded webview, and Cloudflare scores an unfamiliar UA down.
    static let userAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_5) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15"

    /// The persistent cookie jar, shared by every service and by the sign-in
    /// sheets. Cookies are domain-scoped, so the sites don't collide.
    static var store: WKWebsiteDataStore { .default() }

    let service: WebService

    private static let navigationTimeout: TimeInterval = 20
    private static let fetchTimeoutMS = 15_000

    private var webView: WKWebView?
    private var hostWindow: NSWindow?
    private var pendingLoad: Pending?
    /// Tail of the request chain, so concurrent callers queue instead of failing.
    private var pending: Task<(status: Int, body: String), Error>?

    private init(service: WebService) {
        self.service = service
        super.init()
    }

    var isConnected: Bool { WebConnection.isConnected(service.id) }

    // MARK: Requests

    /// Fetches a path from inside WebKit and returns the raw body, mapping an
    /// auth refusal to `needsLogin`.
    func json(path: String, headers: [String: String] = [:]) async throws -> Data {
        let (status, body) = try await request(path: path, headers: headers)
        switch status {
        case 200:
            WebConnection.mark(service.id, connected: true)
            return Data(body.utf8)
        case 401, 403:
            // Verified on claude.ai: a signed-out session answers 403 (not 401)
            // with a JSON error body. So 403 has to clear the connected flag, or
            // an expired session shows an error forever with nothing telling the
            // user to reconnect. A Cloudflare interstitial is the case that must
            // *not* clear it, and it's an HTML page rather than JSON.
            if Self.isSessionRejection(body) {
                WebConnection.mark(service.id, connected: false)
                throw Failure.needsLogin(service.displayName)
            }
            throw Failure.http(status)
        case -1:
            throw Failure.timedOut
        default:
            throw Failure.http(status)
        }
    }

    private static func isSessionRejection(_ body: String) -> Bool {
        let head = body.prefix(600).lowercased()
        if head.contains("<!doctype html") || head.contains("just a moment")
            || head.contains("cf-browser-verification") || head.contains("cf-chl") {
            return false  // Cloudflare challenge — the session may still be fine
        }
        return head.contains("account_session_invalid")
            || head.contains("permission_error")
            || head.contains("authentication_error")
            || head.contains("invalid authorization")
            // Anything else JSON-shaped at 401/403 is an auth refusal too; only
            // the HTML challenge above is the exception.
            || head.hasPrefix("{")
    }

    /// True when the store holds a session the site accepts right now.
    func verify() async -> Bool {
        guard let (status, body) = try? await request(path: service.verifyPath) else { return false }
        let ok = service.verify(status, body)
        WebConnection.mark(service.id, connected: ok)
        return ok
    }

    /// Drops the transport view so the next request re-navigates with whatever
    /// the store now holds. Called after a fresh sign-in or a pasted cookie.
    func reset() { teardown() }

    /// Status + body straight from the page, with no interpretation.
    ///
    /// Requests are chained rather than rejected when one is already in flight.
    /// Failing fast looked tidier but produced spurious errors in the case that
    /// matters most: a sign-in sheet's poll overlapping the refresh triggered by
    /// connecting, which surfaced as "no windows" plus whatever unrelated error
    /// the other code path happened to report.
    func request(path: String, headers: [String: String] = [:]) async throws -> (status: Int, body: String) {
        let previous = pending
        let task = Task<(status: Int, body: String), Error> { [weak self] in
            _ = await previous?.result
            guard let self else { throw Failure.busy }
            return try await self.perform(path: path, headers: headers)
        }
        // Kept after completion on purpose: it's the chain's tail, and awaiting
        // an already-finished task returns immediately.
        pending = task
        return try await task.value
    }

    private func perform(path: String, headers: [String: String]) async throws -> (status: Int, body: String) {
        let webView = try await readyWebView()

        // The abort controller is the real timeout here: `callAsyncJavaScript`
        // is not cancellable from Swift, so a hung fetch has to time itself out
        // in JS and return normally.
        let js = """
        const controller = new AbortController();
        const timer = setTimeout(() => controller.abort(), timeoutMS);
        try {
            const response = await fetch(path, {
                credentials: 'include',
                signal: controller.signal,
                headers: Object.assign({ 'Accept': 'application/json' }, extraHeaders),
            });
            return { status: response.status, body: await response.text() };
        } catch (error) {
            return { status: -1, body: String(error) };
        } finally {
            clearTimeout(timer);
        }
        """
        let arguments: [String: Any] = [
            "path": path,
            "timeoutMS": Self.fetchTimeoutMS,
            "extraHeaders": headers,
        ]
        let raw = try await webView.callAsyncJavaScript(
            js, arguments: arguments, in: nil, contentWorld: .page)

        guard let result = raw as? [String: Any],
              let status = result["status"] as? Int,
              let body = result["body"] as? String else {
            throw Failure.badResponse
        }
        return (status, body)
    }

    // MARK: Sign out / manual adopt

    func signOut() async {
        WebConnection.mark(service.id, connected: false)
        teardown()
        guard let host = service.origin.host else { return }
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        let records = await Self.store.dataRecords(ofTypes: types)
        let bare = host.replacingOccurrences(of: "www.", with: "")
        let ours = records.filter { $0.displayName.contains(bare) }
        guard !ours.isEmpty else { return }
        await Self.store.removeData(ofTypes: types, for: ours)
    }

    /// Injects a manually supplied session cookie into the persistent store.
    ///
    /// The escape hatch for anyone an identity provider refuses to sign in inside
    /// an embedded window. Pasting used to be useless because the cookie was
    /// replayed through URLSession; injected into WebKit it goes down the same
    /// working path as a real sign-in.
    func adopt(sessionCookie raw: String) async -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = service.sessionCookieName
        // Tolerate a bare value, `name=value`, or a whole cookie header.
        let value = trimmed
            .split(separator: ";")
            .compactMap { part -> String? in
                let pair = part.trimmingCharacters(in: .whitespaces)
                guard pair.hasPrefix("\(name)=") else { return nil }
                return String(pair.dropFirst(name.count + 1))
            }
            .first ?? trimmed
        guard !value.isEmpty, !value.contains(" "), let host = service.origin.host else { return false }

        guard let cookie = HTTPCookie(properties: [
            .domain: ".\(host)",
            .path: "/",
            .name: name,
            .value: value,
            .secure: "TRUE",
            .expires: Date().addingTimeInterval(60 * 60 * 24 * 365),
        ]) else { return false }

        await Self.store.httpCookieStore.setCookie(cookie)
        teardown()  // force a fresh navigation so the new cookie is used
        return await verify()
    }

    // MARK: Transport view

    private func readyWebView() async throws -> WKWebView {
        let webView = self.webView ?? makeWebView()
        self.webView = webView
        // Same-origin is required: requests use a relative path so the site's
        // own CORS rules never come into play.
        if webView.url?.host == service.origin.host, !webView.isLoading {
            return webView
        }
        try await load(webView, url: service.origin)
        return webView
    }

    private func makeWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = Self.store
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1024, height: 768),
                                configuration: config)
        webView.customUserAgent = Self.userAgent
        webView.navigationDelegate = self
        hostOffscreen(webView)
        return webView
    }

    /// WebKit throttles — and can suspend — content processes for views that
    /// aren't in a visible window, which stalls `callAsyncJavaScript`. Parking
    /// the view in a window that is visible but far offscreen keeps the process
    /// scheduled without ever showing anything.
    private func hostOffscreen(_ webView: WKWebView) {
        let window = NSWindow(contentRect: CGRect(x: -30_000, y: -30_000, width: 1024, height: 768),
                              styleMask: [.borderless],
                              backing: .buffered,
                              defer: false)
        window.isReleasedWhenClosed = false
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.alphaValue = 0.01
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) - 1)
        window.collectionBehavior = [.stationary, .ignoresCycle, .fullScreenNone]
        window.contentView = webView
        window.orderBack(nil)
        hostWindow = window
    }

    private func load(_ webView: WKWebView, url: URL) async throws {
        pendingLoad?.resume(throwing: Failure.busy)
        try await withCheckedThrowingContinuation { continuation in
            let pending = Pending(continuation)
            pendingLoad = pending
            webView.load(URLRequest(url: url))
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.navigationTimeout) { [weak self] in
                guard let self, self.pendingLoad === pending else { return }
                self.pendingLoad = nil
                pending.resume(throwing: Failure.timedOut)
            }
        }
    }

    private func teardown() {
        pendingLoad?.resume(throwing: Failure.timedOut)
        pendingLoad = nil
        webView?.navigationDelegate = nil
        webView = nil
        hostWindow?.contentView = nil
        hostWindow?.close()
        hostWindow = nil
    }

    /// One-shot continuation box. WebKit can report a navigation more than once
    /// (or never), and resuming a continuation twice traps.
    private final class Pending {
        private var continuation: CheckedContinuation<Void, Error>?

        init(_ continuation: CheckedContinuation<Void, Error>) {
            self.continuation = continuation
        }

        func resume(throwing error: Error? = nil) {
            guard let continuation else { return }
            self.continuation = nil
            if let error { continuation.resume(throwing: error) } else { continuation.resume() }
        }
    }
}

extension WebSession: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        pendingLoad?.resume()
        pendingLoad = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        pendingLoad?.resume(throwing: error)
        pendingLoad = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        pendingLoad?.resume(throwing: error)
        pendingLoad = nil
    }

    /// A dead content process leaves the view permanently blank; drop it so the
    /// next request rebuilds from scratch.
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        teardown()
    }
}
