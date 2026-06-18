import Foundation
import Observation
import MoodleNativeCore
import MoodleNativeNetworking

@Observable
@MainActor
final class AssignmentsViewModel: LoadableObject {
    private(set) var assignments: [LmsAssignmentItem] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var lastUpdatedAt: Date?

    private var loadedSession: LmsAuthenticationSession?
    private var loadGeneration = 0
    private var liveDataLoadTask: Task<Void, Never>?
    private var liveDataLoadID: UUID?
    private var hiddenAssignmentIDs: Set<Int>
    private let cacheStore: AssignmentsCacheStore
    private let hiddenStore: HiddenAssignmentsStore
    private let logContext: LmsRequestLogContext

    init(
        cacheStore: AssignmentsCacheStore? = nil,
        hiddenStore: HiddenAssignmentsStore = HiddenAssignmentsStore(),
        navigationPath: String = String(localized: "navigationPath.assignments"),
        pageTitle: String = String(localized: "tab.assignments")
    ) {
        self.cacheStore = cacheStore ?? AssignmentsCacheStore()
        self.hiddenStore = hiddenStore
        self.logContext = LmsRequestLogContext(navigationPath: navigationPath, pageTitle: pageTitle)
        hiddenAssignmentIDs = hiddenStore.load()
    }

    func loadIfNeeded(session: LmsAuthenticationSession?) async {
        guard let session else {
            reset(errorMessage: Self.authenticationRequiredMessage)
            return
        }

        reloadHiddenAssignments()
        await loadCachedDataIfNeeded(session: session)
        await load(session: session, forceRefresh: true)
    }

    func refresh(session: LmsAuthenticationSession?) async {
        guard let session else {
            reset(errorMessage: Self.authenticationRequiredMessage)
            return
        }

        reloadHiddenAssignments()
        await load(session: session, forceRefresh: true)
    }

    var visibleAssignments: [LmsAssignmentItem] {
        Self.orderedAssignments(
            from: assignments.filter { hiddenAssignmentIDs.contains($0.id) == false },
            now: .now
        )
    }

    var allAssignments: [LmsAssignmentItem] {
        Self.orderedAssignments(from: assignments, now: .now)
    }

    var requiresAuthentication: Bool {
        errorMessage == Self.authenticationRequiredMessage
    }

    static func orderedAssignments(from assignments: [LmsAssignmentItem], now: Date = .now) -> [LmsAssignmentItem] {
        LmsAssignmentItem.DueBucket.allCases.flatMap { bucket in
            sortedAssignments(assignments, in: bucket, now: now)
        }
    }

    static func incompleteAssignments(
        from assignments: [LmsAssignmentItem],
        completedAssignmentIDs: Set<Int>
    ) -> [LmsAssignmentItem] {
        assignments.filter { completedAssignmentIDs.contains($0.id) == false }
    }

    func hide(_ assignment: LmsAssignmentItem) {
        hiddenAssignmentIDs.insert(assignment.id)
        hiddenStore.save(hiddenAssignmentIDs)
    }

    func hide(_ assignments: [LmsAssignmentItem]) {
        hiddenAssignmentIDs.formUnion(assignments.map(\.id))
        hiddenStore.save(hiddenAssignmentIDs)
    }

    func show(_ assignment: LmsAssignmentItem) {
        hiddenAssignmentIDs.remove(assignment.id)
        hiddenStore.save(hiddenAssignmentIDs)
    }

    func isHidden(_ assignment: LmsAssignmentItem) -> Bool {
        hiddenAssignmentIDs.contains(assignment.id)
    }

    private func reloadHiddenAssignments() {
        hiddenAssignmentIDs = hiddenStore.load()
    }

    private func loadCachedDataIfNeeded(session: LmsAuthenticationSession) async {
        if loadedSession == session, lastUpdatedAt != nil {
            return
        }

        do {
            guard let cachedSnapshot = try cacheStore.load(for: session) else {
                return
            }

            applyCachedSnapshot(cachedSnapshot, session: session)
        } catch {
            try? cacheStore.delete()
        }
    }

    private func load(session: LmsAuthenticationSession, forceRefresh: Bool) async {
        if forceRefresh == false, loadedSession == session, lastUpdatedAt != nil {
            return
        }

        if let liveDataLoadTask {
            await liveDataLoadTask.value
            return
        }

        let loadID = UUID()
        let task = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            await self.fetchLiveData(session: session)
        }
        liveDataLoadID = loadID
        liveDataLoadTask = task

        await task.value

        if liveDataLoadID == loadID {
            liveDataLoadTask = nil
            liveDataLoadID = nil
        }
    }

    private func fetchLiveData(session: LmsAuthenticationSession) async {
        let generation = loadGeneration + 1
        loadGeneration = generation

        if assignments.isEmpty {
            isLoading = true
        }
        errorMessage = nil

        do {
            let client = LmsWebServiceClient.logged(session: session, context: logContext)
            let assignmentsByCourse = try await client.fetchAssignments()

            guard generation == loadGeneration else {
                return
            }

            let fetchedAssignments = Self.makeAssignments(from: assignmentsByCourse)
            let completedAssignmentIDs = try await Self.fetchCompletedAssignmentIDs(
                for: fetchedAssignments,
                session: session,
                logContext: logContext
            )

            guard generation == loadGeneration else {
                return
            }

            let visibleFetchedAssignments = Self.incompleteAssignments(
                from: fetchedAssignments,
                completedAssignmentIDs: completedAssignmentIDs
            )
            assignments = visibleFetchedAssignments
            loadedSession = session
            let updatedAt = Date.now
            lastUpdatedAt = updatedAt
            isLoading = false
            try? cacheStore.save(assignments: visibleFetchedAssignments, lastUpdatedAt: updatedAt, for: session)
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

    private func reset(errorMessage: String? = nil) {
        loadGeneration += 1
        liveDataLoadTask?.cancel()
        liveDataLoadTask = nil
        liveDataLoadID = nil
        loadedSession = nil
        assignments = []
        isLoading = false
        self.errorMessage = errorMessage
        lastUpdatedAt = nil
    }

    private func applyCachedSnapshot(
        _ snapshot: CachedAssignmentsSnapshot,
        session: LmsAuthenticationSession
    ) {
        assignments = snapshot.assignments.map(\.assignment)
        loadedSession = session
        lastUpdatedAt = snapshot.lastUpdatedAt
        isLoading = false
        errorMessage = nil
    }

    private static var authenticationRequiredMessage: String {
        String(localized: "assignments.loginRequired.description")
    }

    private static func makeAssignments(
        from assignmentsByCourse: [LmsWebServiceClient.CourseAssignments]
    ) -> [LmsAssignmentItem] {
        assignmentsByCourse.flatMap { course in
            let courseTitleParts = LmsCourseTitleParser.parse(course.fullName)
            return course.assignments.map { assignment in
                LmsAssignmentItem(
                    id: assignment.id,
                    courseID: assignment.courseID,
                    courseModuleID: assignment.courseModuleID,
                    courseTitle: courseTitleParts.title,
                    courseCode: courseTitleParts.courseCode,
                    courseShortName: course.shortName,
                    title: assignment.name,
                    introPreview: LmsHTMLTextFormatter.plainText(from: assignment.intro),
                    dueDate: date(from: assignment.dueDate),
                    allowsSubmissionsFromDate: date(from: assignment.allowsSubmissionsFromDate),
                    cutoffDate: date(from: assignment.cutoffDate),
                    updatedAt: date(from: assignment.timeModified),
                    submissionDrafts: assignment.submissionDrafts,
                    requiresSubmissionStatement: assignment.requiresSubmissionStatement,
                    submissionStatement: assignment.submissionStatement,
                    timeLimit: assignment.timeLimit,
                    enabledSubmissionPluginTypes: assignment.enabledSubmissionPluginTypes,
                    onlineTextWordLimit: assignment.onlineTextWordLimit
                )
            }
        }
    }

    private static func date(from timestamp: Int?) -> Date? {
        guard let timestamp, timestamp > 0 else {
            return nil
        }

        return Date(timeIntervalSince1970: TimeInterval(timestamp))
    }

    private static func sortedAssignments(
        _ assignments: [LmsAssignmentItem],
        in bucket: LmsAssignmentItem.DueBucket,
        now: Date
    ) -> [LmsAssignmentItem] {
        assignments
            .filter { $0.dueBucket(now: now) == bucket }
            .sorted { lhs, rhs in
                switch bucket {
                case .overdue:
                    return compareDescending(lhs, rhs)
                case .upcoming:
                    return compareAscending(lhs, rhs)
                case .undated:
                    return compareUndated(lhs, rhs)
                }
            }
    }

    private static func fetchCompletedAssignmentIDs(
        for assignments: [LmsAssignmentItem],
        session: LmsAuthenticationSession,
        logContext: LmsRequestLogContext
    ) async throws -> Set<Int> {
        guard assignments.isEmpty == false else {
            return []
        }

        return try await withThrowingTaskGroup(of: Int?.self, returning: Set<Int>.self) { group in
            for assignment in assignments {
                group.addTask {
                    do {
                        let status = try await LmsWebServiceClient.logged(session: session, context: logContext)
                            .fetchAssignmentSubmissionStatus(assignmentID: assignment.id)
                        return status.hasCompletedSubmission ? assignment.id : nil
                    } catch {
                        if isCancellation(error) {
                            throw error
                        }

                        return nil
                    }
                }
            }

            var completedAssignmentIDs = Set<Int>()
            for try await assignmentID in group {
                if let assignmentID {
                    completedAssignmentIDs.insert(assignmentID)
                }
            }
            return completedAssignmentIDs
        }
    }

    private static func compareAscending(_ lhs: LmsAssignmentItem, _ rhs: LmsAssignmentItem) -> Bool {
        let lhsDate = lhs.dueDate ?? .distantFuture
        let rhsDate = rhs.dueDate ?? .distantFuture
        if lhsDate != rhsDate {
            return lhsDate < rhsDate
        }

        if lhs.courseTitle != rhs.courseTitle {
            return lhs.courseTitle.localizedStandardCompare(rhs.courseTitle) == .orderedAscending
        }

        return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
    }

    private static func compareDescending(_ lhs: LmsAssignmentItem, _ rhs: LmsAssignmentItem) -> Bool {
        let lhsDate = lhs.dueDate ?? .distantPast
        let rhsDate = rhs.dueDate ?? .distantPast
        if lhsDate != rhsDate {
            return lhsDate > rhsDate
        }

        if lhs.courseTitle != rhs.courseTitle {
            return lhs.courseTitle.localizedStandardCompare(rhs.courseTitle) == .orderedAscending
        }

        return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
    }

    private static func compareUndated(_ lhs: LmsAssignmentItem, _ rhs: LmsAssignmentItem) -> Bool {
        if lhs.courseTitle != rhs.courseTitle {
            return lhs.courseTitle.localizedStandardCompare(rhs.courseTitle) == .orderedAscending
        }

        if lhs.updatedAt != rhs.updatedAt {
            return (lhs.updatedAt ?? .distantPast) > (rhs.updatedAt ?? .distantPast)
        }

        return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
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

        return String(localized: "assignments.error.fetchFailed")
    }

    nonisolated private static func isCancellation(_ error: Error) -> Bool {
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
