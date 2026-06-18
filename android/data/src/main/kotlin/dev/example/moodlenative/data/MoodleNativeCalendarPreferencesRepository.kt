package dev.example.moodlenative.data

import dev.example.moodlenative.core.LmsAuthenticationSession
import dev.example.moodlenative.storage.AppSessionSnapshot
import dev.example.moodlenative.storage.AppSessionStore
import java.time.Instant

class MoodleNativeCalendarPreferencesRepository internal constructor(
    private val sessionStore: AppSessionStore,
    private val gatewayFactory: (LmsAuthenticationSession) -> CalendarPreferencesGateway = { session ->
        LmsCalendarPreferencesWebServiceGateway(session)
    },
    private val now: () -> Instant = { Instant.now() },
) {
    constructor(sessionStore: AppSessionStore) : this(
        sessionStore = sessionStore,
        gatewayFactory = { session -> LmsCalendarPreferencesWebServiceGateway(session) },
        now = { Instant.now() },
    )

    suspend fun load(): LiveCalendarPreferencesResult {
        val snapshot = sessionStore.readSnapshot()
        val session = snapshot.lmsSession ?: return LiveCalendarPreferencesResult.MissingSession(snapshot)
        val gateway = gatewayFactory(session)

        return try {
            LiveCalendarPreferencesResult.Loaded(
                snapshot = sessionStore.readSnapshot(),
                form = CalendarPreferencesForm.from(gateway.fetchUserPreferences()),
                loadedAt = now(),
            )
        } catch (error: Exception) {
            failed(error)
        }
    }

    suspend fun setValue(
        key: String,
        value: String,
    ): LiveCalendarPreferencesResult {
        val snapshot = sessionStore.readSnapshot()
        val session = snapshot.lmsSession ?: return LiveCalendarPreferencesResult.MissingSession(snapshot)
        val gateway = gatewayFactory(session)

        return try {
            gateway.updateUserPreferences(
                listOf(
                    LmsUserPreferenceUpdate(
                        type = key,
                        value = value,
                    ),
                ),
            )
            LiveCalendarPreferencesResult.Updated(
                snapshot = sessionStore.readSnapshot(),
                key = key,
                value = value,
                updatedAt = now(),
            )
        } catch (error: Exception) {
            failed(error)
        }
    }

    private fun failed(error: Exception): LiveCalendarPreferencesResult.Failed =
        LiveCalendarPreferencesResult.Failed(
            snapshot = sessionStore.readSnapshot(),
            message = error.message ?: "カレンダー設定を更新できませんでした。",
        )
}

data class CalendarPreferencesForm(
    val timeFormat: String = "0",
    val startWeekday: String = "1",
    val maxEvents: String = "10",
    val lookAhead: String = "21",
    val persistFilters: Boolean = false,
) {
    fun applying(key: String, value: String): CalendarPreferencesForm =
        when (key) {
            "calendar_timeformat" -> copy(timeFormat = value)
            "calendar_startwday" -> copy(startWeekday = value)
            "calendar_maxevents" -> copy(maxEvents = value)
            "calendar_lookahead" -> copy(lookAhead = value)
            "calendar_persistflt" -> copy(persistFilters = value == "1")
            else -> this
        }

    companion object {
        internal fun from(preferences: List<LmsUserPreference>): CalendarPreferencesForm {
            val values = preferences.associate { it.name to it.value }
            return CalendarPreferencesForm(
                timeFormat = values.preferenceValue("calendar_timeformat", defaultValue = "0"),
                startWeekday = values.preferenceValue("calendar_startwday", defaultValue = "1"),
                maxEvents = values.preferenceValue("calendar_maxevents", defaultValue = "10"),
                lookAhead = values.preferenceValue("calendar_lookahead", defaultValue = "21"),
                persistFilters = values["calendar_persistflt"] == "1",
            )
        }

        private fun Map<String, String?>.preferenceValue(
            key: String,
            defaultValue: String,
        ): String =
            this[key] ?: defaultValue
    }
}

internal interface CalendarPreferencesGateway {
    suspend fun fetchUserPreferences(): List<LmsUserPreference>

    suspend fun updateUserPreferences(preferences: List<LmsUserPreferenceUpdate>)
}

sealed class LiveCalendarPreferencesResult {
    abstract val snapshot: AppSessionSnapshot

    data class MissingSession(
        override val snapshot: AppSessionSnapshot,
    ) : LiveCalendarPreferencesResult()

    data class Loaded(
        override val snapshot: AppSessionSnapshot,
        val form: CalendarPreferencesForm,
        val loadedAt: Instant,
    ) : LiveCalendarPreferencesResult()

    data class Updated(
        override val snapshot: AppSessionSnapshot,
        val key: String,
        val value: String,
        val updatedAt: Instant,
    ) : LiveCalendarPreferencesResult()

    data class Failed(
        override val snapshot: AppSessionSnapshot,
        val message: String,
    ) : LiveCalendarPreferencesResult()
}
