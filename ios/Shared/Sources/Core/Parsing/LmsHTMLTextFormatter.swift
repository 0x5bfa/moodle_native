import Foundation

public enum LmsHTMLTextFormatter {
    public static func plainText(from html: String?) -> String? {
        guard let html, html.isEmpty == false else {
            return nil
        }

        let withParagraphBreaks =
            html
            .replacingOccurrences(
                of: "(?i)<\\s*br\\s*/?>|</p>|</div>|</li>|</h[1-6]>",
                with: "\n",
                options: .regularExpression
            )
            .replacingOccurrences(of: "(?i)<li[^>]*>", with: "• ", options: .regularExpression)

        let withoutTags = withParagraphBreaks.replacingOccurrences(
            of: "<[^>]+>",
            with: " ",
            options: .regularExpression
        )

        let decodedEntities =
            withoutTags
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")

        let normalizedLines =
            decodedEntities
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: .newlines)
            .map {
                $0.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { $0.isEmpty == false }

        guard normalizedLines.isEmpty == false else {
            return nil
        }

        return normalizedLines.joined(separator: "\n\n")
    }
}
