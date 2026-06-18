package dev.example.moodlenative.core

import org.junit.Assert.assertEquals
import org.junit.Test

class TimetableSummaryParserTest {
    @Test
    fun parseJapaneseSpringSemester() {
        val summary = "2026 53374:ユーザビリティ工学 春セメスター:春セメ・月2(3-4)"

        val semester = TimetableSummaryParser.parseAcademicSemester(summary = summary)

        assertEquals(AcademicSemester(academicYear = 2026, season = SemesterSeason.SPRING), semester)
    }

    @Test
    fun parseEnglishFallSemester() {
        val summary = "2026 53374:Usability Engineering Fall:F Mon2(3-4)"

        val semester = TimetableSummaryParser.parseAcademicSemester(summary = summary)

        assertEquals(AcademicSemester(academicYear = 2026, season = SemesterSeason.FALL), semester)
    }

    @Test
    fun parseUnknownSemesterWhenSeasonIsMissing() {
        val summary = "2026 53374:オンデマンド授業"

        val semester = TimetableSummaryParser.parseAcademicSemester(summary = summary)

        assertEquals(AcademicSemester(academicYear = 2026, season = SemesterSeason.UNKNOWN), semester)
    }
}
