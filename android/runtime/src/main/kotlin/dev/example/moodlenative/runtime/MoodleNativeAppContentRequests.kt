package dev.example.moodlenative.runtime

import dev.example.moodlenative.core.LmsAssignmentItem
import dev.example.moodlenative.data.LiveAssignmentDetailResult
import dev.example.moodlenative.data.LiveDashboardResult
import dev.example.moodlenative.data.LiveForumResult
import dev.example.moodlenative.storage.AppSessionSnapshot
import dev.example.moodlenative.storage.AppSessionStore

internal class MoodleNativeAppContentRequests(
    private val sessionStore: AppSessionStore,
    private val repositories: MoodleNativeAppRepositories,
) {
    suspend fun loadDashboard(currentSnapshot: AppSessionSnapshot): LiveDashboardResult =
        runMoodleNativeAppRequest(
            onFailure = { error ->
                error.toFailedDashboardResult(snapshot = currentSnapshot)
            },
        ) {
            repositories.live.loadDashboard()
        }

    suspend fun loadAssignmentDetail(assignment: LmsAssignmentItem): LiveAssignmentDetailResult =
        runMoodleNativeAppRequest(
            onFailure = { error ->
                error.toFailedAssignmentDetailResult(
                    snapshot = sessionStore.readSnapshot(),
                    assignment = assignment,
                )
            },
        ) {
            repositories.assignmentDetail.loadDetail(assignment)
        }

    suspend fun loadForum(
        forumIDText: String,
        selectedDiscussionID: Int?,
    ): LiveForumResult =
        runMoodleNativeAppRequest(
            onFailure = { error ->
                error.toFailedForumResult(
                    snapshot = sessionStore.readSnapshot(),
                    forumIDText = forumIDText,
                )
            },
        ) {
            repositories.forum.loadForum(
                forumIDText = forumIDText,
                selectedDiscussionID = selectedDiscussionID,
            )
        }
}
