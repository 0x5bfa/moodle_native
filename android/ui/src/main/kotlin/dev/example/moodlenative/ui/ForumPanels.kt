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
import androidx.compose.material.icons.outlined.Done
import androidx.compose.material.icons.outlined.Forum
import androidx.compose.material3.AssistChip
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import dev.example.moodlenative.features.LmsForumDiscussionPresentation
import dev.example.moodlenative.features.LmsForumPostThreadPresentationNode
import dev.example.moodlenative.presentation.AppUiState

@Composable
internal fun ForumScreen(
    appState: AppUiState,
    onForumIDChange: (String) -> Unit,
    onLoadForum: () -> Unit,
    onSelectDiscussion: (Int) -> Unit,
    onMarkDiscussionViewed: (Int) -> Unit,
) {
    val selectedDiscussion = appState.forumSelectedDiscussion
    val threadNodes = appState.forumPostThreads

    ScreenList {
        item {
            SummaryBand(
                title = "フォーラム",
                primary = appState.forumPrimaryLabel,
                secondary = appState.forumStatusLabel,
            )
        }
        item {
            ForumLoadControls(
                forumIDText = appState.forumIDText,
                isLoading = appState.isLoadingForum,
                onForumIDChange = onForumIDChange,
                onLoadForum = onLoadForum,
            )
        }
        appState.forumActionMessage?.let { message ->
            item {
                InfoRow(
                    title = "フォーラム操作",
                    subtitle = message,
                    leadingIcon = Icons.Outlined.Forum,
                    accent = MaterialTheme.colorScheme.primary,
                )
            }
        }
        appState.forumError?.let { message ->
            item {
                InfoRow(
                    title = "取得エラー",
                    subtitle = message,
                    leadingIcon = Icons.Outlined.Forum,
                    accent = MaterialTheme.colorScheme.primary,
                )
            }
        }
        appState.forumPartialErrors.forEachIndexed { index, message ->
            item {
                InfoRow(
                    title = "一部取得失敗 ${index + 1}",
                    subtitle = message,
                    leadingIcon = Icons.Outlined.Forum,
                    accent = MaterialTheme.colorScheme.primary,
                )
            }
        }
        selectedDiscussion?.let { discussion ->
            item {
                SectionLabel("選択中")
            }
            item {
                ForumDiscussionDetailCard(discussion)
            }
            item {
                ForumDiscussionActionControls(
                    discussionID = discussion.id,
                    isLoadingForum = appState.isLoadingForum,
                    isUpdatingForumAction = appState.isUpdatingForumAction,
                    onMarkDiscussionViewed = onMarkDiscussionViewed,
                )
            }
            item {
                SectionLabel("投稿")
            }
            if (threadNodes.isEmpty()) {
                item {
                    InfoRow(
                        title = "投稿",
                        subtitle = if (appState.isLoadingForum) "取得中" else "投稿はありません",
                        leadingIcon = Icons.Outlined.Forum,
                    )
                }
            } else {
                item {
                    ForumThreadCard(threadNodes)
                }
            }
        }
        item {
            SectionLabel("ディスカッション")
        }
        if (appState.forumDiscussions.isEmpty()) {
            item {
                InfoRow(
                    title = "ディスカッション",
                    subtitle = if (appState.isLoadingForum) "取得中" else "未読み込み",
                    leadingIcon = Icons.Outlined.Forum,
                )
            }
        } else {
            items(appState.forumDiscussions, key = { it.id }) { discussion ->
                ForumDiscussionRow(
                    discussion = discussion,
                    isSelected = discussion.id == selectedDiscussion?.id,
                    onClick = { onSelectDiscussion(discussion.id) },
                )
            }
        }
    }
}

@Composable
private fun ForumDiscussionActionControls(
    discussionID: Int,
    isLoadingForum: Boolean,
    isUpdatingForumAction: Boolean,
    onMarkDiscussionViewed: (Int) -> Unit,
) {
    FlowRow(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        FilledTonalButton(
            onClick = { onMarkDiscussionViewed(discussionID) },
            enabled = !isLoadingForum && !isUpdatingForumAction,
        ) {
            Icon(Icons.Outlined.Done, contentDescription = null, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(8.dp))
            Text(if (isUpdatingForumAction) "更新中" else "閲覧済みにする")
        }
    }
}

@Composable
private fun ForumLoadControls(
    forumIDText: String,
    isLoading: Boolean,
    onForumIDChange: (String) -> Unit,
    onLoadForum: () -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        TextField(
            value = forumIDText,
            onValueChange = onForumIDChange,
            modifier = Modifier.fillMaxWidth(),
            label = { Text("Forum ID") },
            singleLine = true,
        )
        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            FilledTonalButton(
                onClick = onLoadForum,
                enabled = !isLoading,
            ) {
                Icon(Icons.Outlined.Forum, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(8.dp))
                Text(if (isLoading) "取得中" else "読み込み")
            }
        }
    }
}

@Composable
private fun ForumDiscussionRow(
    discussion: LmsForumDiscussionPresentation,
    isSelected: Boolean,
    onClick: () -> Unit,
) {
    val accent = if (isSelected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.secondary
    val subtitle = listOfNotNull(
        discussion.authorName,
        discussion.modifiedAt?.toString(),
        "${discussion.replyCount} 返信",
        discussion.unreadCount.takeIf { it > 0 }?.let { "未読 $it" },
    ).joinToString(" / ")

    InfoRow(
        title = discussion.title,
        subtitle = subtitle,
        leadingIcon = Icons.Outlined.Forum,
        accent = accent,
        modifier = Modifier.clickable(onClick = onClick),
    )
}

@Composable
private fun ForumDiscussionDetailCard(discussion: LmsForumDiscussionPresentation) {
    ElevatedCard(
        colors = CardDefaults.elevatedCardColors(containerColor = MaterialTheme.colorScheme.surface),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                IconBadge(Icons.Outlined.Forum, MaterialTheme.colorScheme.primary)
                Spacer(Modifier.width(12.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = discussion.title,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                    )
                    Text(
                        text = discussion.authorName,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            discussion.previewText?.let { preview ->
                Spacer(Modifier.height(12.dp))
                Text(
                    text = preview,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface,
                    maxLines = 4,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Spacer(Modifier.height(12.dp))
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                AssistChip(onClick = {}, label = { Text("${discussion.replyCount} 返信") })
                if (discussion.unreadCount > 0) {
                    AssistChip(onClick = {}, label = { Text("未読 ${discussion.unreadCount}") })
                }
                discussion.modifiedAt?.let { modifiedAt ->
                    AssistChip(onClick = {}, label = { Text(modifiedAt.toString()) })
                }
            }
        }
    }
}

@Composable
private fun ForumThreadCard(nodes: List<LmsForumPostThreadPresentationNode>) {
    ElevatedCard(
        colors = CardDefaults.elevatedCardColors(containerColor = MaterialTheme.colorScheme.surface),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            nodes.forEachIndexed { index, node ->
                if (index > 0) {
                    Spacer(Modifier.height(14.dp))
                }
                ForumPostThreadNodeRow(node)
            }
        }
    }
}

@Composable
private fun ForumPostThreadNodeRow(
    node: LmsForumPostThreadPresentationNode,
    depth: Int = 0,
) {
    val post = node.post
    val startPadding = (depth * 12).coerceAtMost(36).dp

    Column(modifier = Modifier.padding(start = startPadding)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            IconBadge(
                icon = Icons.Outlined.Forum,
                color = if (post.isUnread) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.secondary,
            )
            Spacer(Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = post.subject ?: "投稿",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    text = listOfNotNull(post.authorName, post.modifiedAt?.toString()).joinToString(" / "),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
        post.bodyText?.takeIf { it.isNotBlank() }?.let { body ->
            Spacer(Modifier.height(8.dp))
            Text(
                text = body,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 5,
                overflow = TextOverflow.Ellipsis,
            )
        }
        if (post.attachmentCount > 0) {
            Spacer(Modifier.height(8.dp))
            Text(
                text = "添付 ${post.attachmentCount} 件",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.primary,
                fontWeight = FontWeight.SemiBold,
            )
        }
        node.children.forEach { child ->
            Spacer(Modifier.height(12.dp))
            ForumPostThreadNodeRow(
                node = child,
                depth = depth + 1,
            )
        }
    }
}
