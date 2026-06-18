package dev.example.moodlenative.data

import dev.example.moodlenative.core.LmsAuthenticationSession
import dev.example.moodlenative.networking.LmsWebServiceClient

internal class LmsNotificationActionWebServiceGateway(
    session: LmsAuthenticationSession,
) : NotificationActionGateway {
    private val client = LmsWebServiceClient(session.toLmsWebServiceSession())

    override suspend fun markNotificationRead(notificationID: Int, timeRead: Int) {
        client.markNotificationRead(
            notificationID = notificationID,
            timeRead = timeRead,
        )
    }

    override suspend fun markAllNotificationsRead(userIDTo: Int?) {
        client.markAllNotificationsRead(userIDTo = userIDTo)
    }
}
