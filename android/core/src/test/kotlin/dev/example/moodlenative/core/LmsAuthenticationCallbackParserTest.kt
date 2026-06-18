package dev.example.moodlenative.core

import java.net.URI
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Test

class LmsAuthenticationCallbackParserTest {
    @Test
    fun parseDirectCustomURL() {
        val callbackURL = URI.create(
            "moodleapp://alice@moodle.example.edu/moodle?token=ws-token-123&privatetoken=private-456"
        )
        val fallbackSiteURL = URI.create("https://moodle.example.edu")
        val authenticatedAt = Instant.ofEpochSecond(1_744_506_000)

        val session = LmsAuthenticationCallbackParser.parse(
            callbackURL = callbackURL,
            fallbackSiteURL = fallbackSiteURL,
            authenticatedAt = authenticatedAt,
        )

        assertEquals("https://moodle.example.edu/moodle", session.siteURL)
        assertEquals("ws-token-123", session.token)
        assertEquals("private-456", session.privateToken)
        assertEquals(
            "moodleapp://alice@moodle.example.edu/moodle?token=ws-token-123&privatetoken=private-456",
            session.rawCallbackURL,
        )
        assertEquals(authenticatedAt, session.authenticatedAt)
    }

    @Test
    fun parseLegacyCustomURL() {
        val callbackURL = URI.create(
            "moodleapp://token=ZHVtbXlzaWduYXR1cmU6Ojp3cy10b2tlbi0xMjM6Ojpwcml2YXRlLTQ1Ng=="
        )
        val fallbackSiteURL = URI.create("https://moodle.example.edu")
        val authenticatedAt = Instant.ofEpochSecond(1_744_506_000)

        val session = LmsAuthenticationCallbackParser.parse(
            callbackURL = callbackURL,
            fallbackSiteURL = fallbackSiteURL,
            authenticatedAt = authenticatedAt,
        )

        assertEquals("https://moodle.example.edu", session.siteURL)
        assertEquals("ws-token-123", session.token)
        assertEquals("private-456", session.privateToken)
        assertEquals(
            "moodleapp://token=ZHVtbXlzaWduYXR1cmU6Ojp3cy10b2tlbi0xMjM6Ojpwcml2YXRlLTQ1Ng==",
            session.rawCallbackURL,
        )
        assertEquals(authenticatedAt, session.authenticatedAt)
    }
}
