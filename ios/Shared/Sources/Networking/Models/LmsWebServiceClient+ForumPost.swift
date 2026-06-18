import Foundation

extension LmsWebServiceClient {
    public struct ForumPostAuthorURLs: Decodable, Equatable, Sendable {
        public let profile: String?
        public let profileImage: String?

        private enum CodingKeys: String, CodingKey {
            case profile
            case profileImage = "profileimage"
        }
    }

    public struct ForumPostAuthor: Decodable, Equatable, Sendable {
        public let id: Int
        public let fullName: String
        public let isDeleted: Bool
        public let urls: ForumPostAuthorURLs

        private enum CodingKeys: String, CodingKey {
            case id
            case fullName = "fullname"
            case isDeleted = "isdeleted"
            case urls
        }

        public init(id: Int, fullName: String, isDeleted: Bool, urls: ForumPostAuthorURLs) {
            self.id = id
            self.fullName = fullName
            self.isDeleted = isDeleted
            self.urls = urls
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
            fullName = try container.decodeIfPresent(String.self, forKey: .fullName) ?? ""
            isDeleted = try container.decodeBoolishIfPresent(forKey: .isDeleted) ?? false
            urls =
                try container.decodeIfPresent(ForumPostAuthorURLs.self, forKey: .urls)
                ?? ForumPostAuthorURLs(
                    profile: nil,
                    profileImage: nil
                )
        }
    }

    public struct ForumPostURLs: Decodable, Equatable, Sendable {
        public let view: String?
        public let viewIsolated: String?
        public let discuss: String?

        private enum CodingKeys: String, CodingKey {
            case view
            case viewIsolated = "viewisolated"
            case discuss
        }
    }

    public struct ForumPostAttachment: Decodable, Equatable, Identifiable, Sendable {
        public let fileName: String?
        public let filePath: String?
        public var fileURL: String?
        public let mimeType: String?

        public var id: String {
            [fileName, filePath, fileURL, mimeType]
                .compactMap { $0 }
                .joined(separator: "|")
        }

        private enum CodingKeys: String, CodingKey {
            case fileName = "filename"
            case filePath = "filepath"
            case fileURL = "fileurl"
            case url
            case mimeType = "mimetype"
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            fileName = try container.decodeIfPresent(String.self, forKey: .fileName)
            filePath = try container.decodeIfPresent(String.self, forKey: .filePath)
            fileURL =
                try container.decodeIfPresent(String.self, forKey: .fileURL)
                ?? container.decodeIfPresent(String.self, forKey: .url)
            mimeType = try container.decodeIfPresent(String.self, forKey: .mimeType)
        }
    }

    public struct ForumPost: Decodable, Equatable, Identifiable, Sendable {
        public let id: Int
        public let discussionID: Int
        public let subject: String
        public let replySubject: String?
        public let message: String?
        public let timeCreated: Int
        public let timeModified: Int
        public let unread: Bool
        public let hasParent: Bool
        public let parentID: Int?
        public let isDeleted: Bool
        public let isPrivateReply: Bool
        public let author: ForumPostAuthor
        public let urls: ForumPostURLs
        public var attachments: [ForumPostAttachment]

        private enum CodingKeys: String, CodingKey {
            case id
            case discussionID = "discussionid"
            case subject
            case replySubject = "replysubject"
            case message
            case timeCreated = "timecreated"
            case timeModified = "timemodified"
            case unread
            case hasParent = "hasparent"
            case parentID = "parentid"
            case isDeleted = "isdeleted"
            case isPrivateReply = "isprivatereply"
            case author
            case urls
            case attachments
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(Int.self, forKey: .id)
            discussionID = try container.decodeIfPresent(Int.self, forKey: .discussionID) ?? 0
            subject = try container.decodeIfPresent(String.self, forKey: .subject) ?? ""
            replySubject = try container.decodeIfPresent(String.self, forKey: .replySubject)
            message = try container.decodeIfPresent(String.self, forKey: .message)
            timeCreated = try container.decodeIfPresent(Int.self, forKey: .timeCreated) ?? 0
            timeModified = try container.decodeIfPresent(Int.self, forKey: .timeModified) ?? 0
            unread = try container.decodeBoolishIfPresent(forKey: .unread) ?? false
            hasParent = try container.decodeBoolishIfPresent(forKey: .hasParent) ?? false
            parentID = try container.decodeIfPresent(Int.self, forKey: .parentID)
            isDeleted = try container.decodeBoolishIfPresent(forKey: .isDeleted) ?? false
            isPrivateReply = try container.decodeBoolishIfPresent(forKey: .isPrivateReply) ?? false
            author =
                try container.decodeIfPresent(ForumPostAuthor.self, forKey: .author)
                ?? ForumPostAuthor(
                    id: 0,
                    fullName: "",
                    isDeleted: false,
                    urls: ForumPostAuthorURLs(profile: nil, profileImage: nil)
                )
            urls =
                try container.decodeIfPresent(ForumPostURLs.self, forKey: .urls)
                ?? ForumPostURLs(
                    view: nil,
                    viewIsolated: nil,
                    discuss: nil
                )
            attachments =
                try container.decodeIfPresent([ForumPostAttachment].self, forKey: .attachments) ?? []
        }
    }

    public struct DiscussionPostsResponse: Decodable {
        public let posts: [ForumPost]
    }
}
