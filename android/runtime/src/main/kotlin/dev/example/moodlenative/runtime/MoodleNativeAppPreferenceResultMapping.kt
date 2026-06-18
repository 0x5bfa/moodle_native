package dev.example.moodlenative.runtime

import dev.example.moodlenative.data.CalendarPreferencesForm
import dev.example.moodlenative.data.LiveCalendarPreferencesResult
import dev.example.moodlenative.data.LiveMessagePreferencesResult
import dev.example.moodlenative.data.LiveNotificationPreferencesResult
import dev.example.moodlenative.features.LmsMessagePreferences
import dev.example.moodlenative.features.LmsNotificationPreferences
import dev.example.moodlenative.features.preferredNotificationPreferenceProcessorName
import dev.example.moodlenative.storage.AppSessionSnapshot

internal data class NotificationPreferencesResultApplication(
    val snapshot: AppSessionSnapshot,
    val preferences: LmsNotificationPreferences?,
    val selectedProcessorName: String?,
    val message: String?,
    val shouldReplacePreferences: Boolean,
)

internal data class MessagePreferencesResultApplication(
    val snapshot: AppSessionSnapshot,
    val preferences: LmsMessagePreferences?,
    val allowsSiteMessaging: Boolean,
    val message: String?,
    val shouldReplacePreferences: Boolean,
)

internal data class CalendarPreferencesResultApplication(
    val snapshot: AppSessionSnapshot,
    val form: CalendarPreferencesForm,
    val message: String?,
)

internal fun LiveNotificationPreferencesResult.toApplication(
    currentSelectedProcessorName: String?,
    clearPreferencesOnFailure: Boolean,
    successMessage: String?,
): NotificationPreferencesResultApplication = when (this) {
    is LiveNotificationPreferencesResult.MissingSession -> NotificationPreferencesResultApplication(
        snapshot = snapshot,
        preferences = null,
        selectedProcessorName = null,
        message = "Moodle に接続してください。",
        shouldReplacePreferences = true,
    )
    is LiveNotificationPreferencesResult.Loaded -> NotificationPreferencesResultApplication(
        snapshot = snapshot,
        preferences = preferences,
        selectedProcessorName = preferences.preferredNotificationPreferenceProcessorName(currentSelectedProcessorName),
        message = successMessage,
        shouldReplacePreferences = true,
    )
    is LiveNotificationPreferencesResult.Updated -> NotificationPreferencesResultApplication(
        snapshot = snapshot,
        preferences = preferences,
        selectedProcessorName = preferences.preferredNotificationPreferenceProcessorName(currentSelectedProcessorName),
        message = successMessage,
        shouldReplacePreferences = true,
    )
    is LiveNotificationPreferencesResult.Failed -> NotificationPreferencesResultApplication(
        snapshot = snapshot,
        preferences = null,
        selectedProcessorName = null,
        message = message,
        shouldReplacePreferences = clearPreferencesOnFailure,
    )
}

internal fun LiveMessagePreferencesResult.toApplication(
    clearPreferencesOnFailure: Boolean,
    successMessage: String?,
): MessagePreferencesResultApplication = when (this) {
    is LiveMessagePreferencesResult.MissingSession -> MessagePreferencesResultApplication(
        snapshot = snapshot,
        preferences = null,
        allowsSiteMessaging = false,
        message = "Moodle に接続してください。",
        shouldReplacePreferences = true,
    )
    is LiveMessagePreferencesResult.Loaded -> MessagePreferencesResultApplication(
        snapshot = snapshot,
        preferences = preferences,
        allowsSiteMessaging = allowsSiteMessaging,
        message = successMessage,
        shouldReplacePreferences = true,
    )
    is LiveMessagePreferencesResult.Updated -> MessagePreferencesResultApplication(
        snapshot = snapshot,
        preferences = preferences,
        allowsSiteMessaging = allowsSiteMessaging,
        message = successMessage,
        shouldReplacePreferences = true,
    )
    is LiveMessagePreferencesResult.Failed -> MessagePreferencesResultApplication(
        snapshot = snapshot,
        preferences = null,
        allowsSiteMessaging = false,
        message = message,
        shouldReplacePreferences = clearPreferencesOnFailure,
    )
}

internal fun LiveCalendarPreferencesResult.toApplication(
    currentForm: CalendarPreferencesForm,
    successMessage: String?,
): CalendarPreferencesResultApplication = when (this) {
    is LiveCalendarPreferencesResult.MissingSession -> CalendarPreferencesResultApplication(
        snapshot = snapshot,
        form = CalendarPreferencesForm(),
        message = "Moodle に接続してください。",
    )
    is LiveCalendarPreferencesResult.Loaded -> CalendarPreferencesResultApplication(
        snapshot = snapshot,
        form = form,
        message = successMessage,
    )
    is LiveCalendarPreferencesResult.Updated -> CalendarPreferencesResultApplication(
        snapshot = snapshot,
        form = currentForm.applying(key, value),
        message = successMessage,
    )
    is LiveCalendarPreferencesResult.Failed -> CalendarPreferencesResultApplication(
        snapshot = snapshot,
        form = currentForm,
        message = message,
    )
}
