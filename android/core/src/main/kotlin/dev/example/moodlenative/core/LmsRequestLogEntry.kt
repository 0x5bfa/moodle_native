package dev.example.moodlenative.core

import java.time.Instant
import java.util.UUID

data class LmsRequestLogContext(
    val navigationPath: String,
    val pageTitle: String,
)

data class LmsRequestLogEntry(
    val id: UUID = UUID.randomUUID(),
    val occurredAt: Instant = Instant.now(),
    val context: LmsRequestLogContext,
    val wsFunction: String,
    val parameters: List<Parameter>,
    val statusCode: Int?,
    val errorMessage: String?,
    val responseBody: String,
) {
    data class Parameter(
        val name: String,
        val value: String?,
    ) {
        val displayText: String
            get() = if (value != null) "$name=$value" else "$name=<nil>"
    }

    val hasError: Boolean
        get() = errorMessage != null || statusCode?.let { it !in 200..299 } == true

    val metadataText: String
        get() = buildList {
            add("path: ${context.navigationPath}")
            add("title: ${context.pageTitle}")
            add("wsfunction: $wsFunction")
            if (parameters.isNotEmpty()) {
                add("parameters:")
                addAll(parameters.map { "  - ${it.displayText}" })
            }
            if (statusCode != null) {
                add("status: $statusCode")
            }
            if (!errorMessage.isNullOrEmpty()) {
                add("error: $errorMessage")
            }
        }.joinToString(separator = "\n")

    val displayText: String
        get() = if (responseBody.isEmpty()) {
            "$metadataText\n\n<empty response>"
        } else {
            "$metadataText\n\n$responseBody"
        }
}
