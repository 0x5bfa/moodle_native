package dev.example.moodlenative.storage

import dev.example.moodlenative.core.LmsAuthenticationSession
import java.time.Instant
import kotlinx.serialization.KSerializer
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerializationException
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.Json

data class AppSessionSnapshot(
    val lmsSession: LmsAuthenticationSession? = null,
) {
    val hasLmsSession: Boolean
        get() = lmsSession != null
}

interface AppSessionStore {
    fun readSnapshot(): AppSessionSnapshot
    fun writeSnapshot(snapshot: AppSessionSnapshot)
    fun clear()

    fun updateLmsSession(session: LmsAuthenticationSession) {
        writeSnapshot(readSnapshot().copy(lmsSession = session))
    }

    fun clearLmsSession() {
        writeSnapshot(readSnapshot().copy(lmsSession = null))
    }
}

object AppSessionSnapshotCodec {
    private val json = Json {
        ignoreUnknownKeys = true
        explicitNulls = false
    }

    fun encode(snapshot: AppSessionSnapshot): String =
        json.encodeToString(
            StoredAppSessionSnapshot.serializer(),
            StoredAppSessionSnapshot(
                lmsSession = snapshot.lmsSession?.let(::StoredLmsAuthenticationSession),
            ),
        )

    fun decode(rawValue: String): AppSessionSnapshot =
        try {
            val stored = json.decodeFromString(StoredAppSessionSnapshot.serializer(), rawValue)
            AppSessionSnapshot(
                lmsSession = stored.lmsSession?.toLmsAuthenticationSession(),
            )
        } catch (error: SerializationException) {
            throw AppSessionStoreError.InvalidStoredSnapshot(error)
        } catch (error: IllegalArgumentException) {
            throw AppSessionStoreError.InvalidStoredSnapshot(error)
        }
}

sealed class AppSessionStoreError(
    override val message: String,
    override val cause: Throwable? = null,
) : Exception(message, cause) {
    data class InvalidStoredSnapshot(
        val parsingCause: Throwable,
    ) : AppSessionStoreError("保存済みのセッションを読み取れませんでした。", parsingCause)

    data class CryptoFailure(
        val cryptoCause: Throwable,
    ) : AppSessionStoreError("保存済みのセッションを復号できませんでした。", cryptoCause)
}

@Serializable
private data class StoredAppSessionSnapshot(
    val version: Int = 1,
    @SerialName("lms_session")
    val lmsSession: StoredLmsAuthenticationSession? = null,
)

@Serializable
private data class StoredLmsAuthenticationSession(
    @SerialName("site_url")
    val siteURL: String,
    val token: String,
    @SerialName("private_token")
    val privateToken: String? = null,
    @SerialName("raw_callback_url")
    val rawCallbackURL: String,
    @Serializable(with = InstantAsStringSerializer::class)
    @SerialName("authenticated_at")
    val authenticatedAt: Instant,
    @SerialName("user_id")
    val userID: Int? = null,
) {
    constructor(session: LmsAuthenticationSession) : this(
        siteURL = session.siteURL,
        token = session.token,
        privateToken = session.privateToken,
        rawCallbackURL = session.rawCallbackURL,
        authenticatedAt = session.authenticatedAt,
        userID = session.userID,
    )

    fun toLmsAuthenticationSession(): LmsAuthenticationSession =
        LmsAuthenticationSession(
            siteURL = siteURL,
            token = token,
            privateToken = privateToken,
            rawCallbackURL = rawCallbackURL,
            authenticatedAt = authenticatedAt,
            userID = userID,
        )
}

private object InstantAsStringSerializer : KSerializer<Instant> {
    override val descriptor: SerialDescriptor =
        PrimitiveSerialDescriptor("InstantAsString", PrimitiveKind.STRING)

    override fun deserialize(decoder: Decoder): Instant =
        Instant.parse(decoder.decodeString())

    override fun serialize(encoder: Encoder, value: Instant) {
        encoder.encodeString(value.toString())
    }
}
