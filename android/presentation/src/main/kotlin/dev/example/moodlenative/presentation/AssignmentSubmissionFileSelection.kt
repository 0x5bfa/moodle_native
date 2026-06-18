package dev.example.moodlenative.presentation

import dev.example.moodlenative.features.AssignmentSubmissionFilePresentation

data class AssignmentSubmissionFileSelection(
    val fileName: String,
    val mimeType: String,
    val data: ByteArray? = null,
    val existingFileURL: String? = null,
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is AssignmentSubmissionFileSelection) return false

        return fileName == other.fileName &&
            mimeType == other.mimeType &&
            data.contentEqualsOrNull(other.data) &&
            existingFileURL == other.existingFileURL
    }

    override fun hashCode(): Int {
        var result = fileName.hashCode()
        result = 31 * result + mimeType.hashCode()
        result = 31 * result + (data?.contentHashCode() ?: 0)
        result = 31 * result + (existingFileURL?.hashCode() ?: 0)
        return result
    }

    private fun ByteArray?.contentEqualsOrNull(other: ByteArray?): Boolean =
        when {
            this == null && other == null -> true
            this == null || other == null -> false
            else -> contentEquals(other)
        }
}

fun AssignmentSubmissionFilePresentation.toAssignmentSubmissionFileSelection(): AssignmentSubmissionFileSelection =
    AssignmentSubmissionFileSelection(
        fileName = fileName,
        mimeType = mimeType,
        existingFileURL = fileURL,
    )
