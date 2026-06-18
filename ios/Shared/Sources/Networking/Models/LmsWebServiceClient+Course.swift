import Foundation

extension LmsWebServiceClient {
    public struct Course: Decodable, Equatable, Identifiable, Sendable {
        public let id: Int
        public let fullName: String
        public let displayName: String?
        public let shortName: String
        public let summary: String?
        public let courseImage: String?
        public let progress: Double?
        public let isFavorite: Bool?

        private enum CodingKeys: String, CodingKey {
            case id
            case fullName = "fullname"
            case displayName = "displayname"
            case shortName = "shortname"
            case summary
            case courseImage = "courseimage"
            case progress
            case isFavorite = "isfavourite"
        }
    }
}
