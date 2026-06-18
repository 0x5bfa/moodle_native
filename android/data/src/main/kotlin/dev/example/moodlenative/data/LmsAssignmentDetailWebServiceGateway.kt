package dev.example.moodlenative.data

import dev.example.moodlenative.core.LmsAuthenticationSession
import dev.example.moodlenative.features.LmsAssignmentSubmissionStatus
import dev.example.moodlenative.networking.LmsWebServiceClient

internal class LmsAssignmentDetailWebServiceGateway(
    session: LmsAuthenticationSession,
) : AssignmentDetailGateway {
    private val client = LmsWebServiceClient(session.toLmsWebServiceSession())

    override suspend fun fetchSubmissionStatus(assignmentID: Int): LmsAssignmentSubmissionStatus =
        client.fetchAssignmentSubmissionStatus(assignmentID = assignmentID).toLmsAssignmentSubmissionStatus()
}
