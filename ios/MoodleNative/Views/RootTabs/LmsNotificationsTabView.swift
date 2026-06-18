import MoodleNativeCore
import SwiftUI

struct LmsNotificationsTabView: View {
    @Environment(\.lmsSession) private var session
    @State private var isSelectingNotifications = false
    @State private var selectedNotificationIDs = Set<String>()
    @State private var showsUnreadOnly = false
    let viewModel: NotificationsViewModel

    init(viewModel: NotificationsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Group {
                    if session == nil {
                        ContentUnavailableView(
                            "notifications.loginRequired.title",
                            systemImage: "bell.badge",
                            description: Text("notifications.loginRequired.description")
                        )
                    } else if viewModel.isLoading {
                        LoadingOverlayCard("notifications.loading")
                    } else if let errorMessage = viewModel.errorMessage, viewModel.notifications.isEmpty {
                        ContentUnavailableView(
                            "notifications.unavailable.title",
                            systemImage: "exclamationmark.triangle",
                            description: Text(errorMessage)
                        )
                    } else if viewModel.notifications.isEmpty {
                        ContentUnavailableView(
                            "notifications.empty.title",
                            systemImage: "bell",
                            description: Text("notifications.empty.description")
                        )
                    } else if visibleNotifications.isEmpty {
                        ContentUnavailableView(
                            "notifications.unreadEmpty.title",
                            systemImage: "bell.badge",
                            description: Text("notifications.unreadEmpty.description")
                        )
                    } else {
                        List {
                            ForEach(visibleNotifications) { notification in
                                if isSelectingNotifications {
                                    Button {
                                        toggleSelection(for: notification)
                                    } label: {
                                        NotificationRow(
                                            notification: notification,
                                            isSelecting: true,
                                            isSelected: selectedNotificationIDs.contains(notification.id)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(canMarkAsRead(notification) == false)
                                } else {
                                    NavigationLink {
                                        LmsNotificationDetailView(notification: notification) {
                                            await viewModel.markAsRead(
                                                notification,
                                                session: session
                                            )
                                        }
                                    } label: {
                                        NotificationRow(notification: notification)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        if canMarkAsRead(notification) {
                                            Button("notifications.action.markRead", systemImage: "checkmark") {
                                                Task {
                                                    await viewModel.markAsRead(
                                                        notification,
                                                        session: session
                                                    )
                                                }
                                            }
                                            .tint(.accentColor)
                                        }
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("tab.notifications")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                if session != nil {
                    ToolbarItem {
                        Button {
                            showsUnreadOnly.toggle()
                        } label: {
                            Image(systemName: showsUnreadOnly ? "envelope.badge.fill" : "envelope.badge")
                        }
                        .accessibilityLabel(
                            showsUnreadOnly
                                ? Text("notifications.filter.showAll")
                                : Text("notifications.filter.unreadOnly")
                        )
                        .accessibilityValue(showsUnreadOnly ? Text("common.on") : Text("common.off"))
                    }
                }

                if visibleNotifications.contains(where: canMarkAsRead(_:)) {
                    if isSelectingNotifications {
                        ToolbarItem {
                            Button("common.cancel") {
                                isSelectingNotifications = false
                                selectedNotificationIDs.removeAll()
                            }
                        }

                        ToolbarSpacer(.fixed)

                        ToolbarItem {
                            Button {
                                Task {
                                    await markSelectedNotificationsAsRead()
                                }
                            } label: {
                                Image(systemName: "checkmark")
                            }
                            .accessibilityLabel(Text("notifications.action.markSelectedRead"))
                            .disabled(selectedUnreadNotifications.isEmpty || viewModel.isMarkingNotificationsRead)
                        }
                    } else {
                        ToolbarItem {
                            Button("common.select") {
                                isSelectingNotifications = true
                                selectedNotificationIDs.removeAll()
                            }
                        }
                    }
                }
            }
            .onChange(of: visibleNotifications.map(\.id)) {
                selectedNotificationIDs.formIntersection(Set(visibleNotifications.map(\.id)))
                if visibleNotifications.contains(where: canMarkAsRead(_:)) == false {
                    isSelectingNotifications = false
                    selectedNotificationIDs.removeAll()
                }
            }
            .task(id: taskID) {
                await viewModel.loadIfNeeded(session: session)
            }
            .refreshable {
                await viewModel.refresh(session: session)
            }
            .safeAreaBar(edge: .bottom) {
                if showsMarkAllReadBar {
                    markAllReadActionPanel
                }
            }
        }
    }

    private var visibleNotifications: [NotificationListItem] {
        viewModel.notifications.filter {
            showsUnreadOnly == false || $0.isUnread
        }
    }

    private var selectedUnreadNotifications: [NotificationListItem] {
        visibleNotifications.filter {
            canMarkAsRead($0) && selectedNotificationIDs.contains($0.id)
        }
    }

    private var taskID: String {
        session?.token ?? "none"
    }

    private var showsMarkAllReadBar: Bool {
        session != nil
            && viewModel.unreadCount > 0
            && isSelectingNotifications == false
    }

    private var markAllReadActionPanel: some View {
        Button {
            Task {
                await viewModel.markAllLmsNotificationsAsRead(session: session)
            }
        } label: {
            if viewModel.isMarkingNotificationsRead {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("common.processing")
                }
            } else {
                Text("notifications.action.markAllRead")
            }
        }
        .controlSize(.large)
        .padding(.bottom, 16)
        .buttonSizing(.fitted)
        .buttonStyle(.glassProminent)
        .disabled(viewModel.isMarkingNotificationsRead)
        .accessibilityLabel(Text("notifications.action.markAllLmsRead"))
    }

    private func toggleSelection(for notification: NotificationListItem) {
        guard canMarkAsRead(notification) else {
            return
        }

        if selectedNotificationIDs.contains(notification.id) {
            selectedNotificationIDs.remove(notification.id)
        } else {
            selectedNotificationIDs.insert(notification.id)
        }
    }

    private func markSelectedNotificationsAsRead() async {
        let notifications = selectedUnreadNotifications
        await viewModel.markAsRead(notifications, session: session)
        selectedNotificationIDs.subtract(notifications.map(\.id))

        if selectedUnreadNotifications.isEmpty {
            isSelectingNotifications = false
        }
    }

    private func canMarkAsRead(_ notification: NotificationListItem) -> Bool {
        notification.isUnread && notification.lmsNotificationID != nil
    }
}

#Preview {
    LmsNotificationsTabView(viewModel: NotificationsViewModel())
}
