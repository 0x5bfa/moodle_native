package dev.example.moodlenative.features

import dev.example.moodlenative.core.LmsNotificationItem

val LmsNotificationItem.bodyText: String
    get() = listOf(plainBody, preview)
        .mapNotNull { it?.trim() }
        .firstOrNull { it.isNotEmpty() }
        ?: "本文を表示できませんでした。"

val LmsNotificationItem.htmlDocument: String?
    get() {
        val html = sanitizedHTML(htmlBody) ?: return null
        return """
            <!doctype html>
            <html lang="ja">
            <head>
              <meta charset="utf-8">
              <meta name="viewport" content="width=device-width, initial-scale=1">
              <style>
                :root {
                  color-scheme: light dark;
                  font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
                }
                body {
                  margin: 0;
                  padding: 0;
                  font: -apple-system-body;
                  line-height: 1.6;
                  word-break: break-word;
                }
                img, video, iframe {
                  max-width: 100%;
                  height: auto;
                }
                table {
                  width: 100%;
                  border-collapse: collapse;
                }
                th, td {
                  border: 1px solid rgba(128, 128, 128, 0.25);
                  padding: 6px 8px;
                }
                pre, code {
                  white-space: pre-wrap;
                  word-break: break-word;
                }
              </style>
            </head>
            <body>
            $html
            </body>
            </html>
        """.trimIndent()
    }

val LmsNotificationItem.metadataItems: List<Pair<String, String>>
    get() = listOfNotNull(
        "状態" to if (isUnread) "未読" else "既読",
        contextName?.let { "リンク先" to it },
        trimmedValue(component)?.let { "component" to it },
        trimmedValue(eventType)?.let { "eventtype" to it },
    )

private fun sanitizedHTML(value: String?): String? {
    val trimmed = trimmedValue(value) ?: return null
    return if (Regex("<[^>]+>").containsMatchIn(trimmed)) trimmed else null
}

private fun trimmedValue(value: String?): String? =
    value?.trim()?.ifEmpty { null }
