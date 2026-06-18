package dev.example.moodlenative.features

data class LmsDashboardSnapshot(
    val siteURL: String,
    val userID: Int?,
    val courses: List<LmsDashboardCourse>,
    val dashboardBlocks: List<LmsDashboardBlock>,
)

data class LmsDashboardCourse(
    val id: Int,
    val fullName: String,
    val displayName: String? = null,
    val shortName: String,
    val summary: String? = null,
    val courseImage: String? = null,
    val progress: Double? = null,
    val isFavorite: Boolean? = null,
)

data class LmsDashboardBlock(
    val instanceID: Int,
    val name: String,
    val region: String? = null,
    val positionID: Int? = null,
    val visible: Boolean? = null,
    val contents: Contents? = null,
) {
    data class Contents(
        val title: String? = null,
        val content: String? = null,
        val contentFormat: Int? = null,
        val footer: String? = null,
    )
}

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

data class LmsCourseModule(
    val id: Int,
    val instanceID: Int? = null,
    val modName: String,
    val name: String,
    val url: String? = null,
    val completionRequirements: List<LmsModuleCompletionRequirement> = emptyList(),
)
