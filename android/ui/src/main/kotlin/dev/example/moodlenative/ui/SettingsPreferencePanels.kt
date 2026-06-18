package dev.example.moodlenative.ui

import androidx.compose.foundation.background
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material.icons.outlined.Refresh
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import dev.example.moodlenative.features.LegacyNotificationPreferenceStatePresentation
import dev.example.moodlenative.features.NotificationPreferencePresentation
import dev.example.moodlenative.features.NotificationPreferencesComponentPresentation
import dev.example.moodlenative.presentation.AppUiState
import dev.example.moodlenative.presentation.PreferenceOption
import dev.example.moodlenative.presentation.calendarWeekdayOptions

@Composable
internal fun MessagePreferencesPanel(
    appState: AppUiState,
    onLoadMessagePreferences: () -> Unit,
    onSetContactablePrivacy: (Int) -> Unit,
    onSetProcessorEnabled: (String, String, Boolean) -> Unit,
) {
    val preferences = appState.messagePreferencesPresentation

    ElevatedCard(
        colors = CardDefaults.elevatedCardColors(containerColor = MaterialTheme.colorScheme.surface),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                SettingsIconBadge(Icons.Outlined.Person, MaterialTheme.colorScheme.secondary)
                Spacer(Modifier.width(12.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = "Moodle メッセージ設定",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Text(
                        text = appState.messagePreferencesStatusLabel,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                IconButton(
                    onClick = onLoadMessagePreferences,
                    enabled = appState.session.hasLmsSession && !appState.isLoadingMessagePreferences,
                ) {
                    Icon(Icons.Outlined.Refresh, contentDescription = "メッセージ設定を再読み込み")
                }
            }

            appState.messagePreferencesMessage?.let { message ->
                Spacer(Modifier.height(10.dp))
                Text(
                    text = message,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.primary,
                )
            }

            Spacer(Modifier.height(12.dp))

            when {
                appState.isLoadingMessagePreferences && preferences == null -> {
                    Text(
                        text = "メッセージ設定を読み込み中",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                preferences == null -> {
                    Text(
                        text = if (appState.session.hasLmsSession) {
                            "メッセージ設定を読み込むと、LMS の連絡範囲と通知先を変更できます。"
                        } else {
                            "Moodle に接続するとメッセージ設定を変更できます。"
                        },
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                else -> {
                    Text(
                        text = "連絡を受け取る範囲",
                        style = MaterialTheme.typography.titleSmall,
                        color = MaterialTheme.colorScheme.primary,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Spacer(Modifier.height(8.dp))
                    FlowRow(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        preferences.contactScopeOptions.forEach { option ->
                            FilterChip(
                                selected = preferences.selectedContactScopeValue == option.value,
                                onClick = { onSetContactablePrivacy(option.value) },
                                label = { Text(option.label) },
                                enabled = !appState.isUpdatingMessagePreferences,
                            )
                        }
                    }

                    Spacer(Modifier.height(14.dp))
                    Text(
                        text = "インスタントメッセージ",
                        style = MaterialTheme.typography.titleSmall,
                        color = MaterialTheme.colorScheme.primary,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Spacer(Modifier.height(8.dp))

                    if (preferences.instantMessageProcessors.isEmpty()) {
                        Text(
                            text = "表示できる通知先がありません。",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    } else {
                        preferences.instantMessageProcessors.forEach { processor ->
                            PreferenceSwitchRow(
                                title = processor.title,
                                subtitle = processor.subtitle,
                                checked = processor.checked,
                                enabled = !appState.isUpdatingMessagePreferences &&
                                    !processor.locked &&
                                    !preferences.areNotificationsDisabled,
                                onCheckedChange = { isEnabled ->
                                    onSetProcessorEnabled(
                                        processor.preferenceKey,
                                        processor.processorName,
                                        isEnabled,
                                    )
                                },
                            )
                            Spacer(Modifier.height(10.dp))
                        }
                    }

                    if (preferences.areNotificationsDisabled) {
                        Text(
                            text = "通知全体が無効のため、通知先の変更が反映されない場合があります。",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }
        }
    }
}

@Composable
internal fun NotificationPreferencesPanel(
    appState: AppUiState,
    onLoadNotificationPreferences: () -> Unit,
    onSelectProcessor: (String) -> Unit,
    onSetAllNotificationsEnabled: (Boolean) -> Unit,
    onSetNotificationEnabled: (String, String, Boolean) -> Unit,
    onSetLegacyState: (String, String, String, Boolean) -> Unit,
) {
    val preferences = appState.notificationPreferencesPresentation
    val selectedProcessor = preferences?.selectedProcessor

    ElevatedCard(
        colors = CardDefaults.elevatedCardColors(containerColor = MaterialTheme.colorScheme.surface),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                SettingsIconBadge(Icons.Outlined.Notifications, MaterialTheme.colorScheme.primary)
                Spacer(Modifier.width(12.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = "Moodle 通知設定",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Text(
                        text = appState.notificationPreferencesStatusLabel,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                IconButton(
                    onClick = onLoadNotificationPreferences,
                    enabled = appState.session.hasLmsSession && !appState.isLoadingNotificationPreferences,
                ) {
                    Icon(Icons.Outlined.Refresh, contentDescription = "通知設定を再読み込み")
                }
            }

            appState.notificationPreferencesMessage?.let { message ->
                Spacer(Modifier.height(10.dp))
                Text(
                    text = message,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.primary,
                )
            }

            Spacer(Modifier.height(12.dp))

            when {
                appState.isLoadingNotificationPreferences && preferences == null -> {
                    Text(
                        text = "通知設定を読み込み中",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                preferences == null -> {
                    Text(
                        text = if (appState.session.hasLmsSession) {
                            "通知設定を読み込むと、LMS の通知先をここで変更できます。"
                        } else {
                            "Moodle に接続すると通知設定を変更できます。"
                        },
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                else -> {
                    PreferenceSwitchRow(
                        title = "すべての通知",
                        subtitle = "Moodle 側の全通知をまとめて切り替えます。",
                        checked = preferences.enableAll,
                        enabled = !appState.isUpdatingNotificationPreferences,
                        onCheckedChange = onSetAllNotificationsEnabled,
                    )

                    if (preferences.processors.size > 1) {
                        Spacer(Modifier.height(12.dp))
                        FlowRow(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            verticalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            preferences.processors.forEach { processor ->
                                FilterChip(
                                    selected = processor.name == selectedProcessor?.name,
                                    onClick = { onSelectProcessor(processor.name) },
                                    label = { Text(processor.displayName) },
                                    enabled = !appState.isUpdatingNotificationPreferences,
                                )
                            }
                        }
                    }

                    Spacer(Modifier.height(14.dp))
                    if (preferences.components.isEmpty() || selectedProcessor == null) {
                        Text(
                            text = "表示できる通知設定がありません。",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    } else {
                        preferences.components.forEach { component ->
                            NotificationPreferencesComponentSection(
                                component = component,
                                isUpdating = appState.isUpdatingNotificationPreferences,
                                onSetNotificationEnabled = onSetNotificationEnabled,
                                onSetLegacyState = onSetLegacyState,
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun NotificationPreferencesComponentSection(
    component: NotificationPreferencesComponentPresentation,
    isUpdating: Boolean,
    onSetNotificationEnabled: (String, String, Boolean) -> Unit,
    onSetLegacyState: (String, String, String, Boolean) -> Unit,
) {
    Text(
        text = component.title,
        style = MaterialTheme.typography.titleSmall,
        color = MaterialTheme.colorScheme.primary,
        fontWeight = FontWeight.SemiBold,
    )
    component.description?.takeIf { it.isNotBlank() }?.let { description ->
        Text(
            text = description,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.primary,
        )
    }
    Spacer(Modifier.height(8.dp))

    component.notifications.forEach { notification ->
        NotificationPreferenceRow(
            notification = notification,
            isUpdating = isUpdating,
            onSetNotificationEnabled = onSetNotificationEnabled,
            onSetLegacyState = onSetLegacyState,
        )
        Spacer(Modifier.height(10.dp))
    }
}

@Composable
private fun NotificationPreferenceRow(
    notification: NotificationPreferencePresentation,
    isUpdating: Boolean,
    onSetNotificationEnabled: (String, String, Boolean) -> Unit,
    onSetLegacyState: (String, String, String, Boolean) -> Unit,
) {
    val directToggle = notification.directToggle
    if (directToggle != null) {
        PreferenceSwitchRow(
            title = notification.title,
            subtitle = directToggle.subtitle,
            checked = directToggle.checked,
            enabled = !isUpdating && !directToggle.locked,
            onCheckedChange = { isEnabled ->
                onSetNotificationEnabled(
                    directToggle.preferenceKey,
                    directToggle.processorName,
                    isEnabled,
                )
            },
        )
    } else {
        Text(
            text = notification.title,
            style = MaterialTheme.typography.bodyLarge,
            fontWeight = FontWeight.Medium,
        )
        notification.legacyStates.forEach { state ->
            LegacyNotificationPreferenceSwitchRow(
                state = state,
                isUpdating = isUpdating,
                onSetLegacyState = onSetLegacyState,
            )
        }
    }
}

@Composable
private fun LegacyNotificationPreferenceSwitchRow(
    state: LegacyNotificationPreferenceStatePresentation,
    isUpdating: Boolean,
    onSetLegacyState: (String, String, String, Boolean) -> Unit,
) {
    PreferenceSwitchRow(
        title = state.title,
        subtitle = state.subtitle,
        checked = state.checked,
        enabled = !isUpdating && !state.locked,
        onCheckedChange = { isEnabled ->
            onSetLegacyState(
                state.preferenceKey,
                state.processorName,
                state.stateName,
                isEnabled,
            )
        },
    )
}

@Composable
internal fun CalendarPreferencesPanel(
    appState: AppUiState,
    onLoadCalendarPreferences: () -> Unit,
    onSetCalendarPreferenceValue: (String, String) -> Unit,
) {
    val form = appState.calendarPreferencesForm

    ElevatedCard(
        colors = CardDefaults.elevatedCardColors(containerColor = MaterialTheme.colorScheme.surface),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                SettingsIconBadge(Icons.Outlined.CalendarMonth, MaterialTheme.colorScheme.tertiary)
                Spacer(Modifier.width(12.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = "LMS カレンダー設定",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Text(
                        text = appState.calendarPreferencesStatusLabel,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                IconButton(
                    onClick = onLoadCalendarPreferences,
                    enabled = appState.session.hasLmsSession && !appState.isLoadingCalendarPreferences,
                ) {
                    Icon(Icons.Outlined.Refresh, contentDescription = "カレンダー設定を再読み込み")
                }
            }

            appState.calendarPreferencesMessage?.let { message ->
                Spacer(Modifier.height(10.dp))
                Text(
                    text = message,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.primary,
                )
            }

            Spacer(Modifier.height(12.dp))

            if (appState.isLoadingCalendarPreferences) {
                Text(
                    text = "カレンダー設定を読み込み中",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                return@Column
            }

            if (!appState.session.hasLmsSession) {
                Text(
                    text = "Moodle に接続するとカレンダー表示設定を変更できます。",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                return@Column
            }

            CalendarPreferenceChipGroup(
                title = "時刻表示",
                selectedValue = form.timeFormat,
                options = calendarTimeFormatOptions,
                enabled = !appState.isUpdatingCalendarPreferences,
                onSelect = { value -> onSetCalendarPreferenceValue("calendar_timeformat", value) },
            )
            CalendarPreferenceChipGroup(
                title = "週の始まり",
                selectedValue = form.startWeekday,
                options = calendarWeekdayOptions,
                enabled = !appState.isUpdatingCalendarPreferences,
                onSelect = { value -> onSetCalendarPreferenceValue("calendar_startwday", value) },
            )
            CalendarPreferenceChipGroup(
                title = "表示件数",
                selectedValue = form.maxEvents,
                options = calendarMaxEventOptions,
                enabled = !appState.isUpdatingCalendarPreferences,
                onSelect = { value -> onSetCalendarPreferenceValue("calendar_maxevents", value) },
            )
            CalendarPreferenceChipGroup(
                title = "先読み期間",
                selectedValue = form.lookAhead,
                options = calendarLookAheadOptions,
                enabled = !appState.isUpdatingCalendarPreferences,
                onSelect = { value -> onSetCalendarPreferenceValue("calendar_lookahead", value) },
            )
            PreferenceSwitchRow(
                title = "フィルターを保持",
                subtitle = "LMS カレンダーの表示フィルターを保存します。",
                checked = form.persistFilters,
                enabled = !appState.isUpdatingCalendarPreferences,
                onCheckedChange = { isEnabled ->
                    onSetCalendarPreferenceValue("calendar_persistflt", if (isEnabled) "1" else "0")
                },
            )
        }
    }
}

@Composable
private fun CalendarPreferenceChipGroup(
    title: String,
    selectedValue: String,
    options: List<PreferenceOption>,
    enabled: Boolean,
    onSelect: (String) -> Unit,
) {
    Spacer(Modifier.height(12.dp))
    Text(
        text = title,
        style = MaterialTheme.typography.titleSmall,
        color = MaterialTheme.colorScheme.primary,
        fontWeight = FontWeight.SemiBold,
    )
    Spacer(Modifier.height(8.dp))
    FlowRow(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        options.forEach { option ->
            FilterChip(
                selected = option.value == selectedValue,
                onClick = { onSelect(option.value) },
                label = { Text(option.label) },
                enabled = enabled,
            )
        }
    }
}

private val calendarTimeFormatOptions = listOf(
    PreferenceOption("0", "既定"),
    PreferenceOption("%I:%M %p", "12時間"),
    PreferenceOption("%H:%M", "24時間"),
)

private val calendarMaxEventOptions = (1..20).map { value ->
    PreferenceOption(value.toString(), value.toString())
}

private val calendarLookAheadOptions = listOf(
    PreferenceOption("365", "1年"),
    PreferenceOption("270", "9か月"),
    PreferenceOption("180", "6か月"),
    PreferenceOption("150", "5か月"),
    PreferenceOption("120", "4か月"),
    PreferenceOption("90", "3か月"),
    PreferenceOption("60", "2か月"),
    PreferenceOption("30", "1か月"),
    PreferenceOption("21", "3週間"),
    PreferenceOption("14", "2週間"),
    PreferenceOption("7", "1週間"),
    PreferenceOption("6", "6日"),
    PreferenceOption("5", "5日"),
    PreferenceOption("4", "4日"),
    PreferenceOption("3", "3日"),
    PreferenceOption("2", "2日"),
    PreferenceOption("1", "1日"),
)

@Composable
private fun PreferenceSwitchRow(
    title: String,
    subtitle: String? = null,
    checked: Boolean,
    enabled: Boolean,
    onCheckedChange: (Boolean) -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                style = MaterialTheme.typography.bodyLarge,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            subtitle?.let {
                Text(
                    text = it,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            enabled = enabled,
        )
    }
}

@Composable
private fun SettingsIconBadge(
    icon: ImageVector,
    color: Color,
) {
    Surface(
        modifier = Modifier
            .size(42.dp)
            .clip(CircleShape),
        shape = CircleShape,
        color = color.copy(alpha = 0.14f),
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = color,
            modifier = Modifier
                .padding(9.dp)
                .background(Color.Transparent),
        )
    }
}
