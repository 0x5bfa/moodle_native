package dev.example.moodlenative.presentation

data class AppSessionPresentationState(
    val hasLmsSession: Boolean = false,
    val lmsSessionLabel: String = "未接続",
)
