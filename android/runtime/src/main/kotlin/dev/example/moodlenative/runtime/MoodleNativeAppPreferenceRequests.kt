package dev.example.moodlenative.runtime

import dev.example.moodlenative.data.LiveCalendarPreferencesResult
import dev.example.moodlenative.data.LiveMessagePreferencesResult
import dev.example.moodlenative.data.LiveNotificationPreferencesResult
import dev.example.moodlenative.storage.AppSessionStore

internal class MoodleNativeAppPreferenceRequests(
    private val sessionStore: AppSessionStore,
    private val repositories: MoodleNativeAppRepositories,
) {
    suspend fun loadNotificationPreferences(): LiveNotificationPreferencesResult =
        runMoodleNativeAppRequest(
            onFailure = { error ->
                error.toFailedLoadNotificationPreferencesResult(
                    snapshot = sessionStore.readSnapshot(),
                )
            },
        ) {
            repositories.notificationPreferences.load()
        }

    suspend fun setAllNotificationsEnabled(isEnabled: Boolean): LiveNotificationPreferencesResult =
        runMoodleNativeAppRequest(
            onFailure = { error ->
                error.toFailedUpdateNotificationPreferencesResult(
                    snapshot = sessionStore.readSnapshot(),
                )
            },
        ) {
            repositories.notificationPreferences.setAllNotificationsEnabled(isEnabled)
        }

    suspend fun setNotificationPreferenceEnabled(
        isEnabled: Boolean,
        preferenceKey: String,
        processorName: String,
    ): LiveNotificationPreferencesResult =
        runMoodleNativeAppRequest(
            onFailure = { error ->
                error.toFailedUpdateNotificationPreferencesResult(
                    snapshot = sessionStore.readSnapshot(),
                )
            },
        ) {
            repositories.notificationPreferences.setNotificationEnabled(
                isEnabled = isEnabled,
                preferenceKey = preferenceKey,
                processorName = processorName,
            )
        }

    suspend fun setLegacyNotificationPreferenceState(
        isEnabled: Boolean,
        stateName: String,
        preferenceKey: String,
        processorName: String,
    ): LiveNotificationPreferencesResult =
        runMoodleNativeAppRequest(
            onFailure = { error ->
                error.toFailedUpdateNotificationPreferencesResult(
                    snapshot = sessionStore.readSnapshot(),
                )
            },
        ) {
            repositories.notificationPreferences.setLegacyNotificationState(
                isEnabled = isEnabled,
                stateName = stateName,
                preferenceKey = preferenceKey,
                processorName = processorName,
            )
        }

    suspend fun loadMessagePreferences(): LiveMessagePreferencesResult =
        runMoodleNativeAppRequest(
            onFailure = { error ->
                error.toFailedLoadMessagePreferencesResult(
                    snapshot = sessionStore.readSnapshot(),
                )
            },
        ) {
            repositories.messagePreferences.load()
        }

    suspend fun setMessageContactablePrivacy(value: Int): LiveMessagePreferencesResult =
        runMoodleNativeAppRequest(
            onFailure = { error ->
                error.toFailedUpdateMessagePreferencesResult(
                    snapshot = sessionStore.readSnapshot(),
                )
            },
        ) {
            repositories.messagePreferences.setContactablePrivacy(value)
        }

    suspend fun setInstantMessageProcessorEnabled(
        isEnabled: Boolean,
        preferenceKey: String,
        processorName: String,
    ): LiveMessagePreferencesResult =
        runMoodleNativeAppRequest(
            onFailure = { error ->
                error.toFailedUpdateMessagePreferencesResult(
                    snapshot = sessionStore.readSnapshot(),
                )
            },
        ) {
            repositories.messagePreferences.setProcessorEnabled(
                isEnabled = isEnabled,
                preferenceKey = preferenceKey,
                processorName = processorName,
            )
        }

    suspend fun loadCalendarPreferences(): LiveCalendarPreferencesResult =
        runMoodleNativeAppRequest(
            onFailure = { error ->
                error.toFailedLoadCalendarPreferencesResult(
                    snapshot = sessionStore.readSnapshot(),
                )
            },
        ) {
            repositories.calendarPreferences.load()
        }

    suspend fun setCalendarPreferenceValue(
        key: String,
        value: String,
    ): LiveCalendarPreferencesResult =
        runMoodleNativeAppRequest(
            onFailure = { error ->
                error.toFailedUpdateCalendarPreferencesResult(
                    snapshot = sessionStore.readSnapshot(),
                )
            },
        ) {
            repositories.calendarPreferences.setValue(
                key = key,
                value = value,
            )
        }
}
