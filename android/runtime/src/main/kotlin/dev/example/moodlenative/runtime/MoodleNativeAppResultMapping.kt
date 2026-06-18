package dev.example.moodlenative.runtime

import dev.example.moodlenative.data.AssignmentAction
import dev.example.moodlenative.data.CourseAction
import dev.example.moodlenative.data.ForumAction
import dev.example.moodlenative.data.LiveAssignmentActionResult
import dev.example.moodlenative.data.LiveCourseActionResult
import dev.example.moodlenative.data.LiveDashboardResult
import dev.example.moodlenative.data.LiveForumActionResult
import dev.example.moodlenative.data.LiveForumResult
import dev.example.moodlenative.data.LiveNotificationActionResult
import dev.example.moodlenative.data.NotificationAction
import dev.example.moodlenative.storage.AppSessionSnapshot

internal val LiveDashboardResult.snapshot: AppSessionSnapshot
    get() = when (this) {
        is LiveDashboardResult.Loaded -> dashboard.snapshot
        is LiveDashboardResult.MissingSession -> snapshot
        is LiveDashboardResult.Failed -> snapshot
    }

internal val LiveForumResult.snapshot: AppSessionSnapshot
    get() = when (this) {
        is LiveForumResult.InvalidForumID -> snapshot
        is LiveForumResult.MissingSession -> snapshot
        is LiveForumResult.Loaded -> snapshot
        is LiveForumResult.Failed -> snapshot
    }

internal val LiveAssignmentActionResult.displayMessage: String
    get() = when (this) {
        is LiveAssignmentActionResult.MissingSession -> "Moodle に接続してください。"
        is LiveAssignmentActionResult.MissingUserID -> "提出削除に必要な user ID がありません。"
        is LiveAssignmentActionResult.Completed -> when (action) {
            is AssignmentAction.SaveSubmission -> "提出を保存しました。"
            is AssignmentAction.SubmitForGrading -> "提出を確定しました。"
            is AssignmentAction.StartSubmission -> "提出を開始しました。"
            is AssignmentAction.RemoveSubmission -> "提出を削除しました。"
        }
        is LiveAssignmentActionResult.Failed -> message
    }

internal val LiveForumActionResult.displayMessage: String
    get() = when (this) {
        is LiveForumActionResult.MissingSession -> "Moodle に接続してください。"
        is LiveForumActionResult.Completed -> when (action) {
            is ForumAction.MarkDiscussionViewed -> "フォーラムを閲覧済みにしました。"
        }
        is LiveForumActionResult.Failed -> message
    }

internal val LiveNotificationActionResult.displayMessage: String
    get() = when (this) {
        is LiveNotificationActionResult.MissingSession -> "Moodle に接続してください。"
        is LiveNotificationActionResult.MissingNotificationID -> "この通知は既読操作に必要な ID がありません。"
        is LiveNotificationActionResult.Completed -> when (action) {
            is NotificationAction.MarkSingle -> "通知を既読にしました。"
            NotificationAction.MarkAll -> "すべての通知を既読にしました。"
        }
        is LiveNotificationActionResult.Failed -> message
    }

internal val LiveCourseActionResult.displayMessage: String
    get() = when (this) {
        is LiveCourseActionResult.MissingSession -> "Moodle に接続してください。"
        is LiveCourseActionResult.Completed -> when (val completedAction = action) {
            is CourseAction.SetFavorite -> if (completedAction.isFavorite) {
                "お気に入りに追加しました。"
            } else {
                "お気に入りから外しました。"
            }
        }
        is LiveCourseActionResult.Failed -> message
    }
