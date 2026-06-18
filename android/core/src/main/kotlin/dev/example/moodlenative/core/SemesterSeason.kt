package dev.example.moodlenative.core

enum class SemesterSeason(
    val rawValue: String,
    val title: String,
    val sortOrder: Int,
) {
    SPRING("spring", "春", 0),
    FALL("fall", "秋", 1),
    UNKNOWN("unknown", "その他", 2),
}

data class AcademicSemester(
    val academicYear: Int,
    val season: SemesterSeason,
) {
    val id: String
        get() = "$academicYear-${season.rawValue}"

    val displayName: String
        get() = "${academicYear}年度${season.title}セメスター"

    val compactDisplayName: String
        get() = "${academicYear % 100} 年度${season.title}セメスター"
}
