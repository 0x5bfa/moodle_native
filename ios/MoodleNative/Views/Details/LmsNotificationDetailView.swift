import Foundation
import MoodleNativeCore
import SwiftUI

struct LmsNotificationDetailView: View {
    let notification: NotificationListItem
    let markAsRead: @MainActor () async -> Void
    @Environment(\.openURL) private var openURL
    @AppStorage(AppSettings.ExternalLinks.preferInAppStorageKey)
    private var prefersInAppExternalLinks = AppSettings.ExternalLinks.preferInAppDefaultValue
    @State private var htmlContentHeight: CGFloat = 1

    init(
        notification: NotificationListItem,
        markAsRead: @escaping @MainActor () async -> Void = {}
    ) {
        self.notification = notification
        self.markAsRead = markAsRead
    }

    var body: some View {
        HtmlBodyView(
            htmlFragment: notificationHTMLFragment,
            onOpenURL: openInApp,
            isScrollEnabled: true,
            contentInsets: EdgeInsets(top: 12, leading: 16, bottom: 24, trailing: 16),
            contentHeight: $htmlContentHeight
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(String(localized: "notificationDetail.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: notification.id) {
            await markAsRead()
        }
        .toolbar {
            if let externalURL = notification.externalURL {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        openInApp(externalURL)
                    } label: {
                        Image(systemName: "safari")
                    }
                }
            }
        }
    }

    private func openInApp(_ url: URL) {
        openURL(url, prefersInApp: prefersInAppExternalLinks)
    }

    private var notificationHTMLFragment: String {
        if let htmlBody = notification.htmlBody?.trimmingCharacters(in: .whitespacesAndNewlines),
            htmlBody.isEmpty == false
        {
            return htmlBody
        }

        let bodyText =
            [
                notification.plainBody,
                notification.fullMessage,
                notification.preview,
            ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { $0.isEmpty == false }) ?? String(localized: "notificationDetail.emptyBody")

        return "<p>\(Self.escapedHTML(bodyText).replacingOccurrences(of: "\n", with: "<br>"))</p>"
    }

    private static func escapedHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

}

#Preview {
    NavigationStack {
        LmsNotificationDetailView(
            notification: NotificationListItem(
                lms: LmsNotificationItem(
                    id: "preview-notification",
                    lmsNotificationID: 1,
                    source: "Moodle",
                    title: String(localized: "debug.sampleNotification.title"),
                    preview: String(localized: "debug.sampleNotification.preview"),
                    plainBody: String(localized: "debug.sampleNotification.plainBody"),
                    fullMessage: String(localized: "debug.sampleNotification.fullMessage"),
                    htmlBody: nil,
                    receivedAt: .now,
                    isUnread: true,
                    isImportant: false,
                    externalURL: URL(string: "https://moodle.example.edu/my/"),
                    component: "mod_forum",
                    eventType: "posts",
                    contextName: String(localized: "debug.sampleNotification.contextName")
                )
            )
        )
    }
}
