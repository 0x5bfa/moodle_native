package dev.example.moodlenative.features

import dev.example.moodlenative.core.LmsAssignmentItem
import java.text.Collator
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.temporal.TemporalAdjusters
import java.util.Locale

object HomeTabPresentationSupport {
    fun navigationTitle(
        date: Instant,
        zoneId: ZoneId = ZoneId.systemDefault(),
        locale: Locale = Locale.JAPAN,
    ): String {
        val formatter = DateTimeFormatter.ofPattern("M月d日(E)", locale)
        return formatter.format(date.atZone(zoneId))
    }

    fun remainingCoursesToday(
        summaries: List<LmsCourseSummary>,
        now: Instant = Instant.now(),
        zoneId: ZoneId = ZoneId.systemDefault(),
    ): List<HomeRemainingCourse> {
        val weekdayIndex = weekdayIndex(now, zoneId) ?: return emptyList()
        val titleCollator = Collator.getInstance(Locale.JAPAN)

        return summaries
            .flatMap { summary ->
                summary.scheduleSlots
                    .filter { it.dayIndex == weekdayIndex }
                    .flatMap { slot ->
                        slot.periodIndices.map { periodIndex ->
                            HomeRemainingCourse(
                                course = summary,
                                periodIndex = periodIndex,
                                room = slot.room ?: summary.courseCode,
                            )
                        }
                    }
            }
            .filter { course ->
                val endDate = periodEndDate(course.periodIndex, now, zoneId)
                endDate == null || endDate > now
            }
            .sortedWith(
                compareBy<HomeRemainingCourse> { it.periodIndex }
                    .thenComparator { lhs, rhs ->
                        titleCollator.compare(lhs.course.title, rhs.course.title)
                    },
            )
    }

    fun remainingAssignmentsThisWeekCount(
        assignments: List<LmsAssignmentItem>,
        now: Instant = Instant.now(),
        zoneId: ZoneId = ZoneId.systemDefault(),
    ): Int {
        val zonedNow = now.atZone(zoneId)
        val weekEnd = zonedNow
            .toLocalDate()
            .with(TemporalAdjusters.next(DayOfWeek.MONDAY))
            .atStartOfDay(zoneId)
            .toInstant()

        return assignments.count { assignment ->
            val dueDate = assignment.dueDate
            dueDate != null && dueDate >= now && dueDate < weekEnd
        }
    }

    fun weekdayIndex(
        date: Instant,
        zoneId: ZoneId = ZoneId.systemDefault(),
    ): Int? =
        when (date.atZone(zoneId).dayOfWeek) {
            DayOfWeek.MONDAY -> 0
            DayOfWeek.TUESDAY -> 1
            DayOfWeek.WEDNESDAY -> 2
            DayOfWeek.THURSDAY -> 3
            DayOfWeek.FRIDAY -> 4
            DayOfWeek.SATURDAY,
            DayOfWeek.SUNDAY,
            -> null
        }

    private fun periodEndDate(
        periodIndex: Int,
        date: Instant,
        zoneId: ZoneId,
    ): Instant? {
        if (periodIndex < 0) {
            return null
        }

        val startMinutes = if (periodIndex < morningPeriodCount) {
            firstPeriodStartMinutes + periodIndex * (classDurationMinutes + breakDurationMinutes)
        } else {
            afternoonFirstPeriodStartMinutes +
                (periodIndex - morningPeriodCount) * (classDurationMinutes + breakDurationMinutes)
        }
        val endMinutes = startMinutes + classDurationMinutes
        val endTime = LocalTime.of(endMinutes / minutesPerHour, endMinutes % minutesPerHour)

        return date
            .atZone(zoneId)
            .toLocalDate()
            .atTime(endTime)
            .atZone(zoneId)
            .toInstant()
    }

    private const val firstPeriodStartMinutes = 9 * 60
    private const val afternoonFirstPeriodStartMinutes = 13 * 60 + 10
    private const val morningPeriodCount = 2
    private const val classDurationMinutes = 95
    private const val breakDurationMinutes = 10
    private const val minutesPerHour = 60
}
