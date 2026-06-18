package dev.example.moodlenative.runtime

import dev.example.moodlenative.core.LmsAssignmentItem
import dev.example.moodlenative.data.ForumAction
import dev.example.moodlenative.data.LiveAssignmentActionResult
import dev.example.moodlenative.data.LiveCourseActionResult
import dev.example.moodlenative.data.LiveForumActionResult
import dev.example.moodlenative.data.LiveNotificationActionResult
import dev.example.moodlenative.storage.AppSessionSnapshot

internal data class CourseActionResultApplication(
    val snapshot: AppSessionSnapshot,
    val message: String,
    val shouldRefreshDashboard: Boolean,
)

internal data class AssignmentActionResultApplication(
    val snapshot: AppSessionSnapshot,
    val message: String,
    val assignmentToReload: LmsAssignmentItem?,
)

internal data class ForumActionResultApplication(
    val snapshot: AppSessionSnapshot,
    val message: String,
    val selectedDiscussionIDToReload: Int?,
)

internal data class NotificationActionResultApplication(
    val snapshot: AppSessionSnapshot,
    val message: String,
    val shouldRefreshDashboard: Boolean,
)

internal fun LiveCourseActionResult.toApplication(): CourseActionResultApplication =
    CourseActionResultApplication(
        snapshot = snapshot,
        message = displayMessage,
        shouldRefreshDashboard = this is LiveCourseActionResult.Completed,
    )

internal fun LiveAssignmentActionResult.toApplication(): AssignmentActionResultApplication =
    AssignmentActionResultApplication(
        snapshot = snapshot,
        message = displayMessage,
        assignmentToReload = when (this) {
            is LiveAssignmentActionResult.Completed -> action.assignment
            is LiveAssignmentActionResult.Failed,
            is LiveAssignmentActionResult.MissingSession,
            is LiveAssignmentActionResult.MissingUserID -> null
        },
    )

internal fun LiveForumActionResult.toApplication(): ForumActionResultApplication =
    ForumActionResultApplication(
        snapshot = snapshot,
        message = displayMessage,
        selectedDiscussionIDToReload = when (this) {
            is LiveForumActionResult.Completed -> when (val completedAction = action) {
                is ForumAction.MarkDiscussionViewed -> completedAction.discussionID
            }
            is LiveForumActionResult.Failed,
            is LiveForumActionResult.MissingSession -> null
        },
    )

internal fun LiveNotificationActionResult.toApplication(): NotificationActionResultApplication =
    NotificationActionResultApplication(
        snapshot = snapshot,
        message = displayMessage,
        shouldRefreshDashboard = this is LiveNotificationActionResult.Completed,
    )
