package dev.example.moodlenative.networking

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class SiteInfo(
    @SerialName("sitename")
    val siteName: String,
    @SerialName("siteurl")
    val siteURL: String,
    @SerialName("userid")
    val userID: Int,
    @SerialName("username")
    val userName: String,
    @SerialName("fullname")
    val fullName: String,
    @SerialName("firstname")
    val firstName: String? = null,
    @SerialName("lastname")
    val lastName: String? = null,
    val functions: List<Function> = emptyList(),
    @SerialName("advancedfeatures")
    val advancedFeatures: List<AdvancedFeature> = emptyList(),
) {
    @Serializable
    data class Function(
        val name: String,
        val version: String? = null,
    )

    @Serializable
    data class AdvancedFeature(
        val name: String,
        val value: Int,
    ) {
        val isEnabled: Boolean
            get() = value != 0
    }

    fun isAdvancedFeatureEnabled(name: String): Boolean =
        advancedFeatures.firstOrNull { it.name == name }?.isEnabled ?: false
}

@Serializable
data class Course(
    val id: Int,
    @SerialName("fullname")
    val fullName: String,
    @SerialName("displayname")
    val displayName: String? = null,
    @SerialName("shortname")
    val shortName: String,
    val summary: String? = null,
    @SerialName("courseimage")
    val courseImage: String? = null,
    val progress: Double? = null,
    @SerialName("isfavourite")
    val isFavorite: Boolean? = null,
)

data class FavouriteCourseUpdate(
    val id: Int,
    val isFavorite: Boolean,
)

@Serializable
data class FavouriteCoursesResponse(
    val warnings: List<FavouriteCourseWarning> = emptyList(),
)

@Serializable
data class FavouriteCourseWarning(
    @SerialName("warningcode")
    val warningCode: String? = null,
    val message: String? = null,
)

@Serializable
data class DashboardBlocksResponse(
    val blocks: List<DashboardBlock> = emptyList(),
)

@Serializable
data class DashboardBlock(
    @SerialName("instanceid")
    val instanceID: Int,
    val name: String,
    val region: String? = null,
    @SerialName("positionid")
    val positionID: Int? = null,
    val collapsible: Boolean? = null,
    val dockable: Boolean? = null,
    val weight: Int? = null,
    val visible: Boolean? = null,
    val contents: Contents? = null,
    val configs: List<Config>? = null,
) {
    @Serializable
    data class Contents(
        val title: String? = null,
        val content: String? = null,
        @SerialName("contentformat")
        val contentFormat: Int? = null,
        val footer: String? = null,
        val files: List<File>? = null,
    ) {
        @Serializable
        data class File(
            @SerialName("filename")
            val fileName: String? = null,
            @SerialName("fileurl")
            val fileURL: String? = null,
        )
    }

    @Serializable
    data class Config(
        val name: String,
        val value: String? = null,
        val type: String? = null,
    )
}

data class DashboardSnapshot(
    val siteURL: String,
    val userID: Int?,
    val courses: List<Course>,
    val dashboardBlocks: List<DashboardBlock>,
)

@Serializable
data class MoodleErrorResponse(
    val exception: String? = null,
    @SerialName("errorcode")
    val errorCode: String? = null,
    val message: String? = null,
    @SerialName("debuginfo")
    val debugInfo: String? = null,
) {
    val isError: Boolean
        get() = exception != null || errorCode != null
}
