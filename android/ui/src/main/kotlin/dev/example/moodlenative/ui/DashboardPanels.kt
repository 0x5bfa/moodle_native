package dev.example.moodlenative.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material.icons.outlined.Star
import androidx.compose.material.icons.outlined.Today
import androidx.compose.material3.AssistChip
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import dev.example.moodlenative.features.HomeRemainingCourse
import dev.example.moodlenative.features.HomeTabPresentationSupport
import dev.example.moodlenative.features.LmsCourseSummary
import dev.example.moodlenative.presentation.AppUiState

@Composable
internal fun HomeScreen(
    appState: AppUiState,
    onToggleCourseFavorite: (LmsCourseSummary) -> Unit,
) {
    val remainingCourses = HomeTabPresentationSupport.remainingCoursesToday(
        summaries = appState.courses,
        now = appState.now,
        zoneId = appState.zoneId,
    )
    val remainingAssignmentCount = HomeTabPresentationSupport.remainingAssignmentsThisWeekCount(
        assignments = appState.assignments,
        now = appState.now,
        zoneId = appState.zoneId,
    )

    ScreenList {
        item {
            SummaryBand(
                title = HomeTabPresentationSupport.navigationTitle(
                    date = appState.now,
                    zoneId = appState.zoneId,
                ),
                primary = "${remainingCourses.size} コマ",
                secondary = "${appState.dashboardStatusLabel} / 今週の課題 $remainingAssignmentCount 件",
            )
        }
        appState.courseActionMessage?.let { message ->
            item {
                InfoRow(
                    title = "授業操作",
                    subtitle = message,
                    leadingIcon = Icons.Outlined.Star,
                    accent = MaterialTheme.colorScheme.primary,
                )
            }
        }
        items(remainingCourses, key = { it.id }) { remainingCourse ->
            RemainingCourseRow(remainingCourse)
        }
        item {
            SectionLabel("最近の授業")
        }
        items(appState.courses.take(3), key = { it.id }) { course ->
            CourseRow(
                course = course,
                isUpdatingFavorite = appState.isUpdatingCourseFavorite,
                onToggleFavorite = { onToggleCourseFavorite(course) },
            )
        }
    }
}

@Composable
internal fun TimetableScreen(
    appState: AppUiState,
    onToggleCourseFavorite: (LmsCourseSummary) -> Unit,
) {
    ScreenList {
        item {
            SectionLabel("My時間割")
        }
        appState.courseActionMessage?.let { message ->
            item {
                InfoRow(
                    title = "授業操作",
                    subtitle = message,
                    leadingIcon = Icons.Outlined.Star,
                    accent = MaterialTheme.colorScheme.primary,
                )
            }
        }
        items(appState.courses, key = { it.id }) { course ->
            CourseRow(
                course = course,
                isUpdatingFavorite = appState.isUpdatingCourseFavorite,
                onToggleFavorite = { onToggleCourseFavorite(course) },
            )
        }
    }
}

@Composable
private fun RemainingCourseRow(course: HomeRemainingCourse) {
    InfoRow(
        title = course.course.title,
        subtitle = listOfNotNull(course.periodTitle, course.room).joinToString(" / "),
        leadingIcon = Icons.Outlined.Today,
        accent = if (course.course.isFavorite) MaterialTheme.colorScheme.tertiary else MaterialTheme.colorScheme.secondary,
    )
}

@Composable
private fun CourseRow(
    course: LmsCourseSummary,
    isUpdatingFavorite: Boolean,
    onToggleFavorite: () -> Unit,
) {
    ElevatedCard(
        colors = CardDefaults.elevatedCardColors(containerColor = MaterialTheme.colorScheme.surface),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                IconBadge(
                    icon = if (course.isFavorite) Icons.Outlined.Star else Icons.Outlined.CalendarMonth,
                    color = if (course.isFavorite) MaterialTheme.colorScheme.tertiary else MaterialTheme.colorScheme.secondary,
                )
                Spacer(Modifier.width(12.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = course.title,
                        style = MaterialTheme.typography.titleMedium,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                    )
                    Text(
                        text = listOfNotNull(course.courseCode, course.academicSemester?.compactDisplayName).joinToString(" / "),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
                IconButton(
                    onClick = onToggleFavorite,
                    enabled = !isUpdatingFavorite,
                ) {
                    Icon(
                        Icons.Outlined.Star,
                        contentDescription = if (course.isFavorite) "お気に入りから外す" else "お気に入りに追加",
                        tint = if (course.isFavorite) MaterialTheme.colorScheme.tertiary else MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            Spacer(Modifier.height(12.dp))
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                course.scheduleSlots.forEach { slot ->
                    AssistChip(
                        onClick = {},
                        label = {
                            Text("${weekdayLabel(slot.dayIndex)} ${slot.periodIndices.joinToString(",") { "${it + 1}限" }}")
                        },
                        leadingIcon = { Icon(Icons.Outlined.Schedule, contentDescription = null, modifier = Modifier.size(18.dp)) },
                    )
                }
            }
        }
    }
}

private fun weekdayLabel(dayIndex: Int): String =
    listOf("月", "火", "水", "木", "金").getOrElse(dayIndex) { "他" }
