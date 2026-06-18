package dev.example.moodlenative.core

object LmsHTMLTextFormatter {
    fun plainText(html: String?): String? {
        if (html.isNullOrEmpty()) {
            return null
        }

        val withParagraphBreaks = html
            .replace(Regex("(?i)<\\s*br\\s*/?>|</p>|</div>|</li>|</h[1-6]>"), "\n")
            .replace(Regex("(?i)<li[^>]*>"), "• ")
        val withoutTags = withParagraphBreaks.replace(Regex("<[^>]+>"), " ")
        val decodedEntities = withoutTags
            .replace("&nbsp;", " ")
            .replace("&amp;", "&")
            .replace("&lt;", "<")
            .replace("&gt;", ">")
            .replace("&quot;", "\"")
            .replace("&#39;", "'")

        val normalizedLines = decodedEntities
            .replace("\r\n", "\n")
            .lines()
            .map { it.replace(Regex("\\s+"), " ").trim() }
            .filter { it.isNotEmpty() }

        return normalizedLines.ifEmpty { null }?.joinToString(separator = "\n\n")
    }
}
