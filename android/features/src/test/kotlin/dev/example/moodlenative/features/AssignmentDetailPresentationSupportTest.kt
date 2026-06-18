package dev.example.moodlenative.features

import dev.example.moodlenative.core.LmsAssignmentItem
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AssignmentDetailPresentationSupportTest {
    @Test
    fun detailPresentationBuildsStatusEditorAndActions() {
        val presentation = status().detailPresentation(
            assignment = assignment(),
            loadedAt = Instant.parse("2026-06-12T03:04:05Z"),
        )

        assertEquals(Instant.parse("2026-06-12T03:04:05Z"), presentation.loadedAt)
        assertEquals(
            listOf(
                AssignmentDetailRowPresentation("提出状態", "draft"),
                AssignmentDetailRowPresentation("採点状態", "notgraded"),
                AssignmentDetailRowPresentation("評点", "85 / 100"),
                AssignmentDetailRowPresentation("添付", "2 件"),
                AssignmentDetailRowPresentation("警告", "確認してください"),
            ),
            presentation.statusRows,
        )

        val editor = presentation.editor ?: error("Expected editable assignment presentation")
        assertEquals(77, editor.submissionID)
        assertEquals("本文です", editor.initialOnlineText)
        assertEquals(1, editor.initialFiles.size)
        assertEquals("previous.pdf", editor.initialFiles.single().fileName)
        assertEquals("application/pdf", editor.initialFiles.single().mimeType)
        assertEquals("https://lms.example.test/pluginfile.php/previous.pdf", editor.initialFiles.single().fileURL)
        assertEquals(400, editor.wordLimit)

        assertFalse(presentation.actions.canStart)
        assertTrue(presentation.actions.canSubmit)
        assertTrue(presentation.actions.canRemove)
        assertEquals(99, presentation.actions.removeUserID)
    }

    @Test
    fun detailPresentationCanStartTimedNewSubmission() {
        val presentation = status(
            submission = submission(status = "new", timeStarted = null),
            canSubmit = false,
        ).detailPresentation(
            assignment = assignment(timeLimit = 1800),
            loadedAt = Instant.parse("2026-06-12T03:04:05Z"),
        )

        assertTrue(presentation.actions.canStart)
        assertFalse(presentation.actions.canSubmit)
        assertFalse(presentation.actions.canRemove)
    }

    @Test
    fun detailPresentationOmitsEditorWhenLocked() {
        val presentation = status(locked = true).detailPresentation(
            assignment = assignment(),
            loadedAt = Instant.parse("2026-06-12T03:04:05Z"),
        )

        assertNull(presentation.editor)
    }

    private companion object {
        fun assignment(timeLimit: Int? = null): LmsAssignmentItem =
            LmsAssignmentItem(
                id = 501,
                courseID = 42,
                courseModuleID = 9001,
                courseTitle = "ソフトウェア工学",
                courseCode = "IS-301",
                courseShortName = "2026-IS-301",
                title = "設計レビュー課題",
                introPreview = "<p>提出前にレビュー観点を整理する。</p>",
                dueDate = Instant.parse("2026-06-10T14:59:00Z"),
                allowsSubmissionsFromDate = null,
                cutoffDate = null,
                updatedAt = Instant.parse("2026-06-08T00:30:00Z"),
                timeLimit = timeLimit,
                enabledSubmissionPluginTypes = null,
                onlineTextWordLimit = 400,
            )

        fun status(
            submission: LmsAssignmentSubmission = submission(),
            locked: Boolean = false,
            canSubmit: Boolean = true,
        ): LmsAssignmentSubmissionStatus =
            LmsAssignmentSubmissionStatus(
                lastAttempt = LmsAssignmentLastAttempt(
                    submission = submission,
                    submissionsEnabled = true,
                    locked = locked,
                    canEdit = true,
                    canSubmit = canSubmit,
                    gradingStatus = "notgraded",
                    timeLimit = null,
                ),
                feedback = LmsAssignmentFeedback(gradeForDisplay = "85 / 100"),
                assignmentData = LmsAssignmentData(
                    attachments = LmsAssignmentDataAttachments(
                        intro = listOf(LmsAssignmentFile(fileName = "intro.pdf")),
                        activity = listOf(LmsAssignmentFile(fileName = "activity.pdf")),
                    ),
                ),
                warnings = listOf(LmsAssignmentWarning(message = "確認してください")),
            )

        fun submission(
            status: String = "draft",
            timeStarted: Int? = 1_775_200_500,
        ): LmsAssignmentSubmission =
            LmsAssignmentSubmission(
                id = 77,
                userID = 99,
                timeStarted = timeStarted,
                status = status,
                plugins = listOf(
                    LmsAssignmentPlugin(
                        type = "onlinetext",
                        editorFields = listOf(
                            LmsAssignmentPluginEditorField(text = "<p>本文です</p>"),
                        ),
                    ),
                    LmsAssignmentPlugin(
                        type = "file",
                        fileAreas = listOf(
                            LmsAssignmentPluginFileArea(
                                files = listOf(
                                    LmsAssignmentFile(
                                        fileName = "previous.pdf",
                                        fileURL = "https://lms.example.test/pluginfile.php/previous.pdf",
                                        mimeType = "application/pdf",
                                    ),
                                ),
                            ),
                        ),
                    ),
                ),
            )
    }
}
