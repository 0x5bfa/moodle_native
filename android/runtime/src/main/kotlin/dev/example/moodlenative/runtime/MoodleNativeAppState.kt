package dev.example.moodlenative.runtime

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import dev.example.moodlenative.core.LmsAssignmentItem
import dev.example.moodlenative.core.LmsNotificationItem
import dev.example.moodlenative.data.CalendarPreferencesForm
import dev.example.moodlenative.data.LiveAssignmentActionResult
import dev.example.moodlenative.data.LiveAssignmentDetailResult
import dev.example.moodlenative.data.LiveCalendarPreferencesResult
import dev.example.moodlenative.data.LiveCalendarResult
import dev.example.moodlenative.data.LiveCourseActionResult
import dev.example.moodlenative.data.LiveForumActionResult
import dev.example.moodlenative.data.LiveDashboardResult
import dev.example.moodlenative.data.LiveForumResult
import dev.example.moodlenative.data.LiveMessagePreferencesResult
import dev.example.moodlenative.data.LiveNotificationActionResult
import dev.example.moodlenative.data.LiveNotificationPreferencesResult
import dev.example.moodlenative.data.AssignmentSubmissionFileInput
import dev.example.moodlenative.data.ExistingAssignmentSubmissionFileInput
import dev.example.moodlenative.features.LmsCourseSummary
import dev.example.moodlenative.features.LmsMessagePreferences
import dev.example.moodlenative.features.LmsNotificationPreferences
import dev.example.moodlenative.features.MessagePreferencesPresentation
import dev.example.moodlenative.features.NotificationPreferencesPresentation
import dev.example.moodlenative.features.presentation
import dev.example.moodlenative.presentation.AppUiState
import dev.example.moodlenative.presentation.AssignmentSubmissionFileSelection
import dev.example.moodlenative.storage.AppSessionSnapshot
import dev.example.moodlenative.storage.AppSessionStore
import java.net.URI

class MoodleNativeAppState private constructor(
    private val sessionStore: AppSessionStore,
    initialSnapshot: AppSessionSnapshot,
    private val repositories: MoodleNativeAppRepositories,
    defaultLmsSiteURI: URI = URI("https://moodle.example.edu"),
) {
    constructor(
        sessionStore: AppSessionStore,
        initialSnapshot: AppSessionSnapshot = sessionStore.readSnapshot(),
        defaultLmsSiteURI: URI = URI("https://moodle.example.edu"),
    ) : this(
        sessionStore = sessionStore,
        initialSnapshot = initialSnapshot,
        repositories = MoodleNativeAppRepositories(sessionStore),
        defaultLmsSiteURI = defaultLmsSiteURI,
    )

    private val actionRequests = MoodleNativeAppActionRequests(sessionStore, repositories)
    private val contentRequests = MoodleNativeAppContentRequests(sessionStore, repositories)
    private val preferenceRequests = MoodleNativeAppPreferenceRequests(sessionStore, repositories)
    private val sessionRequests = MoodleNativeAppSessionRequests(sessionStore, defaultLmsSiteURI)

    var sessionSnapshot by mutableStateOf(initialSnapshot)
        private set

    private var liveDashboardResult by mutableStateOf<LiveDashboardResult?>(null)
        private set

    private var isLoadingLiveDashboard by mutableStateOf(false)
        private set

    private var sessionActionMessage by mutableStateOf<String?>(null)
        private set

    private var selectedAssignment by mutableStateOf<LmsAssignmentItem?>(null)
        private set

    private var liveAssignmentDetailResult by mutableStateOf<LiveAssignmentDetailResult?>(null)
        private set

    private var isLoadingAssignmentDetail by mutableStateOf(false)
        private set

    private var assignmentActionMessage by mutableStateOf<String?>(null)
        private set

    private var isUpdatingAssignmentAction by mutableStateOf(false)
        private set

    private var forumIDText by mutableStateOf("")
        private set

    private var liveForumResult by mutableStateOf<LiveForumResult?>(null)
        private set

    private var isLoadingForum by mutableStateOf(false)
        private set

    private var forumActionMessage by mutableStateOf<String?>(null)
        private set

    private var isUpdatingForumAction by mutableStateOf(false)
        private set

    private var notificationActionMessage by mutableStateOf<String?>(null)
        private set

    private var isUpdatingNotifications by mutableStateOf(false)
        private set

    private var notificationPreferences by mutableStateOf<LmsNotificationPreferences?>(null)
        private set

    private var isLoadingNotificationPreferences by mutableStateOf(false)
        private set

    private var isUpdatingNotificationPreferences by mutableStateOf(false)
        private set

    private var notificationPreferencesMessage by mutableStateOf<String?>(null)
        private set

    private var selectedNotificationPreferenceProcessorName by mutableStateOf<String?>(null)
        private set

    private val notificationPreferencesPresentation: NotificationPreferencesPresentation?
        get() = notificationPreferences?.presentation(selectedNotificationPreferenceProcessorName)

    private var messagePreferences by mutableStateOf<LmsMessagePreferences?>(null)
        private set

    private var allowsSiteMessaging by mutableStateOf(false)
        private set

    private val messagePreferencesPresentation: MessagePreferencesPresentation?
        get() = messagePreferences?.presentation(allowsSiteMessaging)

    private var isLoadingMessagePreferences by mutableStateOf(false)
        private set

    private var isUpdatingMessagePreferences by mutableStateOf(false)
        private set

    private var messagePreferencesMessage by mutableStateOf<String?>(null)
        private set

    private var calendarPreferencesForm by mutableStateOf(CalendarPreferencesForm())
        private set

    private var isLoadingCalendarPreferences by mutableStateOf(false)
        private set

    private var isUpdatingCalendarPreferences by mutableStateOf(false)
        private set

    private var calendarPreferencesMessage by mutableStateOf<String?>(null)
        private set

    private var courseActionMessage by mutableStateOf<String?>(null)
        private set

    private var isUpdatingCourseFavorite by mutableStateOf(false)
        private set

    private var liveCalendarResult by mutableStateOf<LiveCalendarResult?>(null)
        private set

    private var isLoadingCalendarSubscription by mutableStateOf(false)
        private set

    val uiState: AppUiState
        get() = AppUiState.create(
            sessionSnapshot = sessionSnapshot,
            liveDashboardResult = liveDashboardResult,
            isLoadingLiveDashboard = isLoadingLiveDashboard,
            sessionActionMessage = sessionActionMessage,
            selectedAssignment = selectedAssignment,
            liveAssignmentDetailResult = liveAssignmentDetailResult,
            isLoadingAssignmentDetail = isLoadingAssignmentDetail,
            assignmentActionMessage = assignmentActionMessage,
            isUpdatingAssignmentAction = isUpdatingAssignmentAction,
            forumIDText = forumIDText,
            liveForumResult = liveForumResult,
            isLoadingForum = isLoadingForum,
            forumActionMessage = forumActionMessage,
            isUpdatingForumAction = isUpdatingForumAction,
            notificationActionMessage = notificationActionMessage,
            isUpdatingNotifications = isUpdatingNotifications,
            notificationPreferencesPresentation = notificationPreferencesPresentation,
            isLoadingNotificationPreferences = isLoadingNotificationPreferences,
            isUpdatingNotificationPreferences = isUpdatingNotificationPreferences,
            notificationPreferencesMessage = notificationPreferencesMessage,
            messagePreferencesPresentation = messagePreferencesPresentation,
            isLoadingMessagePreferences = isLoadingMessagePreferences,
            isUpdatingMessagePreferences = isUpdatingMessagePreferences,
            messagePreferencesMessage = messagePreferencesMessage,
            courseActionMessage = courseActionMessage,
            isUpdatingCourseFavorite = isUpdatingCourseFavorite,
            calendarPreferencesForm = calendarPreferencesForm,
            isLoadingCalendarPreferences = isLoadingCalendarPreferences,
            isUpdatingCalendarPreferences = isUpdatingCalendarPreferences,
            calendarPreferencesMessage = calendarPreferencesMessage,
            liveCalendarResult = liveCalendarResult,
            isLoadingCalendarSubscription = isLoadingCalendarSubscription,
        )

    fun updateSessionSnapshot(snapshot: AppSessionSnapshot) {
        sessionSnapshot = snapshot
    }

    suspend fun refreshDashboard() {
        val session = sessionSnapshot.lmsSession
        if (session == null) {
            val snapshot = sessionStore.readSnapshot()
            sessionSnapshot = snapshot
            liveDashboardResult = LiveDashboardResult.MissingSession(snapshot)
            isLoadingLiveDashboard = false
            return
        }

        sessionActionMessage = null
        isLoadingLiveDashboard = true
        val result = contentRequests.loadDashboard(currentSnapshot = sessionSnapshot)
        liveDashboardResult = result
        sessionSnapshot = result.snapshot
        isLoadingLiveDashboard = false
    }

    fun openLmsLogin(openURL: (URI) -> Unit) {
        sessionActionMessage = sessionRequests.openLmsLogin(openURL)
    }

    fun clearLmsSession() {
        val reset = sessionRequests.clearLmsSession(
            selectedAssignment = selectedAssignment,
            forumIDText = forumIDText,
        )
        applySessionReset(reset)
    }

    private fun applySessionReset(reset: MoodleNativeAppSessionReset) {
        sessionSnapshot = reset.sessionSnapshot
        liveDashboardResult = reset.liveDashboardResult
        liveAssignmentDetailResult = reset.liveAssignmentDetailResult
        assignmentActionMessage = reset.assignmentActionMessage
        isUpdatingAssignmentAction = reset.isUpdatingAssignmentAction
        liveForumResult = reset.liveForumResult
        forumActionMessage = reset.forumActionMessage
        isUpdatingForumAction = reset.isUpdatingForumAction
        notificationActionMessage = reset.notificationActionMessage
        isUpdatingNotifications = reset.isUpdatingNotifications
        notificationPreferences = reset.notificationPreferences
        isLoadingNotificationPreferences = reset.isLoadingNotificationPreferences
        isUpdatingNotificationPreferences = reset.isUpdatingNotificationPreferences
        notificationPreferencesMessage = reset.notificationPreferencesMessage
        selectedNotificationPreferenceProcessorName = reset.selectedNotificationPreferenceProcessorName
        messagePreferences = reset.messagePreferences
        allowsSiteMessaging = reset.allowsSiteMessaging
        isLoadingMessagePreferences = reset.isLoadingMessagePreferences
        isUpdatingMessagePreferences = reset.isUpdatingMessagePreferences
        messagePreferencesMessage = reset.messagePreferencesMessage
        calendarPreferencesForm = reset.calendarPreferencesForm
        isLoadingCalendarPreferences = reset.isLoadingCalendarPreferences
        isUpdatingCalendarPreferences = reset.isUpdatingCalendarPreferences
        calendarPreferencesMessage = reset.calendarPreferencesMessage
        courseActionMessage = reset.courseActionMessage
        isUpdatingCourseFavorite = reset.isUpdatingCourseFavorite
        liveCalendarResult = reset.liveCalendarResult
        isLoadingCalendarSubscription = reset.isLoadingCalendarSubscription
        sessionActionMessage = reset.sessionActionMessage
    }

    suspend fun loadAssignmentDetail(assignment: LmsAssignmentItem) {
        selectedAssignment = assignment
        if (!isUpdatingAssignmentAction) {
            assignmentActionMessage = null
        }
        isLoadingAssignmentDetail = true
        liveAssignmentDetailResult = contentRequests.loadAssignmentDetail(assignment)
        isLoadingAssignmentDetail = false
    }

    suspend fun saveAssignmentSubmission(
        assignment: LmsAssignmentItem,
        files: List<AssignmentSubmissionFileSelection>?,
        onlineTextHTML: String?,
    ) {
        isUpdatingAssignmentAction = true
        val result = actionRequests.saveAssignmentSubmission(
            assignment = assignment,
            files = files?.map { file -> file.toAssignmentSubmissionFileInput() },
            onlineTextHTML = onlineTextHTML,
        )
        applyAssignmentActionResult(result)
    }

    suspend fun startAssignmentSubmission(assignment: LmsAssignmentItem) {
        isUpdatingAssignmentAction = true
        val result = actionRequests.startAssignmentSubmission(assignment)
        applyAssignmentActionResult(result)
    }

    suspend fun submitAssignmentForGrading(
        assignment: LmsAssignmentItem,
        acceptsSubmissionStatement: Boolean = true,
    ) {
        isUpdatingAssignmentAction = true
        val result = actionRequests.submitAssignmentForGrading(
            assignment = assignment,
            acceptsSubmissionStatement = acceptsSubmissionStatement,
        )
        applyAssignmentActionResult(result)
    }

    suspend fun removeAssignmentSubmission(
        assignment: LmsAssignmentItem,
        userID: Int?,
    ) {
        isUpdatingAssignmentAction = true
        val result = actionRequests.removeAssignmentSubmission(
            assignment = assignment,
            userID = userID,
        )
        applyAssignmentActionResult(result)
    }

    fun updateForumIDText(text: String) {
        forumIDText = text
    }

    suspend fun loadForum(selectedDiscussionID: Int? = null) {
        val currentForumIDText = forumIDText
        isLoadingForum = true
        val result = contentRequests.loadForum(
            forumIDText = currentForumIDText,
            selectedDiscussionID = selectedDiscussionID,
        )
        liveForumResult = result
        sessionSnapshot = result.snapshot
        isLoadingForum = false
    }

    suspend fun markForumDiscussionViewed(discussionID: Int) {
        isUpdatingForumAction = true
        val result = actionRequests.markForumDiscussionViewed(discussionID)
        applyForumActionResult(result)
    }

    suspend fun markNotificationRead(notification: LmsNotificationItem) {
        isUpdatingNotifications = true
        val result = actionRequests.markNotificationRead(notification)
        applyNotificationActionResult(result)
    }

    suspend fun markAllNotificationsRead() {
        isUpdatingNotifications = true
        val result = actionRequests.markAllNotificationsRead()
        applyNotificationActionResult(result)
    }

    fun selectNotificationPreferenceProcessor(processorName: String) {
        selectedNotificationPreferenceProcessorName = processorName
    }

    suspend fun loadNotificationPreferences() {
        isLoadingNotificationPreferences = true
        notificationPreferencesMessage = null
        val result = preferenceRequests.loadNotificationPreferences()
        applyNotificationPreferencesResult(
            result = result,
            clearPreferencesOnFailure = true,
            successMessage = null,
        )
        isLoadingNotificationPreferences = false
    }

    suspend fun setAllNotificationsEnabled(isEnabled: Boolean) {
        if (notificationPreferences == null) {
            return
        }

        isUpdatingNotificationPreferences = true
        notificationPreferencesMessage = null
        val result = preferenceRequests.setAllNotificationsEnabled(isEnabled)
        applyNotificationPreferencesResult(
            result = result,
            clearPreferencesOnFailure = false,
            successMessage = "通知設定を更新しました。",
        )
        isUpdatingNotificationPreferences = false
    }

    suspend fun setNotificationPreferenceEnabled(
        isEnabled: Boolean,
        preferenceKey: String,
        processorName: String,
    ) {
        isUpdatingNotificationPreferences = true
        notificationPreferencesMessage = null
        val result = preferenceRequests.setNotificationPreferenceEnabled(
            isEnabled = isEnabled,
            preferenceKey = preferenceKey,
            processorName = processorName,
        )
        applyNotificationPreferencesResult(
            result = result,
            clearPreferencesOnFailure = false,
            successMessage = "通知設定を更新しました。",
        )
        isUpdatingNotificationPreferences = false
    }

    suspend fun setLegacyNotificationPreferenceState(
        isEnabled: Boolean,
        stateName: String,
        preferenceKey: String,
        processorName: String,
    ) {
        isUpdatingNotificationPreferences = true
        notificationPreferencesMessage = null
        val result = preferenceRequests.setLegacyNotificationPreferenceState(
            isEnabled = isEnabled,
            stateName = stateName,
            preferenceKey = preferenceKey,
            processorName = processorName,
        )
        applyNotificationPreferencesResult(
            result = result,
            clearPreferencesOnFailure = false,
            successMessage = "通知設定を更新しました。",
        )
        isUpdatingNotificationPreferences = false
    }

    suspend fun loadMessagePreferences() {
        isLoadingMessagePreferences = true
        messagePreferencesMessage = null
        val result = preferenceRequests.loadMessagePreferences()
        applyMessagePreferencesResult(
            result = result,
            clearPreferencesOnFailure = true,
            successMessage = null,
        )
        isLoadingMessagePreferences = false
    }

    suspend fun setMessageContactablePrivacy(value: Int) {
        isUpdatingMessagePreferences = true
        messagePreferencesMessage = null
        val result = preferenceRequests.setMessageContactablePrivacy(value)
        applyMessagePreferencesResult(
            result = result,
            clearPreferencesOnFailure = false,
            successMessage = "メッセージ設定を更新しました。",
        )
        isUpdatingMessagePreferences = false
    }

    suspend fun setInstantMessageProcessorEnabled(
        isEnabled: Boolean,
        preferenceKey: String,
        processorName: String,
    ) {
        isUpdatingMessagePreferences = true
        messagePreferencesMessage = null
        val result = preferenceRequests.setInstantMessageProcessorEnabled(
            isEnabled = isEnabled,
            preferenceKey = preferenceKey,
            processorName = processorName,
        )
        applyMessagePreferencesResult(
            result = result,
            clearPreferencesOnFailure = false,
            successMessage = "メッセージ設定を更新しました。",
        )
        isUpdatingMessagePreferences = false
    }

    suspend fun loadCalendarPreferences() {
        isLoadingCalendarPreferences = true
        calendarPreferencesMessage = null
        val result = preferenceRequests.loadCalendarPreferences()
        applyCalendarPreferencesResult(result, successMessage = null)
        isLoadingCalendarPreferences = false
    }

    suspend fun setCalendarPreferenceValue(
        key: String,
        value: String,
    ) {
        val previousForm = calendarPreferencesForm
        calendarPreferencesForm = calendarPreferencesForm.applying(key, value)
        isUpdatingCalendarPreferences = true
        calendarPreferencesMessage = null
        val result = preferenceRequests.setCalendarPreferenceValue(
            key = key,
            value = value,
        )
        if (result is LiveCalendarPreferencesResult.Failed) {
            calendarPreferencesForm = previousForm
        }
        applyCalendarPreferencesResult(result, successMessage = "カレンダー設定を更新しました。")
        isUpdatingCalendarPreferences = false
    }

    suspend fun toggleCourseFavorite(course: LmsCourseSummary) {
        setCourseFavorite(
            course = course,
            isFavorite = !course.isFavorite,
        )
    }

    private suspend fun setCourseFavorite(
        course: LmsCourseSummary,
        isFavorite: Boolean,
    ) {
        isUpdatingCourseFavorite = true
        val result = actionRequests.setCourseFavorite(
            course = course,
            isFavorite = isFavorite,
        )
        applyCourseActionResult(result)
    }

    suspend fun makeCalendarSubscription() {
        isLoadingCalendarSubscription = true
        val result = actionRequests.makeCalendarSubscription()
        liveCalendarResult = result
        sessionSnapshot = result.snapshot
        isLoadingCalendarSubscription = false
    }

    private suspend fun applyCourseActionResult(result: LiveCourseActionResult) {
        val application = result.toApplication()
        sessionSnapshot = application.snapshot
        courseActionMessage = application.message
        if (application.shouldRefreshDashboard) {
            refreshDashboard()
        }
        isUpdatingCourseFavorite = false
    }

    private suspend fun applyAssignmentActionResult(result: LiveAssignmentActionResult) {
        val application = result.toApplication()
        sessionSnapshot = application.snapshot
        assignmentActionMessage = application.message
        val assignmentToReload = application.assignmentToReload
        if (assignmentToReload != null) {
            loadAssignmentDetail(assignmentToReload)
        }
        isUpdatingAssignmentAction = false
    }

    private suspend fun applyForumActionResult(result: LiveForumActionResult) {
        val application = result.toApplication()
        sessionSnapshot = application.snapshot
        forumActionMessage = application.message
        val selectedDiscussionIDToReload = application.selectedDiscussionIDToReload
        if (selectedDiscussionIDToReload != null) {
            loadForum(selectedDiscussionID = selectedDiscussionIDToReload)
        }
        isUpdatingForumAction = false
    }

    private suspend fun applyNotificationActionResult(result: LiveNotificationActionResult) {
        val application = result.toApplication()
        sessionSnapshot = application.snapshot
        notificationActionMessage = application.message
        if (application.shouldRefreshDashboard) {
            refreshDashboard()
        }
        isUpdatingNotifications = false
    }

    private fun applyNotificationPreferencesResult(
        result: LiveNotificationPreferencesResult,
        clearPreferencesOnFailure: Boolean,
        successMessage: String?,
    ) {
        val application = result.toApplication(
            currentSelectedProcessorName = selectedNotificationPreferenceProcessorName,
            clearPreferencesOnFailure = clearPreferencesOnFailure,
            successMessage = successMessage,
        )
        sessionSnapshot = application.snapshot
        if (application.shouldReplacePreferences) {
            notificationPreferences = application.preferences
            selectedNotificationPreferenceProcessorName = application.selectedProcessorName
        }
        notificationPreferencesMessage = application.message
    }

    private fun applyMessagePreferencesResult(
        result: LiveMessagePreferencesResult,
        clearPreferencesOnFailure: Boolean,
        successMessage: String?,
    ) {
        val application = result.toApplication(
            clearPreferencesOnFailure = clearPreferencesOnFailure,
            successMessage = successMessage,
        )
        sessionSnapshot = application.snapshot
        if (application.shouldReplacePreferences) {
            messagePreferences = application.preferences
            allowsSiteMessaging = application.allowsSiteMessaging
        }
        messagePreferencesMessage = application.message
    }

    private fun applyCalendarPreferencesResult(
        result: LiveCalendarPreferencesResult,
        successMessage: String?,
    ) {
        val application = result.toApplication(
            currentForm = calendarPreferencesForm,
            successMessage = successMessage,
        )
        sessionSnapshot = application.snapshot
        calendarPreferencesForm = application.form
        calendarPreferencesMessage = application.message
    }

}

private fun AssignmentSubmissionFileSelection.toAssignmentSubmissionFileInput(): AssignmentSubmissionFileInput =
    AssignmentSubmissionFileInput(
        fileName = fileName,
        mimeType = mimeType,
        data = data,
        existingFile = existingFileURL?.let { url ->
            ExistingAssignmentSubmissionFileInput(
                fileName = fileName,
                mimeType = mimeType,
                fileURL = url,
            )
        },
    )
