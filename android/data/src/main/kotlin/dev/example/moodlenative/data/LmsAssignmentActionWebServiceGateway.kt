package dev.example.moodlenative.data

import dev.example.moodlenative.core.LmsAuthenticationSession
import dev.example.moodlenative.networking.LmsWebServiceClient
import dev.example.moodlenative.networking.AssignmentFile as NetworkAssignmentFile
import dev.example.moodlenative.networking.AssignmentOnlineTextInput as NetworkAssignmentOnlineTextInput
import dev.example.moodlenative.networking.AssignmentSubmissionUploadFile as NetworkAssignmentSubmissionUploadFile

internal class LmsAssignmentActionWebServiceGateway(
    session: LmsAuthenticationSession,
) : AssignmentActionGateway {
    private val client = LmsWebServiceClient(session.toLmsWebServiceSession())

    override suspend fun downloadAssignmentSubmissionFile(file: ExistingAssignmentSubmissionFileInput): AssignmentSubmissionFileInput {
        val downloaded = client.downloadAssignmentSubmissionFile(
            NetworkAssignmentFile(
                fileName = file.fileName,
                fileURL = file.fileURL,
                mimeType = file.mimeType,
            ),
        )
        return AssignmentSubmissionFileInput(
            fileName = downloaded.fileName,
            mimeType = downloaded.mimeType,
            data = downloaded.data,
        )
    }

    override suspend fun uploadAssignmentSubmissionFiles(files: List<AssignmentSubmissionFileInput>): Int {
        val uploadedFiles = client.uploadAssignmentSubmissionFiles(
            files = files.map { file ->
                NetworkAssignmentSubmissionUploadFile(
                    fileName = file.fileName,
                    mimeType = file.mimeType,
                    data = file.data ?: throw IllegalStateException("提出ファイルを読み取れませんでした。"),
                )
            },
        )
        return uploadedFiles.firstOrNull()?.itemID
            ?: throw IllegalStateException("アップロード結果を取得できませんでした。")
    }

    override suspend fun saveAssignmentSubmission(
        assignmentID: Int,
        fileDraftItemID: Int?,
        onlineText: AssignmentSubmissionOnlineTextInput?,
    ) {
        client.saveAssignmentSubmission(
            assignmentID = assignmentID,
            fileDraftItemID = fileDraftItemID,
            onlineText = onlineText?.toNetworkAssignmentOnlineTextInput(),
        )
    }

    override suspend fun submitAssignmentForGrading(
        assignmentID: Int,
        acceptsSubmissionStatement: Boolean,
    ) {
        client.submitAssignmentForGrading(
            assignmentID = assignmentID,
            acceptsSubmissionStatement = acceptsSubmissionStatement,
        )
    }

    override suspend fun startAssignmentSubmission(assignmentID: Int) {
        client.startAssignmentSubmission(assignmentID = assignmentID)
    }

    override suspend fun removeAssignmentSubmission(assignmentID: Int, userID: Int) {
        client.removeAssignmentSubmission(
            assignmentID = assignmentID,
            userID = userID,
        )
    }
}

private fun AssignmentSubmissionOnlineTextInput.toNetworkAssignmentOnlineTextInput(): NetworkAssignmentOnlineTextInput =
    NetworkAssignmentOnlineTextInput(
        text = html,
        format = format,
        draftItemID = draftItemID,
    )
