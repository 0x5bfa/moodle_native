import Foundation

extension LmsWebServiceClient {
    public struct UserPreferencesResponse: Decodable, Equatable, Sendable {
        public let preferences: [UserPreference]
    }

    public struct UserPreference: Decodable, Equatable, Identifiable, Sendable {
        public let name: String
        public let value: String?

        public var id: String { name }

        private enum CodingKeys: String, CodingKey {
            case name
            case value
        }

        public init(name: String, value: String?) {
            self.name = name
            self.value = value
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            value = try container.decodeStringishIfPresent(forKey: .value)
        }
    }
}
