import SwiftUI
import WidgetKit

/// 同期済みの時間割から次の授業を表示するホーム画面ウィジェット
struct NextClassWidget: Widget {
    @Environment(\.widgetFamily) private var widgetFamily

    let kind = MoodleNativeWidgetConstants.nextClassKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextClassProvider()) { entry in
            Group {
                switch widgetFamily {
                case .accessoryRectangular:
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.clock")

                        if let nextClass = entry.nextClass {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("\(nextClass.dayLabel) \(nextClass.course.periodTitle)")
                                    .font(.caption.weight(.semibold))
                                Text(nextClass.course.title)
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                        } else {
                            Text(entry.hasSyncedCourses ? "次の授業なし" : "時間割を同期")
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                        }
                    }
                case .systemSmall:
                    VStack(alignment: .leading, spacing: 8) {
                        Text("次の講義")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.secondary)

                        if let nextClass = entry.nextClass {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(nextClass.course.title)
                                    .font(.headline)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.72)

                                HStack(spacing: 8) {
                                    Text("\(nextClass.dayLabel) \(nextClass.course.periodTitle)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)

                                    if let room = nextClass.course.room, room.isEmpty == false {
                                        Text(room)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }

                                    if widgetFamily != .systemSmall,
                                        let periodTimeRange = TimetableWidgetTimelineSupport.periodTimeRange(
                                            for: nextClass.course.periodIndex
                                        )
                                    {
                                        Text(periodTimeRange)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(entry.hasSyncedCourses ? "次の授業はありません" : "時間割を同期してください")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)

                                Text(entry.hasSyncedCourses ? "次の平日まで更新を待っています。" : "アプリでMoodleにログインして時間割を開くと表示されます。")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                        }
                    }
                default:
                    VStack(alignment: .leading, spacing: 8) {
                        Text("次の講義")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.secondary)

                        if let nextClass = entry.nextClass {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(nextClass.course.title)
                                    .font(.title3.weight(.bold))
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.72)

                                HStack(spacing: 8) {
                                    Text("\(nextClass.dayLabel) \(nextClass.course.periodTitle)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(.secondary.opacity(0.12), in: Capsule())

                                    if let room = nextClass.course.room, room.isEmpty == false {
                                        Label(room, systemImage: "mappin.and.ellipse")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(.secondary.opacity(0.12), in: Capsule())
                                    }

                                    if widgetFamily != .systemSmall,
                                        let periodTimeRange = TimetableWidgetTimelineSupport.periodTimeRange(
                                            for: nextClass.course.periodIndex
                                        )
                                    {
                                        Label(periodTimeRange, systemImage: "clock")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(.secondary.opacity(0.12), in: Capsule())
                                    }
                                }
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(entry.hasSyncedCourses ? "次の授業はありません" : "時間割を同期してください")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)

                                Text(entry.hasSyncedCourses ? "次の平日まで更新を待っています。" : "アプリでMoodleにログインして時間割を開くと表示されます。")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .containerBackground(for: .widget) {
                Color(uiColor: .systemBackground)
            }
        }
        .configurationDisplayName("次の授業")
        .description("Moodleの時間割から、次に受ける授業を表示します。")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

#Preview(as: .systemSmall) {
    NextClassWidget()
} timeline: {
    NextClassEntry(
        date: .now,
        nextClass: TimetableWidgetNextClass(
            course: TimetableWidgetCourse(
                id: "preview-1",
                title: "ユーザビリティ工学",
                room: "H301",
                dayIndex: 0,
                periodIndex: 1
            ),
            date: .now,
            periodEndDate: Calendar.current.date(byAdding: .hour, value: 1, to: .now),
            dayLabel: "今日"
        ),
        lastUpdatedAt: .now,
        hasSyncedCourses: true
    )
}
