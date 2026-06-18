import WidgetKit

/// 次の授業ウィジェットで使うタイムラインエントリ
struct NextClassEntry: TimelineEntry {
    let date: Date
    let nextClass: TimetableWidgetNextClass?
    let lastUpdatedAt: Date?
    let hasSyncedCourses: Bool
}
