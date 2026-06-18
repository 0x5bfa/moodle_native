package dev.example.moodlenative.features

import dev.example.moodlenative.core.LmsAssignmentItem
import java.net.URI
import java.time.Instant

data class LmsAssignmentReference(
    val assignmentID: Int,
    val courseModuleID: Int,
    val courseID: Int?,
    val courseTitle: String?,
    val courseShortName: String?,
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
    val detailURL: URI?,
    val completionRequirements: List<LmsModuleCompletionRequirement> = emptyList(),
) {
    val id: Int
        get() = assignmentID

    val displayCourseTitle: String?
        get() = courseTitle?.trim()?.takeIf { it.isNotEmpty() }

    val hasOverviewDetails: Boolean
        get() = allowsSubmissionsFromDate != null ||
            dueDate != null ||
            cutoffDate != null ||
            introPreview?.trim()?.isNotEmpty() == true

    fun merging(courseModule: LmsCourseModule): LmsAssignmentReference {
        val mergedDetailURL = detailURL ?: courseModule.url?.let { url ->
            runCatching { URI(url) }.getOrNull()
        }
        val mergedRequirements = if (completionRequirements.isEmpty()) {
            courseModule.completionRequirements
        } else {
            completionRequirements
        }

        return copy(
            detailURL = mergedDetailURL,
            completionRequirements = mergedRequirements,
        )
    }
}

fun LmsAssignmentItem.reference(siteURL: String): LmsAssignmentReference =
    LmsAssignmentReference(
        assignmentID = id,
        courseModuleID = courseModuleID,
        courseID = courseID,
        courseTitle = courseTitle,
        courseShortName = courseShortName,
        title = title,
        introPreview = introPreview,
        dueDate = dueDate,
        allowsSubmissionsFromDate = allowsSubmissionsFromDate,
        cutoffDate = cutoffDate,
        updatedAt = updatedAt,
        submissionDrafts = submissionDrafts,
        requiresSubmissionStatement = requiresSubmissionStatement,
        submissionStatement = submissionStatement,
        timeLimit = timeLimit,
        enabledSubmissionPluginTypes = enabledSubmissionPluginTypes,
        onlineTextWordLimit = onlineTextWordLimit,
        detailURL = assignmentDetailURL(baseSiteURL = siteURL, courseModuleID = courseModuleID),
        completionRequirements = emptyList(),
    )

private fun assignmentDetailURL(baseSiteURL: String, courseModuleID: Int): URI? {
    val baseURL = runCatching { URI(baseSiteURL.trim()) }.getOrNull() ?: return null
    if (baseURL.scheme.isNullOrEmpty() || baseURL.authority.isNullOrEmpty()) {
        return null
    }

    return runCatching {
        URI("${baseURL.scheme}://${baseURL.authority}/mod/assign/view.php?id=$courseModuleID")
    }.getOrNull()
}
