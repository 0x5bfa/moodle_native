package dev.example.moodlenative.features

import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class LmsForumPresentationSupportTest {
    @Test
    fun discussionPresentationHelpersNormalizeDisplayValues() {
        val discussion = LmsForumDiscussion(
            rootPostID = 60937,
            discussionID = 28473,
            name = "フォーラム名",
            subject = "",
            message = "<p>本文です</p><p>続きです</p>",
            userFullName = "  ",
            numberOfReplies = -2,
            numberOfUnreadPosts = 3,
            modifiedTimestamp = 1_775_200_576,
        )

        assertEquals("フォーラム名", discussion.displayTitle)
        assertEquals("本文です 続きです", discussion.previewText)
        assertEquals("投稿者不明", discussion.authorName)
        assertEquals(Instant.ofEpochSecond(1_775_200_576), discussion.modifiedAt)
        assertEquals(0, discussion.replyCount)
        assertEquals(3, discussion.unreadCount)

        val presentation = discussion.presentation
        assertEquals(28473, presentation.id)
        assertEquals("フォーラム名", presentation.title)
        assertEquals("投稿者不明", presentation.authorName)
        assertEquals("本文です 続きです", presentation.previewText)

        val untitled = discussion.copy(name = "", subject = "")

        assertEquals("投稿", untitled.displayTitle)
    }

    @Test
    fun postPresentationHelpersNormalizeDisplayValues() {
        val post = LmsForumPost(
            id = 1,
            discussionID = 28473,
            subject = "  ",
            message = "<p>本文です</p>",
            timeCreated = 1_775_200_500,
            timeModified = 0,
            unread = true,
            author = LmsForumPostAuthor(fullName = "  "),
        )

        assertNull(post.displaySubject)
        assertEquals("本文です", post.bodyText)
        assertEquals("投稿者不明", post.authorName)
        assertEquals(true, post.isUnread)
        assertEquals(Instant.ofEpochSecond(1_775_200_500), post.createdAt)
        assertEquals(post.createdAt, post.modifiedAt)

        val presentation = post.presentation
        assertEquals(1, presentation.id)
        assertNull(presentation.subject)
        assertEquals("本文です", presentation.bodyText)
        assertEquals("投稿者不明", presentation.authorName)
        assertEquals(true, presentation.isUnread)
    }

    @Test
    fun threadedPostsSortRootsAndAttachChildren() {
        val posts = listOf(
            LmsForumPost(id = 2, parentID = 1, timeCreated = 30, subject = "child"),
            LmsForumPost(id = 3, parentID = 999, timeCreated = 20, subject = "orphan"),
            LmsForumPost(id = 1, parentID = null, timeCreated = 10, subject = "root"),
            LmsForumPost(id = 4, parentID = 1, timeCreated = 30, subject = "child 2"),
        )

        val threaded = posts.threadedPosts()

        assertEquals(listOf(1, 3), threaded.map { it.id })
        assertEquals(listOf(2, 4), threaded[0].children.map { it.id })
        assertEquals(emptyList<LmsForumPostThreadNode>(), threaded[1].children)

        val presentation = posts.threadPresentation()
        assertEquals(listOf(1, 3), presentation.map { it.id })
        assertEquals(listOf(2, 4), presentation[0].children.map { it.id })
    }

    @Test
    fun attachmentPresentationBuildsResourceTreeAndURLs() {
        val attachments = listOf(
            LmsForumPostAttachment(
                fileName = "guide.pdf",
                filePath = "/week1/docs",
                rawFileURL = "https://lms.example.test/pluginfile.php/1/guide.pdf",
                mimeType = "application/pdf",
            ),
            LmsForumPostAttachment(
                fileName = "  ",
                filePath = "/week1",
                rawFileURL = "https://lms.example.test/pluginfile.php/1/unnamed",
            ),
        )
        val urls = LmsForumPostURLs(discuss = "https://lms.example.test/mod/forum/discuss.php?d=28473")
        val authorURLs = LmsForumPostAuthorURLs(
            profileImage = "https://lms.example.test/theme/image.php/test/core/u/f1",
        )

        assertEquals("guide.pdf", attachments[0].displayName)
        assertEquals("添付ファイル", attachments[1].displayName)
        assertEquals("https://lms.example.test/pluginfile.php/1/guide.pdf", attachments[0].uri.toString())
        assertEquals(listOf("week1", "docs"), attachments[0].pathComponents)
        assertEquals("https://lms.example.test/mod/forum/discuss.php?d=28473", urls.discussURI.toString())
        assertEquals(
            "https://lms.example.test/theme/image.php/test/core/u/f1",
            authorURLs.profileImageURI.toString(),
        )

        val tree = attachments.resourceTreeNodes

        assertEquals(1, tree.size)
        assertEquals("week1", tree[0].title)
        assertEquals(2, tree[0].children.size)
        assertEquals("docs", tree[0].children[0].title)
        assertEquals("guide.pdf", tree[0].children[0].children[0].title)
        assertEquals("添付ファイル", tree[0].children[1].title)
    }
}
