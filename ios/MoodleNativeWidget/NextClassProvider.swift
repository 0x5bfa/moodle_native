import SwiftUI
import WidgetKit

/// 共有された時間割スナップショットから次の授業を計算する TimelineProvider
struct NextClassProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextClassEntry {
        NextClassEntry(
            date: .now,
            nextClass: Self.sampleNextClass,
            lastUpdatedAt: .now,
            hasSyncedCourses: true
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (NextClassEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }

        completion(Self.entry(for: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextClassEntry>) -> Void) {
        let now = Date()
        let entry = Self.entry(for: now)
        let refreshDate = TimetableWidgetTimelineSupport.nextRefreshDate(
            after: entry.nextClass,
            now: now
        )

        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }

    private static func entry(for date: Date) -> NextClassEntry {
        let snapshot = try? TimetableWidgetStore().load()
        let nextClass = snapshot.flatMap {
            TimetableWidgetTimelineSupport.nextClass(in: $0, now: date)
        }

        return NextClassEntry(
            date: date,
            nextClass: nextClass,
            lastUpdatedAt: snapshot?.lastUpdatedAt,
            hasSyncedCourses: snapshot?.courses.isEmpty == false
        )
    }

    private static let sampleNextClass = TimetableWidgetNextClass(
        course: TimetableWidgetCourse(
            id: "sample-1",
            title: "ユーザビリティ工学",
            room: "H301",
            dayIndex: 0,
            periodIndex: 1
        ),
        date: .now,
        periodEndDate: Calendar.current.date(byAdding: .hour, value: 1, to: .now),
        dayLabel: "今日"
    )
}
