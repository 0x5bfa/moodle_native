package dev.example.moodlenative.data

import dev.example.moodlenative.core.LmsAuthenticationSession
import dev.example.moodlenative.core.LmsAssignmentItem
import dev.example.moodlenative.core.LmsNotificationItem
import dev.example.moodlenative.features.LmsDashboardCourse
import dev.example.moodlenative.features.LmsDashboardSnapshot
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

class MoodleNativeLiveRepositoryTest {
    @Test
    fun missingSessionDoesNotCreateGateway() {
        val store = FakeSessionStore(AppSessionSnapshot())
        val repository = MoodleNativeLiveRepository(
            sessionStore = store,
            lmsGatewayFactory = { error("Gateway should not be created without a session") },
        )

        val result = runSuspend { repository.loadDashboard() }

        assertTrue(result is LiveDashboardResult.MissingSession)
    }

    @Test
    fun loadDashboardMapsLiveDataAndPersistsResolvedUserID() {
        val session = session(userID = null)
        val store = FakeSessionStore(AppSessionSnapshot(lmsSession = session))
        val gateway = FakeLmsGateway(
            dashboardSnapshot = LmsDashboardSnapshot(
                siteURL = "https://lms.example.test",
                userID = 99,
                courses = listOf(
                    LmsDashboardCourse(
                        id = 42,
                        fullName = "ソフトウェア工学",
                        shortName = "2026-IS-301",
                        isFavorite = true,
                    ),
                    LmsDashboardCourse(
                        id = 43,
                        fullName = "情報倫理",
                        shortName = "2026-IS-204",
                    ),
                ),
                dashboardBlocks = emptyList(),
            ),
            assignments = listOf(
                LmsAssignmentItem(
                    id = 501,
                    courseID = 42,
                    courseModuleID = 9001,
                    courseTitle = "ソフトウェア工学",
                    courseCode = null,
                    courseShortName = "2026-IS-301",
                    title = "設計レビュー課題",
                    introPreview = null,
                    dueDate = Instant.ofEpochSecond(1_780_000_000),
                    allowsSubmissionsFromDate = null,
                    cutoffDate = null,
                    updatedAt = null,
                ),
            ),
            notificationSnapshot = LmsNotificationSnapshot(
                notifications = listOf(
                    notification(
                        id = 10,
                        title = "通知",
                        receivedAt = Instant.ofEpochSecond(1_780_000_100),
                        isUnread = true,
                    ),
                ),
                unreadCount = 5,
            ),
            unreadNotificationCount = 7,
        )
        val repository = MoodleNativeLiveRepository(
            sessionStore = store,
            lmsGatewayFactory = { gateway },
            now = { Instant.parse("2026-06-11T12:00:00Z") },
        )

        val result = runSuspend { repository.loadDashboard() } as LiveDashboardResult.Loaded
        val dashboard = result.dashboard

        assertEquals(99, store.snapshot.lmsSession?.userID)
        assertEquals(2, dashboard.courses.size)
        assertEquals("ソフトウェア工学", dashboard.courses[0].title)
        assertEquals(1, dashboard.courses.first { it.id == 42 }.assignmentCount)
        assertEquals(0, dashboard.courses.first { it.id == 43 }.assignmentCount)
        assertEquals("設計レビュー課題", dashboard.assignments.single().title)
        assertEquals(1, dashboard.notifications.size)
        assertEquals(7, dashboard.unreadNotificationCount)
        assertTrue(dashboard.partialErrors.isEmpty())
        assertEquals(Instant.parse("2026-06-11T12:00:00Z"), dashboard.loadedAt)
    }

    @Test
    fun assignmentAndNotificationFailuresKeepTimetableData() {
        val store = FakeSessionStore(AppSessionSnapshot(lmsSession = session(userID = 99)))
        val gateway = FakeLmsGateway(
            dashboardSnapshot = LmsDashboardSnapshot(
                siteURL = "https://lms.example.test",
                userID = 99,
                courses = listOf(
                    LmsDashboardCourse(id = 42, fullName = "Software Engineering", shortName = "2026-IS-301"),
                ),
                dashboardBlocks = emptyList(),
            ),
            assignmentError = IllegalStateException("assignments unavailable"),
            notificationError = IllegalStateException("notifications unavailable"),
            unreadError = IllegalStateException("unread unavailable"),
        )
        val repository = MoodleNativeLiveRepository(
            sessionStore = store,
            lmsGatewayFactory = { gateway },
        )

        val result = runSuspend { repository.loadDashboard() } as LiveDashboardResult.Loaded

        assertEquals(1, result.dashboard.courses.size)
        assertTrue(result.dashboard.assignments.isEmpty())
        assertTrue(result.dashboard.notifications.isEmpty())
        assertEquals(0, result.dashboard.unreadNotificationCount)
        assertEquals(
            listOf("assignments unavailable", "notifications unavailable", "unread unavailable"),
            result.dashboard.partialErrors,
        )
    }

    @Test
    fun timetableFailureReturnsFailedResult() {
        val store = FakeSessionStore(AppSessionSnapshot(lmsSession = session(userID = 99)))
        val gateway = FakeLmsGateway(
            dashboardError = IllegalStateException("dashboard unavailable"),
        )
        val repository = MoodleNativeLiveRepository(
            sessionStore = store,
            lmsGatewayFactory = { gateway },
        )

        val result = runSuspend { repository.loadDashboard() }

        assertEquals("dashboard unavailable", (result as LiveDashboardResult.Failed).message)
    }

    private class FakeSessionStore(
        var snapshot: AppSessionSnapshot,
    ) : AppSessionStore {
        override fun readSnapshot(): AppSessionSnapshot = snapshot

        override fun writeSnapshot(snapshot: AppSessionSnapshot) {
            this.snapshot = snapshot
        }

        override fun clear() {
            snapshot = AppSessionSnapshot()
        }
    }

    private class FakeLmsGateway(
        private val dashboardSnapshot: LmsDashboardSnapshot? = null,
        private val assignments: List<LmsAssignmentItem> = emptyList(),
        private val notificationSnapshot: LmsNotificationSnapshot = LmsNotificationSnapshot(),
        private val unreadNotificationCount: Int = 0,
        private val dashboardError: Exception? = null,
        private val assignmentError: Exception? = null,
        private val notificationError: Exception? = null,
        private val unreadError: Exception? = null,
    ) : LmsGateway {
        override suspend fun fetchTimetableSnapshot(): LmsDashboardSnapshot {
            dashboardError?.let { throw it }
            return requireNotNull(dashboardSnapshot)
        }

        override suspend fun fetchAssignments(): List<LmsAssignmentItem> {
            assignmentError?.let { throw it }
            return assignments
        }

        override suspend fun fetchPopupNotifications(): LmsNotificationSnapshot {
            notificationError?.let { throw it }
            return notificationSnapshot
        }

        override suspend fun fetchUnreadNotificationCount(): Int {
            unreadError?.let { throw it }
            return unreadNotificationCount
        }
    }

    private fun session(userID: Int?): LmsAuthenticationSession =
        LmsAuthenticationSession(
            siteURL = "https://lms.example.test",
            token = "ws-token-123",
            privateToken = null,
            rawCallbackURL = "moodlemobile://example?token=ws-token-123",
            authenticatedAt = Instant.parse("2026-06-11T10:15:30Z"),
            userID = userID,
        )

    private fun notification(
        id: Int,
        title: String,
        receivedAt: Instant,
        isUnread: Boolean,
    ): LmsNotificationItem =
        LmsNotificationItem(
            id = "lms-$id",
            lmsNotificationID = id,
            source = "Moodle",
            title = title,
            preview = title,
            plainBody = title,
            fullMessage = title,
            htmlBody = null,
            receivedAt = receivedAt,
            isUnread = isUnread,
            isImportant = false,
            externalURL = null,
            component = null,
            eventType = null,
            contextName = null,
        )

    private fun <T> runSuspend(block: suspend () -> T): T {
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
