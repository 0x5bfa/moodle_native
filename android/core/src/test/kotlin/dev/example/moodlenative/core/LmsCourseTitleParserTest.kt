package dev.example.moodlenative.core

import org.junit.Assert.assertEquals
import org.junit.Test

class LmsCourseTitleParserTest {
    @Test
    fun parseCourseTitleIntoCourseCodeAndTitle() {
        val parsed = LmsCourseTitleParser.parse("54580:中国の国家と社会(GV)")

        assertEquals("54580", parsed.courseCode)
        assertEquals("中国の国家と社会(GV)", parsed.title)
    }
}
