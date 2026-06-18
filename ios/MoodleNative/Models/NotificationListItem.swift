import Foundation
import MoodleNativeCore

struct NotificationListItem: Identifiable, Equatable, Sendable {
    enum Source: Equatable, Sendable {
        case lms
    }

    let id: String
    let source: Source
    let sourceTitle: String
    let title: String
    let preview: String
    let plainBody: String?
    let fullMessage: String?
    let htmlBody: String?
    let receivedAt: Date
    let isUnread: Bool
    let isImportant: Bool
    let externalURL: URL?
    let contextName: String?
    let lmsNotificationID: Int?

    init(lms notification: LmsNotificationItem) {
        id = notification.id
        source = .lms
        sourceTitle = notification.source
        title = notification.title
        preview = notification.preview
        plainBody = notification.plainBody
        fullMessage = notification.fullMessage
        htmlBody = notification.htmlBody
        receivedAt = notification.receivedAt
        isUnread = notification.isUnread
        isImportant = notification.isImportant
        externalURL = notification.externalURL
        contextName = notification.contextName
        lmsNotificationID = notification.lmsNotificationID
    }
}
