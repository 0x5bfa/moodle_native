package dev.example.moodlenative.features

data class LmsForumDiscussion(
    val rootPostID: Int = 0,
    val discussionID: Int = 0,
    val name: String = "",
    val subject: String = "",
    val message: String? = null,
    val userFullName: String = "",
    val numberOfReplies: Int = 0,
    val numberOfUnreadPosts: Int = 0,
    val isPinned: Boolean = false,
    val isLocked: Boolean = false,
    val modifiedTimestamp: Int = 0,
    val canReply: Boolean = false,
) {
    val id: Int
        get() = discussionID
}

data class LmsForumPostAuthorURLs(
    val profile: String? = null,
    val profileImage: String? = null,
)

data class LmsForumPostAuthor(
    val id: Int = 0,
    val fullName: String = "",
    val isDeleted: Boolean = false,
    val urls: LmsForumPostAuthorURLs = LmsForumPostAuthorURLs(),
)

data class LmsForumPostURLs(
    val view: String? = null,
    val viewIsolated: String? = null,
    val discuss: String? = null,
)

data class LmsForumPostAttachment(
    val fileName: String? = null,
    val filePath: String? = null,
    val rawFileURL: String? = null,
    val url: String? = null,
    val mimeType: String? = null,
) {
    val fileURL: String?
        get() = rawFileURL ?: url

    val id: String
        get() = listOfNotNull(fileName, filePath, fileURL, mimeType).joinToString("|")
}

data class LmsForumPost(
    val id: Int = 0,
    val discussionID: Int = 0,
    val subject: String = "",
    val replySubject: String? = null,
    val message: String? = null,
    val timeCreated: Int = 0,
    val timeModified: Int = 0,
    val unread: Boolean = false,
    val hasParent: Boolean = false,
    val parentID: Int? = null,
    val isDeleted: Boolean = false,
    val isPrivateReply: Boolean = false,
    val author: LmsForumPostAuthor = LmsForumPostAuthor(),
    val urls: LmsForumPostURLs = LmsForumPostURLs(),
    val attachments: List<LmsForumPostAttachment> = emptyList(),
)
