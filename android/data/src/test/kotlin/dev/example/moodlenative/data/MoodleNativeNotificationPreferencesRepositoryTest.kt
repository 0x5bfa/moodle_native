package dev.example.moodlenative.data

import dev.example.moodlenative.core.LmsAuthenticationSession
import dev.example.moodlenative.features.LmsNotificationPreference
import dev.example.moodlenative.features.LmsNotificationPreferenceProcessor
import dev.example.moodlenative.features.LmsNotificationPreferenceProcessorState
import dev.example.moodlenative.features.LmsNotificationPreferences
import dev.example.moodlenative.features.LmsNotificationPreferencesComponent
import dev.example.moodlenative.features.LmsNotificationPreferencesProcessor
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

class MoodleNativeNotificationPreferencesRepositoryTest {
    @Test
    fun missingSessionDoesNotCreateGatewayForLoad() {
        val repository = MoodleNativeNotificationPreferencesRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot()),
            gatewayFactory = { error("Gateway should not be created without a session") },
        )

        val result = runSuspend { repository.load() }

        assertTrue(result is LiveNotificationPreferencesResult.MissingSession)
    }

    @Test
    fun loadFetchesNotificationPreferences() {
        val preferences = preferences()
        val gateway = FakeNotificationPreferencesGateway(preferences = preferences)
        val repository = MoodleNativeNotificationPreferencesRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot(lmsSession = session())),
            gatewayFactory = { gateway },
            now = { Instant.parse("2026-06-12T03:04:05Z") },
        )

        val result = runSuspend { repository.load() } as LiveNotificationPreferencesResult.Loaded

        assertEquals(1, gateway.fetchCount)
        assertEquals(preferences, result.preferences)
        assertEquals(Instant.parse("2026-06-12T03:04:05Z"), result.loadedAt)
    }

    @Test
    fun setAllNotificationsEnabledSendsEmailStopAndReloads() {
        val gateway = FakeNotificationPreferencesGateway(preferences = preferences(disableAll = true))
        val repository = MoodleNativeNotificationPreferencesRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot(lmsSession = session())),
            gatewayFactory = { gateway },
        )

        val result = runSuspend {
            repository.setAllNotificationsEnabled(isEnabled = false)
        } as LiveNotificationPreferencesResult.Updated

        assertEquals(listOf(emptyList<LmsUserPreferenceUpdate>() to true), gateway.updates)
        assertEquals(1, gateway.fetchCount)
        assertTrue(result.action is NotificationPreferencesAction.SetAllNotificationsEnabled)
    }

    @Test
    fun setNotificationEnabledSendsProcessorPreferenceKey() {
        val gateway = FakeNotificationPreferencesGateway()
        val repository = MoodleNativeNotificationPreferencesRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot(lmsSession = session())),
            gatewayFactory = { gateway },
        )

        runSuspend {
            repository.setNotificationEnabled(
                isEnabled = true,
                preferenceKey = "message_provider_mod_assign_assign_notification",
                processorName = "airnotifier",
            )
        }

        assertEquals(
            listOf(
                listOf(
                    LmsUserPreferenceUpdate(
                        type = "message_provider_mod_assign_assign_notification_airnotifier",
                        value = "1",
                    ),
                ) to null,
            ),
            gateway.updates,
        )
    }

    @Test
    fun setLegacyNotificationStatePreservesOtherProcessorStates() {
        val gateway = FakeNotificationPreferencesGateway()
        val repository = MoodleNativeNotificationPreferencesRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot(lmsSession = session())),
            gatewayFactory = { gateway },
        )

        runSuspend {
            repository.setLegacyNotificationState(
                isEnabled = true,
                stateName = "loggedin",
                preferenceKey = "message_provider_mod_forum_posts",
                processorName = "airnotifier",
            )
        }

        assertEquals(
            listOf(
                listOf(
                    LmsUserPreferenceUpdate(
                        type = "message_provider_mod_forum_posts_loggedin",
                        value = "airnotifier,email",
                    ),
                ) to null,
            ),
            gateway.updates,
        )
    }

    @Test
    fun setLegacyNotificationStateSendsNoneWhenAllProcessorsAreDisabled() {
        val gateway = FakeNotificationPreferencesGateway(preferences = preferences(legacyEmailLoggedOff = false))
        val repository = MoodleNativeNotificationPreferencesRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot(lmsSession = session())),
            gatewayFactory = { gateway },
        )

        runSuspend {
            repository.setLegacyNotificationState(
                isEnabled = false,
                stateName = "loggedoff",
                preferenceKey = "message_provider_mod_forum_posts",
                processorName = "airnotifier",
            )
        }

        assertEquals(
            listOf(
                listOf(
                    LmsUserPreferenceUpdate(
                        type = "message_provider_mod_forum_posts_loggedoff",
                        value = "none",
                    ),
                ) to null,
            ),
            gateway.updates,
        )
    }

    @Test
    fun failureReturnsFailedResult() {
        val repository = MoodleNativeNotificationPreferencesRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot(lmsSession = session())),
            gatewayFactory = {
                FakeNotificationPreferencesGateway(fetchError = IllegalStateException("preferences unavailable"))
            },
        )

        val result = runSuspend { repository.load() } as LiveNotificationPreferencesResult.Failed

        assertEquals("preferences unavailable", result.message)
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

    private class FakeNotificationPreferencesGateway(
        private val preferences: LmsNotificationPreferences = preferences(),
        private val fetchError: Exception? = null,
        private val updateError: Exception? = null,
    ) : NotificationPreferencesGateway {
        var fetchCount = 0
        val updates = mutableListOf<Pair<List<LmsUserPreferenceUpdate>, Boolean?>>()

        override suspend fun fetchNotificationPreferences(): LmsNotificationPreferences {
            fetchCount += 1
            fetchError?.let { throw it }
            return preferences
        }

        override suspend fun updateUserPreferences(
            preferences: List<LmsUserPreferenceUpdate>,
            disableNotifications: Boolean?,
        ) {
            updateError?.let { throw it }
            updates += preferences to disableNotifications
        }
    }

    private companion object {
        fun preferences(
            disableAll: Boolean = false,
            legacyEmailLoggedOff: Boolean = true,
        ): LmsNotificationPreferences =
            LmsNotificationPreferences(
                userID = 99,
                disableAll = disableAll,
                processors = listOf(
                    LmsNotificationPreferencesProcessor(
                        displayName = "Mobile",
                        name = "airnotifier",
                        hasSettings = false,
                        contextID = null,
                        userConfigured = true,
                    ),
                ),
                components = listOf(
                    LmsNotificationPreferencesComponent(
                        displayName = "課題",
                        notifications = listOf(
                            notification(),
                            legacyNotification(emailLoggedOff = legacyEmailLoggedOff),
                        ),
                    ),
                ),
            )

        fun notification(): LmsNotificationPreference =
            LmsNotificationPreference(
                displayName = "課題通知",
                preferenceKey = "message_provider_mod_assign_assign_notification",
                processors = listOf(
                    LmsNotificationPreferenceProcessor(
                        displayName = "Mobile",
                        name = "airnotifier",
                        locked = false,
                        lockedMessage = null,
                        userConfigured = true,
                        enabled = false,
                        loggedIn = null,
                        loggedOff = null,
                    ),
                ),
            )

        fun legacyNotification(emailLoggedOff: Boolean = true): LmsNotificationPreference =
            LmsNotificationPreference(
                displayName = "フォーラム投稿",
                preferenceKey = "message_provider_mod_forum_posts",
                processors = listOf(
                    LmsNotificationPreferenceProcessor(
                        displayName = "Mobile",
                        name = "airnotifier",
                        locked = false,
                        lockedMessage = null,
                        userConfigured = true,
                        enabled = null,
                        loggedIn = LmsNotificationPreferenceProcessorState(
                            name = "loggedin",
                            displayName = "オンライン",
                            checked = false,
                        ),
                        loggedOff = LmsNotificationPreferenceProcessorState(
                            name = "loggedoff",
                            displayName = "オフライン",
                            checked = true,
                        ),
                    ),
                    LmsNotificationPreferenceProcessor(
                        displayName = "Email",
                        name = "email",
                        locked = false,
                        lockedMessage = null,
                        userConfigured = true,
                        enabled = null,
                        loggedIn = LmsNotificationPreferenceProcessorState(
                            name = "loggedin",
                            displayName = "オンライン",
                            checked = true,
                        ),
                        loggedOff = LmsNotificationPreferenceProcessorState(
                            name = "loggedoff",
                            displayName = "オフライン",
                            checked = emailLoggedOff,
                        ),
                    ),
                ),
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
