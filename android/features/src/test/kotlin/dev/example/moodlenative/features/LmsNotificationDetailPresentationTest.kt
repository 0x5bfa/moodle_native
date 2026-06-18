package dev.example.moodlenative.features

import dev.example.moodlenative.core.LmsNotificationItem
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class LmsNotificationDetailPresentationTest {
    @Test
    fun parsesRemindersDueIntoStructuredSections() {
        val notification = notification(
            id = 2_613_999,
            title = "[Moodle-Reminder] (2026-53356-13_課題) 「必須課題1-6提出先」の提出期限",
            fullMessage = """
                (2026-53356-13_課題) 「必須課題1-6提出先」の提出期限 [1 day to go]
                いつ: 2026年 04月 16日(木曜日) 17:00 - JST
                コース: 53356:プログラミング演習２(B1)
                活動: 13_課題: 必須課題1-6提出先
                説明: <p>説明本文</p>
            """.trimIndent(),
            component = "local_reminders",
            eventType = "reminders_due",
        )

        val presentation = notification.detailPresentation

        assertEquals(2, presentation.sections.size)

        val summary = presentation.sections.first()
        assertEquals("概要", summary.title)
        assertTrue(
            summary.rows.any {
                it.label == "タイトル" &&
                    rowText(it) == "(2026-53356-13_課題) 「必須課題1-6提出先」の提出期限"
            },
        )
        assertTrue(summary.rows.any { it.label == "状態" && rowText(it) == "[1 day to go]" })
        assertTrue(
            summary.rows.any {
                it.label == "いつ" && rowText(it) == "2026年 04月 16日(木曜日) 17:00 - JST"
            },
        )
        assertTrue(
            summary.rows.any {
                it.label == "コース" && rowText(it) == "53356:プログラミング演習２(B1)"
            },
        )
        assertTrue(
            summary.rows.any {
                it.label == "活動" && rowText(it) == "13_課題: 必須課題1-6提出先"
            },
        )

        val description = presentation.sections.last()
        assertEquals("説明", description.title)
        assertEquals(1, description.rows.size)
        assertEquals("<p>説明本文</p>", rowHTML(description.rows[0]))
    }

    @Test
    fun parsesGenericNotificationsIntoLinkRows() {
        val notification = notification(
            id = 2_124_761,
            title = "あなたは課題「 必須課題1-2提出先 」への提出を送信しました。",
            fullMessage = genericMessage,
            component = "mod_assign",
            eventType = "assign_notification",
        )

        val presentation = notification.detailPresentation

        assertEquals(1, presentation.sections.size)
        val body = presentation.sections.first()
        assertEquals("本文", body.title)
        assertTrue(
            body.rows.any {
                rowLink(it) == "https://moodle.example.edu/mod/assign/view.php?id=127579"
            },
        )
    }

    private fun rowText(row: LmsNotificationDetailPresentation.Section.Row): String? =
        (row.content as? LmsNotificationDetailPresentation.Section.Row.Content.Text)?.text

    private fun rowHTML(row: LmsNotificationDetailPresentation.Section.Row): String? =
        (row.content as? LmsNotificationDetailPresentation.Section.Row.Content.Html)?.html

    private fun rowLink(row: LmsNotificationDetailPresentation.Section.Row): String? =
        (row.content as? LmsNotificationDetailPresentation.Section.Row.Content.Link)?.uri?.toString()

    private companion object {
        fun notification(
            id: Int,
            title: String,
            fullMessage: String,
            component: String,
            eventType: String,
        ): LmsNotificationItem =
            LmsNotificationItem(
                id = "lms-$id",
                lmsNotificationID = id,
                source = "Moodle",
                title = title,
                preview = fullMessage,
                plainBody = fullMessage,
                fullMessage = fullMessage,
                htmlBody = null,
                receivedAt = Instant.ofEpochSecond(1_775_700_000),
                isUnread = true,
                isImportant = false,
                externalURL = null,
                component = component,
                eventType = eventType,
                contextName = null,
            )

        val genericMessage = """
            2026-53356 -> 13_課題 -> 必須課題1-2提出先
            ---------------------------------------------------------------------
            あなたは課題「 必須課題1-2提出先 」への提出を送信しました。

            あなたの課題提出ステータスを確認できます:

                 https://moodle.example.edu/mod/assign/view.php?id=127579

            ---------------------------------------------------------------------
        """.trimIndent()
    }
}
