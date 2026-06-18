package dev.example.moodlenative.features

data class MessagePreferencesPresentation(
    val selectedContactScopeValue: Int,
    val selectedContactScopeLabel: String,
    val contactScopeOptions: List<MessageContactScopePresentation>,
    val instantMessageProcessors: List<MessageNotificationProcessorPresentation>,
    val areNotificationsDisabled: Boolean,
)

data class MessageContactScopePresentation(
    val value: Int,
    val label: String,
)

data class MessageNotificationProcessorPresentation(
    val preferenceKey: String,
    val processorName: String,
    val title: String,
    val subtitle: String?,
    val checked: Boolean,
    val locked: Boolean,
)

data class NotificationPreferencesPresentation(
    val enableAll: Boolean,
    val componentGroupCount: Int,
    val processors: List<NotificationPreferencesProcessorPresentation>,
    val selectedProcessor: NotificationPreferencesProcessorPresentation?,
    val components: List<NotificationPreferencesComponentPresentation>,
)

data class NotificationPreferencesProcessorPresentation(
    val name: String,
    val displayName: String,
)

data class NotificationPreferencesComponentPresentation(
    val title: String,
    val description: String?,
    val notifications: List<NotificationPreferencePresentation>,
)

data class NotificationPreferencePresentation(
    val preferenceKey: String,
    val title: String,
    val directToggle: NotificationPreferenceTogglePresentation?,
    val legacyStates: List<LegacyNotificationPreferenceStatePresentation>,
)

data class NotificationPreferenceTogglePresentation(
    val preferenceKey: String,
    val processorName: String,
    val subtitle: String?,
    val checked: Boolean,
    val locked: Boolean,
)

data class LegacyNotificationPreferenceStatePresentation(
    val preferenceKey: String,
    val processorName: String,
    val stateName: String,
    val title: String,
    val subtitle: String?,
    val checked: Boolean,
    val locked: Boolean,
)

fun messageContactScopeLabel(value: Int): String =
    when (value) {
        0 -> "同じコースの参加者"
        1 -> "連絡先のみ"
        2 -> "サイト全体"
        else -> "未設定"
    }

fun LmsMessagePreferences.presentation(allowsSiteMessaging: Boolean): MessagePreferencesPresentation =
    MessagePreferencesPresentation(
        selectedContactScopeValue = blockNonContacts,
        selectedContactScopeLabel = messageContactScopeLabel(blockNonContacts),
        contactScopeOptions = messageContactScopeOptions(
            selectedValue = blockNonContacts,
            allowsSiteMessaging = allowsSiteMessaging,
        ),
        instantMessageProcessors = instantMessageNotification?.processors.orEmpty().map { processor ->
            MessageNotificationProcessorPresentation(
                preferenceKey = instantMessageNotificationPreferenceKey,
                processorName = processor.name,
                title = processor.displayName,
                subtitle = processor.lockedMessage?.takeIf { it.isNotBlank() },
                checked = processor.enabled ?: false,
                locked = processor.locked,
            )
        },
        areNotificationsDisabled = notificationPreferences.disableAll,
    )

fun LmsNotificationPreferences.presentation(
    currentSelectedProcessorName: String?,
): NotificationPreferencesPresentation {
    val selectedProcessorName = preferredNotificationPreferenceProcessorName(currentSelectedProcessorName)
    val selectedProcessor = processors.firstOrNull { processor -> processor.name == selectedProcessorName }

    return NotificationPreferencesPresentation(
        enableAll = enableAll,
        componentGroupCount = components.size,
        processors = processors.map { processor -> processor.presentation },
        selectedProcessor = selectedProcessor?.presentation,
        components = selectedProcessorName?.let { selectedName ->
            components.mapNotNull { component ->
                val notifications = component.notifications.mapNotNull { notification ->
                    notification.presentation(selectedProcessorName = selectedName)
                }
                NotificationPreferencesComponentPresentation(
                    title = component.displayName,
                    description = component.description,
                    notifications = notifications,
                ).takeIf { notifications.isNotEmpty() }
            }
        }.orEmpty(),
    )
}

fun LmsNotificationPreferences.preferredNotificationPreferenceProcessorName(
    currentSelectedProcessorName: String?,
): String? {
    if (currentSelectedProcessorName != null && processors.any { it.name == currentSelectedProcessorName }) {
        return currentSelectedProcessorName
    }

    return processors.firstOrNull { it.name == "airnotifier" }?.name
        ?: processors.firstOrNull()?.name
}

private val LmsNotificationPreferencesProcessor.presentation: NotificationPreferencesProcessorPresentation
    get() = NotificationPreferencesProcessorPresentation(
        name = name,
        displayName = displayName,
    )

private fun LmsNotificationPreference.presentation(
    selectedProcessorName: String,
): NotificationPreferencePresentation? {
    val processor = processor(selectedProcessorName) ?: return null
    val directToggle = processor.enabled?.let { enabled ->
        NotificationPreferenceTogglePresentation(
            preferenceKey = preferenceKey,
            processorName = processor.name,
            subtitle = processor.lockedMessage?.takeIf { it.isNotBlank() },
            checked = enabled,
            locked = processor.locked,
        )
    }
    val legacyStates = if (directToggle == null) {
        listOfNotNull(
            processor.loggedIn?.presentation(
                preference = this,
                processorName = processor.name,
                locked = processor.locked,
                lockedMessage = processor.lockedMessage,
            ),
            processor.loggedOff?.presentation(
                preference = this,
                processorName = processor.name,
                locked = processor.locked,
                lockedMessage = processor.lockedMessage,
            ),
        )
    } else {
        emptyList()
    }

    return NotificationPreferencePresentation(
        preferenceKey = preferenceKey,
        title = displayName,
        directToggle = directToggle,
        legacyStates = legacyStates,
    ).takeIf { directToggle != null || legacyStates.isNotEmpty() }
}

private fun LmsNotificationPreferenceProcessorState.presentation(
    preference: LmsNotificationPreference,
    processorName: String,
    locked: Boolean,
    lockedMessage: String?,
): LegacyNotificationPreferenceStatePresentation =
    LegacyNotificationPreferenceStatePresentation(
        preferenceKey = preference.preferenceKey,
        processorName = processorName,
        stateName = name,
        title = displayName,
        subtitle = lockedMessage?.takeIf { it.isNotBlank() },
        checked = checked,
        locked = locked,
    )

private val LmsMessagePreferences.instantMessageNotification: LmsNotificationPreference?
    get() = notificationPreferences.components
        .flatMap { component -> component.notifications }
        .firstOrNull { notification -> notification.preferenceKey == instantMessageNotificationPreferenceKey }

private fun messageContactScopeOptions(
    selectedValue: Int,
    allowsSiteMessaging: Boolean,
): List<MessageContactScopePresentation> =
    buildList {
        add(MessageContactScopePresentation(value = 0, label = messageContactScopeLabel(0)))
        add(MessageContactScopePresentation(value = 1, label = messageContactScopeLabel(1)))
        if (allowsSiteMessaging || selectedValue == 2) {
            add(MessageContactScopePresentation(value = 2, label = messageContactScopeLabel(2)))
        }
    }

private const val instantMessageNotificationPreferenceKey = "message_provider_moodle_instantmessage"
