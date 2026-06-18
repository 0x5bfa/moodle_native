package dev.example.moodlenative.networking

import java.net.HttpURLConnection
import java.net.URI

data class LmsHttpRequest(
    val method: String,
    val url: URI,
    val headers: Map<String, String> = emptyMap(),
    val body: ByteArray? = null,
) {
    val bodyText: String?
        get() = body?.toString(Charsets.UTF_8)
}

data class LmsHttpResponse(
    val statusCode: Int,
    val body: String,
    val bodyBytes: ByteArray = body.toByteArray(Charsets.UTF_8),
)

interface LmsHttpClient {
    suspend fun send(request: LmsHttpRequest): LmsHttpResponse
}

class HttpUrlConnectionLmsHttpClient : LmsHttpClient {
    override suspend fun send(request: LmsHttpRequest): LmsHttpResponse {
        val connection = request.url.toURL().openConnection() as HttpURLConnection
        try {
            connection.requestMethod = request.method
            connection.instanceFollowRedirects = true
            request.headers.forEach { (name, value) ->
                connection.setRequestProperty(name, value)
            }

            val body = request.body
            if (body != null) {
                connection.doOutput = true
                connection.outputStream.use { stream ->
                    stream.write(body)
                }
            }

            val statusCode = connection.responseCode
            val responseBytes = if (statusCode in 200..299) {
                connection.inputStream.use { stream ->
                    stream.readBytes()
                }
            } else {
                connection.errorStream?.use { stream -> stream.readBytes() } ?: ByteArray(0)
            }

            return LmsHttpResponse(
                statusCode = statusCode,
                body = responseBytes.toString(Charsets.UTF_8),
                bodyBytes = responseBytes,
            )
        } finally {
            connection.disconnect()
        }
    }
}
