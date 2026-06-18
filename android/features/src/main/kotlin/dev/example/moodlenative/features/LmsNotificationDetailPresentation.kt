package dev.example.moodlenative.features

import dev.example.moodlenative.core.LmsNotificationItem
import java.net.URI

data class LmsNotificationDetailPresentation(
    val id: String,
    val sections: List<Section>,
) {
    data class Section(
        val id: String,
        val title: String?,
        val rows: List<Row>,
    ) {
        data class Row(
            val id: String,
            val label: String?,
            val content: Content,
        ) {
            sealed class Content {
                data class Text(val text: String) : Content()
                data class Html(val html: String) : Content()
                data class Link(val title: String, val uri: URI) : Content()
            }
        }
    }
}

val LmsNotificationItem.detailPresentation: LmsNotificationDetailPresentation
    get() = LmsNotificationDetailPresentation(
        id = id,
        sections = makeNotificationSections(this),
    )

private fun makeNotificationSections(notification: LmsNotificationItem): List<LmsNotificationDetailPresentation.Section> {
    val message = trimmedValue(notification.fullMessage) ?: notification.bodyText
    return when (normalizedEventType(notification.eventType)) {
        "reminders_due" -> makeReminderSections(notification = notification, message = message)
        else -> makeGenericSections(message)
    }
}

private fun makeReminderSections(
    notification: LmsNotificationItem,
    message: String,
): List<LmsNotificationDetailPresentation.Section> {
    val lines = messageLines(message)
    if (lines.isEmpty()) {
        return makeGenericSections(message)
    }

    val summaryRows = mutableListOf<LmsNotificationDetailPresentation.Section.Row>()
    val descriptionRows = mutableListOf<LmsNotificationDetailPresentation.Section.Row>()
    val activityURI = extractReminderActivityURI(notification.htmlBody)

    lines.firstOrNull()?.let { firstLine ->
        val titleInfo = splitReminderTitle(firstLine)
        summaryRows += LmsNotificationDetailPresentation.Section.Row(
            id = makeRowID(sectionID = "reminder-summary", index = 0, label = "タイトル"),
            label = "タイトル",
            content = LmsNotificationDetailPresentation.Section.Row.Content.Text(titleInfo.title),
        )

        titleInfo.status?.let { status ->
            summaryRows += LmsNotificationDetailPresentation.Section.Row(
                id = makeRowID(sectionID = "reminder-summary", index = 1, label = "状態"),
                label = "状態",
                content = LmsNotificationDetailPresentation.Section.Row.Content.Text(status),
            )
        }
    }

    var rowIndex = summaryRows.size
    for (line in lines.drop(1)) {
        val labelValue = parseLabelValue(line) ?: continue
        val label = labelValue.first
        val value = decodeHTMLEntities(labelValue.second)
        val labelKey = normalizedLabel(label)

        if (labelKey == "説明") {
            descriptionRows += LmsNotificationDetailPresentation.Section.Row(
                id = makeRowID(
                    sectionID = "reminder-description",
                    index = descriptionRows.size,
                    label = null,
                ),
                label = null,
                content = LmsNotificationDetailPresentation.Section.Row.Content.Html(value),
            )
            continue
        }

        val content = if (labelKey == "活動" && activityURI != null) {
            LmsNotificationDetailPresentation.Section.Row.Content.Link(title = value, uri = activityURI)
        } else {
            LmsNotificationDetailPresentation.Section.Row.Content.Text(value)
        }

        summaryRows += LmsNotificationDetailPresentation.Section.Row(
            id = makeRowID(sectionID = "reminder-summary", index = rowIndex, label = label),
            label = label,
            content = content,
        )
        rowIndex += 1
    }

    val sections = mutableListOf<LmsNotificationDetailPresentation.Section>()
    if (summaryRows.isNotEmpty()) {
        sections += LmsNotificationDetailPresentation.Section(
            id = "reminder-summary",
            title = "概要",
            rows = summaryRows,
        )
    }
    if (descriptionRows.isNotEmpty()) {
        sections += LmsNotificationDetailPresentation.Section(
            id = "reminder-description",
            title = "説明",
            rows = descriptionRows,
        )
    }

    return sections.ifEmpty { makeGenericSections(message) }
}

private fun makeGenericSections(message: String): List<LmsNotificationDetailPresentation.Section> {
    val rows = messageLines(message).mapIndexedNotNull { index, line ->
        makeGenericRow(line = line, sectionID = "body", rowIndex = index)
    }

    if (rows.isEmpty()) {
        return emptyList()
    }

    return listOf(
        LmsNotificationDetailPresentation.Section(
            id = "body",
            title = "本文",
            rows = rows,
        ),
    )
}

private fun makeGenericRow(
    line: String,
    sectionID: String,
    rowIndex: Int,
): LmsNotificationDetailPresentation.Section.Row? {
    val trimmedLine = trimWhitespace(line)
    if (trimmedLine.isEmpty() || isSeparatorLine(trimmedLine) || trimmedLine == "Links:") {
        return null
    }

    val link = parseLinkLine(trimmedLine)
    if (link != null) {
        return LmsNotificationDetailPresentation.Section.Row(
            id = makeRowID(sectionID = sectionID, index = rowIndex, label = null),
            label = null,
            content = LmsNotificationDetailPresentation.Section.Row.Content.Link(
                title = link.first,
                uri = link.second,
            ),
        )
    }

    if (trimmedLine.startsWith("* ") || trimmedLine.startsWith("• ")) {
        return LmsNotificationDetailPresentation.Section.Row(
            id = makeRowID(sectionID = sectionID, index = rowIndex, label = null),
            label = null,
            content = LmsNotificationDetailPresentation.Section.Row.Content.Text("• ${trimmedLine.drop(2)}"),
        )
    }

    return LmsNotificationDetailPresentation.Section.Row(
        id = makeRowID(sectionID = sectionID, index = rowIndex, label = null),
        label = null,
        content = LmsNotificationDetailPresentation.Section.Row.Content.Text(decodeHTMLEntities(trimmedLine)),
    )
}

private fun parseLabelValue(line: String): Pair<String, String>? {
    val trimmedLine = trimWhitespace(line)
    val separatorIndex = trimmedLine.indexOf(':')
    if (separatorIndex < 0) {
        return null
    }

    val label = trimmedLine.substring(0, separatorIndex).trim()
    val value = trimmedLine.substring(separatorIndex + 1).trim()
    if (label.isEmpty() || value.isEmpty()) {
        return null
    }

    return decodeHTMLEntities(label) to value
}

private fun parseLinkLine(line: String): Pair<String, URI>? {
    val trimmedLine = trimWhitespace(line)
    val numberedMatch = Regex("""^\[(\d+)]\s+(https?://.+)$""", RegexOption.IGNORE_CASE)
        .find(trimmedLine)
    if (numberedMatch != null) {
        val number = numberedMatch.groupValues[1]
        val uriString = decodeHTMLEntities(numberedMatch.groupValues[2])
        val uri = runCatching { URI(uriString) }.getOrNull()
        if (uri != null) {
            return "リンク $number" to uri
        }
    }

    if (trimmedLine.startsWith("http://") || trimmedLine.startsWith("https://")) {
        val uriString = decodeHTMLEntities(trimmedLine)
        val uri = runCatching { URI(uriString) }.getOrNull()
        if (uri != null) {
            return uri.toString() to uri
        }
    }

    return null
}

private fun splitReminderTitle(line: String): ReminderTitle {
    val trimmedLine = trimWhitespace(line)
    val match = Regex("""^(.*?)(?:\s+(\[[^\]]+]))?$""", RegexOption.IGNORE_CASE)
        .find(trimmedLine)
        ?: return ReminderTitle(title = decodeHTMLEntities(trimmedLine), status = null)

    val title = decodeHTMLEntities(match.groupValues[1].trim())
    val status = match.groups[2]?.value?.takeIf { it.isNotEmpty() }?.let(::decodeHTMLEntities)
    return ReminderTitle(title = title, status = status)
}

private fun extractReminderActivityURI(html: String?): URI? {
    if (html.isNullOrEmpty()) {
        return null
    }

    val match = Regex(
        """(?is)<tr><td[^>]*>\s*活動\s*</td><td>\s*<a[^>]*href="([^"]+)"""",
    ).find(html)
    val rawURI = match?.groupValues?.getOrNull(1) ?: return null
    return runCatching { URI(decodeHTMLEntities(rawURI)) }.getOrNull()
}

private fun messageLines(message: String): List<String> =
    message
        .replace("\r\n", "\n")
        .replace("\r", "\n")
        .split("\n")
        .map(::trimWhitespace)
        .filter { it.isNotEmpty() }

private fun normalizedEventType(value: String?): String =
    trimmedValue(value)?.lowercase() ?: ""

private fun normalizedLabel(value: String): String =
    trimWhitespace(value).lowercase()

private fun trimWhitespace(value: String): String =
    value.trim()

private fun trimmedValue(value: String?): String? =
    value?.trim()?.ifEmpty { null }

private fun decodeHTMLEntities(value: String): String =
    value
        .replace("&nbsp;", " ")
        .replace("&amp;", "&")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&quot;", "\"")
        .replace("&#39;", "'")

private fun isSeparatorLine(value: String): Boolean =
    Regex("""^[\-=＿ー—\s]+$""").matches(value)

private fun makeRowID(sectionID: String, index: Int, label: String?): String =
    if (!label.isNullOrEmpty()) "$sectionID-$index-$label" else "$sectionID-$index"

private data class ReminderTitle(
    val title: String,
    val status: String?,
)
