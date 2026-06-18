package dev.example.moodlenative.features

data class LmsAssignmentFile(
    val fileName: String? = null,
    val filePath: String? = null,
    val fileSize: Int? = null,
    val fileURL: String? = null,
    val mimeType: String? = null,
    val timeModified: Int? = null,
    val isExternalFile: Boolean = false,
    val repositoryType: String? = null,
) {
    val id: String
        get() = listOfNotNull(fileName, filePath, fileURL, mimeType).joinToString("|")
}

data class LmsAssignmentPluginFileArea(
    val area: String = "",
    val files: List<LmsAssignmentFile> = emptyList(),
) {
    val id: String
        get() = area
}

data class LmsAssignmentPluginEditorField(
    val name: String = "",
    val description: String = "",
    val text: String? = null,
    val format: Int? = null,
) {
    val id: String
        get() = name
}

data class LmsAssignmentPlugin(
    val type: String = "",
    val name: String = "",
    val fileAreas: List<LmsAssignmentPluginFileArea> = emptyList(),
    val editorFields: List<LmsAssignmentPluginEditorField> = emptyList(),
) {
    val id: String
        get() = "$type|$name"
}

data class LmsAssignmentSubmission(
    val id: Int = 0,
    val userID: Int = 0,
    val attemptNumber: Int = 0,
    val timeCreated: Int = 0,
    val timeModified: Int = 0,
    val timeStarted: Int? = null,
    val status: String = "",
    val groupID: Int = 0,
    val assignmentID: Int? = null,
    val latest: Int? = null,
    val plugins: List<LmsAssignmentPlugin> = emptyList(),
    val gradingStatus: String? = null,
)

data class LmsAssignmentGrade(
    val id: Int = 0,
    val assignmentID: Int? = null,
    val userID: Int = 0,
    val attemptNumber: Int = 0,
    val timeCreated: Int = 0,
    val timeModified: Int = 0,
    val grader: Int = 0,
    val grade: String = "",
    val gradeForDisplay: String? = null,
)

data class LmsAssignmentLastAttempt(
    val submission: LmsAssignmentSubmission? = null,
    val teamSubmission: LmsAssignmentSubmission? = null,
    val submissionGroup: Int? = null,
    val submissionGroupMembersWhoNeedToSubmit: List<Int> = emptyList(),
    val submissionsEnabled: Boolean = false,
    val locked: Boolean = false,
    val graded: Boolean = false,
    val canEdit: Boolean = false,
    val canEditOwner: Boolean = false,
    val canSubmit: Boolean = false,
    val extensionDueDate: Int = 0,
    val timeLimit: Int? = null,
    val blindMarking: Boolean = false,
    val gradingStatus: String = "",
    val userGroups: List<Int> = emptyList(),
)

data class LmsAssignmentFeedback(
    val grade: LmsAssignmentGrade? = null,
    val gradeForDisplay: String? = null,
    val gradedDate: Int? = null,
    val plugins: List<LmsAssignmentPlugin> = emptyList(),
)

data class LmsAssignmentDataAttachments(
    val intro: List<LmsAssignmentFile> = emptyList(),
    val activity: List<LmsAssignmentFile> = emptyList(),
)

data class LmsAssignmentData(
    val attachments: LmsAssignmentDataAttachments? = null,
    val activity: String? = null,
    val activityFormat: Int? = null,
)

data class LmsAssignmentWarning(
    val item: String? = null,
    val itemID: Int? = null,
    val warningCode: String? = null,
    val message: String? = null,
) {
    val id: String
        get() = listOf(
            item.orEmpty(),
            itemID?.toString().orEmpty(),
            warningCode.orEmpty(),
            message.orEmpty(),
        ).joinToString("|")
}

data class LmsAssignmentSubmissionStatus(
    val lastAttempt: LmsAssignmentLastAttempt? = null,
    val feedback: LmsAssignmentFeedback? = null,
    val assignmentData: LmsAssignmentData? = null,
    val warnings: List<LmsAssignmentWarning> = emptyList(),
)
