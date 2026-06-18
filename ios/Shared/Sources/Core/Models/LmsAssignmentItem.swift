import Foundation

public struct LmsAssignmentItem: Identifiable, Equatable, Sendable {
    public enum DueBucket: CaseIterable, Sendable {
        case overdue
        case upcoming
        case undated

        public var sectionTitle: String {
            switch self {
            case .overdue:
                return "期限切れ"
            case .upcoming:
                return "これからの課題"
            case .undated:
                return "期限未設定"
            }
        }
    }

    public let id: Int
    public let courseID: Int
    public let courseModuleID: Int
    public let courseTitle: String
    public let courseCode: String?
    public let courseShortName: String
    public let title: String
    public let introPreview: String?
    public let dueDate: Date?
    public let allowsSubmissionsFromDate: Date?
    public let cutoffDate: Date?
    public let updatedAt: Date?
    public let submissionDrafts: Bool?
    public let requiresSubmissionStatement: Bool?
    public let submissionStatement: String?
    public let timeLimit: Int?
    public let enabledSubmissionPluginTypes: [String]?
    public let onlineTextWordLimit: Int?

    public init(
        id: Int,
        courseID: Int,
        courseModuleID: Int,
        courseTitle: String,
        courseCode: String? = nil,
        courseShortName: String,
        title: String,
        introPreview: String?,
        dueDate: Date?,
        allowsSubmissionsFromDate: Date?,
        cutoffDate: Date?,
        updatedAt: Date?,
        submissionDrafts: Bool? = nil,
        requiresSubmissionStatement: Bool? = nil,
        submissionStatement: String? = nil,
        timeLimit: Int? = nil,
        enabledSubmissionPluginTypes: [String]? = nil,
        onlineTextWordLimit: Int? = nil
    ) {
        self.id = id
        self.courseID = courseID
        self.courseModuleID = courseModuleID
        self.courseTitle = courseTitle
        self.courseCode = courseCode
        self.courseShortName = courseShortName
        self.title = title
        self.introPreview = introPreview.singleLineDisplayText
        self.dueDate = dueDate
        self.allowsSubmissionsFromDate = allowsSubmissionsFromDate
        self.cutoffDate = cutoffDate
        self.updatedAt = updatedAt
        self.submissionDrafts = submissionDrafts
        self.requiresSubmissionStatement = requiresSubmissionStatement
        self.submissionStatement = submissionStatement
        self.timeLimit = timeLimit
        self.enabledSubmissionPluginTypes = enabledSubmissionPluginTypes
        self.onlineTextWordLimit = onlineTextWordLimit
    }

    public func dueBucket(now: Date = .now) -> DueBucket {
        guard let dueDate else {
            return .undated
        }

        if dueDate < now {
            return .overdue
        }

        return .upcoming
    }
}
