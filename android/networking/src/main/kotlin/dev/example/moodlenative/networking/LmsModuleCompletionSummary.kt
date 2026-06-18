package dev.example.moodlenative.networking

data class LmsModuleCompletionSummary(
    val progress: Double,
    val completedRequirementCount: Int,
    val totalRequirementCount: Int,
    val isComplete: Boolean,
    val accessibilityLabel: String,
) {
    val isInProgress: Boolean
        get() = !isComplete && progress > 0.0
}
