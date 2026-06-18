import MoodleNativeCore
import MoodleNativeNetworking
import SwiftUI

struct LmsCalendarPreferencesView: View {
    let session: LmsAuthenticationSession?

    @Environment(\.openURL) private var openURL
    @State private var viewModel = LmsCalendarPreferencesViewModel()

    var body: some View {
        @Bindable var viewModel = viewModel

        List {
            if viewModel.isLoading {
                loadingSection
            } else {
                Section("calendarPreferences.display.section") {
                    Picker(
                        "calendarPreferences.timeFormat",
                        selection: Binding(
                            get: { viewModel.form.timeFormat },
                            set: { value in
                                Task {
                                    await viewModel.setValue(
                                        value,
                                        for: "calendar_timeformat",
                                        session: session
                                    )
                                }
                            }
                        )
                    ) {
                        Text("calendarPreferences.timeFormat.default").tag("0")
                        Text("calendarPreferences.timeFormat.12Hour").tag("%I:%M %p")
                        Text("calendarPreferences.timeFormat.24Hour").tag("%H:%M")
                    }
                    .disabled(viewModel.isUpdating("calendar_timeformat"))

                    Picker(
                        "calendarPreferences.startWeekday",
                        selection: Binding(
                            get: { viewModel.form.startWeekday },
                            set: { value in
                                Task {
                                    await viewModel.setValue(
                                        value,
                                        for: "calendar_startwday",
                                        session: session
                                    )
                                }
                            }
                        )
                    ) {
                        ForEach(Self.weekdayOptions, id: \.value) { option in
                            Text(LocalizedStringKey(option.titleKey)).tag(option.value)
                        }
                    }
                    .disabled(viewModel.isUpdating("calendar_startwday"))
                }

                Section("calendarPreferences.upcomingEvents.section") {
                    Picker(
                        "calendarPreferences.maxEvents",
                        selection: Binding(
                            get: { viewModel.form.maxEvents },
                            set: { value in
                                Task {
                                    await viewModel.setValue(
                                        value,
                                        for: "calendar_maxevents",
                                        session: session
                                    )
                                }
                            }
                        )
                    ) {
                        ForEach(1...20, id: \.self) { value in
                            Text("\(value)").tag(String(value))
                        }
                    }
                    .disabled(viewModel.isUpdating("calendar_maxevents"))

                    Picker(
                        "calendarPreferences.lookAhead",
                        selection: Binding(
                            get: { viewModel.form.lookAhead },
                            set: { value in
                                Task {
                                    await viewModel.setValue(
                                        value,
                                        for: "calendar_lookahead",
                                        session: session
                                    )
                                }
                            }
                        )
                    ) {
                        ForEach(Self.lookAheadOptions, id: \.value) { option in
                            Text(LocalizedStringKey(option.titleKey)).tag(option.value)
                        }
                    }
                    .disabled(viewModel.isUpdating("calendar_lookahead"))

                    Toggle(
                        "calendarPreferences.persistFilters",
                        isOn: Binding(
                            get: { viewModel.form.persistFilters },
                            set: { value in
                                Task {
                                    await viewModel.setValue(
                                        value ? "1" : "0",
                                        for: "calendar_persistflt",
                                        session: session
                                    )
                                }
                            }
                        )
                    )
                    .disabled(viewModel.isUpdating("calendar_persistflt"))
                }

                Section {
                    Button {
                        Task {
                            guard let subscription = await viewModel.prepareCalendarSubscription(
                                session: session
                            ) else {
                                return
                            }

                            openURL(subscription.webcalURL)
                        }
                    } label: {
                        Label(
                            "calendarPreferences.appleCalendar.add",
                            systemImage: "calendar.badge.plus"
                        )
                    }
                    .disabled(session == nil || viewModel.isPreparingCalendarSubscription)

                    if viewModel.isPreparingCalendarSubscription {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("calendarPreferences.appleCalendar.preparing")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("calendarPreferences.appleCalendar.section")
                } footer: {
                    Text("calendarPreferences.appleCalendar.footer")
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .navigationTitle(String(localized: "calendarPreferences.title"))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await viewModel.load(session: session)
        }
        .task(id: session) {
            await viewModel.load(session: session)
        }
    }

    private var loadingSection: some View {
        Section {
            HStack(spacing: 12) {
                ProgressView()
                Text("calendarPreferences.loading")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private static let weekdayOptions: [(value: String, titleKey: String)] = [
        ("0", "calendarPreferences.weekday.sunday"),
        ("1", "calendarPreferences.weekday.monday"),
        ("2", "calendarPreferences.weekday.tuesday"),
        ("3", "calendarPreferences.weekday.wednesday"),
        ("4", "calendarPreferences.weekday.thursday"),
        ("5", "calendarPreferences.weekday.friday"),
        ("6", "calendarPreferences.weekday.saturday"),
    ]

    private static let lookAheadOptions: [(value: String, titleKey: String)] = [
        ("365", "calendarPreferences.lookAhead.oneYear"),
        ("270", "calendarPreferences.lookAhead.nineMonths"),
        ("180", "calendarPreferences.lookAhead.sixMonths"),
        ("150", "calendarPreferences.lookAhead.fiveMonths"),
        ("120", "calendarPreferences.lookAhead.fourMonths"),
        ("90", "calendarPreferences.lookAhead.threeMonths"),
        ("60", "calendarPreferences.lookAhead.twoMonths"),
        ("30", "calendarPreferences.lookAhead.oneMonth"),
        ("21", "calendarPreferences.lookAhead.threeWeeks"),
        ("14", "calendarPreferences.lookAhead.twoWeeks"),
        ("7", "calendarPreferences.lookAhead.oneWeek"),
        ("6", "calendarPreferences.lookAhead.sixDays"),
        ("5", "calendarPreferences.lookAhead.fiveDays"),
        ("4", "calendarPreferences.lookAhead.fourDays"),
        ("3", "calendarPreferences.lookAhead.threeDays"),
        ("2", "calendarPreferences.lookAhead.twoDays"),
        ("1", "calendarPreferences.lookAhead.oneDay"),
    ]
}

#Preview {
    NavigationStack {
        LmsCalendarPreferencesView(session: nil)
    }
}
