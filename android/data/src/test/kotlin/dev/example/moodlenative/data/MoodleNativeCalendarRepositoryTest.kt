package dev.example.moodlenative.data

import dev.example.moodlenative.core.LmsAuthenticationSession
import dev.example.moodlenative.features.LmsCalendarSubscription
import dev.example.moodlenative.storage.AppSessionSnapshot
import dev.example.moodlenative.storage.AppSessionStore
import java.net.URI
import java.time.Instant
import java.util.concurrent.CountDownLatch
import kotlin.coroutines.Continuation
import kotlin.coroutines.EmptyCoroutineContext
import kotlin.coroutines.startCoroutine
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class MoodleNativeCalendarRepositoryTest {
    @Test
    fun missingSessionDoesNotCreateGateway() {
        val repository = MoodleNativeCalendarRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot()),
            gatewayFactory = { error("Gateway should not be created without a session") },
        )

        val result = runSuspend { repository.makeCalendarSubscription() }

        assertTrue(result is LiveCalendarResult.MissingSession)
    }

    @Test
    fun makeCalendarSubscriptionUsesSessionUserID() {
        val gateway = FakeCalendarGateway(
            subscription = LmsCalendarSubscription(
                uri = URI("https://lms.example.test/calendar/export_execute.php?userid=99&authtoken=token"),
            ),
        )
        val repository = MoodleNativeCalendarRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot(lmsSession = session(userID = 99))),
            gatewayFactory = { gateway },
            now = { Instant.parse("2026-06-12T03:04:05Z") },
        )

        val result = runSuspend { repository.makeCalendarSubscription() } as LiveCalendarResult.Loaded

        assertEquals(listOf(99), gateway.userIDs)
        assertEquals("https", result.subscription.uri.scheme)
        assertEquals("webcal", result.subscription.webcalURI.scheme)
        assertEquals(Instant.parse("2026-06-12T03:04:05Z"), result.loadedAt)
    }

    @Test
    fun failureReturnsFailedResult() {
        val repository = MoodleNativeCalendarRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot(lmsSession = session())),
            gatewayFactory = {
                FakeCalendarGateway(error = IllegalStateException("calendar unavailable"))
            },
        )

        val result = runSuspend { repository.makeCalendarSubscription() } as LiveCalendarResult.Failed

        assertEquals("calendar unavailable", result.message)
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

    private class FakeCalendarGateway(
        private val subscription: LmsCalendarSubscription = LmsCalendarSubscription(
            uri = URI("https://lms.example.test/calendar/export_execute.php?userid=99"),
        ),
        private val error: Exception? = null,
    ) : CalendarGateway {
        val userIDs = mutableListOf<Int?>()

        override suspend fun makeCalendarSubscription(userID: Int?): LmsCalendarSubscription {
            userIDs += userID
            error?.let { throw it }
            return subscription
        }
    }

    private companion object {
        fun session(userID: Int? = 99): LmsAuthenticationSession =
            LmsAuthenticationSession(
                siteURL = "https://lms.example.test",
                token = "ws-token-123",
                privateToken = null,
                rawCallbackURL = "moodlemobile://example?token=ws-token-123",
                authenticatedAt = Instant.parse("2026-06-11T10:15:30Z"),
                userID = userID,
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
