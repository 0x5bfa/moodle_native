import MoodleNativeCore
import MoodleNativeNetworking
import SwiftUI

struct SettingsTabView: View {
    @Environment(LmsAuthenticationViewModel.self) private var lmsAuthenticationViewModel
    @Environment(\.lmsSession) private var lmsSession
    @AppStorage(CoursesDisplayMode.storageKey) private var displayModeRawValue = CoursesDisplayMode.timetable.rawValue
    @AppStorage(TimetableViewModel.selectedSemesterStorageKey) private var selectedSemesterID = ""
    @AppStorage(AppSettings.NextClassLiveActivity.storageKey)
    private var isNextClassLiveActivityEnabled = AppSettings.NextClassLiveActivity.defaultValue
    @AppStorage(AppSettings.ExternalLinks.preferInAppStorageKey)
    private var prefersInAppExternalLinks = AppSettings.ExternalLinks.preferInAppDefaultValue
    #if DEBUG
        @AppStorage(DebugTimetableFixtureStore.selectionStorageKey)
        private var debugTimetableFixtureID = DebugTimetableFixtureStore.noneFixtureID
    #endif
    @State private var viewModel = SettingsViewModel()
    @State private var profileViewModel = SettingsProfileViewModel()
    @State private var timetableViewModel = TimetableViewModel(
        navigationPath: String(localized: "navigationPath.settings.display"),
        pageTitle: String(localized: "settings.title")
    )

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            Form {
                profileSection
                displaySection
                #if DEBUG
                    debugSection
                #endif
                storageSection
                versionSection
            }
            .navigationTitle("settings.title")
            .toolbarTitleDisplayMode(.inlineLarge)
            .alert(
                viewModel.activeAlert?.title ?? "",
                isPresented: $viewModel.isShowingAlert,
                presenting: viewModel.activeAlert
            ) { alert in
                switch alert {
                case .cacheDeletionConfirmation:
                    Button("settings.alert.button.delete", role: .destructive, action: viewModel.clearCaches)
                    Button("common.cancel", role: .cancel) {}
                case .result:
                    Button("common.ok", role: .cancel) {}
                }
            } message: { alert in
                Text(alert.message)
            }
            .task(id: lmsSession) {
                await profileViewModel.loadIfNeeded(session: lmsSession)
                await timetableViewModel.loadIfNeeded(session: lmsSession)
                viewModel.refreshHiddenAssignmentsState()
            }
            .onChange(of: isNextClassLiveActivityEnabled) { _, isEnabled in
                Task {
                    if isEnabled {
                        await NextClassLiveActivityManager.shared.syncFromStoredSnapshot()
                    } else {
                        await NextClassLiveActivityManager.shared.endAll()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var wstokenRow: some View {
        if let token = lmsSession?.token {
            VStack(alignment: .leading, spacing: 8) {
                Text("wstoken")

                Text(token)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    @ViewBuilder
    private var profileSection: some View {
        if lmsSession != nil {
            Section {
                if let profile = profileViewModel.profile {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.14))

                            Text(profileViewModel.profileInitials)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                        }
                        .frame(width: 52, height: 52)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.fullName)
                                .font(.headline)

                            Text("@\(profile.userName)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                } else if profileViewModel.isLoading {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("settings.profile.loading")
                            .foregroundStyle(.secondary)
                    }
                } else if let profileErrorMessage = profileViewModel.errorMessage {
                    Text(profileErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if lmsAuthenticationViewModel.isLoggedIn {
                    NavigationLink {
                        LmsNotificationPreferencesView(session: lmsSession)
                    } label: {
                        Text("settings.profile.moodleNotifications")
                    }

                    NavigationLink {
                        LmsCalendarPreferencesView(session: lmsSession)
                    } label: {
                        Text("settings.profile.moodleCalendar")
                    }

                    NavigationLink {
                        LmsMessagePreferencesView(session: lmsSession)
                    } label: {
                        Text("settings.profile.moodleMessages")
                    }

                    Button("settings.profile.logout", action: lmsAuthenticationViewModel.signOut)
                }
            }
        }
    }

    @ViewBuilder
    private var displaySection: some View {
        Section("settings.display.section") {
            Picker("settings.display.timetableTab", selection: $displayModeRawValue) {
                ForEach(CoursesDisplayMode.allCases) { displayMode in
                    Text(displayMode.title).tag(displayMode.rawValue)
                }
            }
            .pickerStyle(.menu)

            Picker("settings.display.selectedTimetable", selection: $selectedSemesterID) {
                if timetableViewModel.availableSemesters.isEmpty {
                    Text("settings.display.noSemesters").tag(selectedSemesterID)
                } else {
                    ForEach(timetableViewModel.availableSemesters) { semester in
                        Text(semester.compactDisplayName).tag(semester.id)
                    }
                }
            }
            .pickerStyle(.menu)
            .disabled(lmsSession == nil || timetableViewModel.availableSemesters.isEmpty)

            Toggle("settings.display.liveActivity", isOn: $isNextClassLiveActivityEnabled)

            Toggle("settings.display.openLinksInApp", isOn: $prefersInAppExternalLinks)

            Button("settings.display.unhideAssignments", action: viewModel.unhideAllAssignments)
                .disabled(viewModel.hasHiddenAssignments == false)
        }
    }

    @ViewBuilder
    private var storageSection: some View {
        Section {
            Button("settings.storage.clearCache", role: .destructive) {
                viewModel.presentCacheDeletionConfirmation()
            }
        }
    }

    #if DEBUG
        @ViewBuilder
        private var debugSection: some View {
            Section("settings.debug.section") {
                NavigationLink {
                    LmsRequestLogsView()
                } label: {
                    Text("settings.debug.requestLogs")
                }

                wstokenRow

                Picker("settings.debug.timetableFixture", selection: $debugTimetableFixtureID) {
                    Text("settings.debug.timetableFixture.none").tag(DebugTimetableFixtureStore.noneFixtureID)

                    ForEach(DebugTimetableFixtureStore.builtInFixtures) { fixture in
                        Text(fixture.title).tag(fixture.id)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    #endif

    @ViewBuilder
    private var versionSection: some View {
        Text(viewModel.appVersionDescription)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .listRowBackground(Color.clear)
    }
}

#Preview {
    SettingsTabView()
        .environment(LmsAuthenticationViewModel())
}
