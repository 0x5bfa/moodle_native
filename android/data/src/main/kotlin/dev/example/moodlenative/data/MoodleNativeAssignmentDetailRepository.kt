package dev.example.moodlenative.data

import dev.example.moodlenative.core.LmsAssignmentItem
import dev.example.moodlenative.core.LmsAuthenticationSession
import dev.example.moodlenative.features.LmsAssignmentSubmissionStatus
import dev.example.moodlenative.storage.AppSessionSnapshot
import dev.example.moodlenative.storage.AppSessionStore
import java.time.Instant

class MoodleNativeAssignmentDetailRepository internal constructor(
    private val sessionStore: AppSessionStore,
    private val gatewayFactory: (LmsAuthenticationSession) -> AssignmentDetailGateway = { session ->
        LmsAssignmentDetailWebServiceGateway(session)
    },
    private val now: () -> Instant = { Instant.now() },
) {
    constructor(sessionStore: AppSessionStore) : this(
        sessionStore = sessionStore,
        gatewayFactory = { session -> LmsAssignmentDetailWebServiceGateway(session) },
        now = { Instant.now() },
    )

    suspend fun loadDetail(assignment: LmsAssignmentItem): LiveAssignmentDetailResult {
        val snapshot = sessionStore.readSnapshot()
        val session = snapshot.lmsSession ?: return LiveAssignmentDetailResult.MissingSession(
            snapshot = snapshot,
            assignment = assignment,
        )
        val gateway = gatewayFactory(session)

        return try {
            LiveAssignmentDetailResult.Loaded(
                snapshot = sessionStore.readSnapshot(),
                assignment = assignment,
                status = gateway.fetchSubmissionStatus(assignmentID = assignment.id),
                loadedAt = now(),
            )
        } catch (error: Exception) {
            LiveAssignmentDetailResult.Failed(
                snapshot = sessionStore.readSnapshot(),
                assignment = assignment,
                message = error.message ?: "課題詳細を取得できませんでした。",
            )
        }
    }
}

internal interface AssignmentDetailGateway {
    suspend fun fetchSubmissionStatus(assignmentID: Int): LmsAssignmentSubmissionStatus
}

sealed class LiveAssignmentDetailResult {
    abstract val assignment: LmsAssignmentItem

    data class MissingSession(
        val snapshot: AppSessionSnapshot,
        override val assignment: LmsAssignmentItem,
    ) : LiveAssignmentDetailResult()

    data class Loaded(
        val snapshot: AppSessionSnapshot,
        override val assignment: LmsAssignmentItem,
        val status: LmsAssignmentSubmissionStatus,
        val loadedAt: Instant,
    ) : LiveAssignmentDetailResult()

    data class Failed(
        val snapshot: AppSessionSnapshot,
        override val assignment: LmsAssignmentItem,
        val message: String,
    ) : LiveAssignmentDetailResult()
}
