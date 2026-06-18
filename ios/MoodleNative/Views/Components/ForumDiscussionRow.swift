import SwiftUI
import MoodleNativeNetworking
import MoodleNativeFeatures

struct ForumDiscussionRow: View {
    let discussion: LmsWebServiceClient.ForumDiscussion

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            leadingStatusColumn
                .frame(width: 12, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(discussion.displayTitle)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let relativeModifiedAtText {
                        Text(relativeModifiedAtText)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                if let previewText = discussion.previewText {
                    Text(previewText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "person")
                        Text(discussion.authorName)
                            .lineLimit(1)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left.and.bubble.right")
                        Text(Self.localizedReplyCount(discussion.replyCount))
                            .lineLimit(1)
                    }

                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var leadingStatusColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if discussion.unreadCount > 0 {
                    Capsule(style: .continuous)
                        .fill(Color.accentColor)
                        .frame(width: 8, height: 8)
                }

                if discussion.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 20, alignment: .center)

            if discussion.isLocked {
                Image(systemName: "lock.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, lockLeadingInset)
            }
        }
    }

    private var lockLeadingInset: CGFloat {
        discussion.unreadCount > 0 && discussion.isPinned ? 12 : 0
    }

    private var relativeModifiedAtText: String? {
        guard let modifiedAt = discussion.modifiedAt else {
            return nil
        }

        return Self.relativeDateFormatter.localizedString(
            for: modifiedAt,
            relativeTo: .now
        )
    }

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.unitsStyle = .full
        return formatter
    }()

    private static func localizedReplyCount(_ count: Int) -> String {
        String.localizedStringWithFormat(String(localized: "forumDiscussion.replies.count"), count)
    }
}
