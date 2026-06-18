import Foundation
import MoodleNativeCore
import MoodleNativeNetworking

public struct LmsForumPostThreadNode: Identifiable {
    public let post: LmsWebServiceClient.ForumPost
    public let children: [LmsForumPostThreadNode]

    public init(post: LmsWebServiceClient.ForumPost, children: [LmsForumPostThreadNode]) {
        self.post = post
        self.children = children
    }

    public var id: Int {
        post.id
    }
}

extension LmsWebServiceClient.ForumDiscussion {
    public var displayTitle: String {
        if subject.isEmpty == false {
            return subject
        }

        if name.isEmpty == false {
            return name
        }

        return "投稿"
    }

    public var previewText: String? {
        LmsHTMLTextFormatter.plainText(from: message).singleLineDisplayText
    }

    public var authorName: String {
        let trimmed = userFullName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "投稿者不明" : trimmed
    }

    public var modifiedAt: Date? {
        guard modifiedTimestamp > 0 else {
            return nil
        }

        return Date(timeIntervalSince1970: TimeInterval(modifiedTimestamp))
    }

    public var replyCount: Int {
        max(0, numberOfReplies)
    }

    public var unreadCount: Int {
        max(0, numberOfUnreadPosts)
    }
}
extension LmsWebServiceClient.ForumPost {
    public var createdAt: Date? {
        guard timeCreated > 0 else {
            return nil
        }

        return Date(timeIntervalSince1970: TimeInterval(timeCreated))
    }

    public var displaySubject: String? {
        let trimmed = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    public var bodyText: String? {
        LmsHTMLTextFormatter.plainText(from: message)
    }

    public var authorName: String {
        let trimmed = author.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "投稿者不明" : trimmed
    }

    public var isUnread: Bool {
        unread
    }

    public var modifiedAt: Date? {
        guard timeModified > 0 else {
            return createdAt
        }

        return Date(timeIntervalSince1970: TimeInterval(timeModified))
    }
}

extension Array where Element == LmsWebServiceClient.ForumPost {
    public func threadedPosts() -> [LmsForumPostThreadNode] {
        let sortedPosts = sorted { lhs, rhs in
            if lhs.timeCreated == rhs.timeCreated {
                return lhs.id < rhs.id
            }

            return lhs.timeCreated < rhs.timeCreated
        }

        let postsByID = Dictionary(uniqueKeysWithValues: sortedPosts.map { ($0.id, $0) })
        var childrenByParent: [Int: [LmsWebServiceClient.ForumPost]] = [:]
        var roots: [LmsWebServiceClient.ForumPost] = []

        for post in sortedPosts {
            if let parentID = post.parentID, postsByID[parentID] != nil {
                childrenByParent[parentID, default: []].append(post)
            } else {
                roots.append(post)
            }
        }

        func makeNode(for post: LmsWebServiceClient.ForumPost) -> LmsForumPostThreadNode {
            LmsForumPostThreadNode(
                post: post,
                children: (childrenByParent[post.id] ?? []).map(makeNode)
            )
        }

        return roots.map(makeNode)
    }
}

extension LmsWebServiceClient.ForumPostAttachment {
    public var url: URL? {
        fileURL.flatMap(URL.init(string:))
    }

    public var pathComponents: [String] {
        (filePath ?? "").lmsPathComponents
    }

    public var displayName: String {
        let trimmed = fileName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "添付ファイル" : trimmed
    }
}

extension Array where Element == LmsWebServiceClient.ForumPostAttachment {
    public var resourceTreeNodes: [LmsResourceTreeNode] {
        compactMap { attachment in
            guard let url = attachment.url else {
                return nil
            }

            return LmsResourceTreeFile(
                id: attachment.id,
                title: attachment.displayName,
                url: url,
                pathComponents: attachment.pathComponents
            )
        }
        .treeNodes()
    }
}

extension LmsWebServiceClient.ForumPostURLs {
    public var discussURL: URL? {
        discuss.flatMap(URL.init(string:))
    }
}

extension LmsWebServiceClient.ForumPostAuthorURLs {
    public var profileImageURL: URL? {
        profileImage.flatMap(URL.init(string:))
    }
}
