package dev.example.moodlenative.ui

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.Assignment
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.Forum
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.ui.graphics.vector.ImageVector

internal enum class AppTab(
    val title: String,
    val icon: ImageVector,
) {
    HOME("ホーム", Icons.Outlined.Home),
    TIMETABLE("時間割", Icons.Outlined.CalendarMonth),
    ASSIGNMENTS("課題", Icons.AutoMirrored.Outlined.Assignment),
    FORUM("フォーラム", Icons.Outlined.Forum),
    NOTIFICATIONS("通知", Icons.Outlined.Notifications),
    SETTINGS("設定", Icons.Outlined.Settings),
}
