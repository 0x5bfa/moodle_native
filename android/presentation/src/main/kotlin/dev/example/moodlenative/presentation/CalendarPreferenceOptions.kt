package dev.example.moodlenative.presentation

data class PreferenceOption(
    val value: String,
    val label: String,
)

val calendarWeekdayOptions = listOf(
    PreferenceOption("0", "日"),
    PreferenceOption("1", "月"),
    PreferenceOption("2", "火"),
    PreferenceOption("3", "水"),
    PreferenceOption("4", "木"),
    PreferenceOption("5", "金"),
    PreferenceOption("6", "土"),
)
