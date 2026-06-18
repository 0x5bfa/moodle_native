package dev.example.moodlenative.data

import dev.example.moodlenative.core.LmsAuthenticationSession
import dev.example.moodlenative.features.LmsCalendarSubscription
import dev.example.moodlenative.storage.AppSessionSnapshot
import dev.example.moodlenative.storage.AppSessionStore
import java.time.Instant

class MoodleNativeCalendarRepository internal constructor(
    private val sessionStore: AppSessionStore,
    private val gatewayFactory: (LmsAuthenticationSession) -> CalendarGateway = { session ->
        LmsCalendarWebServiceGateway(session)
    },
    private val now: () -> Instant = { Instant.now() },
) {
    constructor(sessionStore: AppSessionStore) : this(
        sessionStore = sessionStore,
        gatewayFactory = { session -> LmsCalendarWebServiceGateway(session) },
        now = { Instant.now() },
    )

    suspend fun makeCalendarSubscription(): LiveCalendarResult {
        val snapshot = sessionStore.readSnapshot()
        val session = snapshot.lmsSession ?: return LiveCalendarResult.MissingSession(snapshot)
        val gateway = gatewayFactory(session)

        return try {
            LiveCalendarResult.Loaded(
                snapshot = sessionStore.readSnapshot(),
                subscription = gateway.makeCalendarSubscription(userID = session.userID),
                loadedAt = now(),
            )
        } catch (error: Exception) {
            LiveCalendarResult.Failed(
                snapshot = sessionStore.readSnapshot(),
                message = error.message ?: "カレンダー URL を生成できませんでした。",
            )
        }
    }
}

internal interface CalendarGateway {
    suspend fun makeCalendarSubscription(userID: Int?): LmsCalendarSubscription
}

sealed class LiveCalendarResult {
    abstract val snapshot: AppSessionSnapshot

    data class MissingSession(
        override val snapshot: AppSessionSnapshot,
    ) : LiveCalendarResult()

    data class Loaded(
        override val snapshot: AppSessionSnapshot,
        val subscription: LmsCalendarSubscription,
        val loadedAt: Instant,
    ) : LiveCalendarResult()

    data class Failed(
        override val snapshot: AppSessionSnapshot,
        val message: String,
    ) : LiveCalendarResult()
}
