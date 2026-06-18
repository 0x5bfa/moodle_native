package dev.example.moodlenative.data

import dev.example.moodlenative.core.LmsAuthenticationSession
import dev.example.moodlenative.storage.AppSessionSnapshot
import dev.example.moodlenative.storage.AppSessionStore
import java.time.Instant
import java.util.concurrent.CountDownLatch
import kotlin.coroutines.Continuation
import kotlin.coroutines.EmptyCoroutineContext
import kotlin.coroutines.startCoroutine
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class MoodleNativeForumActionRepositoryTest {
    @Test
    fun missingSessionDoesNotCreateGateway() {
        val repository = MoodleNativeForumActionRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot()),
            gatewayFactory = { error("Gateway should not be created without a session") },
        )

        val result = runSuspend { repository.markDiscussionViewed(discussionID = 101) }

        assertTrue(result is LiveForumActionResult.MissingSession)
        assertEquals(101, (result.action as ForumAction.MarkDiscussionViewed).discussionID)
    }

    @Test
    fun markDiscussionViewedUsesDiscussionID() {
        val gateway = FakeForumActionGateway()
        val repository = MoodleNativeForumActionRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot(lmsSession = session())),
            gatewayFactory = { gateway },
            now = { Instant.parse("2026-06-12T03:04:05Z") },
        )

        val result = runSuspend { repository.markDiscussionViewed(discussionID = 202) }
            as LiveForumActionResult.Completed

        assertEquals(listOf(202), gateway.discussionIDs)
        assertEquals(Instant.parse("2026-06-12T03:04:05Z"), result.completedAt)
    }

    @Test
    fun failureReturnsFailedResult() {
        val repository = MoodleNativeForumActionRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot(lmsSession = session())),
            gatewayFactory = {
                FakeForumActionGateway(error = IllegalStateException("view unavailable"))
            },
        )

        val result = runSuspend { repository.markDiscussionViewed(discussionID = 101) }
            as LiveForumActionResult.Failed

        assertEquals("view unavailable", result.message)
        assertEquals(101, (result.action as ForumAction.MarkDiscussionViewed).discussionID)
    }

    private class FakeSessionStore(
        private var snapshot: AppSessionSnapshot,
    ) : AppSessionStore {
        override fun readSnapshot(): AppSessionSnapshot = snapshot

        override fun writeSnapshot(snapshot: AppSessionSnapshot) {
            this.snapshot = snapshot
        }

        override fun clear() {
            snapshot = AppSessionSnapshot()
        }
    }

    private class FakeForumActionGateway(
        private val error: Exception? = null,
    ) : ForumActionGateway {
        val discussionIDs = mutableListOf<Int>()

        override suspend fun markForumDiscussionViewed(discussionID: Int) {
            error?.let { throw it }
            discussionIDs += discussionID
        }
    }

    private companion object {
        fun session(): LmsAuthenticationSession =
            LmsAuthenticationSession(
                siteURL = "https://lms.example.test",
                token = "ws-token-123",
                privateToken = null,
                rawCallbackURL = "moodlemobile://example?token=ws-token-123",
                authenticatedAt = Instant.parse("2026-06-11T10:15:30Z"),
                userID = 99,
            )

        fun <T> runSuspend(block: suspend () -> T): T {
            val latch = CountDownLatch(1)
            var value: T? = null
            var failure: Throwable? = null

            block.startCoroutine(
                object : Continuation<T> {
                    override val context = EmptyCoroutineContext

                    override fun resumeWith(result: Result<T>) {
                        result.fold(
                            onSuccess = { value = it },
                            onFailure = { failure = it },
                        )
                        latch.countDown()
                    }
                },
            )

            latch.await()
            failure?.let { throw it }
            @Suppress("UNCHECKED_CAST")
            return value as T
        }
    }
}
