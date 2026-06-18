package dev.example.moodlenative.data

import dev.example.moodlenative.core.LmsAssignmentItem
import dev.example.moodlenative.core.LmsAuthenticationSession
import dev.example.moodlenative.storage.AppSessionSnapshot
import dev.example.moodlenative.storage.AppSessionStore
import java.time.Instant

class MoodleNativeAssignmentActionRepository internal constructor(
    private val sessionStore: AppSessionStore,
    private val gatewayFactory: (LmsAuthenticationSession) -> AssignmentActionGateway = { session ->
        LmsAssignmentActionWebServiceGateway(session)
    },
    private val now: () -> Instant = { Instant.now() },
) {
    constructor(sessionStore: AppSessionStore) : this(
        sessionStore = sessionStore,
        gatewayFactory = { session -> LmsAssignmentActionWebServiceGateway(session) },
        now = { Instant.now() },
    )

    suspend fun saveSubmission(
        assignment: LmsAssignmentItem,
        fileDraftItemID: Int? = null,
        onlineTextHTML: String? = null,
    ): LiveAssignmentActionResult {
        val onlineText = onlineTextHTML?.let { html -> AssignmentSubmissionOnlineTextInput(html = html) }
        return perform(
            action = AssignmentAction.SaveSubmission(
                assignment = assignment,
                fileDraftItemID = fileDraftItemID,
                onlineText = onlineText,
            ),
        ) { gateway ->
            gateway.saveAssignmentSubmission(
                assignmentID = assignment.id,
                fileDraftItemID = fileDraftItemID,
                onlineText = onlineText,
            )
        }
    }

    suspend fun uploadAndSaveSubmission(
        assignment: LmsAssignmentItem,
        files: List<AssignmentSubmissionFileInput>?,
        onlineTextHTML: String? = null,
    ): LiveAssignmentActionResult {
        val onlineText = onlineTextHTML?.let { html -> AssignmentSubmissionOnlineTextInput(html = html) }
        return perform(
            action = AssignmentAction.SaveSubmission(
                assignment = assignment,
                fileDraftItemID = null,
                onlineText = onlineText,
                fileCount = files?.size,
            ),
        ) { gateway ->
            val fileDraftItemID = files?.let { changedFiles ->
                if (changedFiles.isEmpty()) {
                    0
                } else {
                    gateway.uploadAssignmentSubmissionFiles(
                        changedFiles.map { file -> file.resolvedUploadFile(gateway) },
                    )
                }
            }
            gateway.saveAssignmentSubmission(
                assignmentID = assignment.id,
                fileDraftItemID = fileDraftItemID,
                onlineText = onlineText,
            )
        }
    }

    suspend fun submitForGrading(
        assignment: LmsAssignmentItem,
        acceptsSubmissionStatement: Boolean = true,
    ): LiveAssignmentActionResult =
        perform(
            action = AssignmentAction.SubmitForGrading(
                assignment = assignment,
                acceptsSubmissionStatement = acceptsSubmissionStatement,
            ),
        ) { gateway ->
            gateway.submitAssignmentForGrading(
                assignmentID = assignment.id,
                acceptsSubmissionStatement = acceptsSubmissionStatement,
            )
        }

    suspend fun startSubmission(assignment: LmsAssignmentItem): LiveAssignmentActionResult =
        perform(action = AssignmentAction.StartSubmission(assignment)) { gateway ->
            gateway.startAssignmentSubmission(assignmentID = assignment.id)
        }

    suspend fun removeSubmission(
        assignment: LmsAssignmentItem,
        userID: Int?,
    ): LiveAssignmentActionResult {
        val action = AssignmentAction.RemoveSubmission(assignment = assignment, userID = userID)
        val snapshot = sessionStore.readSnapshot()
        val session = snapshot.lmsSession ?: return LiveAssignmentActionResult.MissingSession(snapshot, action)
        if (userID == null || userID <= 0) {
            return LiveAssignmentActionResult.MissingUserID(
                snapshot = snapshot,
                action = action,
            )
        }

        val gateway = gatewayFactory(session)
        val completedAt = now()
        return try {
            gateway.removeAssignmentSubmission(
                assignmentID = assignment.id,
                userID = userID,
            )
            LiveAssignmentActionResult.Completed(
                snapshot = sessionStore.readSnapshot(),
                action = action,
                completedAt = completedAt,
            )
        } catch (error: Exception) {
            LiveAssignmentActionResult.Failed(
                snapshot = sessionStore.readSnapshot(),
                action = action,
                message = error.message ?: "課題提出を更新できませんでした。",
            )
        }
    }

    private suspend fun perform(
        action: AssignmentAction,
        block: suspend (AssignmentActionGateway) -> Unit,
    ): LiveAssignmentActionResult {
        val snapshot = sessionStore.readSnapshot()
        val session = snapshot.lmsSession ?: return LiveAssignmentActionResult.MissingSession(snapshot, action)
        val gateway = gatewayFactory(session)
        val completedAt = now()

        return try {
            block(gateway)
            LiveAssignmentActionResult.Completed(
                snapshot = sessionStore.readSnapshot(),
                action = action,
                completedAt = completedAt,
            )
        } catch (error: Exception) {
            LiveAssignmentActionResult.Failed(
                snapshot = sessionStore.readSnapshot(),
                action = action,
                message = error.message ?: "課題提出を更新できませんでした。",
            )
        }
    }

    private suspend fun AssignmentSubmissionFileInput.resolvedUploadFile(
        gateway: AssignmentActionGateway,
    ): AssignmentSubmissionFileInput {
        if (data != null) {
            return this
        }

        val downloaded = existingFile?.let { file -> gateway.downloadAssignmentSubmissionFile(file) }
            ?: throw IllegalStateException("提出ファイルを読み取れませんでした。")
        return downloaded.copy(
            fileName = fileName,
            mimeType = mimeType,
        )
    }
}

internal interface AssignmentActionGateway {
    suspend fun downloadAssignmentSubmissionFile(file: ExistingAssignmentSubmissionFileInput): AssignmentSubmissionFileInput

    suspend fun uploadAssignmentSubmissionFiles(files: List<AssignmentSubmissionFileInput>): Int

    suspend fun saveAssignmentSubmission(
        assignmentID: Int,
        fileDraftItemID: Int?,
        onlineText: AssignmentSubmissionOnlineTextInput?,
    )

    suspend fun submitAssignmentForGrading(
        assignmentID: Int,
        acceptsSubmissionStatement: Boolean,
    )

    suspend fun startAssignmentSubmission(assignmentID: Int)

    suspend fun removeAssignmentSubmission(assignmentID: Int, userID: Int)
}

sealed class AssignmentAction {
    abstract val assignment: LmsAssignmentItem

    data class SaveSubmission(
        override val assignment: LmsAssignmentItem,
        val fileDraftItemID: Int?,
        val onlineText: AssignmentSubmissionOnlineTextInput?,
        val fileCount: Int? = null,
    ) : AssignmentAction()

    data class SubmitForGrading(
        override val assignment: LmsAssignmentItem,
        val acceptsSubmissionStatement: Boolean,
    ) : AssignmentAction()

    data class StartSubmission(
        override val assignment: LmsAssignmentItem,
    ) : AssignmentAction()

    data class RemoveSubmission(
        override val assignment: LmsAssignmentItem,
        val userID: Int?,
    ) : AssignmentAction()
}

data class AssignmentSubmissionOnlineTextInput(
    val html: String,
    val format: Int = 1,
    val draftItemID: Int = 0,
)

data class AssignmentSubmissionFileInput(
    val fileName: String,
    val mimeType: String,
    val data: ByteArray? = null,
    val existingFile: ExistingAssignmentSubmissionFileInput? = null,
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is AssignmentSubmissionFileInput) return false

        return fileName == other.fileName &&
            mimeType == other.mimeType &&
            data.contentEqualsOrNull(other.data) &&
            existingFile == other.existingFile
    }

    override fun hashCode(): Int {
        var result = fileName.hashCode()
        result = 31 * result + mimeType.hashCode()
        result = 31 * result + (data?.contentHashCode() ?: 0)
        result = 31 * result + (existingFile?.hashCode() ?: 0)
        return result
    }

    private fun ByteArray?.contentEqualsOrNull(other: ByteArray?): Boolean =
        when {
            this == null && other == null -> true
            this == null || other == null -> false
            else -> contentEquals(other)
    }
}

data class ExistingAssignmentSubmissionFileInput(
    val fileName: String,
    val mimeType: String,
    val fileURL: String,
)

sealed class LiveAssignmentActionResult {
    abstract val snapshot: AppSessionSnapshot
    abstract val action: AssignmentAction

    data class MissingSession(
        override val snapshot: AppSessionSnapshot,
        override val action: AssignmentAction,
    ) : LiveAssignmentActionResult()

    data class MissingUserID(
        override val snapshot: AppSessionSnapshot,
        override val action: AssignmentAction.RemoveSubmission,
    ) : LiveAssignmentActionResult()

    data class Completed(
        override val snapshot: AppSessionSnapshot,
        override val action: AssignmentAction,
        val completedAt: Instant,
    ) : LiveAssignmentActionResult()

    data class Failed(
        override val snapshot: AppSessionSnapshot,
        override val action: AssignmentAction,
        val message: String,
    ) : LiveAssignmentActionResult()
}
