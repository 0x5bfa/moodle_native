import Foundation
import Observation
import MoodleNativeCore
import MoodleNativeNetworking

@Observable
@MainActor
final class LmsCalendarPreferencesViewModel {
    struct FormState: Equatable {
        var timeFormat = "0"
        var startWeekday = "1"
        var maxEvents = "10"
        var lookAhead = "21"
        var persistFilters = false
    }

    private(set) var form = FormState()
    private(set) var isLoading = false
    private(set) var isPreparingCalendarSubscription = false
    private(set) var errorMessage: String?
    private(set) var updatingKeys: Set<String> = []

    private let fetchPreferences: @Sendable (LmsAuthenticationSession) async throws
        -> [LmsWebServiceClient.UserPreference]
    private let makeCalendarSubscription: @Sendable (LmsAuthenticationSession) async throws
        -> LmsWebServiceClient.CalendarSubscription
    private let updatePreferences: @Sendable (
        LmsAuthenticationSession,
        [LmsWebServiceClient.UserPreferenceUpdate]
    ) async throws -> Void

    convenience init() {
        self.init(
            fetchPreferences: { session in
                try await LmsWebServiceClient.logged(
                    session: session,
                    context: LmsRequestLogContext(
                        navigationPath: String(localized: "navigationPath.settings.calendarPreferences"),
                        pageTitle: String(localized: "calendarPreferences.title")
                    )
                ).fetchUserPreferences()
            },
            makeCalendarSubscription: { session in
                try await LmsWebServiceClient.logged(
                    session: session,
                    context: LmsRequestLogContext(
                        navigationPath: String(localized: "navigationPath.settings.calendarPreferences"),
                        pageTitle: String(localized: "calendarPreferences.title")
                    )
                ).makeCalendarSubscription()
            },
            updatePreferences: { session, preferences in
                try await LmsWebServiceClient.logged(
                    session: session,
                    context: LmsRequestLogContext(
                        navigationPath: String(localized: "navigationPath.settings.calendarPreferences"),
                        pageTitle: String(localized: "calendarPreferences.title")
                    )
                ).updateUserPreferences(preferences)
            }
        )
    }

    init(
        fetchPreferences: @escaping @Sendable (LmsAuthenticationSession) async throws
            -> [LmsWebServiceClient.UserPreference],
        makeCalendarSubscription: @escaping @Sendable (LmsAuthenticationSession) async throws
            -> LmsWebServiceClient.CalendarSubscription,
        updatePreferences: @escaping @Sendable (
            LmsAuthenticationSession,
            [LmsWebServiceClient.UserPreferenceUpdate]
        ) async throws -> Void
    ) {
        self.fetchPreferences = fetchPreferences
        self.makeCalendarSubscription = makeCalendarSubscription
        self.updatePreferences = updatePreferences
    }

    func load(session: LmsAuthenticationSession?) async {
        guard let session else {
            errorMessage = nil
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let values = Dictionary(
                uniqueKeysWithValues: try await fetchPreferences(session).map { ($0.name, $0.value) }
            )
            form = FormState(
                timeFormat: preferenceValue("calendar_timeformat", in: values, defaultValue: "0"),
                startWeekday: preferenceValue("calendar_startwday", in: values, defaultValue: "1"),
                maxEvents: preferenceValue("calendar_maxevents", in: values, defaultValue: "10"),
                lookAhead: preferenceValue("calendar_lookahead", in: values, defaultValue: "21"),
                persistFilters: values["calendar_persistflt"] == "1"
            )
            isLoading = false
        } catch {
            errorMessage = Self.message(for: error)
            isLoading = false
        }
    }

    func setValue(_ value: String, for key: String, session: LmsAuthenticationSession?) async {
        guard let session else {
            return
        }

        apply(value: value, for: key)
        updatingKeys.insert(key)
        errorMessage = nil

        do {
            try await updatePreferences(session, [.init(type: key, value: value)])
        } catch {
            errorMessage = Self.message(for: error)
            await load(session: session)
        }

        updatingKeys.remove(key)
    }

    func isUpdating(_ key: String) -> Bool {
        updatingKeys.contains(key)
    }

    func prepareCalendarSubscription(
        session: LmsAuthenticationSession?
    ) async -> LmsWebServiceClient.CalendarSubscription? {
        guard let session else {
            errorMessage = String(localized: "common.loginRequiredBeforeOpening")
            return nil
        }

        isPreparingCalendarSubscription = true
        errorMessage = nil

        do {
            let subscription = try await makeCalendarSubscription(session)
            isPreparingCalendarSubscription = false
            return subscription
        } catch {
            errorMessage = Self.message(for: error)
            isPreparingCalendarSubscription = false
            return nil
        }
    }

    private func preferenceValue(
        _ key: String,
        in values: [String: String?],
        defaultValue: String
    ) -> String {
        guard let value = values[key] else {
            return defaultValue
        }

        return value ?? defaultValue
    }

    private func apply(value: String, for key: String) {
        switch key {
        case "calendar_timeformat":
            form.timeFormat = value
        case "calendar_startwday":
            form.startWeekday = value
        case "calendar_maxevents":
            form.maxEvents = value
        case "calendar_lookahead":
            form.lookAhead = value
        case "calendar_persistflt":
            form.persistFilters = value == "1"
        default:
            break
        }
    }

    private static func message(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
            let description = localizedError.errorDescription,
            description.isEmpty == false
        {
            return description
        }

        let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return description.isEmpty ? String(localized: "calendarPreferences.error.updateFailed") : description
    }
}
