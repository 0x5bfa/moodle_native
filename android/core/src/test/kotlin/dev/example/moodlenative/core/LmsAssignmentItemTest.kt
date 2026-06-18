package dev.example.moodlenative.core

import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Test

class LmsAssignmentItemTest {
    @Test
    fun classifyDueBuckets() {
        val now = Instant.ofEpochSecond(1_745_000_000)

        val overdue = assignment(id = 1, courseModuleID = 101, dueDate = now.minusSeconds(60))
        val upcoming = assignment(id = 2, courseModuleID = 102, dueDate = now.plusSeconds(60))
        val undated = assignment(id = 3, courseModuleID = 103, dueDate = null)

        assertEquals(LmsAssignmentItem.DueBucket.OVERDUE, overdue.dueBucket(now))
        assertEquals(LmsAssignmentItem.DueBucket.UPCOMING, upcoming.dueBucket(now))
        assertEquals(LmsAssignmentItem.DueBucket.UNDATED, undated.dueBucket(now))
        assertEquals("期限切れ", overdue.dueBucket(now).sectionTitle)
        assertEquals("これからの課題", upcoming.dueBucket(now).sectionTitle)
        assertEquals("期限未設定", undated.dueBucket(now).sectionTitle)
    }

    private fun assignment(
        id: Int,
        courseModuleID: Int,
        dueDate: Instant?,
    ): LmsAssignmentItem = LmsAssignmentItem(
        id = id,
        courseID = 10,
        courseModuleID = courseModuleID,
        courseTitle = "ソフトウェア工学",
        courseShortName = "2026-50001",
        title = if (id == 3) "レポート" else "第${id}回課題",
        introPreview = null,
        dueDate = dueDate,
        allowsSubmissionsFromDate = null,
        cutoffDate = null,
        updatedAt = null,
    )
}
