package dev.example.moodlenative.data

import dev.example.moodlenative.core.LmsAssignmentItem
import dev.example.moodlenative.core.LmsAuthenticationSession
import dev.example.moodlenative.core.LmsNotificationItem
import dev.example.moodlenative.features.LmsCourseSummary
import dev.example.moodlenative.features.LmsCourseSummaryFactory
import dev.example.moodlenative.features.LmsDashboardSnapshot
import dev.example.moodlenative.storage.AppSessionSnapshot
import dev.example.moodlenative.storage.AppSessionStore
import java.time.Instant

class MoodleNativeLiveRepository internal constructor(
    private val sessionStore: AppSessionStore,
    private val lmsGatewayFactory: (LmsAuthenticationSession) -> LmsGateway = { session ->
        LmsWebServiceGateway(session)
    },
    private val now: () -> Instant = { Instant.now() },
) {
    constructor(sessionStore: AppSessionStore) : this(
        sessionStore = sessionStore,
        lmsGatewayFactory = { session -> LmsWebServiceGateway(session) },
        now = { Instant.now() },
    )

    suspend fun loadDashboard(): LiveDashboardResult {
        val storedSnapshot = sessionStore.readSnapshot()
        val session = storedSnapshot.lmsSession ?: return LiveDashboardResult.MissingSession(storedSnapshot)
        val gateway = lmsGatewayFactory(session)

        val timetableSnapshot = try {
            gateway.fetchTimetableSnapshot()
        } catch (error: Exception) {
            return LiveDashboardResult.Failed(
                snapshot = sessionStore.readSnapshot(),
                message = error.message ?: "Moodle の時間割を取得できませんでした。",
            )
        }

        persistResolvedUserID(session, timetableSnapshot)
        val refreshedSnapshot = sessionStore.readSnapshot()
        val assignmentResult = runCatching { gateway.fetchAssignments() }
        val notificationResult = runCatching { gateway.fetchPopupNotifications() }
        val unreadCountResult = runCatching { gateway.fetchUnreadNotificationCount() }

        val assignments = assignmentResult.getOrElse { emptyList() }
        val notifications = notificationResult.getOrNull()?.notifications.orEmpty()
        val unreadNotificationCount = unreadCountResult.getOrElse {
            notificationResult.getOrNull()?.unreadCount ?: notifications.count { it.isUnread }
        }
        val partialErrors = listOfNotNull(
            assignmentResult.exceptionOrNull()?.let { it.message ?: "課題を取得できませんでした。" },
            notificationResult.exceptionOrNull()?.let { it.message ?: "通知を取得できませんでした。" },
            unreadCountResult.exceptionOrNull()?.let { it.message ?: "未読通知数を取得できませんでした。" },
        )

        return LiveDashboardResult.Loaded(
            dashboard = LiveDashboard(
                snapshot = refreshedSnapshot,
                courses = LmsCourseSummaryFactory
                    .makeCourseSummaries(timetableSnapshot)
                    .withAssignmentCounts(assignments),
                assignments = assignments.sortedWith(compareBy<LmsAssignmentItem> { it.dueDate ?: Instant.MAX }.thenBy { it.title }),
                notifications = notifications.sortedByDescending { it.receivedAt },
                unreadNotificationCount = unreadNotificationCount,
                partialErrors = partialErrors,
                loadedAt = now(),
            ),
        )
    }

    private fun persistResolvedUserID(
        session: LmsAuthenticationSession,
        timetableSnapshot: LmsDashboardSnapshot,
    ) {
        val userID = timetableSnapshot.userID ?: return
        if (session.userID == userID) {
            return
        }

        sessionStore.updateLmsSession(session.withUserID(userID))
    }

    private fun List<LmsCourseSummary>.withAssignmentCounts(assignments: List<LmsAssignmentItem>): List<LmsCourseSummary> {
        val assignmentsByCourseID = assignments.groupingBy { it.courseID }.eachCount()
        return map { summary ->
            summary.copy(assignmentCount = assignmentsByCourseID[summary.id] ?: 0)
        }
    }
}

internal interface LmsGateway {
    suspend fun fetchTimetableSnapshot(): LmsDashboardSnapshot
    suspend fun fetchAssignments(): List<LmsAssignmentItem>
    suspend fun fetchPopupNotifications(): LmsNotificationSnapshot
    suspend fun fetchUnreadNotificationCount(): Int
}

sealed class LiveDashboardResult {
    data class MissingSession(
        val snapshot: AppSessionSnapshot,
    ) : LiveDashboardResult()

    data class Loaded(
        val dashboard: LiveDashboard,
    ) : LiveDashboardResult()

    data class Failed(
        val snapshot: AppSessionSnapshot,
        val message: String,
    ) : LiveDashboardResult()
}

data class LiveDashboard(
    val snapshot: AppSessionSnapshot,
    val courses: List<LmsCourseSummary>,
    val assignments: List<LmsAssignmentItem>,
    val notifications: List<LmsNotificationItem>,
    val unreadNotificationCount: Int,
    val partialErrors: List<String>,
    val loadedAt: Instant,
)
