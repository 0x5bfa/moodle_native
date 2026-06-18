package dev.example.moodlenative.data

import dev.example.moodlenative.core.LmsAuthenticationSession
import dev.example.moodlenative.features.LmsForumDiscussion
import dev.example.moodlenative.features.LmsForumPost
import dev.example.moodlenative.storage.AppSessionSnapshot
import dev.example.moodlenative.storage.AppSessionStore
import java.time.Instant

class MoodleNativeForumRepository internal constructor(
    private val sessionStore: AppSessionStore,
    private val gatewayFactory: (LmsAuthenticationSession) -> ForumGateway = { session ->
        LmsForumWebServiceGateway(session)
    },
    private val now: () -> Instant = { Instant.now() },
) {
    constructor(sessionStore: AppSessionStore) : this(
        sessionStore = sessionStore,
        gatewayFactory = { session -> LmsForumWebServiceGateway(session) },
        now = { Instant.now() },
    )

    suspend fun loadForum(
        forumIDText: String,
        selectedDiscussionID: Int? = null,
    ): LiveForumResult {
        val snapshot = sessionStore.readSnapshot()
        val forumID = forumIDText.trim().toIntOrNull()
            ?: return LiveForumResult.InvalidForumID(snapshot = snapshot, forumIDText = forumIDText.trim())
        val session = snapshot.lmsSession ?: return LiveForumResult.MissingSession(snapshot = snapshot, forumID = forumID)
        val gateway = gatewayFactory(session)

        val discussions = try {
            gateway.fetchForumDiscussions(forumID = forumID)
        } catch (error: Exception) {
            return LiveForumResult.Failed(
                snapshot = sessionStore.readSnapshot(),
                forumID = forumID,
                message = error.message ?: "フォーラム一覧を取得できませんでした。",
            )
        }
        val selectedDiscussion = selectedDiscussionID
            ?.let { id -> discussions.firstOrNull { it.discussionID == id } }
            ?: discussions.firstOrNull()
        val postsResult = selectedDiscussion?.let { discussion ->
            runCatching { gateway.fetchDiscussionPosts(discussionID = discussion.discussionID) }
        }

        return LiveForumResult.Loaded(
            snapshot = sessionStore.readSnapshot(),
            forumID = forumID,
            discussions = discussions,
            selectedDiscussion = selectedDiscussion,
            posts = postsResult?.getOrNull().orEmpty(),
            partialErrors = listOfNotNull(
                postsResult?.exceptionOrNull()?.let { error ->
                    error.message ?: "フォーラム投稿を取得できませんでした。"
                },
            ),
            loadedAt = now(),
        )
    }
}

internal interface ForumGateway {
    suspend fun fetchForumDiscussions(forumID: Int): List<LmsForumDiscussion>
    suspend fun fetchDiscussionPosts(discussionID: Int): List<LmsForumPost>
}

sealed class LiveForumResult {
    data class InvalidForumID(
        val snapshot: AppSessionSnapshot,
        val forumIDText: String,
    ) : LiveForumResult()

    data class MissingSession(
        val snapshot: AppSessionSnapshot,
        val forumID: Int,
    ) : LiveForumResult()

    data class Loaded(
        val snapshot: AppSessionSnapshot,
        val forumID: Int,
        val discussions: List<LmsForumDiscussion>,
        val selectedDiscussion: LmsForumDiscussion?,
        val posts: List<LmsForumPost>,
        val partialErrors: List<String>,
        val loadedAt: Instant,
    ) : LiveForumResult()

    data class Failed(
        val snapshot: AppSessionSnapshot,
        val forumID: Int,
        val message: String,
    ) : LiveForumResult()
}
