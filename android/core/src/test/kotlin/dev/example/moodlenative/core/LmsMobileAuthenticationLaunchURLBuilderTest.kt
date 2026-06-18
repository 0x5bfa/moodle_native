package dev.example.moodlenative.core

import java.net.URI
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class LmsMobileAuthenticationLaunchURLBuilderTest {
    @Test
    fun buildsMoodleMobileLaunchURL() {
        val launchURL = LmsMobileAuthenticationLaunchURLBuilder.build(
            siteURL = URI("https://moodle.example.edu"),
            callbackScheme = "moodlemobile",
            passport = "abc123",
        )

        assertEquals(
            "https://moodle.example.edu/admin/tool/mobile/launch.php" +
                "?service=moodle_mobile_app&passport=abc123&urlscheme=moodlemobile&confirmed=1",
            launchURL.toString(),
        )
    }

    @Test
    fun trimsTrailingSlashAndPreservesSitePath() {
        val launchURL = LmsMobileAuthenticationLaunchURLBuilder.build(
            siteURL = URI("https://lms.example.test/moodle/"),
            callbackScheme = "custom scheme",
            passport = "passport-value",
        )

        assertEquals(
            "https://lms.example.test/moodle/admin/tool/mobile/launch.php" +
                "?service=moodle_mobile_app&passport=passport-value&urlscheme=custom+scheme&confirmed=1",
            launchURL.toString(),
        )
    }

    @Test
    fun rejectsInvalidSiteURL() {
        assertThrows(IllegalArgumentException::class.java) {
            LmsMobileAuthenticationLaunchURLBuilder.build(
                siteURL = URI("not-a-url"),
                passport = "abc123",
            )
        }
    }
}
