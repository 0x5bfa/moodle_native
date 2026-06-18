package dev.example.moodlenative.data

import dev.example.moodlenative.core.LmsAuthenticationSession
import dev.example.moodlenative.storage.AppSessionSnapshot
import dev.example.moodlenative.storage.AppSessionStore
import java.time.Instant
import java.util.concurrent.CountDownLatch
import kotlin.coroutines.Continuation
import kotlin.coroutines.EmptyCoroutineContext
import kotlin.coroutines.startCoroutine
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class MoodleNativeCalendarPreferencesRepositoryTest {
    @Test
    fun missingSessionDoesNotCreateGatewayForLoad() {
        val repository = MoodleNativeCalendarPreferencesRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot()),
            gatewayFactory = { error("Gateway should not be created without a session") },
        )

        val result = runSuspend { repository.load() }

        assertTrue(result is LiveCalendarPreferencesResult.MissingSession)
    }

    @Test
    fun loadMapsCalendarPreferenceValues() {
        val gateway = FakeCalendarPreferencesGateway(
            preferences = listOf(
                LmsUserPreference("calendar_timeformat", "%H:%M"),
                LmsUserPreference("calendar_startwday", "0"),
                LmsUserPreference("calendar_maxevents", "20"),
                LmsUserPreference("calendar_lookahead", "365"),
                LmsUserPreference("calendar_persistflt", "1"),
            ),
        )
        val repository = MoodleNativeCalendarPreferencesRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot(lmsSession = session())),
            gatewayFactory = { gateway },
            now = { Instant.parse("2026-06-12T03:04:05Z") },
        )

        val result = runSuspend { repository.load() } as LiveCalendarPreferencesResult.Loaded

        assertEquals(
            CalendarPreferencesForm(
                timeFormat = "%H:%M",
                startWeekday = "0",
                maxEvents = "20",
                lookAhead = "365",
                persistFilters = true,
            ),
            result.form,
        )
        assertEquals(1, gateway.fetchCount)
        assertEquals(Instant.parse("2026-06-12T03:04:05Z"), result.loadedAt)
    }

    @Test
    fun loadUsesSwiftDefaultsWhenPreferencesAreMissingOrNull() {
        val repository = MoodleNativeCalendarPreferencesRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot(lmsSession = session())),
            gatewayFactory = {
                FakeCalendarPreferencesGateway(
                    preferences = listOf(
                        LmsUserPreference("calendar_timeformat", null),
                        LmsUserPreference("calendar_persistflt", "0"),
                    ),
                )
            },
        )

        val result = runSuspend { repository.load() } as LiveCalendarPreferencesResult.Loaded

        assertEquals("0", result.form.timeFormat)
        assertEquals("1", result.form.startWeekday)
        assertEquals("10", result.form.maxEvents)
        assertEquals("21", result.form.lookAhead)
        assertFalse(result.form.persistFilters)
    }

    @Test
    fun setValueSendsSingleUserPreferenceUpdate() {
        val gateway = FakeCalendarPreferencesGateway()
        val repository = MoodleNativeCalendarPreferencesRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot(lmsSession = session())),
            gatewayFactory = { gateway },
            now = { Instant.parse("2026-06-12T03:04:05Z") },
        )

        val result = runSuspend {
            repository.setValue("calendar_lookahead", "30")
        } as LiveCalendarPreferencesResult.Updated

        assertEquals(
            listOf(
                listOf(
                    LmsUserPreferenceUpdate(
                        type = "calendar_lookahead",
                        value = "30",
                    ),
                ),
            ),
            gateway.updates,
        )
        assertEquals("calendar_lookahead", result.key)
        assertEquals("30", result.value)
        assertEquals(Instant.parse("2026-06-12T03:04:05Z"), result.updatedAt)
    }

    @Test
    fun failureReturnsFailedResult() {
        val repository = MoodleNativeCalendarPreferencesRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot(lmsSession = session())),
            gatewayFactory = {
                FakeCalendarPreferencesGateway(fetchError = IllegalStateException("calendar prefs unavailable"))
            },
        )

        val result = runSuspend { repository.load() } as LiveCalendarPreferencesResult.Failed

        assertEquals("calendar prefs unavailable", result.message)
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

    private class FakeCalendarPreferencesGateway(
        private val preferences: List<LmsUserPreference> = emptyList(),
        private val fetchError: Exception? = null,
        private val updateError: Exception? = null,
    ) : CalendarPreferencesGateway {
        var fetchCount = 0
        val updates = mutableListOf<List<LmsUserPreferenceUpdate>>()

        override suspend fun fetchUserPreferences(): List<LmsUserPreference> {
            fetchCount += 1
            fetchError?.let { throw it }
            return preferences
        }

        override suspend fun updateUserPreferences(preferences: List<LmsUserPreferenceUpdate>) {
            updateError?.let { throw it }
            updates += preferences
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
