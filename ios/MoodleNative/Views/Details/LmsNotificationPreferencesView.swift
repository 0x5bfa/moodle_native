import MoodleNativeCore
import MoodleNativeNetworking
import SwiftUI

struct LmsNotificationPreferencesView: View {
    let session: LmsAuthenticationSession?

    @State private var viewModel = LmsNotificationPreferencesViewModel()

    var body: some View {
        @Bindable var viewModel = viewModel

        List {
            if viewModel.isLoading && viewModel.preferences == nil {
                loadingSection
            } else if let preferences = viewModel.preferences {
                Section {
                    Toggle(
                        "notificationPreferences.enableAll",
                        isOn: Binding(
                            get: { preferences.enableAll },
                            set: { isEnabled in
                                Task {
                                    await viewModel.setAllNotificationsEnabled(
                                        isEnabled,
                                        session: session
                                    )
                                }
                            }
                        )
                    )
                    .disabled(viewModel.isUpdating("emailstop"))

                }

                if preferences.processors.count > 1 {
                    Section {
                        Picker("notificationPreferences.processor", selection: $viewModel.selectedProcessorName) {
                            ForEach(preferences.processors) { processor in
                                Text(processor.displayName).tag(Optional(processor.name))
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                if viewModel.selectedProcessorComponents.isEmpty {
                    emptySection
                } else {
                    ForEach(viewModel.selectedProcessorComponents) { component in
                        Section {
                            ForEach(component.notifications) { notification in
                                notificationRow(notification)
                            }
                        } header: {
                            componentHeader(component)
                        }
                    }
                }
            } else {
                unavailableSection
            }
        }
        .navigationTitle(String(localized: "notificationPreferences.title"))
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if viewModel.isLoading && viewModel.preferences != nil {
                ProgressView()
                    .controlSize(.regular)
            }
        }
        .refreshable {
            await viewModel.load(session: session)
        }
        .task(id: session) {
            await viewModel.load(session: session)
        }
    }

    @ViewBuilder
    private func componentHeader(_ component: LmsWebServiceClient.NotificationPreferencesComponent)
        -> some View
    {
        if let description = component.description, description.isEmpty == false {
            VStack(alignment: .leading, spacing: 4) {
                Text(component.displayName)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        } else {
            Text(component.displayName)
        }
    }

    private var loadingSection: some View {
        Section {
            HStack(spacing: 12) {
                ProgressView()
                Text("notificationPreferences.loading")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var unavailableSection: some View {
        Section {
            ContentUnavailableView(
                "notificationPreferences.unavailable.title",
                systemImage: "bell.slash",
                description: Text(viewModel.errorMessage ?? String(localized: "common.loginRequiredBeforeOpening"))
            )
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    private var emptySection: some View {
        Section {
            ContentUnavailableView(
                "notificationPreferences.empty.title",
                systemImage: "bell",
                description: Text("notificationPreferences.empty.description")
            )
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private func notificationRow(_ notification: LmsWebServiceClient.NotificationPreference) -> some View {
        if let processor = selectedProcessor(for: notification), let enabled = processor.enabled {
            Toggle(
                notification.displayName,
                isOn: Binding(
                    get: { enabled },
                    set: { isEnabled in
                        Task {
                            await viewModel.setNotificationEnabled(
                                isEnabled,
                                notification: notification,
                                session: session
                            )
                        }
                    }
                )
            )
            .disabled(processor.locked || viewModel.isUpdating("\(notification.preferenceKey)_\(processor.name)"))
        } else if let processor = selectedProcessor(for: notification) {
            VStack(alignment: .leading, spacing: 12) {
                Text(notification.displayName)

                if let loggedIn = processor.loggedIn {
                    legacyToggle(
                        state: loggedIn,
                        notification: notification,
                        isLocked: processor.locked
                    )
                }

                if let loggedOff = processor.loggedOff {
                    legacyToggle(
                        state: loggedOff,
                        notification: notification,
                        isLocked: processor.locked
                    )
                }
            }
        }
    }

    private func legacyToggle(
        state: LmsWebServiceClient.NotificationPreferenceProcessorState,
        notification: LmsWebServiceClient.NotificationPreference,
        isLocked: Bool
    ) -> some View {
        let key = "\(notification.preferenceKey)_\(state.name)"

        return Toggle(
            state.displayName,
            isOn: Binding(
                get: { state.checked },
                set: { isEnabled in
                    Task {
                        await viewModel.setLegacyNotificationState(
                            isEnabled,
                            stateName: state.name,
                            notification: notification,
                            session: session
                        )
                    }
                }
            )
        )
        .font(.subheadline)
        .disabled(isLocked || viewModel.isUpdating(key))
    }

    private func selectedProcessor(
        for notification: LmsWebServiceClient.NotificationPreference
    ) -> LmsWebServiceClient.NotificationPreferenceProcessor? {
        guard let selectedProcessor = viewModel.selectedProcessor else {
            return nil
        }

        return notification.processor(named: selectedProcessor.name)
    }
}

#Preview {
    NavigationStack {
        LmsNotificationPreferencesView(session: nil)
    }
}
