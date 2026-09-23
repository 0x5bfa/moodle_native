import SwiftUI
import WebKit

struct LmsMoodleAuthenticationWebView: UIViewRepresentable {
    let launchURL: URL
    let siteHost: String
    let retryTrigger: Int
    let onCallback: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            launchURL: launchURL,
            siteHost: siteHost,
            onCallback: onCallback
        )
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        context.coordinator.webView = webView
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if context.coordinator.didLoadInitialRequest == false {
            context.coordinator.didLoadInitialRequest = true
            webView.load(URLRequest(url: launchURL))
            return
        }

        if context.coordinator.lastRetryTrigger != retryTrigger {
            context.coordinator.lastRetryTrigger = retryTrigger
            context.coordinator.extractCallbackFromPage(in: webView, force: true)
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let launchURL: URL
        let siteHost: String
        let onCallback: (String) -> Void

        weak var webView: WKWebView?
        var didLoadInitialRequest = false
        var lastRetryTrigger = 0
        private var didCompleteCallback = false
        private var didScheduleLaunchRelaunch = false
        private var extractionAttempts = 0

        init(
            launchURL: URL,
            siteHost: String,
            onCallback: @escaping (String) -> Void
        ) {
            self.launchURL = launchURL
            self.siteHost = siteHost
            self.onCallback = onCallback
        }

        func handleCallbackURLString(_ rawURLString: String) {
            guard didCompleteCallback == false else {
                return
            }

            let trimmed = rawURLString.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else {
                return
            }

            didCompleteCallback = true
            Task { @MainActor in
                onCallback(trimmed)
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard didCompleteCallback == false else {
                decisionHandler(.cancel)
                return
            }

            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            if let rawCallback = rawCallbackURLString(from: url) {
                handleCallbackURLString(rawCallback)
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard didCompleteCallback == false, let url = webView.url else {
                return
            }

            if let rawCallback = rawCallbackURLString(from: url) {
                handleCallbackURLString(rawCallback)
                return
            }

            if url.path.contains("/admin/tool/mobile/launch.php") {
                scheduleCallbackExtraction(in: webView)
                return
            }

            if shouldRelaunchMobileLogin(from: url) {
                scheduleLaunchRelaunch(in: webView)
            }
        }

        func extractCallbackFromPage(in webView: WKWebView, force: Bool = false) {
            guard didCompleteCallback == false else {
                return
            }

            if force == false, extractionAttempts >= 6 {
                return
            }

            if force == false {
                extractionAttempts += 1
            }

            webView.evaluateJavaScript(Self.launchAppHrefJavaScript) { [weak self] result, _ in
                guard let self, self.didCompleteCallback == false else {
                    return
                }

                if let href = result as? String, href.isEmpty == false {
                    self.handleCallbackURLString(href)
                }
            }
        }

        private func scheduleCallbackExtraction(in webView: WKWebView) {
            let delays: [TimeInterval] = [0, 0.4, 1.0, 2.0, 3.5, 5.0]
            for delay in delays {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak webView] in
                    guard let self, let webView, self.didCompleteCallback == false else {
                        return
                    }

                    self.extractCallbackFromPage(in: webView)
                }
            }
        }

        private func shouldRelaunchMobileLogin(from url: URL) -> Bool {
            guard didScheduleLaunchRelaunch == false else {
                return false
            }

            guard let host = url.host?.lowercased(), host == siteHost.lowercased() else {
                return false
            }

            return url.path.contains("/admin/tool/mobile/launch.php") == false
        }

        private func scheduleLaunchRelaunch(in webView: WKWebView) {
            didScheduleLaunchRelaunch = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self, weak webView] in
                guard let self, let webView, self.didCompleteCallback == false else {
                    return
                }

                webView.load(URLRequest(url: self.launchURL))
            }
        }

        private func rawCallbackURLString(from url: URL) -> String? {
            let raw = url.absoluteString
            if raw.contains("://token=") {
                return raw
            }

            guard let scheme = url.scheme?.lowercased(), scheme == "moodleapp" || scheme == "moodlemobile" else {
                return nil
            }

            return raw
        }

        private static let launchAppHrefJavaScript = """
        (function() {
            var launchLink = document.getElementById('launchapp');
            if (launchLink) {
                var href = launchLink.getAttribute('href');
                if (href) { return href; }
            }

            var links = Array.from(document.querySelectorAll('a[href]'));
            for (var i = 0; i < links.length; i++) {
                var candidate = links[i].getAttribute('href');
                if (!candidate) { continue; }
                if (candidate.indexOf('://token=') !== -1) { return candidate; }
                if (candidate.indexOf('moodleapp://') === 0) { return candidate; }
                if (candidate.indexOf('moodlemobile://') === 0) { return candidate; }
            }

            var html = document.documentElement.innerHTML;
            var tokenMatch = html.match(/(?:moodleapp|moodlemobile):\\/\\/token=[^"'\\s<]+/);
            if (tokenMatch) { return tokenMatch[0]; }

            return null;
        })();
        """
    }
}
