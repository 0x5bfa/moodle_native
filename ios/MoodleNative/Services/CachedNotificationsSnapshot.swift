import Foundation
import MoodleNativeCore

struct CachedNotificationsSnapshot: Codable, Equatable, Sendable {
    let siteURL: String
    let authenticatedAt: Date
    let lastUpdatedAt: Date
    let unreadCount: Int
    let notifications: [CachedNotificationRecord]
}

struct CachedNotificationRecord: Codable, Equatable, Sendable {
    let id: String
    let lmsNotificationID: Int?
    let source: String
    let title: String
    let preview: String
    let plainBody: String?
    let fullMessage: String?
    let htmlBody: String?
    let receivedAt: Date
    let isUnread: Bool
    let isImportant: Bool
    let externalURL: URL?
    let component: String?
    let eventType: String?
    let contextName: String?

    init(notification: LmsNotificationItem) {
        id = notification.id
        lmsNotificationID = notification.lmsNotificationID
        source = notification.source
        title = notification.title
        preview = notification.preview
        plainBody = notification.plainBody
        fullMessage = notification.fullMessage
        htmlBody = notification.htmlBody
        receivedAt = notification.receivedAt
        isUnread = notification.isUnread
        isImportant = notification.isImportant
        externalURL = notification.externalURL
        component = notification.component
        eventType = notification.eventType
        contextName = notification.contextName
    }

    var notification: LmsNotificationItem {
        LmsNotificationItem(
            id: id,
            lmsNotificationID: lmsNotificationID,
            source: source,
            title: title,
            preview: preview,
            plainBody: plainBody,
            fullMessage: fullMessage,
            htmlBody: htmlBody,
            receivedAt: receivedAt,
            isUnread: isUnread,
            isImportant: isImportant,
            externalURL: externalURL,
            component: component,
            eventType: eventType,
            contextName: contextName
        )
    }
}
