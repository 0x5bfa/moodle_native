import MoodleNativeCore
import MoodleNativeFeatures
import SwiftUI

struct HomeTabView: View {
    @Environment(LmsAuthenticationViewModel.self) private var lmsAuthenticationViewModel
    @Environment(\.lmsSession) private var session
    @Binding var selectedTab: RootTab
    let assignmentsViewModel: AssignmentsViewModel
    let notificationsViewModel: NotificationsViewModel

    @State private var timetableViewModel = TimetableViewModel(
        navigationPath: String(localized: "navigationPath.home"),
        pageTitle: String(localized: "tab.home")
    )

    var body: some View {
        NavigationStack {
            List {
                nextClassesSection
                assignmentsSection

                notificationsSection
            }
            .navigationTitle(greetingTitle)
            .navigationSubtitle(dateSubtitle)
            .toolbarTitleDisplayMode(.inlineLarge)
            .task(id: taskID) {
                await loadIfNeeded()
            }
            .refreshable {
                await refresh()
            }
        }
    }

    private var nextClassesSection: some View {
        Section("home.nextClasses.section") {
            if session == nil {
                Text("home.nextClasses.loginRequired")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if timetableViewModel.isLoading && upcomingCourses.isEmpty {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("timetable.loading")
                        .foregroundStyle(.secondary)
                }
            } else if let errorMessage = timetableViewModel.errorMessage, upcomingCourses.isEmpty {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.orange)
            } else if upcomingCourses.isEmpty {
                Text("home.nextClasses.empty")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(upcomingCourses.prefix(3), id: \.id) { course in
                    if let summary = timetableViewModel.courseSummary(for: course) {
                        NavigationLink {
                            LmsCourseDetailView(
                                course: summary,
                                navigationPath: String(localized: "navigationPath.home.nextClass.courseDetail")
                            )
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Circle()
                                    .fill(Color(.systemGray4))
                                    .frame(width: 12, height: 12)
                                    .padding(.top, 6)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(course.title)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)

                                    Text(classSummaryLine(for: course))
                                        .font(.body)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    private var assignmentsSection: some View {
        Section {
            if session == nil {
                Text("home.assignments.loginRequired")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if assignmentsViewModel.isLoading && topAssignments.isEmpty {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("assignments.loading")
                        .foregroundStyle(.secondary)
                }
            } else if let errorMessage = assignmentsViewModel.errorMessage, topAssignments.isEmpty {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.orange)
            } else if topAssignments.isEmpty {
                Text("home.assignments.empty")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if let session {
                ForEach(topAssignments) { assignment in
                    NavigationLink {
                        LmsAssignmentDetailView(
                            assignment: assignment.reference(siteURL: session.siteURL),
                            navigationPath: String(localized: "navigationPath.home.assignmentDetail")
                        )
                    } label: {
                        HStack(alignment: .top, spacing: 4) {
                            VStack(alignment: .leading) {
                                Text(assignment.title)
                                    .font(.headline)
                                    .lineLimit(2)

                                Text(assignment.courseTitle)
                                    .font(.body)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text(assignment.dueDateLine())
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .contentShape(Rectangle())
                    }
                }
            }
        } header: {
            HStack {
                Text("home.assignments.section")

                Spacer()

                Button("home.showAll") {
                    selectedTab = .assignments
                }
                .font(.caption.weight(.semibold))
            }
        }
    }

    private var notificationsSection: some View {
        Section {
            if session == nil {
                Text("home.notifications.loginRequired")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if notificationsViewModel.isLoading && topNotifications.isEmpty {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("notifications.loading")
                        .foregroundStyle(.secondary)
                }
            } else if let errorMessage = notificationsViewModel.errorMessage, topNotifications.isEmpty {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.orange)
            } else if topNotifications.isEmpty {
                Text("notifications.empty.title")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(topNotifications) { notification in
                    NavigationLink {
                        LmsNotificationDetailView(notification: notification) {
                            await notificationsViewModel.markAsRead(notification, session: session)
                        }
                    } label: {
                        NotificationRow(notification: notification)
                    }
                }
            }
        } header: {
            HStack {
                Text("home.notifications.section")

                Spacer()

                Button("home.showAll") {
                    selectedTab = .notifications
                }
                .font(.caption.weight(.semibold))
            }
        }
    }

    private var greetingTitle: String {
        let hour = Calendar.current.component(.hour, from: .now)

        switch hour {
        case 5..<12:
            return String(localized: "home.greeting.morning")
        case 12..<18:
            return String(localized: "home.greeting.afternoon")
        default:
            return String(localized: "home.greeting.evening")
        }
    }

    private var dateSubtitle: String {
        Date.now.formatted(.dateTime.month().day().weekday(.abbreviated))
    }

    private var taskID: String {
        session?.token ?? "none"
    }

    private var upcomingCourses: [TimetableCourse] {
        timetableViewModel.courses
            .filter {
                $0.dayIndex != nil
                    && $0.periodIndex != nil
                    && timetableViewModel.courseSummary(for: $0) != nil
                    && nextDate(for: $0) != nil
            }
            .sorted { lhs, rhs in
                let lhsDate = nextDate(for: lhs) ?? .distantFuture
                let rhsDate = nextDate(for: rhs) ?? .distantFuture
                if lhsDate != rhsDate {
                    return lhsDate < rhsDate
                }

                let lhsPeriod = lhs.periodIndex ?? .max
                let rhsPeriod = rhs.periodIndex ?? .max
                if lhsPeriod != rhsPeriod {
                    return lhsPeriod < rhsPeriod
                }

                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
    }

    private var topAssignments: ArraySlice<LmsAssignmentItem> {
        assignmentsViewModel.visibleAssignments.prefix(3)
    }

    private var topNotifications: ArraySlice<NotificationListItem> {
        notificationsViewModel.notifications.prefix(3)
    }

    @MainActor
    private func loadIfNeeded() async {
        async let assignmentsTask = assignmentsViewModel.loadIfNeeded(session: session)
        async let timetableTask = timetableViewModel.loadIfNeeded(
            session: session,
            userIDResolved: lmsAuthenticationViewModel.updateSessionUserID
        )
        async let notificationsTask = notificationsViewModel.loadIfNeeded(session: session)
        _ = await (assignmentsTask, timetableTask, notificationsTask)
    }

    @MainActor
    private func refresh() async {
        async let assignmentsTask = assignmentsViewModel.refresh(session: session)
        async let timetableTask = timetableViewModel.refresh(
            session: session,
            userIDResolved: lmsAuthenticationViewModel.updateSessionUserID
        )
        async let notificationsTask = notificationsViewModel.refresh(session: session)
        _ = await (assignmentsTask, timetableTask, notificationsTask)
    }

    private func classSummaryLine(for course: TimetableCourse) -> String {
        var components = [String]()
        if let periodTitle = periodTitle(for: course) {
            components.append(periodTitle)
        }
        if let room = course.room?.trimmingCharacters(in: .whitespacesAndNewlines),
            room.isEmpty == false
        {
            components.append(room)
        }

        return components.isEmpty ? String(localized: "home.nextClasses.periodRoomUnset") : components.joined(separator: " ")
    }

    private func periodTitle(for course: TimetableCourse) -> String? {
        guard let periodIndex = course.periodIndex else {
            return nil
        }

        if course.periodSpan > 1 {
            return String(
                format: String(localized: "home.nextClasses.periodRange"),
                periodIndex + 1,
                periodIndex + course.periodSpan
            )
        }

        return String(
            format: String(localized: "home.nextClasses.period"),
            periodIndex + 1
        )
    }

    private func nextDate(
        for course: TimetableCourse,
        now: Date = .now,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> Date? {
        guard let courseDayIndex = course.dayIndex else {
            return nil
        }

        let startOfToday = calendar.startOfDay(for: now)

        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday),
                weekdayIndex(for: date, calendar: calendar) == courseDayIndex
            else {
                continue
            }

            if dayOffset == 0,
                let periodIndex = course.periodIndex,
                let interval = TimetableWidgetTimelineSupport.periodDateInterval(
                    for: periodIndex,
                    on: date,
                    calendar: calendar
                ),
                interval.end <= now
            {
                continue
            }

            return date
        }

        return nil
    }

    private func weekdayIndex(for date: Date, calendar: Calendar) -> Int? {
        switch calendar.component(.weekday, from: date) {
        case 2...6:
            return calendar.component(.weekday, from: date) - 2
        default:
            return nil
        }
    }
}

#Preview {
    HomeTabView(
        selectedTab: .constant(.home),
        assignmentsViewModel: AssignmentsViewModel(),
        notificationsViewModel: NotificationsViewModel()
    )
}
