import SwiftUI
import WebKit

@MainActor final class BrowserModel: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    @Published private(set) var webView: WKWebView?
    @Published private(set) var accountID: UUID?
    @Published private(set) var loading = false
    @Published var popup: WKWebView?
    @Published var message: String?
    private var observer: NSKeyValueObservation?

    func open(_ account: StudioAccount) {
        guard accountID != account.id else { return }
        closePopup()
        webView?.stopLoading()
        webView?.navigationDelegate = nil; webView?.uiDelegate = nil
        observer = nil
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore(forIdentifier: account.id)
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        let next = WKWebView(frame: .zero, configuration: configuration)
        next.navigationDelegate = self; next.uiDelegate = self
        next.allowsBackForwardNavigationGestures = true
        observer = next.observe(\.isLoading, options: [.new]) { [weak self] view, _ in
            Task { @MainActor in self?.loading = view.isLoading }
        }
        accountID = account.id
        webView = next
        navigate("https://www.instagram.com/")
    }

    func navigate(_ value: String) {
        guard let view = webView, let url = URL(string: value), url.scheme == "https" else { return }
        view.load(URLRequest(url: url))
    }

    func openPost(_ value: String) {
        guard webView != nil else { message = "Choose an account first."; return }
        do { webView?.load(URLRequest(url: try InstagramLink.post(value))) }
        catch { message = error.localizedDescription }
    }

    func closePopup() {
        popup?.stopLoading(); popup?.navigationDelegate = nil; popup?.uiDelegate = nil
        popup = nil
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let scheme = navigationAction.request.url?.scheme?.lowercased() ?? ""
        if ["https", "about", "blob"].contains(scheme) {
            // Loading a tapped top-level link ourselves keeps universal links
            // in this web view instead of handing them to an installed app.
            if navigationAction.navigationType == .linkActivated,
               navigationAction.targetFrame?.isMainFrame != false {
                decisionHandler(.cancel)
                webView.load(navigationAction.request)
                return
            }
            decisionHandler(.allow)
        } else {
            if navigationAction.targetFrame?.isMainFrame != false {
                message = "This link requires another app. Use Instagram's web controls here instead."
            }
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard popup == nil else { message = "Close the current login window before opening another."; return nil }
        guard let scheme = navigationAction.request.url?.scheme?.lowercased(), ["https", "about"].contains(scheme) else {
            message = "External app links stay closed. Continue using the web page inside this app."; return nil
        }
        configuration.websiteDataStore = webView.configuration.websiteDataStore
        let next = WKWebView(frame: .zero, configuration: configuration)
        next.navigationDelegate = self; next.uiDelegate = self
        popup = next
        return next
    }

    func webViewDidClose(_ webView: WKWebView) { if popup === webView { closePopup() } }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        message = "Page did not load: \(error.localizedDescription)"
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        message = "The browser stopped, possibly due to memory pressure. Tap Reload to reopen the page."
    }
}

struct EmbeddedBrowser: UIViewRepresentable {
    let view: WKWebView
    func makeUIView(context: Context) -> WKWebView { view }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
