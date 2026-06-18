package dev.example.moodlenative.data

import dev.example.moodlenative.core.LmsAuthenticationSession
import dev.example.moodlenative.features.LmsCourseSummary
import dev.example.moodlenative.storage.AppSessionSnapshot
import dev.example.moodlenative.storage.AppSessionStore
import java.time.Instant

class MoodleNativeCourseActionRepository internal constructor(
    private val sessionStore: AppSessionStore,
    private val gatewayFactory: (LmsAuthenticationSession) -> CourseActionGateway = { session ->
        LmsCourseActionWebServiceGateway(session)
    },
    private val now: () -> Instant = { Instant.now() },
) {
    constructor(sessionStore: AppSessionStore) : this(
        sessionStore = sessionStore,
        gatewayFactory = { session -> LmsCourseActionWebServiceGateway(session) },
        now = { Instant.now() },
    )

    suspend fun setCourseFavorite(
        course: LmsCourseSummary,
        isFavorite: Boolean,
    ): LiveCourseActionResult {
        val action = CourseAction.SetFavorite(course = course, isFavorite = isFavorite)
        val snapshot = sessionStore.readSnapshot()
        val session = snapshot.lmsSession ?: return LiveCourseActionResult.MissingSession(snapshot, action)
        val gateway = gatewayFactory(session)
        val completedAt = now()

        return try {
            gateway.setFavouriteCourses(
                listOf(CourseFavoriteUpdate(id = course.id, isFavorite = isFavorite)),
            )
            LiveCourseActionResult.Completed(
                snapshot = sessionStore.readSnapshot(),
                action = action,
                completedAt = completedAt,
            )
        } catch (error: Exception) {
            LiveCourseActionResult.Failed(
                snapshot = sessionStore.readSnapshot(),
                action = action,
                message = error.message ?: "お気に入りを更新できませんでした。",
            )
        }
    }
}

internal interface CourseActionGateway {
    suspend fun setFavouriteCourses(courses: List<CourseFavoriteUpdate>)
}

internal data class CourseFavoriteUpdate(
    val id: Int,
    val isFavorite: Boolean,
)

sealed class CourseAction {
    data class SetFavorite(
        val course: LmsCourseSummary,
        val isFavorite: Boolean,
    ) : CourseAction()
}

sealed class LiveCourseActionResult {
    abstract val snapshot: AppSessionSnapshot
    abstract val action: CourseAction

    data class MissingSession(
        override val snapshot: AppSessionSnapshot,
        override val action: CourseAction,
    ) : LiveCourseActionResult()

    data class Completed(
        override val snapshot: AppSessionSnapshot,
        override val action: CourseAction,
        val completedAt: Instant,
    ) : LiveCourseActionResult()

    data class Failed(
        override val snapshot: AppSessionSnapshot,
        override val action: CourseAction,
        val message: String,
    ) : LiveCourseActionResult()
}
