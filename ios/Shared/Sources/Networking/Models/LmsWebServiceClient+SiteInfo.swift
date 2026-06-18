import Foundation

extension LmsWebServiceClient {
    public struct SiteInfo: Decodable, Equatable, Sendable {
        public struct Function: Decodable, Equatable, Sendable {
            public let name: String
            public let version: String?
        }

        public struct AdvancedFeature: Decodable, Equatable, Sendable {
            public let name: String
            public let value: Int

            public var isEnabled: Bool {
                value != 0
            }
        }

        public let siteName: String
        public let siteURL: String
        public let userID: Int
        public let userName: String
        public let fullName: String
        public let firstName: String?
        public let lastName: String?
        public let functions: [Function]
        public let advancedFeatures: [AdvancedFeature]

        public func isAdvancedFeatureEnabled(_ name: String) -> Bool {
            advancedFeatures.first { $0.name == name }?.isEnabled ?? false
        }

        private enum CodingKeys: String, CodingKey {
            case siteName = "sitename"
            case siteURL = "siteurl"
            case userID = "userid"
            case userName = "username"
            case fullName = "fullname"
            case firstName = "firstname"
            case lastName = "lastname"
            case functions
            case advancedFeatures = "advancedfeatures"
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            siteName = try container.decode(String.self, forKey: .siteName)
            siteURL = try container.decode(String.self, forKey: .siteURL)
            userID = try container.decode(Int.self, forKey: .userID)
            userName = try container.decode(String.self, forKey: .userName)
            fullName = try container.decode(String.self, forKey: .fullName)
            firstName = try container.decodeIfPresent(String.self, forKey: .firstName)
            lastName = try container.decodeIfPresent(String.self, forKey: .lastName)
            functions = try container.decodeIfPresent([Function].self, forKey: .functions) ?? []
            advancedFeatures = try container.decodeIfPresent(
                [AdvancedFeature].self,
                forKey: .advancedFeatures
            ) ?? []
        }
    }
}
