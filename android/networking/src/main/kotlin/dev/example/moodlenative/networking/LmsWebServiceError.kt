package dev.example.moodlenative.networking

sealed class LmsWebServiceError(
    override val message: String,
    override val cause: Throwable? = null,
) : Exception(message, cause) {
    data object InvalidSiteURL : LmsWebServiceError("Moodle の API URL を組み立てられませんでした。")

    data object InvalidResponse : LmsWebServiceError("Moodle から不正なレスポンスを受け取りました。")

    data object InvalidSubmissionFiles : LmsWebServiceError("提出ファイルが選択されていません。")

    data class Http(
        val statusCode: Int,
        val response: String,
    ) : LmsWebServiceError(
        if (response.isEmpty()) {
            "Moodle が HTTP $statusCode を返しました。"
        } else {
            "Moodle が HTTP $statusCode を返しました。 $response"
        },
    )

    data class Moodle(
        val moodleMessage: String,
        val debugInfo: String?,
    ) : LmsWebServiceError(
        if (debugInfo.isNullOrEmpty()) {
            moodleMessage
        } else {
            "$moodleMessage ($debugInfo)"
        },
    )

    data class Decoding(
        val decodingCause: Throwable,
    ) : LmsWebServiceError("Moodle のレスポンスを解析できませんでした。", decodingCause)
}
