package dev.example.moodlenative.networking

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.intOrNull

@Serializable
data class CourseAssignments(
    val id: Int,
    @SerialName("fullname")
    val fullName: String,
    @SerialName("shortname")
    val shortName: String,
    val assignments: List<Assignment> = emptyList(),
)

@Serializable
data class Assignment(
    val id: Int,
    @SerialName("course")
    val courseID: Int,
    @SerialName("cmid")
    val courseModuleID: Int,
    val name: String,
    val intro: String? = null,
    @SerialName("allowsubmissionsfromdate")
    val allowsSubmissionsFromDate: Long? = null,
    @SerialName("duedate")
    val dueDate: Long? = null,
    @SerialName("cutoffdate")
    val cutoffDate: Long? = null,
    @SerialName("gradingduedate")
    val gradingDueDate: Long? = null,
    @SerialName("timemodified")
    val timeModified: Long? = null,
    @SerialName("submissiondrafts")
    private val submissionDraftsRaw: JsonElement? = null,
    @SerialName("requiresubmissionstatement")
    private val requiresSubmissionStatementRaw: JsonElement? = null,
    @SerialName("submissionstatement")
    val submissionStatement: String? = null,
    @SerialName("timelimit")
    val timeLimit: Int? = null,
    val configs: List<AssignmentPluginConfig>? = null,
) {
    val submissionDrafts: Boolean?
        get() = submissionDraftsRaw.boolishOrNull()

    val requiresSubmissionStatement: Boolean?
        get() = requiresSubmissionStatementRaw.boolishOrNull()

    val enabledSubmissionPluginTypes: List<String>?
        get() = configs
            ?.filter { config ->
                config.subtype == "assignsubmission" &&
                    config.name == "enabled" &&
                    config.value == "1"
            }
            ?.map { it.plugin }

    val onlineTextWordLimit: Int?
        get() {
            val onlineTextConfigs = configs
                ?.filter { it.plugin == "onlinetext" && it.subtype == "assignsubmission" }
                ?.associate { it.name to it.value }
                ?: return null

            return if (onlineTextConfigs["wordlimitenabled"] == "1") {
                onlineTextConfigs["wordlimit"]?.toIntOrNull()
            } else {
                null
            }
        }

}

@Serializable
data class AssignmentPluginConfig(
    val plugin: String,
    val subtype: String,
    val name: String,
    val value: String,
)

@Serializable
data class AssignmentsResponse(
    val courses: List<CourseAssignments> = emptyList(),
)

private fun JsonElement?.boolishOrNull(): Boolean? {
    if (this == null || this is JsonNull || this !is JsonPrimitive) {
        return null
    }

    booleanOrNull?.let { return it }
    intOrNull?.let { return it != 0 }

    return when (content.lowercase()) {
        "1", "true", "yes" -> true
        "0", "false", "no" -> false
        else -> null
    }
}
