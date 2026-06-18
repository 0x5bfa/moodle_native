package dev.example.moodlenative.data

import dev.example.moodlenative.core.LmsAssignmentItem
import dev.example.moodlenative.networking.Assignment as NetworkAssignment
import dev.example.moodlenative.networking.CourseAssignments as NetworkCourseAssignments
import java.time.Instant

internal fun List<NetworkCourseAssignments>.toLmsAssignmentItems(): List<LmsAssignmentItem> =
    flatMap { course ->
        course.assignments.map { assignment ->
            assignment.toLmsAssignmentItem(course = course)
        }
    }

private fun NetworkAssignment.toLmsAssignmentItem(course: NetworkCourseAssignments): LmsAssignmentItem =
    LmsAssignmentItem(
        id = id,
        courseID = courseID,
        courseModuleID = courseModuleID,
        courseTitle = course.fullName,
        courseCode = null,
        courseShortName = course.shortName,
        title = name,
        introPreview = intro,
        dueDate = dueDate.toInstantOrNull(),
        allowsSubmissionsFromDate = allowsSubmissionsFromDate.toInstantOrNull(),
        cutoffDate = cutoffDate.toInstantOrNull(),
        updatedAt = timeModified.toInstantOrNull(),
        submissionDrafts = submissionDrafts,
        requiresSubmissionStatement = requiresSubmissionStatement,
        submissionStatement = submissionStatement,
        timeLimit = timeLimit,
        enabledSubmissionPluginTypes = enabledSubmissionPluginTypes,
        onlineTextWordLimit = onlineTextWordLimit,
    )

private fun Long?.toInstantOrNull(): Instant? =
    this?.takeIf { it > 0 }?.let(Instant::ofEpochSecond)
