import MoodleNativeCore
import MoodleNativeNetworking
import SwiftUI

struct LmsMessagePreferencesView: View {
    let session: LmsAuthenticationSession?

    @State private var viewModel = LmsMessagePreferencesViewModel()

    var body: some View {
        List {
            if viewModel.isLoading && viewModel.preferences == nil {
                loadingSection
            } else if let preferences = viewModel.preferences {
                Section("messagePreferences.contactScope.section") {
                    Picker(
                        "messagePreferences.contactScope.picker",
                        selection: Binding(
                            get: { preferences.blockNonContacts },
                            set: { value in
                                Task {
                                    await viewModel.setContactablePrivacy(value, session: session)
                                }
                            }
                        )
                    ) {
                        Text("messagePreferences.contactScope.courseMembers").tag(0)
                        Text("messagePreferences.contactScope.contactsOnly").tag(1)
                        if viewModel.allowsSiteMessaging || preferences.blockNonContacts == 2 {
                            Text("messagePreferences.contactScope.siteWide").tag(2)
                        }
                    }
                    .pickerStyle(.inline)
                    .disabled(viewModel.isUpdating("message_blocknoncontacts"))
                }

                if let notification = viewModel.instantMessageNotification {
                    Section("messagePreferences.instantMessages.section") {
                        ForEach(notification.processors) { processor in
                            processorRow(processor)
                        }
                    }
                }

                if preferences.notificationPreferences.disableAll {
                    Section {
                        Text("messagePreferences.notificationsDisabledWarning")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            } else {
                unavailableSection
            }
        }
        .navigationTitle(String(localized: "messagePreferences.title"))
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if viewModel.isLoading && viewModel.preferences != nil {
                ProgressView()
            }
        }
        .refreshable {
            await viewModel.load(session: session)
        }
        .task(id: session) {
            await viewModel.load(session: session)
        }
    }

    private func processorRow(_ processor: LmsWebServiceClient.NotificationPreferenceProcessor) -> some View {
        Toggle(
            processor.displayName,
            isOn: Binding(
                get: { processor.enabled ?? false },
                set: { isEnabled in
                    Task {
                        await viewModel.setProcessorEnabled(
                            isEnabled,
                            processor: processor,
                            session: session
                        )
                    }
                }
            )
        )
        .disabled(
            processor.locked
                || viewModel.preferences?.notificationPreferences.disableAll == true
                || viewModel.isUpdating("message_provider_moodle_instantmessage_enabled")
        )
    }

    private var loadingSection: some View {
        Section {
            HStack(spacing: 12) {
                ProgressView()
                Text("messagePreferences.loading")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var unavailableSection: some View {
        Section {
            ContentUnavailableView(
                "messagePreferences.unavailable.title",
                systemImage: "message.badge",
                description: Text(viewModel.errorMessage ?? String(localized: "common.loginRequiredBeforeOpening"))
            )
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
}

#Preview {
    NavigationStack {
        LmsMessagePreferencesView(session: nil)
    }
}
