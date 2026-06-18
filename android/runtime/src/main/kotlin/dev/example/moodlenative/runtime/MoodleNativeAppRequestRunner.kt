package dev.example.moodlenative.runtime

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

internal suspend fun <T> runMoodleNativeAppRequest(
    onFailure: (Throwable) -> T,
    block: suspend () -> T,
): T = runCatching {
    withContext(Dispatchers.IO) {
        block()
    }
}.getOrElse(onFailure)
