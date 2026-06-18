import ActivityKit
import SwiftUI
import WidgetKit

/// 次の授業をロック画面と Dynamic Island に表示する Live Activity 定義
struct NextClassLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NextClassLiveActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("次の講義")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(context.state.title)
                        .font(.title3.weight(.bold))
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    Text(context.state.periodTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.secondary.opacity(0.12), in: Capsule())

                    if let room = context.state.room, room.isEmpty == false {
                        Label(room, systemImage: "mappin.and.ellipse")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.secondary.opacity(0.12), in: Capsule())
                    }

                    if let timeRangeText = context.state.timeRangeText {
                        Label(timeRangeText, systemImage: "clock")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.secondary.opacity(0.12), in: Capsule())
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .activityBackgroundTint(Color(red: 0.13, green: 0.17, blue: 0.24))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text("\(context.state.periodTitle) &bull; \(context.state.title)")
                        .font(.subheadline.weight(.bold))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(alignment: .center, spacing: 8) {
                        if let room = context.state.room, room.isEmpty == false {
                            Label(room, systemImage: "mappin.and.ellipse")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.secondary.opacity(0.12), in: Capsule())
                        }

                        if let timeRangeText = context.state.timeRangeText {
                            Label(timeRangeText, systemImage: "clock")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.secondary.opacity(0.12), in: Capsule())
                        }
                    }
                }
            } compactLeading: {
                Text(context.state.periodTitle)
                    .font(.caption2.weight(.bold))
            } compactTrailing: {
                Text(context.state.room ?? "")
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "calendar.badge.clock")
            }
        }
    }
}
