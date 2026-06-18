import Foundation

extension LmsWebServiceClient {
    public struct NotificationPreferencesResponse: Decodable, Equatable, Sendable {
        public var preferences: NotificationPreferences

        public init(preferences: NotificationPreferences) {
            self.preferences = preferences
        }
    }

    public struct NotificationPreferences: Decodable, Equatable, Sendable {
        public var userID: Int
        public var disableAll: Bool
        public var processors: [NotificationPreferencesProcessor]
        public var components: [NotificationPreferencesComponent]

        public var enableAll: Bool {
            get { disableAll == false }
            set { disableAll = newValue == false }
        }

        private enum CodingKeys: String, CodingKey {
            case userID = "userid"
            case disableAll = "disableall"
            case processors
            case components
        }

        public init(
            userID: Int,
            disableAll: Bool,
            processors: [NotificationPreferencesProcessor],
            components: [NotificationPreferencesComponent]
        ) {
            self.userID = userID
            self.disableAll = disableAll
            self.processors = processors
            self.components = components
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            userID = try container.decode(Int.self, forKey: .userID)
            disableAll = try container.decodeBoolishIfPresent(forKey: .disableAll) ?? false
            processors = try container.decodeIfPresent(
                [NotificationPreferencesProcessor].self,
                forKey: .processors
            ) ?? []
            components = try container.decodeIfPresent(
                [NotificationPreferencesComponent].self,
                forKey: .components
            ) ?? []
        }
    }

    public struct NotificationPreferencesProcessor: Decodable, Equatable, Identifiable, Sendable {
        public var displayName: String
        public var name: String
        public var hasSettings: Bool
        public var contextID: Int?
        public var userConfigured: Bool

        public var id: String { name }

        private enum CodingKeys: String, CodingKey {
            case displayName = "displayname"
            case name
            case hasSettings = "hassettings"
            case contextID = "contextid"
            case userConfigured = "userconfigured"
        }

        public init(
            displayName: String,
            name: String,
            hasSettings: Bool,
            contextID: Int?,
            userConfigured: Bool
        ) {
            self.displayName = displayName
            self.name = name
            self.hasSettings = hasSettings
            self.contextID = contextID
            self.userConfigured = userConfigured
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            displayName = try container.decode(String.self, forKey: .displayName)
            name = try container.decode(String.self, forKey: .name)
            hasSettings = try container.decodeBoolishIfPresent(forKey: .hasSettings) ?? false
            contextID = try container.decodeIfPresent(Int.self, forKey: .contextID)
            userConfigured = try container.decodeBoolishIfPresent(forKey: .userConfigured) ?? false
        }
    }

    public struct NotificationPreferencesComponent: Decodable, Equatable, Identifiable, Sendable {
        public var displayName: String
        public var description: String?
        public var notifications: [NotificationPreference]

        public var id: String { displayName }

        private enum CodingKeys: String, CodingKey {
            case displayName = "displayname"
            case description
            case notifications
        }

        public init(
            displayName: String,
            description: String? = nil,
            notifications: [NotificationPreference]
        ) {
            self.displayName = displayName
            self.description = description
            self.notifications = notifications
        }
    }

    public struct NotificationPreference: Decodable, Equatable, Identifiable, Sendable {
        public var displayName: String
        public var preferenceKey: String
        public var processors: [NotificationPreferenceProcessor]

        public var id: String { preferenceKey }

        private enum CodingKeys: String, CodingKey {
            case displayName = "displayname"
            case preferenceKey = "preferencekey"
            case processors
        }

        public init(
            displayName: String,
            preferenceKey: String,
            processors: [NotificationPreferenceProcessor]
        ) {
            self.displayName = displayName
            self.preferenceKey = preferenceKey
            self.processors = processors
        }

        public func processor(named name: String) -> NotificationPreferenceProcessor? {
            processors.first { $0.name == name }
        }
    }

    public struct NotificationPreferenceProcessor: Decodable, Equatable, Identifiable, Sendable {
        public var displayName: String
        public var name: String
        public var locked: Bool
        public var lockedMessage: String?
        public var userConfigured: Bool
        public var enabled: Bool?
        public var loggedIn: NotificationPreferenceProcessorState?
        public var loggedOff: NotificationPreferenceProcessorState?

        public var id: String { name }

        private enum CodingKeys: String, CodingKey {
            case displayName = "displayname"
            case name
            case locked
            case lockedMessage = "lockedmessage"
            case userConfigured = "userconfigured"
            case enabled
            case loggedIn = "loggedin"
            case loggedOff = "loggedoff"
        }

        public init(
            displayName: String,
            name: String,
            locked: Bool,
            lockedMessage: String?,
            userConfigured: Bool,
            enabled: Bool?,
            loggedIn: NotificationPreferenceProcessorState?,
            loggedOff: NotificationPreferenceProcessorState?
        ) {
            self.displayName = displayName
            self.name = name
            self.locked = locked
            self.lockedMessage = lockedMessage
            self.userConfigured = userConfigured
            self.enabled = enabled
            self.loggedIn = loggedIn
            self.loggedOff = loggedOff
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            displayName = try container.decode(String.self, forKey: .displayName)
            name = try container.decode(String.self, forKey: .name)
            locked = try container.decodeBoolishIfPresent(forKey: .locked) ?? false
            lockedMessage = try container.decodeIfPresent(String.self, forKey: .lockedMessage)
            userConfigured = try container.decodeBoolishIfPresent(forKey: .userConfigured) ?? false
            enabled = try container.decodeBoolishIfPresent(forKey: .enabled)
            loggedIn = try container.decodeIfPresent(
                NotificationPreferenceProcessorState.self,
                forKey: .loggedIn
            )
            loggedOff = try container.decodeIfPresent(
                NotificationPreferenceProcessorState.self,
                forKey: .loggedOff
            )
        }
    }

    public struct NotificationPreferenceProcessorState: Decodable, Equatable, Identifiable, Sendable {
        public var name: String
        public var displayName: String
        public var checked: Bool

        public var id: String { name }

        private enum CodingKeys: String, CodingKey {
            case name
            case displayName = "displayname"
            case checked
        }

        public init(name: String, displayName: String, checked: Bool) {
            self.name = name
            self.displayName = displayName
            self.checked = checked
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            displayName = try container.decode(String.self, forKey: .displayName)
            checked = try container.decodeBoolishIfPresent(forKey: .checked) ?? false
        }
    }
}
