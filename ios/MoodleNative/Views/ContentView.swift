import MoodleNativeCore
import SwiftUI
#if targetEnvironment(macCatalyst)
import UIKit
#endif

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var lmsAuthenticationViewModel: LmsAuthenticationViewModel
    @State private var assignmentsViewModel = AssignmentsViewModel()
    @State private var lmsNotificationsViewModel = NotificationsViewModel()
    @State private var showsLmsLoginSheet = false
    @Binding private var selectedTab: RootTab
    #if targetEnvironment(macCatalyst)
    @State private var sidebarColumnVisibility: NavigationSplitViewVisibility = .all
    @State private var isSidebarToggleHovered = false
    #endif

    init(
        selectedTab: Binding<RootTab>,
        launchConfiguration: AppLaunchConfiguration = .current
    ) {
        _selectedTab = selectedTab
        _lmsAuthenticationViewModel = State(
            initialValue: launchConfiguration.makeAuthenticationViewModel()
        )
    }

    var body: some View {
        rootNavigation
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
            .onOpenURL { url in
                _ = LmsAuthenticationCallbackCoordinator.shared.handleIncomingURL(url)
            }
            #if targetEnvironment(macCatalyst)
            .onAppear(perform: scheduleMacWindowSizeRelaxation)
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                scheduleMacWindowSizeRelaxation()
            }
            .onChange(of: selectedTab) { _, _ in
                resetDetailNavigation()
            }
            #endif
    }

    @ViewBuilder
    private var rootNavigation: some View {
        #if targetEnvironment(macCatalyst)
        NavigationSplitView(columnVisibility: $sidebarColumnVisibility) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Text(verbatim: "Moodle Native")
                        .font(.title.weight(.bold))
                        .foregroundStyle(.primary)
                        .accessibilityAddTraits(.isHeader)

                    Spacer(minLength: 8)

                    Button(action: toggleSidebar) {
                        Image(systemName: "sidebar.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(isSidebarToggleHovered ? .primary : .secondary)
                            .frame(width: 30, height: 26)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(isSidebarToggleHovered ? Color.primary.opacity(0.10) : .clear)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .onHover { isSidebarToggleHovered = $0 }
                    .accessibilityLabel("サイドバーを切り替え")
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 8)

                LazyVStack(spacing: 6) {
                    ForEach(RootTab.allCases) { tab in
                        MacSidebarTabRow(
                            tab: tab,
                            badgeValue: badgeValue(for: tab),
                            isSelected: selectedTab == tab,
                            isWindowActive: scenePhase == .active
                        ) {
                            if selectedTab == tab {
                                // Re-tapping the active tab pops its detail stack back to the list.
                                resetDetailNavigation(animated: true)
                            } else {
                                selectedTab = tab
                            }
                        }
                    }
                }
                .padding(.horizontal, 10)

                Spacer(minLength: 0)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        } detail: {
            tabContent(selectedTab)
                .id(selectedTab)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .navigationSplitViewStyle(.balanced)
        #else
        TabView(selection: $selectedTab) {
            ForEach(RootTab.allCases) { tab in
                Tab(tab.titleKey, systemImage: tab.systemImage, value: tab) {
                    tabContent(tab)
                }
                .badge(badgeValue(for: tab))
            }
        }
        #endif
    }

    @ViewBuilder
    private func tabContent(_ tab: RootTab) -> some View {
        switch tab {
        case .home:
            HomeTabView(
                selectedTab: $selectedTab,
                assignmentsViewModel: assignmentsViewModel,
                notificationsViewModel: lmsNotificationsViewModel
            )
        case .assignments:
            AssignmentsTabView(viewModel: assignmentsViewModel)
        case .timetable:
            TimetableTabView()
        case .notifications:
            LmsNotificationsTabView(viewModel: lmsNotificationsViewModel)
        case .settings:
            SettingsTabView()
        }
    }

    private func badgeValue(for tab: RootTab) -> Int {
        switch tab {
        case .assignments:
            return assignmentsBadgeValue
        case .notifications:
            return notificationsBadgeValue
        default:
            return 0
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

    #if targetEnvironment(macCatalyst)
    /// Collapse/expand the sidebar column. When collapsed (`.detailOnly`) the custom toggle in the
    /// header disappears with the sidebar, so re-expansion is driven by the native toggle that the
    /// split view exposes in the detail column's navigation bar.
    private func toggleSidebar() {
        withAnimation(.easeInOut(duration: 0.2)) {
            sidebarColumnVisibility = (sidebarColumnVisibility == .detailOnly) ? .all : .detailOnly
        }
    }

    /// Pop all pushed UINavigationController stacks in the NavigationSplitView's secondary column
    /// so that switching tabs via the sidebar always shows the selected tab's root view.
    /// - Parameter animated: Use a sliding pop animation. `true` for re-tapping the active tab
    ///   (the detail stays on screen, so the pop should animate); `false` for switching to another
    ///   tab, where `.id(selectedTab)` swaps the whole detail and an animated pop would be unseen.
    private func resetDetailNavigation(animated: Bool = false) {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                guard let root = window.rootViewController,
                      let split = findSplitVC(in: root),
                      let secondary = split.viewControllers.last else { continue }
                popNavControllers(in: secondary, animated: animated)
                return
            }
        }
    }

    private func findSplitVC(in vc: UIViewController) -> UISplitViewController? {
        if let s = vc as? UISplitViewController { return s }
        return vc.children.lazy.compactMap { findSplitVC(in: $0) }.first
    }

    private func popNavControllers(in vc: UIViewController, animated: Bool) {
        if let nav = vc as? UINavigationController {
            nav.popToRootViewController(animated: animated)
        }
        vc.children.forEach { popNavControllers(in: $0, animated: animated) }
    }

    /// Mac Catalyst keeps a default `UIWindowScene.sizeRestrictions.maximumSize`, which caps how
    /// far the window can grow. Lift it so the window scales up to full screen like a native Mac
    /// app (e.g. Mail), while keeping a sensible minimum size.
    private func scheduleMacWindowSizeRelaxation() {
        relaxMacWindowSizeRestrictions()
        Task { @MainActor in
            for delayMilliseconds in [50, 200, 600] {
                try? await Task.sleep(for: .milliseconds(delayMilliseconds))
                relaxMacWindowSizeRestrictions()
            }
        }
    }

    private func relaxMacWindowSizeRestrictions() {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }

            let screenBounds = windowScene.screen.bounds.size
            let unrestrictedMaximum = CGSize(
                width: max(screenBounds.width, 4_096),
                height: max(screenBounds.height, 4_096)
            )

            windowScene.sizeRestrictions?.minimumSize = CGSize(width: 820, height: 600)
            windowScene.sizeRestrictions?.maximumSize = unrestrictedMaximum

            // Run the sidebar to the very top of the window (native Liquid Glass look): hide the
            // window title, unify the toolbar with the content, and drop the separator so the
            // traffic-light area blends into the sidebar background instead of sitting in a
            // distinct title bar above it.
            if let titlebar = windowScene.titlebar {
                titlebar.titleVisibility = .hidden
                titlebar.toolbarStyle = .unified
                titlebar.separatorStyle = .none
            }
        }
    }
    #endif
}

#if targetEnvironment(macCatalyst)
/// A click-only sidebar row. SwiftUI `List(.sidebar)` is backed by a focusable collection view on
/// Mac Catalyst, which retains keyboard focus independently from selection and can reveal a stale
/// halo around a previously selected row. Plain rows have no UIKit focus item to retain.
private struct MacSidebarTabRow: View {
    let tab: RootTab
    let badgeValue: Int
    let isSelected: Bool
    let isWindowActive: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: tab.systemImage)
                .frame(width: 24)

            Text(tab.titleKey)
                .lineLimit(1)

            Spacer(minLength: 8)

            if badgeValue > 0 {
                Text(verbatim: "\(badgeValue)")
                    .font(.system(size: 15, weight: .medium).monospacedDigit())
            }
        }
        .font(.system(size: 17, weight: .medium))
        .foregroundStyle(foregroundStyle)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
        .background(backgroundStyle, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction {
            action()
        }
        .animation(.easeOut(duration: 0.10), value: isHovered)
        .animation(.easeOut(duration: 0.10), value: isSelected)
    }

    private var foregroundStyle: Color {
        if isSelected {
            return isWindowActive ? .white : .accentColor
        }
        return .primary
    }

    private var backgroundStyle: Color {
        if isSelected {
            return isWindowActive ? .accentColor : Color.primary.opacity(0.08)
        }
        return isHovered ? Color.primary.opacity(0.06) : .clear
    }
}
#endif

#Preview {
    ContentView(selectedTab: .constant(.home))
}
