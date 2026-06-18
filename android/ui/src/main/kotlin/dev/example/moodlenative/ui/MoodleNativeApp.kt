package dev.example.moodlenative.ui

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import dev.example.moodlenative.core.LmsAssignmentItem
import dev.example.moodlenative.core.LmsNotificationItem
import dev.example.moodlenative.features.LmsCourseSummary
import dev.example.moodlenative.presentation.AppUiState
import dev.example.moodlenative.presentation.AssignmentSubmissionFileSelection

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MoodleNativeApp(
    appState: AppUiState = AppUiState.demo(),
    onStartLmsLogin: () -> Unit = {},
    onRefreshDashboard: () -> Unit = {},
    onClearLmsSession: () -> Unit = {},
    onOpenAssignment: (LmsAssignmentItem) -> Unit = {},
    onSaveAssignmentSubmission: (LmsAssignmentItem, List<AssignmentSubmissionFileSelection>?, String?) -> Unit = { _, _, _ -> },
    onStartAssignmentSubmission: (LmsAssignmentItem) -> Unit = {},
    onSubmitAssignmentForGrading: (LmsAssignmentItem) -> Unit = {},
    onRemoveAssignmentSubmission: (LmsAssignmentItem, Int?) -> Unit = { _, _ -> },
    onForumIDChange: (String) -> Unit = {},
    onLoadForum: () -> Unit = {},
    onSelectForumDiscussion: (Int) -> Unit = {},
    onMarkForumDiscussionViewed: (Int) -> Unit = {},
    onMarkNotificationRead: (LmsNotificationItem) -> Unit = {},
    onMarkAllNotificationsRead: () -> Unit = {},
    onLoadNotificationPreferences: () -> Unit = {},
    onSelectNotificationPreferenceProcessor: (String) -> Unit = {},
    onSetAllNotificationsEnabled: (Boolean) -> Unit = {},
    onSetNotificationPreferenceEnabled: (String, String, Boolean) -> Unit = { _, _, _ -> },
    onSetLegacyNotificationPreferenceState: (String, String, String, Boolean) -> Unit = { _, _, _, _ -> },
    onLoadMessagePreferences: () -> Unit = {},
    onSetMessageContactablePrivacy: (Int) -> Unit = {},
    onSetInstantMessageProcessorEnabled: (String, String, Boolean) -> Unit = { _, _, _ -> },
    onToggleCourseFavorite: (LmsCourseSummary) -> Unit = {},
    onLoadCalendarPreferences: () -> Unit = {},
    onSetCalendarPreferenceValue: (String, String) -> Unit = { _, _ -> },
    onMakeCalendarSubscription: () -> Unit = {},
) {
    var selectedTab by remember { mutableStateOf(AppTab.HOME) }
    var selectedNotificationID by remember { mutableStateOf<String?>(null) }

    MaterialTheme(colorScheme = MoodleNativeColorScheme) {
        Scaffold(
            topBar = {
                TopAppBar(
                    title = {
                        Text(
                            text = selectedTab.title,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    },
                )
            },
            bottomBar = {
                NavigationBar {
                    AppTab.entries.forEach { tab ->
                        NavigationBarItem(
                            selected = selectedTab == tab,
                            onClick = { selectedTab = tab },
                            icon = { Icon(tab.icon, contentDescription = null) },
                            label = { Text(tab.title) },
                        )
                    }
                }
            },
        ) { innerPadding ->
            Surface(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding),
                color = MaterialTheme.colorScheme.background,
            ) {
                when (selectedTab) {
                    AppTab.HOME -> HomeScreen(
                        appState = appState,
                        onToggleCourseFavorite = onToggleCourseFavorite,
                    )
                    AppTab.TIMETABLE -> TimetableScreen(
                        appState = appState,
                        onToggleCourseFavorite = onToggleCourseFavorite,
                    )
                    AppTab.ASSIGNMENTS -> AssignmentsScreen(
                        appState = appState,
                        onOpenAssignment = onOpenAssignment,
                        onSaveAssignmentSubmission = onSaveAssignmentSubmission,
                        onStartAssignmentSubmission = onStartAssignmentSubmission,
                        onSubmitAssignmentForGrading = onSubmitAssignmentForGrading,
                        onRemoveAssignmentSubmission = onRemoveAssignmentSubmission,
                    )
                    AppTab.FORUM -> ForumScreen(
                        appState = appState,
                        onForumIDChange = onForumIDChange,
                        onLoadForum = onLoadForum,
                        onSelectDiscussion = onSelectForumDiscussion,
                        onMarkDiscussionViewed = onMarkForumDiscussionViewed,
                    )
                    AppTab.NOTIFICATIONS -> NotificationsScreen(
                        appState = appState,
                        selectedNotificationID = selectedNotificationID,
                        onSelectNotification = { selectedNotificationID = it },
                        onMarkNotificationRead = onMarkNotificationRead,
                        onMarkAllNotificationsRead = onMarkAllNotificationsRead,
                    )
                    AppTab.SETTINGS -> SettingsScreen(
                        appState = appState,
                        onStartLmsLogin = onStartLmsLogin,
                        onRefreshDashboard = onRefreshDashboard,
                        onClearLmsSession = onClearLmsSession,
                        onLoadNotificationPreferences = onLoadNotificationPreferences,
                        onSelectNotificationPreferenceProcessor = onSelectNotificationPreferenceProcessor,
                        onSetAllNotificationsEnabled = onSetAllNotificationsEnabled,
                        onSetNotificationPreferenceEnabled = onSetNotificationPreferenceEnabled,
                        onSetLegacyNotificationPreferenceState = onSetLegacyNotificationPreferenceState,
                        onLoadMessagePreferences = onLoadMessagePreferences,
                        onSetMessageContactablePrivacy = onSetMessageContactablePrivacy,
                        onSetInstantMessageProcessorEnabled = onSetInstantMessageProcessorEnabled,
                        onLoadCalendarPreferences = onLoadCalendarPreferences,
                        onSetCalendarPreferenceValue = onSetCalendarPreferenceValue,
                        onMakeCalendarSubscription = onMakeCalendarSubscription,
                    )
                }
            }
        }
    }
}

@Preview
@Composable
private fun MoodleNativeAppPreview() {
    MoodleNativeApp()
}
