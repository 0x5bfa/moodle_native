package dev.example.moodlenative.runtime

import dev.example.moodlenative.core.LmsAssignmentItem
import dev.example.moodlenative.data.CalendarPreferencesForm
import dev.example.moodlenative.data.LiveAssignmentDetailResult
import dev.example.moodlenative.data.LiveCalendarResult
import dev.example.moodlenative.data.LiveDashboardResult
import dev.example.moodlenative.data.LiveForumResult
import dev.example.moodlenative.features.LmsMessagePreferences
import dev.example.moodlenative.features.LmsNotificationPreferences
import dev.example.moodlenative.storage.AppSessionSnapshot

internal data class MoodleNativeAppSessionReset(
    val sessionSnapshot: AppSessionSnapshot,
    val liveDashboardResult: LiveDashboardResult,
    val liveAssignmentDetailResult: LiveAssignmentDetailResult?,
    val assignmentActionMessage: String?,
    val isUpdatingAssignmentAction: Boolean,
    val liveForumResult: LiveForumResult?,
    val forumActionMessage: String?,
    val isUpdatingForumAction: Boolean,
    val notificationActionMessage: String?,
    val isUpdatingNotifications: Boolean,
    val notificationPreferences: LmsNotificationPreferences?,
    val isLoadingNotificationPreferences: Boolean,
    val isUpdatingNotificationPreferences: Boolean,
    val notificationPreferencesMessage: String?,
    val selectedNotificationPreferenceProcessorName: String?,
    val messagePreferences: LmsMessagePreferences?,
    val allowsSiteMessaging: Boolean,
    val isLoadingMessagePreferences: Boolean,
    val isUpdatingMessagePreferences: Boolean,
    val messagePreferencesMessage: String?,
    val calendarPreferencesForm: CalendarPreferencesForm,
    val isLoadingCalendarPreferences: Boolean,
    val isUpdatingCalendarPreferences: Boolean,
    val calendarPreferencesMessage: String?,
    val courseActionMessage: String?,
    val isUpdatingCourseFavorite: Boolean,
    val liveCalendarResult: LiveCalendarResult,
    val isLoadingCalendarSubscription: Boolean,
    val sessionActionMessage: String,
)

internal fun AppSessionSnapshot.toMoodleNativeAppSessionReset(
    selectedAssignment: LmsAssignmentItem?,
    forumIDText: String,
): MoodleNativeAppSessionReset = MoodleNativeAppSessionReset(
    sessionSnapshot = this,
    liveDashboardResult = LiveDashboardResult.MissingSession(this),
    liveAssignmentDetailResult = selectedAssignment?.let { assignment ->
        LiveAssignmentDetailResult.MissingSession(
            snapshot = this,
            assignment = assignment,
        )
    },
    assignmentActionMessage = null,
    isUpdatingAssignmentAction = false,
    liveForumResult = forumIDText.trim().toIntOrNull()?.let { forumID ->
        LiveForumResult.MissingSession(
            snapshot = this,
            forumID = forumID,
        )
    },
    forumActionMessage = null,
    isUpdatingForumAction = false,
    notificationActionMessage = null,
    isUpdatingNotifications = false,
    notificationPreferences = null,
    isLoadingNotificationPreferences = false,
    isUpdatingNotificationPreferences = false,
    notificationPreferencesMessage = null,
    selectedNotificationPreferenceProcessorName = null,
    messagePreferences = null,
    allowsSiteMessaging = false,
    isLoadingMessagePreferences = false,
    isUpdatingMessagePreferences = false,
    messagePreferencesMessage = null,
    calendarPreferencesForm = CalendarPreferencesForm(),
    isLoadingCalendarPreferences = false,
    isUpdatingCalendarPreferences = false,
    calendarPreferencesMessage = null,
    courseActionMessage = null,
    isUpdatingCourseFavorite = false,
    liveCalendarResult = LiveCalendarResult.MissingSession(this),
    isLoadingCalendarSubscription = false,
    sessionActionMessage = "Moodle セッションを削除しました。",
)
