package dev.example.moodlenative.features

import java.net.URI

data class CoursePlacement(
    val courseID: Int,
    val title: String,
    val room: String?,
    val dayIndex: Int?,
    val periodIndex: Int?,
    val detailURL: URI?,
    val isFavorite: Boolean,
    val hasUnreadAnnouncement: Boolean,
    val hasPendingAssignment: Boolean,
    val hasUnreadForum: Boolean,
)

object LmsRutimeTableParser {
    private val dayMap = mapOf(
        '月' to 0,
        '火' to 1,
        '水' to 2,
        '木' to 3,
        '金' to 4,
    )

    fun parse(snapshot: LmsDashboardSnapshot): List<CoursePlacement> =
        parse(dashboardBlocks = snapshot.dashboardBlocks, siteURL = snapshot.siteURL)

    fun parse(dashboardBlocks: List<LmsDashboardBlock>, siteURL: String): List<CoursePlacement> {
        val block = dashboardBlocks.firstOrNull { block ->
            if (block.name == "rutime_table") {
                return@firstOrNull true
            }

            val content = block.contents?.content ?: return@firstOrNull false
            content.contains("class=\"subject\"") && content.contains("active-course-name")
        }

        val content = block?.contents?.content
        if (content.isNullOrEmpty()) {
            return emptyList()
        }

        return parse(content = content, siteURL = siteURL)
    }

    fun parse(content: String, siteURL: String): List<CoursePlacement> {
        val normalized = content.replace("\r\n", "\n")

        val tablePlacements = parseTablePlacements(normalized, siteURL)
        if (tablePlacements.isNotEmpty()) {
            return tablePlacements
        }

        val subjects = captureGroups(
            pattern = """<div\s+class="subject">([\s\S]*?)(?=<div\s+class="subject">|</table>|$)""",
            text = normalized,
        )

        return subjects.flatMap { parseSubjectPlacements(it, siteURL) }
    }

    private fun parseTablePlacements(content: String, siteURL: String): List<CoursePlacement> {
        val rows = captureGroups("""<tr[^>]*>([\s\S]*?)</tr>""", content)
        val placements = mutableListOf<CoursePlacement>()

        for (row in rows) {
            val periodText = firstMatch("""<td\s+class="time"[^>]*>([\s\S]*?)</td>""", row)
                ?.let { decodeHTMLText(it).trim() }
            val periodNumber = periodText
                ?.let(::normalizedDigits)
                ?.toIntOrNull()
                ?: continue

            val cells = captureGroups(
                pattern = """<td\s+class="(?:highlight|empty)[^"]*"[^>]*>([\s\S]*?)</td>""",
                text = row,
            )

            for ((cellIndex, cell) in cells.withIndex()) {
                val subjects = captureGroups(
                    pattern = """<div\s+class="subject">([\s\S]*?)(?=<div\s+class="subject">|$)""",
                    text = cell,
                )

                for (subject in subjects) {
                    placements += parseSubjectPlacements(
                        subject = subject,
                        siteURL = siteURL,
                        dayIndexOverride = cellIndex.takeIf { it < 5 },
                        periodIndexOverride = periodNumber - 1,
                    )
                }
            }
        }

        return placements
    }

    private fun parseSubjectPlacements(
        subject: String,
        siteURL: String,
        dayIndexOverride: Int? = null,
        periodIndexOverride: Int? = null,
    ): List<CoursePlacement> {
        val courseID = firstMatch("""course/view\.php\?id=(\d+)""", subject)
            ?.toIntOrNull()
            ?: return emptyList()

        val title = decodeHTMLText(
            firstMatch("""<a[^>]*class="active-course-name"[^>]*>([\s\S]*?)</a>""", subject) ?: "",
        ).trim()

        val roomText = decodeHTMLText(
            firstMatch("""<div\s+class="room">([\s\S]*?)</div>""", subject) ?: "",
        ).trim()

        val parsedRoom = parseRoom(roomText)
        val detailURL = firstMatch("<a[^>]*href=\"([^\"]+)\"", subject)
            ?.let { resolvedURL(it, siteURL) }
            ?: resolvedURL("$siteURL/course/view.php?id=$courseID", siteURL)

        val dayIndex = dayIndexOverride ?: parsedRoom.dayIndex
        val periodIndices = periodIndexOverride?.let(::listOf) ?: parsedRoom.periodIndices

        if (periodIndices.isEmpty()) {
            return listOf(
                CoursePlacement(
                    courseID = courseID,
                    title = title,
                    room = parsedRoom.room,
                    dayIndex = dayIndex,
                    periodIndex = null,
                    detailURL = detailURL,
                    isFavorite = isIconOn("favouriteicon", subject),
                    hasUnreadAnnouncement = isIconOn("newsicon", subject),
                    hasPendingAssignment = isIconOn("assignicon", subject),
                    hasUnreadForum = isIconOn("forumicon", subject),
                ),
            )
        }

        return periodIndices.map { periodIndex ->
            CoursePlacement(
                courseID = courseID,
                title = title,
                room = parsedRoom.room,
                dayIndex = dayIndex,
                periodIndex = periodIndex,
                detailURL = detailURL,
                isFavorite = isIconOn("favouriteicon", subject),
                hasUnreadAnnouncement = isIconOn("newsicon", subject),
                hasPendingAssignment = isIconOn("assignicon", subject),
                hasUnreadForum = isIconOn("forumicon", subject),
            )
        }
    }

    private fun parseRoom(value: String): ParsedRoom {
        if (value.isEmpty()) {
            return ParsedRoom(dayIndex = null, periodIndices = emptyList(), room = null)
        }

        val parts = splitScheduleAndRoom(value)
        val dayToken = firstMatch("""([月火水木金])""", parts.schedule)
        val dayIndex = dayToken?.firstOrNull()?.let(dayMap::get)

        if (dayIndex == null) {
            return ParsedRoom(dayIndex = null, periodIndices = emptyList(), room = value)
        }

        val room = parts.room?.trim()?.takeIf { it.isNotEmpty() }

        return ParsedRoom(
            dayIndex = dayIndex,
            periodIndices = periodNumbers(parts.schedule).map { it - 1 },
            room = room,
        )
    }

    private fun splitScheduleAndRoom(value: String): ScheduleAndRoom {
        val separatorIndex = value.indexOfFirst { it == ':' || it == '：' }
        if (separatorIndex < 0) {
            return ScheduleAndRoom(schedule = value, room = null)
        }

        return ScheduleAndRoom(
            schedule = value.substring(0, separatorIndex),
            room = value.substring(separatorIndex + 1).trim(),
        )
    }

    private fun periodNumbers(text: String): List<Int> {
        val periodText = firstMatch(
            pattern = """([月火水木金])\s*([0-9０-９]+(?:\s*[-－〜~～・･,，/／、]\s*[月火水木金]?\s*[0-9０-９]+)*)""",
            text = text,
            group = 2,
        ) ?: return emptyList()

        return captureGroups("""([0-9０-９]+)""", periodText)
            .mapNotNull { normalizedDigits(it).toIntOrNull() }
            .filter { it > 0 }
    }

    private fun normalizedDigits(value: String): String =
        buildString {
            for (char in value) {
                if (char.code in fullWidthZeroCode..fullWidthNineCode) {
                    append((char.code - fullWidthZeroCode + asciiZeroCode).toChar())
                } else {
                    append(char)
                }
            }
        }

    private fun isIconOn(iconClass: String, text: String): Boolean {
        val escapedIconClass = Regex.escape(iconClass)
        val pattern =
            """(<span\s+class="on">(?:(?!</span>)[\s\S])*?class="[^"]*\b$escapedIconClass\b[^"]*")"""
        return firstMatch(pattern, text, group = 1) != null
    }

    private fun decodeHTMLText(value: String): String =
        value
            .replace(Regex("<[^>]+>"), " ")
            .replace("&nbsp;", " ")
            .replace("&amp;", "&")
            .replace("&lt;", "<")
            .replace("&gt;", ">")
            .replace("&quot;", "\"")
            .replace("&#39;", "'")

    private fun resolvedURL(href: String, siteURL: String): URI? {
        val absoluteURL = runCatching { URI(href) }.getOrNull()
        if (absoluteURL?.isAbsolute == true) {
            return absoluteURL
        }

        val baseURL = runCatching { URI(siteURL) }.getOrNull() ?: return null
        return runCatching { baseURL.resolve(href) }.getOrNull()
    }

    private fun captureGroups(pattern: String, text: String): List<String> =
        Regex(pattern).findAll(text).mapNotNull { match ->
            match.groups[1]?.value
        }.toList()

    private fun firstMatch(pattern: String, text: String, group: Int = 1): String? =
        Regex(pattern).find(text)?.groups?.get(group)?.value

    private data class ParsedRoom(
        val dayIndex: Int?,
        val periodIndices: List<Int>,
        val room: String?,
    )

    private data class ScheduleAndRoom(
        val schedule: String,
        val room: String?,
    )

    private const val fullWidthZeroCode = 0xFF10
    private const val fullWidthNineCode = 0xFF19
    private const val asciiZeroCode = 0x30
}
