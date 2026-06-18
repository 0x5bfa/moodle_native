package dev.example.moodlenative.presentation

import dev.example.moodlenative.core.LmsAssignmentItem
import dev.example.moodlenative.core.LmsNotificationItem
import dev.example.moodlenative.features.AssignmentDetailPresentation
import dev.example.moodlenative.features.AssignmentDetailRowPresentation
import dev.example.moodlenative.features.CalendarSubscriptionPresentation
import dev.example.moodlenative.features.LmsCourseSummary
import dev.example.moodlenative.features.LmsForumDiscussionPresentation
import dev.example.moodlenative.features.LmsForumPostThreadPresentationNode
import dev.example.moodlenative.features.MessagePreferencesPresentation
import dev.example.moodlenative.features.NotificationPreferencesPresentation
import java.time.Instant
import java.time.ZoneId

data class AppUiState(
    val session: AppSessionPresentationState,
    val now: Instant,
    val zoneId: ZoneId,
    val courses: List<LmsCourseSummary>,
    val assignments: List<LmsAssignmentItem>,
    val notifications: List<LmsNotificationItem>,
    val selectedAssignment: LmsAssignmentItem?,
    val assignmentDetailPresentation: AssignmentDetailPresentation?,
    val assignmentDetailStatusRows: List<AssignmentDetailRowPresentation>,
    val isLoadingAssignmentDetail: Boolean,
    val assignmentActionMessage: String?,
    val isUpdatingAssignmentAction: Boolean,
    val forumIDText: String,
    val forumDiscussions: List<LmsForumDiscussionPresentation>,
    val forumSelectedDiscussion: LmsForumDiscussionPresentation?,
    val forumPostThreads: List<LmsForumPostThreadPresentationNode>,
    val forumPartialErrors: List<String>,
    val forumError: String?,
    val forumPrimaryLabel: String,
    val forumStatusLabel: String,
    val isLoadingForum: Boolean,
    val forumActionMessage: String?,
    val isUpdatingForumAction: Boolean,
    val isLoadingLiveDashboard: Boolean,
    val loadedAt: Instant?,
    val dashboardError: String?,
    val unreadNotificationCount: Int,
    val notificationActionMessage: String?,
    val isUpdatingNotifications: Boolean,
    val notificationPreferencesPresentation: NotificationPreferencesPresentation?,
    val isLoadingNotificationPreferences: Boolean,
    val isUpdatingNotificationPreferences: Boolean,
    val notificationPreferencesMessage: String?,
    val messagePreferencesPresentation: MessagePreferencesPresentation?,
    val isLoadingMessagePreferences: Boolean,
    val isUpdatingMessagePreferences: Boolean,
    val messagePreferencesMessage: String?,
    val courseActionMessage: String?,
    val isUpdatingCourseFavorite: Boolean,
    val calendarPreferencesForm: CalendarPreferencesPresentationForm,
    val isLoadingCalendarPreferences: Boolean,
    val isUpdatingCalendarPreferences: Boolean,
    val calendarPreferencesMessage: String?,
    val calendarSubscription: CalendarSubscriptionPresentation?,
    val calendarStatusMessage: String?,
    val isLoadingCalendarSubscription: Boolean,
    val partialErrors: List<String>,
    val sessionActionMessage: String?,
) {
    val sessionStatusLabel: String
        get() = when {
            isLoadingLiveDashboard -> "LMS 同期中"
            loadedAt != null -> "LMS 同期済み"
            dashboardError != null -> "LMS 取得失敗"
            session.hasLmsSession -> "セッション保存済み"
            else -> "デモ環境"
        }

    val dashboardStatusLabel: String
        get() = when {
            isLoadingLiveDashboard -> "同期中"
            loadedAt != null -> "LMS 同期済み"
            dashboardError != null -> "取得失敗"
            session.hasLmsSession -> "未同期"
            else -> "デモ"
        }

    val dashboardStatusDetail: String
        get() = when {
            isLoadingLiveDashboard -> "Moodle から読み込み中"
            dashboardError != null -> dashboardError
            loadedAt != null -> "コース ${courses.size} 件 / 課題 ${assignments.size} 件"
            session.hasLmsSession -> "保存済みセッションあり"
            else -> "未接続"
        }

    val lmsSessionLabel: String
        get() = session.lmsSessionLabel

    val notificationPrimaryLabel: String
        get() = when {
            isLoadingLiveDashboard -> "取得中"
            unreadNotificationCount > 0 -> "未読 $unreadNotificationCount 件"
            else -> "${notifications.size} 件"
        }

    val notificationStatusLabel: String
        get() = when {
            isLoadingLiveDashboard -> "LMS 同期中"
            dashboardError != null -> "取得失敗"
            loadedAt != null -> "LMS 同期済み"
            session.hasLmsSession -> "未同期"
            else -> "デモ"
        }

    val notificationPreferencesStatusLabel: String
        get() = when {
            isLoadingNotificationPreferences -> "読み込み中"
            isUpdatingNotificationPreferences -> "更新中"
            notificationPreferencesPresentation != null -> {
                val enabledLabel = if (notificationPreferencesPresentation.enableAll) "全体 ON" else "全体 OFF"
                "$enabledLabel / ${notificationPreferencesPresentation.componentGroupCount} グループ"
            }
            notificationPreferencesMessage != null -> "取得失敗"
            session.hasLmsSession -> "未読み込み"
            else -> "未接続"
        }

    val messagePreferencesStatusLabel: String
        get() = when {
            isLoadingMessagePreferences -> "読み込み中"
            isUpdatingMessagePreferences -> "更新中"
            messagePreferencesPresentation != null -> messagePreferencesPresentation.selectedContactScopeLabel
            messagePreferencesMessage != null -> "取得失敗"
            session.hasLmsSession -> "未読み込み"
            else -> "未接続"
        }

    val calendarPreferencesStatusLabel: String
        get() = when {
            isLoadingCalendarPreferences -> "読み込み中"
            isUpdatingCalendarPreferences -> "更新中"
            calendarPreferencesMessage != null -> "更新結果あり"
            session.hasLmsSession -> {
                val weekday = calendarWeekdayOptions.firstOrNull { it.value == calendarPreferencesForm.startWeekday }?.label
                    ?: calendarPreferencesForm.startWeekday
                "$weekday 始まり / ${calendarPreferencesForm.maxEvents} 件"
            }
            else -> "未接続"
        }

    companion object {
        fun demo(): AppUiState =
            AppUiState(
                session = AppSessionPresentationState(),
                now = AppDemoData.now,
                zoneId = AppDemoData.zoneId,
                courses = AppDemoData.courses,
                assignments = AppDemoData.assignments,
                notifications = AppDemoData.notifications,
                selectedAssignment = null,
                assignmentDetailPresentation = null,
                assignmentDetailStatusRows = listOf(AssignmentDetailRowPresentation("詳細", "課題を選択してください")),
                isLoadingAssignmentDetail = false,
                assignmentActionMessage = null,
                isUpdatingAssignmentAction = false,
                forumIDText = "",
                forumDiscussions = emptyList(),
                forumSelectedDiscussion = null,
                forumPostThreads = emptyList(),
                forumPartialErrors = emptyList(),
                forumError = null,
                forumPrimaryLabel = "未指定",
                forumStatusLabel = "未読み込み",
                isLoadingForum = false,
                forumActionMessage = null,
                isUpdatingForumAction = false,
                isLoadingLiveDashboard = false,
                loadedAt = null,
                dashboardError = null,
                unreadNotificationCount = AppDemoData.notifications.count { it.isUnread },
                notificationActionMessage = null,
                isUpdatingNotifications = false,
                notificationPreferencesPresentation = null,
                isLoadingNotificationPreferences = false,
                isUpdatingNotificationPreferences = false,
                notificationPreferencesMessage = null,
                messagePreferencesPresentation = null,
                isLoadingMessagePreferences = false,
                isUpdatingMessagePreferences = false,
                messagePreferencesMessage = null,
                courseActionMessage = null,
                isUpdatingCourseFavorite = false,
                calendarPreferencesForm = CalendarPreferencesPresentationForm(),
                isLoadingCalendarPreferences = false,
                isUpdatingCalendarPreferences = false,
                calendarPreferencesMessage = null,
                calendarSubscription = null,
                calendarStatusMessage = null,
                isLoadingCalendarSubscription = false,
                partialErrors = emptyList(),
                sessionActionMessage = null,
            )
    }
}
