package dev.example.moodlenative.core

import java.io.ByteArrayOutputStream
import java.net.URI
import java.time.Instant
import java.util.Base64

enum class LmsAuthenticationCallbackError(val errorDescription: String) {
    MISSING_CALLBACK_URL("Moodle のコールバック URL を受け取れませんでした。"),
    INVALID_CALLBACK_URL("Moodle のコールバック URL を解析できませんでした。"),
    MISSING_TOKEN("Moodle のログイン結果に token が含まれていませんでした。"),
    INVALID_LEGACY_TOKEN("Moodle の旧形式トークンを復元できませんでした。"),
}

class LmsAuthenticationCallbackException(
    val reason: LmsAuthenticationCallbackError,
) : IllegalArgumentException(reason.errorDescription)

data class LmsAuthenticationSession(
    val siteURL: String,
    val token: String,
    val privateToken: String?,
    val rawCallbackURL: String,
    val authenticatedAt: Instant,
    val userID: Int? = null,
) {
    fun withUserID(userID: Int): LmsAuthenticationSession = copy(userID = userID)
}

object LmsAuthenticationCallbackParser {
    fun parse(
        callbackURL: URI,
        fallbackSiteURL: URI,
        authenticatedAt: Instant = Instant.now(),
    ): LmsAuthenticationSession {
        val rawCustomURL = trimCustomURL(callbackURL.toString())
        if (rawCustomURL.isEmpty()) {
            throw LmsAuthenticationCallbackException(LmsAuthenticationCallbackError.MISSING_CALLBACK_URL)
        }

        return if (rawCustomURL.contains("://token=")) {
            parseLegacy(rawCustomURL, fallbackSiteURL, authenticatedAt)
        } else {
            parseDirect(callbackURL, rawCustomURL, fallbackSiteURL, authenticatedAt)
        }
    }

    private fun parseLegacy(
        rawCustomURL: String,
        fallbackSiteURL: URI,
        authenticatedAt: Instant,
    ): LmsAuthenticationSession {
        val parts = rawCustomURL.split("://token=", limit = 2)
        if (parts.size != 2 || parts[1].isEmpty()) {
            throw LmsAuthenticationCallbackException(LmsAuthenticationCallbackError.INVALID_LEGACY_TOKEN)
        }

        var normalized = percentDecode(parts[1])
            .replace("-", "+")
            .replace("_", "/")

        val remainder = normalized.length % 4
        if (remainder != 0) {
            normalized += "=".repeat(4 - remainder)
        }

        val decodedPayload = runCatching {
            String(Base64.getDecoder().decode(normalized), Charsets.UTF_8)
        }.getOrElse {
            throw LmsAuthenticationCallbackException(LmsAuthenticationCallbackError.INVALID_LEGACY_TOKEN)
        }

        val payloadParts = decodedPayload.split(":::")
        if (payloadParts.size < 2) {
            throw LmsAuthenticationCallbackException(LmsAuthenticationCallbackError.INVALID_LEGACY_TOKEN)
        }

        val token = payloadParts[1].trim()
        if (token.isEmpty()) {
            throw LmsAuthenticationCallbackException(LmsAuthenticationCallbackError.INVALID_LEGACY_TOKEN)
        }

        return LmsAuthenticationSession(
            siteURL = normalizeSiteURL(fallbackSiteURL.toString()),
            token = token,
            privateToken = payloadParts.getOrNull(2).optionalTrimmed(),
            rawCallbackURL = rawCustomURL,
            authenticatedAt = authenticatedAt,
        )
    }

    private fun parseDirect(
        callbackURL: URI,
        rawCustomURL: String,
        fallbackSiteURL: URI,
        authenticatedAt: Instant,
    ): LmsAuthenticationSession {
        val token = firstNonEmptyQueryValue(callbackURL.rawQuery, listOf("token"))
            ?: throw LmsAuthenticationCallbackException(LmsAuthenticationCallbackError.MISSING_TOKEN)
        val privateToken = firstNonEmptyQueryValue(callbackURL.rawQuery, listOf("privatetoken", "privateToken"))

        return LmsAuthenticationSession(
            siteURL = deriveSiteURL(callbackURL, fallbackSiteURL),
            token = token,
            privateToken = privateToken,
            rawCallbackURL = rawCustomURL,
            authenticatedAt = authenticatedAt,
        )
    }

    private fun deriveSiteURL(callbackURL: URI, fallbackSiteURL: URI): String {
        val scheme = fallbackSiteURL.scheme.optionalTrimmed()
        val host = callbackURL.host.optionalTrimmed()
        if (scheme == null || host == null) {
            throw LmsAuthenticationCallbackException(LmsAuthenticationCallbackError.INVALID_CALLBACK_URL)
        }

        val port = if (callbackURL.port >= 0) ":${callbackURL.port}" else ""
        val trimmedPath = callbackURL.path.orEmpty().trim('/')
        val path = if (trimmedPath.isEmpty()) "" else "/$trimmedPath"
        return normalizeSiteURL("$scheme://$host$port$path")
    }

    private fun firstNonEmptyQueryValue(rawQuery: String?, names: List<String>): String? {
        if (rawQuery.isNullOrEmpty()) {
            return null
        }

        val items = rawQuery.split("&").map { item ->
            val separator = item.indexOf('=')
            if (separator < 0) {
                percentDecode(item) to null
            } else {
                percentDecode(item.substring(0, separator)) to percentDecode(item.substring(separator + 1))
            }
        }

        for (name in names) {
            val value = items.firstOrNull { it.first == name }?.second.optionalTrimmed()
            if (value != null) {
                return value
            }
        }

        return null
    }

    private fun normalizeSiteURL(value: String): String = value.trim().trimEnd('/')

    private fun trimCustomURL(rawValue: String): String = rawValue.trim().trimEnd('/', '#')

    private fun percentDecode(value: String): String {
        val bytes = ByteArrayOutputStream(value.length)
        var index = 0
        while (index < value.length) {
            val char = value[index]
            if (char == '%' && index + 2 < value.length) {
                val hex = value.substring(index + 1, index + 3).toIntOrNull(16)
                if (hex != null) {
                    bytes.write(hex)
                    index += 3
                    continue
                }
            }

            bytes.write(char.toString().toByteArray(Charsets.UTF_8))
            index += 1
        }

        return bytes.toByteArray().toString(Charsets.UTF_8)
    }
}
