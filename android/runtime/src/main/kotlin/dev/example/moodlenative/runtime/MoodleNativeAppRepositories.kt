package dev.example.moodlenative.runtime

import dev.example.moodlenative.data.MoodleNativeAssignmentActionRepository
import dev.example.moodlenative.data.MoodleNativeAssignmentDetailRepository
import dev.example.moodlenative.data.MoodleNativeCalendarPreferencesRepository
import dev.example.moodlenative.data.MoodleNativeCalendarRepository
import dev.example.moodlenative.data.MoodleNativeCourseActionRepository
import dev.example.moodlenative.data.MoodleNativeForumActionRepository
import dev.example.moodlenative.data.MoodleNativeForumRepository
import dev.example.moodlenative.data.MoodleNativeLiveRepository
import dev.example.moodlenative.data.MoodleNativeMessagePreferencesRepository
import dev.example.moodlenative.data.MoodleNativeNotificationPreferencesRepository
import dev.example.moodlenative.data.MoodleNativeNotificationRepository
import dev.example.moodlenative.storage.AppSessionStore

internal class MoodleNativeAppRepositories(
    sessionStore: AppSessionStore,
    val live: MoodleNativeLiveRepository = MoodleNativeLiveRepository(sessionStore),
    val assignmentDetail: MoodleNativeAssignmentDetailRepository = MoodleNativeAssignmentDetailRepository(sessionStore),
    val assignmentAction: MoodleNativeAssignmentActionRepository = MoodleNativeAssignmentActionRepository(sessionStore),
    val forum: MoodleNativeForumRepository = MoodleNativeForumRepository(sessionStore),
    val forumAction: MoodleNativeForumActionRepository = MoodleNativeForumActionRepository(sessionStore),
    val notification: MoodleNativeNotificationRepository = MoodleNativeNotificationRepository(sessionStore),
    val notificationPreferences: MoodleNativeNotificationPreferencesRepository =
        MoodleNativeNotificationPreferencesRepository(sessionStore),
    val messagePreferences: MoodleNativeMessagePreferencesRepository = MoodleNativeMessagePreferencesRepository(sessionStore),
    val courseAction: MoodleNativeCourseActionRepository = MoodleNativeCourseActionRepository(sessionStore),
    val calendar: MoodleNativeCalendarRepository = MoodleNativeCalendarRepository(sessionStore),
    val calendarPreferences: MoodleNativeCalendarPreferencesRepository = MoodleNativeCalendarPreferencesRepository(sessionStore),
)
