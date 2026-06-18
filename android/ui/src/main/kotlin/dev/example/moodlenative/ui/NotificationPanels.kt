package dev.example.moodlenative.ui

import androidx.compose.foundation.clickable
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
import androidx.compose.material.icons.automirrored.outlined.OpenInNew
import androidx.compose.material.icons.outlined.Done
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material3.AssistChip
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import dev.example.moodlenative.core.LmsHTMLTextFormatter
import dev.example.moodlenative.core.LmsNotificationItem
import dev.example.moodlenative.features.LmsNotificationDetailPresentation
import dev.example.moodlenative.features.detailPresentation
import dev.example.moodlenative.features.isUnread
import dev.example.moodlenative.features.metadataItems
import dev.example.moodlenative.presentation.AppUiState

@Composable
internal fun NotificationsScreen(
    appState: AppUiState,
    selectedNotificationID: String?,
    onSelectNotification: (String) -> Unit,
    onMarkNotificationRead: (LmsNotificationItem) -> Unit,
    onMarkAllNotificationsRead: () -> Unit,
) {
    val selectedNotification = appState.notifications
        .firstOrNull { it.id == selectedNotificationID }
        ?: appState.notifications.firstOrNull()

    ScreenList {
        item {
            SummaryBand(
                title = "通知",
                primary = appState.notificationPrimaryLabel,
                secondary = appState.notificationStatusLabel,
            )
        }
        item {
            NotificationActionControls(
                appState = appState,
                selectedNotification = selectedNotification,
                onMarkNotificationRead = onMarkNotificationRead,
                onMarkAllNotificationsRead = onMarkAllNotificationsRead,
            )
        }
        appState.notificationActionMessage?.let { message ->
            item {
                InfoRow(
                    title = "通知操作",
                    subtitle = message,
                    leadingIcon = Icons.Outlined.Notifications,
                    accent = MaterialTheme.colorScheme.primary,
                )
            }
        }
        selectedNotification?.let { notification ->
            item {
                SectionLabel("詳細")
            }
            item {
                NotificationDetailCard(notification)
            }
        }
        item {
            SectionLabel("通知一覧")
        }
        if (appState.notifications.isEmpty()) {
            item {
                InfoRow(
                    title = "通知",
                    subtitle = if (appState.isLoadingLiveDashboard) "取得中" else "通知はありません",
                    leadingIcon = Icons.Outlined.Notifications,
                )
            }
        } else {
            items(appState.notifications, key = { it.id }) { notification ->
                NotificationRow(
                    notification = notification,
                    isSelected = notification.id == selectedNotification?.id,
                    onClick = { onSelectNotification(notification.id) },
                )
            }
        }
    }
}

@Composable
private fun NotificationActionControls(
    appState: AppUiState,
    selectedNotification: LmsNotificationItem?,
    onMarkNotificationRead: (LmsNotificationItem) -> Unit,
    onMarkAllNotificationsRead: () -> Unit,
) {
    FlowRow(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        FilledTonalButton(
            onClick = {
                if (selectedNotification != null) {
                    onMarkNotificationRead(selectedNotification)
                }
            },
            enabled = !appState.isUpdatingNotifications &&
                selectedNotification?.isUnread == true &&
                selectedNotification?.lmsNotificationID != null,
        ) {
            Icon(Icons.Outlined.Done, contentDescription = null, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(8.dp))
            Text(if (appState.isUpdatingNotifications) "更新中" else "既読にする")
        }
        OutlinedButton(
            onClick = onMarkAllNotificationsRead,
            enabled = !appState.isUpdatingNotifications && appState.notifications.any { it.isUnread },
        ) {
            Icon(Icons.Outlined.Done, contentDescription = null, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(8.dp))
            Text("すべて既読")
        }
    }
}

@Composable
private fun NotificationRow(
    notification: LmsNotificationItem,
    isSelected: Boolean,
    onClick: () -> Unit,
) {
    val accent = when {
        isSelected -> MaterialTheme.colorScheme.primary
        notification.isUnread -> MaterialTheme.colorScheme.tertiary
        else -> MaterialTheme.colorScheme.secondary
    }
    val subtitle = listOfNotNull(
        notification.source,
        notification.receivedAt.toString(),
        if (notification.isUnread) "未読" else "既読",
        notification.contextName,
    ).joinToString(" / ")

    InfoRow(
        title = notification.title,
        subtitle = subtitle,
        leadingIcon = Icons.Outlined.Notifications,
        accent = accent,
        modifier = Modifier.clickable(onClick = onClick),
    )
}

@Composable
private fun NotificationDetailCard(notification: LmsNotificationItem) {
    val presentation = notification.detailPresentation

    ElevatedCard(
        colors = CardDefaults.elevatedCardColors(containerColor = MaterialTheme.colorScheme.surface),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                IconBadge(
                    icon = Icons.Outlined.Notifications,
                    color = if (notification.isUnread) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.secondary,
                )
                Spacer(Modifier.width(12.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = notification.title,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                    )
                    Text(
                        text = "${notification.source} / ${notification.receivedAt}",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
            Spacer(Modifier.height(12.dp))
            Text(
                text = notification.preview,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 4,
                overflow = TextOverflow.Ellipsis,
            )
            Spacer(Modifier.height(12.dp))
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                notification.metadataItems.forEach { item ->
                    AssistChip(
                        onClick = {},
                        label = { Text("${item.first}: ${item.second}") },
                    )
                }
                notification.externalURL?.let {
                    AssistChip(
                        onClick = {},
                        label = { Text("リンクあり") },
                        leadingIcon = {
                            Icon(
                                Icons.AutoMirrored.Outlined.OpenInNew,
                                contentDescription = null,
                                modifier = Modifier.size(18.dp),
                            )
                        },
                    )
                }
            }
            presentation.sections.forEach { section ->
                NotificationDetailSection(section)
            }
        }
    }
}

@Composable
private fun NotificationDetailSection(section: LmsNotificationDetailPresentation.Section) {
    Spacer(Modifier.height(16.dp))
    section.title?.let { title ->
        Text(
            text = title,
            style = MaterialTheme.typography.titleSmall,
            color = MaterialTheme.colorScheme.primary,
            fontWeight = FontWeight.SemiBold,
        )
        Spacer(Modifier.height(6.dp))
    }
    section.rows.forEach { row ->
        NotificationDetailRow(row)
    }
}

@Composable
private fun NotificationDetailRow(row: LmsNotificationDetailPresentation.Section.Row) {
    val label = row.label
    val content = row.content

    if (label != null) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.primary,
            fontWeight = FontWeight.SemiBold,
        )
    }

    when (content) {
        is LmsNotificationDetailPresentation.Section.Row.Content.Html -> {
            Text(
                text = LmsHTMLTextFormatter.plainText(content.html) ?: content.html,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface,
            )
        }

        is LmsNotificationDetailPresentation.Section.Row.Content.Link -> {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = content.title,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.weight(1f),
                )
                Icon(
                    Icons.AutoMirrored.Outlined.OpenInNew,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(18.dp),
                )
            }
        }

        is LmsNotificationDetailPresentation.Section.Row.Content.Text -> {
            Text(
                text = content.text,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface,
            )
        }
    }
    Spacer(Modifier.height(8.dp))
}
