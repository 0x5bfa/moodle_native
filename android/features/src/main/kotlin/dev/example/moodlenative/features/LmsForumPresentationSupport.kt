package dev.example.moodlenative.features

import dev.example.moodlenative.core.LmsHTMLTextFormatter
import dev.example.moodlenative.core.LmsResourceTreeFile
import dev.example.moodlenative.core.LmsResourceTreeNode
import dev.example.moodlenative.core.lmsPathComponents
import dev.example.moodlenative.core.singleLineDisplayTextOrNull
import dev.example.moodlenative.core.treeNodes
import java.net.URI
import java.time.Instant

data class LmsForumPostThreadNode(
    val post: LmsForumPost,
    val children: List<LmsForumPostThreadNode>,
) {
    val id: Int
        get() = post.id
}

data class LmsForumDiscussionPresentation(
    val id: Int,
    val title: String,
    val authorName: String,
    val modifiedAt: Instant?,
    val replyCount: Int,
    val unreadCount: Int,
    val previewText: String?,
)

data class LmsForumPostPresentation(
    val id: Int,
    val subject: String?,
    val bodyText: String?,
    val authorName: String,
    val isUnread: Boolean,
    val modifiedAt: Instant?,
    val attachmentCount: Int,
)

data class LmsForumPostThreadPresentationNode(
    val post: LmsForumPostPresentation,
    val children: List<LmsForumPostThreadPresentationNode>,
) {
    val id: Int
        get() = post.id
}

val LmsForumDiscussion.presentation: LmsForumDiscussionPresentation
    get() = LmsForumDiscussionPresentation(
        id = discussionID,
        title = displayTitle,
        authorName = authorName,
        modifiedAt = modifiedAt,
        replyCount = replyCount,
        unreadCount = unreadCount,
        previewText = previewText,
    )

val LmsForumDiscussion.displayTitle: String
    get() = when {
        subject.isNotEmpty() -> subject
        name.isNotEmpty() -> name
        else -> "投稿"
    }

val LmsForumDiscussion.previewText: String?
    get() = LmsHTMLTextFormatter.plainText(message).singleLineDisplayTextOrNull()

val LmsForumDiscussion.authorName: String
    get() = userFullName.trim().ifEmpty { "投稿者不明" }

val LmsForumDiscussion.modifiedAt: Instant?
    get() = modifiedTimestamp.takeIf { it > 0 }?.let { Instant.ofEpochSecond(it.toLong()) }

val LmsForumDiscussion.replyCount: Int
    get() = maxOf(0, numberOfReplies)

val LmsForumDiscussion.unreadCount: Int
    get() = maxOf(0, numberOfUnreadPosts)

val LmsForumPost.createdAt: Instant?
    get() = timeCreated.takeIf { it > 0 }?.let { Instant.ofEpochSecond(it.toLong()) }

val LmsForumPost.displaySubject: String?
    get() = subject.trim().ifEmpty { null }

val LmsForumPost.bodyText: String?
    get() = LmsHTMLTextFormatter.plainText(message)

val LmsForumPost.authorName: String
    get() = author.fullName.trim().ifEmpty { "投稿者不明" }

val LmsForumPost.isUnread: Boolean
    get() = unread

val LmsForumPost.modifiedAt: Instant?
    get() = timeModified.takeIf { it > 0 }?.let { Instant.ofEpochSecond(it.toLong()) } ?: createdAt

val LmsForumPost.presentation: LmsForumPostPresentation
    get() = LmsForumPostPresentation(
        id = id,
        subject = displaySubject,
        bodyText = bodyText,
        authorName = authorName,
        isUnread = isUnread,
        modifiedAt = modifiedAt,
        attachmentCount = attachments.size,
    )

fun List<LmsForumPost>.threadedPosts(): List<LmsForumPostThreadNode> {
    val sortedPosts = sortedWith(compareBy<LmsForumPost> { it.timeCreated }.thenBy { it.id })
    val postsByID = sortedPosts.associateBy { it.id }
    val childrenByParent = mutableMapOf<Int, MutableList<LmsForumPost>>()
    val roots = mutableListOf<LmsForumPost>()

    for (post in sortedPosts) {
        val parentID = post.parentID
        if (parentID != null && postsByID[parentID] != null) {
            childrenByParent.getOrPut(parentID) { mutableListOf() } += post
        } else {
            roots += post
        }
    }

    fun makeNode(post: LmsForumPost): LmsForumPostThreadNode =
        LmsForumPostThreadNode(
            post = post,
            children = childrenByParent[post.id].orEmpty().map(::makeNode),
        )

    return roots.map(::makeNode)
}

fun List<LmsForumPost>.threadPresentation(): List<LmsForumPostThreadPresentationNode> =
    threadedPosts().map { node -> node.presentation }

private val LmsForumPostThreadNode.presentation: LmsForumPostThreadPresentationNode
    get() = LmsForumPostThreadPresentationNode(
        post = post.presentation,
        children = children.map { child -> child.presentation },
    )

val LmsForumPostAttachment.uri: URI?
    get() = fileURL?.let { runCatching { URI(it) }.getOrNull() }

val LmsForumPostAttachment.pathComponents: List<String>
    get() = (filePath ?: "").lmsPathComponents

val LmsForumPostAttachment.displayName: String
    get() = fileName?.trim()?.ifEmpty { null } ?: "添付ファイル"

val List<LmsForumPostAttachment>.resourceTreeNodes: List<LmsResourceTreeNode>
    get() = mapNotNull { attachment ->
        val uri = attachment.uri ?: return@mapNotNull null
        LmsResourceTreeFile(
            id = attachment.id,
            title = attachment.displayName,
            url = uri,
            pathComponents = attachment.pathComponents,
        )
    }.treeNodes()

val LmsForumPostURLs.discussURI: URI?
    get() = discuss?.let { runCatching { URI(it) }.getOrNull() }

val LmsForumPostAuthorURLs.profileImageURI: URI?
    get() = profileImage?.let { runCatching { URI(it) }.getOrNull() }
