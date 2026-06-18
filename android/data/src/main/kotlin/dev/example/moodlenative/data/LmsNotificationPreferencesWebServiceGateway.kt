package dev.example.moodlenative.data

import dev.example.moodlenative.core.LmsAuthenticationSession
import dev.example.moodlenative.features.LmsNotificationPreferences
import dev.example.moodlenative.networking.LmsWebServiceClient

internal class LmsNotificationPreferencesWebServiceGateway(
    session: LmsAuthenticationSession,
) : NotificationPreferencesGateway {
    private val client = LmsWebServiceClient(session.toLmsWebServiceSession())

    override suspend fun fetchNotificationPreferences(): LmsNotificationPreferences =
        client.fetchNotificationPreferences().toLmsNotificationPreferences()

    override suspend fun updateUserPreferences(
        preferences: List<LmsUserPreferenceUpdate>,
        disableNotifications: Boolean?,
    ) {
        client.updateUserPreferences(
            preferences = preferences.toNetworkUserPreferenceUpdates(),
            disableNotifications = disableNotifications,
        )
    }
}
