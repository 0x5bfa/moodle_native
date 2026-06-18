package dev.example.moodlenative.networking

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class CourseSection(
    val id: Int,
    val section: Int? = null,
    val name: String,
    val summary: String? = null,
    val modules: List<CourseModule> = emptyList(),
)

@Serializable
data class CourseModule(
    val id: Int,
    @SerialName("instance")
    val instanceID: Int? = null,
    @SerialName("modname")
    val modName: String,
    val name: String,
    val url: String? = null,
    @SerialName("modicon")
    val iconURL: String? = null,
    val purpose: String? = null,
    val completion: Int? = null,
    @SerialName("completiondata")
    val completionData: ModuleCompletionData? = null,
    val contents: List<ModuleContent> = emptyList(),
    val dates: List<ModuleDate> = emptyList(),
)

@Serializable
data class ModuleCompletionData(
    val state: Int? = null,
    @SerialName("hascompletion")
    val hasCompletion: Boolean = false,
    @SerialName("uservisible")
    val userVisible: Boolean = false,
    val details: List<Detail> = emptyList(),
    @SerialName("isoverallcomplete")
    val isOverallComplete: Boolean = false,
) {
    @Serializable
    data class Detail(
        @SerialName("rulename")
        val ruleName: String,
        @SerialName("rulevalue")
        val ruleValue: RuleValue? = null,
    ) {
        @Serializable
        data class RuleValue(
            val status: Int? = null,
            val description: String? = null,
        )
    }

    val summary: LmsModuleCompletionSummary?
        get() {
            if (!hasCompletion || !userVisible) {
                return null
            }

            val ruleStatuses = details.map { maxOf(it.ruleValue?.status ?: 0, 0) }
            val totalRuleCount = maxOf(ruleStatuses.size, 1)
            val completedRuleCount = if (details.isEmpty()) {
                if (isOverallComplete || state == 1) 1 else 0
            } else {
                ruleStatuses.count { it > 0 }
            }
            val clampedCompletedRuleCount = completedRuleCount.coerceIn(0, totalRuleCount)
            val isComplete = isOverallComplete || clampedCompletedRuleCount == totalRuleCount
            val progress = if (isComplete) {
                1.0
            } else {
                clampedCompletedRuleCount.toDouble() / totalRuleCount.toDouble()
            }

            return LmsModuleCompletionSummary(
                progress = progress,
                completedRequirementCount = clampedCompletedRuleCount,
                totalRequirementCount = totalRuleCount,
                isComplete = isComplete,
                accessibilityLabel = completionAccessibilityLabel(
                    completedRequirementCount = clampedCompletedRuleCount,
                    totalRequirementCount = totalRuleCount,
                    isComplete = isComplete,
                ),
            )
        }

    val requirements: List<LmsModuleCompletionRequirement>
        get() {
            if (!hasCompletion || !userVisible) {
                return emptyList()
            }

            return details.mapNotNull { detail ->
                val text = detail.ruleValue?.description?.trim()
                val fallbackText = fallbackRequirementText(detail.ruleName)
                val resolvedText = listOfNotNull(text, fallbackText)
                    .map { it.trim() }
                    .firstOrNull { it.isNotEmpty() }
                    ?: return@mapNotNull null

                LmsModuleCompletionRequirement(
                    id = detail.ruleName,
                    text = resolvedText,
                    isComplete = maxOf(detail.ruleValue?.status ?: 0, 0) > 0,
                )
            }
        }

    private fun completionAccessibilityLabel(
        completedRequirementCount: Int,
        totalRequirementCount: Int,
        isComplete: Boolean,
    ): String {
        if (totalRequirementCount <= 1) {
            return if (isComplete) "完了" else "未完了"
        }

        if (isComplete) {
            return "完了 $completedRequirementCount/$totalRequirementCount"
        }

        return "$completedRequirementCount/$totalRequirementCount 条件を完了"
    }

    private fun fallbackRequirementText(ruleName: String): String? =
        when (ruleName.trim().lowercase()) {
            "completionview" -> "閲覧する"
            "completionsubmit" -> "提出する"
            "completionposts" -> "フォーラム投稿を作成する"
            "completionreplies" -> "返信する"
            "completiondiscussions" -> "ディスカッションを開始する"
            "completionminattempts" -> "受験する"
            else -> null
        }
}

@Serializable
data class ModuleContent(
    val type: String? = null,
    @SerialName("filename")
    val fileName: String? = null,
    @SerialName("filepath")
    val filePath: String? = null,
    @SerialName("filesize")
    val fileSize: Int? = null,
    @SerialName("fileurl")
    val fileURL: String? = null,
    @SerialName("mimetype")
    val mimeType: String? = null,
    @SerialName("timemodified")
    val timeModified: Int? = null,
) {
    val id: String
        get() = listOfNotNull(type, filePath, fileName, fileURL).joinToString("|")
}

@Serializable
data class ModuleDate(
    val label: String,
    val timestamp: Int,
    @SerialName("dataid")
    val dataID: String,
) {
    val id: String
        get() = dataID
}
