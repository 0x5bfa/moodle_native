import Foundation
import Testing

@testable import MoodleNative

struct TimetableWidgetTimelineSupportTests {
    @Test func liveActivityClassIsHiddenBeforeTodaySixAM() throws {
        let snapshot = Self.snapshot(dayIndex: 0)
        let now = try Self.date(year: 2026, month: 6, day: 1, hour: 5, minute: 59)

        let nextClass = TimetableWidgetTimelineSupport.liveActivityNextClass(
            in: snapshot,
            now: now,
            calendar: Self.calendar
        )

        #expect(nextClass == nil)
    }

    @Test func liveActivityClassIsShownFromTodaySixAM() throws {
        let snapshot = Self.snapshot(dayIndex: 0)
        let now = try Self.date(year: 2026, month: 6, day: 1, hour: 6, minute: 0)

        let nextClass = TimetableWidgetTimelineSupport.liveActivityNextClass(
            in: snapshot,
            now: now,
            calendar: Self.calendar
        )

        #expect(nextClass?.course.title == "情報理論")
        #expect(nextClass?.dayLabel == "今日")
    }

    @Test func liveActivityClassDoesNotShowTomorrowClass() throws {
        let snapshot = Self.snapshot(dayIndex: 1)
        let now = try Self.date(year: 2026, month: 6, day: 1, hour: 23, minute: 0)

        let nextClass = TimetableWidgetTimelineSupport.liveActivityNextClass(
            in: snapshot,
            now: now,
            calendar: Self.calendar
        )

        #expect(nextClass == nil)
    }

    @Test func periodTimeRangesUseNinetyFiveMinuteClassesWithTenMinuteBreaks() {
        #expect(TimetableWidgetTimelineSupport.periodTimeRange(for: 0) == "9:00-10:35")
        #expect(TimetableWidgetTimelineSupport.periodTimeRange(for: 1) == "10:45-12:20")
        #expect(TimetableWidgetTimelineSupport.periodTimeRange(for: 2) == "13:10-14:45")
        #expect(TimetableWidgetTimelineSupport.periodTimeRange(for: 3) == "14:55-16:30")
        #expect(TimetableWidgetTimelineSupport.periodTimeRange(for: 4) == "16:40-18:15")
        #expect(TimetableWidgetTimelineSupport.periodTimeRange(for: 5) == "18:25-20:00")
    }

    @Test func periodDateIntervalUsesGeneratedPeriodTimes() throws {
        let date = try Self.date(year: 2026, month: 6, day: 1, hour: 0, minute: 0)

        let interval = try #require(
            TimetableWidgetTimelineSupport.periodDateInterval(
                for: 5,
                on: date,
                calendar: Self.calendar
            )
        )

        #expect(interval.start == (try Self.date(year: 2026, month: 6, day: 1, hour: 18, minute: 25)))
        #expect(interval.end == (try Self.date(year: 2026, month: 6, day: 1, hour: 20, minute: 0)))
    }

    private static func snapshot(dayIndex: Int) -> TimetableWidgetSnapshot {
        TimetableWidgetSnapshot(
            lastUpdatedAt: Date(timeIntervalSince1970: 0),
            courses: [
                TimetableWidgetCourse(
                    id: "course-\(dayIndex)",
                    title: "情報理論",
                    room: "AC101",
                    dayIndex: dayIndex,
                    periodIndex: 0
                )
            ]
        )
    }

    private static func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int
    ) throws -> Date {
        try #require(
            calendar.date(
                from: DateComponents(
                    timeZone: calendar.timeZone,
                    year: year,
                    month: month,
                    day: day,
                    hour: hour,
                    minute: minute
                )
            )
        )
    }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ja_JP")
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        calendar.firstWeekday = 2
        return calendar
    }
}
