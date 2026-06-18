package dev.example.moodlenative.presentation

import dev.example.moodlenative.core.AcademicSemester
import dev.example.moodlenative.core.LmsAssignmentItem
import dev.example.moodlenative.core.LmsNotificationItem
import dev.example.moodlenative.core.SemesterSeason
import dev.example.moodlenative.core.TimetableScheduleSlot
import dev.example.moodlenative.features.LmsCourseSummary
import java.net.URI
import java.time.Instant
import java.time.ZoneId

object AppDemoData {
    val zoneId: ZoneId = ZoneId.of("Asia/Tokyo")
    val now: Instant = Instant.parse("2026-06-08T00:30:00Z")

    private val semester = AcademicSemester(academicYear = 2026, season = SemesterSeason.SPRING)

    val courses = listOf(
        LmsCourseSummary(
            id = 42,
            title = "ソフトウェア工学",
            courseCode = "IS-301",
            shortName = "2026-IS-301",
            summary = "Android port demo",
            courseImageURL = null,
            progress = 68.0,
            isFavorite = true,
            academicSemester = semester,
            scheduleSlots = listOf(TimetableScheduleSlot(dayIndex = 0, periodIndices = listOf(0), room = "H101")),
            assignmentCount = 2,
            unreadAnnouncementCount = 1,
            unreadForumPostCount = 0,
            isRecentlyAccessed = true,
            detailURL = URI("https://lms.example.test/course/view.php?id=42"),
        ),
        LmsCourseSummary(
            id = 43,
            title = "情報倫理",
            courseCode = "IS-204",
            shortName = "2026-IS-204",
            summary = null,
            courseImageURL = null,
            progress = 40.0,
            isFavorite = false,
            academicSemester = semester,
            scheduleSlots = listOf(TimetableScheduleSlot(dayIndex = 0, periodIndices = listOf(2), room = "C201")),
            assignmentCount = 1,
            unreadAnnouncementCount = 0,
            unreadForumPostCount = 2,
            isRecentlyAccessed = true,
            detailURL = URI("https://lms.example.test/course/view.php?id=43"),
        ),
        LmsCourseSummary(
            id = 44,
            title = "データベース",
            courseCode = "IS-220",
            shortName = "2026-IS-220",
            summary = null,
            courseImageURL = null,
            progress = 20.0,
            isFavorite = false,
            academicSemester = semester,
            scheduleSlots = listOf(TimetableScheduleSlot(dayIndex = 2, periodIndices = listOf(1), room = "B102")),
            assignmentCount = 3,
            unreadAnnouncementCount = 0,
            unreadForumPostCount = 1,
            isRecentlyAccessed = false,
            detailURL = URI("https://lms.example.test/course/view.php?id=44"),
        ),
    )

    val assignments = listOf(
        LmsAssignmentItem(
            id = 501,
            courseID = 42,
            courseModuleID = 9001,
            courseTitle = "ソフトウェア工学",
            courseCode = "IS-301",
            courseShortName = "2026-IS-301",
            title = "設計レビュー課題",
            introPreview = "提出前にレビュー観点を整理する。",
            dueDate = Instant.parse("2026-06-10T14:59:00Z"),
            allowsSubmissionsFromDate = null,
            cutoffDate = null,
            updatedAt = now,
        ),
        LmsAssignmentItem(
            id = 502,
            courseID = 43,
            courseModuleID = 9002,
            courseTitle = "情報倫理",
            courseCode = "IS-204",
            courseShortName = "2026-IS-204",
            title = "ケーススタディ",
            introPreview = null,
            dueDate = Instant.parse("2026-06-12T14:59:00Z"),
            allowsSubmissionsFromDate = null,
            cutoffDate = null,
            updatedAt = now,
        ),
    )

    val notifications = listOf(
        LmsNotificationItem(
            id = "demo-reminder",
            lmsNotificationID = 2_613_999,
            source = "Moodle",
            title = "必須課題1-6提出先の提出期限",
            preview = "提出期限が近づいています。",
            plainBody = """
                (2026-53356-13_課題) 「必須課題1-6提出先」の提出期限 [1 day to go]
                いつ: 2026年 04月 16日(木曜日) 17:00 - JST
                コース: 53356:プログラミング演習２(B1)
                活動: 13_課題: 必須課題1-6提出先
            """.trimIndent(),
            fullMessage = """
                (2026-53356-13_課題) 「必須課題1-6提出先」の提出期限 [1 day to go]
                いつ: 2026年 04月 16日(木曜日) 17:00 - JST
                コース: 53356:プログラミング演習２(B1)
                活動: 13_課題: 必須課題1-6提出先
            """.trimIndent(),
            htmlBody = null,
            receivedAt = Instant.parse("2026-06-08T00:05:00Z"),
            isUnread = true,
            isImportant = false,
            externalURL = URI("https://lms.example.test/mod/assign/view.php?id=127579"),
            component = "local_reminders",
            eventType = "reminders_due",
            contextName = "必須課題1-6提出先",
        ),
        LmsNotificationItem(
            id = "demo-submission",
            lmsNotificationID = 2_124_761,
            source = "Moodle",
            title = "課題提出を送信しました",
            preview = "あなたは課題への提出を送信しました。",
            plainBody = "あなたは課題「必須課題1-2提出先」への提出を送信しました。",
            fullMessage = "あなたは課題「必須課題1-2提出先」への提出を送信しました。",
            htmlBody = null,
            receivedAt = Instant.parse("2026-06-07T02:20:00Z"),
            isUnread = false,
            isImportant = false,
            externalURL = URI("https://lms.example.test/mod/assign/view.php?id=127570"),
            component = "mod_assign",
            eventType = "assign_notification",
            contextName = "必須課題1-2提出先",
        ),
    )
}
