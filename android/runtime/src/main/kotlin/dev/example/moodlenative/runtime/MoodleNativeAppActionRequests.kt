package dev.example.moodlenative.runtime

import dev.example.moodlenative.core.LmsAssignmentItem
import dev.example.moodlenative.core.LmsNotificationItem
import dev.example.moodlenative.data.AssignmentSubmissionFileInput
import dev.example.moodlenative.data.LiveAssignmentActionResult
import dev.example.moodlenative.data.LiveCalendarResult
import dev.example.moodlenative.data.LiveCourseActionResult
import dev.example.moodlenative.data.LiveForumActionResult
import dev.example.moodlenative.data.LiveNotificationActionResult
import dev.example.moodlenative.features.LmsCourseSummary
import dev.example.moodlenative.storage.AppSessionStore

internal class MoodleNativeAppActionRequests(
    private val sessionStore: AppSessionStore,
    private val repositories: MoodleNativeAppRepositories,
) {
    suspend fun saveAssignmentSubmission(
        assignment: LmsAssignmentItem,
        files: List<AssignmentSubmissionFileInput>?,
        onlineTextHTML: String?,
    ): LiveAssignmentActionResult {
        return runMoodleNativeAppRequest(
            onFailure = { error ->
                error.toFailedSaveAssignmentSubmissionResult(
                    snapshot = sessionStore.readSnapshot(),
                    assignment = assignment,
                    onlineTextHTML = onlineTextHTML,
                    fileCount = files?.size,
                )
            },
        ) {
            repositories.assignmentAction.uploadAndSaveSubmission(
                assignment = assignment,
                files = files,
                onlineTextHTML = onlineTextHTML,
            )
        }
    }

    suspend fun startAssignmentSubmission(assignment: LmsAssignmentItem): LiveAssignmentActionResult =
        runMoodleNativeAppRequest(
            onFailure = { error ->
                error.toFailedStartAssignmentSubmissionResult(
                    snapshot = sessionStore.readSnapshot(),
                    assignment = assignment,
                )
            },
        ) {
            repositories.assignmentAction.startSubmission(assignment)
        }

    suspend fun submitAssignmentForGrading(
        assignment: LmsAssignmentItem,
        acceptsSubmissionStatement: Boolean,
    ): LiveAssignmentActionResult =
        runMoodleNativeAppRequest(
            onFailure = { error ->
                error.toFailedSubmitAssignmentForGradingResult(
                    snapshot = sessionStore.readSnapshot(),
                    assignment = assignment,
                    acceptsSubmissionStatement = acceptsSubmissionStatement,
                )
            },
        ) {
            repositories.assignmentAction.submitForGrading(
                assignment = assignment,
                acceptsSubmissionStatement = acceptsSubmissionStatement,
            )
        }

    suspend fun removeAssignmentSubmission(
        assignment: LmsAssignmentItem,
        userID: Int?,
    ): LiveAssignmentActionResult =
        runMoodleNativeAppRequest(
            onFailure = { error ->
                error.toFailedRemoveAssignmentSubmissionResult(
                    snapshot = sessionStore.readSnapshot(),
                    assignment = assignment,
                    userID = userID,
                )
            },
        ) {
            repositories.assignmentAction.removeSubmission(
                assignment = assignment,
                userID = userID,
            )
        }

    suspend fun markForumDiscussionViewed(discussionID: Int): LiveForumActionResult =
        runMoodleNativeAppRequest(
            onFailure = { error ->
                error.toFailedForumActionResult(
                    snapshot = sessionStore.readSnapshot(),
                    discussionID = discussionID,
                )
            },
        ) {
            repositories.forumAction.markDiscussionViewed(discussionID)
        }

    suspend fun markNotificationRead(notification: LmsNotificationItem): LiveNotificationActionResult =
        runMoodleNativeAppRequest(
            onFailure = { error ->
                error.toFailedMarkNotificationReadResult(
                    snapshot = sessionStore.readSnapshot(),
                    notification = notification,
                )
            },
        ) {
            repositories.notification.markNotificationRead(notification)
        }

    suspend fun markAllNotificationsRead(): LiveNotificationActionResult =
        runMoodleNativeAppRequest(
            onFailure = { error ->
                error.toFailedMarkAllNotificationsReadResult(
                    snapshot = sessionStore.readSnapshot(),
                )
            },
        ) {
            repositories.notification.markAllNotificationsRead()
        }

    suspend fun setCourseFavorite(
        course: LmsCourseSummary,
        isFavorite: Boolean,
    ): LiveCourseActionResult =
        runMoodleNativeAppRequest(
            onFailure = { error ->
                error.toFailedSetCourseFavoriteResult(
                    snapshot = sessionStore.readSnapshot(),
                    course = course,
                    isFavorite = isFavorite,
                )
            },
        ) {
            repositories.courseAction.setCourseFavorite(
                course = course,
                isFavorite = isFavorite,
            )
        }

    suspend fun makeCalendarSubscription(): LiveCalendarResult =
        runMoodleNativeAppRequest(
            onFailure = { error ->
                error.toFailedCalendarSubscriptionResult(
                    snapshot = sessionStore.readSnapshot(),
                )
            },
        ) {
            repositories.calendar.makeCalendarSubscription()
        }
}
