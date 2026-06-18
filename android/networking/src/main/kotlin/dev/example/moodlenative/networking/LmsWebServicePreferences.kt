package dev.example.moodlenative.networking

import java.net.URI
import kotlinx.serialization.KSerializer
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerializationException
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.JsonDecoder
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.intOrNull

@Serializable
data class NotificationPreferencesResponse(
    val preferences: NotificationPreferences,
)

@Serializable
data class NotificationPreferences(
    @SerialName("userid")
    val userID: Int,
    @SerialName("disableall")
    private val disableAllRaw: JsonElement? = null,
    val processors: List<NotificationPreferencesProcessor> = emptyList(),
    val components: List<NotificationPreferencesComponent> = emptyList(),
) {
    val disableAll: Boolean
        get() = disableAllRaw.boolishOrNull() ?: false

    val enableAll: Boolean
        get() = !disableAll

    constructor(
        userID: Int,
        disableAll: Boolean,
        processors: List<NotificationPreferencesProcessor>,
        components: List<NotificationPreferencesComponent>,
    ) : this(
        userID = userID,
        disableAllRaw = JsonPrimitive(disableAll),
        processors = processors,
        components = components,
    )
}

@Serializable
data class NotificationPreferencesProcessor(
    @SerialName("displayname")
    val displayName: String,
    val name: String,
    @SerialName("hassettings")
    private val hasSettingsRaw: JsonElement? = null,
    @SerialName("contextid")
    val contextID: Int? = null,
    @SerialName("userconfigured")
    private val userConfiguredRaw: JsonElement? = null,
) {
    val id: String
        get() = name

    val hasSettings: Boolean
        get() = hasSettingsRaw.boolishOrNull() ?: false

    val userConfigured: Boolean
        get() = userConfiguredRaw.boolishOrNull() ?: false

    constructor(
        displayName: String,
        name: String,
        hasSettings: Boolean,
        contextID: Int?,
        userConfigured: Boolean,
    ) : this(
        displayName = displayName,
        name = name,
        hasSettingsRaw = JsonPrimitive(hasSettings),
        contextID = contextID,
        userConfiguredRaw = JsonPrimitive(userConfigured),
    )
}

@Serializable
data class NotificationPreferencesComponent(
    @SerialName("displayname")
    val displayName: String,
    val description: String? = null,
    val notifications: List<NotificationPreference> = emptyList(),
) {
    val id: String
        get() = displayName
}

@Serializable
data class NotificationPreference(
    @SerialName("displayname")
    val displayName: String,
    @SerialName("preferencekey")
    val preferenceKey: String,
    val processors: List<NotificationPreferenceProcessor> = emptyList(),
) {
    val id: String
        get() = preferenceKey

    fun processor(name: String): NotificationPreferenceProcessor? =
        processors.firstOrNull { it.name == name }
}

@Serializable
data class NotificationPreferenceProcessor(
    @SerialName("displayname")
    val displayName: String,
    val name: String,
    @SerialName("locked")
    private val lockedRaw: JsonElement? = null,
    @SerialName("lockedmessage")
    val lockedMessage: String? = null,
    @SerialName("userconfigured")
    private val userConfiguredRaw: JsonElement? = null,
    @SerialName("enabled")
    private val enabledRaw: JsonElement? = null,
    @SerialName("loggedin")
    val loggedIn: NotificationPreferenceProcessorState? = null,
    @SerialName("loggedoff")
    val loggedOff: NotificationPreferenceProcessorState? = null,
) {
    val id: String
        get() = name

    val locked: Boolean
        get() = lockedRaw.boolishOrNull() ?: false

    val userConfigured: Boolean
        get() = userConfiguredRaw.boolishOrNull() ?: false

    val enabled: Boolean?
        get() = enabledRaw.boolishOrNull()

    constructor(
        displayName: String,
        name: String,
        locked: Boolean,
        lockedMessage: String?,
        userConfigured: Boolean,
        enabled: Boolean?,
        loggedIn: NotificationPreferenceProcessorState?,
        loggedOff: NotificationPreferenceProcessorState?,
    ) : this(
        displayName = displayName,
        name = name,
        lockedRaw = JsonPrimitive(locked),
        lockedMessage = lockedMessage,
        userConfiguredRaw = JsonPrimitive(userConfigured),
        enabledRaw = enabled?.let(::JsonPrimitive),
        loggedIn = loggedIn,
        loggedOff = loggedOff,
    )
}

@Serializable
data class NotificationPreferenceProcessorState(
    val name: String,
    @SerialName("displayname")
    val displayName: String,
    @SerialName("checked")
    private val checkedRaw: JsonElement? = null,
) {
    val id: String
        get() = name

    val checked: Boolean
        get() = checkedRaw.boolishOrNull() ?: false

    constructor(
        name: String,
        displayName: String,
        checked: Boolean,
    ) : this(
        name = name,
        displayName = displayName,
        checkedRaw = JsonPrimitive(checked),
    )
}

@Serializable
data class MessagePreferencesResponse(
    val preferences: NotificationPreferences,
    @SerialName("blocknoncontacts")
    val blockNonContacts: Int,
    @SerialName("entertosend")
    private val enterToSendRaw: JsonElement? = null,
) {
    val enterToSend: Boolean
        get() = enterToSendRaw.boolishOrNull() ?: false
}

data class MessagePreferences(
    val notificationPreferences: NotificationPreferences,
    val blockNonContacts: Int,
    val enterToSend: Boolean,
)

data class UserPreferenceUpdate(
    val type: String,
    val value: String?,
)

@Serializable
data class UserPreferencesResponse(
    val preferences: List<UserPreference> = emptyList(),
)

@Serializable
data class UserPreference(
    val name: String,
    @Serializable(with = StringishNullableSerializer::class)
    val value: String? = null,
) {
    val id: String
        get() = name
}

@Serializable
data class CalendarExportTokenResponse(
    val token: String,
)

data class CalendarSubscription(
    val uri: URI,
) {
    enum class EventPreset(val rawValue: String) {
        ALL("all"),
        USER("user"),
        GROUPS("groups"),
        COURSES("courses"),
        CATEGORIES("categories"),
    }

    enum class TimePreset(val rawValue: String) {
        WEEK_NOW("weeknow"),
        WEEK_NEXT("weeknext"),
        MONTH_NOW("monthnow"),
        MONTH_NEXT("monthnext"),
        RECENT_UPCOMING("recentupcoming"),
    }

    val webcalURI: URI
        get() = runCatching {
            URI("webcal", uri.userInfo, uri.host, uri.port, uri.path, uri.query, uri.fragment)
        }.getOrDefault(uri)
}

private object StringishNullableSerializer : KSerializer<String?> {
    override val descriptor: SerialDescriptor =
        PrimitiveSerialDescriptor("StringishNullable", PrimitiveKind.STRING)

    override fun deserialize(decoder: Decoder): String? {
        val jsonDecoder = decoder as? JsonDecoder
            ?: return decoder.decodeString()
        val element = jsonDecoder.decodeJsonElement()

        if (element is JsonNull || element !is JsonPrimitive) {
            return null
        }

        element.intOrNull?.let { return it.toString() }
        element.doubleOrNull?.let { return it.toString() }
        element.booleanOrNull?.let { return if (it) "1" else "0" }
        return element.content
    }

    override fun serialize(encoder: Encoder, value: String?) {
        if (value == null) {
            throw SerializationException("StringishNullableSerializer does not encode null")
        }
        encoder.encodeString(value)
    }
}

private fun JsonElement?.boolishOrNull(): Boolean? {
    if (this == null || this is JsonNull || this !is JsonPrimitive) {
        return null
    }

    booleanOrNull?.let { return it }
    intOrNull?.let { return it != 0 }

    return when (content.lowercase()) {
        "1", "true", "yes" -> true
        "0", "false", "no" -> false
        else -> null
    }
}
