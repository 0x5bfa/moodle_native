import MoodleNativeCore
import MoodleNativeFeatures
import MoodleNativeNetworking
import SwiftUI

struct LmsAssignmentDetailView: View {
    @Environment(\.lmsSession) private var session
    @Environment(\.openURL) private var openURL
    @AppStorage(AppSettings.ExternalLinks.preferInAppStorageKey)
    private var prefersInAppExternalLinks = AppSettings.ExternalLinks.preferInAppDefaultValue

    let assignment: LmsAssignmentReference

    @State private var viewModel: AssignmentDetailViewModel
    @State private var submissionSheet: AssignmentSubmissionSheetContext?
    @State private var isConfirmingSubmission = false
    @State private var isConfirmingRemoval = false
    @State private var submissionUserIDToRemove: Int?
    @State private var acceptsSubmissionStatement = false

    init(
        assignment: LmsAssignmentReference,
        navigationPath: String = String(localized: "navigationPath.assignments.assignmentDetail")
    ) {
        self.assignment = assignment
        _viewModel = State(
            initialValue: AssignmentDetailViewModel(
                assignment: assignment,
                navigationPath: navigationPath
            )
        )
    }

    var body: some View {
        Group {
            if session == nil {
                ContentUnavailableView(
                    "assignments.loginRequired.title",
                    systemImage: "checklist.unchecked",
                    description: Text("assignmentDetail.loginRequired.description")
                )
            } else if viewModel.isLoading && viewModel.detail == nil {
                LoadingOverlayCard("assignmentDetail.loading")
            } else if let errorMessage = viewModel.errorMessage {
                ContentUnavailableView(
                    "assignmentDetail.unavailable.title",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else {
                List {
                    if let courseTitle = assignment.displayCourseTitle {
                        Section(courseTitle) {
                            if let allowsSubmissionsFromDate = assignment.allowsSubmissionsFromDate {
                                LabeledContent("assignmentDetail.overview.start", value: Self.dateFormatter.string(from: allowsSubmissionsFromDate))
                            }

                            if let dueDate = assignment.dueDate {
                                LabeledContent("assignmentDetail.overview.due", value: Self.dateFormatter.string(from: dueDate))
                            }

                            if let cutoffDate = assignment.cutoffDate {
                                LabeledContent("assignmentDetail.overview.cutoff", value: Self.dateFormatter.string(from: cutoffDate))
                            }

                            if let introPreview = assignment.introPreview,
                                introPreview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                            {
                                Text(introPreview)
                            }

                            if assignment.hasOverviewDetails == false {
                                Text("assignmentDetail.overview.empty")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // if viewModel.completionRequirements.isEmpty == false {
                    //         ForEach(viewModel.completionRequirements) { requirement in
                    //             LmsModuleCompletionRequirementRow(requirement: requirement)
                    //         }
                    //     }
                    // }

                    if let detail = viewModel.detail {
                        detailSections(detail)
                    }
                }
            }
        }
        .navigationTitle(assignment.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let detailURL = assignment.detailURL {
                    Button("common.openInMoodle", systemImage: "safari") {
                        openResource(detailURL)
                    }
                }
            }
        }
        .loadable(viewModel, session: session)
        .sheet(item: $submissionSheet) { context in
            LmsAssignmentSubmissionSheet(
                assignmentTitle: assignment.title,
                assignmentDescription: Self.preferredAssignmentDescription(
                    introPreview: assignment.introPreview,
                    activityText: viewModel.detail?.assignmentData?.activityText
                ),
                existingFiles: context.existingFiles,
                existingOnlineText: context.existingOnlineText,
                allowsFileSubmission: context.allowsFileSubmission,
                allowsOnlineTextSubmission: context.allowsOnlineTextSubmission,
                onlineTextWordLimit: assignment.onlineTextWordLimit,
                isEditing: context.isEditing,
                submissionDrafts: assignment.submissionDrafts ?? false,
                requiredSubmissionStatement: assignment.submissionDrafts == false
                    ? requiredSubmissionStatement
                    : nil,
                session: session,
                viewModel: viewModel
            )
        }
        .safeAreaBar(edge: .bottom) {
            if let lastAttempt = viewModel.detail?.lastAttempt {
                submissionActionPanel(lastAttempt)
            }
        }
    }

    @ViewBuilder
    private func detailSections(
        _ detail: LmsWebServiceClient.AssignmentSubmissionStatus
    ) -> some View {
        if let lastAttempt = detail.lastAttempt {
            lastAttemptSection(lastAttempt)

            if let submission = lastAttempt.submission, submission.hasVisibleContent {
                Section("assignmentDetail.submissionStatus.section") {
                    LmsAssignmentSubmissionContentView(submission: submission, onOpenResource: openResource)
                }
            }

            if let teamSubmission = lastAttempt.teamSubmission, teamSubmission.hasVisibleContent {
                Section("assignmentDetail.teamSubmission.section") {
                    LmsAssignmentSubmissionContentView(submission: teamSubmission, onOpenResource: openResource)
                }
            }
        }

        if let feedback = detail.feedback, feedback.hasVisibleContent {
            Section("assignmentDetail.feedback.section") {
                if let grade = feedback.displayGrade {
                    LabeledContent("assignmentDetail.grade", value: grade)
                }

                if let gradedAt = feedback.gradedAt {
                    LabeledContent("assignmentDetail.gradedAt", value: Self.dateFormatter.string(from: gradedAt))
                }

                if feedback.plugins.isEmpty == false {
                    LmsAssignmentPluginGroupView(plugins: feedback.plugins, onOpenResource: openResource)
                }
            }
        }

        if let attachments = detail.assignmentData?.attachments, attachments.hasVisibleContent {
            Section("assignmentDetail.materials.section") {
                if attachments.intro.isEmpty == false {
                    LmsAssignmentFileGroupView(
                        title: String(localized: "assignmentDetail.materials.intro"),
                        files: attachments.intro,
                        onOpenResource: openResource
                    )
                }

                if attachments.activity.isEmpty == false {
                    LmsAssignmentFileGroupView(
                        title: String(localized: "assignmentDetail.materials.activity"),
                        files: attachments.activity,
                        onOpenResource: openResource
                    )
                }
            }
        }

        if let gradingSummary = detail.gradingSummary, gradingSummary.hasVisibleContent {
            Section("assignmentDetail.gradingSummary.section") {
                LabeledContent(
                    "assignmentDetail.gradingSummary.participants",
                    value: Self.localizedPeopleCount(gradingSummary.participantCount)
                )
                LabeledContent(
                    "assignmentDetail.gradingSummary.submitted",
                    value: Self.localizedItemCount(gradingSummary.submissionsSubmittedCount)
                )
                LabeledContent(
                    "assignmentDetail.gradingSummary.drafts",
                    value: Self.localizedItemCount(gradingSummary.submissionDraftsCount)
                )
                LabeledContent(
                    "assignmentDetail.gradingSummary.needsGrading",
                    value: Self.localizedItemCount(gradingSummary.submissionsNeedGradingCount)
                )
            }
        }

        if detail.previousAttempts.isEmpty == false {
            Section("assignmentDetail.previousAttempts.section") {
                ForEach(detail.previousAttempts) { attempt in
                    LmsAssignmentAttemptRow(attempt: attempt, onOpenResource: openResource)
                }
            }
        }

        if detail.hasVisibleDetails == false && viewModel.errorMessage == nil {
            Section {
                Text("assignmentDetail.emptyDetails")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func lastAttemptSection(
        _ lastAttempt: LmsWebServiceClient.AssignmentLastAttempt
    ) -> some View {
        Section("assignmentDetail.lastAttempt.section") {
            if let submission = lastAttempt.submission {
                LabeledContent("assignmentDetail.individualSubmission", value: submission.statusDisplayName)

                if let modifiedAt = submission.modifiedAt {
                    LabeledContent("assignmentDetail.individualSubmission.modifiedAt", value: Self.dateFormatter.string(from: modifiedAt))
                }
            }

            if let teamSubmission = lastAttempt.teamSubmission {
                LabeledContent("assignmentDetail.teamSubmission", value: teamSubmission.statusDisplayName)

                if let modifiedAt = teamSubmission.modifiedAt {
                    LabeledContent("assignmentDetail.teamSubmission.modifiedAt", value: Self.dateFormatter.string(from: modifiedAt))
                }
            }

            submissionActions(lastAttempt)

            // if let gradingStatus = lastAttempt.gradingStatusDisplayName {
            // }

            if let extensionDueAt = lastAttempt.extensionDueAt {
                LabeledContent("assignmentDetail.extensionDueAt", value: Self.dateFormatter.string(from: extensionDueAt))
            }

            if lastAttempt.locked {
                Text("assignmentDetail.submission.locked")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func submissionActions(
        _ lastAttempt: LmsWebServiceClient.AssignmentLastAttempt
    ) -> some View {
        if let operation = viewModel.submissionOperation {
            if hasSubmissionActionPanel(for: lastAttempt) == false {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(operation.progressTitle)
                }
            }
        } else {
            let canEdit =
                lastAttempt.submissionsEnabled
                && lastAttempt.locked == false
                && lastAttempt.canEdit
            let canUseSubmissionConfiguration =
                assignment.submissionDrafts != nil && hasMissingSubmissionStatement == false
            let canEditInApp = supportsSubmissionEditing(lastAttempt)

            if assignment.submissionDrafts == true,
                canUseSubmissionConfiguration,
                lastAttempt.canSubmit,
                lastAttempt.locked == false
            {
                if let requiredSubmissionStatement {
                    Text(Self.statementText(requiredSubmissionStatement))
                        .font(.footnote)
                    Toggle("assignmentDetail.statement.accept", isOn: $acceptsSubmissionStatement)
                }

                Button("assignmentDetail.action.submitForGrading", systemImage: "paperplane") {
                    isConfirmingSubmission = true
                }
                .disabled(requiredSubmissionStatement != nil && acceptsSubmissionStatement == false)
                .confirmationDialog(
                    String(localized: "assignmentDetail.confirmSubmit.title"),
                    isPresented: $isConfirmingSubmission,
                    titleVisibility: .visible
                ) {
                    Button("assignmentDetail.action.submitForGrading") {
                        Task {
                            _ = await viewModel.submitForGrading(
                                acceptsSubmissionStatement: requiredSubmissionStatement == nil
                                    || acceptsSubmissionStatement,
                                session: session
                            )
                        }
                    }
                    Button("common.cancel", role: .cancel) {}
                } message: {
                    Text("assignmentDetail.confirmSubmit.message")
                }
            }

            if (canEdit || lastAttempt.canSubmit) && canUseSubmissionConfiguration == false {
                Text(submissionConfigurationMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if canEdit && canEditInApp == false {
                Text("assignmentDetail.submission.unsupportedInApp")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if canEdit == false && lastAttempt.canSubmit == false {
                Text(
                    lastAttempt.submissionsEnabled
                        ? String(localized: "assignmentDetail.submission.noActions")
                        : String(localized: "assignmentDetail.submission.closed")
                )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }

        if let message = viewModel.submissionErrorMessage {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private func submissionActionPanel(
        _ lastAttempt: LmsWebServiceClient.AssignmentLastAttempt
    ) -> some View {
        let canEdit =
            lastAttempt.submissionsEnabled
            && lastAttempt.locked == false
            && lastAttempt.canEdit
        let canUseConfiguration =
            assignment.submissionDrafts != nil && hasMissingSubmissionStatement == false
        let canEditInApp = supportsSubmissionEditing(lastAttempt)
        let showsEditorAction = canEdit && canUseConfiguration && canEditInApp
        let removableSubmission =
            canEdit && lastAttempt.submission?.isExistingSubmissionForEditing == true
            ? lastAttempt.submission
            : nil

        if showsEditorAction || removableSubmission != nil {
            VStack(spacing: 10) {
                if let operation = viewModel.submissionOperation {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text(operation.progressTitle)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                } else {
                    if showsEditorAction {
                        let editorAction = submissionEditorAction(for: lastAttempt.submission)
                        if editorAction == String(localized: "assignmentDetail.action.edit"), let removableSubmission {
                            HStack(spacing: 12) {
                                submissionEditorButton(
                                    title: editorAction,
                                    lastAttempt: lastAttempt
                                )

                                removeSubmissionButton(removableSubmission)
                            }
                        } else {
                            submissionEditorButton(
                                title: editorAction,
                                lastAttempt: lastAttempt
                            )
                        }
                    } else if let removableSubmission {
                        removeSubmissionButton(removableSubmission)
                    }
                }
            }
            .controlSize(.large)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
    }

    private func submissionEditorButton(
        title: String,
        lastAttempt: LmsWebServiceClient.AssignmentLastAttempt
    ) -> some View {
        Button {
            presentSubmissionEditor(for: lastAttempt)
        } label: {
            Text(title)
                .frame(maxWidth: .infinity)
        }
        .buttonSizing(.flexible)
        .buttonStyle(.glassProminent)
    }

    private func removeSubmissionButton(
        _ submission: LmsWebServiceClient.AssignmentSubmission
    ) -> some View {
        Button {
            submissionUserIDToRemove = submission.userID
            isConfirmingRemoval = true
        } label: {
            Text("common.delete")
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
        }
        .buttonSizing(.flexible)
        .buttonStyle(.glass)
        .confirmationDialog(
            String(localized: "assignmentDetail.confirmDelete.title"),
            isPresented: $isConfirmingRemoval,
            titleVisibility: .visible
        ) {
            Button("assignmentDetail.action.deleteSubmission", role: .destructive) {
                guard let submissionUserIDToRemove else {
                    return
                }

                Task {
                    _ = await viewModel.removeSubmission(
                        userID: submissionUserIDToRemove,
                        session: session
                    )
                    self.submissionUserIDToRemove = nil
                }
            }

            Button("common.cancel", role: .cancel) {
                submissionUserIDToRemove = nil
            }
        }
    }

    private func hasSubmissionActionPanel(
        for lastAttempt: LmsWebServiceClient.AssignmentLastAttempt
    ) -> Bool {
        let canEdit =
            lastAttempt.submissionsEnabled
            && lastAttempt.locked == false
            && lastAttempt.canEdit
        let canEditInApp =
            assignment.submissionDrafts != nil
            && hasMissingSubmissionStatement == false
            && supportsSubmissionEditing(lastAttempt)
        let hasExistingSubmission = lastAttempt.submission?.isExistingSubmissionForEditing == true

        return canEdit && (canEditInApp || hasExistingSubmission)
    }

    private var requiredSubmissionStatement: String? {
        guard assignment.requiresSubmissionStatement == true,
            let statement = assignment.submissionStatement,
            statement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        else {
            return nil
        }

        return statement
    }

    private var hasMissingSubmissionStatement: Bool {
        assignment.requiresSubmissionStatement == true && assignment.submissionStatement == nil
    }

    private var submissionConfigurationMessage: String {
        if hasMissingSubmissionStatement {
            return String(localized: "assignmentDetail.submission.missingStatement")
        }

        return String(localized: "assignmentDetail.submission.missingConfiguration")
    }

    private func supportsSubmissionEditing(
        _ lastAttempt: LmsWebServiceClient.AssignmentLastAttempt
    ) -> Bool {
        let pluginTypes: Set<String>
        if let configuredTypes = assignment.enabledSubmissionPluginTypes {
            pluginTypes = Set(configuredTypes.map { $0.lowercased() })
        } else if let submission = lastAttempt.submission {
            return submission.canEditAsSupportedSubmission
        } else {
            return false
        }

        return pluginTypes.intersection(["file", "onlinetext"]).isEmpty == false
            && pluginTypes.subtracting(["file", "onlinetext", "comments"]).isEmpty
    }

    private func submissionEditorAction(
        for submission: LmsWebServiceClient.AssignmentSubmission?
    ) -> String {
        guard let submission else {
            return String(localized: "assignmentDetail.action.startSubmission")
        }

        if submission.isNew {
            return String(localized: "assignmentDetail.action.startSubmission")
        }

        if submission.isReopened {
            return String(localized: "assignmentDetail.action.startResubmission")
        }

        return String(localized: "assignmentDetail.action.edit")
    }

    private func presentSubmissionEditor(
        for lastAttempt: LmsWebServiceClient.AssignmentLastAttempt
    ) {
        viewModel.clearSubmissionError()

        let showEditor = {
            let latestAttempt = viewModel.detail?.lastAttempt ?? lastAttempt
            let submission = latestAttempt.submission
            let isEditing = submission?.isExistingSubmissionForEditing == true
            let pluginTypes = enabledSubmissionPluginTypes(for: submission)
            submissionSheet = AssignmentSubmissionSheetContext(
                existingFiles: isEditing ? submission?.submissionFiles ?? [] : [],
                existingOnlineText: isEditing ? submission?.onlineTextEditorField : nil,
                allowsFileSubmission: pluginTypes.contains("file"),
                allowsOnlineTextSubmission: pluginTypes.contains("onlinetext"),
                isEditing: isEditing
            )
        }

        guard (assignment.timeLimit ?? lastAttempt.timeLimit ?? 0) > 0,
            lastAttempt.submission?.startedAt == nil,
            lastAttempt.submission?.isSubmitted != true
        else {
            showEditor()
            return
        }

        Task {
            if await viewModel.startTimedSubmission(session: session) {
                showEditor()
            }
        }
    }

    private func enabledSubmissionPluginTypes(
        for submission: LmsWebServiceClient.AssignmentSubmission?
    ) -> Set<String> {
        if let configuredTypes = assignment.enabledSubmissionPluginTypes {
            return Set(configuredTypes.map { $0.lowercased() })
        }

        return Set(
            submission?.plugins.map { $0.type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                ?? []
        )
    }

    private func openResource(_ url: URL) {
        openInApp(url)
    }

    private func openInApp(_ url: URL) {
        openURL(url, prefersInApp: prefersInAppExternalLinks)
    }

    private static func preferredAssignmentDescription(
        introPreview: String?,
        activityText: String?
    ) -> String? {
        if let activityText = trimmedNonEmptyText(activityText) {
            return activityText
        }

        return trimmedNonEmptyText(introPreview)
    }

    private static func trimmedNonEmptyText(_ text: String?) -> String? {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func statementText(_ html: String) -> String {
        LmsHTMLTextFormatter.plainText(from: html) ?? html
    }

    private static func localizedItemCount(_ count: Int) -> String {
        String.localizedStringWithFormat(String(localized: "common.count.items"), count)
    }

    private static func localizedPeopleCount(_ count: Int) -> String {
        String.localizedStringWithFormat(String(localized: "common.count.people"), count)
    }

    fileprivate static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct LmsAssignmentSubmissionContentView: View {
    let submission: LmsWebServiceClient.AssignmentSubmission
    let onOpenResource: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let startedAt = submission.startedAt {
                LabeledContent("assignmentDetail.submission.startedAt", value: LmsAssignmentDetailView.dateFormatter.string(from: startedAt))
            }

            if let createdAt = submission.createdAt {
                LabeledContent("assignmentDetail.submission.createdAt", value: LmsAssignmentDetailView.dateFormatter.string(from: createdAt))
            }

            if let gradingStatus = submission.gradingStatusDisplayName {
                LabeledContent("assignmentDetail.gradingStatus", value: gradingStatus)
            }

            LmsAssignmentPluginGroupView(plugins: submission.plugins, onOpenResource: onOpenResource)
        }
        .padding(.vertical, 4)
    }
}

private struct LmsAssignmentPluginGroupView: View {
    let plugins: [LmsWebServiceClient.AssignmentPlugin]
    let onOpenResource: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(plugins.filter { $0.hasVisibleContent }) { plugin in
                VStack(alignment: .leading, spacing: 10) {
                    Text(plugin.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    ForEach(plugin.editorFields.filter { $0.displayText != nil }) { field in
                        VStack(alignment: .leading, spacing: 6) {
                            if let description = field.displayDescription {
                                Text(description)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }

                            if let text = field.displayText {
                                Text(text)
                                    .font(.footnote)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }

                    ForEach(plugin.fileAreas.filter { $0.files.isEmpty == false }) { fileArea in
                        LmsAssignmentFileGroupView(
                            title: fileArea.displayName,
                            files: fileArea.files,
                            onOpenResource: onOpenResource
                        )
                    }
                }
            }
        }
    }
}

private struct LmsAssignmentFileGroupView: View {
    let title: String
    let files: [LmsWebServiceClient.AssignmentFile]
    let onOpenResource: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(files) { file in
                if let url = file.url {
                    Button {
                        onOpenResource(url)
                    } label: {
                        Label(file.displayName, systemImage: "doc")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct LmsAssignmentAttemptRow: View {
    let attempt: LmsWebServiceClient.AssignmentPreviousAttempt
    let onOpenResource: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(
                String.localizedStringWithFormat(
                    String(localized: "assignmentDetail.attempt.title"),
                    attempt.attemptNumber + 1
                )
            )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            if let submission = attempt.submission {
                LabeledContent("assignmentDetail.lastAttempt.section", value: submission.statusDisplayName)

                if let modifiedAt = submission.modifiedAt {
                    LabeledContent("assignmentDetail.submission.modifiedAt", value: LmsAssignmentDetailView.dateFormatter.string(from: modifiedAt))
                }

                if submission.hasVisibleContent {
                    LmsAssignmentSubmissionContentView(submission: submission, onOpenResource: onOpenResource)
                }
            }

            if let grade = attempt.grade {
                let displayGrade = grade.gradeForDisplay?.trimmingCharacters(in: .whitespacesAndNewlines)

                if let displayGrade, displayGrade.isEmpty == false {
                    LabeledContent("assignmentDetail.grade", value: displayGrade)
                } else {
                    LabeledContent("assignmentDetail.grade", value: grade.grade)
                }

                if let modifiedAt = grade.modifiedAt {
                    LabeledContent("assignmentDetail.gradedAt", value: LmsAssignmentDetailView.dateFormatter.string(from: modifiedAt))
                }
            }

            if attempt.feedbackPlugins.isEmpty == false {
                LmsAssignmentPluginGroupView(plugins: attempt.feedbackPlugins, onOpenResource: onOpenResource)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct AssignmentSubmissionSheetContext: Identifiable {
    let id = UUID()
    let existingFiles: [LmsWebServiceClient.AssignmentFile]
    let existingOnlineText: LmsWebServiceClient.AssignmentPluginEditorField?
    let allowsFileSubmission: Bool
    let allowsOnlineTextSubmission: Bool
    let isEditing: Bool
}
