package dev.example.moodlenative.data

import dev.example.moodlenative.core.LmsAuthenticationSession
import dev.example.moodlenative.features.LmsNotificationPreference
import dev.example.moodlenative.features.LmsNotificationPreferences
import dev.example.moodlenative.storage.AppSessionSnapshot
import dev.example.moodlenative.storage.AppSessionStore
import java.time.Instant

class MoodleNativeNotificationPreferencesRepository internal constructor(
    private val sessionStore: AppSessionStore,
    private val gatewayFactory: (LmsAuthenticationSession) -> NotificationPreferencesGateway = { session ->
        LmsNotificationPreferencesWebServiceGateway(session)
    },
    private val now: () -> Instant = { Instant.now() },
) {
    constructor(sessionStore: AppSessionStore) : this(
        sessionStore = sessionStore,
        gatewayFactory = { session -> LmsNotificationPreferencesWebServiceGateway(session) },
        now = { Instant.now() },
    )

    suspend fun load(): LiveNotificationPreferencesResult {
        val snapshot = sessionStore.readSnapshot()
        val session = snapshot.lmsSession ?: return LiveNotificationPreferencesResult.MissingSession(snapshot)
        val gateway = gatewayFactory(session)

        return try {
            LiveNotificationPreferencesResult.Loaded(
                snapshot = sessionStore.readSnapshot(),
                preferences = gateway.fetchNotificationPreferences(),
                loadedAt = now(),
            )
        } catch (error: Exception) {
            failed(error)
        }
    }

    suspend fun setAllNotificationsEnabled(isEnabled: Boolean): LiveNotificationPreferencesResult =
        updateAndReload(
            action = NotificationPreferencesAction.SetAllNotificationsEnabled(isEnabled),
        ) { gateway ->
            gateway.updateUserPreferences(
                preferences = emptyList(),
                disableNotifications = !isEnabled,
            )
        }

    suspend fun setNotificationEnabled(
        isEnabled: Boolean,
        preferenceKey: String,
        processorName: String,
    ): LiveNotificationPreferencesResult =
        updateAndReload(
            action = NotificationPreferencesAction.SetNotificationEnabled(
                preferenceKey = preferenceKey,
                processorName = processorName,
                isEnabled = isEnabled,
            ),
        ) { gateway ->
            gateway.updateUserPreferences(
                preferences = listOf(
                    LmsUserPreferenceUpdate(
                        type = "${preferenceKey}_$processorName",
                        value = if (isEnabled) "1" else "0",
                    ),
                ),
                disableNotifications = null,
            )
        }

    suspend fun setLegacyNotificationState(
        isEnabled: Boolean,
        stateName: String,
        preferenceKey: String,
        processorName: String,
    ): LiveNotificationPreferencesResult =
        updateAndReload(
            action = NotificationPreferencesAction.SetLegacyNotificationState(
                preferenceKey = preferenceKey,
                stateName = stateName,
                processorName = processorName,
                isEnabled = isEnabled,
            ),
        ) { gateway ->
            val notification = gateway.fetchNotificationPreferences().notification(preferenceKey)
            val enabledProcessorNames = notification.processors.mapNotNull { processor ->
                val current = when (stateName) {
                    "loggedin" -> processor.loggedIn?.checked ?: false
                    "loggedoff" -> processor.loggedOff?.checked ?: false
                    else -> false
                }
                val next = if (processor.name == processorName) isEnabled else current
                processor.name.takeIf { next }
            }

            gateway.updateUserPreferences(
                preferences = listOf(
                    LmsUserPreferenceUpdate(
                        type = "${preferenceKey}_$stateName",
                        value = enabledProcessorNames.joinToString(",").ifEmpty { "none" },
                    ),
                ),
                disableNotifications = null,
            )
        }

    private suspend fun updateAndReload(
        action: NotificationPreferencesAction,
        update: suspend (NotificationPreferencesGateway) -> Unit,
    ): LiveNotificationPreferencesResult {
        val snapshot = sessionStore.readSnapshot()
        val session = snapshot.lmsSession
            ?: return LiveNotificationPreferencesResult.MissingSession(snapshot)
        val gateway = gatewayFactory(session)

        return try {
            update(gateway)
            LiveNotificationPreferencesResult.Updated(
                snapshot = sessionStore.readSnapshot(),
                preferences = gateway.fetchNotificationPreferences(),
                action = action,
                loadedAt = now(),
            )
        } catch (error: Exception) {
            failed(error)
        }
    }

    private fun failed(error: Exception): LiveNotificationPreferencesResult.Failed =
        LiveNotificationPreferencesResult.Failed(
            snapshot = sessionStore.readSnapshot(),
            message = error.message ?: "通知設定を更新できませんでした。",
        )
}

private fun LmsNotificationPreferences.notification(preferenceKey: String): LmsNotificationPreference =
    components.asSequence()
        .flatMap { component -> component.notifications.asSequence() }
        .firstOrNull { notification -> notification.preferenceKey == preferenceKey }
        ?: throw IllegalArgumentException("Notification preference '$preferenceKey' was not found.")

internal interface NotificationPreferencesGateway {
    suspend fun fetchNotificationPreferences(): LmsNotificationPreferences

    suspend fun updateUserPreferences(
        preferences: List<LmsUserPreferenceUpdate>,
        disableNotifications: Boolean?,
    )
}

sealed class NotificationPreferencesAction {
    data class SetAllNotificationsEnabled(
        val isEnabled: Boolean,
    ) : NotificationPreferencesAction()

    data class SetNotificationEnabled(
        val preferenceKey: String,
        val processorName: String,
        val isEnabled: Boolean,
    ) : NotificationPreferencesAction()

    data class SetLegacyNotificationState(
        val preferenceKey: String,
        val stateName: String,
        val processorName: String,
        val isEnabled: Boolean,
    ) : NotificationPreferencesAction()
}

sealed class LiveNotificationPreferencesResult {
    abstract val snapshot: AppSessionSnapshot

    data class MissingSession(
        override val snapshot: AppSessionSnapshot,
    ) : LiveNotificationPreferencesResult()

    data class Loaded(
        override val snapshot: AppSessionSnapshot,
        val preferences: LmsNotificationPreferences,
        val loadedAt: Instant,
    ) : LiveNotificationPreferencesResult()

    data class Updated(
        override val snapshot: AppSessionSnapshot,
        val preferences: LmsNotificationPreferences,
        val action: NotificationPreferencesAction,
        val loadedAt: Instant,
    ) : LiveNotificationPreferencesResult()

    data class Failed(
        override val snapshot: AppSessionSnapshot,
        val message: String,
    ) : LiveNotificationPreferencesResult()
}
