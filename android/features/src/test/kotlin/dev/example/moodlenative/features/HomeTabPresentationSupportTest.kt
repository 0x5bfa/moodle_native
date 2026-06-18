package dev.example.moodlenative.features

import dev.example.moodlenative.core.LmsAssignmentItem
import dev.example.moodlenative.core.TimetableScheduleSlot
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId
import org.junit.Assert.assertEquals
import org.junit.Test

class HomeTabPresentationSupportTest {
    @Test
    fun filterRemainingCoursesForToday() {
        val now = date(year = 2026, month = 4, day = 15, hour = 11, minute = 0)
        val summaries = listOf(
            LmsCourseSummary(
                id = 1,
                title = "朝の授業",
                courseCode = null,
                shortName = "A",
                summary = null,
                courseImageURL = null,
                progress = null,
                isFavorite = false,
                academicSemester = null,
                scheduleSlots = listOf(TimetableScheduleSlot(dayIndex = 2, periodIndices = listOf(0), room = "H101")),
                assignmentCount = 0,
                unreadAnnouncementCount = 0,
                unreadForumPostCount = 0,
                isRecentlyAccessed = false,
                detailURL = null,
            ),
            LmsCourseSummary(
                id = 2,
                title = "午後の授業",
                courseCode = null,
                shortName = "B",
                summary = null,
                courseImageURL = null,
                progress = null,
                isFavorite = false,
                academicSemester = null,
                scheduleSlots = listOf(TimetableScheduleSlot(dayIndex = 2, periodIndices = listOf(2), room = "H202")),
                assignmentCount = 0,
                unreadAnnouncementCount = 0,
                unreadForumPostCount = 0,
                isRecentlyAccessed = false,
                detailURL = null,
            ),
            LmsCourseSummary(
                id = 3,
                title = "明日の授業",
                courseCode = null,
                shortName = "C",
                summary = null,
                courseImageURL = null,
                progress = null,
                isFavorite = false,
                academicSemester = null,
                scheduleSlots = listOf(TimetableScheduleSlot(dayIndex = 3, periodIndices = listOf(1), room = "H303")),
                assignmentCount = 0,
                unreadAnnouncementCount = 0,
                unreadForumPostCount = 0,
                isRecentlyAccessed = false,
                detailURL = null,
            ),
        )

        val remaining = HomeTabPresentationSupport.remainingCoursesToday(
            summaries = summaries,
            now = now,
            zoneId = zoneId,
        )

        assertEquals(listOf("午後の授業"), remaining.map { it.course.title })
        assertEquals("3限", remaining.firstOrNull()?.periodTitle)
    }

    @Test
    fun countAssignmentsRemainingThisWeek() {
        val now = date(year = 2026, month = 4, day = 15, hour = 11, minute = 0)
        val assignments = listOf(
            makeAssignment(id = 1, dueDate = date(year = 2026, month = 4, day = 15, hour = 18, minute = 0)),
            makeAssignment(id = 2, dueDate = date(year = 2026, month = 4, day = 17, hour = 9, minute = 0)),
            makeAssignment(id = 3, dueDate = date(year = 2026, month = 4, day = 20, hour = 9, minute = 0)),
            makeAssignment(id = 4, dueDate = date(year = 2026, month = 4, day = 14, hour = 9, minute = 0)),
            makeAssignment(id = 5, dueDate = null),
        )

        val count = HomeTabPresentationSupport.remainingAssignmentsThisWeekCount(
            assignments = assignments,
            now = now,
            zoneId = zoneId,
        )

        assertEquals(2, count)
    }

    private fun date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
    ): Instant =
        LocalDateTime.of(year, month, day, hour, minute)
            .atZone(zoneId)
            .toInstant()

    private fun makeAssignment(id: Int, dueDate: Instant?): LmsAssignmentItem =
        LmsAssignmentItem(
            id = id,
            courseID = 10,
            courseModuleID = 100 + id,
            courseTitle = "ソフトウェア工学",
            courseShortName = "2026-50001",
            title = "課題$id",
            introPreview = null,
            dueDate = dueDate,
            allowsSubmissionsFromDate = null,
            cutoffDate = null,
            updatedAt = null,
        )

    private companion object {
        val zoneId: ZoneId = ZoneId.of("Asia/Tokyo")
    }
}
