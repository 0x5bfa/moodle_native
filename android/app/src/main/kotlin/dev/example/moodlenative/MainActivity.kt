package dev.example.moodlenative

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import dev.example.moodlenative.core.LmsAuthenticationCallbackParser
import dev.example.moodlenative.runtime.MoodleNativeAppState
import dev.example.moodlenative.storage.AndroidEncryptedAppSessionStore
import dev.example.moodlenative.storage.AppSessionSnapshot
import dev.example.moodlenative.ui.MoodleNativeApp
import java.net.URI
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    private lateinit var sessionStore: AndroidEncryptedAppSessionStore
    private var updateSessionSnapshot: ((AppSessionSnapshot) -> Unit)? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        sessionStore = AndroidEncryptedAppSessionStore(this)
        val initialSnapshot = updateSessionFromIntent(intent)

        super.onCreate(savedInstanceState)

        setContent {
            val appState = remember {
                MoodleNativeAppState(
                    sessionStore = sessionStore,
                    initialSnapshot = initialSnapshot,
                    defaultLmsSiteURI = DEFAULT_LMS_SITE_URI,
                )
            }
            val coroutineScope = rememberCoroutineScope()
            DisposableEffect(Unit) {
                updateSessionSnapshot = appState::updateSessionSnapshot
                onDispose { updateSessionSnapshot = null }
            }

            LaunchedEffect(appState.sessionSnapshot.lmsSession?.token) {
                appState.refreshDashboard()
            }

            LaunchedEffect(appState.sessionSnapshot.lmsSession?.token) {
                if (appState.sessionSnapshot.lmsSession != null) {
                    appState.loadNotificationPreferences()
                    appState.loadMessagePreferences()
                    appState.loadCalendarPreferences()
                }
            }

            MoodleNativeApp(
                appState = appState.uiState,
                onStartLmsLogin = {
                    appState.openLmsLogin { launchURL ->
                        startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(launchURL.toString())))
                    }
                },
                onRefreshDashboard = {
                    coroutineScope.launch { appState.refreshDashboard() }
                },
                onClearLmsSession = {
                    appState.clearLmsSession()
                },
                onOpenAssignment = { assignment ->
                    coroutineScope.launch { appState.loadAssignmentDetail(assignment) }
                },
                onSaveAssignmentSubmission = { assignment, files, onlineTextHTML ->
                    coroutineScope.launch {
                        appState.saveAssignmentSubmission(
                            assignment = assignment,
                            files = files,
                            onlineTextHTML = onlineTextHTML,
                        )
                    }
                },
                onStartAssignmentSubmission = { assignment ->
                    coroutineScope.launch { appState.startAssignmentSubmission(assignment) }
                },
                onSubmitAssignmentForGrading = { assignment ->
                    coroutineScope.launch { appState.submitAssignmentForGrading(assignment) }
                },
                onRemoveAssignmentSubmission = { assignment, userID ->
                    coroutineScope.launch { appState.removeAssignmentSubmission(assignment, userID) }
                },
                onForumIDChange = { forumIDText ->
                    appState.updateForumIDText(forumIDText)
                },
                onLoadForum = {
                    coroutineScope.launch { appState.loadForum() }
                },
                onSelectForumDiscussion = { discussionID ->
                    coroutineScope.launch { appState.loadForum(selectedDiscussionID = discussionID) }
                },
                onMarkForumDiscussionViewed = { discussionID ->
                    coroutineScope.launch { appState.markForumDiscussionViewed(discussionID) }
                },
                onMarkNotificationRead = { notification ->
                    coroutineScope.launch { appState.markNotificationRead(notification) }
                },
                onMarkAllNotificationsRead = {
                    coroutineScope.launch { appState.markAllNotificationsRead() }
                },
                onLoadNotificationPreferences = {
                    coroutineScope.launch { appState.loadNotificationPreferences() }
                },
                onSelectNotificationPreferenceProcessor = { processorName ->
                    appState.selectNotificationPreferenceProcessor(processorName)
                },
                onSetAllNotificationsEnabled = { isEnabled ->
                    coroutineScope.launch { appState.setAllNotificationsEnabled(isEnabled) }
                },
                onSetNotificationPreferenceEnabled = { preferenceKey, processorName, isEnabled ->
                    coroutineScope.launch {
                        appState.setNotificationPreferenceEnabled(
                            isEnabled = isEnabled,
                            preferenceKey = preferenceKey,
                            processorName = processorName,
                        )
                    }
                },
                onSetLegacyNotificationPreferenceState = { preferenceKey, processorName, stateName, isEnabled ->
                    coroutineScope.launch {
                        appState.setLegacyNotificationPreferenceState(
                            isEnabled = isEnabled,
                            stateName = stateName,
                            preferenceKey = preferenceKey,
                            processorName = processorName,
                        )
                    }
                },
                onLoadMessagePreferences = {
                    coroutineScope.launch { appState.loadMessagePreferences() }
                },
                onSetMessageContactablePrivacy = { value ->
                    coroutineScope.launch { appState.setMessageContactablePrivacy(value) }
                },
                onSetInstantMessageProcessorEnabled = { preferenceKey, processorName, isEnabled ->
                    coroutineScope.launch {
                        appState.setInstantMessageProcessorEnabled(
                            isEnabled = isEnabled,
                            preferenceKey = preferenceKey,
                            processorName = processorName,
                        )
                    }
                },
                onLoadCalendarPreferences = {
                    coroutineScope.launch { appState.loadCalendarPreferences() }
                },
                onSetCalendarPreferenceValue = { key, value ->
                    coroutineScope.launch {
                        appState.setCalendarPreferenceValue(
                            key = key,
                            value = value,
                        )
                    }
                },
                onToggleCourseFavorite = { course ->
                    coroutineScope.launch { appState.toggleCourseFavorite(course) }
                },
                onMakeCalendarSubscription = {
                    coroutineScope.launch { appState.makeCalendarSubscription() }
                },
            )
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        updateSessionSnapshot?.invoke(updateSessionFromIntent(intent))
    }

    private fun updateSessionFromIntent(intent: Intent?): AppSessionSnapshot {
        val callbackURL = intent?.data ?: return sessionStore.readSnapshot()
        runCatching {
            LmsAuthenticationCallbackParser.parse(
                callbackURL = URI(callbackURL.toString()),
                fallbackSiteURL = DEFAULT_LMS_SITE_URI,
            )
        }.onSuccess { session ->
            sessionStore.updateLmsSession(session)
        }

        return sessionStore.readSnapshot()
    }

    private companion object {
        val DEFAULT_LMS_SITE_URI: URI = URI("https://moodle.example.edu")
    }
}
