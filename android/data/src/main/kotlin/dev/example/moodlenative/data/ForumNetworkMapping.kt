package dev.example.moodlenative.data

import dev.example.moodlenative.features.LmsForumDiscussion
import dev.example.moodlenative.features.LmsForumPost
import dev.example.moodlenative.features.LmsForumPostAttachment
import dev.example.moodlenative.features.LmsForumPostAuthor
import dev.example.moodlenative.features.LmsForumPostAuthorURLs
import dev.example.moodlenative.features.LmsForumPostURLs
import dev.example.moodlenative.networking.ForumDiscussion as NetworkForumDiscussion
import dev.example.moodlenative.networking.ForumPost as NetworkForumPost
import dev.example.moodlenative.networking.ForumPostAttachment as NetworkForumPostAttachment
import dev.example.moodlenative.networking.ForumPostAuthor as NetworkForumPostAuthor
import dev.example.moodlenative.networking.ForumPostAuthorURLs as NetworkForumPostAuthorURLs
import dev.example.moodlenative.networking.ForumPostURLs as NetworkForumPostURLs

internal fun NetworkForumDiscussion.toLmsForumDiscussion(): LmsForumDiscussion =
    LmsForumDiscussion(
        rootPostID = rootPostID,
        discussionID = discussionID,
        name = name,
        subject = subject,
        message = message,
        userFullName = userFullName,
        numberOfReplies = numberOfReplies,
        numberOfUnreadPosts = numberOfUnreadPosts,
        isPinned = isPinned,
        isLocked = isLocked,
        modifiedTimestamp = modifiedTimestamp,
        canReply = canReply,
    )

internal fun NetworkForumPost.toLmsForumPost(): LmsForumPost =
    LmsForumPost(
        id = id,
        discussionID = discussionID,
        subject = subject,
        replySubject = replySubject,
        message = message,
        timeCreated = timeCreated,
        timeModified = timeModified,
        unread = unread,
        hasParent = hasParent,
        parentID = parentID,
        isDeleted = isDeleted,
        isPrivateReply = isPrivateReply,
        author = author.toLmsForumPostAuthor(),
        urls = urls.toLmsForumPostURLs(),
        attachments = attachments.map { attachment -> attachment.toLmsForumPostAttachment() },
    )

private fun NetworkForumPostAuthor.toLmsForumPostAuthor(): LmsForumPostAuthor =
    LmsForumPostAuthor(
        id = id,
        fullName = fullName,
        isDeleted = isDeleted,
        urls = urls.toLmsForumPostAuthorURLs(),
    )

private fun NetworkForumPostAuthorURLs.toLmsForumPostAuthorURLs(): LmsForumPostAuthorURLs =
    LmsForumPostAuthorURLs(
        profile = profile,
        profileImage = profileImage,
    )

private fun NetworkForumPostURLs.toLmsForumPostURLs(): LmsForumPostURLs =
    LmsForumPostURLs(
        view = view,
        viewIsolated = viewIsolated,
        discuss = discuss,
    )

private fun NetworkForumPostAttachment.toLmsForumPostAttachment(): LmsForumPostAttachment =
    LmsForumPostAttachment(
        fileName = fileName,
        filePath = filePath,
        rawFileURL = rawFileURL,
        url = url,
        mimeType = mimeType,
    )
