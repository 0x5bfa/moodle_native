package dev.example.moodlenative.data

import dev.example.moodlenative.core.LmsAuthenticationSession
import dev.example.moodlenative.core.LmsNotificationItem
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

class MoodleNativeNotificationRepositoryTest {
    @Test
    fun missingSessionDoesNotCreateGatewayForSingleNotification() {
        val repository = MoodleNativeNotificationRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot()),
            gatewayFactory = { error("Gateway should not be created without a session") },
        )

        val result = runSuspend { repository.markNotificationRead(notification()) }

        assertTrue(result is LiveNotificationActionResult.MissingSession)
        assertTrue(result.action is NotificationAction.MarkSingle)
    }

    @Test
    fun missingNotificationIDDoesNotCreateGateway() {
        val repository = MoodleNativeNotificationRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot(lmsSession = session())),
            gatewayFactory = { error("Gateway should not be created without a notification ID") },
        )

        val result = runSuspend {
            repository.markNotificationRead(notification(lmsNotificationID = null))
        }

        assertTrue(result is LiveNotificationActionResult.MissingNotificationID)
    }

    @Test
    fun markNotificationReadUsesNotificationIDAndTimeRead() {
        val gateway = FakeNotificationActionGateway()
        val repository = MoodleNativeNotificationRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot(lmsSession = session())),
            gatewayFactory = { gateway },
            now = { Instant.parse("2026-06-12T03:04:05Z") },
        )

        val result = runSuspend { repository.markNotificationRead(notification(lmsNotificationID = 991)) }
            as LiveNotificationActionResult.Completed

        assertEquals(listOf(991 to 1_781_233_445), gateway.readNotifications)
        assertTrue(result.action is NotificationAction.MarkSingle)
        assertEquals(Instant.parse("2026-06-12T03:04:05Z"), result.completedAt)
    }

    @Test
    fun markAllNotificationsReadUsesSessionUserID() {
        val gateway = FakeNotificationActionGateway()
        val repository = MoodleNativeNotificationRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot(lmsSession = session(userID = 99))),
            gatewayFactory = { gateway },
        )

        val result = runSuspend { repository.markAllNotificationsRead() }

        assertTrue(result is LiveNotificationActionResult.Completed)
        assertEquals(listOf(99), gateway.allReadUserIDs)
    }

    @Test
    fun missingSessionDoesNotCreateGatewayForAllNotifications() {
        val repository = MoodleNativeNotificationRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot()),
            gatewayFactory = { error("Gateway should not be created without a session") },
        )

        val result = runSuspend { repository.markAllNotificationsRead() }

        assertTrue(result is LiveNotificationActionResult.MissingSession)
        assertTrue(result.action is NotificationAction.MarkAll)
    }

    @Test
    fun failureReturnsFailedResult() {
        val repository = MoodleNativeNotificationRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot(lmsSession = session())),
            gatewayFactory = {
                FakeNotificationActionGateway(singleError = IllegalStateException("read unavailable"))
            },
        )

        val result = runSuspend { repository.markNotificationRead(notification()) }
            as LiveNotificationActionResult.Failed

        assertEquals("read unavailable", result.message)
        assertTrue(result.action is NotificationAction.MarkSingle)
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

    private class FakeNotificationActionGateway(
        private val singleError: Exception? = null,
        private val allError: Exception? = null,
    ) : NotificationActionGateway {
        val readNotifications = mutableListOf<Pair<Int, Int>>()
        val allReadUserIDs = mutableListOf<Int?>()

        override suspend fun markNotificationRead(notificationID: Int, timeRead: Int) {
            singleError?.let { throw it }
            readNotifications += notificationID to timeRead
        }

        override suspend fun markAllNotificationsRead(userIDTo: Int?) {
            allError?.let { throw it }
            allReadUserIDs += userIDTo
        }
    }

    private companion object {
        fun notification(lmsNotificationID: Int? = 991): LmsNotificationItem =
            LmsNotificationItem(
                id = "lms-${lmsNotificationID ?: "missing"}",
                lmsNotificationID = lmsNotificationID,
                source = "Moodle",
                title = "課題通知",
                preview = "提出期限が近づいています。",
                plainBody = "本文",
                fullMessage = "本文",
                htmlBody = null,
                receivedAt = Instant.parse("2026-06-11T10:15:30Z"),
                isUnread = true,
                isImportant = false,
                externalURL = URI("https://lms.example.test/mod/assign/view.php?id=1"),
                component = "mod_assign",
                eventType = "assign_notification",
                contextName = "課題",
            )

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
