package dev.example.moodlenative.runtime

import dev.example.moodlenative.data.LiveForumResult
import dev.example.moodlenative.features.LmsForumDiscussionPresentation
import dev.example.moodlenative.features.LmsForumPostThreadPresentationNode
import dev.example.moodlenative.features.presentation
import dev.example.moodlenative.features.threadPresentation

internal data class ForumPresentationResult(
    val discussions: List<LmsForumDiscussionPresentation>,
    val selectedDiscussion: LmsForumDiscussionPresentation?,
    val postThreads: List<LmsForumPostThreadPresentationNode>,
    val partialErrors: List<String>,
    val error: String?,
    val primaryLabel: String,
    val statusLabel: String,
)

internal fun resolveForumPresentation(
    forumIDText: String,
    liveForumResult: LiveForumResult?,
    isLoadingForum: Boolean,
): ForumPresentationResult {
    val liveForum = liveForumResult as? LiveForumResult.Loaded
    val discussions = liveForum?.discussions.orEmpty().map { discussion -> discussion.presentation }
    val postThreads = liveForum?.posts.orEmpty().threadPresentation()
    val postCount = liveForum?.posts?.size ?: 0
    val error = when (liveForumResult) {
        is LiveForumResult.InvalidForumID -> {
            if (liveForumResult.forumIDText.isBlank()) "Forum ID が未入力です。" else "Forum ID は数値で入力してください。"
        }
        is LiveForumResult.MissingSession -> "Moodle に接続してください。"
        is LiveForumResult.Failed -> liveForumResult.message
        is LiveForumResult.Loaded,
        null,
        -> null
    }
    val primaryLabel = when {
        isLoadingForum -> "取得中"
        liveForum != null -> "${discussions.size} 件"
        forumIDText.isBlank() -> "未指定"
        else -> "未取得"
    }
    val statusLabel = when {
        isLoadingForum -> "LMS 同期中"
        liveForum != null -> "投稿 $postCount 件"
        liveForumResult is LiveForumResult.InvalidForumID -> "入力エラー"
        liveForumResult is LiveForumResult.MissingSession -> "未接続"
        liveForumResult is LiveForumResult.Failed -> "取得失敗"
        else -> "未読み込み"
    }

    return ForumPresentationResult(
        discussions = discussions,
        selectedDiscussion = liveForum?.selectedDiscussion?.presentation,
        postThreads = postThreads,
        partialErrors = liveForum?.partialErrors.orEmpty(),
        error = error,
        primaryLabel = primaryLabel,
        statusLabel = statusLabel,
    )
}
