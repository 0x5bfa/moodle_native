package dev.example.moodlenative.data

import dev.example.moodlenative.core.LmsAuthenticationSession
import dev.example.moodlenative.storage.AppSessionSnapshot
import dev.example.moodlenative.storage.AppSessionStore
import java.time.Instant

class MoodleNativeForumActionRepository internal constructor(
    private val sessionStore: AppSessionStore,
    private val gatewayFactory: (LmsAuthenticationSession) -> ForumActionGateway = { session ->
        LmsForumActionWebServiceGateway(session)
    },
    private val now: () -> Instant = { Instant.now() },
) {
    constructor(sessionStore: AppSessionStore) : this(
        sessionStore = sessionStore,
        gatewayFactory = { session -> LmsForumActionWebServiceGateway(session) },
        now = { Instant.now() },
    )

    suspend fun markDiscussionViewed(discussionID: Int): LiveForumActionResult {
        val action = ForumAction.MarkDiscussionViewed(discussionID)
        val snapshot = sessionStore.readSnapshot()
        val session = snapshot.lmsSession ?: return LiveForumActionResult.MissingSession(snapshot, action)
        val gateway = gatewayFactory(session)
        val completedAt = now()

        return try {
            gateway.markForumDiscussionViewed(discussionID = discussionID)
            LiveForumActionResult.Completed(
                snapshot = sessionStore.readSnapshot(),
                action = action,
                completedAt = completedAt,
            )
        } catch (error: Exception) {
            LiveForumActionResult.Failed(
                snapshot = sessionStore.readSnapshot(),
                action = action,
                message = error.message ?: "フォーラムを閲覧済みにできませんでした。",
            )
        }
    }
}

internal interface ForumActionGateway {
    suspend fun markForumDiscussionViewed(discussionID: Int)
}

sealed class ForumAction {
    data class MarkDiscussionViewed(
        val discussionID: Int,
    ) : ForumAction()
}

sealed class LiveForumActionResult {
    abstract val snapshot: AppSessionSnapshot
    abstract val action: ForumAction

    data class MissingSession(
        override val snapshot: AppSessionSnapshot,
        override val action: ForumAction,
    ) : LiveForumActionResult()

    data class Completed(
        override val snapshot: AppSessionSnapshot,
        override val action: ForumAction,
        val completedAt: Instant,
    ) : LiveForumActionResult()

    data class Failed(
        override val snapshot: AppSessionSnapshot,
        override val action: ForumAction,
        val message: String,
    ) : LiveForumActionResult()
}
