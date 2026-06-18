package dev.example.moodlenative.data

import dev.example.moodlenative.core.LmsAuthenticationSession
import dev.example.moodlenative.features.LmsMessagePreferences
import dev.example.moodlenative.networking.LmsWebServiceClient

internal class LmsMessagePreferencesWebServiceGateway(
    session: LmsAuthenticationSession,
) : MessagePreferencesGateway {
    private val client = LmsWebServiceClient(session.toLmsWebServiceSession())

    override suspend fun fetchMessagePreferences(): LmsMessagePreferences =
        client.fetchMessagePreferences().toLmsMessagePreferences()

    override suspend fun fetchSiteInfo(): LmsSiteInfo =
        client.fetchSiteInfo().toLmsSiteInfo()

    override suspend fun updateUserPreferences(preferences: List<LmsUserPreferenceUpdate>) {
        client.updateUserPreferences(preferences = preferences.toNetworkUserPreferenceUpdates())
    }
}
