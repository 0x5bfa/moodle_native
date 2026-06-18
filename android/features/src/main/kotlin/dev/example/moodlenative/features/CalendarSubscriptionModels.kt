package dev.example.moodlenative.features

import java.net.URI

data class LmsCalendarSubscription(
    val uri: URI,
) {
    val webcalURI: URI
        get() = runCatching {
            URI("webcal", uri.userInfo, uri.host, uri.port, uri.path, uri.query, uri.fragment)
        }.getOrDefault(uri)
}
