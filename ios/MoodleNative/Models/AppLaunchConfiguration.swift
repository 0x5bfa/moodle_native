import Foundation
import MoodleNativeCore
import MoodleNativeFeatures
import MoodleNativeNetworking

struct AppLaunchConfiguration {
    static let current = AppLaunchConfiguration()

    private let arguments: Set<String>

    init(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) {
        self.arguments = Set(arguments)
    }

    var initialSelectedTab: RootTab {
        if arguments.contains("UITEST_START_TIMETABLE") {
            return .timetable
        }

        return .home
    }

    var shouldIgnoreStoredSession: Bool {
        arguments.contains("UITEST_FORCE_LOGGED_OUT")
            || arguments.contains("UITEST_SAMPLE_TIMETABLE")
    }

    var shouldForceTimetableDisplayMode: Bool {
        arguments.contains("UITEST_SAMPLE_TIMETABLE")
    }

    var initialSession: LmsAuthenticationSession? {
        guard arguments.contains("UITEST_SAMPLE_TIMETABLE") else {
            return nil
        }

        return LmsAuthenticationSession(
            siteURL: "https://lms.example.test",
            token: "ui-test-token",
            privateToken: nil,
            rawCallbackURL: "moodleapp://example?token=ui-test-token",
            authenticatedAt: Self.authenticatedAt
        )
    }

    func makeAuthenticationViewModel() -> LmsAuthenticationViewModel {
        LmsAuthenticationViewModel(
            authenticationService: LmsMobileAuthenticationService(),
            store: LmsAuthenticationStore(),
            timetableCacheStore: TimetableCacheStore(),
            settingsProfileCacheStore: SettingsProfileCacheStore(),
            loadStoredSession: shouldIgnoreStoredSession == false,
            initialSession: initialSession
        )
    }

    func makeTimetableViewModel(
        navigationPath: String = String(localized: "navigationPath.timetable"),
        pageTitle: String = String(localized: "tab.timetable")
    ) -> TimetableViewModel {
        guard let session = initialSession else {
            return TimetableViewModel(navigationPath: navigationPath, pageTitle: pageTitle)
        }

        let cacheDirectoryURL = FileManager.default.temporaryDirectory
            .appending(path: "MoodleNative-UITests")
        let cacheStore = TimetableCacheStore(cacheDirectoryURL: cacheDirectoryURL)

        try? cacheStore.delete()
        try? cacheStore.save(
            summaries: [Self.sampleCourseSummary],
            lastUpdatedAt: .now,
            for: session
        )

        return TimetableViewModel(
            cacheStore: cacheStore,
            navigationPath: navigationPath,
            pageTitle: pageTitle
        )
    }

    private static let authenticatedAt = Date(timeIntervalSince1970: 1_775_000_000)

    private static let sampleCourseSummary = LmsCourseSummary(
        id: 1,
        title: String(localized: "debug.sampleCourse.title"),
        courseCode: "53374",
        shortName: String(localized: "debug.sampleCourse.shortName"),
        summary: String(localized: "debug.sampleCourse.summary"),
        courseImageURL: nil,
        progress: 55,
        isFavorite: true,
        academicSemester: AcademicSemester(academicYear: 2026, season: .spring),
        scheduleSlots: [
            TimetableScheduleSlot(dayIndex: 0, periodIndices: [1], room: "H301")
        ],
        assignmentCount: 2,
        unreadAnnouncementCount: 1,
        unreadForumPostCount: 3,
        isRecentlyAccessed: true,
        detailURL: URL(string: "https://lms.example.test/course/view.php?id=1")
    )
}

extension LmsAuthenticationViewModel {
    static func makeDefault() -> LmsAuthenticationViewModel {
        AppLaunchConfiguration.current.makeAuthenticationViewModel()
    }
}

extension TimetableViewModel {
    static func makeDefault(
        navigationPath: String = String(localized: "navigationPath.timetable"),
        pageTitle: String = String(localized: "tab.timetable")
    ) -> TimetableViewModel {
        AppLaunchConfiguration.current.makeTimetableViewModel(
            navigationPath: navigationPath,
            pageTitle: pageTitle
        )
    }
}
