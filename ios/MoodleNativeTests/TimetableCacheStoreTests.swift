import Foundation
import MoodleNativeCore
import MoodleNativeNetworking
import MoodleNativeFeatures
import Testing

@testable import MoodleNative

@MainActor
struct TimetableCacheStoreTests {
    @Test func cacheRoundTripForMatchingSession() throws {
        let directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let store = TimetableCacheStore(cacheDirectoryURL: directoryURL)
        let session = LmsAuthenticationSession(
            siteURL: "https://lms.example.test",
            token: "ws-token-123",
            privateToken: nil,
            rawCallbackURL: "moodleapp://example?token=ws-token-123",
            authenticatedAt: Date(timeIntervalSince1970: 1_744_506_000)
        )
        let summaries = [
            LmsCourseSummary(
                id: 42,
                title: "計算機構成論",
                courseCode: "53346",
                shortName: "2026-53346",
                summary: "春セメスター:春セメ・金4(7-8) 金4:H202",
                courseImageURL: URL(string: "https://lms.example.test/course.svg"),
                progress: 50,
                isFavorite: false,
                academicSemester: AcademicSemester(academicYear: 2026, season: .spring),
                scheduleSlots: [
                    TimetableScheduleSlot(dayIndex: 4, periodIndices: [3], room: "H202")
                ],
                assignmentCount: 1,
                unreadAnnouncementCount: 3,
                unreadForumPostCount: 2,
                isRecentlyAccessed: true,
                detailURL: URL(string: "https://lms.example.test/course/view.php?id=42")
            )
        ]
        let updatedAt = Date(timeIntervalSince1970: 1_745_000_000)

        try store.save(summaries: summaries, lastUpdatedAt: updatedAt, for: session)
        let loaded = try store.load(for: session)
        let cached = try #require(loaded)

        #expect(cached.siteURL == session.siteURL)
        #expect(cached.authenticatedAt == session.authenticatedAt)
        #expect(cached.lastUpdatedAt == updatedAt)
        #expect(
            cached.courses == [
                CachedCourseRecord(
                    id: 42,
                    title: "計算機構成論",
                    courseCode: "53346",
                    shortName: "2026-53346",
                    summary: "春セメスター:春セメ・金4(7-8) 金4:H202",
                    progress: 50,
                    isFavorite: false,
                    academicSemester: AcademicSemester(academicYear: 2026, season: .spring),
                    scheduleSlots: [
                        CachedScheduleSlot(dayIndex: 4, periodIndices: [3], room: "H202")
                    ]
                )
            ])

        #expect(cached.courses.count == 1)
        let restoredSummary = try #require(cached.courses.first?.lmsCourseSummary(siteURL: session.siteURL))
        #expect(restoredSummary.assignmentCount == 0)
        #expect(restoredSummary.unreadAnnouncementCount == 0)
        #expect(restoredSummary.unreadForumPostCount == 0)
        #expect(restoredSummary.isRecentlyAccessed == false)
    }

    @Test func cacheIsIgnoredWhenSessionChanges() throws {
        let directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let store = TimetableCacheStore(cacheDirectoryURL: directoryURL)
        let originalSession = LmsAuthenticationSession(
            siteURL: "https://lms.example.test",
            token: "ws-token-123",
            privateToken: nil,
            rawCallbackURL: "moodleapp://example?token=ws-token-123",
            authenticatedAt: Date(timeIntervalSince1970: 1_744_506_000)
        )
        let anotherSession = LmsAuthenticationSession(
            siteURL: "https://lms.example.test",
            token: "ws-token-456",
            privateToken: nil,
            rawCallbackURL: "moodleapp://example?token=ws-token-456",
            authenticatedAt: Date(timeIntervalSince1970: 1_744_606_000)
        )

        try store.save(summaries: [], lastUpdatedAt: .now, for: originalSession)
        let cached = try store.load(for: anotherSession)

        #expect(cached == nil)
    }

    @Test func cacheRefreshesAfterConfiguredInterval() throws {
        let directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let store = TimetableCacheStore(
            cacheDirectoryURL: directoryURL,
            automaticRefreshInterval: 60
        )
        let session = LmsAuthenticationSession(
            siteURL: "https://lms.example.test",
            token: "ws-token-123",
            privateToken: nil,
            rawCallbackURL: "moodleapp://example?token=ws-token-123",
            authenticatedAt: Date(timeIntervalSince1970: 1_744_506_000)
        )
        let updatedAt = Date(timeIntervalSince1970: 1_745_000_000)

        try store.save(summaries: [], lastUpdatedAt: updatedAt, for: session)
        let loaded = try store.load(for: session)
        let cached = try #require(loaded)

        #expect(store.shouldRefresh(cached, now: updatedAt.addingTimeInterval(59)) == false)
        #expect(store.shouldRefresh(cached, now: updatedAt.addingTimeInterval(60)) == true)
    }
}
