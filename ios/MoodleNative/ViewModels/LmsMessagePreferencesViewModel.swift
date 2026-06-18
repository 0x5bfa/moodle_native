import Foundation
import Observation
import MoodleNativeCore
import MoodleNativeNetworking

@Observable
@MainActor
final class LmsMessagePreferencesViewModel {
    private(set) var preferences: LmsWebServiceClient.MessagePreferences?
    private(set) var allowsSiteMessaging = false
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var updatingKeys: Set<String> = []

    private let fetchPreferences: @Sendable (LmsAuthenticationSession) async throws
        -> LmsWebServiceClient.MessagePreferences
    private let fetchSiteInfo: @Sendable (LmsAuthenticationSession) async throws
        -> LmsWebServiceClient.SiteInfo
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
                        navigationPath: String(localized: "navigationPath.settings.messagePreferences"),
                        pageTitle: String(localized: "messagePreferences.title")
                    )
                ).fetchMessagePreferences()
            },
            fetchSiteInfo: { session in
                try await LmsWebServiceClient.logged(
                    session: session,
                    context: LmsRequestLogContext(
                        navigationPath: String(localized: "navigationPath.settings.messagePreferences"),
                        pageTitle: String(localized: "messagePreferences.title")
                    )
                ).fetchSiteInfo()
            },
            updatePreferences: { session, preferences in
                try await LmsWebServiceClient.logged(
                    session: session,
                    context: LmsRequestLogContext(
                        navigationPath: String(localized: "navigationPath.settings.messagePreferences"),
                        pageTitle: String(localized: "messagePreferences.title")
                    )
                ).updateUserPreferences(preferences)
            }
        )
    }

    init(
        fetchPreferences: @escaping @Sendable (LmsAuthenticationSession) async throws
            -> LmsWebServiceClient.MessagePreferences,
        fetchSiteInfo: @escaping @Sendable (LmsAuthenticationSession) async throws
            -> LmsWebServiceClient.SiteInfo,
        updatePreferences: @escaping @Sendable (
            LmsAuthenticationSession,
            [LmsWebServiceClient.UserPreferenceUpdate]
        ) async throws -> Void
    ) {
        self.fetchPreferences = fetchPreferences
        self.fetchSiteInfo = fetchSiteInfo
        self.updatePreferences = updatePreferences
    }

    var instantMessageNotification: LmsWebServiceClient.NotificationPreference? {
        preferences?.notificationPreferences.components
            .flatMap(\.notifications)
            .first { $0.preferenceKey == "message_provider_moodle_instantmessage" }
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
            async let loadedPreferences = fetchPreferences(session)
            async let siteInfo = fetchSiteInfo(session)
            preferences = try await loadedPreferences
            allowsSiteMessaging = try await siteInfo.isAdvancedFeatureEnabled("messagingallusers")
            isLoading = false
        } catch {
            preferences = nil
            allowsSiteMessaging = false
            errorMessage = Self.message(for: error)
            isLoading = false
        }
    }

    func setContactablePrivacy(_ value: Int, session: LmsAuthenticationSession?) async {
        guard let session else {
            return
        }

        let key = "message_blocknoncontacts"
        updatingKeys.insert(key)
        errorMessage = nil

        do {
            try await updatePreferences(session, [.init(type: key, value: String(value))])
            await load(session: session)
        } catch {
            errorMessage = Self.message(for: error)
        }

        updatingKeys.remove(key)
    }

    func setProcessorEnabled(
        _ isEnabled: Bool,
        processor: LmsWebServiceClient.NotificationPreferenceProcessor,
        session: LmsAuthenticationSession?
    ) async {
        guard let session, let notification = instantMessageNotification else {
            return
        }

        let key = "\(notification.preferenceKey)_enabled"
        updatingKeys.insert(key)
        errorMessage = nil

        do {
            let value = notification.processors.compactMap { currentProcessor -> String? in
                let nextEnabled = currentProcessor.name == processor.name
                    ? isEnabled
                    : currentProcessor.enabled ?? false

                return nextEnabled ? currentProcessor.name : nil
            }.joined(separator: ",")

            try await updatePreferences(
                session,
                [.init(type: key, value: value.isEmpty ? "none" : value)]
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

    private static func message(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
            let description = localizedError.errorDescription,
            description.isEmpty == false
        {
            return description
        }

        let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return description.isEmpty ? String(localized: "messagePreferences.error.updateFailed") : description
    }
}
