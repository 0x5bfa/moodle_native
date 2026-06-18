import Foundation
import MoodleNativeNetworking

public struct LmsForumReference: Hashable, Identifiable, Sendable {
    public let forumID: Int
    public let courseModuleID: Int
    public let title: String
    public let detailURL: URL?
    public let completionRequirements: [LmsModuleCompletionRequirement]

    public init(
        forumID: Int,
        courseModuleID: Int,
        title: String,
        detailURL: URL?,
        completionRequirements: [LmsModuleCompletionRequirement]
    ) {
        self.forumID = forumID
        self.courseModuleID = courseModuleID
        self.title = title
        self.detailURL = detailURL
        self.completionRequirements = completionRequirements
    }

    public var id: Int {
        forumID
    }
}
