package dev.example.moodlenative.data

import dev.example.moodlenative.core.LmsAuthenticationSession
import dev.example.moodlenative.features.LmsForumDiscussion
import dev.example.moodlenative.features.LmsForumPost
import dev.example.moodlenative.networking.LmsWebServiceClient

internal class LmsForumWebServiceGateway(
    session: LmsAuthenticationSession,
) : ForumGateway {
    private val client = LmsWebServiceClient(session.toLmsWebServiceSession())

    override suspend fun fetchForumDiscussions(forumID: Int): List<LmsForumDiscussion> =
        client.fetchForumDiscussions(forumID = forumID).map { discussion -> discussion.toLmsForumDiscussion() }

    override suspend fun fetchDiscussionPosts(discussionID: Int): List<LmsForumPost> =
        client.fetchDiscussionPosts(discussionID = discussionID).map { post -> post.toLmsForumPost() }
}
