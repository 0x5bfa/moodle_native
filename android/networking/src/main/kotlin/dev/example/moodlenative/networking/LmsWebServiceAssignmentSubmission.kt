package dev.example.moodlenative.networking

import kotlinx.serialization.KSerializer
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerializationException
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonDecoder
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonEncoder
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.encodeToJsonElement
import kotlinx.serialization.json.intOrNull

@Serializable
data class AssignmentFile(
    @SerialName("filename")
    val fileName: String? = null,
    @SerialName("filepath")
    val filePath: String? = null,
    @SerialName("filesize")
    val fileSize: Int? = null,
    @SerialName("fileurl")
    val fileURL: String? = null,
    @SerialName("mimetype")
    val mimeType: String? = null,
    @SerialName("timemodified")
    val timeModified: Int? = null,
    @SerialName("isexternalfile")
    private val isExternalFileRaw: JsonElement? = null,
    @SerialName("repositorytype")
    val repositoryType: String? = null,
) {
    val id: String
        get() = listOfNotNull(fileName, filePath, fileURL, mimeType).joinToString("|")

    val isExternalFile: Boolean
        get() = isExternalFileRaw.boolishOrNull() ?: false
}

@Serializable
data class AssignmentPluginFileArea(
    val area: String = "",
    val files: List<AssignmentFile> = emptyList(),
) {
    val id: String
        get() = area
}

@Serializable
data class AssignmentPluginEditorField(
    val name: String = "",
    val description: String = "",
    val text: String? = null,
    val format: Int? = null,
) {
    val id: String
        get() = name
}

@Serializable
data class AssignmentPlugin(
    val type: String = "",
    val name: String = "",
    @SerialName("fileareas")
    val fileAreas: List<AssignmentPluginFileArea> = emptyList(),
    @SerialName("editorfields")
    val editorFields: List<AssignmentPluginEditorField> = emptyList(),
) {
    val id: String
        get() = "$type|$name"
}

@Serializable
data class AssignmentSubmission(
    val id: Int,
    @SerialName("userid")
    val userID: Int = 0,
    @SerialName("attemptnumber")
    val attemptNumber: Int = 0,
    @SerialName("timecreated")
    val timeCreated: Int = 0,
    @SerialName("timemodified")
    val timeModified: Int = 0,
    @SerialName("timestarted")
    val timeStarted: Int? = null,
    val status: String = "",
    @SerialName("groupid")
    val groupID: Int = 0,
    @SerialName("assignment")
    val assignmentID: Int? = null,
    val latest: Int? = null,
    val plugins: List<AssignmentPlugin> = emptyList(),
    @SerialName("gradingstatus")
    val gradingStatus: String? = null,
)

@Serializable
data class AssignmentGrade(
    val id: Int,
    @SerialName("assignment")
    val assignmentID: Int? = null,
    @SerialName("userid")
    val userID: Int,
    @SerialName("attemptnumber")
    val attemptNumber: Int,
    @SerialName("timecreated")
    val timeCreated: Int,
    @SerialName("timemodified")
    val timeModified: Int,
    val grader: Int,
    val grade: String,
    @SerialName("gradefordisplay")
    val gradeForDisplay: String? = null,
)

@Serializable
data class AssignmentGradingSummary(
    @SerialName("participantcount")
    val participantCount: Int = 0,
    @SerialName("submissiondraftscount")
    val submissionDraftsCount: Int = 0,
    @SerialName("submissionsenabled")
    private val submissionsEnabledRaw: JsonElement? = null,
    @SerialName("submissionssubmittedcount")
    val submissionsSubmittedCount: Int = 0,
    @SerialName("submissionsneedgradingcount")
    val submissionsNeedGradingCount: Int = 0,
    @SerialName("warnofungroupedusers")
    val warningOfUngroupedUsers: String = "",
) {
    val submissionsEnabled: Boolean
        get() = submissionsEnabledRaw.boolishOrNull() ?: false
}

@Serializable
data class AssignmentLastAttempt(
    val submission: AssignmentSubmission? = null,
    @SerialName("teamsubmission")
    val teamSubmission: AssignmentSubmission? = null,
    @SerialName("submissiongroup")
    val submissionGroup: Int? = null,
    @SerialName("submissiongroupmemberswhoneedtosubmit")
    val submissionGroupMembersWhoNeedToSubmit: List<Int> = emptyList(),
    @SerialName("submissionsenabled")
    private val submissionsEnabledRaw: JsonElement? = null,
    @SerialName("locked")
    private val lockedRaw: JsonElement? = null,
    @SerialName("graded")
    private val gradedRaw: JsonElement? = null,
    @SerialName("canedit")
    private val canEditRaw: JsonElement? = null,
    @SerialName("caneditowner")
    private val canEditOwnerRaw: JsonElement? = null,
    @SerialName("cansubmit")
    private val canSubmitRaw: JsonElement? = null,
    @SerialName("extensionduedate")
    private val extensionDueDateRaw: Int? = null,
    @SerialName("timelimit")
    val timeLimit: Int? = null,
    @SerialName("blindmarking")
    private val blindMarkingRaw: JsonElement? = null,
    @SerialName("gradingstatus")
    val gradingStatus: String = "",
    @SerialName("usergroups")
    val userGroups: List<Int> = emptyList(),
) {
    val submissionsEnabled: Boolean
        get() = submissionsEnabledRaw.boolishOrNull() ?: false

    val locked: Boolean
        get() = lockedRaw.boolishOrNull() ?: false

    val graded: Boolean
        get() = gradedRaw.boolishOrNull() ?: false

    val canEdit: Boolean
        get() = canEditRaw.boolishOrNull() ?: false

    val canEditOwner: Boolean
        get() = canEditOwnerRaw.boolishOrNull() ?: false

    val canSubmit: Boolean
        get() = canSubmitRaw.boolishOrNull() ?: false

    val extensionDueDate: Int
        get() = extensionDueDateRaw ?: 0

    val blindMarking: Boolean
        get() = blindMarkingRaw.boolishOrNull() ?: false

    constructor(
        submission: AssignmentSubmission? = null,
        teamSubmission: AssignmentSubmission? = null,
        submissionsEnabled: Boolean,
        locked: Boolean,
        canEdit: Boolean,
        canSubmit: Boolean,
        gradingStatus: String = "",
        timeLimit: Int? = null,
    ) : this(
        submission = submission,
        teamSubmission = teamSubmission,
        submissionsEnabledRaw = JsonPrimitive(submissionsEnabled),
        lockedRaw = JsonPrimitive(locked),
        canEditRaw = JsonPrimitive(canEdit),
        canSubmitRaw = JsonPrimitive(canSubmit),
        gradingStatus = gradingStatus,
        timeLimit = timeLimit,
    )
}

@Serializable
data class AssignmentFeedback(
    val grade: AssignmentGrade? = null,
    @SerialName("gradefordisplay")
    val gradeForDisplay: String? = null,
    @SerialName("gradeddate")
    val gradedDate: Int? = null,
    val plugins: List<AssignmentPlugin> = emptyList(),
)

@Serializable
data class AssignmentPreviousAttempt(
    @SerialName("attemptnumber")
    val attemptNumber: Int = 0,
    val submission: AssignmentSubmission? = null,
    val grade: AssignmentGrade? = null,
    @SerialName("feedbackplugins")
    val feedbackPlugins: List<AssignmentPlugin> = emptyList(),
) {
    val id: Int
        get() = attemptNumber
}

@Serializable
data class AssignmentDataAttachments(
    val intro: List<AssignmentFile> = emptyList(),
    val activity: List<AssignmentFile> = emptyList(),
)

@Serializable
data class AssignmentData(
    val attachments: AssignmentDataAttachments? = null,
    val activity: String? = null,
    @SerialName("activityformat")
    val activityFormat: Int? = null,
)

@Serializable
data class AssignmentWarning(
    val item: String? = null,
    @SerialName("itemid")
    val itemID: Int? = null,
    @SerialName("warningcode")
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

@Serializable
data class AssignmentSubmissionStatus(
    @SerialName("gradingsummary")
    val gradingSummary: AssignmentGradingSummary? = null,
    @SerialName("lastattempt")
    val lastAttempt: AssignmentLastAttempt? = null,
    val feedback: AssignmentFeedback? = null,
    @SerialName("previousattempts")
    val previousAttempts: List<AssignmentPreviousAttempt> = emptyList(),
    @SerialName("assignmentdata")
    @Serializable(with = AssignmentDataOrEmptyArraySerializer::class)
    val assignmentData: AssignmentData? = null,
    val warnings: List<AssignmentWarning> = emptyList(),
)

private object AssignmentDataOrEmptyArraySerializer : KSerializer<AssignmentData?> {
    override val descriptor: SerialDescriptor = AssignmentData.serializer().descriptor

    override fun deserialize(decoder: Decoder): AssignmentData? {
        val jsonDecoder = decoder as? JsonDecoder
            ?: throw SerializationException("AssignmentData can only be decoded from JSON")
        val element = jsonDecoder.decodeJsonElement()

        if (element is JsonNull) {
            return null
        }

        if (element is JsonArray && element.isEmpty()) {
            return null
        }

        return jsonDecoder.json.decodeFromJsonElement<AssignmentData>(element)
    }

    @OptIn(ExperimentalSerializationApi::class)
    override fun serialize(encoder: Encoder, value: AssignmentData?) {
        val jsonEncoder = encoder as? JsonEncoder
            ?: throw SerializationException("AssignmentData can only be encoded to JSON")

        if (value == null) {
            jsonEncoder.encodeNull()
        } else {
            jsonEncoder.encodeJsonElement(jsonEncoder.json.encodeToJsonElement(value))
        }
    }
}

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
