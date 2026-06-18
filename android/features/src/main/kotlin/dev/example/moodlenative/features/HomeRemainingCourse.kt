package dev.example.moodlenative.features

data class HomeRemainingCourse(
    val course: LmsCourseSummary,
    val periodIndex: Int,
    val room: String?,
) {
    val id: String
        get() = "${course.id}-$periodIndex"

    val periodTitle: String
        get() = "${periodIndex + 1}限"
}
