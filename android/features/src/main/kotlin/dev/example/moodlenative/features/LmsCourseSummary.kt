package dev.example.moodlenative.features

import dev.example.moodlenative.core.AcademicSemester
import dev.example.moodlenative.core.TimetableScheduleSlot
import java.net.URI

data class LmsCourseSummary(
    val id: Int,
    val title: String,
    val courseCode: String?,
    val shortName: String,
    val summary: String?,
    val courseImageURL: URI?,
    val progress: Double?,
    val isFavorite: Boolean,
    val academicSemester: AcademicSemester?,
    val scheduleSlots: List<TimetableScheduleSlot>,
    val assignmentCount: Int,
    val unreadAnnouncementCount: Int,
    val unreadForumPostCount: Int,
    val isRecentlyAccessed: Boolean,
    val detailURL: URI?,
) {
    val progressFraction: Double?
        get() = progress?.coerceIn(0.0, 100.0)?.div(100.0)
}
