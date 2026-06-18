package dev.example.moodlenative.features

import dev.example.moodlenative.core.AcademicSemester
import dev.example.moodlenative.core.SemesterSeason
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LmsCourseSummaryFactoryTest {
    @Test
    fun makeCourseSummariesMapsCourseFieldsAndStripsSummary() {
        val snapshot = LmsDashboardSnapshot(
            siteURL = siteURL,
            userID = 99,
            courses = listOf(
                LmsDashboardCourse(
                    id = 36057,
                    fullName = "53374:ユーザビリティ工学(A1)",
                    displayName = null,
                    shortName = "2026-53374 Fall",
                    summary = "<p>2026 秋セメスター&nbsp; <strong>説明&amp;補足</strong></p>",
                    courseImage = "$siteURL/pluginfile.php/course-image.png",
                    progress = 42.5,
                    isFavorite = true,
                ),
            ),
            dashboardBlocks = emptyList(),
        )

        val summaries = LmsCourseSummaryFactory.makeCourseSummaries(snapshot)

        assertEquals(1, summaries.size)
        val summary = summaries[0]
        assertEquals(36057, summary.id)
        assertEquals("ユーザビリティ工学(A1)", summary.title)
        assertEquals("53374", summary.courseCode)
        assertEquals("2026-53374 Fall", summary.shortName)
        assertEquals("2026 秋セメスター 説明&補足", summary.summary)
        assertEquals("$siteURL/pluginfile.php/course-image.png", summary.courseImageURL.toString())
        assertEquals(42.5, summary.progress)
        assertEquals(true, summary.isFavorite)
        assertEquals(AcademicSemester(academicYear = 2026, season = SemesterSeason.FALL), summary.academicSemester)
        assertEquals("$siteURL/course/view.php?id=36057", summary.detailURL.toString())
        assertTrue(summary.scheduleSlots.isEmpty())
        assertEquals(0, summary.assignmentCount)
        assertEquals(0, summary.unreadAnnouncementCount)
        assertEquals(0, summary.unreadForumPostCount)
        assertEquals(false, summary.isRecentlyAccessed)
    }

    @Test
    fun makeCourseSummariesUsesDisplayNameAndSortsFavoritesFirst() {
        val snapshot = LmsDashboardSnapshot(
            siteURL = siteURL,
            userID = 99,
            courses = listOf(
                LmsDashboardCourse(
                    id = 1,
                    fullName = "99999:Fallback",
                    displayName = "53338:コンピュータネットワーク(K1)",
                    shortName = "2026 Spring",
                    isFavorite = false,
                ),
                LmsDashboardCourse(
                    id = 2,
                    fullName = "53374:ユーザビリティ工学(A1)",
                    displayName = null,
                    shortName = "2026 Fall",
                    isFavorite = true,
                ),
                LmsDashboardCourse(
                    id = 3,
                    fullName = "53334:ソフトウェア工学(K1)",
                    displayName = null,
                    shortName = "2026 Spring",
                    isFavorite = false,
                ),
            ),
            dashboardBlocks = emptyList(),
        )

        val summaries = LmsCourseSummaryFactory.makeCourseSummaries(snapshot)

        assertEquals(listOf(2, 1, 3), summaries.map { it.id })
        assertEquals("コンピュータネットワーク(K1)", summaries[1].title)
        assertEquals("53338", summaries[1].courseCode)
    }

    @Test
    fun makeCourseSummariesDefaultsAndDropsBlankSummary() {
        val snapshot = LmsDashboardSnapshot(
            siteURL = "$siteURL/",
            userID = null,
            courses = listOf(
                LmsDashboardCourse(
                    id = 10,
                    fullName = "オンデマンド授業",
                    displayName = null,
                    shortName = "2026 Spring",
                    summary = "<p>&nbsp;</p>",
                    courseImage = "https:// lms.example.test/bad image.png",
                    progress = null,
                    isFavorite = null,
                ),
            ),
            dashboardBlocks = emptyList(),
        )

        val summaries = LmsCourseSummaryFactory.makeCourseSummaries(snapshot)

        assertEquals(1, summaries.size)
        assertEquals("オンデマンド授業", summaries[0].title)
        assertNull(summaries[0].courseCode)
        assertNull(summaries[0].summary)
        assertNull(summaries[0].courseImageURL)
        assertEquals(false, summaries[0].isFavorite)
        assertEquals(AcademicSemester(academicYear = 2026, season = SemesterSeason.SPRING), summaries[0].academicSemester)
        assertEquals("$siteURL/course/view.php?id=10", summaries[0].detailURL.toString())
    }

    private companion object {
        const val siteURL = "https://lms.example.test"
    }
}
