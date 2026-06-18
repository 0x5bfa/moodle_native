import Foundation
import MoodleNativeCore

public enum HomeTabPresentationSupport {
    public static func navigationTitle(
        for date: Date,
        locale: Locale = Locale(identifier: "ja_JP")
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "M月d日(E)"
        return formatter.string(from: date)
    }

    public static func remainingCoursesToday(
        from summaries: [LmsCourseSummary],
        now: Date = .now,
        calendar: Calendar? = nil
    ) -> [HomeRemainingCourse] {
        let calendar = calendar ?? academicCalendar

        guard let weekdayIndex = weekdayIndex(for: now, calendar: calendar) else {
            return []
        }

        return
            summaries
            .flatMap { summary in
                summary.scheduleSlots
                    .filter { $0.dayIndex == weekdayIndex }
                    .flatMap { slot in
                        slot.periodIndices.map { periodIndex in
                            HomeRemainingCourse(
                                course: summary,
                                periodIndex: periodIndex,
                                room: slot.room ?? summary.courseCode
                            )
                        }
                    }
            }
            .filter { course in
                guard let endDate = periodEndDate(for: course.periodIndex, on: now, calendar: calendar)
                else {
                    return true
                }

                return endDate > now
            }
            .sorted { lhs, rhs in
                if lhs.periodIndex != rhs.periodIndex {
                    return lhs.periodIndex < rhs.periodIndex
                }

                return lhs.course.title.localizedStandardCompare(rhs.course.title) == .orderedAscending
            }
    }

    public static func remainingAssignmentsThisWeekCount(
        from assignments: [LmsAssignmentItem],
        now: Date = .now,
        calendar: Calendar? = nil
    ) -> Int {
        let calendar = calendar ?? academicCalendar

        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return 0
        }

        return assignments.reduce(into: 0) { count, assignment in
            guard let dueDate = assignment.dueDate else {
                return
            }

            guard dueDate >= now, dueDate < weekInterval.end else {
                return
            }

            count += 1
        }
    }

    public static func weekdayIndex(for date: Date, calendar: Calendar? = nil) -> Int? {
        let calendar = calendar ?? academicCalendar

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
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = endMinutes / 60
        components.minute = endMinutes % 60
        components.second = 0
        return calendar.date(from: components)
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
