import SwiftUI
import WebKit

struct HtmlBodyView: UIViewRepresentable {
    let htmlFragment: String
    let onOpenURL: (URL) -> Void
    var isScrollEnabled = false
    var contentInsets = EdgeInsets()
    @Binding var contentHeight: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(contentHeight: $contentHeight, onOpenURL: onOpenURL)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = isScrollEnabled
        webView.navigationDelegate = context.coordinator
        webView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.scrollView.isScrollEnabled = isScrollEnabled

        let document: String = Self.makeHTMLDocument(from: htmlFragment, contentInsets: contentInsets)
        guard context.coordinator.lastHTML != document else {
            return
        }

        context.coordinator.lastHTML = document
        webView.loadHTMLString(document, baseURL: Self.baseURL)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding private var contentHeight: CGFloat
        private let onOpenURL: (URL) -> Void
        var lastHTML: String?

        init(contentHeight: Binding<CGFloat>, onOpenURL: @escaping (URL) -> Void) {
            _contentHeight = contentHeight
            self.onOpenURL = onOpenURL
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("document.documentElement.scrollHeight") { result, _ in
                guard let number = result as? NSNumber else {
                    return
                }

                DispatchQueue.main.async {
                    self.contentHeight = max(CGFloat(truncating: number), 1)
                }
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard navigationAction.navigationType == .linkActivated,
                let url = navigationAction.request.url
            else {
                decisionHandler(.allow)
                return
            }

            onOpenURL(url)
            decisionHandler(.cancel)
        }
    }
}

extension HtmlBodyView {
    fileprivate static let baseURL = AppSettings.MoodleSite.resolvedURL()

    fileprivate static func makeHTMLDocument(from fragment: String, contentInsets: EdgeInsets) -> String {
        """
        <!doctype html>
        <html lang="ja">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <style>
            :root {
              color-scheme: light dark;
              font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
            }
            body {
              margin: 0;
              padding: \(contentInsets.top)px \(contentInsets.trailing)px \(contentInsets.bottom)px \(contentInsets.leading)px;
              box-sizing: border-box;
              font: -apple-system-body;
              line-height: 1.6;
              word-break: break-word;
            }
            a {
              color: inherit;
            }
            img, video, iframe {
              max-width: 100%;
              height: auto;
            }
            table {
              width: 100%;
              border-collapse: collapse;
            }
            th, td {
              border: 1px solid rgba(128, 128, 128, 0.25);
              padding: 6px 8px;
            }
            pre, code {
              white-space: pre-wrap;
              word-break: break-word;
            }
          </style>
        </head>
        <body>
        \(fragment)
        </body>
        </html>
        """
    }
}
