package dev.example.moodlenative.core

data class TimetableScheduleSlot(
    val dayIndex: Int,
    val periodIndices: List<Int>,
    val room: String?,
)
