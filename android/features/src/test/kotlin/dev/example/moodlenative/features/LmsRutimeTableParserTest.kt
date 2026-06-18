package dev.example.moodlenative.features

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LmsRutimeTableParserTest {
    private val siteURL = "https://moodle.example.edu"

    @Test
    fun parseSnapshotUsesRutimeTableBlock() {
        val content = subject(courseID = 36022, title = "53338:コンピュータネットワーク(K1)", room = "水1:AC237")
        val snapshot = LmsDashboardSnapshot(
            siteURL = siteURL,
            userID = 99,
            courses = listOf(
                LmsDashboardCourse(
                    id = 36022,
                    fullName = "53338:コンピュータネットワーク(K1)",
                    shortName = "2026-53338",
                ),
            ),
            dashboardBlocks = listOf(
                LmsDashboardBlock(
                    instanceID = 1,
                    name = "html",
                    contents = LmsDashboardBlock.Contents(content = "<p>ignored</p>"),
                ),
                LmsDashboardBlock(
                    instanceID = 2,
                    name = "rutime_table",
                    contents = LmsDashboardBlock.Contents(content = content),
                ),
            ),
        )

        val placements = LmsRutimeTableParser.parse(snapshot)

        assertEquals(1, placements.size)
        assertEquals(36022, placements[0].courseID)
        assertEquals(2, placements[0].dayIndex)
        assertEquals(0, placements[0].periodIndex)
    }

    @Test
    fun parseDashboardBlocksFallsBackToSubjectContentWhenBlockNameDiffers() {
        val content = subject(courseID = 36057, title = "53374:ユーザビリティ工学(A1)", room = "月2:H301")
        val blocks = listOf(
            LmsDashboardBlock(
                instanceID = 1,
                name = "html",
                contents = LmsDashboardBlock.Contents(content = content),
            ),
        )

        val placements = LmsRutimeTableParser.parse(dashboardBlocks = blocks, siteURL = siteURL)

        assertEquals(1, placements.size)
        assertEquals(36057, placements[0].courseID)
        assertEquals(0, placements[0].dayIndex)
        assertEquals(1, placements[0].periodIndex)
    }

    @Test
    fun parseSingleCourseWithScheduledSlot() {
        val content = subject(courseID = 36022, title = "53338:コンピュータネットワーク(K1)", room = "水1:AC237")

        val placements = LmsRutimeTableParser.parse(content = content, siteURL = siteURL)

        assertEquals(1, placements.size)
        val placement = placements[0]
        assertEquals(36022, placement.courseID)
        assertEquals(2, placement.dayIndex)
        assertEquals(0, placement.periodIndex)
        assertEquals("AC237", placement.room)
        assertEquals("53338:コンピュータネットワーク(K1)", placement.title)
    }

    @Test
    fun parseMultipleCoursesFromRealHTML() {
        val c1 = subject(courseID = 36022, title = "53338:コンピュータネットワーク(K1)", room = "水1:AC237")
        val c2 = subject(courseID = 36057, title = "53374:ユーザビリティ工学(A1)", room = "月2:H301")
        val c3 = subject(courseID = 36018, title = "53334:ソフトウェア工学(K1)", room = "水2:H301")
        val content = "<table>$c1$c2$c3</table>"

        val placements = LmsRutimeTableParser.parse(content = content, siteURL = siteURL)

        assertEquals(3, placements.size)
        assertEquals(36022, placements[0].courseID)
        assertEquals(36057, placements[1].courseID)
        assertEquals(0, placements[1].dayIndex)
        assertEquals(1, placements[1].periodIndex)
        assertEquals(36018, placements[2].courseID)
        assertEquals(2, placements[2].dayIndex)
        assertEquals(1, placements[2].periodIndex)
    }

    @Test
    fun parsesAllWeekdayIndices() {
        val days = listOf('月' to 0, '火' to 1, '水' to 2, '木' to 3, '金' to 4)

        for ((kanji, expectedIndex) in days) {
            val content = subject(courseID = 100, title = "テスト科目", room = "${kanji}3:Room101")
            val placements = LmsRutimeTableParser.parse(content = content, siteURL = siteURL)
            assertEquals("Failed for $kanji", expectedIndex, placements.firstOrNull()?.dayIndex)
        }
    }

    @Test
    fun parsesAllPeriodIndices() {
        for (period in 1..5) {
            val content = subject(courseID = 100, title = "テスト科目", room = "月$period:Room")
            val placements = LmsRutimeTableParser.parse(content = content, siteURL = siteURL)
            assertEquals("Failed for period $period", period - 1, placements.firstOrNull()?.periodIndex)
        }
    }

    @Test
    fun expandsConsecutivePeriodsJoinedByHyphen() {
        val content = subject(courseID = 36099, title = "53347:計算機科学実験(K1)", room = "木3-4:実験室")

        val placements = LmsRutimeTableParser.parse(content = content, siteURL = siteURL)

        assertEquals(2, placements.size)
        assertEquals(listOf(3, 3), placements.map { it.dayIndex })
        assertEquals(listOf(2, 3), placements.map { it.periodIndex })
        assertEquals(listOf("実験室", "実験室"), placements.map { it.room })
    }

    @Test
    fun expandsConsecutivePeriodsJoinedByJapaneseSeparator() {
        val content = subject(courseID = 36099, title = "53347:計算機科学実験(K1)", room = "木3・4:実験室")

        val placements = LmsRutimeTableParser.parse(content = content, siteURL = siteURL)

        assertEquals(2, placements.size)
        assertEquals(listOf(2, 3), placements.map { it.periodIndex })
    }

    @Test
    fun parsesFullWidthPeriodDigits() {
        val content = subject(courseID = 36099, title = "53347:計算機科学実験(K1)", room = "木３－４：実験室")

        val placements = LmsRutimeTableParser.parse(content = content, siteURL = siteURL)

        assertEquals(2, placements.size)
        assertEquals(listOf(2, 3), placements.map { it.periodIndex })
        assertEquals(listOf("実験室", "実験室"), placements.map { it.room })
    }

    @Test
    fun doesNotTreatRoomDigitsAsPeriodsWhenRoomSeparatorIsMissing() {
        val content = subject(courseID = 36099, title = "53347:計算機科学実験(K1)", room = "木3 H301")

        val placements = LmsRutimeTableParser.parse(content = content, siteURL = siteURL)

        assertEquals(1, placements.size)
        assertEquals(2, placements.firstOrNull()?.periodIndex)
    }

    @Test
    fun tableCellPositionOverridesStaleRoomPeriod() {
        val experiment = subject(
            courseID = 36056,
            title = "53373:計算機科学実験１ (B1)",
            room = "木3:H902",
        )
        val content = """
            <table class="timetable">
                <tr>
                    <td class="time">3</td>
                    <td class="empty"><div>&nbsp;</div></td>
                    <td class="empty"><div>&nbsp;</div></td>
                    <td class="empty"><div>&nbsp;</div></td>
                    <td class="highlight">$experiment</td>
                    <td class="empty"><div>&nbsp;</div></td>
                </tr>
                <tr>
                    <td class="time">4</td>
                    <td class="empty"><div>&nbsp;</div></td>
                    <td class="empty"><div>&nbsp;</div></td>
                    <td class="empty"><div>&nbsp;</div></td>
                    <td class="highlight">$experiment</td>
                    <td class="empty"><div>&nbsp;</div></td>
                </tr>
            </table>
        """.trimIndent()

        val placements = LmsRutimeTableParser.parse(content = content, siteURL = siteURL)

        assertEquals(2, placements.size)
        assertEquals(listOf(3, 3), placements.map { it.dayIndex })
        assertEquals(listOf(2, 3), placements.map { it.periodIndex })
        assertEquals(listOf("H902", "H902"), placements.map { it.room })
    }

    @Test
    fun parsesIsFavoriteWhenOn() {
        val content = subject(courseID = 1, title = "課題", room = "月1:H101", isFavorite = true)
        val placements = LmsRutimeTableParser.parse(content = content, siteURL = siteURL)
        assertTrue(placements.firstOrNull()?.isFavorite == true)
    }

    @Test
    fun parsesIsFavoriteWhenOff() {
        val content = subject(courseID = 1, title = "課題", room = "月1:H101", isFavorite = false)
        val placements = LmsRutimeTableParser.parse(content = content, siteURL = siteURL)
        assertFalse(placements.firstOrNull()?.isFavorite == true)
    }

    @Test
    fun parsesHasUnreadAnnouncementWhenOn() {
        val content = subject(courseID = 1, title = "課題", room = "火2:AC101", hasUnreadAnnouncement = true)
        val placements = LmsRutimeTableParser.parse(content = content, siteURL = siteURL)
        assertTrue(placements.firstOrNull()?.hasUnreadAnnouncement == true)
    }

    @Test
    fun parsesHasPendingAssignmentWhenOn() {
        val content = subject(courseID = 1, title = "課題", room = "水3:H201", hasPendingAssignment = true)
        val placements = LmsRutimeTableParser.parse(content = content, siteURL = siteURL)
        assertTrue(placements.firstOrNull()?.hasPendingAssignment == true)
    }

    @Test
    fun parsesHasUnreadForumWhenOn() {
        val content = subject(courseID = 1, title = "課題", room = "木4:AC110", hasUnreadForum = true)
        val placements = LmsRutimeTableParser.parse(content = content, siteURL = siteURL)
        assertTrue(placements.firstOrNull()?.hasUnreadForum == true)
    }

    @Test
    fun iconStateDoesNotBleedAcrossSiblingSpans() {
        val content = subject(
            courseID = 1,
            title = "課題",
            room = "木4:AC110",
            isFavorite = true,
            hasUnreadAnnouncement = false,
            hasPendingAssignment = false,
            hasUnreadForum = false,
        )

        val placement = LmsRutimeTableParser.parse(content = content, siteURL = siteURL).first()

        assertTrue(placement.isFavorite)
        assertFalse(placement.hasUnreadAnnouncement)
        assertFalse(placement.hasPendingAssignment)
        assertFalse(placement.hasUnreadForum)
    }

    @Test
    fun returnsEmptyForEmptyContent() {
        val placements = LmsRutimeTableParser.parse(content = "", siteURL = siteURL)
        assertTrue(placements.isEmpty())
    }

    @Test
    fun skipsSubjectWithoutCourseID() {
        val content = """
            <div class="subject">
                <a href="/other/page">No course ID here</a>
                <div class="room">月1:H101</div>
            </div>
        """.trimIndent()

        val placements = LmsRutimeTableParser.parse(content = content, siteURL = siteURL)

        assertTrue(placements.isEmpty())
    }

    @Test
    fun courseWithNoRoomHasNilDayAndPeriod() {
        val content = """
            <div class="subject">
                <a href="$siteURL/course/view.php?id=999" class="active-course-name">オンデマンド授業</a>
                <div class="room"></div>
            </div>
            </table>
        """.trimIndent()

        val placements = LmsRutimeTableParser.parse(content = content, siteURL = siteURL)

        assertEquals(1, placements.size)
        assertEquals(999, placements[0].courseID)
        assertNull(placements[0].dayIndex)
        assertNull(placements[0].periodIndex)
        assertNull(placements[0].room)
    }

    @Test
    fun detailURLIsResolvedToAbsoluteURL() {
        val content = subject(courseID = 36022, title = "テスト", room = "月1:H101")
        val placements = LmsRutimeTableParser.parse(content = content, siteURL = siteURL)
        assertEquals("$siteURL/course/view.php?id=36022", placements.firstOrNull()?.detailURL.toString())
    }

    private fun subject(
        courseID: Int,
        title: String,
        room: String,
        isFavorite: Boolean = false,
        hasUnreadAnnouncement: Boolean = false,
        hasPendingAssignment: Boolean = false,
        hasUnreadForum: Boolean = false,
    ): String {
        fun icon(cls: String, on: Boolean): String {
            val state = if (on) "on" else "off"
            return """
                <span class="$state">
                    <img src="https://moodle.example.edu/theme/image.php/boost/block_rutime_table/1/icon" class="$cls" alt="">
                </span>
            """.trimIndent()
        }

        return """
            <div class="subject">
                <a href="$siteURL/course/view.php?id=$courseID" class="active-course-name">$title</a>
                <div class="room">$room</div>
                ${icon("favouriteicon", isFavorite)}
                ${icon("newsicon", hasUnreadAnnouncement)}
                ${icon("assignicon", hasPendingAssignment)}
                ${icon("forumicon", hasUnreadForum)}
            </div>
        """.trimIndent()
    }
}
