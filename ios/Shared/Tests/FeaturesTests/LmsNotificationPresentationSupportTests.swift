import Foundation
import MoodleNativeCore
import MoodleNativeFeatures
import MoodleNativeNetworking
import Testing

@testable import MoodleNativeFeatures

struct LmsNotificationPresentationSupportTests {
    @Test func prefersHTMLBodyWhenMarkupExists() throws {
        let notification = try decodeNotification(
            """
            {
              "id": 991,
              "useridfrom": 2,
              "useridto": 99,
              "subject": "フォーラム通知",
              "shortenedsubject": "フォーラム通知",
              "text": "本文",
              "fullmessage": "本文",
              "fullmessageformat": 1,
              "fullmessagehtml": "<p><strong>本文</strong></p>",
              "smallmessage": "本文",
              "contexturl": "https://lms.example.test/mod/forum/view.php?id=1",
              "contexturlname": "授業ページ",
              "timecreated": 1775700000,
              "timeread": 0,
              "read": false,
              "deleted": false,
              "iconurl": null,
              "component": "mod_forum",
              "eventtype": "posts",
              "customdata": ""
            }
            """
        )

        let presentation = LmsNotificationItem.lms(from: notification)

        #expect(presentation.preview == "本文")
        #expect(presentation.bodyText == "本文")
        #expect(presentation.htmlDocument?.contains("<strong>本文</strong>") == true)
        #expect(
            presentation.metadataItems.contains(where: { $0.0 == "component" && $0.1 == "mod_forum" }))
    }

    @Test func fallsBackToPlainTextWhenHTMLFieldHasNoMarkup() throws {
        let notification = try decodeNotification(
            """
            {
              "id": 992,
              "useridfrom": 2,
              "useridto": 99,
              "subject": "課題通知",
              "shortenedsubject": "",
              "text": "プレーン通知",
              "fullmessage": "プレーン通知",
              "fullmessageformat": 0,
              "fullmessagehtml": "プレーン通知",
              "smallmessage": "",
              "contexturl": null,
              "contexturlname": "",
              "timecreated": 1775700000,
              "timeread": 1775700300,
              "read": true,
              "deleted": false,
              "iconurl": null,
              "component": "mod_assign",
              "eventtype": "submission",
              "customdata": ""
            }
            """
        )

        let presentation = LmsNotificationItem.lms(from: notification)

        #expect(presentation.htmlDocument == nil)
        #expect(presentation.bodyText == "プレーン通知")
        #expect(presentation.isUnread == false)
    }
}

private func decodeNotification(_ json: String) throws -> LmsWebServiceClient.PopupNotification {
    try JSONDecoder().decode(
        LmsWebServiceClient.PopupNotification.self,
        from: Data(json.utf8)
    )
}
