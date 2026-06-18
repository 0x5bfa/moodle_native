package dev.example.moodlenative.data

import dev.example.moodlenative.core.LmsAuthenticationSession
import dev.example.moodlenative.networking.LmsWebServiceClient

internal class LmsCalendarPreferencesWebServiceGateway(
    session: LmsAuthenticationSession,
) : CalendarPreferencesGateway {
    private val client = LmsWebServiceClient(session.toLmsWebServiceSession())

    override suspend fun fetchUserPreferences(): List<LmsUserPreference> =
        client.fetchUserPreferences().toLmsUserPreferences()

    override suspend fun updateUserPreferences(preferences: List<LmsUserPreferenceUpdate>) {
        client.updateUserPreferences(preferences = preferences.toNetworkUserPreferenceUpdates())
    }
}
