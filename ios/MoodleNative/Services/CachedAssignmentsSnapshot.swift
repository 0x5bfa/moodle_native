import Foundation
import MoodleNativeCore

struct CachedAssignmentsSnapshot: Codable, Equatable, Sendable {
    let siteURL: String
    let authenticatedAt: Date
    let lastUpdatedAt: Date
    let assignments: [CachedAssignmentRecord]
}

struct CachedAssignmentRecord: Codable, Equatable, Sendable {
    let id: Int
    let courseID: Int
    let courseModuleID: Int
    let courseTitle: String
    let courseCode: String?
    let courseShortName: String
    let title: String
    let introPreview: String?
    let dueDate: Date?
    let allowsSubmissionsFromDate: Date?
    let cutoffDate: Date?
    let updatedAt: Date?
    let submissionDrafts: Bool?
    let requiresSubmissionStatement: Bool?
    let submissionStatement: String?
    let timeLimit: Int?
    let enabledSubmissionPluginTypes: [String]?
    let onlineTextWordLimit: Int?

    init(assignment: LmsAssignmentItem) {
        id = assignment.id
        courseID = assignment.courseID
        courseModuleID = assignment.courseModuleID
        courseTitle = assignment.courseTitle
        courseCode = assignment.courseCode
        courseShortName = assignment.courseShortName
        title = assignment.title
        introPreview = assignment.introPreview
        dueDate = assignment.dueDate
        allowsSubmissionsFromDate = assignment.allowsSubmissionsFromDate
        cutoffDate = assignment.cutoffDate
        updatedAt = assignment.updatedAt
        submissionDrafts = assignment.submissionDrafts
        requiresSubmissionStatement = assignment.requiresSubmissionStatement
        submissionStatement = assignment.submissionStatement
        timeLimit = assignment.timeLimit
        enabledSubmissionPluginTypes = assignment.enabledSubmissionPluginTypes
        onlineTextWordLimit = assignment.onlineTextWordLimit
    }

    var assignment: LmsAssignmentItem {
        LmsAssignmentItem(
            id: id,
            courseID: courseID,
            courseModuleID: courseModuleID,
            courseTitle: courseTitle,
            courseCode: courseCode,
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
            onlineTextWordLimit: onlineTextWordLimit
        )
    }
}
