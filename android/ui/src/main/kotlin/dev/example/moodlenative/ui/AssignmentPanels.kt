package dev.example.moodlenative.ui

import android.content.Context
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
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
import androidx.compose.material.icons.automirrored.outlined.Assignment
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Done
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import dev.example.moodlenative.core.LmsAssignmentItem
import dev.example.moodlenative.core.LmsHTMLTextFormatter
import dev.example.moodlenative.features.AssignmentDetailRowPresentation
import dev.example.moodlenative.features.AssignmentSubmissionActionsPresentation
import dev.example.moodlenative.features.AssignmentSubmissionEditorPresentation
import dev.example.moodlenative.presentation.AppUiState
import dev.example.moodlenative.presentation.AssignmentSubmissionFileSelection
import dev.example.moodlenative.presentation.toAssignmentSubmissionFileSelection
import java.time.Instant

@Composable
internal fun AssignmentsScreen(
    appState: AppUiState,
    onOpenAssignment: (LmsAssignmentItem) -> Unit,
    onSaveAssignmentSubmission: (LmsAssignmentItem, List<AssignmentSubmissionFileSelection>?, String?) -> Unit,
    onStartAssignmentSubmission: (LmsAssignmentItem) -> Unit,
    onSubmitAssignmentForGrading: (LmsAssignmentItem) -> Unit,
    onRemoveAssignmentSubmission: (LmsAssignmentItem, Int?) -> Unit,
) {
    val context = LocalContext.current
    val selectedAssignment = appState.selectedAssignment
    val assignmentDetail = appState.assignmentDetailPresentation
    val editor = assignmentDetail?.editor
    val initialOnlineText = editor?.initialOnlineText.orEmpty()
    val initialFiles = editor?.initialFiles
        ?.map { file -> file.toAssignmentSubmissionFileSelection() }
        .orEmpty()
    var onlineText by remember(selectedAssignment?.id, editor?.submissionID, assignmentDetail?.loadedAt, initialOnlineText) {
        mutableStateOf(initialOnlineText)
    }
    var selectedFiles by remember(selectedAssignment?.id, editor?.submissionID, assignmentDetail?.loadedAt) {
        mutableStateOf(initialFiles)
    }
    var fileSelectionMessage by remember(selectedAssignment?.id, editor?.submissionID, assignmentDetail?.loadedAt) {
        mutableStateOf<String?>(null)
    }
    val filePicker = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenMultipleDocuments(),
    ) { uris ->
        val files = uris.mapNotNull { uri ->
            runCatching { context.readAssignmentSubmissionFile(uri) }
                .onFailure { error -> fileSelectionMessage = error.message ?: "ファイルを読み取れませんでした。" }
                .getOrNull()
        }
        if (files.isNotEmpty()) {
            selectedFiles = selectedFiles + files
            fileSelectionMessage = "${files.size} 件のファイルを選択しました。"
        }
    }

    ScreenList {
        item {
            SectionLabel("これからの課題")
        }
        selectedAssignment?.let { assignment ->
            appState.assignmentActionMessage?.let { message ->
                item {
                    InfoRow(
                        title = "提出操作",
                        subtitle = message,
                        leadingIcon = Icons.AutoMirrored.Outlined.Assignment,
                        accent = MaterialTheme.colorScheme.primary,
                    )
                }
            }
            item {
                AssignmentDetailCard(
                    assignment = assignment,
                    detailRows = appState.assignmentDetailStatusRows,
                    isLoading = appState.isLoadingAssignmentDetail,
                    now = appState.now,
                )
            }
            item {
                AssignmentSubmissionEditor(
                    assignment = assignment,
                    editor = editor,
                    onlineText = onlineText,
                    selectedFiles = selectedFiles,
                    fileSelectionMessage = fileSelectionMessage,
                    isLoadingDetail = appState.isLoadingAssignmentDetail,
                    isUpdatingAction = appState.isUpdatingAssignmentAction,
                    onOnlineTextChange = { onlineText = it },
                    onPickFiles = { filePicker.launch(arrayOf("*/*")) },
                    onRemoveSelectedFile = { index ->
                        selectedFiles = selectedFiles.filterIndexed { fileIndex, _ -> fileIndex != index }
                    },
                    onSave = { files, onlineTextHTML ->
                        onSaveAssignmentSubmission(assignment, files, onlineTextHTML)
                    },
                )
            }
            item {
                AssignmentActionControls(
                    assignment = assignment,
                    actions = assignmentDetail?.actions,
                    isLoadingDetail = appState.isLoadingAssignmentDetail,
                    isUpdatingAction = appState.isUpdatingAssignmentAction,
                    onStartSubmission = onStartAssignmentSubmission,
                    onSubmitForGrading = onSubmitAssignmentForGrading,
                    onRemoveSubmission = onRemoveAssignmentSubmission,
                )
            }
        }
        items(appState.assignments, key = { it.id }) { assignment ->
            AssignmentRow(
                assignment = assignment,
                now = appState.now,
                onClick = { onOpenAssignment(assignment) },
            )
        }
    }
}

@Composable
internal fun AssignmentDetailCard(
    assignment: LmsAssignmentItem,
    detailRows: List<AssignmentDetailRowPresentation>,
    isLoading: Boolean,
    now: Instant,
) {
    ElevatedCard(
        colors = CardDefaults.elevatedCardColors(containerColor = MaterialTheme.colorScheme.surface),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                IconBadge(Icons.AutoMirrored.Outlined.Assignment, MaterialTheme.colorScheme.primary)
                Spacer(Modifier.width(12.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = assignment.title,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                    )
                    Text(
                        text = assignment.courseTitle,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            Spacer(Modifier.height(12.dp))
            AssignmentDetailRow("期限", assignment.dueBucket(now).sectionTitle)
            assignment.dueDate?.let { AssignmentDetailRow("提出期限", it.toString()) }
            assignment.cutoffDate?.let { AssignmentDetailRow("遮断日時", it.toString()) }
            LmsHTMLTextFormatter.plainText(assignment.introPreview)?.let { intro ->
                AssignmentDetailRow("説明", intro)
            }
            AssignmentDetailStatusRows(
                detailRows = detailRows,
                isLoading = isLoading,
            )
        }
    }
}

@Composable
internal fun AssignmentSubmissionEditor(
    assignment: LmsAssignmentItem,
    editor: AssignmentSubmissionEditorPresentation?,
    onlineText: String,
    selectedFiles: List<AssignmentSubmissionFileSelection>,
    fileSelectionMessage: String?,
    isLoadingDetail: Boolean,
    isUpdatingAction: Boolean,
    onOnlineTextChange: (String) -> Unit,
    onPickFiles: () -> Unit,
    onRemoveSelectedFile: (Int) -> Unit,
    onSave: (List<AssignmentSubmissionFileSelection>?, String?) -> Unit,
) {
    editor ?: return

    val hasOnlineTextChanges = editor.allowsOnlineText && onlineText != editor.initialOnlineText
    val initialFiles = editor.initialFiles.map { file -> file.toAssignmentSubmissionFileSelection() }
    val hasFileChanges = editor.allowsFile && selectedFiles != initialFiles
    val wordLimit = editor.wordLimit
    val wordCount = onlineText.wordCount()
    val exceedsWordLimit = wordLimit != null && wordCount > wordLimit
    val canSave = (hasOnlineTextChanges || hasFileChanges) &&
        !exceedsWordLimit &&
        !isLoadingDetail &&
        !isUpdatingAction

    ElevatedCard(
        colors = CardDefaults.elevatedCardColors(containerColor = MaterialTheme.colorScheme.surface),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                IconBadge(Icons.AutoMirrored.Outlined.Assignment, MaterialTheme.colorScheme.secondary)
                Spacer(Modifier.width(12.dp))
                Text(
                    text = "提出編集",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                )
            }
            if (editor.allowsOnlineText) {
                TextField(
                    value = onlineText,
                    onValueChange = onOnlineTextChange,
                    modifier = Modifier.fillMaxWidth(),
                    label = { Text("オンラインテキスト") },
                    minLines = 4,
                    maxLines = 8,
                    enabled = !isLoadingDetail && !isUpdatingAction,
                )
                if (wordLimit != null) {
                    Text(
                        text = "$wordCount / $wordLimit 語",
                        style = MaterialTheme.typography.bodySmall,
                        color = if (exceedsWordLimit) {
                            MaterialTheme.colorScheme.primary
                        } else {
                            MaterialTheme.colorScheme.onSurfaceVariant
                        },
                    )
                }
            }
            if (editor.allowsFile) {
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    OutlinedButton(
                        onClick = onPickFiles,
                        enabled = !isLoadingDetail && !isUpdatingAction,
                    ) {
                        Icon(Icons.AutoMirrored.Outlined.Assignment, contentDescription = null, modifier = Modifier.size(18.dp))
                        Spacer(Modifier.width(8.dp))
                        Text("ファイルを選択")
                    }
                }
                if (selectedFiles.isEmpty()) {
                    Text(
                        text = "提出ファイルはありません。",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                selectedFiles.forEachIndexed { index, file ->
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = file.fileName,
                                style = MaterialTheme.typography.bodyMedium,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                            Text(
                                text = file.fileMetadataLabel,
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        IconButton(
                            onClick = { onRemoveSelectedFile(index) },
                            enabled = !isLoadingDetail && !isUpdatingAction,
                        ) {
                            Icon(Icons.Outlined.Delete, contentDescription = "削除")
                        }
                    }
                }
                fileSelectionMessage?.let { message ->
                    Text(
                        text = message,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            FilledTonalButton(
                onClick = {
                    onSave(
                        selectedFiles.takeIf { hasFileChanges },
                        onlineText.toMoodleHTML().takeIf { hasOnlineTextChanges },
                    )
                },
                enabled = canSave,
            ) {
                Icon(Icons.Outlined.Done, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(8.dp))
                Text(if (isUpdatingAction) "保存中" else "提出を保存")
            }
        }
    }
}

@Composable
internal fun AssignmentActionControls(
    assignment: LmsAssignmentItem,
    actions: AssignmentSubmissionActionsPresentation?,
    isLoadingDetail: Boolean,
    isUpdatingAction: Boolean,
    onStartSubmission: (LmsAssignmentItem) -> Unit,
    onSubmitForGrading: (LmsAssignmentItem) -> Unit,
    onRemoveSubmission: (LmsAssignmentItem, Int?) -> Unit,
) {
    actions ?: return

    if (!actions.canStart && !actions.canSubmit && !actions.canRemove) {
        return
    }

    FlowRow(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        if (actions.canStart) {
            OutlinedButton(
                onClick = { onStartSubmission(assignment) },
                enabled = !isLoadingDetail && !isUpdatingAction,
            ) {
                Icon(Icons.Outlined.Schedule, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(8.dp))
                Text(if (isUpdatingAction) "更新中" else "提出開始")
            }
        }
        if (actions.canSubmit) {
            FilledTonalButton(
                onClick = { onSubmitForGrading(assignment) },
                enabled = !isLoadingDetail && !isUpdatingAction,
            ) {
                Icon(Icons.Outlined.Done, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(8.dp))
                Text(if (isUpdatingAction) "更新中" else "提出を確定")
            }
        }
        if (actions.canRemove) {
            OutlinedButton(
                onClick = { onRemoveSubmission(assignment, actions.removeUserID) },
                enabled = !isLoadingDetail && !isUpdatingAction,
            ) {
                Icon(Icons.Outlined.Delete, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(8.dp))
                Text(if (isUpdatingAction) "更新中" else "提出を削除")
            }
        }
    }
}

@Composable
private fun AssignmentRow(
    assignment: LmsAssignmentItem,
    now: Instant,
    onClick: () -> Unit = {},
) {
    InfoRow(
        title = assignment.title,
        subtitle = "${assignment.courseTitle} / ${assignment.dueBucket(now).sectionTitle}",
        leadingIcon = Icons.AutoMirrored.Outlined.Assignment,
        accent = MaterialTheme.colorScheme.primary,
        modifier = Modifier.clickable(onClick = onClick),
    )
}

@Composable
private fun AssignmentDetailStatusRows(
    detailRows: List<AssignmentDetailRowPresentation>,
    isLoading: Boolean,
) {
    if (isLoading) {
        AssignmentDetailRow("詳細", "読み込み中")
    } else {
        detailRows.forEach { row ->
            AssignmentDetailRow(row.label, row.value)
        }
    }
}

private val AssignmentSubmissionFileSelection.fileMetadataLabel: String
    get() = data?.let { bytes -> "$mimeType / ${bytes.size} bytes" } ?: "$mimeType / 既存ファイル"

private fun String.wordCount(): Int =
    trim()
        .split(Regex("\\s+"))
        .count { it.isNotEmpty() }

private fun String.toMoodleHTML(): String {
    val escaped = replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace("\"", "&quot;")
    return escaped
        .split("\n\n")
        .joinToString(separator = "") { paragraph ->
            "<p>${paragraph.replace("\n", "<br>")}</p>"
        }
}

internal fun Context.readAssignmentSubmissionFile(uri: android.net.Uri): AssignmentSubmissionFileSelection {
    val fileName = queryDisplayName(uri)
        ?: uri.lastPathSegment?.substringAfterLast('/')
        ?: "submission-file"
    val mimeType = contentResolver.getType(uri) ?: "application/octet-stream"
    val data = contentResolver.openInputStream(uri)?.use { stream ->
        stream.readBytes()
    } ?: throw IllegalStateException("ファイルを読み取れませんでした。")

    return AssignmentSubmissionFileSelection(
        fileName = fileName.trim().ifEmpty { "submission-file" },
        mimeType = mimeType,
        data = data,
    )
}

private fun Context.queryDisplayName(uri: android.net.Uri): String? =
    contentResolver.query(
        uri,
        arrayOf(android.provider.OpenableColumns.DISPLAY_NAME),
        null,
        null,
        null,
    )?.use { cursor ->
        val index = cursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
        if (index >= 0 && cursor.moveToFirst()) {
            cursor.getString(index)?.takeIf { it.isNotBlank() }
        } else {
            null
        }
    }

@Composable
internal fun AssignmentDetailRow(
    label: String,
    value: String,
) {
    Spacer(Modifier.height(8.dp))
    Text(
        text = label,
        style = MaterialTheme.typography.labelMedium,
        color = MaterialTheme.colorScheme.primary,
        fontWeight = FontWeight.SemiBold,
    )
    Text(
        text = value,
        style = MaterialTheme.typography.bodyMedium,
        color = MaterialTheme.colorScheme.onSurface,
    )
}
