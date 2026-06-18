package dev.example.moodlenative.data

import dev.example.moodlenative.core.LmsAuthenticationSession
import dev.example.moodlenative.features.LmsForumDiscussion
import dev.example.moodlenative.features.LmsForumPost
import dev.example.moodlenative.features.LmsForumPostAuthor
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

class MoodleNativeForumRepositoryTest {
    @Test
    fun invalidForumIDDoesNotCreateGateway() {
        val repository = MoodleNativeForumRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot()),
            gatewayFactory = { error("Gateway should not be created for invalid forum ID") },
        )

        val result = runSuspend { repository.loadForum(forumIDText = "abc") }

        assertTrue(result is LiveForumResult.InvalidForumID)
    }

    @Test
    fun missingSessionDoesNotCreateGateway() {
        val repository = MoodleNativeForumRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot()),
            gatewayFactory = { error("Gateway should not be created without a session") },
        )

        val result = runSuspend { repository.loadForum(forumIDText = "42") }

        assertTrue(result is LiveForumResult.MissingSession)
        assertEquals(42, (result as LiveForumResult.MissingSession).forumID)
    }

    @Test
    fun loadForumFetchesDiscussionsAndFirstDiscussionPosts() {
        val gateway = FakeForumGateway(
            discussions = listOf(
                discussion(discussionID = 101, subject = "最初の議論"),
                discussion(discussionID = 102, subject = "次の議論"),
            ),
            posts = listOf(post(id = 1001, discussionID = 101)),
        )
        val repository = MoodleNativeForumRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot(lmsSession = session())),
            gatewayFactory = { gateway },
            now = { Instant.parse("2026-06-11T12:00:00Z") },
        )

        val result = runSuspend { repository.loadForum(forumIDText = " 42 ") } as LiveForumResult.Loaded

        assertEquals(listOf(42), gateway.forumIDs)
        assertEquals(listOf(101), gateway.discussionIDs)
        assertEquals("最初の議論", result.selectedDiscussion?.subject)
        assertEquals(listOf(1001), result.posts.map { it.id })
        assertTrue(result.partialErrors.isEmpty())
        assertEquals(Instant.parse("2026-06-11T12:00:00Z"), result.loadedAt)
    }

    @Test
    fun explicitDiscussionIDSelectsMatchingDiscussion() {
        val gateway = FakeForumGateway(
            discussions = listOf(
                discussion(discussionID = 101, subject = "最初の議論"),
                discussion(discussionID = 102, subject = "選択した議論"),
            ),
            posts = listOf(post(id = 1002, discussionID = 102)),
        )
        val repository = MoodleNativeForumRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot(lmsSession = session())),
            gatewayFactory = { gateway },
        )

        val result = runSuspend {
            repository.loadForum(forumIDText = "42", selectedDiscussionID = 102)
        } as LiveForumResult.Loaded

        assertEquals(listOf(102), gateway.discussionIDs)
        assertEquals("選択した議論", result.selectedDiscussion?.subject)
        assertEquals(listOf(1002), result.posts.map { it.id })
    }

    @Test
    fun postFailureKeepsDiscussions() {
        val gateway = FakeForumGateway(
            discussions = listOf(discussion(discussionID = 101, subject = "議論")),
            postError = IllegalStateException("posts unavailable"),
        )
        val repository = MoodleNativeForumRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot(lmsSession = session())),
            gatewayFactory = { gateway },
        )

        val result = runSuspend { repository.loadForum(forumIDText = "42") } as LiveForumResult.Loaded

        assertEquals(1, result.discussions.size)
        assertTrue(result.posts.isEmpty())
        assertEquals(listOf("posts unavailable"), result.partialErrors)
    }

    @Test
    fun discussionFailureReturnsFailedResult() {
        val repository = MoodleNativeForumRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot(lmsSession = session())),
            gatewayFactory = {
                FakeForumGateway(discussionError = IllegalStateException("forum unavailable"))
            },
        )

        val result = runSuspend { repository.loadForum(forumIDText = "42") } as LiveForumResult.Failed

        assertEquals(42, result.forumID)
        assertEquals("forum unavailable", result.message)
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

    private class FakeForumGateway(
        private val discussions: List<LmsForumDiscussion> = emptyList(),
        private val posts: List<LmsForumPost> = emptyList(),
        private val discussionError: Exception? = null,
        private val postError: Exception? = null,
    ) : ForumGateway {
        val forumIDs = mutableListOf<Int>()
        val discussionIDs = mutableListOf<Int>()

        override suspend fun fetchForumDiscussions(forumID: Int): List<LmsForumDiscussion> {
            forumIDs += forumID
            discussionError?.let { throw it }
            return discussions
        }

        override suspend fun fetchDiscussionPosts(discussionID: Int): List<LmsForumPost> {
            discussionIDs += discussionID
            postError?.let { throw it }
            return posts.filter { it.discussionID == discussionID }
        }
    }

    private companion object {
        fun discussion(
            discussionID: Int,
            subject: String,
        ): LmsForumDiscussion =
            LmsForumDiscussion(
                rootPostID = discussionID + 1_000,
                discussionID = discussionID,
                subject = subject,
                userFullName = "山田 太郎",
                modifiedTimestamp = 1_775_200_576,
            )

        fun post(
            id: Int,
            discussionID: Int,
        ): LmsForumPost =
            LmsForumPost(
                id = id,
                discussionID = discussionID,
                subject = "返信",
                message = "<p>本文</p>",
                timeCreated = 1_775_200_600,
                author = LmsForumPostAuthor(fullName = "佐藤 花子"),
            )

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
