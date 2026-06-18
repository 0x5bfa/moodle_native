package dev.example.moodlenative.runtime

import dev.example.moodlenative.core.LmsAssignmentItem
import dev.example.moodlenative.core.LmsNotificationItem
import dev.example.moodlenative.data.LiveDashboardResult
import dev.example.moodlenative.features.LmsCourseSummary
import dev.example.moodlenative.presentation.AppDemoData
import java.time.Instant
import java.time.ZoneId

internal data class DashboardPresentationResult(
    val now: Instant,
    val zoneId: ZoneId,
    val courses: List<LmsCourseSummary>,
    val assignments: List<LmsAssignmentItem>,
    val notifications: List<LmsNotificationItem>,
    val unreadNotificationCount: Int,
    val loadedAt: Instant?,
    val error: String?,
    val partialErrors: List<String>,
)

internal fun resolveDashboardPresentation(
    liveDashboardResult: LiveDashboardResult?,
): DashboardPresentationResult {
    val liveDashboard = (liveDashboardResult as? LiveDashboardResult.Loaded)?.dashboard
    val notifications = liveDashboard?.notifications ?: AppDemoData.notifications
    val unreadNotificationCount = liveDashboard?.unreadNotificationCount
        ?: notifications.count { it.isUnread }

    return DashboardPresentationResult(
        now = liveDashboard?.loadedAt ?: AppDemoData.now,
        zoneId = AppDemoData.zoneId,
        courses = liveDashboard?.courses ?: AppDemoData.courses,
        assignments = liveDashboard?.assignments ?: AppDemoData.assignments,
        notifications = notifications,
        unreadNotificationCount = unreadNotificationCount,
        loadedAt = liveDashboard?.loadedAt,
        error = (liveDashboardResult as? LiveDashboardResult.Failed)?.message,
        partialErrors = liveDashboard?.partialErrors.orEmpty(),
    )
}
