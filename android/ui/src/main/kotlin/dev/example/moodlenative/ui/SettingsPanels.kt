package dev.example.moodlenative.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.Login
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Refresh
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.Today
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import dev.example.moodlenative.features.CalendarSubscriptionPresentation
import dev.example.moodlenative.presentation.AppUiState

@Composable
internal fun SettingsScreen(
    appState: AppUiState,
    onStartLmsLogin: () -> Unit,
    onRefreshDashboard: () -> Unit,
    onClearLmsSession: () -> Unit,
    onLoadNotificationPreferences: () -> Unit,
    onSelectNotificationPreferenceProcessor: (String) -> Unit,
    onSetAllNotificationsEnabled: (Boolean) -> Unit,
    onSetNotificationPreferenceEnabled: (String, String, Boolean) -> Unit,
    onSetLegacyNotificationPreferenceState: (String, String, String, Boolean) -> Unit,
    onLoadMessagePreferences: () -> Unit,
    onSetMessageContactablePrivacy: (Int) -> Unit,
    onSetInstantMessageProcessorEnabled: (String, String, Boolean) -> Unit,
    onLoadCalendarPreferences: () -> Unit,
    onSetCalendarPreferenceValue: (String, String) -> Unit,
    onMakeCalendarSubscription: () -> Unit,
) {
    ScreenList {
        item {
            SummaryBand(
                title = "Moodle Native",
                primary = "Android",
                secondary = appState.sessionStatusLabel,
            )
        }
        item {
            InfoRow(
                title = "Moodle",
                subtitle = appState.lmsSessionLabel,
            )
        }
        item {
            LmsSessionActions(
                appState = appState,
                onStartLmsLogin = onStartLmsLogin,
                onRefreshDashboard = onRefreshDashboard,
                onClearLmsSession = onClearLmsSession,
            )
        }
        appState.sessionActionMessage?.let { message ->
            item {
                InfoRow(
                    title = "操作",
                    subtitle = message,
                    leadingIcon = Icons.Outlined.Settings,
                )
            }
        }
        item {
            InfoRow(
                title = "Dashboard",
                subtitle = appState.dashboardStatusDetail,
                leadingIcon = Icons.Outlined.Schedule,
            )
        }
        item {
            CalendarPreferencesPanel(
                appState = appState,
                onLoadCalendarPreferences = onLoadCalendarPreferences,
                onSetCalendarPreferenceValue = onSetCalendarPreferenceValue,
            )
        }
        item {
            CalendarSubscriptionActions(
                appState = appState,
                onMakeCalendarSubscription = onMakeCalendarSubscription,
            )
        }
        appState.calendarStatusMessage?.let { message ->
            item {
                InfoRow(
                    title = "LMS カレンダー",
                    subtitle = message,
                    leadingIcon = Icons.Outlined.CalendarMonth,
                    accent = MaterialTheme.colorScheme.primary,
                )
            }
        }
        appState.calendarSubscription?.let { subscription ->
            item {
                CalendarSubscriptionCard(subscription)
            }
        }
        if (appState.unreadNotificationCount > 0) {
            item {
                InfoRow(
                    title = "通知",
                    subtitle = "未読 ${appState.unreadNotificationCount} 件",
                    leadingIcon = Icons.Outlined.Today,
                )
            }
        }
        item {
            MessagePreferencesPanel(
                appState = appState,
                onLoadMessagePreferences = onLoadMessagePreferences,
                onSetContactablePrivacy = onSetMessageContactablePrivacy,
                onSetProcessorEnabled = onSetInstantMessageProcessorEnabled,
            )
        }
        item {
            NotificationPreferencesPanel(
                appState = appState,
                onLoadNotificationPreferences = onLoadNotificationPreferences,
                onSelectProcessor = onSelectNotificationPreferenceProcessor,
                onSetAllNotificationsEnabled = onSetAllNotificationsEnabled,
                onSetNotificationEnabled = onSetNotificationPreferenceEnabled,
                onSetLegacyState = onSetLegacyNotificationPreferenceState,
            )
        }
        appState.partialErrors.forEachIndexed { index, message ->
            item {
                InfoRow(
                    title = "一部取得失敗 ${index + 1}",
                    subtitle = message,
                    leadingIcon = Icons.Outlined.Settings,
                    accent = MaterialTheme.colorScheme.primary,
                )
            }
        }
    }
}

@Composable
private fun CalendarSubscriptionActions(
    appState: AppUiState,
    onMakeCalendarSubscription: () -> Unit,
) {
    FlowRow(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        FilledTonalButton(
            onClick = onMakeCalendarSubscription,
            enabled = appState.session.hasLmsSession && !appState.isLoadingCalendarSubscription,
        ) {
            Icon(Icons.Outlined.CalendarMonth, contentDescription = null, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(8.dp))
            Text(if (appState.isLoadingCalendarSubscription) "生成中" else "カレンダー URL 生成")
        }
    }
}

@Composable
private fun CalendarSubscriptionCard(subscription: CalendarSubscriptionPresentation) {
    ElevatedCard(
        colors = CardDefaults.elevatedCardColors(containerColor = MaterialTheme.colorScheme.surface),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "LMS カレンダー URL",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
            )
            Spacer(Modifier.height(10.dp))
            AssignmentDetailRow("webcal", subscription.webcalURL)
            AssignmentDetailRow("https", subscription.httpsURL)
        }
    }
}

@Composable
private fun LmsSessionActions(
    appState: AppUiState,
    onStartLmsLogin: () -> Unit,
    onRefreshDashboard: () -> Unit,
    onClearLmsSession: () -> Unit,
) {
    FlowRow(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        if (appState.session.hasLmsSession) {
            FilledTonalButton(
                onClick = onRefreshDashboard,
                enabled = !appState.isLoadingLiveDashboard,
            ) {
                Icon(Icons.Outlined.Refresh, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(8.dp))
                Text(if (appState.isLoadingLiveDashboard) "同期中" else "再読み込み")
            }
            OutlinedButton(onClick = onClearLmsSession) {
                Icon(Icons.Outlined.Delete, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(8.dp))
                Text("削除")
            }
        } else {
            FilledTonalButton(onClick = onStartLmsLogin) {
                Icon(Icons.AutoMirrored.Outlined.Login, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(8.dp))
                Text("Moodle に接続")
            }
        }
    }
}
