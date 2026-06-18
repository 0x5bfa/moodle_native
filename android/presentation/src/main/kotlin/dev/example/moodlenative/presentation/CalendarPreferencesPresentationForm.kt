package dev.example.moodlenative.presentation

data class CalendarPreferencesPresentationForm(
    val timeFormat: String = "0",
    val startWeekday: String = "1",
    val maxEvents: String = "10",
    val lookAhead: String = "21",
    val persistFilters: Boolean = false,
)
