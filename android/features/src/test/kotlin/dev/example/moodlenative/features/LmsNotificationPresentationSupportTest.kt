package dev.example.moodlenative.features

import dev.example.moodlenative.core.LmsNotificationItem
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LmsNotificationPresentationSupportTest {
    @Test
    fun htmlDocumentWrapsHTMLBodyWhenMarkupExists() {
        val notification = notification(
            plainBody = "本文",
            htmlBody = "<p><strong>本文</strong></p>",
            component = "mod_forum",
            eventType = "posts",
        )

        assertEquals("本文", notification.preview)
        assertEquals("本文", notification.bodyText)
        assertTrue(notification.htmlDocument?.contains("<strong>本文</strong>") == true)
        assertTrue(notification.metadataItems.contains("component" to "mod_forum"))
    }

    @Test
    fun bodyTextFallsBackToPlainPreviewWhenHTMLBodyHasNoMarkup() {
        val notification = notification(
            preview = "プレーン通知",
            plainBody = "プレーン通知",
            htmlBody = "プレーン通知",
            isUnread = false,
        )

        assertNull(notification.htmlDocument)
        assertEquals("プレーン通知", notification.bodyText)
        assertEquals(false, notification.isUnread)
    }

    @Test
    fun emptyBodyFallsBackToPreview() {
        val notification = notification(
            preview = "通知本文を表示できます。",
            plainBody = null,
            fullMessage = null,
            htmlBody = null,
        )

        assertEquals("LMS通知", notification.title)
        assertEquals("通知本文を表示できます。", notification.preview)
        assertEquals("通知本文を表示できます。", notification.bodyText)
    }

    private fun notification(
        preview: String = "本文",
        plainBody: String? = "本文",
        fullMessage: String? = plainBody,
        htmlBody: String? = null,
        isUnread: Boolean = true,
        component: String? = null,
        eventType: String? = null,
    ): LmsNotificationItem =
        LmsNotificationItem(
            id = "lms-991",
            lmsNotificationID = 991,
            source = "Moodle",
            title = "LMS通知",
            preview = preview,
            plainBody = plainBody,
            fullMessage = fullMessage,
            htmlBody = htmlBody,
            receivedAt = Instant.ofEpochSecond(1_775_700_000),
            isUnread = isUnread,
            isImportant = false,
            externalURL = null,
            component = component,
            eventType = eventType,
            contextName = null,
        )
}
