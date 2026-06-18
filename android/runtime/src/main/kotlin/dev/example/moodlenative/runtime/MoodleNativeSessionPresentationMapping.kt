package dev.example.moodlenative.runtime

import dev.example.moodlenative.data.LiveCalendarResult
import dev.example.moodlenative.data.LiveDashboardResult
import dev.example.moodlenative.data.LiveForumResult
import dev.example.moodlenative.presentation.AppSessionPresentationState
import dev.example.moodlenative.storage.AppSessionSnapshot

internal fun resolveSessionPresentationState(
    sessionSnapshot: AppSessionSnapshot,
    liveDashboardResult: LiveDashboardResult?,
    liveForumResult: LiveForumResult?,
    liveCalendarResult: LiveCalendarResult?,
): AppSessionPresentationState = when (liveDashboardResult) {
    is LiveDashboardResult.Loaded -> liveDashboardResult.dashboard.snapshot.toPresentationState()
    is LiveDashboardResult.MissingSession -> liveDashboardResult.snapshot.toPresentationState()
    is LiveDashboardResult.Failed -> liveDashboardResult.snapshot.toPresentationState()
    null -> when (liveForumResult) {
        is LiveForumResult.InvalidForumID -> liveForumResult.snapshot.toPresentationState()
        is LiveForumResult.MissingSession -> liveForumResult.snapshot.toPresentationState()
        is LiveForumResult.Loaded -> liveForumResult.snapshot.toPresentationState()
        is LiveForumResult.Failed -> liveForumResult.snapshot.toPresentationState()
        null -> when (liveCalendarResult) {
            is LiveCalendarResult.MissingSession -> liveCalendarResult.snapshot.toPresentationState()
            is LiveCalendarResult.Loaded -> liveCalendarResult.snapshot.toPresentationState()
            is LiveCalendarResult.Failed -> liveCalendarResult.snapshot.toPresentationState()
            null -> sessionSnapshot.toPresentationState()
        }
    }
}

private fun AppSessionSnapshot.toPresentationState(): AppSessionPresentationState {
    val session = lmsSession
    val sessionLabel = if (session == null) {
        "未接続"
    } else {
        val userID = session.userID?.let { " / user $it" }.orEmpty()
        "${session.siteURL}$userID"
    }

    return AppSessionPresentationState(
        hasLmsSession = hasLmsSession,
        lmsSessionLabel = sessionLabel,
    )
}
