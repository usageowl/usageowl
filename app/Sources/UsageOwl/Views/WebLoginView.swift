import AppKit
import SwiftUI
import WebKit

/// One-click connect for any `WebService`: an embedded sign-in sheet.
///
/// The sheet writes into the same persistent WebKit store `WebSession` fetches
/// through, so signing in here is all it takes — no cookie is read, copied, or
/// stored anywhere, and the session survives quit/relaunch.
///
/// Success is confirmed by an authenticated request against the site, made
/// through the shared session rather than against this view — after a federated
/// sign-in the view itself can be parked on the identity provider's domain.
struct WebLoginView: View {
    @Environment(\.dismiss) private var dismiss
    let service: WebService
    let onConnected: () -> Void

    @State private var status: String
    @State private var checking = false
    /// Set when a cookie change lands mid-check. Without it the one event that
    /// matters — the session cookie appearing — can be dropped and never retried.
    @State private var recheckQueued = false
    @State private var host: String?
    @State private var showPaste = false
    @State private var pasted = ""
    @State private var pasteStatus: String?
    @State private var adopting = false
    @State private var webView: WKWebView?

    init(service: WebService, onConnected: @escaping () -> Void) {
        self.service = service
        self.onConnected = onConnected
        _status = State(initialValue:
            "Sign in below — the app connects itself once \(service.displayName) accepts the session.")
    }

    private var session: WebSession { WebSession.session(for: service) }

    /// Backstop for sign-in flows that set the cookie without a navigation the
    /// cookie observer reports.
    private let poll = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    /// True once sign-in has left the service's own domain for an identity
    /// provider. Google in particular often refuses to complete inside an
    /// embedded window, so this is where the escape hatches have to appear.
    private var offSite: Bool {
        guard let host, !host.isEmpty, let expected = service.origin.host else { return false }
        return host != expected && !host.hasSuffix(".\(expected)")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Connect \(service.displayName)").font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            .padding(12)
            Divider()

            LoginWebView(
                loginURL: service.loginURL,
                onReady: { webView = $0 },
                onChanged: { check(manual: false) },
                onHostChange: { host = $0 })

            .onReceive(poll) { _ in check(manual: false) }

            if offSite || showPaste {
                Divider()
                escapeHatches
            }

            HStack(spacing: 12) {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                if checking { ProgressView().controlSize(.small) }
                Button("Start over") { restart() }
                    .controlSize(.small)
                Button("Check now") { check(manual: true) }
                    .controlSize(.small)
                    .disabled(checking)
            }
            .padding(10)
        }
        .frame(width: 520, height: 700)
    }

    /// Shown once sign-in leaves the service's domain. Both routes end in the
    /// same place — a session in the shared WebKit store — so neither is a
    /// downgrade.
    private var escapeHatches: some View {
        VStack(alignment: .leading, spacing: 8) {
            if offSite {
                Label(
                    "Sign-in moved to \(host ?? "another site"). Google often refuses to finish inside an embedded window and leaves the page blank — either of these works instead.",
                    systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                Button("Use email code instead") {
                    restart()
                    status = "Choose the email option and enter the code \(service.displayName) sends you."
                }
                Button("Sign in in my browser") {
                    NSWorkspace.shared.open(service.origin)
                    showPaste = true
                }
                Spacer()
            }
            .controlSize(.small)

            if showPaste {
                Text("In that browser: DevTools → Application → Cookies → \(service.origin.host ?? "") → copy the `\(service.sessionCookieName)` value and paste it here.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    SecureField("\(service.sessionCookieName) value", text: $pasted)
                        .textFieldStyle(.roundedBorder)
                    Button("Use") { adopt() }
                        .disabled(adopting || pasted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if adopting { ProgressView().controlSize(.small) }
                }
                .controlSize(.small)
                if let pasteStatus {
                    Text(pasteStatus).font(.caption2).foregroundStyle(.orange)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
    }

    private func restart() {
        host = nil
        LoginWebView.closePopup()
        webView?.load(URLRequest(url: service.loginURL))
    }

    /// Confirms the session with the site rather than trusting the cookie jar.
    ///
    /// Serialised, and never drops a change that arrives while a check is in
    /// flight — that race is what left the first version saving nothing at all.
    private func check(manual: Bool) {
        guard !checking, !adopting else {
            recheckQueued = true
            return
        }
        checking = true
        Task {
            // The shared store, not this view's cookie jar: after a federated
            // sign-in the credential can land while the view sits on the
            // provider's domain.
            var worth = manual
            if !worth { worth = await Self.hasSessionCookie(service) }
            let signedIn = worth ? await session.verify() : false
            await MainActor.run {
                checking = false
                if signedIn { succeed(); return }
                if manual {
                    status = offSite
                        ? "\(service.displayName) hasn't accepted a session yet — the sign-in is still on \(host ?? "another site")."
                        : "Not signed in yet — finish sign-in, then try again."
                }
                if recheckQueued {
                    recheckQueued = false
                    check(manual: false)
                }
            }
        }
    }

    private func succeed() {
        WebConnection.mark(service.id, connected: true)
        session.reset()
        LoginWebView.closePopup()
        status = "Connected — \(service.displayName) stays signed in on this Mac."
        onConnected()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { dismiss() }
    }

    private func adopt() {
        adopting = true
        pasteStatus = nil
        status = "Checking pasted session…"
        let value = pasted
        Task {
            let ok = await session.adopt(sessionCookie: value)
            await MainActor.run {
                adopting = false
                if ok {
                    pasted = ""
                    succeed()
                } else {
                    pasteStatus = "\(service.displayName) rejected that value. Make sure it's the \(service.sessionCookieName) cookie's value, copied while signed in."
                    status = "Paste rejected."
                }
            }
        }
    }

    /// Cheap pre-filter so the poll isn't hitting the site every two seconds
    /// before a session exists.
    private static func hasSessionCookie(_ service: WebService) async -> Bool {
        guard let host = service.origin.host else { return false }
        let cookies = await WebSession.store.httpCookieStore.allCookies()
        return cookies.contains {
            $0.name == service.sessionCookieName
                && ($0.domain.hasSuffix(host) || host.hasSuffix($0.domain.trimmingCharacters(in: ["."])))
        }
    }
}

private struct LoginWebView: NSViewRepresentable {
    let loginURL: URL
    let onReady: (WKWebView) -> Void
    let onChanged: () -> Void
    let onHostChange: (String?) -> Void

    /// The OAuth popup lives outside SwiftUI's view tree, so it's tracked here.
    @MainActor private static var popupWindow: NSWindow?

    @MainActor
    static func closePopup() {
        popupWindow?.close()
        popupWindow = nil
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // The shared persistent store — signing in here is what authenticates
        // every later WebSession fetch.
        config.websiteDataStore = WebSession.store
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = WebSession.userAgent
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        config.websiteDataStore.httpCookieStore.add(context.coordinator)
        webView.load(URLRequest(url: loginURL))
        DispatchQueue.main.async { onReady(webView) }
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onChanged: onChanged, onHostChange: onHostChange)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKHTTPCookieStoreObserver {
        private let onChanged: () -> Void
        private let onHostChange: (String?) -> Void

        init(onChanged: @escaping () -> Void, onHostChange: @escaping (String?) -> Void) {
            self.onChanged = onChanged
            self.onHostChange = onHostChange
        }

        /// OAuth opens a popup. It has to become a *real* second web view built
        /// from the configuration WebKit hands us — returning nil and loading the
        /// URL into the parent (the obvious shortcut) destroys `window.opener`,
        /// so when the provider finishes it has nothing to hand the result back
        /// to and the flow dead-ends on a blank page with no session cookie.
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            let popup = WKWebView(frame: CGRect(x: 0, y: 0, width: 520, height: 640),
                                  configuration: configuration)
            popup.customUserAgent = WebSession.userAgent
            popup.navigationDelegate = self
            popup.uiDelegate = self

            let window = NSWindow(contentRect: popup.frame,
                                  styleMask: [.titled, .closable, .resizable],
                                  backing: .buffered,
                                  defer: false)
            window.title = "Sign in"
            window.isReleasedWhenClosed = false
            window.contentView = popup
            window.center()
            LoginWebView.popupWindow?.close()
            LoginWebView.popupWindow = window
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return popup
        }

        func webViewDidClose(_ webView: WKWebView) {
            LoginWebView.closePopup()
            DispatchQueue.main.async { self.onChanged() }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.onHostChange(webView.url?.host)
                self.onChanged()
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { self.onHostChange(webView.url?.host) }
        }

        /// A terminated content process leaves the sheet permanently white —
        /// reload instead of stranding the user on a blank page.
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            webView.reload()
        }

        /// The requirement is `cookiesDidChange(in:)` — a `cookiesDidChange(_:)`
        /// spelling compiles but never matches the selector, so the observer
        /// silently never fires.
        func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
            DispatchQueue.main.async { self.onChanged() }
        }
    }
}
