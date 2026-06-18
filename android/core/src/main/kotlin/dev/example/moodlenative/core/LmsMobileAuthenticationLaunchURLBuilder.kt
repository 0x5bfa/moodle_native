package dev.example.moodlenative.core

import java.net.URI
import java.net.URLEncoder
import java.util.UUID

object LmsMobileAuthenticationLaunchURLBuilder {
    fun build(
        siteURL: URI = URI("https://moodle.example.edu"),
        callbackScheme: String = "moodlemobile",
        passport: String = UUID.randomUUID().toString().replace("-", "").lowercase(),
    ): URI {
        val normalizedSiteURL = normalizeSiteURL(siteURL)
        val query = listOf(
            "service" to "moodle_mobile_app",
            "passport" to passport,
            "urlscheme" to callbackScheme,
            "confirmed" to "1",
        ).joinToString("&") { (name, value) ->
            "${name.formEncoded()}=${value.formEncoded()}"
        }

        return runCatching {
            URI("$normalizedSiteURL/admin/tool/mobile/launch.php?$query")
        }.getOrElse {
            throw IllegalArgumentException("Moodle のログイン URL を作成できませんでした。", it)
        }
    }

    private fun normalizeSiteURL(siteURL: URI): String {
        if (siteURL.scheme.isNullOrBlank() || siteURL.host.isNullOrBlank()) {
            throw IllegalArgumentException("Moodle のサイト URL が正しくありません。")
        }

        return siteURL.toString().trimEnd('/')
    }

    private fun String.formEncoded(): String =
        URLEncoder.encode(this, Charsets.UTF_8)
}
