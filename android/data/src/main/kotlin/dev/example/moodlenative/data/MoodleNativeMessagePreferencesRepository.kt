package dev.example.moodlenative.data

import dev.example.moodlenative.core.LmsAuthenticationSession
import dev.example.moodlenative.features.LmsMessagePreferences
import dev.example.moodlenative.features.LmsNotificationPreference
import dev.example.moodlenative.features.LmsNotificationPreferences
import dev.example.moodlenative.storage.AppSessionSnapshot
import dev.example.moodlenative.storage.AppSessionStore
import java.time.Instant

class MoodleNativeMessagePreferencesRepository internal constructor(
    private val sessionStore: AppSessionStore,
    private val gatewayFactory: (LmsAuthenticationSession) -> MessagePreferencesGateway = { session ->
        LmsMessagePreferencesWebServiceGateway(session)
    },
    private val now: () -> Instant = { Instant.now() },
) {
    constructor(sessionStore: AppSessionStore) : this(
        sessionStore = sessionStore,
        gatewayFactory = { session -> LmsMessagePreferencesWebServiceGateway(session) },
        now = { Instant.now() },
    )

    suspend fun load(): LiveMessagePreferencesResult {
        val snapshot = sessionStore.readSnapshot()
        val session = snapshot.lmsSession ?: return LiveMessagePreferencesResult.MissingSession(snapshot)
        val gateway = gatewayFactory(session)

        return loadWithGateway(gateway)
    }

    suspend fun setContactablePrivacy(value: Int): LiveMessagePreferencesResult =
        updateAndReload(
            action = MessagePreferencesAction.SetContactablePrivacy(value),
        ) { gateway ->
            gateway.updateUserPreferences(
                listOf(
                    LmsUserPreferenceUpdate(
                        type = "message_blocknoncontacts",
                        value = value.toString(),
                    ),
                ),
            )
        }

    suspend fun setProcessorEnabled(
        isEnabled: Boolean,
        preferenceKey: String,
        processorName: String,
    ): LiveMessagePreferencesResult =
        updateAndReload(
            action = MessagePreferencesAction.SetProcessorEnabled(
                preferenceKey = preferenceKey,
                processorName = processorName,
                isEnabled = isEnabled,
            ),
        ) { gateway ->
            val notification = gateway.fetchMessagePreferences()
                .notificationPreferences
                .notification(preferenceKey)
            val enabledProcessorNames = notification.processors.mapNotNull { currentProcessor ->
                val nextEnabled = if (currentProcessor.name == processorName) {
                    isEnabled
                } else {
                    currentProcessor.enabled ?: false
                }
                currentProcessor.name.takeIf { nextEnabled }
            }

            gateway.updateUserPreferences(
                listOf(
                    LmsUserPreferenceUpdate(
                        type = "${preferenceKey}_enabled",
                        value = enabledProcessorNames.joinToString(",").ifEmpty { "none" },
                    ),
                ),
            )
        }

    private suspend fun updateAndReload(
        action: MessagePreferencesAction,
        update: suspend (MessagePreferencesGateway) -> Unit,
    ): LiveMessagePreferencesResult {
        val snapshot = sessionStore.readSnapshot()
        val session = snapshot.lmsSession ?: return LiveMessagePreferencesResult.MissingSession(snapshot)
        val gateway = gatewayFactory(session)

        return try {
            update(gateway)
            when (val result = loadWithGateway(gateway)) {
                is LiveMessagePreferencesResult.Loaded -> LiveMessagePreferencesResult.Updated(
                    snapshot = result.snapshot,
                    preferences = result.preferences,
                    allowsSiteMessaging = result.allowsSiteMessaging,
                    action = action,
                    loadedAt = result.loadedAt,
                )
                else -> result
            }
        } catch (error: Exception) {
            failed(error)
        }
    }

    private suspend fun loadWithGateway(gateway: MessagePreferencesGateway): LiveMessagePreferencesResult =
        try {
            val preferences = gateway.fetchMessagePreferences()
            val siteInfo = gateway.fetchSiteInfo()
            LiveMessagePreferencesResult.Loaded(
                snapshot = sessionStore.readSnapshot(),
                preferences = preferences,
                allowsSiteMessaging = siteInfo.isAdvancedFeatureEnabled("messagingallusers"),
                loadedAt = now(),
            )
        } catch (error: Exception) {
            failed(error)
        }

    private fun failed(error: Exception): LiveMessagePreferencesResult.Failed =
        LiveMessagePreferencesResult.Failed(
            snapshot = sessionStore.readSnapshot(),
            message = error.message ?: "メッセージ設定を更新できませんでした。",
        )
}

internal interface MessagePreferencesGateway {
    suspend fun fetchMessagePreferences(): LmsMessagePreferences

    suspend fun fetchSiteInfo(): LmsSiteInfo

    suspend fun updateUserPreferences(preferences: List<LmsUserPreferenceUpdate>)
}

sealed class MessagePreferencesAction {
    data class SetContactablePrivacy(
        val value: Int,
    ) : MessagePreferencesAction()

    data class SetProcessorEnabled(
        val preferenceKey: String,
        val processorName: String,
        val isEnabled: Boolean,
    ) : MessagePreferencesAction()
}

sealed class LiveMessagePreferencesResult {
    abstract val snapshot: AppSessionSnapshot

    data class MissingSession(
        override val snapshot: AppSessionSnapshot,
    ) : LiveMessagePreferencesResult()

    data class Loaded(
        override val snapshot: AppSessionSnapshot,
        val preferences: LmsMessagePreferences,
        val allowsSiteMessaging: Boolean,
        val loadedAt: Instant,
    ) : LiveMessagePreferencesResult()

    data class Updated(
        override val snapshot: AppSessionSnapshot,
        val preferences: LmsMessagePreferences,
        val allowsSiteMessaging: Boolean,
        val action: MessagePreferencesAction,
        val loadedAt: Instant,
    ) : LiveMessagePreferencesResult()

    data class Failed(
        override val snapshot: AppSessionSnapshot,
        val message: String,
    ) : LiveMessagePreferencesResult()
}

private fun LmsNotificationPreferences.notification(preferenceKey: String): LmsNotificationPreference =
    components.asSequence()
        .flatMap { component -> component.notifications.asSequence() }
        .firstOrNull { notification -> notification.preferenceKey == preferenceKey }
        ?: throw IllegalArgumentException("Notification preference '$preferenceKey' was not found.")
