import Foundation
import Observation
import MoodleNativeCore
import MoodleNativeNetworking
import MoodleNativeFeatures

@Observable
@MainActor
final class AssignmentDetailViewModel: LoadableObject {
    enum SubmissionOperation {
        case saving
        case submitting
        case starting
        case removing

        var progressTitle: String {
            switch self {
            case .saving:
                return String(localized: "assignmentDetail.progress.saving")
            case .submitting:
                return String(localized: "assignmentDetail.progress.submitting")
            case .starting:
                return String(localized: "assignmentDetail.progress.starting")
            case .removing:
                return String(localized: "assignmentDetail.progress.removing")
            }
        }
    }

    private(set) var completionRequirements: [LmsModuleCompletionRequirement]
    private(set) var detail: LmsWebServiceClient.AssignmentSubmissionStatus?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var submissionOperation: SubmissionOperation?
    private(set) var submissionErrorMessage: String?

    private let assignmentID: Int
    private let courseID: Int?
    private let courseModuleID: Int
    private let initialCompletionRequirements: [LmsModuleCompletionRequirement]
    private let logContext: LmsRequestLogContext
    private let submissionLogContext: LmsRequestLogContext
    private var loadedSession: LmsAuthenticationSession?
    private var hasLoaded = false
    private var loadGeneration = 0

    init(
        assignment: LmsAssignmentReference,
        navigationPath: String = String(localized: "navigationPath.assignments.assignmentDetail")
    ) {
        self.assignmentID = assignment.assignmentID
        self.courseID = assignment.courseID
        self.courseModuleID = assignment.courseModuleID
        self.initialCompletionRequirements = assignment.completionRequirements
        self.completionRequirements = assignment.completionRequirements
        self.logContext = LmsRequestLogContext(
            navigationPath: navigationPath,
            pageTitle: assignment.title
        )
        self.submissionLogContext = LmsRequestLogContext(
            navigationPath: "\(navigationPath) > \(String(localized: "assignmentSubmission.title.start"))",
            pageTitle: assignment.title
        )
    }

    func loadIfNeeded(session: LmsAuthenticationSession?) async {
        guard let session else {
            reset()
            return
        }

        guard hasLoaded == false || loadedSession != session else {
            return
        }

        await load(session: session)
    }

    func refresh(session: LmsAuthenticationSession?) async {
        guard let session else {
            reset()
            return
        }

        await load(session: session, forceRefresh: true)
    }

    func saveSubmission(
        files submissionFiles: [AssignmentSubmissionFileDraft],
        fileContentChanged: Bool,
        onlineText: LmsWebServiceClient.AssignmentOnlineTextInput?,
        session: LmsAuthenticationSession?
    ) async -> Bool {
        await performSubmissionOperation(.saving, session: session) { client in
            try await self.performSaveSubmission(
                using: client,
                files: submissionFiles,
                fileContentChanged: fileContentChanged,
                onlineText: onlineText
            )
        }
    }

    /// Submits a saved draft for grading. Use only when `submissionDrafts == true`.
    /// Non-draft assignments are submitted by `saveSubmission` alone.
    func submitForGrading(
        acceptsSubmissionStatement: Bool,
        session: LmsAuthenticationSession?
    ) async -> Bool {
        await performSubmissionOperation(.submitting, session: session) { client in
            try await client.submitAssignmentForGrading(
                assignmentID: self.assignmentID,
                acceptsSubmissionStatement: acceptsSubmissionStatement
            )
        }
    }

    func startTimedSubmission(session: LmsAuthenticationSession?) async -> Bool {
        await performSubmissionOperation(.starting, session: session) { client in
            try await client.startAssignmentSubmission(assignmentID: self.assignmentID)
        }
    }

    func removeSubmission(userID: Int, session: LmsAuthenticationSession?) async -> Bool {
        await performSubmissionOperation(.removing, session: session) { client in
            try await client.removeAssignmentSubmission(
                assignmentID: self.assignmentID,
                userID: userID
            )
        }
    }

    func clearSubmissionError() {
        submissionErrorMessage = nil
    }

    private func load(
        session: LmsAuthenticationSession,
        forceRefresh: Bool = false
    ) async {
        guard forceRefresh || hasLoaded == false || loadedSession != session else {
            return
        }

        let generation = loadGeneration + 1
        loadGeneration = generation
        isLoading = true
        errorMessage = nil

        do {
            let client = LmsWebServiceClient.logged(session: session, context: logContext)
            let detail = try await client.fetchAssignmentSubmissionStatus(
                assignmentID: assignmentID
            )
            let completionRequirements = await fetchCompletionRequirements(
                using: client
            )
            guard generation == loadGeneration else {
                return
            }

            self.completionRequirements = completionRequirements
            self.detail = detail
            loadedSession = session
            hasLoaded = true
            isLoading = false
        } catch {
            guard generation == loadGeneration else {
                return
            }

            if Self.isCancellation(error) {
                isLoading = false
                return
            }

            errorMessage = Self.message(for: error)
            isLoading = false
        }
    }

    private func reset() {
        loadGeneration += 1
        completionRequirements = initialCompletionRequirements
        detail = nil
        isLoading = false
        errorMessage = nil
        submissionOperation = nil
        submissionErrorMessage = nil
        loadedSession = nil
        hasLoaded = false
    }

    private func performSaveSubmission(
        using client: LmsWebServiceClient,
        files submissionFiles: [AssignmentSubmissionFileDraft],
        fileContentChanged: Bool,
        onlineText: LmsWebServiceClient.AssignmentOnlineTextInput?
    ) async throws {
        var fileDraftItemID: Int?
        if fileContentChanged {
            let files = try await submissionFiles.asyncMap { file in
                try await file.uploadFile(using: client)
            }

            if files.isEmpty {
                fileDraftItemID = 0
            } else {
                let uploadedFiles = try await client.uploadAssignmentSubmissionFiles(files)
                guard let uploadedItemID = uploadedFiles.first?.itemID else {
                    throw LmsWebServiceError.invalidResponse
                }
                fileDraftItemID = uploadedItemID
            }
        }

        try await client.saveAssignmentSubmission(
            assignmentID: assignmentID,
            fileDraftItemID: fileDraftItemID,
            onlineText: onlineText
        )
    }

    private func performSubmissionOperation(
        _ operation: SubmissionOperation,
        session: LmsAuthenticationSession?,
        action: (LmsWebServiceClient) async throws -> Void
    ) async -> Bool {
        guard let session, submissionOperation == nil else {
            return false
        }

        submissionOperation = operation
        submissionErrorMessage = nil
        let client = LmsWebServiceClient.logged(session: session, context: submissionLogContext)

        do {
            try await action(client)
            let refreshedDetail = try await client.fetchAssignmentSubmissionStatus(
                assignmentID: assignmentID
            )
            detail = refreshedDetail
            loadedSession = session
            hasLoaded = true
            submissionOperation = nil
            return true
        } catch {
            submissionOperation = nil

            if Self.isCancellation(error) {
                return false
            }

            submissionErrorMessage = Self.message(for: error)
            return false
        }
    }

    private func fetchCompletionRequirements(
        using client: LmsWebServiceClient
    ) async -> [LmsModuleCompletionRequirement] {
        guard initialCompletionRequirements.isEmpty,
            let courseID
        else {
            return completionRequirements
        }

        do {
            let sections = try await client.fetchCourseContents(courseID: courseID)
            guard
                let courseModule = Self.findCourseModule(
                    in: sections,
                    courseModuleID: courseModuleID,
                    assignmentID: assignmentID
                )
            else {
                return completionRequirements
            }

            return courseModule.completionData?.requirements ?? initialCompletionRequirements
        } catch {
            if Self.isCancellation(error) {
                return completionRequirements
            }

            return completionRequirements
        }
    }

    private static func findCourseModule(
        in sections: [LmsWebServiceClient.CourseSection],
        courseModuleID: Int,
        assignmentID: Int
    ) -> LmsWebServiceClient.CourseModule? {
        sections
            .flatMap(\.modules)
            .first { module in
                module.id == courseModuleID || module.instanceID == assignmentID
            }
    }

    private static func message(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
            let description = localizedError.errorDescription,
            description.isEmpty == false
        {
            return description
        }

        let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if description.isEmpty == false {
            return description
        }

        return String(localized: "assignmentDetail.error.fetchFailed")
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        if let urlError = error as? URLError, urlError.code == .cancelled {
            return true
        }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == URLError.cancelled.rawValue
    }
}

struct AssignmentSubmissionFileDraft: Identifiable, Equatable {
    enum Source: Equatable {
        case existing(LmsWebServiceClient.AssignmentFile)
        case local(data: Data, mimeType: String)
    }

    let id: String
    var fileName: String
    var source: Source

    nonisolated init(existing file: LmsWebServiceClient.AssignmentFile) {
        id = "existing:\(file.id)"
        fileName = Self.displayFileName(for: file)
        source = .existing(file)
    }

    nonisolated init(uploadFile: LmsWebServiceClient.AssignmentSubmissionUploadFile) {
        id = "local:\(UUID().uuidString)"
        fileName = uploadFile.fileName
        source = .local(data: uploadFile.data, mimeType: uploadFile.mimeType)
    }

    var trimmedFileName: String {
        fileName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var initialSignature: String {
        switch source {
        case .existing(let file):
            return "existing:\(file.id):\(Self.displayFileName(for: file))"
        case .local:
            return "local:\(id):\(trimmedFileName)"
        }
    }

    var currentSignature: String {
        switch source {
        case .existing(let file):
            return "existing:\(file.id):\(trimmedFileName)"
        case .local:
            return "local:\(id):\(trimmedFileName)"
        }
    }

    func uploadFile(
        using client: LmsWebServiceClient
    ) async throws -> LmsWebServiceClient.AssignmentSubmissionUploadFile {
        switch source {
        case .existing(let file):
            let downloadedFile = try await client.downloadAssignmentSubmissionFile(file)
            return .init(
                fileName: normalizedFileName(fallback: downloadedFile.fileName),
                mimeType: downloadedFile.mimeType,
                data: downloadedFile.data
            )
        case .local(let data, let mimeType):
            return .init(
                fileName: normalizedFileName(fallback: "submission-file"),
                mimeType: mimeType,
                data: data
            )
        }
    }

    private func normalizedFileName(fallback: String) -> String {
        let trimmed = trimmedFileName
        return trimmed.isEmpty ? fallback : trimmed
    }

    nonisolated private static func displayFileName(for file: LmsWebServiceClient.AssignmentFile) -> String {
        let trimmedName = file.fileName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedName.isEmpty ? String(localized: "common.attachment") : trimmedName
    }
}

private extension Sequence {
    func asyncMap<Transformed>(
        _ transform: (Element) async throws -> Transformed
    ) async throws -> [Transformed] {
        var transformed: [Transformed] = []
        transformed.reserveCapacity(underestimatedCount)

        for element in self {
            try Task.checkCancellation()
            transformed.append(try await transform(element))
        }

        return transformed
    }
}
