package dev.example.moodlenative.core

import java.time.Instant

data class LmsAssignmentItem(
    val id: Int,
    val courseID: Int,
    val courseModuleID: Int,
    val courseTitle: String,
    val courseCode: String? = null,
    val courseShortName: String,
    val title: String,
    val introPreview: String?,
    val dueDate: Instant?,
    val allowsSubmissionsFromDate: Instant?,
    val cutoffDate: Instant?,
    val updatedAt: Instant?,
    val submissionDrafts: Boolean? = null,
    val requiresSubmissionStatement: Boolean? = null,
    val submissionStatement: String? = null,
    val timeLimit: Int? = null,
    val enabledSubmissionPluginTypes: List<String>? = null,
    val onlineTextWordLimit: Int? = null,
) {
    enum class DueBucket(val sectionTitle: String) {
        OVERDUE("期限切れ"),
        UPCOMING("これからの課題"),
        UNDATED("期限未設定"),
    }

    fun dueBucket(now: Instant = Instant.now()): DueBucket =
        when {
            dueDate == null -> DueBucket.UNDATED
            dueDate < now -> DueBucket.OVERDUE
            else -> DueBucket.UPCOMING
        }
}
