package dev.example.moodlenative.data

import dev.example.moodlenative.core.LmsAuthenticationSession
import dev.example.moodlenative.networking.LmsWebServiceClient
import dev.example.moodlenative.networking.FavouriteCourseUpdate as NetworkFavouriteCourseUpdate

internal class LmsCourseActionWebServiceGateway(
    session: LmsAuthenticationSession,
) : CourseActionGateway {
    private val client = LmsWebServiceClient(session.toLmsWebServiceSession())

    override suspend fun setFavouriteCourses(courses: List<CourseFavoriteUpdate>) {
        client.setFavouriteCourses(
            courses.map { course ->
                NetworkFavouriteCourseUpdate(id = course.id, isFavorite = course.isFavorite)
            },
        )
    }
}
