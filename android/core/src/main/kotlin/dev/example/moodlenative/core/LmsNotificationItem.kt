package dev.example.moodlenative.core

import java.net.URI
import java.time.Instant

data class LmsNotificationItem(
    val id: String,
    val lmsNotificationID: Int?,
    val source: String,
    val title: String,
    val preview: String,
    val plainBody: String?,
    val fullMessage: String?,
    val htmlBody: String?,
    val receivedAt: Instant,
    val isUnread: Boolean,
    val isImportant: Boolean,
    val externalURL: URI?,
    val component: String?,
    val eventType: String?,
    val contextName: String?,
)
