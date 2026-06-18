import Foundation
import MoodleNativeCore
import MoodleNativeNetworking

public struct LmsAssignmentReference: Hashable, Identifiable, Sendable {
    public let assignmentID: Int
    public let courseModuleID: Int
    public let courseID: Int?
    public let courseTitle: String?
    public let courseShortName: String?
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
    public let detailURL: URL?
    public let completionRequirements: [LmsModuleCompletionRequirement]

    public init(
        assignmentID: Int,
        courseModuleID: Int,
        courseID: Int?,
        courseTitle: String?,
        courseShortName: String?,
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
        onlineTextWordLimit: Int? = nil,
        detailURL: URL?,
        completionRequirements: [LmsModuleCompletionRequirement]
    ) {
        self.assignmentID = assignmentID
        self.courseModuleID = courseModuleID
        self.courseID = courseID
        self.courseTitle = courseTitle
        self.courseShortName = courseShortName
        self.title = title
        self.introPreview = introPreview
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
        self.detailURL = detailURL
        self.completionRequirements = completionRequirements
    }

    public var id: Int {
        assignmentID
    }

    public var displayCourseTitle: String? {
        guard let courseTitle else {
            return nil
        }

        let trimmed = courseTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    public var hasOverviewDetails: Bool {
        if allowsSubmissionsFromDate != nil || dueDate != nil || cutoffDate != nil {
            return true
        }

        guard let introPreview else {
            return false
        }

        return introPreview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    public func merging(courseModule: LmsWebServiceClient.CourseModule) -> LmsAssignmentReference {
        let mergedDetailURL = detailURL ?? courseModule.url.flatMap(URL.init(string:))
        let mergedRequirements =
            completionRequirements.isEmpty
            ? courseModule.completionData?.requirements ?? []
            : completionRequirements

        return LmsAssignmentReference(
            assignmentID: assignmentID,
            courseModuleID: courseModuleID,
            courseID: courseID,
            courseTitle: courseTitle,
            courseShortName: courseShortName,
            title: title,
            introPreview: introPreview,
            dueDate: dueDate,
            allowsSubmissionsFromDate: allowsSubmissionsFromDate,
            cutoffDate: cutoffDate,
            updatedAt: updatedAt,
            submissionDrafts: submissionDrafts,
            requiresSubmissionStatement: requiresSubmissionStatement,
            submissionStatement: submissionStatement,
            timeLimit: timeLimit,
            enabledSubmissionPluginTypes: enabledSubmissionPluginTypes,
            onlineTextWordLimit: onlineTextWordLimit,
            detailURL: mergedDetailURL,
            completionRequirements: mergedRequirements
        )
    }
}

public extension LmsAssignmentItem {
    func reference(siteURL: String) -> LmsAssignmentReference {
        LmsAssignmentReference(
            assignmentID: id,
            courseModuleID: courseModuleID,
            courseID: courseID,
            courseTitle: courseTitle,
            courseShortName: courseShortName,
            title: title,
            introPreview: introPreview,
            dueDate: dueDate,
            allowsSubmissionsFromDate: allowsSubmissionsFromDate,
            cutoffDate: cutoffDate,
            updatedAt: updatedAt,
            submissionDrafts: submissionDrafts,
            requiresSubmissionStatement: requiresSubmissionStatement,
            submissionStatement: submissionStatement,
            timeLimit: timeLimit,
            enabledSubmissionPluginTypes: enabledSubmissionPluginTypes,
            onlineTextWordLimit: onlineTextWordLimit,
            detailURL: URL.assignmentDetail(baseSiteURL: siteURL, courseModuleID: courseModuleID),
            completionRequirements: []
        )
    }
}

extension URL {
    fileprivate static func assignmentDetail(baseSiteURL: String, courseModuleID: Int) -> URL? {
        guard var components = URLComponents(string: baseSiteURL) else {
            return nil
        }

        components.path = "/mod/assign/view.php"
        components.queryItems = [URLQueryItem(name: "id", value: String(courseModuleID))]
        return components.url
    }
}
