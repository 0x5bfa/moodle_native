package dev.example.moodlenative.runtime

import dev.example.moodlenative.core.LmsAssignmentItem
import dev.example.moodlenative.core.LmsNotificationItem
import dev.example.moodlenative.data.AssignmentAction
import dev.example.moodlenative.data.AssignmentSubmissionOnlineTextInput
import dev.example.moodlenative.data.CourseAction
import dev.example.moodlenative.data.ForumAction
import dev.example.moodlenative.data.LiveAssignmentActionResult
import dev.example.moodlenative.data.LiveAssignmentDetailResult
import dev.example.moodlenative.data.LiveCalendarPreferencesResult
import dev.example.moodlenative.data.LiveCalendarResult
import dev.example.moodlenative.data.LiveCourseActionResult
import dev.example.moodlenative.data.LiveDashboardResult
import dev.example.moodlenative.data.LiveForumActionResult
import dev.example.moodlenative.data.LiveForumResult
import dev.example.moodlenative.data.LiveMessagePreferencesResult
import dev.example.moodlenative.data.LiveNotificationActionResult
import dev.example.moodlenative.data.LiveNotificationPreferencesResult
import dev.example.moodlenative.data.NotificationAction
import dev.example.moodlenative.features.LmsCourseSummary
import dev.example.moodlenative.storage.AppSessionSnapshot

internal fun Throwable.toFailedDashboardResult(snapshot: AppSessionSnapshot): LiveDashboardResult =
    LiveDashboardResult.Failed(
        snapshot = snapshot,
        message = message ?: "Moodle のデータを取得できませんでした。",
    )

internal fun Throwable.toFailedAssignmentDetailResult(
    snapshot: AppSessionSnapshot,
    assignment: LmsAssignmentItem,
): LiveAssignmentDetailResult =
    LiveAssignmentDetailResult.Failed(
        snapshot = snapshot,
        assignment = assignment,
        message = message ?: "課題詳細を取得できませんでした。",
    )

internal fun Throwable.toFailedSaveAssignmentSubmissionResult(
    snapshot: AppSessionSnapshot,
    assignment: LmsAssignmentItem,
    onlineTextHTML: String?,
    fileCount: Int?,
): LiveAssignmentActionResult =
    LiveAssignmentActionResult.Failed(
        snapshot = snapshot,
        action = AssignmentAction.SaveSubmission(
            assignment = assignment,
            fileDraftItemID = null,
            onlineText = onlineTextHTML?.let { html -> AssignmentSubmissionOnlineTextInput(html = html) },
            fileCount = fileCount,
        ),
        message = message ?: "課題提出を保存できませんでした。",
    )

internal fun Throwable.toFailedStartAssignmentSubmissionResult(
    snapshot: AppSessionSnapshot,
    assignment: LmsAssignmentItem,
): LiveAssignmentActionResult =
    LiveAssignmentActionResult.Failed(
        snapshot = snapshot,
        action = AssignmentAction.StartSubmission(assignment),
        message = message ?: "課題提出を開始できませんでした。",
    )

internal fun Throwable.toFailedSubmitAssignmentForGradingResult(
    snapshot: AppSessionSnapshot,
    assignment: LmsAssignmentItem,
    acceptsSubmissionStatement: Boolean,
): LiveAssignmentActionResult =
    LiveAssignmentActionResult.Failed(
        snapshot = snapshot,
        action = AssignmentAction.SubmitForGrading(
            assignment = assignment,
            acceptsSubmissionStatement = acceptsSubmissionStatement,
        ),
        message = message ?: "課題提出を確定できませんでした。",
    )

internal fun Throwable.toFailedRemoveAssignmentSubmissionResult(
    snapshot: AppSessionSnapshot,
    assignment: LmsAssignmentItem,
    userID: Int?,
): LiveAssignmentActionResult =
    LiveAssignmentActionResult.Failed(
        snapshot = snapshot,
        action = AssignmentAction.RemoveSubmission(assignment = assignment, userID = userID),
        message = message ?: "課題提出を削除できませんでした。",
    )

internal fun Throwable.toFailedForumResult(
    snapshot: AppSessionSnapshot,
    forumIDText: String,
): LiveForumResult {
    val trimmedForumIDText = forumIDText.trim()
    val forumID = trimmedForumIDText.toIntOrNull()
    return if (forumID == null) {
        LiveForumResult.InvalidForumID(
            snapshot = snapshot,
            forumIDText = trimmedForumIDText,
        )
    } else {
        LiveForumResult.Failed(
            snapshot = snapshot,
            forumID = forumID,
            message = message ?: "フォーラムを取得できませんでした。",
        )
    }
}

internal fun Throwable.toFailedForumActionResult(
    snapshot: AppSessionSnapshot,
    discussionID: Int,
): LiveForumActionResult =
    LiveForumActionResult.Failed(
        snapshot = snapshot,
        action = ForumAction.MarkDiscussionViewed(discussionID),
        message = message ?: "フォーラムを閲覧済みにできませんでした。",
    )

internal fun Throwable.toFailedMarkNotificationReadResult(
    snapshot: AppSessionSnapshot,
    notification: LmsNotificationItem,
): LiveNotificationActionResult =
    LiveNotificationActionResult.Failed(
        snapshot = snapshot,
        action = NotificationAction.MarkSingle(notification),
        message = message ?: "通知を既読にできませんでした。",
    )

internal fun Throwable.toFailedMarkAllNotificationsReadResult(snapshot: AppSessionSnapshot): LiveNotificationActionResult =
    LiveNotificationActionResult.Failed(
        snapshot = snapshot,
        action = NotificationAction.MarkAll,
        message = message ?: "すべての通知を既読にできませんでした。",
    )

internal fun Throwable.toFailedLoadNotificationPreferencesResult(
    snapshot: AppSessionSnapshot,
): LiveNotificationPreferencesResult =
    LiveNotificationPreferencesResult.Failed(
        snapshot = snapshot,
        message = message ?: "通知設定を取得できませんでした。",
    )

internal fun Throwable.toFailedUpdateNotificationPreferencesResult(
    snapshot: AppSessionSnapshot,
): LiveNotificationPreferencesResult =
    LiveNotificationPreferencesResult.Failed(
        snapshot = snapshot,
        message = message ?: "通知設定を更新できませんでした。",
    )

internal fun Throwable.toFailedLoadMessagePreferencesResult(snapshot: AppSessionSnapshot): LiveMessagePreferencesResult =
    LiveMessagePreferencesResult.Failed(
        snapshot = snapshot,
        message = message ?: "メッセージ設定を取得できませんでした。",
    )

internal fun Throwable.toFailedUpdateMessagePreferencesResult(snapshot: AppSessionSnapshot): LiveMessagePreferencesResult =
    LiveMessagePreferencesResult.Failed(
        snapshot = snapshot,
        message = message ?: "メッセージ設定を更新できませんでした。",
    )

internal fun Throwable.toFailedLoadCalendarPreferencesResult(
    snapshot: AppSessionSnapshot,
): LiveCalendarPreferencesResult =
    LiveCalendarPreferencesResult.Failed(
        snapshot = snapshot,
        message = message ?: "カレンダー設定を取得できませんでした。",
    )

internal fun Throwable.toFailedUpdateCalendarPreferencesResult(
    snapshot: AppSessionSnapshot,
): LiveCalendarPreferencesResult =
    LiveCalendarPreferencesResult.Failed(
        snapshot = snapshot,
        message = message ?: "カレンダー設定を更新できませんでした。",
    )

internal fun Throwable.toFailedSetCourseFavoriteResult(
    snapshot: AppSessionSnapshot,
    course: LmsCourseSummary,
    isFavorite: Boolean,
): LiveCourseActionResult =
    LiveCourseActionResult.Failed(
        snapshot = snapshot,
        action = CourseAction.SetFavorite(course = course, isFavorite = isFavorite),
        message = message ?: "お気に入りを更新できませんでした。",
    )

internal fun Throwable.toFailedCalendarSubscriptionResult(snapshot: AppSessionSnapshot): LiveCalendarResult =
    LiveCalendarResult.Failed(
        snapshot = snapshot,
        message = message ?: "カレンダー URL を生成できませんでした。",
    )
