package dev.example.moodlenative.features

data class LmsMessagePreferences(
    val notificationPreferences: LmsNotificationPreferences,
    val blockNonContacts: Int,
    val enterToSend: Boolean,
)

data class LmsNotificationPreferences(
    val userID: Int,
    val disableAll: Boolean,
    val processors: List<LmsNotificationPreferencesProcessor>,
    val components: List<LmsNotificationPreferencesComponent>,
) {
    val enableAll: Boolean
        get() = !disableAll
}

data class LmsNotificationPreferencesProcessor(
    val displayName: String,
    val name: String,
    val hasSettings: Boolean,
    val contextID: Int?,
    val userConfigured: Boolean,
)

data class LmsNotificationPreferencesComponent(
    val displayName: String,
    val description: String? = null,
    val notifications: List<LmsNotificationPreference> = emptyList(),
)

data class LmsNotificationPreference(
    val displayName: String,
    val preferenceKey: String,
    val processors: List<LmsNotificationPreferenceProcessor> = emptyList(),
) {
    fun processor(name: String): LmsNotificationPreferenceProcessor? =
        processors.firstOrNull { it.name == name }
}

data class LmsNotificationPreferenceProcessor(
    val displayName: String,
    val name: String,
    val locked: Boolean,
    val lockedMessage: String?,
    val userConfigured: Boolean,
    val enabled: Boolean?,
    val loggedIn: LmsNotificationPreferenceProcessorState?,
    val loggedOff: LmsNotificationPreferenceProcessorState?,
)

data class LmsNotificationPreferenceProcessorState(
    val name: String,
    val displayName: String,
    val checked: Boolean,
)
