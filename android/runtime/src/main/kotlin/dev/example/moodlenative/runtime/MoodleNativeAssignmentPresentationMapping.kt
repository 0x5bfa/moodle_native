package dev.example.moodlenative.runtime

import dev.example.moodlenative.core.LmsAssignmentItem
import dev.example.moodlenative.data.LiveAssignmentDetailResult
import dev.example.moodlenative.features.AssignmentDetailPresentation
import dev.example.moodlenative.features.AssignmentDetailRowPresentation
import dev.example.moodlenative.features.detailPresentation

internal data class AssignmentDetailPresentationResult(
    val presentation: AssignmentDetailPresentation?,
    val statusRows: List<AssignmentDetailRowPresentation>,
)

internal fun resolveAssignmentDetailPresentation(
    selectedAssignment: LmsAssignmentItem?,
    liveAssignmentDetailResult: LiveAssignmentDetailResult?,
): AssignmentDetailPresentationResult {
    val detailPresentation = when (liveAssignmentDetailResult) {
        is LiveAssignmentDetailResult.Loaded -> {
            val assignment = selectedAssignment
            if (assignment == null) {
                null
            } else {
                liveAssignmentDetailResult.status.detailPresentation(
                    assignment = assignment,
                    loadedAt = liveAssignmentDetailResult.loadedAt,
                )
            }
        }
        is LiveAssignmentDetailResult.Failed,
        is LiveAssignmentDetailResult.MissingSession,
        null,
        -> null
    }

    val statusRows = when (liveAssignmentDetailResult) {
        is LiveAssignmentDetailResult.MissingSession -> listOf(
            AssignmentDetailRowPresentation("詳細", "Moodle に接続してください"),
        )
        is LiveAssignmentDetailResult.Failed -> listOf(
            AssignmentDetailRowPresentation("詳細", liveAssignmentDetailResult.message),
        )
        is LiveAssignmentDetailResult.Loaded -> detailPresentation?.statusRows.orEmpty()
        null -> listOf(AssignmentDetailRowPresentation("詳細", "課題を選択しました"))
    }

    return AssignmentDetailPresentationResult(
        presentation = detailPresentation,
        statusRows = statusRows,
    )
}
