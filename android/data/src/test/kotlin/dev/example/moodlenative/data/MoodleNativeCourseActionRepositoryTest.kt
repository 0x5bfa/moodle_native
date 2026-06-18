package dev.example.moodlenative.data

import dev.example.moodlenative.core.AcademicSemester
import dev.example.moodlenative.core.LmsAuthenticationSession
import dev.example.moodlenative.core.SemesterSeason
import dev.example.moodlenative.features.LmsCourseSummary
import dev.example.moodlenative.storage.AppSessionSnapshot
import dev.example.moodlenative.storage.AppSessionStore
import java.net.URI
import java.time.Instant
import java.util.concurrent.CountDownLatch
import kotlin.coroutines.Continuation
import kotlin.coroutines.EmptyCoroutineContext
import kotlin.coroutines.startCoroutine
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class MoodleNativeCourseActionRepositoryTest {
    @Test
    fun missingSessionDoesNotCreateGateway() {
        val repository = MoodleNativeCourseActionRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot()),
            gatewayFactory = { error("Gateway should not be created without a session") },
        )

        val result = runSuspend {
            repository.setCourseFavorite(
                course = course(),
                isFavorite = true,
            )
        }

        assertTrue(result is LiveCourseActionResult.MissingSession)
        assertEquals(42, (result.action as CourseAction.SetFavorite).course.id)
    }

    @Test
    fun setCourseFavoriteSendsCourseIDAndState() {
        val gateway = FakeCourseActionGateway()
        val repository = MoodleNativeCourseActionRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot(lmsSession = session())),
            gatewayFactory = { gateway },
            now = { Instant.parse("2026-06-12T03:04:05Z") },
        )

        val result = runSuspend {
            repository.setCourseFavorite(
                course = course(id = 42, isFavorite = false),
                isFavorite = true,
            )
        } as LiveCourseActionResult.Completed

        assertEquals(listOf(CourseFavoriteUpdate(id = 42, isFavorite = true)), gateway.updates)
        assertEquals(Instant.parse("2026-06-12T03:04:05Z"), result.completedAt)
        assertEquals(true, (result.action as CourseAction.SetFavorite).isFavorite)
    }

    @Test
    fun failureReturnsFailedResult() {
        val repository = MoodleNativeCourseActionRepository(
            sessionStore = FakeSessionStore(AppSessionSnapshot(lmsSession = session())),
            gatewayFactory = {
                FakeCourseActionGateway(error = IllegalStateException("favorite unavailable"))
            },
        )

        val result = runSuspend {
            repository.setCourseFavorite(
                course = course(),
                isFavorite = false,
            )
        } as LiveCourseActionResult.Failed

        assertEquals("favorite unavailable", result.message)
        assertEquals(false, (result.action as CourseAction.SetFavorite).isFavorite)
    }

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

    private class FakeCourseActionGateway(
        private val error: Exception? = null,
    ) : CourseActionGateway {
        val updates = mutableListOf<CourseFavoriteUpdate>()

        override suspend fun setFavouriteCourses(courses: List<CourseFavoriteUpdate>) {
            error?.let { throw it }
            updates += courses
        }
    }

    private companion object {
        fun course(
            id: Int = 42,
            isFavorite: Boolean = false,
        ): LmsCourseSummary =
            LmsCourseSummary(
                id = id,
                title = "ソフトウェア工学",
                courseCode = "IS-301",
                shortName = "2026-IS-301",
                summary = "Android port demo",
                courseImageURL = null,
                progress = 68.0,
                isFavorite = isFavorite,
                academicSemester = AcademicSemester(academicYear = 2026, season = SemesterSeason.SPRING),
                scheduleSlots = emptyList(),
                assignmentCount = 2,
                unreadAnnouncementCount = 1,
                unreadForumPostCount = 0,
                isRecentlyAccessed = true,
                detailURL = URI("https://lms.example.test/course/view.php?id=$id"),
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
