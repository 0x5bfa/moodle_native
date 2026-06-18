package dev.example.moodlenative.core

object TimetableSummaryParser {
    private val academicYearPattern = Regex("(20\\d{2})")

    fun parseAcademicSemester(
        summary: String?,
        fallbackText: String? = null,
    ): AcademicSemester? {
        val combined = listOfNotNull(summary, fallbackText)
            .joinToString(separator = " ")
            .trim()
        if (combined.isEmpty()) {
            return null
        }

        val academicYear = academicYearPattern.find(combined)?.groupValues?.get(1)?.toIntOrNull()
            ?: return null
        val lowercased = combined.lowercase()
        val season = when {
            combined.contains("春セメスター") || lowercased.contains("spring") -> SemesterSeason.SPRING
            combined.contains("秋セメスター") ||
                lowercased.contains("fall") ||
                lowercased.contains("autumn") -> SemesterSeason.FALL
            else -> SemesterSeason.UNKNOWN
        }

        return AcademicSemester(academicYear = academicYear, season = season)
    }
}
