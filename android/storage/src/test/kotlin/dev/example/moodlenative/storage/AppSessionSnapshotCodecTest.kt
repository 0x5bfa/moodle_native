package dev.example.moodlenative.storage

import dev.example.moodlenative.core.LmsAuthenticationSession
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class AppSessionSnapshotCodecTest {
    @Test
    fun snapshotRoundTripsLmsSession() {
        val snapshot = AppSessionSnapshot(
            lmsSession = LmsAuthenticationSession(
                siteURL = "https://lms.example.test",
                token = "ws-token-123",
                privateToken = "private-token-456",
                rawCallbackURL = "moodlemobile://alice@lms.example.test?token=ws-token-123",
                authenticatedAt = Instant.parse("2026-06-11T10:15:30Z"),
                userID = 99,
            ),
        )

        val decoded = AppSessionSnapshotCodec.decode(AppSessionSnapshotCodec.encode(snapshot))

        assertTrue(decoded.hasLmsSession)
        assertEquals("https://lms.example.test", decoded.lmsSession?.siteURL)
        assertEquals("ws-token-123", decoded.lmsSession?.token)
        assertEquals("private-token-456", decoded.lmsSession?.privateToken)
        assertEquals("moodlemobile://alice@lms.example.test?token=ws-token-123", decoded.lmsSession?.rawCallbackURL)
        assertEquals(Instant.parse("2026-06-11T10:15:30Z"), decoded.lmsSession?.authenticatedAt)
        assertEquals(99, decoded.lmsSession?.userID)
    }

    @Test
    fun invalidStoredSnapshotThrows() {
        assertThrows(AppSessionStoreError.InvalidStoredSnapshot::class.java) {
            AppSessionSnapshotCodec.decode("{not-json")
        }
    }
}
