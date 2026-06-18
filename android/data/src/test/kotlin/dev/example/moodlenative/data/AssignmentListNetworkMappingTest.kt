package dev.example.moodlenative.data

import dev.example.moodlenative.networking.Assignment
import dev.example.moodlenative.networking.AssignmentPluginConfig
import dev.example.moodlenative.networking.CourseAssignments
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AssignmentListNetworkMappingTest {
    @Test
    fun courseAssignmentsMapToCoreAssignmentItems() {
        val courseAssignments = listOf(
            CourseAssignments(
                id = 42,
                fullName = "ソフトウェア工学",
                shortName = "2026-50001",
                assignments = listOf(
                    Assignment(
                        id = 27625,
                        courseID = 42,
                        courseModuleID = 177,
                        name = "提出課題",
                        intro = "<p>説明</p>",
                        allowsSubmissionsFromDate = 1_740_000_000,
                        dueDate = 1_750_000_000,
                        cutoffDate = 1_760_000_000,
                        timeModified = 1_745_000_000,
                        submissionStatement = "<p>自分の成果物です。</p>",
                        timeLimit = 3600,
                        configs = listOf(
                            AssignmentPluginConfig("file", "assignsubmission", "enabled", "1"),
                            AssignmentPluginConfig("onlinetext", "assignsubmission", "enabled", "1"),
                            AssignmentPluginConfig("onlinetext", "assignsubmission", "wordlimitenabled", "1"),
                            AssignmentPluginConfig("onlinetext", "assignsubmission", "wordlimit", "500"),
                        ),
                    ),
                ),
            ),
        )

        val items = courseAssignments.toLmsAssignmentItems()

        assertEquals(1, items.size)
        val item = items[0]
        assertEquals(27625, item.id)
        assertEquals(42, item.courseID)
        assertEquals(177, item.courseModuleID)
        assertEquals("ソフトウェア工学", item.courseTitle)
        assertEquals("2026-50001", item.courseShortName)
        assertEquals("提出課題", item.title)
        assertEquals("<p>説明</p>", item.introPreview)
        assertEquals(1_750_000_000L, item.dueDate?.epochSecond)
        assertEquals(1_740_000_000L, item.allowsSubmissionsFromDate?.epochSecond)
        assertEquals(1_760_000_000L, item.cutoffDate?.epochSecond)
        assertEquals(1_745_000_000L, item.updatedAt?.epochSecond)
        assertNull(item.submissionDrafts)
        assertNull(item.requiresSubmissionStatement)
        assertEquals("<p>自分の成果物です。</p>", item.submissionStatement)
        assertEquals(3600, item.timeLimit)
        assertEquals(listOf("file", "onlinetext"), item.enabledSubmissionPluginTypes)
        assertEquals(500, item.onlineTextWordLimit)
    }
}
