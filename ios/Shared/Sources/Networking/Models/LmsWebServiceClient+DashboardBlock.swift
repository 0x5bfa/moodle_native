import Foundation

extension LmsWebServiceClient {
    public struct DashboardBlocksResponse: Decodable, Equatable, Sendable {
        public let blocks: [DashboardBlock]
    }

    public struct DashboardBlock: Decodable, Equatable, Sendable {
        public struct Contents: Decodable, Equatable, Sendable {
            public struct File: Decodable, Equatable, Sendable {
                public let fileName: String?
                public let fileURL: String?

                private enum CodingKeys: String, CodingKey {
                    case fileName = "filename"
                    case fileURL = "fileurl"
                }
            }

            public let title: String?
            public let content: String?
            public let contentFormat: Int?
            public let footer: String?
            public let files: [File]?

            private enum CodingKeys: String, CodingKey {
                case title
                case content
                case contentFormat = "contentformat"
                case footer
                case files
            }
        }

        public struct Config: Decodable, Equatable, Sendable {
            public let name: String
            public let value: String?
            public let type: String?
        }

        public let instanceID: Int
        public let name: String
        public let region: String?
        public let positionID: Int?
        public let collapsible: Bool?
        public let dockable: Bool?
        public let weight: Int?
        public let visible: Bool?
        public let contents: Contents?
        public let configs: [Config]?

        private enum CodingKeys: String, CodingKey {
            case instanceID = "instanceid"
            case name
            case region
            case positionID = "positionid"
            case collapsible
            case dockable
            case weight
            case visible
            case contents
            case configs
        }
    }
}
