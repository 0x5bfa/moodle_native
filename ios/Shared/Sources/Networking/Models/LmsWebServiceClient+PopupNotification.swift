import Foundation

extension LmsWebServiceClient {
    public struct PopupNotification: Decodable, Equatable, Identifiable, Sendable {
        public let id: Int
        public let userIDFrom: Int?
        public let userIDTo: Int?
        public let subject: String
        public let shortenedSubject: String?
        public let text: String?
        public let fullMessage: String?
        public let fullMessageFormat: Int?
        public let fullMessageHTML: String?
        public let smallMessage: String?
        public let contextURL: String?
        public let contextURLName: String?
        public let timeCreated: Int
        public let timeRead: Int?
        public let read: Bool
        public let deleted: Bool
        public let iconURL: String?
        public let component: String?
        public let eventType: String?
        public let customData: String?

        private enum CodingKeys: String, CodingKey {
            case id
            case userIDFrom = "useridfrom"
            case userIDTo = "useridto"
            case subject
            case shortenedSubject = "shortenedsubject"
            case text
            case fullMessage = "fullmessage"
            case fullMessageFormat = "fullmessageformat"
            case fullMessageHTML = "fullmessagehtml"
            case smallMessage = "smallmessage"
            case contextURL = "contexturl"
            case contextURLName = "contexturlname"
            case timeCreated = "timecreated"
            case timeRead = "timeread"
            case read
            case deleted
            case iconURL = "iconurl"
            case component
            case eventType = "eventtype"
            case customData = "customdata"
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(Int.self, forKey: .id)
            userIDFrom = try container.decodeIfPresent(Int.self, forKey: .userIDFrom)
            userIDTo = try container.decodeIfPresent(Int.self, forKey: .userIDTo)
            subject = try container.decode(String.self, forKey: .subject)
            shortenedSubject = try container.decodeIfPresent(String.self, forKey: .shortenedSubject)
            text = try container.decodeIfPresent(String.self, forKey: .text)
            fullMessage = try container.decodeIfPresent(String.self, forKey: .fullMessage)
            fullMessageFormat = try container.decodeIfPresent(Int.self, forKey: .fullMessageFormat)
            fullMessageHTML = try container.decodeIfPresent(String.self, forKey: .fullMessageHTML)
            smallMessage = try container.decodeIfPresent(String.self, forKey: .smallMessage)
            contextURL = try container.decodeIfPresent(String.self, forKey: .contextURL)
            contextURLName = try container.decodeIfPresent(String.self, forKey: .contextURLName)
            timeCreated = try container.decode(Int.self, forKey: .timeCreated)
            timeRead = try container.decodeIfPresent(Int.self, forKey: .timeRead)
            read = try container.decodeBoolishIfPresent(forKey: .read) ?? false
            deleted = try container.decodeBoolishIfPresent(forKey: .deleted) ?? false
            iconURL = try container.decodeIfPresent(String.self, forKey: .iconURL)
            component = try container.decodeIfPresent(String.self, forKey: .component)
            eventType = try container.decodeIfPresent(String.self, forKey: .eventType)
            customData = try container.decodeIfPresent(String.self, forKey: .customData)
        }
    }

    public struct PopupNotificationsResponse: Decodable, Equatable, Sendable {
        public let notifications: [PopupNotification]

        private enum CodingKeys: String, CodingKey {
            case notifications
        }
    }
}
