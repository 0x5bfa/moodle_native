import Foundation

public struct LmsNotificationItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let lmsNotificationID: Int?
    public let source: String
    public let title: String
    public let preview: String
    public let plainBody: String?
    public let fullMessage: String?
    public let htmlBody: String?
    public let receivedAt: Date
    public let isUnread: Bool
    public let isImportant: Bool
    public let externalURL: URL?
    public let component: String?
    public let eventType: String?
    public let contextName: String?

    public init(
        id: String,
        lmsNotificationID: Int?,
        source: String,
        title: String,
        preview: String,
        plainBody: String?,
        fullMessage: String?,
        htmlBody: String?,
        receivedAt: Date,
        isUnread: Bool,
        isImportant: Bool,
        externalURL: URL?,
        component: String?,
        eventType: String?,
        contextName: String?
    ) {
        self.id = id
        self.lmsNotificationID = lmsNotificationID
        self.source = source
        self.title = title
        self.preview = preview.singleLineDisplayText
        self.plainBody = plainBody
        self.fullMessage = fullMessage
        self.htmlBody = htmlBody
        self.receivedAt = receivedAt
        self.isUnread = isUnread
        self.isImportant = isImportant
        self.externalURL = externalURL
        self.component = component
        self.eventType = eventType
        self.contextName = contextName
    }
}
