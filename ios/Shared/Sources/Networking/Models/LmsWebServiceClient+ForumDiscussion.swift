import Foundation

extension LmsWebServiceClient {
    public struct ForumDiscussion: Decodable, Equatable, Identifiable, Sendable {
        public let rootPostID: Int
        public let discussionID: Int
        public let name: String
        public let subject: String
        public let message: String?
        public let userFullName: String
        public let numberOfReplies: Int
        public let numberOfUnreadPosts: Int
        public let isPinned: Bool
        public let isLocked: Bool
        public let modifiedTimestamp: Int
        public let canReply: Bool

        public var id: Int {
            discussionID
        }

        private enum CodingKeys: String, CodingKey {
            case rootPostID = "id"
            case discussionID = "discussion"
            case name
            case subject
            case message
            case userFullName = "userfullname"
            case numberOfReplies = "numreplies"
            case numberOfUnreadPosts = "numunread"
            case isPinned = "pinned"
            case isLocked = "locked"
            case modifiedTimestamp = "modified"
            case canReply = "canreply"
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            rootPostID = try container.decode(Int.self, forKey: .rootPostID)
            discussionID = try container.decode(Int.self, forKey: .discussionID)
            name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
            subject = try container.decodeIfPresent(String.self, forKey: .subject) ?? ""
            message = try container.decodeIfPresent(String.self, forKey: .message)
            userFullName = try container.decodeIfPresent(String.self, forKey: .userFullName) ?? ""
            numberOfReplies = try container.decodeIfPresent(Int.self, forKey: .numberOfReplies) ?? 0
            numberOfUnreadPosts =
                try container.decodeIfPresent(Int.self, forKey: .numberOfUnreadPosts) ?? 0
            isPinned = try container.decodeBoolishIfPresent(forKey: .isPinned) ?? false
            isLocked = try container.decodeBoolishIfPresent(forKey: .isLocked) ?? false
            modifiedTimestamp = try container.decodeIfPresent(Int.self, forKey: .modifiedTimestamp) ?? 0
            canReply = try container.decodeBoolishIfPresent(forKey: .canReply) ?? false
        }
    }

    public struct ForumDiscussionsResponse: Decodable {
        public let discussions: [ForumDiscussion]
    }
}
