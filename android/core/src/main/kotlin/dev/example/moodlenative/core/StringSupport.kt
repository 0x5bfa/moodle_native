package dev.example.moodlenative.core

val String.lmsPathComponents: List<String>
    get() = split("/")
        .map { it.trim() }
        .filter { it.isNotEmpty() }

val String.singleLineDisplayText: String
    get() = replace("\r\n", "\n")
        .replace("\r", "\n")
        .split("\n")
        .map { it.trim() }
        .filter { it.isNotEmpty() }
        .joinToString(separator = " ")

fun String?.singleLineDisplayTextOrNull(): String? =
    this?.singleLineDisplayText?.ifEmpty { null }

internal fun String?.optionalTrimmed(): String? =
    this?.trim()?.ifEmpty { null }
