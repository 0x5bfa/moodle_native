package dev.example.moodlenative.networking

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

data class AssignmentSubmissionUploadFile(
    val fileName: String,
    val mimeType: String,
    val data: ByteArray,
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is AssignmentSubmissionUploadFile) return false

        return fileName == other.fileName &&
            mimeType == other.mimeType &&
            data.contentEquals(other.data)
    }

    override fun hashCode(): Int {
        var result = fileName.hashCode()
        result = 31 * result + mimeType.hashCode()
        result = 31 * result + data.contentHashCode()
        return result
    }
}

@Serializable
data class AssignmentUploadedDraftFile(
    val component: String,
    @SerialName("contextid")
    val contextID: Int,
    @SerialName("userid")
    val userID: Int,
    @SerialName("filearea")
    val fileArea: String,
    @SerialName("itemid")
    val itemID: Int,
    @SerialName("filename")
    val fileName: String,
    @SerialName("filepath")
    val filePath: String,
    @SerialName("filesize")
    val fileSize: Int? = null,
)

data class AssignmentOnlineTextInput(
    val text: String,
    val format: Int = 1,
    val draftItemID: Int = 0,
)

@Serializable
data class AssignmentSubmissionStartResponse(
    @SerialName("submissionid")
    val submissionID: Int,
    val warnings: List<AssignmentWarning> = emptyList(),
)

@Serializable
data class AssignmentSubmissionRemovalResponse(
    val status: Boolean,
    val warnings: List<AssignmentWarning> = emptyList(),
)
