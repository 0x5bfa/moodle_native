package dev.example.moodlenative.data

import dev.example.moodlenative.core.LmsAuthenticationSession
import dev.example.moodlenative.core.LmsNotificationItem
import dev.example.moodlenative.storage.AppSessionSnapshot
import dev.example.moodlenative.storage.AppSessionStore
import java.time.Instant

class MoodleNativeNotificationRepository internal constructor(
    private val sessionStore: AppSessionStore,
    private val gatewayFactory: (LmsAuthenticationSession) -> NotificationActionGateway = { session ->
        LmsNotificationActionWebServiceGateway(session)
    },
    private val now: () -> Instant = { Instant.now() },
) {
    constructor(sessionStore: AppSessionStore) : this(
        sessionStore = sessionStore,
        gatewayFactory = { session -> LmsNotificationActionWebServiceGateway(session) },
        now = { Instant.now() },
    )

    suspend fun markNotificationRead(notification: LmsNotificationItem): LiveNotificationActionResult {
        val action = NotificationAction.MarkSingle(notification)
        val snapshot = sessionStore.readSnapshot()
        val session = snapshot.lmsSession ?: return LiveNotificationActionResult.MissingSession(snapshot, action)
        val notificationID = notification.lmsNotificationID
            ?: return LiveNotificationActionResult.MissingNotificationID(snapshot, notification)
        val completedAt = now()
        val gateway = gatewayFactory(session)

        return try {
            gateway.markNotificationRead(
                notificationID = notificationID,
                timeRead = completedAt.epochSecond.toInt(),
            )
            LiveNotificationActionResult.Completed(
                snapshot = sessionStore.readSnapshot(),
                action = action,
                completedAt = completedAt,
            )
        } catch (error: Exception) {
            LiveNotificationActionResult.Failed(
                snapshot = sessionStore.readSnapshot(),
                action = action,
                message = error.message ?: "通知を既読にできませんでした。",
            )
        }
    }

    suspend fun markAllNotificationsRead(): LiveNotificationActionResult {
        val action = NotificationAction.MarkAll
        val snapshot = sessionStore.readSnapshot()
        val session = snapshot.lmsSession ?: return LiveNotificationActionResult.MissingSession(snapshot, action)
        val completedAt = now()
        val gateway = gatewayFactory(session)

        return try {
            gateway.markAllNotificationsRead(userIDTo = session.userID)
            LiveNotificationActionResult.Completed(
                snapshot = sessionStore.readSnapshot(),
                action = action,
                completedAt = completedAt,
            )
        } catch (error: Exception) {
            LiveNotificationActionResult.Failed(
                snapshot = sessionStore.readSnapshot(),
                action = action,
                message = error.message ?: "すべての通知を既読にできませんでした。",
            )
        }
    }
}

internal interface NotificationActionGateway {
    suspend fun markNotificationRead(notificationID: Int, timeRead: Int)
    suspend fun markAllNotificationsRead(userIDTo: Int?)
}

sealed class NotificationAction {
    data class MarkSingle(
        val notification: LmsNotificationItem,
    ) : NotificationAction()

    data object MarkAll : NotificationAction()
}

sealed class LiveNotificationActionResult {
    abstract val snapshot: AppSessionSnapshot
    abstract val action: NotificationAction

    data class MissingSession(
        override val snapshot: AppSessionSnapshot,
        override val action: NotificationAction,
    ) : LiveNotificationActionResult()

    data class MissingNotificationID(
        override val snapshot: AppSessionSnapshot,
        val notification: LmsNotificationItem,
    ) : LiveNotificationActionResult() {
        override val action: NotificationAction = NotificationAction.MarkSingle(notification)
    }

    data class Completed(
        override val snapshot: AppSessionSnapshot,
        override val action: NotificationAction,
        val completedAt: Instant,
    ) : LiveNotificationActionResult()

    data class Failed(
        override val snapshot: AppSessionSnapshot,
        override val action: NotificationAction,
        val message: String,
    ) : LiveNotificationActionResult()
}
