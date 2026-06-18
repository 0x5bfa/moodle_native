package dev.example.moodlenative.networking

data class LmsModuleCompletionRequirement(
    val id: String,
    val text: String,
    val isComplete: Boolean,
) {
    val symbolName: String
        get() = if (isComplete) "checkmark.circle.fill" else "checkmark.circle.dotted"

    val accessibilityLabel: String
        get() = "$text、${if (isComplete) "完了" else "未完了"}"
}
