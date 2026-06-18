import Foundation
import Observation
import MoodleNativeCore
import MoodleNativeFeatures
import MoodleNativeNetworking

@Observable
@MainActor
final class TimetableViewModel: LoadableObject {
    static let selectedSemesterStorageKey = "settings.timetableSelectedSemesterID"

    let weekdays = [
        String(localized: "weekday.monday.short"),
        String(localized: "weekday.tuesday.short"),
        String(localized: "weekday.wednesday.short"),
        String(localized: "weekday.thursday.short"),
        String(localized: "weekday.friday.short"),
    ]
    let periods = ["1", "2", "3", "4", "5", "6"]

    private(set) var courses: [TimetableCourse] = []
    private(set) var displayedCourseSummaries: [LmsCourseSummary] = []
    private(set) var availableSemesters: [AcademicSemester] = []
    private(set) var selectedSemester: AcademicSemester?
    private(set) var pendingCourseConflicts: [TimetableCourseConflict] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var lastUpdatedAt: Date?
    #if DEBUG
    private(set) var activeDebugFixtureTitle: String?
    #endif

    private var loadedSession: LmsAuthenticationSession?
    private var allCourseSummaries: [LmsCourseSummary] = []
    private var courseSummariesByID: [String: LmsCourseSummary] = [:]
    private var courseConflictResolutions = TimetableCourseConflictResolutionStore.load()
    private var loadGeneration = 0
    private let cacheStore: TimetableCacheStore
    private let logContext: LmsRequestLogContext

    private struct ScheduleSlotGroupKey: Hashable {
        let dayIndex: Int
        let room: String?
    }

    init(
        cacheStore: TimetableCacheStore? = nil,
        navigationPath: String = String(localized: "navigationPath.timetable"),
        pageTitle: String = String(localized: "tab.timetable")
    ) {
        self.cacheStore = cacheStore ?? TimetableCacheStore()
        self.logContext = LmsRequestLogContext(navigationPath: navigationPath, pageTitle: pageTitle)
    }

    var scheduledGridRows: [TimetableGridRow] {
        guard scheduledCourses.isEmpty == false else {
            return []
        }

        return periods.enumerated().map { periodIndex, period in
            TimetableGridRow(
                id: "scheduled-\(period)",
                title: period,
                courses: weekdays.enumerated().map { dayIndex, _ in
                    scheduledCourses.first {
                        $0.dayIndex == dayIndex
                            && $0.periodIndex == periodIndex
                    }
                }
            )
        }
    }

    var unscheduledGridRows: [TimetableGridRow] {
        unscheduledCourseRows.enumerated().map { rowIndex, rowCourses in
            TimetableGridRow(
                id: "unscheduled-\(rowIndex)",
                title: scheduledGridRows.isEmpty ? "" : "-",
                courses: rowCourses
            )
        }
    }

    var scheduledGridPlacements: [TimetableCourse] {
        scheduledCourses.sorted { lhs, rhs in
            let lhsDay = lhs.dayIndex ?? .max
            let rhsDay = rhs.dayIndex ?? .max
            if lhsDay != rhsDay {
                return lhsDay < rhsDay
            }

            let lhsPeriod = lhs.periodIndex ?? .max
            let rhsPeriod = rhs.periodIndex ?? .max
            if lhsPeriod != rhsPeriod {
                return lhsPeriod < rhsPeriod
            }

            return lhs.id < rhs.id
        }
    }

    var gridRows: [TimetableGridRow] {
        scheduledGridRows + unscheduledGridRows
    }

    var hasScheduledCourses: Bool {
        scheduledCourses.isEmpty == false
    }

    #if DEBUG
    var isUsingDebugFixture: Bool {
        activeDebugFixtureTitle != nil
    }
    #endif

    func courseSummary(for course: TimetableCourse) -> LmsCourseSummary? {
        courseSummariesByID[course.id]
    }

    func resolveCourseConflicts(_ resolutions: [String: String]) {
        let pendingConflicts = Dictionary(uniqueKeysWithValues: pendingCourseConflicts.map { ($0.id, $0) })
        for (conflictID, selectedCourseID) in resolutions {
            guard
                let conflict = pendingConflicts[conflictID],
                conflict.courses.contains(where: { $0.id == selectedCourseID })
            else {
                continue
            }

            courseConflictResolutions[conflictID] = selectedCourseID
        }

        TimetableCourseConflictResolutionStore.save(courseConflictResolutions)
        rebuildVisibleState()
    }

    func selectSemester(_ semester: AcademicSemester) {
        guard selectedSemester != semester else {
            return
        }

        UserDefaults.standard.set(semester.id, forKey: Self.selectedSemesterStorageKey)
        selectedSemester = semester
        rebuildVisibleState()
    }

    func selectSemester(id semesterID: String) {
        guard let semester = availableSemesters.first(where: { $0.id == semesterID }) else {
            return
        }

        selectSemester(semester)
    }

    func loadIfNeeded(session: LmsAuthenticationSession?) async {
        await loadIfNeeded(session: session, userIDResolved: nil)
    }

    func loadIfNeeded(
        session: LmsAuthenticationSession?,
        userIDResolved: (@MainActor (Int, LmsAuthenticationSession) -> Void)?
    ) async {
        #if DEBUG
        guard isUsingDebugFixture == false else {
            return
        }
        #endif

        await loadDataIfNeeded(session: session, userIDResolved: userIDResolved)
    }

    @discardableResult
    private func loadDataIfNeeded(
        session: LmsAuthenticationSession?,
        userIDResolved: (@MainActor (Int, LmsAuthenticationSession) -> Void)? = nil
    ) async -> Bool {
        #if DEBUG
        let profiler = TimetableLoadProfiler(label: "\(logContext.navigationPath) loadIfNeeded")
        #endif

        guard let session else {
            reset()
            #if DEBUG
            profiler.finish("no session")
            #endif
            return false
        }

        let isSwitchingSession = loadedSession != session
        let shouldRefreshLoadedData =
            loadedSession == session
            && displayedCourseSummaries.isEmpty == false
            && lastUpdatedAt.map { Self.shouldRefresh(since: $0) } == true

        guard
            isSwitchingSession || displayedCourseSummaries.isEmpty
                || shouldRefreshLoadedData
        else {
            #if DEBUG
            profiler.finish("skip already loaded")
            #endif
            return false
        }

        var shouldFetchLiveData = isSwitchingSession || shouldRefreshLoadedData

        if isSwitchingSession || displayedCourseSummaries.isEmpty {
            do {
                #if DEBUG
                profiler.mark("cache load start")
                #endif

                if let cachedSnapshot = try cacheStore.load(for: session) {
                    applyCachedSnapshot(cachedSnapshot, session: session)

                    #if DEBUG
                    profiler.mark("cache applied courses=\(cachedSnapshot.courses.count)")
                    #endif

                    let hasScheduledSlots = cachedSnapshot.courses.contains {
                        $0.scheduleSlots.isEmpty == false
                    }

                    if cacheStore.shouldRefresh(cachedSnapshot) == false && hasScheduledSlots {
                        #if DEBUG
                        profiler.finish("cache hit, silent icon refresh")
                        #endif
                        return await refreshIconsFromDashboardBlocks(session: session)
                    }

                    shouldFetchLiveData = true
                } else {
                    #if DEBUG
                    profiler.mark("cache miss")
                    #endif
                    shouldFetchLiveData = true
                }
            } catch {
                try? cacheStore.delete()
                #if DEBUG
                profiler.mark("cache error deleted")
                #endif
                shouldFetchLiveData = true
            }
        }

        guard shouldFetchLiveData else {
            #if DEBUG
            profiler.finish("skip live fetch")
            #endif
            return false
        }

        #if DEBUG
        profiler.finish("live fetch required")
        #endif
        return await load(session: session, forceRefresh: true, userIDResolved: userIDResolved)
    }

    func refresh(session: LmsAuthenticationSession?) async {
        await refresh(session: session, userIDResolved: nil)
    }

    func refresh(
        session: LmsAuthenticationSession?,
        userIDResolved: (@MainActor (Int, LmsAuthenticationSession) -> Void)?
    ) async {
        #if DEBUG
        guard isUsingDebugFixture == false else {
            return
        }
        #endif

        guard let session else {
            reset()
            return
        }

        _ = await load(session: session, forceRefresh: true, userIDResolved: userIDResolved)
    }

    func setCourseFavorite(
        courseID: Int,
        isFavorite: Bool,
        session: LmsAuthenticationSession?
    ) async throws {
        guard let session else {
            throw LmsWebServiceError.moodle(
                message: String(localized: "timetable.error.loginRequired"),
                debugInfo: nil
            )
        }

        guard let existingSummary = allCourseSummaries.first(where: { $0.id == courseID }) else {
            return
        }

        guard existingSummary.isFavorite != isFavorite else {
            return
        }

        do {
            try await LmsWebServiceClient.logged(session: session, context: logContext)
            .setFavouriteCourses([
                .init(id: courseID, isFavorite: isFavorite)
            ])

            let updatedAt = Date.now
            let updatedSummaries = allCourseSummaries.map { summary in
                summary.id == courseID
                    ? Self.updating(summary: summary, isFavorite: isFavorite)
                    : summary
            }

            applySummaries(updatedSummaries, session: session, lastUpdatedAt: updatedAt)
            try? cacheStore.save(summaries: updatedSummaries, lastUpdatedAt: updatedAt, for: session)
            errorMessage = nil
        } catch {
            if Self.isCancellation(error) {
                throw error
            }

            errorMessage = Self.message(for: error)
            throw error
        }
    }

    @discardableResult
    private func load(
        session: LmsAuthenticationSession,
        forceRefresh: Bool = false,
        userIDResolved: (@MainActor (Int, LmsAuthenticationSession) -> Void)? = nil
    ) async -> Bool {
        guard
            forceRefresh || loadedSession != session
                || displayedCourseSummaries.isEmpty
        else {
            return false
        }

        let generation = loadGeneration + 1
        loadGeneration = generation

        if displayedCourseSummaries.isEmpty {
            isLoading = true
        }
        errorMessage = nil

        do {
            #if DEBUG
            let profiler = TimetableLoadProfiler(label: "\(logContext.navigationPath) live load")
            profiler.mark("network start")
            #endif

            let snapshot = try await LmsWebServiceClient.logged(session: session, context: logContext)
                .fetchTimetableSnapshot(userID: session.userID)

            #if DEBUG
            profiler.mark("network finished courses=\(snapshot.courses.count) blocks=\(snapshot.dashboardBlocks.count)")
            #endif

            let resolvedSession: LmsAuthenticationSession
            if let userID = snapshot.userID {
                resolvedSession = session.userID == userID ? session : session.withUserID(userID)
                if session.userID != userID {
                    userIDResolved?(userID, session)
                }
            } else {
                resolvedSession = session
            }

            guard generation == loadGeneration else {
                #if DEBUG
                profiler.finish("discarded generation")
                #endif
                return false
            }

            let updatedAt = Date.now
            let baseSummaries = LmsCourseSummaryFactory.makeCourseSummaries(
                from: snapshot
            )
            #if DEBUG
            profiler.mark("summary factory summaries=\(baseSummaries.count)")
            #endif

            let rutimePlacements = LmsRutimeTableParser.parse(from: snapshot)
            #if DEBUG
            profiler.mark("rutime parse placements=\(rutimePlacements.count)")
            #endif

            let summaries = Self.applyingPlacements(
                rutimePlacements,
                to: baseSummaries
            )
            #if DEBUG
            profiler.mark("apply placements summaries=\(summaries.count)")
            #endif

            applySummaries(summaries, session: resolvedSession, lastUpdatedAt: updatedAt)
            #if DEBUG
            profiler.mark("apply summaries courses=\(courses.count)")
            #endif

            try? cacheStore.save(
                summaries: summaries,
                lastUpdatedAt: updatedAt,
                for: resolvedSession
            )
            #if DEBUG
            profiler.mark("cache save")
            #endif

            loadedSession = resolvedSession
            isLoading = false
            #if DEBUG
            profiler.finish("success")
            #endif
            return true
        } catch {
            guard generation == loadGeneration else {
                return false
            }

            if Self.isCancellation(error) {
                isLoading = false
                return false
            }

            errorMessage = Self.message(for: error)
            isLoading = false
            #if DEBUG
            TimetableLoadProfiler.log("\(logContext.navigationPath) live load failed: \(Self.message(for: error))")
            #endif
            return false
        }
    }

    @discardableResult
    private func refreshIconsFromDashboardBlocks(session: LmsAuthenticationSession) async -> Bool {
        guard allCourseSummaries.isEmpty == false else {
            return false
        }

        let generation = loadGeneration

        do {
            #if DEBUG
            let profiler = TimetableLoadProfiler(label: "\(logContext.navigationPath) silent icon refresh")
            profiler.mark("dashboard_blocks start")
            #endif

            let dashboardBlocks = try await LmsWebServiceClient.logged(session: session, context: logContext)
                .fetchDashboardBlocks(returnContents: true)

            #if DEBUG
            profiler.mark("dashboard_blocks finished blocks=\(dashboardBlocks.count)")
            #endif

            guard generation == loadGeneration else {
                #if DEBUG
                profiler.finish("discarded generation")
                #endif
                return false
            }

            let placements = LmsRutimeTableParser.parse(
                dashboardBlocks: dashboardBlocks,
                siteURL: session.siteURL
            )
            #if DEBUG
            profiler.mark("rutime parse placements=\(placements.count)")
            #endif

            let summaries = Self.applyingPlacements(placements, to: allCourseSummaries)
            applySummaries(summaries, session: session, lastUpdatedAt: Date.now)
            #if DEBUG
            profiler.finish("success")
            #endif
            return true
        } catch {
            if Self.isCancellation(error) {
                return false
            }

            errorMessage = Self.message(for: error)
            #if DEBUG
            TimetableLoadProfiler.log("\(logContext.navigationPath) silent icon refresh failed: \(Self.message(for: error))")
            #endif
            return false
        }
    }

    private var scheduledCourses: [TimetableCourse] {
        courses.filter { $0.dayIndex != nil && $0.periodIndex != nil }
    }

    private var unscheduledCourses: [TimetableCourse] {
        courses.filter { $0.dayIndex == nil || $0.periodIndex == nil }
    }

    private var unscheduledCourseRows: [[TimetableCourse?]] {
        let chunkSize = weekdays.count

        guard unscheduledCourses.isEmpty == false else {
            return []
        }

        var rows: [[TimetableCourse?]] = []
        var dayKnownCourses = unscheduledCourses.filter { $0.dayIndex != nil }
        let dayUnknownCourses = unscheduledCourses.filter { $0.dayIndex == nil }

        while dayKnownCourses.isEmpty == false {
            var row = Array(repeating: TimetableCourse?.none, count: chunkSize)

            dayKnownCourses.removeAll { course in
                guard
                    let dayIndex = course.dayIndex,
                    row.indices.contains(dayIndex),
                    row[dayIndex] == nil
                else {
                    return false
                }

                row[dayIndex] = course
                return true
            }

            rows.append(row)
        }

        rows += stride(from: 0, to: dayUnknownCourses.count, by: chunkSize).map { startIndex in
            let endIndex = min(startIndex + chunkSize, dayUnknownCourses.count)
            let row = Array(dayUnknownCourses[startIndex..<endIndex]).map(Optional.some)
            let emptyCells = Array(repeating: TimetableCourse?.none, count: max(0, chunkSize - row.count))
            return row + emptyCells
        }

        return rows
    }

    private func reset() {
        loadGeneration += 1
        loadedSession = nil
        allCourseSummaries = []
        displayedCourseSummaries = []
        availableSemesters = []
        selectedSemester = nil
        courseSummariesByID = [:]
        courses = []
        pendingCourseConflicts = []
        isLoading = false
        errorMessage = nil
        lastUpdatedAt = nil
        #if DEBUG
        activeDebugFixtureTitle = nil
        #endif
    }

    #if DEBUG
    func applyDebugFixture(_ fixture: DebugTimetableFixture) {
        loadGeneration += 1
        loadedSession = nil
        allCourseSummaries = fixture.summaries
        lastUpdatedAt = .now
        isLoading = false
        errorMessage = nil
        activeDebugFixtureTitle = fixture.title
        reconcileSemesterSelection()
        rebuildVisibleState()
    }

    func clearDebugFixture() {
        guard isUsingDebugFixture else {
            return
        }

        reset()
    }
    #endif

    private func applyCachedSnapshot(
        _ snapshot: CachedTimetableSnapshot,
        session: LmsAuthenticationSession
    ) {
        let summaries = snapshot.courses.map { $0.lmsCourseSummary(siteURL: session.siteURL) }

        applySummaries(summaries, session: session, lastUpdatedAt: snapshot.lastUpdatedAt)
        loadedSession = session
        isLoading = false
        errorMessage = nil
    }

    private func applySummaries(
        _ summaries: [LmsCourseSummary],
        session: LmsAuthenticationSession,
        lastUpdatedAt: Date
    ) {
        allCourseSummaries = summaries
        loadedSession = session
        self.lastUpdatedAt = lastUpdatedAt
        reconcileSemesterSelection()
        rebuildVisibleState()
    }

    private func reconcileSemesterSelection() {
        let semesters = Self.detectedSemesters(from: allCourseSummaries)
        availableSemesters = semesters

        let storedSemesterID = UserDefaults.standard.string(forKey: Self.selectedSemesterStorageKey)
        if let storedSemester = semesters.first(where: { $0.id == storedSemesterID }) {
            selectedSemester = storedSemester
        } else if let selectedSemester, semesters.contains(selectedSemester) {
            UserDefaults.standard.set(selectedSemester.id, forKey: Self.selectedSemesterStorageKey)
        } else {
            selectedSemester = semesters.first
            if let selectedSemester {
                UserDefaults.standard.set(selectedSemester.id, forKey: Self.selectedSemesterStorageKey)
            }
        }
    }

    private func rebuildVisibleState() {
        displayedCourseSummaries = Self.filteredSummaries(
            from: allCourseSummaries,
            selectedSemester: selectedSemester
        )

        let timetableCourses = displayedCourseSummaries.flatMap { summary in
            Self.makeTimetableCourses(from: summary).map { ($0, summary) }
        }

        let rawCourses = timetableCourses.map(\.0)
        let conflicts = Self.makeCourseConflicts(
            from: rawCourses,
            selectedSemester: selectedSemester
        )
        let validConflictResolutions = courseConflictResolutions.filter { conflictID, selectedCourseID in
            guard let conflict = conflicts.first(where: { $0.id == conflictID }) else {
                return false
            }

            return conflict.courses.contains { $0.id == selectedCourseID }
        }
        if validConflictResolutions != courseConflictResolutions {
            courseConflictResolutions = validConflictResolutions
            TimetableCourseConflictResolutionStore.save(validConflictResolutions)
        }

        let hiddenCourseIDs = Set(conflicts.flatMap { conflict in
            guard let selectedCourseID = validConflictResolutions[conflict.id] else {
                return [String]()
            }

            return conflict.courses.map(\.id).filter { $0 != selectedCourseID }
        })
        courses = rawCourses.filter { hiddenCourseIDs.contains($0.id) == false }
        pendingCourseConflicts = conflicts.filter {
            validConflictResolutions[$0.id] == nil
        }
        courseSummariesByID = timetableCourses.reduce(into: [String: LmsCourseSummary]()) {
            result,
            pair in
            result[pair.0.id] = pair.1
        }
    }

    static func contiguousPeriodRanges(for periodIndices: [Int]) -> [ClosedRange<Int>] {
        let sortedPeriods = Array(Set(periodIndices)).sorted()
        guard let firstPeriod = sortedPeriods.first else {
            return []
        }

        var ranges: [ClosedRange<Int>] = []
        var lowerBound = firstPeriod
        var upperBound = firstPeriod

        for periodIndex in sortedPeriods.dropFirst() {
            if periodIndex == upperBound + 1 {
                upperBound = periodIndex
                continue
            }

            ranges.append(lowerBound...upperBound)
            lowerBound = periodIndex
            upperBound = periodIndex
        }

        ranges.append(lowerBound...upperBound)
        return ranges
    }

    static func normalizedScheduleSlots(_ slots: [TimetableScheduleSlot]) -> [TimetableScheduleSlot] {
        let groupedSlots = Dictionary(grouping: slots) {
            ScheduleSlotGroupKey(dayIndex: $0.dayIndex, room: $0.room)
        }

        return
            groupedSlots
            .map { key, grouped in
                TimetableScheduleSlot(
                    dayIndex: key.dayIndex,
                    periodIndices: grouped.flatMap(\.periodIndices).sorted(),
                    room: key.room
                )
            }
            .sorted { lhs, rhs in
                if lhs.dayIndex != rhs.dayIndex {
                    return lhs.dayIndex < rhs.dayIndex
                }

                let lhsPeriod = lhs.periodIndices.min() ?? .max
                let rhsPeriod = rhs.periodIndices.min() ?? .max
                if lhsPeriod != rhsPeriod {
                    return lhsPeriod < rhsPeriod
                }

                return (lhs.room ?? "") < (rhs.room ?? "")
            }
    }

    static func makeTimetableCourses(from summary: LmsCourseSummary)
        -> [TimetableCourse]
    {
        let statuses = makeStatuses(from: summary)
        let normalizedSlots = normalizedScheduleSlots(summary.scheduleSlots)

        guard normalizedSlots.isEmpty == false else {
            return [
                TimetableCourse(
                    id: "course-\(summary.id)",
                    title: summary.title,
                    room: summary.courseCode,
                    dayIndex: nil,
                    periodIndex: nil,
                    periodSpan: 1,
                    isTentative: false,
                    statuses: statuses,
                    detailURL: summary.detailURL
                )
            ]
        }

        return normalizedSlots.flatMap { slot in
            contiguousPeriodRanges(for: slot.periodIndices).map { periodRange in
                TimetableCourse(
                    id: "course-\(summary.id)-\(slot.dayIndex)-\(periodRange.lowerBound)",
                    title: summary.title,
                    room: slot.room ?? summary.courseCode,
                    dayIndex: slot.dayIndex,
                    periodIndex: periodRange.lowerBound,
                    periodSpan: periodRange.upperBound - periodRange.lowerBound + 1,
                    isTentative: false,
                    statuses: statuses,
                    detailURL: summary.detailURL
                )
            }
        }
    }

    static func makeCourseConflicts(
        from courses: [TimetableCourse],
        selectedSemester: AcademicSemester?
    ) -> [TimetableCourseConflict] {
        let scheduledCourses = courses.filter {
            $0.dayIndex != nil && $0.periodIndex != nil
        }
        var conflicts: [TimetableCourseConflict] = []
        var seenCourseGroups = Set<String>()

        for dayIndex in 0..<5 {
            let coursesByPeriod = Dictionary(grouping: scheduledCourses) { course in
                course.dayIndex ?? .max
            }[dayIndex] ?? []

            for periodIndex in 0..<6 {
                let overlappingCourses = coursesByPeriod.filter {
                    courseOccupies($0, periodIndex: periodIndex)
                }
                guard overlappingCourses.count > 1 else {
                    continue
                }

                let relatedCourses = overlappingComponent(
                    startingWith: Set(overlappingCourses.map(\.id)),
                    in: coursesByPeriod
                )
                let courseGroupKey = relatedCourses.map(\.id).sorted().joined(separator: ",")
                guard seenCourseGroups.insert(courseGroupKey).inserted else {
                    continue
                }

                let occupiedPeriods = relatedCourses.flatMap { occupiedPeriodIndices(for: $0) }
                let periodIndices = Array(Set(occupiedPeriods)).sorted()
                let conflictID = conflictID(
                    selectedSemester: selectedSemester,
                    dayIndex: dayIndex,
                    periodIndices: periodIndices,
                    courseIDs: relatedCourses.map(\.id)
                )

                conflicts.append(
                    TimetableCourseConflict(
                        id: conflictID,
                        dayIndex: dayIndex,
                        periodIndices: periodIndices,
                        courses: relatedCourses.sorted {
                            if $0.periodSpan != $1.periodSpan {
                                return $0.periodSpan > $1.periodSpan
                            }

                            return $0.title.localizedStandardCompare($1.title) == .orderedAscending
                        }
                    )
                )
            }
        }

        return conflicts.sorted {
            if $0.dayIndex != $1.dayIndex {
                return $0.dayIndex < $1.dayIndex
            }

            return ($0.periodIndices.min() ?? .max) < ($1.periodIndices.min() ?? .max)
        }
    }

    private static func overlappingComponent(
        startingWith seedCourseIDs: Set<String>,
        in courses: [TimetableCourse]
    ) -> [TimetableCourse] {
        var selectedIDs = seedCourseIDs
        var changed = true

        while changed {
            changed = false
            let selectedCourses = courses.filter { selectedIDs.contains($0.id) }
            let selectedSlots = Set(selectedCourses.flatMap { occupiedPeriodIndices(for: $0) })

            for course in courses where selectedIDs.contains(course.id) == false {
                let overlaps = occupiedPeriodIndices(for: course).contains {
                    selectedSlots.contains($0)
                }
                if overlaps {
                    selectedIDs.insert(course.id)
                    changed = true
                }
            }
        }

        return courses.filter { selectedIDs.contains($0.id) }
    }

    private static func courseOccupies(_ course: TimetableCourse, periodIndex: Int) -> Bool {
        occupiedPeriodIndices(for: course).contains(periodIndex)
    }

    private static func occupiedPeriodIndices(for course: TimetableCourse) -> [Int] {
        guard let periodIndex = course.periodIndex else {
            return []
        }

        return Array(periodIndex..<(periodIndex + course.periodSpan))
    }

    private static func conflictID(
        selectedSemester: AcademicSemester?,
        dayIndex: Int,
        periodIndices: [Int],
        courseIDs: [String]
    ) -> String {
        let semesterID = selectedSemester?.id ?? "all"
        let periodID = periodIndices.map(String.init).joined(separator: "-")
        let courseID = courseIDs.sorted().joined(separator: "-")
        return "\(semesterID):\(dayIndex):\(periodID):\(courseID)"
    }

    static func applyingPlacements(
        _ placements: [LmsRutimeTableParser.CoursePlacement],
        to summaries: [LmsCourseSummary]
    ) -> [LmsCourseSummary] {
        guard placements.isEmpty == false else {
            return summaries
        }

        let statusesByCourseID = placements.reduce(into: [Int: TimetablePlacementStatuses]()) {
            partialResult,
            placement in
            var statuses = partialResult[placement.courseID] ?? TimetablePlacementStatuses()
            statuses.isFavorite = statuses.isFavorite || placement.isFavorite
            statuses.hasUnreadAnnouncement = statuses.hasUnreadAnnouncement || placement.hasUnreadAnnouncement
            statuses.hasPendingAssignment = statuses.hasPendingAssignment || placement.hasPendingAssignment
            statuses.hasUnreadForum = statuses.hasUnreadForum || placement.hasUnreadForum
            partialResult[placement.courseID] = statuses
        }
        let slotsByCourseID = placements.reduce(into: [Int: [TimetableScheduleSlot]]()) {
            partialResult,
            placement in
            guard
                let dayIndex = placement.dayIndex,
                let periodIndex = placement.periodIndex
            else {
                return
            }

            partialResult[placement.courseID, default: []].append(
                TimetableScheduleSlot(
                    dayIndex: dayIndex,
                    periodIndices: [periodIndex],
                    room: placement.room
                )
            )
        }

        return summaries.map { summary in
            let scheduleSlots: [TimetableScheduleSlot]
            if let placementSlots = slotsByCourseID[summary.id], placementSlots.isEmpty == false {
                var seenKeys = Set<String>()
                let deduplicatedSlots: [TimetableScheduleSlot] = placementSlots.compactMap {
                    slot -> TimetableScheduleSlot? in
                    guard let periodIndex = slot.periodIndices.first else {
                        return nil
                    }

                    let key = "\(slot.dayIndex)-\(periodIndex)"
                    guard seenKeys.insert(key).inserted else {
                        return nil
                    }

                    return slot
                }

                scheduleSlots = normalizedScheduleSlots(deduplicatedSlots)
            } else {
                scheduleSlots = summary.scheduleSlots
            }

            return LmsCourseSummary(
                id: summary.id,
                title: summary.title,
                courseCode: summary.courseCode,
                shortName: summary.shortName,
                summary: summary.summary,
                courseImageURL: summary.courseImageURL,
                progress: summary.progress,
                isFavorite: summary.isFavorite || (statusesByCourseID[summary.id]?.isFavorite ?? false),
                academicSemester: summary.academicSemester,
                scheduleSlots: scheduleSlots,
                assignmentCount: count(
                    summary.assignmentCount,
                    isOn: statusesByCourseID[summary.id]?.hasPendingAssignment ?? false
                ),
                unreadAnnouncementCount: count(
                    summary.unreadAnnouncementCount,
                    isOn: statusesByCourseID[summary.id]?.hasUnreadAnnouncement ?? false
                ),
                unreadForumPostCount: count(
                    summary.unreadForumPostCount,
                    isOn: statusesByCourseID[summary.id]?.hasUnreadForum ?? false
                ),
                isRecentlyAccessed: summary.isRecentlyAccessed,
                detailURL: summary.detailURL
            )
        }
    }

    private struct TimetablePlacementStatuses {
        var isFavorite = false
        var hasUnreadAnnouncement = false
        var hasPendingAssignment = false
        var hasUnreadForum = false
    }

    private static func count(_ currentCount: Int, isOn: Bool) -> Int {
        isOn ? max(currentCount, 1) : currentCount
    }

    private static func makeStatuses(from summary: LmsCourseSummary) -> [TimetableStatus] {
        var statuses: [TimetableStatus] = []

        if summary.isFavorite {
            statuses.append(.favorite)
        }
        if summary.unreadAnnouncementCount > 0 {
            statuses.append(.unreadAnnouncement)
        }
        if summary.assignmentCount > 0 {
            statuses.append(.pendingAssignment)
        }
        if summary.unreadForumPostCount > 0 {
            statuses.append(.unreadForum)
        }

        return statuses
    }

    private static func detectedSemesters(from summaries: [LmsCourseSummary])
        -> [AcademicSemester]
    {
        Array(
            Set(
                summaries.compactMap(\.academicSemester).filter {
                    $0.season != .unknown
                }
            )
        )
        .sorted { lhs, rhs in
            if lhs.academicYear != rhs.academicYear {
                return lhs.academicYear > rhs.academicYear
            }

            return lhs.season.sortOrder < rhs.season.sortOrder
        }
    }

    private static func filteredSummaries(
        from summaries: [LmsCourseSummary],
        selectedSemester: AcademicSemester?
    ) -> [LmsCourseSummary] {
        guard let selectedSemester else {
            return summaries
        }

        return summaries.filter { summary in
            guard let academicSemester = summary.academicSemester else {
                return true
            }

            if academicSemester.season == .unknown {
                return true
            }

            return academicSemester == selectedSemester
        }
    }

    private static func message(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
            let description = localizedError.errorDescription,
            description.isEmpty == false
        {
            return description
        }

        let description = error.localizedDescription.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if description.isEmpty == false {
            return description
        }

        return String(localized: "timetable.error.fetchFailed")
    }

    private static func updating(summary: LmsCourseSummary, isFavorite: Bool) -> LmsCourseSummary {
        LmsCourseSummary(
            id: summary.id,
            title: summary.title,
            courseCode: summary.courseCode,
            shortName: summary.shortName,
            summary: summary.summary,
            courseImageURL: summary.courseImageURL,
            progress: summary.progress,
            isFavorite: isFavorite,
            academicSemester: summary.academicSemester,
            scheduleSlots: summary.scheduleSlots,
            assignmentCount: summary.assignmentCount,
            unreadAnnouncementCount: summary.unreadAnnouncementCount,
            unreadForumPostCount: summary.unreadForumPostCount,
            isRecentlyAccessed: summary.isRecentlyAccessed,
            detailURL: summary.detailURL
        )
    }

    nonisolated private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        if let urlError = error as? URLError, urlError.code == .cancelled {
            return true
        }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain
            && nsError.code == URLError.cancelled.rawValue
    }

    private static func shouldRefresh(
        since lastUpdatedAt: Date,
        now: Date = .now
    ) -> Bool {
        now.timeIntervalSince(lastUpdatedAt)
            >= TimetableCacheStore.defaultAutomaticRefreshInterval
    }
}

#if DEBUG
private final class TimetableLoadProfiler {
    private let label: String
    private let startedAt: CFAbsoluteTime
    private var lastMarkedAt: CFAbsoluteTime

    init(label: String) {
        self.label = label
        let now = CFAbsoluteTimeGetCurrent()
        startedAt = now
        lastMarkedAt = now
        Self.log("\(label) started")
    }

    func mark(_ name: String) {
        let now = CFAbsoluteTimeGetCurrent()
        Self.log(
            "\(label) \(name): +\(Self.milliseconds(now - lastMarkedAt))ms total=\(Self.milliseconds(now - startedAt))ms"
        )
        lastMarkedAt = now
    }

    func finish(_ name: String) {
        let now = CFAbsoluteTimeGetCurrent()
        Self.log("\(label) \(name): total=\(Self.milliseconds(now - startedAt))ms")
    }

    static func log(_ message: String) {
        print("[TimetablePerformance] \(message)")
    }

    private static func milliseconds(_ seconds: CFTimeInterval) -> Int {
        Int((seconds * 1000).rounded())
    }
}
#endif
