package dev.example.moodlenative.data

import dev.example.moodlenative.core.LmsHTMLTextFormatter
import dev.example.moodlenative.core.LmsNotificationItem
import dev.example.moodlenative.networking.PopupNotification
import dev.example.moodlenative.networking.PopupNotificationsResponse
import java.net.URI
import java.time.Instant

internal data class LmsNotificationSnapshot(
    val notifications: List<LmsNotificationItem> = emptyList(),
    val unreadCount: Int? = null,
)

internal fun PopupNotificationsResponse.toLmsNotificationSnapshot(): LmsNotificationSnapshot =
    LmsNotificationSnapshot(
        notifications = notifications.map { notification -> notification.toLmsNotificationItem() },
        unreadCount = unreadCount,
    )

internal fun PopupNotification.toLmsNotificationItem(): LmsNotificationItem {
    val plainBody = listOf(fullMessageHTML, fullMessage, text, smallMessage)
        .mapNotNull { LmsHTMLTextFormatter.plainText(it) }
        .firstOrNull()

    val preview = listOf(
        LmsHTMLTextFormatter.plainText(smallMessage),
        plainBody,
    )
        .mapNotNull { it?.trim() }
        .firstOrNull { it.isNotEmpty() }
        ?: "通知本文を表示できます。"

    val title = listOf(subject, shortenedSubject, contextURLName)
        .mapNotNull(::trimmedValue)
        .firstOrNull()
        ?: "LMS通知"

    return LmsNotificationItem(
        id = "lms-$id",
        lmsNotificationID = id,
        source = "Moodle",
        title = title,
        preview = preview,
        plainBody = plainBody,
        fullMessage = fullMessage,
        htmlBody = sanitizedHTML(fullMessageHTML),
        receivedAt = Instant.ofEpochSecond(timeCreated.toLong()),
        isUnread = !read,
        isImportant = false,
        externalURL = contextURL?.let { runCatching { URI(it) }.getOrNull() },
        component = component,
        eventType = eventType,
        contextName = trimmedValue(contextURLName),
    )
}

private fun sanitizedHTML(value: String?): String? {
    val trimmed = trimmedValue(value) ?: return null
    return if (Regex("<[^>]+>").containsMatchIn(trimmed)) trimmed else null
}

private fun trimmedValue(value: String?): String? =
    value?.trim()?.ifEmpty { null }
