import ActivityKit
import Foundation

@MainActor
final class NextClassLiveActivityManager {
    static let shared = NextClassLiveActivityManager()

    private init() {}

    func syncFromStoredSnapshot() async {
        guard AppSettings.NextClassLiveActivity.isEnabled else {
            await endAll()
            return
        }

        guard let snapshot = try? TimetableWidgetStore().load() else {
            await endAll()
            return
        }

        await sync(with: snapshot)
    }

    func sync(with snapshot: TimetableWidgetSnapshot, now: Date = .now) async {
        guard AppSettings.NextClassLiveActivity.isEnabled else {
            await endAll()
            return
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }

        guard let nextClass = TimetableWidgetTimelineSupport.liveActivityNextClass(in: snapshot, now: now) else {
            await endAll()
            return
        }

        let state = makeContentState(for: nextClass)
        let content = ActivityContent(
            state: state,
            staleDate: nextClass.periodEndDate?.addingTimeInterval(5)
        )

        let activities = Activity<NextClassLiveActivityAttributes>.activities
        if let currentActivity = activities.first {
            await currentActivity.update(content)

            for redundantActivity in activities.dropFirst() {
                await redundantActivity.end(nil, dismissalPolicy: .immediate)
            }
            return
        }

        do {
            _ = try Activity<NextClassLiveActivityAttributes>.request(
                attributes: NextClassLiveActivityAttributes(
                    activityID: NextClassLiveActivityAttributes.nextClassActivityID
                ),
                content: content,
                pushType: nil
            )
        } catch {
            return
        }
    }

    func endAll() async {
        for activity in Activity<NextClassLiveActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private func makeContentState(
        for nextClass: TimetableWidgetNextClass
    ) -> NextClassLiveActivityAttributes.ContentState {
        let interval = TimetableWidgetTimelineSupport.periodDateInterval(
            for: nextClass.course.periodIndex,
            on: nextClass.date
        )

        return NextClassLiveActivityAttributes.ContentState(
            title: nextClass.course.title,
            room: nextClass.course.room,
            periodTitle: nextClass.course.periodTitle,
            timeRangeText: TimetableWidgetTimelineSupport.periodTimeRange(
                for: nextClass.course.periodIndex
            ),
            startDate: interval?.start ?? nextClass.date,
            endDate: interval?.end,
        )
    }
}
