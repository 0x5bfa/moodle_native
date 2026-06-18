import Foundation
import MoodleNativeCore
import MoodleNativeNetworking
import SwiftUI

extension LmsAssignmentItem.DueBucket {
    var rowBadgeTitle: String? {
        switch self {
        case .upcoming:
            return nil
        case .overdue, .undated:
            return badgeTitle
        }
    }

    var badgeTitle: String {
        switch self {
        case .overdue:
            return String(localized: "assignment.badge.overdue")
        case .upcoming:
            return String(localized: "assignment.badge.upcoming")
        case .undated:
            return String(localized: "assignment.badge.undated")
        }
    }

    var badgeForegroundColor: Color {
        switch self {
        case .overdue:
            return .red
        case .upcoming:
            return .accentColor
        case .undated:
            return .secondary
        }
    }

    var badgeBackgroundColor: Color {
        switch self {
        case .overdue:
            return .red.opacity(0.12)
        case .upcoming:
            return .accentColor.opacity(0.12)
        case .undated:
            return .secondary.opacity(0.12)
        }
    }
}

extension LmsAssignmentItem {
    func dueDateLine(
        relativeTo now: Date = .now,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        guard let dueDate else {
            return ""
        }

        return "\(Self.relativeDateText(for: dueDate, relativeTo: now, locale: locale))"
    }

    private static func relativeDateText(
        for date: Date,
        relativeTo now: Date,
        locale: Locale
    ) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: now)
    }
}

extension LmsWebServiceClient.AssignmentSubmissionStatus {
    nonisolated var hasVisibleDetails: Bool {
        lastAttempt != nil
            || feedback?.hasVisibleContent == true
            || previousAttempts.contains(where: { $0.hasVisibleContent })
            || assignmentData?.hasVisibleContent == true
            || gradingSummary != nil
    }

    nonisolated var hasCompletedSubmission: Bool {
        lastAttempt?.hasCompletedSubmission == true
    }
}

extension LmsWebServiceClient.AssignmentGradingSummary {
    var hasVisibleContent: Bool {
        participantCount > 0
            || submissionDraftsCount > 0
            || submissionsSubmittedCount > 0
            || submissionsNeedGradingCount > 0
            || warningOfUngroupedUsers.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
}

extension LmsWebServiceClient.AssignmentLastAttempt {
    nonisolated var hasCompletedSubmission: Bool {
        submission?.isSubmitted == true || teamSubmission?.isSubmitted == true
    }

    var extensionDueAt: Date? {
        guard extensionDueDate > 0 else {
            return nil
        }

        return Date(timeIntervalSince1970: TimeInterval(extensionDueDate))
    }

    var gradingStatusDisplayName: String? {
        Self.displayName(for: gradingStatus)
    }

    private static func displayName(for status: String) -> String? {
        let trimmedStatus = status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch trimmedStatus {
        case "":
            return nil
        case "graded":
            return String(localized: "assignment.status.graded")
        case "notmarked":
            return String(localized: "assignment.status.notMarked")
        case "released":
            return String(localized: "assignment.status.released")
        case "inmarking":
            return String(localized: "assignment.status.inMarking")
        case "notsubmitted":
            return String(localized: "assignment.status.notSubmitted")
        default:
            return status.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}

extension LmsWebServiceClient.AssignmentSubmission {
    private var normalizedStatus: String {
        status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    nonisolated var isSubmitted: Bool {
        status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "submitted"
    }

    var isNew: Bool {
        normalizedStatus.isEmpty || normalizedStatus == "new"
    }

    var isReopened: Bool {
        normalizedStatus == "reopened"
    }

    var isExistingSubmissionForEditing: Bool {
        isNew == false && isReopened == false
    }

    var createdAt: Date? {
        guard timeCreated > 0 else {
            return nil
        }

        return Date(timeIntervalSince1970: TimeInterval(timeCreated))
    }

    var modifiedAt: Date? {
        guard timeModified > 0 else {
            return nil
        }

        return Date(timeIntervalSince1970: TimeInterval(timeModified))
    }

    var startedAt: Date? {
        guard let timeStarted, timeStarted > 0 else {
            return nil
        }

        return Date(timeIntervalSince1970: TimeInterval(timeStarted))
    }

    var statusDisplayName: String {
        switch normalizedStatus {
        case "submitted":
            return String(localized: "assignment.status.submitted")
        case "draft":
            return String(localized: "assignment.status.draft")
        case "new":
            return String(localized: "assignment.status.notSubmitted")
        case "reopened":
            return String(localized: "assignment.status.reopened")
        default:
            let fallback = status.trimmingCharacters(in: .whitespacesAndNewlines)
            return fallback.isEmpty ? String(localized: "assignment.status.notSubmitted") : fallback
        }
    }

    var gradingStatusDisplayName: String? {
        let trimmedStatus = gradingStatus?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch trimmedStatus {
        case nil, "":
            return nil
        case "graded":
            return String(localized: "assignment.status.graded")
        case "notmarked":
            return String(localized: "assignment.status.notMarked")
        case "released":
            return String(localized: "assignment.status.released")
        case "inmarking":
            return String(localized: "assignment.status.inMarking")
        default:
            return gradingStatus?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    var hasVisibleContent: Bool {
        plugins.contains(where: \.hasVisibleContent)
    }

    var submissionFiles: [LmsWebServiceClient.AssignmentFile] {
        plugins
            .filter { $0.type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "file" }
            .flatMap(\.fileAreas)
            .flatMap(\.files)
    }

    var onlineTextEditorField: LmsWebServiceClient.AssignmentPluginEditorField? {
        plugins
            .first { $0.type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "onlinetext" }?
            .editorFields
            .first
    }

    var canEditAsSupportedSubmission: Bool {
        let pluginTypes = Set(
            plugins.map { $0.type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        )
        return pluginTypes.intersection(["file", "onlinetext"]).isEmpty == false
            && pluginTypes.subtracting(["file", "onlinetext", "comments"]).isEmpty
    }
}

extension LmsWebServiceClient.AssignmentFeedback {
    nonisolated var displayGrade: String? {
        let candidates = [
            gradeForDisplay,
            grade?.gradeForDisplay,
            grade?.grade,
        ]

        return
            candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { $0.isEmpty == false })
    }

    nonisolated var gradedAt: Date? {
        guard let gradedDate, gradedDate > 0 else {
            return nil
        }

        return Date(timeIntervalSince1970: TimeInterval(gradedDate))
    }

    nonisolated var hasVisibleContent: Bool {
        displayGrade != nil || gradedAt != nil || plugins.contains(where: { $0.hasVisibleContent })
    }
}

extension LmsWebServiceClient.AssignmentPreviousAttempt {
    nonisolated var hasVisibleContent: Bool {
        submission != nil || grade != nil || feedbackPlugins.contains(where: { $0.hasVisibleContent })
    }
}

extension LmsWebServiceClient.AssignmentData {
    nonisolated var activityText: String? {
        LmsHTMLTextFormatter.plainText(from: activity)
    }

    nonisolated var hasVisibleContent: Bool {
        attachments?.hasVisibleContent == true
    }
}

extension LmsWebServiceClient.AssignmentDataAttachments {
    nonisolated var hasVisibleContent: Bool {
        intro.isEmpty == false || activity.isEmpty == false
    }
}

extension LmsWebServiceClient.AssignmentPlugin {
    var displayName: String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty == false {
            return trimmedName
        }

        let trimmedType = type.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedType.isEmpty ? String(localized: "assignment.plugin.details") : trimmedType
    }

    nonisolated var hasVisibleContent: Bool {
        fileAreas.contains(where: { $0.files.isEmpty == false })
            || editorFields.contains(where: { $0.displayText != nil })
    }
}

extension LmsWebServiceClient.AssignmentPluginFileArea {
    var displayName: String {
        switch area.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "submission_files":
            return String(localized: "assignment.fileArea.submissionFiles")
        case "intro":
            return String(localized: "assignment.fileArea.intro")
        case "activity":
            return String(localized: "assignment.fileArea.activity")
        case "files":
            return String(localized: "common.attachment")
        default:
            let trimmedArea = area.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedArea.isEmpty ? String(localized: "common.file") : trimmedArea
        }
    }
}

extension LmsWebServiceClient.AssignmentPluginEditorField {
    nonisolated var displayDescription: String? {
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedDescription.isEmpty ? nil : trimmedDescription
    }

    nonisolated var displayText: String? {
        LmsHTMLTextFormatter.plainText(from: text)
    }
}

extension LmsWebServiceClient.AssignmentGrade {
    var modifiedAt: Date? {
        guard timeModified > 0 else {
            return nil
        }

        return Date(timeIntervalSince1970: TimeInterval(timeModified))
    }
}

extension LmsWebServiceClient.AssignmentFile {
    var url: URL? {
        fileURL.flatMap(URL.init(string:))
    }

    var displayName: String {
        let trimmedName = fileName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedName.isEmpty ? String(localized: "common.attachment") : trimmedName
    }
}
