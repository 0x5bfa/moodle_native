package dev.example.moodlenative.data

import dev.example.moodlenative.core.LmsAssignmentItem
import dev.example.moodlenative.core.LmsAuthenticationSession
import dev.example.moodlenative.storage.AppSessionSnapshot
import dev.example.moodlenative.storage.AppSessionStore
import java.time.Instant
import java.util.concurrent.CountDownLatch
import kotlin.coroutines.Continuation
import kotlin.coroutines.EmptyCoroutineContext
import kotlin.coroutines.startCoroutine
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class MoodleNativeAssignmentActionRepositoryTest {
    @Test
    fun missingSessionDoesNotCreateGateway() {
        val repository = MoodleNativeAssignmentActionRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot()),
            gatewayFactory = { error("Gateway should not be created without a session") },
        )

        val result = runSuspend { repository.submitForGrading(assignment()) }

        assertTrue(result is LiveAssignmentActionResult.MissingSession)
        assertEquals(501, result.action.assignment.id)
    }

    @Test
    fun saveSubmissionUsesAssignmentIDDraftAndOnlineText() {
        val gateway = FakeAssignmentActionGateway()
        val repository = repository(gateway = gateway)
        val expectedOnlineText = AssignmentSubmissionOnlineTextInput(html = "<p>本文</p>", format = 1, draftItemID = 0)

        val result = runSuspend {
            repository.saveSubmission(
                assignment = assignment(id = 27625),
                fileDraftItemID = 123456,
                onlineTextHTML = "<p>本文</p>",
            )
        } as LiveAssignmentActionResult.Completed

        assertEquals(
            listOf(SaveCall(assignmentID = 27625, fileDraftItemID = 123456, onlineText = expectedOnlineText)),
            gateway.saveCalls,
        )
        assertEquals("<p>本文</p>", (result.action as AssignmentAction.SaveSubmission).onlineText?.html)
        assertEquals(Instant.parse("2026-06-12T03:04:05Z"), result.completedAt)
    }

    @Test
    fun uploadAndSaveSubmissionUploadsFilesBeforeSave() {
        val gateway = FakeAssignmentActionGateway(uploadedDraftItemID = 987654)
        val repository = repository(gateway = gateway)
        val file = AssignmentSubmissionFileInput(
            fileName = "report.txt",
            mimeType = "text/plain",
            data = "body".toByteArray(),
        )

        val result = runSuspend {
            repository.uploadAndSaveSubmission(
                assignment = assignment(id = 27625),
                files = listOf(file),
                onlineTextHTML = null,
            )
        } as LiveAssignmentActionResult.Completed

        assertEquals(listOf(file), gateway.uploadedFiles)
        assertEquals(
            listOf(SaveCall(assignmentID = 27625, fileDraftItemID = 987654, onlineText = null)),
            gateway.saveCalls,
        )
        assertEquals(1, (result.action as AssignmentAction.SaveSubmission).fileCount)
    }

    @Test
    fun uploadAndSaveSubmissionCanClearFileSubmission() {
        val gateway = FakeAssignmentActionGateway()
        val repository = repository(gateway = gateway)

        runSuspend {
            repository.uploadAndSaveSubmission(
                assignment = assignment(id = 27625),
                files = emptyList(),
                onlineTextHTML = null,
            )
        }

        assertEquals(emptyList<AssignmentSubmissionFileInput>(), gateway.uploadedFiles)
        assertEquals(
            listOf(SaveCall(assignmentID = 27625, fileDraftItemID = 0, onlineText = null)),
            gateway.saveCalls,
        )
    }

    @Test
    fun uploadAndSaveSubmissionDownloadsExistingFilesBeforeUpload() {
        val existingFile = ExistingAssignmentSubmissionFileInput(
            fileName = "previous.pdf",
            fileURL = "https://lms.example.test/pluginfile.php/previous.pdf?token=ws-token-123",
            mimeType = "application/pdf",
        )
        val renamedInput = AssignmentSubmissionFileInput(
            fileName = "renamed.pdf",
            mimeType = "application/pdf",
            existingFile = existingFile,
        )
        val gateway = FakeAssignmentActionGateway(
            downloadedFiles = mapOf(
                existingFile to AssignmentSubmissionFileInput(
                    fileName = "previous.pdf",
                    mimeType = "application/pdf",
                    data = "previous-content".toByteArray(),
                ),
            ),
            uploadedDraftItemID = 987654,
        )
        val repository = repository(gateway = gateway)

        runSuspend {
            repository.uploadAndSaveSubmission(
                assignment = assignment(id = 27625),
                files = listOf(renamedInput),
                onlineTextHTML = null,
            )
        }

        assertEquals(listOf(existingFile), gateway.downloadedAssignmentFiles)
        assertEquals(
            listOf(
                AssignmentSubmissionFileInput(
                    fileName = "renamed.pdf",
                    mimeType = "application/pdf",
                    data = "previous-content".toByteArray(),
                ),
            ),
            gateway.uploadedFiles,
        )
        assertEquals(
            listOf(SaveCall(assignmentID = 27625, fileDraftItemID = 987654, onlineText = null)),
            gateway.saveCalls,
        )
    }

    @Test
    fun submitForGradingUsesStatementFlag() {
        val gateway = FakeAssignmentActionGateway()
        val repository = repository(gateway = gateway)

        val result = runSuspend {
            repository.submitForGrading(
                assignment = assignment(id = 27625),
                acceptsSubmissionStatement = false,
            )
        } as LiveAssignmentActionResult.Completed

        assertEquals(listOf(SubmitCall(assignmentID = 27625, acceptsSubmissionStatement = false)), gateway.submitCalls)
        assertEquals(false, (result.action as AssignmentAction.SubmitForGrading).acceptsSubmissionStatement)
    }

    @Test
    fun startSubmissionUsesAssignmentID() {
        val gateway = FakeAssignmentActionGateway()
        val repository = repository(gateway = gateway)

        val result = runSuspend {
            repository.startSubmission(assignment(id = 27625))
        } as LiveAssignmentActionResult.Completed

        assertEquals(listOf(27625), gateway.startedAssignmentIDs)
        assertTrue(result.action is AssignmentAction.StartSubmission)
    }

    @Test
    fun removeSubmissionRequiresUserIDBeforeGateway() {
        val repository = MoodleNativeAssignmentActionRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot(lmsSession = session())),
            gatewayFactory = { error("Gateway should not be created without a user ID") },
        )

        val result = runSuspend {
            repository.removeSubmission(
                assignment = assignment(id = 27625),
                userID = null,
            )
        }

        assertTrue(result is LiveAssignmentActionResult.MissingUserID)
        assertEquals(27625, result.action.assignment.id)
    }

    @Test
    fun removeSubmissionUsesAssignmentIDAndUserID() {
        val gateway = FakeAssignmentActionGateway()
        val repository = repository(gateway = gateway)

        val result = runSuspend {
            repository.removeSubmission(
                assignment = assignment(id = 27625),
                userID = 67797,
            )
        } as LiveAssignmentActionResult.Completed

        assertEquals(listOf(RemoveCall(assignmentID = 27625, userID = 67797)), gateway.removeCalls)
        assertEquals(67797, (result.action as AssignmentAction.RemoveSubmission).userID)
    }

    @Test
    fun failureReturnsFailedResult() {
        val repository = repository(
            gateway = FakeAssignmentActionGateway(error = IllegalStateException("submission unavailable")),
        )

        val result = runSuspend { repository.startSubmission(assignment()) } as LiveAssignmentActionResult.Failed

        assertEquals("submission unavailable", result.message)
        assertTrue(result.action is AssignmentAction.StartSubmission)
    }

    private fun repository(gateway: FakeAssignmentActionGateway): MoodleNativeAssignmentActionRepository =
        MoodleNativeAssignmentActionRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot(lmsSession = session())),
            gatewayFactory = { gateway },
            now = { Instant.parse("2026-06-12T03:04:05Z") },
        )

    private class FakeSessionStore(
        private var snapshot: AppSessionSnapshot,
    ) : AppSessionStore {
        override fun readSnapshot(): AppSessionSnapshot = snapshot

        override fun writeSnapshot(snapshot: AppSessionSnapshot) {
            this.snapshot = snapshot
        }

        override fun clear() {
            snapshot = AppSessionSnapshot()
        }
    }

    private class FakeAssignmentActionGateway(
        private val error: Exception? = null,
        private val uploadedDraftItemID: Int = 123456,
        private val downloadedFiles: Map<ExistingAssignmentSubmissionFileInput, AssignmentSubmissionFileInput> = emptyMap(),
    ) : AssignmentActionGateway {
        val downloadedAssignmentFiles = mutableListOf<ExistingAssignmentSubmissionFileInput>()
        val uploadedFiles = mutableListOf<AssignmentSubmissionFileInput>()
        val saveCalls = mutableListOf<SaveCall>()
        val submitCalls = mutableListOf<SubmitCall>()
        val startedAssignmentIDs = mutableListOf<Int>()
        val removeCalls = mutableListOf<RemoveCall>()

        override suspend fun downloadAssignmentSubmissionFile(
            file: ExistingAssignmentSubmissionFileInput,
        ): AssignmentSubmissionFileInput {
            error?.let { throw it }
            downloadedAssignmentFiles += file
            return downloadedFiles[file]
                ?: error("Missing downloaded file fixture for ${file.fileName}")
        }

        override suspend fun uploadAssignmentSubmissionFiles(files: List<AssignmentSubmissionFileInput>): Int {
            error?.let { throw it }
            uploadedFiles += files
            return uploadedDraftItemID
        }

        override suspend fun saveAssignmentSubmission(
            assignmentID: Int,
            fileDraftItemID: Int?,
            onlineText: AssignmentSubmissionOnlineTextInput?,
        ) {
            error?.let { throw it }
            saveCalls += SaveCall(assignmentID, fileDraftItemID, onlineText)
        }

        override suspend fun submitAssignmentForGrading(
            assignmentID: Int,
            acceptsSubmissionStatement: Boolean,
        ) {
            error?.let { throw it }
            submitCalls += SubmitCall(assignmentID, acceptsSubmissionStatement)
        }

        override suspend fun startAssignmentSubmission(assignmentID: Int) {
            error?.let { throw it }
            startedAssignmentIDs += assignmentID
        }

        override suspend fun removeAssignmentSubmission(assignmentID: Int, userID: Int) {
            error?.let { throw it }
            removeCalls += RemoveCall(assignmentID, userID)
        }
    }

    private data class SaveCall(
        val assignmentID: Int,
        val fileDraftItemID: Int?,
        val onlineText: AssignmentSubmissionOnlineTextInput?,
    )

    private data class SubmitCall(
        val assignmentID: Int,
        val acceptsSubmissionStatement: Boolean,
    )

    private data class RemoveCall(
        val assignmentID: Int,
        val userID: Int,
    )

    private companion object {
        fun assignment(id: Int = 501): LmsAssignmentItem =
            LmsAssignmentItem(
                id = id,
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
            )

        fun session(): LmsAuthenticationSession =
            LmsAuthenticationSession(
                siteURL = "https://lms.example.test",
                token = "ws-token-123",
                privateToken = null,
                rawCallbackURL = "moodlemobile://example?token=ws-token-123",
                authenticatedAt = Instant.parse("2026-06-11T10:15:30Z"),
                userID = 99,
            )

        fun <T> runSuspend(block: suspend () -> T): T {
            val latch = CountDownLatch(1)
            var value: T? = null
            var failure: Throwable? = null

            block.startCoroutine(
                object : Continuation<T> {
                    override val context = EmptyCoroutineContext

                    override fun resumeWith(result: Result<T>) {
                        result.fold(
                            onSuccess = { value = it },
                            onFailure = { failure = it },
                        )
                        latch.countDown()
                    }
                },
            )

            latch.await()
            failure?.let { throw it }
            @Suppress("UNCHECKED_CAST")
            return value as T
        }
    }
}
