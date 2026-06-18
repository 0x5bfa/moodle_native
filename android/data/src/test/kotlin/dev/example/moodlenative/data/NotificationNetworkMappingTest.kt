package dev.example.moodlenative.data

import dev.example.moodlenative.features.bodyText
import dev.example.moodlenative.features.htmlDocument
import dev.example.moodlenative.features.metadataItems
import dev.example.moodlenative.networking.PopupNotification
import dev.example.moodlenative.networking.PopupNotificationsResponse
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class NotificationNetworkMappingTest {
    @Test
    fun popupNotificationMapsToLmsNotificationItem() {
        val notification = PopupNotification(
            id = 991,
            userIDFrom = 2,
            userIDTo = 99,
            subject = "フォーラム通知",
            shortenedSubject = "フォーラム通知",
            text = "本文",
            fullMessage = "本文",
            fullMessageFormat = 1,
            fullMessageHTML = "<p><strong>本文</strong></p>",
            smallMessage = "本文",
            contextURL = "https://lms.example.test/mod/forum/view.php?id=1",
            contextURLName = "授業ページ",
            timeCreated = 1_775_700_000,
            timeRead = 0,
            read = false,
            deleted = false,
            component = "mod_forum",
            eventType = "posts",
            customData = "",
        )

        val item = notification.toLmsNotificationItem()

        assertEquals("lms-991", item.id)
        assertEquals(991, item.lmsNotificationID)
        assertEquals("フォーラム通知", item.title)
        assertEquals("本文", item.preview)
        assertEquals("本文", item.bodyText)
        assertTrue(item.htmlDocument?.contains("<strong>本文</strong>") == true)
        assertTrue(item.metadataItems.contains("component" to "mod_forum"))
        assertEquals("https://lms.example.test/mod/forum/view.php?id=1", item.externalURL.toString())
        assertEquals(true, item.isUnread)
    }

    @Test
    fun popupNotificationFallsBackToPlainTextWhenHTMLFieldHasNoMarkup() {
        val notification = PopupNotification(
            id = 992,
            userIDFrom = 2,
            userIDTo = 99,
            subject = "課題通知",
            shortenedSubject = "",
            text = "プレーン通知",
            fullMessage = "プレーン通知",
            fullMessageFormat = 0,
            fullMessageHTML = "プレーン通知",
            smallMessage = "",
            contextURL = null,
            contextURLName = "",
            timeCreated = 1_775_700_000,
            timeRead = 1_775_700_300,
            read = true,
            deleted = false,
            component = "mod_assign",
            eventType = "submission",
            customData = "",
        )

        val item = notification.toLmsNotificationItem()

        assertNull(item.htmlDocument)
        assertEquals("プレーン通知", item.bodyText)
        assertEquals(false, item.isUnread)
    }

    @Test
    fun popupNotificationEmptyContentFallsBackToDefaultPreviewAndTitle() {
        val notification = PopupNotification(
            id = 993,
            subject = " ",
            shortenedSubject = null,
            text = null,
            fullMessage = null,
            fullMessageHTML = null,
            smallMessage = null,
            contextURLName = null,
            timeCreated = 1_775_700_000,
        )

        val item = notification.toLmsNotificationItem()

        assertEquals("LMS通知", item.title)
        assertEquals("通知本文を表示できます。", item.preview)
        assertEquals("通知本文を表示できます。", item.bodyText)
    }

    @Test
    fun popupNotificationsResponseMapsUnreadCount() {
        val snapshot = PopupNotificationsResponse(
            notifications = listOf(
                PopupNotification(id = 1, subject = "A", timeCreated = 1_775_700_000),
            ),
            unreadCount = 4,
        ).toLmsNotificationSnapshot()

        assertEquals(1, snapshot.notifications.size)
        assertEquals(4, snapshot.unreadCount)
    }
}
