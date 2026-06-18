import Foundation
import Observation
import MoodleNativeCore
import MoodleNativeNetworking

@Observable
@MainActor
final class LmsNotificationPreferencesViewModel {
    private(set) var preferences: LmsWebServiceClient.NotificationPreferences?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var updatingKeys: Set<String> = []
    var selectedProcessorName: String?

    private let fetchPreferences: @Sendable (LmsAuthenticationSession) async throws
        -> LmsWebServiceClient.NotificationPreferences
    private let updatePreferences: @Sendable (
        LmsAuthenticationSession,
        [LmsWebServiceClient.UserPreferenceUpdate],
        Bool?
    ) async throws -> Void

    convenience init() {
        self.init(
            fetchPreferences: { session in
                try await LmsWebServiceClient.logged(
                    session: session,
                    context: LmsRequestLogContext(
                        navigationPath: String(localized: "navigationPath.settings.notificationPreferences"),
                        pageTitle: String(localized: "notificationPreferences.title")
                    )
                ).fetchNotificationPreferences()
            },
            updatePreferences: { session, preferences, disableNotifications in
                try await LmsWebServiceClient.logged(
                    session: session,
                    context: LmsRequestLogContext(
                        navigationPath: String(localized: "navigationPath.settings.notificationPreferences"),
                        pageTitle: String(localized: "notificationPreferences.title")
                    )
                ).updateUserPreferences(
                    preferences,
                    disableNotifications: disableNotifications
                )
            }
        )
    }

    init(
        fetchPreferences: @escaping @Sendable (LmsAuthenticationSession) async throws
            -> LmsWebServiceClient.NotificationPreferences,
        updatePreferences: @escaping @Sendable (
            LmsAuthenticationSession,
            [LmsWebServiceClient.UserPreferenceUpdate],
            Bool?
        ) async throws -> Void
    ) {
        self.fetchPreferences = fetchPreferences
        self.updatePreferences = updatePreferences
    }

    var selectedProcessor: LmsWebServiceClient.NotificationPreferencesProcessor? {
        guard let preferences else {
            return nil
        }

        if let selectedProcessorName,
            let processor = preferences.processors.first(where: { $0.name == selectedProcessorName })
        {
            return processor
        }

        return preferredProcessor(in: preferences)
    }

    var selectedProcessorComponents: [LmsWebServiceClient.NotificationPreferencesComponent] {
        guard let preferences, let selectedProcessor else {
            return []
        }

        return preferences.components.compactMap { component in
            let notifications = component.notifications.filter {
                $0.processor(named: selectedProcessor.name) != nil
            }

            guard notifications.isEmpty == false else {
                return nil
            }

            var component = component
            component.notifications = notifications
            return component
        }
    }

    func load(session: LmsAuthenticationSession?) async {
        guard let session else {
            preferences = nil
            errorMessage = nil
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let loadedPreferences = try await fetchPreferences(session)
            preferences = loadedPreferences
            if selectedProcessorName == nil
                || loadedPreferences.processors.contains(where: { $0.name == selectedProcessorName }) == false
            {
                selectedProcessorName = preferredProcessor(in: loadedPreferences)?.name
            }
            isLoading = false
        } catch {
            preferences = nil
            errorMessage = Self.message(for: error)
            isLoading = false
        }
    }

    func setAllNotificationsEnabled(_ isEnabled: Bool, session: LmsAuthenticationSession?) async {
        guard let session, preferences != nil else {
            return
        }

        let key = "emailstop"
        updatingKeys.insert(key)
        errorMessage = nil

        do {
            try await updatePreferences(session, [], isEnabled == false)
            await load(session: session)
        } catch {
            errorMessage = Self.message(for: error)
        }

        updatingKeys.remove(key)
    }

    func setNotificationEnabled(
        _ isEnabled: Bool,
        notification: LmsWebServiceClient.NotificationPreference,
        session: LmsAuthenticationSession?
    ) async {
        guard let session, let processorName = selectedProcessor?.name else {
            return
        }

        let key = "\(notification.preferenceKey)_\(processorName)"
        updatingKeys.insert(key)
        errorMessage = nil

        do {
            try await updatePreferences(session, [.init(type: key, value: isEnabled ? "1" : "0")], nil)
            await load(session: session)
        } catch {
            errorMessage = Self.message(for: error)
        }

        updatingKeys.remove(key)
    }

    func setLegacyNotificationState(
        _ isEnabled: Bool,
        stateName: String,
        notification: LmsWebServiceClient.NotificationPreference,
        session: LmsAuthenticationSession?
    ) async {
        guard let session, let processorName = selectedProcessor?.name else {
            return
        }

        let key = "\(notification.preferenceKey)_\(stateName)"
        updatingKeys.insert(key)
        errorMessage = nil

        do {
            let value = notification.processors.compactMap { processor -> String? in
                let current: Bool
                switch stateName {
                case "loggedin":
                    current = processor.loggedIn?.checked ?? false
                case "loggedoff":
                    current = processor.loggedOff?.checked ?? false
                default:
                    current = false
                }

                let next = processor.name == processorName ? isEnabled : current
                return next ? processor.name : nil
            }.joined(separator: ",")

            try await updatePreferences(
                session,
                [.init(type: key, value: value.isEmpty ? "none" : value)],
                nil
            )
            await load(session: session)
        } catch {
            errorMessage = Self.message(for: error)
        }

        updatingKeys.remove(key)
    }

    func isUpdating(_ key: String) -> Bool {
        updatingKeys.contains(key)
    }

    private func preferredProcessor(
        in preferences: LmsWebServiceClient.NotificationPreferences
    ) -> LmsWebServiceClient.NotificationPreferencesProcessor? {
        preferences.processors.first { $0.name == "airnotifier" } ?? preferences.processors.first
    }

    private static func message(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
            let description = localizedError.errorDescription,
            description.isEmpty == false
        {
            return description
        }

        let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if description.isEmpty == false {
            return description
        }

        return String(localized: "notificationPreferences.error.updateFailed")
    }
}
