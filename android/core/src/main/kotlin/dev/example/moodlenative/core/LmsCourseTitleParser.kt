package dev.example.moodlenative.core

data class ParsedCourseTitle(
    val courseCode: String?,
    val title: String,
)

object LmsCourseTitleParser {
    fun parse(value: String): ParsedCourseTitle {
        val trimmed = value.trim()
        val separatorIndex = trimmed.indexOf(':')
        if (separatorIndex < 0) {
            return ParsedCourseTitle(null, trimmed)
        }

        val codeCandidate = trimmed.substring(0, separatorIndex).trim()
        val titleCandidate = trimmed.substring(separatorIndex + 1).trim()
        return ParsedCourseTitle(
            courseCode = codeCandidate.ifEmpty { null },
            title = titleCandidate.ifEmpty { trimmed },
        )
    }
}
