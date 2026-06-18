import Foundation

enum MoodleNativeWidgetConstants {
    static let appGroupIdentifier = "group.dev.example.MoodleNative"
    static let nextClassKind = "MoodleNativeNextClassWidget"
    static let timetableSnapshotFilename = "timetable-widget.json"
}

struct TimetableWidgetSnapshot: Codable, Equatable, Sendable {
    let lastUpdatedAt: Date
    let courses: [TimetableWidgetCourse]
}

struct TimetableWidgetCourse: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let room: String?
    let dayIndex: Int
    let periodIndex: Int

    var periodTitle: String {
        "\(periodIndex + 1)限"
    }
}

struct TimetableWidgetNextClass: Equatable, Identifiable, Sendable {
    let course: TimetableWidgetCourse
    let date: Date
    let periodEndDate: Date?
    let dayLabel: String

    var id: String {
        "\(course.id)-\(date.timeIntervalSince1970)"
    }
}

enum TimetableWidgetTimelineSupport {
    static func liveActivityNextClass(
        in snapshot: TimetableWidgetSnapshot,
        now: Date = .now,
        calendar: Calendar? = nil
    ) -> TimetableWidgetNextClass? {
        let calendar = calendar ?? academicCalendar
        guard let availableFrom = liveActivityAvailableDate(on: now, calendar: calendar),
            now >= availableFrom,
            let nextClass = nextClass(in: snapshot, now: now, calendar: calendar),
            calendar.isDate(nextClass.date, inSameDayAs: now)
        else {
            return nil
        }

        return nextClass
    }

    static func nextClass(
        in snapshot: TimetableWidgetSnapshot,
        now: Date = .now,
        calendar: Calendar? = nil
    ) -> TimetableWidgetNextClass? {
        let calendar = calendar ?? academicCalendar
        let startOfToday = calendar.startOfDay(for: now)

        for dayOffset in 0..<7 {
            guard let candidateDate = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday),
                let weekdayIndex = weekdayIndex(for: candidateDate, calendar: calendar)
            else {
                continue
            }

            let courses = snapshot.courses
                .filter { $0.dayIndex == weekdayIndex }
                .filter { course in
                    guard dayOffset == 0,
                        let endDate = periodEndDate(
                            for: course.periodIndex,
                            on: candidateDate,
                            calendar: calendar
                        )
                    else {
                        return true
                    }

                    return endDate > now
                }
                .sorted { lhs, rhs in
                    if lhs.periodIndex != rhs.periodIndex {
                        return lhs.periodIndex < rhs.periodIndex
                    }

                    return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
                }

            guard let course = courses.first else {
                continue
            }

            return TimetableWidgetNextClass(
                course: course,
                date: candidateDate,
                periodEndDate: periodEndDate(for: course.periodIndex, on: candidateDate, calendar: calendar),
                dayLabel: dayLabel(for: candidateDate, now: now, calendar: calendar)
            )
        }

        return nil
    }

    static func nextRefreshDate(
        after nextClass: TimetableWidgetNextClass?,
        now: Date = .now
    ) -> Date {
        if let periodEndDate = nextClass?.periodEndDate,
            periodEndDate > now
        {
            return periodEndDate.addingTimeInterval(5)
        }

        return now.addingTimeInterval(60 * 30)
    }

    static func periodTimeRange(for periodIndex: Int) -> String? {
        guard let period = periodTime(for: periodIndex) else {
            return nil
        }

        return "\(format(period.start))-\(format(period.end))"
    }

    static func periodDateInterval(
        for periodIndex: Int,
        on date: Date,
        calendar: Calendar? = nil
    ) -> DateInterval? {
        let calendar = calendar ?? academicCalendar
        guard let period = periodTime(for: periodIndex) else {
            return nil
        }

        var startComponents = calendar.dateComponents([.year, .month, .day], from: date)
        startComponents.hour = period.start.hour
        startComponents.minute = period.start.minute
        startComponents.second = 0

        var endComponents = calendar.dateComponents([.year, .month, .day], from: date)
        endComponents.hour = period.end.hour
        endComponents.minute = period.end.minute
        endComponents.second = 0

        guard let startDate = calendar.date(from: startComponents),
            let endDate = calendar.date(from: endComponents)
        else {
            return nil
        }

        return DateInterval(start: startDate, end: endDate)
    }

    private static func weekdayIndex(for date: Date, calendar: Calendar) -> Int? {
        switch calendar.component(.weekday, from: date) {
        case 2...6:
            return calendar.component(.weekday, from: date) - 2
        default:
            return nil
        }
    }

    private static func periodEndDate(
        for periodIndex: Int,
        on date: Date,
        calendar: Calendar
    ) -> Date? {
        guard let period = periodTime(for: periodIndex) else {
            return nil
        }

        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = period.end.hour
        components.minute = period.end.minute
        components.second = 0
        return calendar.date(from: components)
    }

    private static func liveActivityAvailableDate(on date: Date, calendar: Calendar) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = 6
        components.minute = 0
        components.second = 0
        return calendar.date(from: components)
    }

    private static func dayLabel(for date: Date, now: Date, calendar: Calendar) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            return "今日"
        }

        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)),
            calendar.isDate(date, inSameDayAs: tomorrow)
        {
            return "明日"
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d(E)"
        return formatter.string(from: date)
    }

    private static func format(_ components: DateComponents) -> String {
        String(format: "%d:%02d", components.hour ?? 0, components.minute ?? 0)
    }

    private static func periodTime(for periodIndex: Int) -> (start: DateComponents, end: DateComponents)? {
        guard periodIndex >= 0 else {
            return nil
        }

        let startMinutes =
            if periodIndex < morningPeriodCount {
                firstPeriodStartMinutes + periodIndex * (classDurationMinutes + breakDurationMinutes)
            } else {
                afternoonFirstPeriodStartMinutes
                    + (periodIndex - morningPeriodCount) * (classDurationMinutes + breakDurationMinutes)
            }
        let endMinutes = startMinutes + classDurationMinutes
        return (
            start: DateComponents(hour: startMinutes / 60, minute: startMinutes % 60),
            end: DateComponents(hour: endMinutes / 60, minute: endMinutes % 60)
        )
    }

    private static let firstPeriodStartMinutes = 9 * 60
    private static let afternoonFirstPeriodStartMinutes = 13 * 60 + 10
    private static let morningPeriodCount = 2
    private static let classDurationMinutes = 95
    private static let breakDurationMinutes = 10

    private static var academicCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ja_JP")
        calendar.timeZone = .current
        calendar.firstWeekday = 2
        return calendar
    }
}
