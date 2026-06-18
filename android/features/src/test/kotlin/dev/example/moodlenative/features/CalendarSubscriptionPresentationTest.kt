package dev.example.moodlenative.features

import java.net.URI
import org.junit.Assert.assertEquals
import org.junit.Test

class CalendarSubscriptionPresentationTest {
    @Test
    fun presentationBuildsHttpsAndWebcalURLs() {
        val subscription = LmsCalendarSubscription(
            uri = URI("https://lms.example.test/calendar/export_execute.php?userid=42&token=abc"),
        )

        val presentation = subscription.presentation

        assertEquals(
            "webcal://lms.example.test/calendar/export_execute.php?userid=42&token=abc",
            presentation.webcalURL,
        )
        assertEquals(
            "https://lms.example.test/calendar/export_execute.php?userid=42&token=abc",
            presentation.httpsURL,
        )
    }
}
