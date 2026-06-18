import Foundation
import MoodleNativeCore
import MoodleNativeNetworking

extension LmsNotificationItem {
    public static func lms(from notification: LmsWebServiceClient.PopupNotification) -> LmsNotificationItem {
        let plainBody = [
            notification.fullMessageHTML,
            notification.fullMessage,
            notification.text,
            notification.smallMessage,
        ]
        .compactMap(LmsHTMLTextFormatter.plainText)
        .first

        let preview =
            [
                LmsHTMLTextFormatter.plainText(from: notification.smallMessage),
                plainBody,
            ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { $0.isEmpty == false }) ?? "通知本文を表示できます。"

        let title =
            [
                notification.subject,
                notification.shortenedSubject,
                notification.contextURLName,
            ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { $0.isEmpty == false }) ?? "LMS通知"

        return LmsNotificationItem(
            id: "lms-\(notification.id)",
            lmsNotificationID: notification.id,
            source: "Moodle",
            title: title,
            preview: preview,
            plainBody: plainBody,
            fullMessage: notification.fullMessage,
            htmlBody: sanitizedHTML(notification.fullMessageHTML),
            receivedAt: Date(timeIntervalSince1970: TimeInterval(notification.timeCreated)),
            isUnread: notification.read == false,
            isImportant: false,
            externalURL: notification.contextURL.flatMap(URL.init(string:)),
            component: notification.component,
            eventType: notification.eventType,
            contextName: trimmedValue(for: notification.contextURLName)
        )
    }

    public var bodyText: String {
        let candidates = [plainBody, preview]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        return candidates.first(where: { $0.isEmpty == false }) ?? "本文を表示できませんでした。"
    }

    public var htmlDocument: String? {
        guard let htmlBody = sanitizedHTML(htmlBody) else {
            return nil
        }

        return """
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
                  padding: 0;
                  font: -apple-system-body;
                  line-height: 1.6;
                  word-break: break-word;
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
            \(htmlBody)
            </body>
            </html>
            """
    }

    public var metadataItems: [(String, String)] {
        [
            ("状態", isUnread ? "未読" : "既読"),
            contextName.flatMap { ("リンク先", $0) },
            trimmedValue(for: component).flatMap { ("component", $0) },
            trimmedValue(for: eventType).flatMap { ("eventtype", $0) },
        ]
        .compactMap { $0 }
    }
}

private func sanitizedHTML(_ value: String?) -> String? {
    guard let trimmed = trimmedValue(for: value) else {
        return nil
    }

    return trimmed.range(of: "<[^>]+>", options: .regularExpression) == nil ? nil : trimmed
}

private func trimmedValue(for value: String?) -> String? {
    guard let value else {
        return nil
    }

    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}
