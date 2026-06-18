package dev.example.moodlenative.networking

import kotlinx.serialization.KSerializer
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.JsonDecoder
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.intOrNull

@Serializable
data class PopupNotification(
    val id: Int,
    @SerialName("useridfrom")
    val userIDFrom: Int? = null,
    @SerialName("useridto")
    val userIDTo: Int? = null,
    val subject: String,
    @SerialName("shortenedsubject")
    val shortenedSubject: String? = null,
    val text: String? = null,
    @SerialName("fullmessage")
    val fullMessage: String? = null,
    @SerialName("fullmessageformat")
    val fullMessageFormat: Int? = null,
    @SerialName("fullmessagehtml")
    val fullMessageHTML: String? = null,
    @SerialName("smallmessage")
    val smallMessage: String? = null,
    @SerialName("contexturl")
    val contextURL: String? = null,
    @SerialName("contexturlname")
    val contextURLName: String? = null,
    @SerialName("timecreated")
    val timeCreated: Int,
    @SerialName("timeread")
    val timeRead: Int? = null,
    @Serializable(with = NotificationBoolishBooleanSerializer::class)
    val read: Boolean = false,
    @Serializable(with = NotificationBoolishBooleanSerializer::class)
    val deleted: Boolean = false,
    @SerialName("iconurl")
    val iconURL: String? = null,
    val component: String? = null,
    @SerialName("eventtype")
    val eventType: String? = null,
    @SerialName("customdata")
    val customData: String? = null,
)

@Serializable
data class PopupNotificationsResponse(
    val notifications: List<PopupNotification> = emptyList(),
    @SerialName("unreadcount")
    val unreadCount: Int? = null,
)

private object NotificationBoolishBooleanSerializer : KSerializer<Boolean> {
    override val descriptor: SerialDescriptor =
        PrimitiveSerialDescriptor("NotificationBoolishBoolean", PrimitiveKind.BOOLEAN)

    override fun deserialize(decoder: Decoder): Boolean {
        val jsonDecoder = decoder as? JsonDecoder
        if (jsonDecoder == null) {
            return decoder.decodeBoolean()
        }

        val element = jsonDecoder.decodeJsonElement()
        if (element is JsonNull || element !is JsonPrimitive) {
            return false
        }

        element.booleanOrNull?.let { return it }
        element.intOrNull?.let { return it != 0 }

        return when (element.content.lowercase()) {
            "1", "true", "yes" -> true
            "0", "false", "no" -> false
            else -> false
        }
    }

    override fun serialize(encoder: Encoder, value: Boolean) {
        encoder.encodeBoolean(value)
    }
}
