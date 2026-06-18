package dev.example.moodlenative.features

import dev.example.moodlenative.core.LmsCourseTitleParser
import dev.example.moodlenative.core.TimetableSummaryParser
import java.net.URI
import java.text.Collator
import java.util.Locale

object LmsCourseSummaryFactory {
    fun makeCourseSummaries(snapshot: LmsDashboardSnapshot): List<LmsCourseSummary> {
        val titleCollator = Collator.getInstance(Locale.JAPAN)

        return snapshot.courses
            .map { course ->
                val titleParts = LmsCourseTitleParser.parse(course.displayName ?: course.fullName)
                val summary = strippedSummary(course.summary)
                LmsCourseSummary(
                    id = course.id,
                    title = titleParts.title,
                    courseCode = titleParts.courseCode,
                    shortName = course.shortName,
                    summary = summary,
                    courseImageURL = course.courseImage?.let(::uriOrNull),
                    progress = course.progress,
                    isFavorite = course.isFavorite ?: false,
                    academicSemester = TimetableSummaryParser.parseAcademicSemester(
                        summary = summary,
                        fallbackText = course.shortName,
                    ),
                    scheduleSlots = emptyList(),
                    assignmentCount = 0,
                    unreadAnnouncementCount = 0,
                    unreadForumPostCount = 0,
                    isRecentlyAccessed = false,
                    detailURL = uriOrNull("${snapshot.siteURL.trimEnd('/')}/course/view.php?id=${course.id}"),
                )
            }
            .sortedWith { lhs, rhs ->
                if (lhs.isFavorite != rhs.isFavorite) {
                    if (lhs.isFavorite) -1 else 1
                } else {
                    titleCollator.compare(lhs.title, rhs.title)
                }
            }
    }

    private fun strippedSummary(value: String?): String? {
        if (value == null) {
            return null
        }

        val withoutTags = value.replace(Regex("<[^>]+>"), " ")
        val unescaped = withoutTags
            .replace("&nbsp;", " ")
            .replace("&amp;", "&")
            .replace("&lt;", "<")
            .replace("&gt;", ">")
            .replace("&quot;", "\"")
        val collapsed = unescaped
            .replace(Regex("\\s+"), " ")
            .trim()

        return collapsed.ifEmpty { null }
    }

    private fun uriOrNull(value: String): URI? =
        runCatching { URI(value) }.getOrNull()
}
