import MoodleNativeCore
import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var lmsAuthenticationViewModel: LmsAuthenticationViewModel
    @State private var assignmentsViewModel = AssignmentsViewModel()
    @State private var lmsNotificationsViewModel = NotificationsViewModel()
    @State private var showsLmsLoginSheet = false
    @State private var selectedTab: RootTab

    init(launchConfiguration: AppLaunchConfiguration = .current) {
        _lmsAuthenticationViewModel = State(
            initialValue: launchConfiguration.makeAuthenticationViewModel()
        )
        _selectedTab = State(initialValue: launchConfiguration.initialSelectedTab)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("tab.home", systemImage: "house", value: .home) {
                HomeTabView(
                    selectedTab: $selectedTab,
                    assignmentsViewModel: assignmentsViewModel,
                    notificationsViewModel: lmsNotificationsViewModel
                )
            }

            Tab("tab.assignments", systemImage: "checklist", value: .assignments) {
                AssignmentsTabView(viewModel: assignmentsViewModel)
            }
            .badge(assignmentsBadgeValue)

            Tab("tab.timetable", systemImage: "calendar", value: .timetable) {
                TimetableTabView()
            }

            Tab("tab.notifications", systemImage: "bell", value: .notifications) {
                LmsNotificationsTabView(viewModel: lmsNotificationsViewModel)
            }
            .badge(notificationsBadgeValue)

            Tab("tab.settings", systemImage: "gearshape", value: .settings) {
                SettingsTabView()
            }
        }
        .environment(lmsAuthenticationViewModel)
        .environment(\.lmsSession, lmsAuthenticationViewModel.session)
        .sheet(isPresented: $showsLmsLoginSheet) {
            LoginOnboardingSheetView(isPresented: $showsLmsLoginSheet)
                .environment(lmsAuthenticationViewModel)
                .environment(\.lmsSession, lmsAuthenticationViewModel.session)
                .presentationDetents([.fraction(1.00)])
                .presentationDragIndicator(.hidden)
        }
        .onAppear {
            showsLmsLoginSheet = lmsAuthenticationViewModel.isLoggedIn == false
        }
        .task(id: notificationsTaskID) {
            await refreshAuthenticatedContent()
        }
        .onChange(of: lmsAuthenticationViewModel.isLoggedIn) { _, isLoggedIn in
            if isLoggedIn == false {
                showsLmsLoginSheet = true
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                return
            }

            Task {
                if lmsAuthenticationViewModel.session == nil {
                    await NextClassLiveActivityManager.shared.endAll()
                } else {
                    await NextClassLiveActivityManager.shared.syncFromStoredSnapshot()
                }
            }
        }
    }

    private var notificationsBadgeValue: Int {
        let unreadCount = lmsNotificationsViewModel.unreadCount
        return unreadCount > 0 ? unreadCount : 0
    }

    private var assignmentsBadgeValue: Int {
        let count = assignmentsViewModel.visibleAssignments.count
        return count > 0 ? count : 0
    }

    private var notificationsTaskID: String {
        lmsAuthenticationViewModel.session?.token ?? "none"
    }

    @MainActor
    private func refreshAuthenticatedContent() async {
        async let assignmentsTask = assignmentsViewModel.loadIfNeeded(
            session: lmsAuthenticationViewModel.session
        )
        async let notificationsTask = lmsNotificationsViewModel.loadIfNeeded(session: lmsAuthenticationViewModel.session)
        _ = await (assignmentsTask, notificationsTask)

        if lmsAuthenticationViewModel.session == nil {
            await NextClassLiveActivityManager.shared.endAll()
        } else {
            await NextClassLiveActivityManager.shared.syncFromStoredSnapshot()
        }
    }
}
#Preview {
    ContentView()
}
