package dev.example.moodlenative.features

import dev.example.moodlenative.core.LmsAssignmentItem
import dev.example.moodlenative.core.LmsHTMLTextFormatter
import java.time.Instant

data class AssignmentDetailPresentation(
    val loadedAt: Instant,
    val statusRows: List<AssignmentDetailRowPresentation>,
    val editor: AssignmentSubmissionEditorPresentation?,
    val actions: AssignmentSubmissionActionsPresentation,
)

data class AssignmentDetailRowPresentation(
    val label: String,
    val value: String,
)

data class AssignmentSubmissionEditorPresentation(
    val submissionID: Int?,
    val initialOnlineText: String,
    val initialFiles: List<AssignmentSubmissionFilePresentation>,
    val allowsOnlineText: Boolean,
    val allowsFile: Boolean,
    val wordLimit: Int?,
)

data class AssignmentSubmissionFilePresentation(
    val fileName: String,
    val mimeType: String,
    val fileURL: String?,
    val metadataLabel: String,
)

data class AssignmentSubmissionActionsPresentation(
    val canStart: Boolean,
    val canSubmit: Boolean,
    val canRemove: Boolean,
    val removeUserID: Int?,
)

fun LmsAssignmentSubmissionStatus.detailPresentation(
    assignment: LmsAssignmentItem,
    loadedAt: Instant,
): AssignmentDetailPresentation {
    val lastAttempt = lastAttempt
    val submission = lastAttempt?.submission ?: lastAttempt?.teamSubmission
    val pluginTypes = assignment.submissionPluginTypes(submission)
    val allowsOnlineText = pluginTypes.contains("onlinetext")
    val allowsFile = pluginTypes.contains("file")
    val canEdit = lastAttempt?.let { attempt ->
        attempt.submissionsEnabled && !attempt.locked && attempt.canEdit
    } ?: false
    val timeLimit = assignment.timeLimit ?: lastAttempt?.timeLimit ?: 0

    return AssignmentDetailPresentation(
        loadedAt = loadedAt,
        statusRows = statusRows(),
        editor = if (canEdit && (allowsOnlineText || allowsFile)) {
            AssignmentSubmissionEditorPresentation(
                submissionID = submission?.id,
                initialOnlineText = submission?.onlineTextPlainText.orEmpty(),
                initialFiles = submission?.submissionFiles.orEmpty().map { file -> file.presentation },
                allowsOnlineText = allowsOnlineText,
                allowsFile = allowsFile,
                wordLimit = assignment.onlineTextWordLimit,
            )
        } else {
            null
        },
        actions = AssignmentSubmissionActionsPresentation(
            canStart = lastAttempt != null &&
                timeLimit > 0 &&
                submission?.startedAtEpochSeconds == null &&
                submission?.isSubmitted != true,
            canSubmit = lastAttempt?.canSubmit == true,
            canRemove = lastAttempt?.canEdit == true && submission?.isExistingSubmissionForEditing == true,
            removeUserID = submission?.userID?.takeIf { it > 0 },
        ),
    )
}

fun LmsAssignmentSubmissionStatus.statusRows(): List<AssignmentDetailRowPresentation> {
    val lastAttempt = lastAttempt
    val submission = lastAttempt?.submission ?: lastAttempt?.teamSubmission
    val rows = mutableListOf(
        AssignmentDetailRowPresentation(
            label = "提出状態",
            value = submission?.status?.ifBlank { null } ?: "未提出",
        ),
    )

    lastAttempt?.gradingStatus?.takeIf { it.isNotBlank() }?.let { gradingStatus ->
        rows += AssignmentDetailRowPresentation("採点状態", gradingStatus)
    }

    val gradeDisplay = feedback?.gradeForDisplay?.takeIf { it.isNotBlank() }
        ?: feedback?.grade?.gradeForDisplay?.takeIf { it.isNotBlank() }
    gradeDisplay?.let { grade ->
        rows += AssignmentDetailRowPresentation("評点", grade)
    }

    assignmentData?.attachments?.let { attachments ->
        val count = attachments.intro.size + attachments.activity.size
        if (count > 0) {
            rows += AssignmentDetailRowPresentation("添付", "${count} 件")
        }
    }

    warnings.mapNotNull { warning -> warning.message?.takeIf(String::isNotBlank) }
        .firstOrNull()
        ?.let { message -> rows += AssignmentDetailRowPresentation("警告", message) }

    return rows
}

private fun LmsAssignmentItem.submissionPluginTypes(submission: LmsAssignmentSubmission?): Set<String> {
    enabledSubmissionPluginTypes?.let { configuredTypes ->
        return configuredTypes.map { it.trim().lowercase() }.filter { it.isNotEmpty() }.toSet()
    }

    return submission?.plugins
        ?.map { it.type.trim().lowercase() }
        ?.filter { it.isNotEmpty() }
        ?.toSet()
        ?: emptySet()
}

private val LmsAssignmentSubmission.onlineTextPlainText: String?
    get() {
        val htmlText = plugins
            .firstOrNull { it.type.trim().lowercase() == "onlinetext" }
            ?.editorFields
            ?.firstOrNull()
            ?.text

        return LmsHTMLTextFormatter.plainText(htmlText) ?: htmlText
    }

private val LmsAssignmentSubmission.submissionFiles: List<LmsAssignmentFile>
    get() = plugins
        .filter { it.type.trim().lowercase() == "file" }
        .flatMap { it.fileAreas }
        .flatMap { it.files }

private val LmsAssignmentFile.presentation: AssignmentSubmissionFilePresentation
    get() {
        val mimeType = mimeType?.takeIf { it.isNotBlank() } ?: "application/octet-stream"
        return AssignmentSubmissionFilePresentation(
            fileName = displayFileName,
            mimeType = mimeType,
            fileURL = fileURL?.takeIf { it.isNotBlank() },
            metadataLabel = "$mimeType / 既存ファイル",
        )
    }

private val LmsAssignmentFile.displayFileName: String
    get() = fileName?.trim()?.takeIf { it.isNotEmpty() } ?: "submission-file"

private val LmsAssignmentSubmission.normalizedStatus: String
    get() = status.trim().lowercase()

private val LmsAssignmentSubmission.isSubmitted: Boolean
    get() = normalizedStatus == "submitted"

private val LmsAssignmentSubmission.isExistingSubmissionForEditing: Boolean
    get() = normalizedStatus.isNotEmpty() &&
        normalizedStatus != "new" &&
        normalizedStatus != "reopened"

private val LmsAssignmentSubmission.startedAtEpochSeconds: Int?
    get() = timeStarted?.takeIf { it > 0 }
