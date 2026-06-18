package dev.example.moodlenative.data

import dev.example.moodlenative.core.LmsAuthenticationSession
import dev.example.moodlenative.networking.LmsWebServiceClient

internal class LmsForumActionWebServiceGateway(
    session: LmsAuthenticationSession,
) : ForumActionGateway {
    private val client = LmsWebServiceClient(session.toLmsWebServiceSession())

    override suspend fun markForumDiscussionViewed(discussionID: Int) {
        client.markForumDiscussionViewed(discussionID = discussionID)
    }
}
