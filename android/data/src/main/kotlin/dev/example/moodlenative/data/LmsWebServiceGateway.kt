package dev.example.moodlenative.data

import dev.example.moodlenative.core.LmsAssignmentItem
import dev.example.moodlenative.core.LmsAuthenticationSession
import dev.example.moodlenative.features.LmsDashboardSnapshot
import dev.example.moodlenative.networking.LmsWebServiceClient

internal class LmsWebServiceGateway(
    session: LmsAuthenticationSession,
) : LmsGateway {
    private val client = LmsWebServiceClient(session.toLmsWebServiceSession())

    override suspend fun fetchTimetableSnapshot(): LmsDashboardSnapshot =
        client.fetchTimetableSnapshot().toLmsDashboardSnapshot()

    override suspend fun fetchAssignments(): List<LmsAssignmentItem> =
        client.fetchAssignments().toLmsAssignmentItems()

    override suspend fun fetchPopupNotifications(): LmsNotificationSnapshot =
        client.fetchPopupNotifications().toLmsNotificationSnapshot()

    override suspend fun fetchUnreadNotificationCount(): Int =
        client.fetchUnreadNotificationCount()
}
