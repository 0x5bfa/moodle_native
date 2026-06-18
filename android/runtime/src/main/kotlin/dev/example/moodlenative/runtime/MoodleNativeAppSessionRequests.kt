package dev.example.moodlenative.runtime

import dev.example.moodlenative.core.LmsAssignmentItem
import dev.example.moodlenative.core.LmsMobileAuthenticationLaunchURLBuilder
import dev.example.moodlenative.storage.AppSessionStore
import java.net.URI

internal class MoodleNativeAppSessionRequests(
    private val sessionStore: AppSessionStore,
    private val defaultLmsSiteURI: URI,
) {
    fun openLmsLogin(openURL: (URI) -> Unit): String =
        runCatching {
            val launchURL = LmsMobileAuthenticationLaunchURLBuilder.build(siteURL = defaultLmsSiteURI)
            openURL(launchURL)
        }.fold(
            onSuccess = { "Moodle のログイン画面を開きました。" },
            onFailure = { error -> error.message ?: "Moodle のログイン画面を開けませんでした。" },
        )

    fun clearLmsSession(
        selectedAssignment: LmsAssignmentItem?,
        forumIDText: String,
    ): MoodleNativeAppSessionReset {
        sessionStore.clearLmsSession()
        return sessionStore.readSnapshot().toMoodleNativeAppSessionReset(
            selectedAssignment = selectedAssignment,
            forumIDText = forumIDText,
        )
    }
}
