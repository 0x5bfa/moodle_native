import MoodleNativeCore
import MoodleNativeNetworking
import SwiftUI
import UniformTypeIdentifiers

struct LmsAssignmentSubmissionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let assignmentTitle: String
    let assignmentDescription: String?
    let existingFiles: [LmsWebServiceClient.AssignmentFile]
    let existingOnlineText: LmsWebServiceClient.AssignmentPluginEditorField?
    let allowsFileSubmission: Bool
    let allowsOnlineTextSubmission: Bool
    let onlineTextWordLimit: Int?
    let isEditing: Bool
    let submissionDrafts: Bool
    let requiredSubmissionStatement: String?
    let session: LmsAuthenticationSession?
    let viewModel: AssignmentDetailViewModel

    @State private var submissionFiles: [AssignmentSubmissionFileDraft]
    @State private var onlineText: String
    @State private var acceptsSubmissionStatement = false
    @State private var isSelectingFiles = false
    @State private var localErrorMessage: String?
    @State private var presentationDetent: PresentationDetent = .large
    @State private var isConfirmingFinalSubmission = false

    init(
        assignmentTitle: String,
        assignmentDescription: String?,
        existingFiles: [LmsWebServiceClient.AssignmentFile],
        existingOnlineText: LmsWebServiceClient.AssignmentPluginEditorField?,
        allowsFileSubmission: Bool,
        allowsOnlineTextSubmission: Bool,
        onlineTextWordLimit: Int?,
        isEditing: Bool,
        submissionDrafts: Bool,
        requiredSubmissionStatement: String?,
        session: LmsAuthenticationSession?,
        viewModel: AssignmentDetailViewModel
    ) {
        self.assignmentTitle = assignmentTitle
        self.assignmentDescription = assignmentDescription
        self.existingFiles = existingFiles
        self.existingOnlineText = existingOnlineText
        self.allowsFileSubmission = allowsFileSubmission
        self.allowsOnlineTextSubmission = allowsOnlineTextSubmission
        self.onlineTextWordLimit = onlineTextWordLimit
        self.isEditing = isEditing
        self.submissionDrafts = submissionDrafts
        self.requiredSubmissionStatement = requiredSubmissionStatement
        self.session = session
        self.viewModel = viewModel
        _submissionFiles = State(
            initialValue: existingFiles.map(AssignmentSubmissionFileDraft.init(existing:))
        )
        _onlineText = State(initialValue: existingOnlineText?.displayText ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(assignmentTitle)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if let assignmentDescription {
                            Text(assignmentDescription)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

                if allowsFileSubmission {
                    Section {
                        Button("assignmentSubmission.action.selectFiles", systemImage: "doc.badge.plus") {
                            isSelectingFiles = true
                        }
                        .disabled(viewModel.submissionOperation != nil)

                        if submissionFiles.isEmpty {
                            Text("assignmentSubmission.files.empty")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach($submissionFiles) { $file in
                                LmsAssignmentSubmissionFileDraftRow(
                                    file: $file,
                                    isDisabled: viewModel.submissionOperation != nil,
                                    remove: {
                                        removeSubmissionFile(id: file.id)
                                    }
                                )
                            }
                        }

                        if hasDuplicateFileNames {
                            Text("assignmentSubmission.files.duplicateNames")
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }

                        if hasBlankFileNames {
                            Text("assignmentSubmission.files.blankName")
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    } header: {
                        Text("assignmentSubmission.files.section")
                    } footer: {
                        Text("assignmentSubmission.files.footer")
                    }
                }

                if allowsOnlineTextSubmission {
                    Section {
                        TextEditor(text: $onlineText)
                            .frame(minHeight: 160)
                            .disabled(viewModel.submissionOperation != nil)

                        if let onlineTextWordLimit {
                            LabeledContent(
                                "assignmentSubmission.onlineText.wordCount",
                                value: "\(onlineTextWordCount) / \(onlineTextWordLimit)"
                            )
                            .foregroundStyle(exceedsOnlineTextWordLimit ? .red : .secondary)
                        }
                    } header: {
                        Text("assignmentSubmission.onlineText.section")
                    } footer: {
                        if exceedsOnlineTextWordLimit {
                            Text("assignmentSubmission.onlineText.wordLimitExceeded")
                                .foregroundStyle(.red)
                        }
                    }
                }

                if let requiredSubmissionStatement {
                    Section("assignmentSubmission.statement.section") {
                        Text(Self.statementText(requiredSubmissionStatement))
                            .font(.footnote)

                        Toggle("assignmentSubmission.statement.accept", isOn: $acceptsSubmissionStatement)
                    }
                }

                Section {
                    Button {
                        if submissionDrafts {
                            submitFiles()
                        } else {
                            isConfirmingFinalSubmission = true
                        }
                    } label: {
                        if let operation = viewModel.submissionOperation,
                            operation == .saving || operation == .submitting
                        {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text(
                                    operation == .submitting
                                        ? String(localized: "assignmentSubmission.submitting")
                                        : String(localized: "assignmentSubmission.saving")
                                )
                            }
                        } else {
                            Text(buttonTitle)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(canSave == false || viewModel.submissionOperation != nil)
                } footer: {
                    Text(
                        submissionDrafts
                            ? String(localized: "assignmentSubmission.footer.draft")
                            : String(localized: "assignmentSubmission.footer.final")
                    )
                }

                if let message = localErrorMessage ?? viewModel.submissionErrorMessage {
                    Section {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(
                isEditing
                    ? String(localized: "assignmentSubmission.title.edit")
                    : String(localized: "assignmentSubmission.title.start")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close") {
                        dismiss()
                    }
                    .disabled(viewModel.submissionOperation != nil)
                }
            }
        }
        .fileImporter(
            isPresented: $isSelectingFiles,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            do {
                submissionFiles.append(
                    contentsOf: try result.get()
                        .map(Self.makeUploadFile(from:))
                        .map(AssignmentSubmissionFileDraft.init(uploadFile:))
                )
                localErrorMessage = nil
                viewModel.clearSubmissionError()
            } catch {
                localErrorMessage = message(for: error)
            }
        }
        .presentationDetents([.medium, .large], selection: $presentationDetent)
        .presentationBackground(Color(.systemBackground))
        .confirmationDialog(
            String(localized: "assignmentDetail.confirmSubmit.title"),
            isPresented: $isConfirmingFinalSubmission,
            titleVisibility: .visible
        ) {
            Button("assignmentSubmission.action.submit") {
                submitFiles()
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("assignmentDetail.confirmSubmit.message")
        }
    }

    private var hasChanges: Bool {
        hasFileChanges || hasOnlineTextChanges
    }

    private var hasFileChanges: Bool {
        allowsFileSubmission && submissionFiles.map(\.currentSignature) != initialFileSignatures
    }

    private var initialFileSignatures: [String] {
        existingFiles
            .map(AssignmentSubmissionFileDraft.init(existing:))
            .map(\.initialSignature)
    }

    private var normalizedFileNames: [String] {
        submissionFiles.map { $0.trimmedFileName.lowercased() }
    }

    private var hasBlankFileNames: Bool {
        submissionFiles.contains { $0.trimmedFileName.isEmpty }
    }

    private var hasDuplicateFileNames: Bool {
        Set(normalizedFileNames).count != normalizedFileNames.count
    }

    private var initialOnlineText: String {
        existingOnlineText?.displayText ?? ""
    }

    private var hasOnlineTextChanges: Bool {
        allowsOnlineTextSubmission && onlineText != initialOnlineText
    }

    private var onlineTextWordCount: Int {
        onlineText.split(whereSeparator: \.isWhitespace).count
    }

    private var exceedsOnlineTextWordLimit: Bool {
        guard let onlineTextWordLimit else {
            return false
        }

        return onlineTextWordCount > onlineTextWordLimit
    }

    private var canSave: Bool {
        let hasFiles = allowsFileSubmission && submissionFiles.isEmpty == false
        let hasText =
            allowsOnlineTextSubmission
            && onlineText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let acceptsRequiredStatement = requiredSubmissionStatement == nil || acceptsSubmissionStatement
        return (hasFiles || hasText || hasFileChanges)
            && hasChanges
            && exceedsOnlineTextWordLimit == false
            && hasBlankFileNames == false
            && hasDuplicateFileNames == false
            && acceptsRequiredStatement
    }

    private var buttonTitle: String {
        if submissionDrafts {
            return isEditing
                ? String(localized: "assignmentSubmission.action.updateFiles")
                : String(localized: "assignmentSubmission.action.saveFiles")
        }

        return isEditing
            ? String(localized: "assignmentSubmission.action.update")
            : String(localized: "assignmentSubmission.action.submit")
    }

    private func submitFiles() {
        localErrorMessage = nil
        viewModel.clearSubmissionError()

        Task {
            let onlineTextInput: LmsWebServiceClient.AssignmentOnlineTextInput? =
                hasOnlineTextChanges
                ? .init(text: Self.htmlText(fromPlainText: onlineText))
                : nil
            // Non-draft assignments are submitted by mod_assign_save_submission alone.
            // Calling submit_for_grading afterward fails with couldnotsubmitforgrading.
            let didSave = await viewModel.saveSubmission(
                files: submissionFiles,
                fileContentChanged: hasFileChanges,
                onlineText: onlineTextInput,
                session: session
            )
            if didSave {
                dismiss()
            }
        }
    }

    private func removeSubmissionFile(id: String) {
        submissionFiles.removeAll { $0.id == id }
    }

    nonisolated private static func makeUploadFile(
        from url: URL
    ) throws -> LmsWebServiceClient.AssignmentSubmissionUploadFile {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let values = try url.resourceValues(forKeys: [.nameKey, .contentTypeKey])
        let fileName = values.name ?? url.lastPathComponent
        let mimeType = values.contentType?.preferredMIMEType ?? "application/octet-stream"
        let data = try Data(contentsOf: url, options: .mappedIfSafe)

        return .init(fileName: fileName, mimeType: mimeType, data: data)
    }

    nonisolated private static func statementText(_ html: String) -> String {
        LmsHTMLTextFormatter.plainText(from: html) ?? html
    }

    nonisolated private static func htmlText(fromPlainText text: String) -> String {
        let escaped =
            text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
        let paragraphs = escaped.components(separatedBy: "\n\n").map {
            "<p>\($0.replacingOccurrences(of: "\n", with: "<br>"))</p>"
        }
        return paragraphs.joined()
    }

    private func message(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
            let description = localizedError.errorDescription,
            description.isEmpty == false
        {
            return description
        }

        return String(localized: "assignmentSubmission.error.fileReadFailed")
    }
}

private struct LmsAssignmentSubmissionFileDraftRow: View {
    @Binding var file: AssignmentSubmissionFileDraft

    let isDisabled: Bool
    let remove: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "doc")
                .foregroundStyle(.secondary)

            TextField("assignmentSubmission.files.fileName", text: $file.fileName)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .disabled(isDisabled)

            Button("common.delete", systemImage: "trash", action: remove)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .disabled(isDisabled)
        }
        .contextMenu {
            Button("common.delete", systemImage: "trash", role: .destructive, action: remove)
                .disabled(isDisabled)
        }
    }
}
