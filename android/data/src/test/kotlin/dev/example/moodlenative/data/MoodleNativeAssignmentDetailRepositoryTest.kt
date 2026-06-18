package dev.example.moodlenative.data

import dev.example.moodlenative.core.LmsAssignmentItem
import dev.example.moodlenative.core.LmsAuthenticationSession
import dev.example.moodlenative.features.LmsAssignmentLastAttempt
import dev.example.moodlenative.features.LmsAssignmentSubmission
import dev.example.moodlenative.features.LmsAssignmentSubmissionStatus
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

class MoodleNativeAssignmentDetailRepositoryTest {
    @Test
    fun missingSessionDoesNotCreateGateway() {
        val repository = MoodleNativeAssignmentDetailRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot()),
            gatewayFactory = { error("Gateway should not be created without a session") },
        )

        val result = runSuspend { repository.loadDetail(assignment()) }

        assertTrue(result is LiveAssignmentDetailResult.MissingSession)
        assertEquals(501, result.assignment.id)
    }

    @Test
    fun loadDetailUsesAssignmentIDAndReturnsStatus() {
        val gateway = FakeAssignmentDetailGateway(
            status = LmsAssignmentSubmissionStatus(
                lastAttempt = LmsAssignmentLastAttempt(
                    submission = LmsAssignmentSubmission(
                        id = 9001,
                        status = "submitted",
                    ),
                    gradingStatus = "graded",
                ),
            ),
        )
        val repository = MoodleNativeAssignmentDetailRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot(lmsSession = session())),
            gatewayFactory = { gateway },
            now = { Instant.parse("2026-06-11T12:00:00Z") },
        )

        val result = runSuspend { repository.loadDetail(assignment()) } as LiveAssignmentDetailResult.Loaded

        assertEquals(listOf(501), gateway.assignmentIDs)
        assertEquals("submitted", result.status.lastAttempt?.submission?.status)
        assertEquals("graded", result.status.lastAttempt?.gradingStatus)
        assertEquals(Instant.parse("2026-06-11T12:00:00Z"), result.loadedAt)
    }

    @Test
    fun failureReturnsFailedResult() {
        val repository = MoodleNativeAssignmentDetailRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot(lmsSession = session())),
            gatewayFactory = {
                FakeAssignmentDetailGateway(error = IllegalStateException("assignment unavailable"))
            },
        )

        val result = runSuspend { repository.loadDetail(assignment()) } as LiveAssignmentDetailResult.Failed

        assertEquals(501, result.assignment.id)
        assertEquals("assignment unavailable", result.message)
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

    private class FakeAssignmentDetailGateway(
        private val status: LmsAssignmentSubmissionStatus = LmsAssignmentSubmissionStatus(),
        private val error: Exception? = null,
    ) : AssignmentDetailGateway {
        val assignmentIDs = mutableListOf<Int>()

        override suspend fun fetchSubmissionStatus(assignmentID: Int): LmsAssignmentSubmissionStatus {
            assignmentIDs += assignmentID
            error?.let { throw it }
            return status
        }
    }

    private companion object {
        fun assignment(): LmsAssignmentItem =
            LmsAssignmentItem(
                id = 501,
                courseID = 42,
                courseModuleID = 9001,
                courseTitle = "ソフトウェア工学",
                courseCode = "IS-301",
                courseShortName = "2026-IS-301",
                title = "設計レビュー課題",
                introPreview = "<p>提出前にレビュー観点を整理する。</p>",
                dueDate = Instant.parse("2026-06-10T14:59:00Z"),
                allowsSubmissionsFromDate = null,
                cutoffDate = null,
                updatedAt = Instant.parse("2026-06-08T00:30:00Z"),
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
