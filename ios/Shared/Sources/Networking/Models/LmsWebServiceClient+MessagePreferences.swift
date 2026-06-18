import Foundation

extension LmsWebServiceClient {
    public struct MessagePreferencesResponse: Decodable, Equatable, Sendable {
        public let preferences: NotificationPreferences
        public let blockNonContacts: Int
        public let enterToSend: Bool

        private enum CodingKeys: String, CodingKey {
            case preferences
            case blockNonContacts = "blocknoncontacts"
            case enterToSend = "entertosend"
        }
    }

    public struct MessagePreferences: Equatable, Sendable {
        public let notificationPreferences: NotificationPreferences
        public let blockNonContacts: Int
        public let enterToSend: Bool

        public init(
            notificationPreferences: NotificationPreferences,
            blockNonContacts: Int,
            enterToSend: Bool
        ) {
            self.notificationPreferences = notificationPreferences
            self.blockNonContacts = blockNonContacts
            self.enterToSend = enterToSend
        }
    }
}
