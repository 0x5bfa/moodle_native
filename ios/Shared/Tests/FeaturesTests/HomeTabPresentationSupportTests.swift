import Foundation
import MoodleNativeCore
import MoodleNativeFeatures
import MoodleNativeNetworking
import Testing

@testable import MoodleNativeFeatures

struct HomeTabPresentationSupportTests {
    @Test func filterRemainingCoursesForToday() {
        let now = Self.date(year: 2026, month: 4, day: 15, hour: 11, minute: 0)
        let summaries = [
            LmsCourseSummary(
                id: 1,
                title: "朝の授業",
                courseCode: nil,
                shortName: "A",
                summary: nil,
                courseImageURL: nil,
                progress: nil,
                isFavorite: false,
                academicSemester: nil,
                scheduleSlots: [TimetableScheduleSlot(dayIndex: 2, periodIndices: [0], room: "H101")],
                assignmentCount: 0,
                unreadAnnouncementCount: 0,
                unreadForumPostCount: 0,
                isRecentlyAccessed: false,
                detailURL: nil
            ),
            LmsCourseSummary(
                id: 2,
                title: "午後の授業",
                courseCode: nil,
                shortName: "B",
                summary: nil,
                courseImageURL: nil,
                progress: nil,
                isFavorite: false,
                academicSemester: nil,
                scheduleSlots: [TimetableScheduleSlot(dayIndex: 2, periodIndices: [2], room: "H202")],
                assignmentCount: 0,
                unreadAnnouncementCount: 0,
                unreadForumPostCount: 0,
                isRecentlyAccessed: false,
                detailURL: nil
            ),
            LmsCourseSummary(
                id: 3,
                title: "明日の授業",
                courseCode: nil,
                shortName: "C",
                summary: nil,
                courseImageURL: nil,
                progress: nil,
                isFavorite: false,
                academicSemester: nil,
                scheduleSlots: [TimetableScheduleSlot(dayIndex: 3, periodIndices: [1], room: "H303")],
                assignmentCount: 0,
                unreadAnnouncementCount: 0,
                unreadForumPostCount: 0,
                isRecentlyAccessed: false,
                detailURL: nil
            ),
        ]

        let remaining = HomeTabPresentationSupport.remainingCoursesToday(
            from: summaries,
            now: now,
            calendar: Self.calendar
        )

        #expect(remaining.map(\.course.title) == ["午後の授業"])
        #expect(remaining.first?.periodTitle == "3限")
    }

    @Test func countAssignmentsRemainingThisWeek() {
        let now = Self.date(year: 2026, month: 4, day: 15, hour: 11, minute: 0)
        let assignments = [
            Self.makeAssignment(
                id: 1, dueDate: Self.date(year: 2026, month: 4, day: 15, hour: 18, minute: 0)),
            Self.makeAssignment(
                id: 2, dueDate: Self.date(year: 2026, month: 4, day: 17, hour: 9, minute: 0)),
            Self.makeAssignment(
                id: 3, dueDate: Self.date(year: 2026, month: 4, day: 20, hour: 9, minute: 0)),
            Self.makeAssignment(
                id: 4, dueDate: Self.date(year: 2026, month: 4, day: 14, hour: 9, minute: 0)),
            Self.makeAssignment(id: 5, dueDate: nil),
        ]

        let count = HomeTabPresentationSupport.remainingAssignmentsThisWeekCount(
            from: assignments,
            now: now,
            calendar: Self.calendar
        )

        #expect(count == 2)
    }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 9 * 60 * 60) ?? .current
        calendar.locale = Locale(identifier: "ja_JP")
        calendar.firstWeekday = 2
        return calendar
    }

    private static func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int
    ) -> Date {
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )

        return calendar.date(from: components) ?? .distantPast
    }

    private static func makeAssignment(id: Int, dueDate: Date?) -> LmsAssignmentItem {
        LmsAssignmentItem(
            id: id,
            courseID: 10,
            courseModuleID: 100 + id,
            courseTitle: "ソフトウェア工学",
            courseShortName: "2026-50001",
            title: "課題\(id)",
            introPreview: nil,
            dueDate: dueDate,
            allowsSubmissionsFromDate: nil,
            cutoffDate: nil,
            updatedAt: nil
        )
    }
}
