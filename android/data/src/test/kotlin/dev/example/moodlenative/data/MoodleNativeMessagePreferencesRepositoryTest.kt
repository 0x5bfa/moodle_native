package dev.example.moodlenative.data

import dev.example.moodlenative.core.LmsAuthenticationSession
import dev.example.moodlenative.features.LmsMessagePreferences
import dev.example.moodlenative.features.LmsNotificationPreference
import dev.example.moodlenative.features.LmsNotificationPreferenceProcessor
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

class MoodleNativeMessagePreferencesRepositoryTest {
    @Test
    fun missingSessionDoesNotCreateGatewayForLoad() {
        val repository = MoodleNativeMessagePreferencesRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot()),
            gatewayFactory = { error("Gateway should not be created without a session") },
        )

        val result = runSuspend { repository.load() }

        assertTrue(result is LiveMessagePreferencesResult.MissingSession)
    }

    @Test
    fun loadFetchesMessagePreferencesAndSiteMessagingFeature() {
        val preferences = messagePreferences(blockNonContacts = 1)
        val gateway = FakeMessagePreferencesGateway(
            preferences = preferences,
            siteInfo = siteInfo(allowsSiteMessaging = true),
        )
        val repository = MoodleNativeMessagePreferencesRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot(lmsSession = session())),
            gatewayFactory = { gateway },
            now = { Instant.parse("2026-06-12T03:04:05Z") },
        )

        val result = runSuspend { repository.load() } as LiveMessagePreferencesResult.Loaded

        assertEquals(1, gateway.fetchPreferencesCount)
        assertEquals(1, gateway.fetchSiteInfoCount)
        assertEquals(preferences, result.preferences)
        assertTrue(result.allowsSiteMessaging)
        assertEquals(Instant.parse("2026-06-12T03:04:05Z"), result.loadedAt)
    }

    @Test
    fun setContactablePrivacySendsMessageBlockNonContactsAndReloads() {
        val gateway = FakeMessagePreferencesGateway()
        val repository = MoodleNativeMessagePreferencesRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot(lmsSession = session())),
            gatewayFactory = { gateway },
        )

        val result = runSuspend {
            repository.setContactablePrivacy(2)
        } as LiveMessagePreferencesResult.Updated

        assertEquals(
            listOf(
                listOf(
                    LmsUserPreferenceUpdate(
                        type = "message_blocknoncontacts",
                        value = "2",
                    ),
                ),
            ),
            gateway.updates,
        )
        assertTrue(result.action is MessagePreferencesAction.SetContactablePrivacy)
        assertEquals(1, gateway.fetchPreferencesCount)
        assertEquals(1, gateway.fetchSiteInfoCount)
    }

    @Test
    fun setProcessorEnabledPreservesOtherInstantMessageProcessors() {
        val gateway = FakeMessagePreferencesGateway()
        val repository = MoodleNativeMessagePreferencesRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot(lmsSession = session())),
            gatewayFactory = { gateway },
        )

        runSuspend {
            repository.setProcessorEnabled(
                isEnabled = true,
                preferenceKey = "message_provider_moodle_instantmessage",
                processorName = "airnotifier",
            )
        }

        assertEquals(
            listOf(
                listOf(
                    LmsUserPreferenceUpdate(
                        type = "message_provider_moodle_instantmessage_enabled",
                        value = "airnotifier,email",
                    ),
                ),
            ),
            gateway.updates,
        )
    }

    @Test
    fun setProcessorEnabledSendsNoneWhenAllProcessorsAreDisabled() {
        val gateway = FakeMessagePreferencesGateway(
            preferences = messagePreferences(emailEnabled = false),
        )
        val repository = MoodleNativeMessagePreferencesRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot(lmsSession = session())),
            gatewayFactory = { gateway },
        )

        runSuspend {
            repository.setProcessorEnabled(
                isEnabled = false,
                preferenceKey = "message_provider_moodle_instantmessage",
                processorName = "airnotifier",
            )
        }

        assertEquals(
            listOf(
                listOf(
                    LmsUserPreferenceUpdate(
                        type = "message_provider_moodle_instantmessage_enabled",
                        value = "none",
                    ),
                ),
            ),
            gateway.updates,
        )
    }

    @Test
    fun failureReturnsFailedResult() {
        val repository = MoodleNativeMessagePreferencesRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot(lmsSession = session())),
            gatewayFactory = {
                FakeMessagePreferencesGateway(fetchPreferencesError = IllegalStateException("message unavailable"))
            },
        )

        val result = runSuspend { repository.load() } as LiveMessagePreferencesResult.Failed

        assertEquals("message unavailable", result.message)
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

    private class FakeMessagePreferencesGateway(
        private val preferences: LmsMessagePreferences = messagePreferences(),
        private val siteInfo: LmsSiteInfo = siteInfo(),
        private val fetchPreferencesError: Exception? = null,
        private val fetchSiteInfoError: Exception? = null,
        private val updateError: Exception? = null,
    ) : MessagePreferencesGateway {
        var fetchPreferencesCount = 0
        var fetchSiteInfoCount = 0
        val updates = mutableListOf<List<LmsUserPreferenceUpdate>>()

        override suspend fun fetchMessagePreferences(): LmsMessagePreferences {
            fetchPreferencesCount += 1
            fetchPreferencesError?.let { throw it }
            return preferences
        }

        override suspend fun fetchSiteInfo(): LmsSiteInfo {
            fetchSiteInfoCount += 1
            fetchSiteInfoError?.let { throw it }
            return siteInfo
        }

        override suspend fun updateUserPreferences(preferences: List<LmsUserPreferenceUpdate>) {
            updateError?.let { throw it }
            updates += preferences
        }
    }

    private companion object {
        fun messagePreferences(
            blockNonContacts: Int = 0,
            disableAll: Boolean = false,
            emailEnabled: Boolean = true,
        ): LmsMessagePreferences =
            LmsMessagePreferences(
                notificationPreferences = LmsNotificationPreferences(
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
                        LmsNotificationPreferencesProcessor(
                            displayName = "Email",
                            name = "email",
                            hasSettings = false,
                            contextID = null,
                            userConfigured = true,
                        ),
                    ),
                    components = listOf(
                        LmsNotificationPreferencesComponent(
                            displayName = "メッセージ",
                            notifications = listOf(instantMessageNotification(emailEnabled = emailEnabled)),
                        ),
                    ),
                ),
                blockNonContacts = blockNonContacts,
                enterToSend = true,
            )

        fun instantMessageNotification(emailEnabled: Boolean = true): LmsNotificationPreference =
            LmsNotificationPreference(
                displayName = "インスタントメッセージ",
                preferenceKey = "message_provider_moodle_instantmessage",
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
                    LmsNotificationPreferenceProcessor(
                        displayName = "Email",
                        name = "email",
                        locked = false,
                        lockedMessage = null,
                        userConfigured = true,
                        enabled = emailEnabled,
                        loggedIn = null,
                        loggedOff = null,
                    ),
                ),
            )

        fun siteInfo(allowsSiteMessaging: Boolean = false): LmsSiteInfo =
            LmsSiteInfo(
                advancedFeatures = mapOf("messagingallusers" to allowsSiteMessaging),
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
