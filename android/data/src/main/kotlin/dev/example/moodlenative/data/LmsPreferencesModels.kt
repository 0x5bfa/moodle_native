package dev.example.moodlenative.data

internal data class LmsUserPreference(
    val name: String,
    val value: String? = null,
)

internal data class LmsUserPreferenceUpdate(
    val type: String,
    val value: String?,
)

internal data class LmsSiteInfo(
    val advancedFeatures: Map<String, Boolean> = emptyMap(),
) {
    fun isAdvancedFeatureEnabled(name: String): Boolean =
        advancedFeatures[name] ?: false
}
