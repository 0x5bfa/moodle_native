import Foundation
import Testing

@testable import MoodleNativeCore

struct LmsAuthenticationCallbackParserTests {
    @Test func parseDirectCustomURL() throws {
        let callbackURL = try #require(
            URL(
                string:
                    "moodleapp://alice@moodle.example.edu/moodle?token=ws-token-123&privatetoken=private-456")
        )
        let fallbackSiteURL = try #require(URL(string: "https://moodle.example.edu"))
        let authenticatedAt = Date(timeIntervalSince1970: 1_744_506_000)

        let session = try LmsAuthenticationCallbackParser.parse(
            callbackURL: callbackURL,
            fallbackSiteURL: fallbackSiteURL,
            authenticatedAt: authenticatedAt
        )

        #expect(session.siteURL == "https://moodle.example.edu/moodle")
        #expect(session.token == "ws-token-123")
        #expect(session.privateToken == "private-456")
        #expect(
            session.rawCallbackURL
                == "moodleapp://alice@moodle.example.edu/moodle?token=ws-token-123&privatetoken=private-456"
        )
        #expect(session.authenticatedAt == authenticatedAt)
    }

    @Test func parseLegacyCustomURL() throws {
        let callbackURL = try #require(
            URL(string: "moodleapp://token=ZHVtbXlzaWduYXR1cmU6Ojp3cy10b2tlbi0xMjM6Ojpwcml2YXRlLTQ1Ng=="))
        let fallbackSiteURL = try #require(URL(string: "https://moodle.example.edu"))
        let authenticatedAt = Date(timeIntervalSince1970: 1_744_506_000)

        let session = try LmsAuthenticationCallbackParser.parse(
            callbackURL: callbackURL,
            fallbackSiteURL: fallbackSiteURL,
            authenticatedAt: authenticatedAt
        )

        #expect(session.siteURL == "https://moodle.example.edu")
        #expect(session.token == "ws-token-123")
        #expect(session.privateToken == "private-456")
        #expect(
            session.rawCallbackURL
                == "moodleapp://token=ZHVtbXlzaWduYXR1cmU6Ojp3cy10b2tlbi0xMjM6Ojpwcml2YXRlLTQ1Ng=="
        )
        #expect(session.authenticatedAt == authenticatedAt)
    }
}
