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
data class ForumDiscussion(
    @SerialName("id")
    val rootPostID: Int,
    @SerialName("discussion")
    val discussionID: Int,
    val name: String = "",
    val subject: String = "",
    val message: String? = null,
    @SerialName("userfullname")
    val userFullName: String = "",
    @SerialName("numreplies")
    val numberOfReplies: Int = 0,
    @SerialName("numunread")
    val numberOfUnreadPosts: Int = 0,
    @SerialName("pinned")
    @Serializable(with = BoolishBooleanSerializer::class)
    val isPinned: Boolean = false,
    @SerialName("locked")
    @Serializable(with = BoolishBooleanSerializer::class)
    val isLocked: Boolean = false,
    @SerialName("modified")
    val modifiedTimestamp: Int = 0,
    @SerialName("canreply")
    @Serializable(with = BoolishBooleanSerializer::class)
    val canReply: Boolean = false,
) {
    val id: Int
        get() = discussionID
}

@Serializable
data class ForumDiscussionsResponse(
    val discussions: List<ForumDiscussion> = emptyList(),
)

@Serializable
data class ForumPostAuthorURLs(
    val profile: String? = null,
    @SerialName("profileimage")
    val profileImage: String? = null,
)

@Serializable
data class ForumPostAuthor(
    val id: Int = 0,
    @SerialName("fullname")
    val fullName: String = "",
    @SerialName("isdeleted")
    @Serializable(with = BoolishBooleanSerializer::class)
    val isDeleted: Boolean = false,
    val urls: ForumPostAuthorURLs = ForumPostAuthorURLs(),
)

@Serializable
data class ForumPostURLs(
    val view: String? = null,
    @SerialName("viewisolated")
    val viewIsolated: String? = null,
    val discuss: String? = null,
)

@Serializable
data class ForumPostAttachment(
    @SerialName("filename")
    val fileName: String? = null,
    @SerialName("filepath")
    val filePath: String? = null,
    @SerialName("fileurl")
    val rawFileURL: String? = null,
    val url: String? = null,
    @SerialName("mimetype")
    val mimeType: String? = null,
) {
    val fileURL: String?
        get() = rawFileURL ?: url

    val id: String
        get() = listOfNotNull(fileName, filePath, fileURL, mimeType).joinToString("|")

    fun withFileURL(fileURL: String?): ForumPostAttachment =
        copy(rawFileURL = fileURL, url = null)
}

@Serializable
data class ForumPost(
    val id: Int,
    @SerialName("discussionid")
    val discussionID: Int = 0,
    val subject: String = "",
    @SerialName("replysubject")
    val replySubject: String? = null,
    val message: String? = null,
    @SerialName("timecreated")
    val timeCreated: Int = 0,
    @SerialName("timemodified")
    val timeModified: Int = 0,
    @Serializable(with = BoolishBooleanSerializer::class)
    val unread: Boolean = false,
    @SerialName("hasparent")
    @Serializable(with = BoolishBooleanSerializer::class)
    val hasParent: Boolean = false,
    @SerialName("parentid")
    val parentID: Int? = null,
    @SerialName("isdeleted")
    @Serializable(with = BoolishBooleanSerializer::class)
    val isDeleted: Boolean = false,
    @SerialName("isprivatereply")
    @Serializable(with = BoolishBooleanSerializer::class)
    val isPrivateReply: Boolean = false,
    val author: ForumPostAuthor = ForumPostAuthor(),
    val urls: ForumPostURLs = ForumPostURLs(),
    val attachments: List<ForumPostAttachment> = emptyList(),
)

@Serializable
data class DiscussionPostsResponse(
    val posts: List<ForumPost> = emptyList(),
)

private object BoolishBooleanSerializer : KSerializer<Boolean> {
    override val descriptor: SerialDescriptor =
        PrimitiveSerialDescriptor("BoolishBoolean", PrimitiveKind.BOOLEAN)

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
