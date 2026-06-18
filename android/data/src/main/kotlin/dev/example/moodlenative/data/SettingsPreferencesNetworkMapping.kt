package dev.example.moodlenative.data

import dev.example.moodlenative.features.LmsMessagePreferences
import dev.example.moodlenative.features.LmsNotificationPreference
import dev.example.moodlenative.features.LmsNotificationPreferenceProcessor
import dev.example.moodlenative.features.LmsNotificationPreferenceProcessorState
import dev.example.moodlenative.features.LmsNotificationPreferences
import dev.example.moodlenative.features.LmsNotificationPreferencesComponent
import dev.example.moodlenative.features.LmsNotificationPreferencesProcessor
import dev.example.moodlenative.networking.MessagePreferences as NetworkMessagePreferences
import dev.example.moodlenative.networking.NotificationPreference as NetworkNotificationPreference
import dev.example.moodlenative.networking.NotificationPreferenceProcessor as NetworkNotificationPreferenceProcessor
import dev.example.moodlenative.networking.NotificationPreferenceProcessorState as NetworkNotificationPreferenceProcessorState
import dev.example.moodlenative.networking.NotificationPreferences as NetworkNotificationPreferences
import dev.example.moodlenative.networking.NotificationPreferencesComponent as NetworkNotificationPreferencesComponent
import dev.example.moodlenative.networking.NotificationPreferencesProcessor as NetworkNotificationPreferencesProcessor
import dev.example.moodlenative.networking.SiteInfo as NetworkSiteInfo
import dev.example.moodlenative.networking.UserPreference as NetworkUserPreference
import dev.example.moodlenative.networking.UserPreferenceUpdate as NetworkUserPreferenceUpdate

internal fun NetworkMessagePreferences.toLmsMessagePreferences(): LmsMessagePreferences =
    LmsMessagePreferences(
        notificationPreferences = notificationPreferences.toLmsNotificationPreferences(),
        blockNonContacts = blockNonContacts,
        enterToSend = enterToSend,
    )

internal fun NetworkNotificationPreferences.toLmsNotificationPreferences(): LmsNotificationPreferences =
    LmsNotificationPreferences(
        userID = userID,
        disableAll = disableAll,
        processors = processors.map { processor -> processor.toLmsNotificationPreferencesProcessor() },
        components = components.map { component -> component.toLmsNotificationPreferencesComponent() },
    )

private fun NetworkNotificationPreferencesProcessor.toLmsNotificationPreferencesProcessor(): LmsNotificationPreferencesProcessor =
    LmsNotificationPreferencesProcessor(
        displayName = displayName,
        name = name,
        hasSettings = hasSettings,
        contextID = contextID,
        userConfigured = userConfigured,
    )

private fun NetworkNotificationPreferencesComponent.toLmsNotificationPreferencesComponent(): LmsNotificationPreferencesComponent =
    LmsNotificationPreferencesComponent(
        displayName = displayName,
        description = description,
        notifications = notifications.map { notification -> notification.toLmsNotificationPreference() },
    )

private fun NetworkNotificationPreference.toLmsNotificationPreference(): LmsNotificationPreference =
    LmsNotificationPreference(
        displayName = displayName,
        preferenceKey = preferenceKey,
        processors = processors.map { processor -> processor.toLmsNotificationPreferenceProcessor() },
    )

private fun NetworkNotificationPreferenceProcessor.toLmsNotificationPreferenceProcessor(): LmsNotificationPreferenceProcessor =
    LmsNotificationPreferenceProcessor(
        displayName = displayName,
        name = name,
        locked = locked,
        lockedMessage = lockedMessage,
        userConfigured = userConfigured,
        enabled = enabled,
        loggedIn = loggedIn?.toLmsNotificationPreferenceProcessorState(),
        loggedOff = loggedOff?.toLmsNotificationPreferenceProcessorState(),
    )

internal fun List<NetworkUserPreference>.toLmsUserPreferences(): List<LmsUserPreference> =
    map { preference ->
        LmsUserPreference(
            name = preference.name,
            value = preference.value,
        )
    }

internal fun List<LmsUserPreferenceUpdate>.toNetworkUserPreferenceUpdates(): List<NetworkUserPreferenceUpdate> =
    map { preference ->
        NetworkUserPreferenceUpdate(
            type = preference.type,
            value = preference.value,
        )
    }

internal fun NetworkSiteInfo.toLmsSiteInfo(): LmsSiteInfo =
    LmsSiteInfo(
        advancedFeatures = advancedFeatures.associate { feature ->
            feature.name to feature.isEnabled
        },
    )

private fun NetworkNotificationPreferenceProcessorState.toLmsNotificationPreferenceProcessorState():
    LmsNotificationPreferenceProcessorState =
    LmsNotificationPreferenceProcessorState(
        name = name,
        displayName = displayName,
        checked = checked,
    )
