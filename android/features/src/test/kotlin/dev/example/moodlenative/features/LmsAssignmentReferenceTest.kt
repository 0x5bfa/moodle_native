package dev.example.moodlenative.features

import dev.example.moodlenative.core.LmsAssignmentItem
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LmsAssignmentReferenceTest {
    @Test
    fun assignmentOverviewHelpersHandleTrimmedValues() {
        val emptyReference = LmsAssignmentReference(
            assignmentID = 1,
            courseModuleID = 101,
            courseID = 10,
            courseTitle = "  ",
            courseShortName = "2026-50001",
            title = "課題",
            introPreview = "   ",
            dueDate = null,
            allowsSubmissionsFromDate = null,
            cutoffDate = null,
            updatedAt = null,
            detailURL = null,
        )

        assertNull(emptyReference.displayCourseTitle)
        assertFalse(emptyReference.hasOverviewDetails)

        val populatedReference = LmsAssignmentReference(
            assignmentID = 2,
            courseModuleID = 102,
            courseID = 10,
            courseTitle = "ソフトウェア工学",
            courseShortName = "2026-50001",
            title = "課題",
            introPreview = null,
            dueDate = null,
            allowsSubmissionsFromDate = null,
            cutoffDate = Instant.ofEpochSecond(1_750_000_000),
            updatedAt = null,
            detailURL = null,
        )

        assertEquals("ソフトウェア工学", populatedReference.displayCourseTitle)
        assertTrue(populatedReference.hasOverviewDetails)
    }

    @Test
    fun assignmentItemReferenceBuildsDetailURLAndCarriesFields() {
        val item = LmsAssignmentItem(
            id = 301,
            courseID = 42,
            courseModuleID = 201,
            courseTitle = "ソフトウェア工学",
            courseCode = "53334",
            courseShortName = "2026-50001",
            title = "第1回課題",
            introPreview = "<p>説明</p>",
            dueDate = Instant.ofEpochSecond(1_750_000_000),
            allowsSubmissionsFromDate = Instant.ofEpochSecond(1_740_000_000),
            cutoffDate = Instant.ofEpochSecond(1_760_000_000),
            updatedAt = Instant.ofEpochSecond(1_745_000_000),
            submissionDrafts = true,
            requiresSubmissionStatement = true,
            submissionStatement = "<p>自分の成果物です。</p>",
            timeLimit = 3600,
            enabledSubmissionPluginTypes = listOf("file", "onlinetext"),
            onlineTextWordLimit = 500,
        )

        val reference = item.reference(siteURL = "https://lms.example.test/base/path")

        assertEquals(301, reference.id)
        assertEquals(301, reference.assignmentID)
        assertEquals(201, reference.courseModuleID)
        assertEquals(42, reference.courseID)
        assertEquals("ソフトウェア工学", reference.courseTitle)
        assertEquals("2026-50001", reference.courseShortName)
        assertEquals("第1回課題", reference.title)
        assertEquals("<p>説明</p>", reference.introPreview)
        assertEquals(Instant.ofEpochSecond(1_750_000_000), reference.dueDate)
        assertEquals(true, reference.submissionDrafts)
        assertEquals(true, reference.requiresSubmissionStatement)
        assertEquals("<p>自分の成果物です。</p>", reference.submissionStatement)
        assertEquals(3600, reference.timeLimit)
        assertEquals(listOf("file", "onlinetext"), reference.enabledSubmissionPluginTypes)
        assertEquals(500, reference.onlineTextWordLimit)
        assertEquals("https://lms.example.test/mod/assign/view.php?id=201", reference.detailURL.toString())
        assertTrue(reference.completionRequirements.isEmpty())
    }

    @Test
    fun mergeCourseModuleAddsCompletionRequirementsAndFallbackURL() {
        val reference = LmsAssignmentReference(
            assignmentID = 301,
            courseModuleID = 201,
            courseID = 42,
            courseTitle = "ソフトウェア工学",
            courseShortName = "2026-50001",
            title = "第1回課題",
            introPreview = null,
            dueDate = null,
            allowsSubmissionsFromDate = null,
            cutoffDate = null,
            updatedAt = null,
            detailURL = null,
        )
        val module = LmsCourseModule(
            id = 201,
            instanceID = 301,
            modName = "assign",
            name = "第1回課題",
            url = "https://lms.example.test/mod/assign/view.php?id=201",
            completionRequirements = listOf(
                LmsModuleCompletionRequirement(
                    id = "completionsubmit",
                    text = "提出する",
                    isComplete = false,
                ),
            ),
        )

        val merged = reference.merging(courseModule = module)

        assertEquals("https://lms.example.test/mod/assign/view.php?id=201", merged.detailURL.toString())
        assertEquals(listOf("提出する"), merged.completionRequirements.map { it.text })
        assertEquals(listOf(false), merged.completionRequirements.map { it.isComplete })
    }

    @Test
    fun mergeCourseModuleKeepsExistingURLAndCompletionRequirements() {
        val existingRequirement = LmsModuleCompletionRequirement(
            id = "existing",
            text = "既存条件",
            isComplete = true,
        )
        val reference = LmsAssignmentReference(
            assignmentID = 301,
            courseModuleID = 201,
            courseID = 42,
            courseTitle = "ソフトウェア工学",
            courseShortName = "2026-50001",
            title = "第1回課題",
            introPreview = null,
            dueDate = null,
            allowsSubmissionsFromDate = null,
            cutoffDate = null,
            updatedAt = null,
            detailURL = java.net.URI("https://lms.example.test/existing"),
            completionRequirements = listOf(existingRequirement),
        )
        val module = LmsCourseModule(
            id = 201,
            instanceID = 301,
            modName = "assign",
            name = "第1回課題",
            url = "https://lms.example.test/mod/assign/view.php?id=201",
            completionRequirements = listOf(
                LmsModuleCompletionRequirement(
                    id = "completionsubmit",
                    text = "提出する",
                    isComplete = false,
                ),
            ),
        )

        val merged = reference.merging(courseModule = module)

        assertEquals("https://lms.example.test/existing", merged.detailURL.toString())
        assertEquals(listOf(existingRequirement), merged.completionRequirements)
    }
}
