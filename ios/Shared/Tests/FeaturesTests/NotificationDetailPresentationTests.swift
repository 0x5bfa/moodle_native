import Foundation
import MoodleNativeCore
import MoodleNativeFeatures
import MoodleNativeNetworking
import Testing

@testable import MoodleNativeFeatures

struct LmsNotificationDetailPresentationTests {
    @Test func parsesRemindersDueIntoStructuredSections() throws {
        let notification = try decodeNotification(
            """
            {
              "id": 2613999,
              "useridfrom": -10,
              "useridto": 53137,
              "subject": "[Moodle-Reminder] (2026-53356-13_課題) 「必須課題1-6提出先」の提出期限",
              "shortenedsubject": "[Moodle-Reminder] (2026-53356-13_課題) 「必須課題1-6提出先」の提出期限",
              "text": "<p>(2026-53356-13_課題) 「必須課題1-6提出先」の提出期限 [1 day to go]<br>\\nいつ: 2026年 04月 16日(木曜日) 17:00 - JST<br>\\nコース: 53356:プログラミング演習２(B1)<br>\\n活動: 13_課題: 必須課題1-6提出先<br>\\n説明: &lt;p&gt;説明本文&lt;/p&gt;<br>\\n</p>",
              "fullmessage": "(2026-53356-13_課題) 「必須課題1-6提出先」の提出期限 [1 day to go]\\nいつ: 2026年 04月 16日(木曜日) 17:00 - JST\\nコース: 53356:プログラミング演習２(B1)\\n活動: 13_課題: 必須課題1-6提出先\\n説明: <p>説明本文</p>\\n",
              "fullmessageformat": 1,
              "fullmessagehtml": null,
              "smallmessage": "",
              "contexturl": null,
              "contexturlname": "",
              "timecreated": 1775700000,
              "timeread": 0,
              "read": false,
              "deleted": false,
              "iconurl": null,
              "component": "local_reminders",
              "eventtype": "reminders_due",
              "customdata": ""
            }
            """
        )

        let presentation = LmsNotificationItem.lms(from: notification).detailPresentation

        #expect(presentation.sections.count == 2)

        let summary = try #require(presentation.sections.first)
        #expect(summary.title == "概要")
        #expect(
            summary.rows.contains(where: {
                $0.label == "タイトル" && rowText($0) == "(2026-53356-13_課題) 「必須課題1-6提出先」の提出期限"
            }))
        #expect(summary.rows.contains(where: { $0.label == "状態" && rowText($0) == "[1 day to go]" }))
        #expect(
            summary.rows.contains(where: {
                $0.label == "いつ" && rowText($0) == "2026年 04月 16日(木曜日) 17:00 - JST"
            }))
        #expect(
            summary.rows.contains(where: { $0.label == "コース" && rowText($0) == "53356:プログラミング演習２(B1)" }))
        #expect(
            summary.rows.contains(where: { $0.label == "活動" && rowText($0) == "13_課題: 必須課題1-6提出先" }))

        let description = try #require(presentation.sections.last)
        #expect(description.title == "説明")
        #expect(description.rows.count == 1)
        #expect(rowHTML(description.rows[0]) == "<p>説明本文</p>")
    }

    @Test func parsesGenericNotificationsIntoLinkRows() throws {
        let notification = try decodeNotification(
            """
            {
              "id": 2124761,
              "useridfrom": 2,
              "useridto": 99,
              "subject": "あなたは課題「 必須課題1-2提出先 」への提出を送信しました。",
              "shortenedsubject": "あなたは課題「 必須課題1-2提出先 」への提出を送信しました。",
              "text": "2026-53356 -> 13_課題 -> 必須課題1-2提出先\\n---------------------------------------------------------------------\\nあなたは課題「 必須課題1-2提出先 」への提出を送信しました。\\n\\nあなたの課題提出ステータスを確認できます:\\n\\n     https://moodle.example.edu/mod/assign/view.php?id=127579\\n\\n---------------------------------------------------------------------\\n",
              "fullmessage": "2026-53356 -> 13_課題 -> 必須課題1-2提出先\\n---------------------------------------------------------------------\\nあなたは課題「 必須課題1-2提出先 」への提出を送信しました。\\n\\nあなたの課題提出ステータスを確認できます:\\n\\n     https://moodle.example.edu/mod/assign/view.php?id=127579\\n\\n---------------------------------------------------------------------\\n",
              "fullmessageformat": 1,
              "fullmessagehtml": null,
              "smallmessage": "",
              "contexturl": null,
              "contexturlname": "",
              "timecreated": 1775700000,
              "timeread": 0,
              "read": false,
              "deleted": false,
              "iconurl": null,
              "component": "mod_assign",
              "eventtype": "assign_notification",
              "customdata": ""
            }
            """
        )

        let presentation = LmsNotificationItem.lms(from: notification).detailPresentation

        #expect(presentation.sections.count == 1)
        let body = try #require(presentation.sections.first)
        #expect(body.title == "本文")
        #expect(
            body.rows.contains(where: {
                rowLink($0)?.absoluteString == "https://moodle.example.edu/mod/assign/view.php?id=127579"
            }))
    }

    private func decodeNotification(_ json: String) throws -> LmsWebServiceClient.PopupNotification {
        try JSONDecoder().decode(
            LmsWebServiceClient.PopupNotification.self,
            from: Data(json.utf8)
        )
    }

    private func rowText(_ row: LmsNotificationDetailPresentation.Section.Row) -> String? {
        if case .text(let text) = row.content {
            return text
        }

        return nil
    }

    private func rowHTML(_ row: LmsNotificationDetailPresentation.Section.Row) -> String? {
        if case .html(let html) = row.content {
            return html
        }

        return nil
    }

    private func rowLink(_ row: LmsNotificationDetailPresentation.Section.Row) -> URL? {
        if case .link(_, let url) = row.content {
            return url
        }

        return nil
    }
}
