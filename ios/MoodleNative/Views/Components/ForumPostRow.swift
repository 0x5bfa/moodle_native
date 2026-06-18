import SwiftUI
import MoodleNativeNetworking
import MoodleNativeFeatures

struct ForumPostRow: View {
    let node: LmsForumPostThreadNode
    let depth: Int
    let onOpenResource: (URL) -> Void
    @State private var messageHeight: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                avatarView

                VStack(alignment: .leading) {
                    HStack(alignment: .top, spacing: 12) {
                        Text(node.post.authorName)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(1)

                        if let relativeModifiedAtText {
                            Text(relativeModifiedAtText)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                                .lineLimit(1)
                        }
                    }

                    if let subject = node.post.displaySubject {
                        Text(subject)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                }
            }

            messageBody

            if node.post.attachments.isEmpty == false {
                attachmentsView
            }

            if node.children.isEmpty == false {
                VStack(alignment: .leading, spacing: 16) {
                    Divider()
                        .padding(.leading, CGFloat((depth + 1) * 20))

                    ForEach(Array(node.children.enumerated()), id: \.element.id) { index, child in
                        if index > 0 {
                            Divider()
                                .padding(.leading, CGFloat((depth + 1) * 20))
                        }

                        ForumPostRow(
                            node: child,
                            depth: depth + 1,
                            onOpenResource: onOpenResource
                        )
                    }
                }
            }
        }
        .padding(.leading, CGFloat(depth) * 20)
        .padding(.vertical, 4)
    }

    private var avatarView: some View {
        Group {
            if let profileImageURL = node.post.author.urls.profileImageURL {
                AsyncImage(url: profileImageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        placeholderAvatar
                    }
                }
            } else {
                placeholderAvatar
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        )
    }

    private var placeholderAvatar: some View {
        ZStack {
            Circle()
                .fill(Color.secondary.opacity(0.12))

            Image(systemName: "person.fill")
                .font(.system(size: 40 * 0.4, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var messageBody: some View {
        if let message = node.post.message,
            message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        {
            HtmlBodyView(
                htmlFragment: message,
                onOpenURL: onOpenResource,
                contentHeight: $messageHeight
            )
            .frame(height: messageHeight)
        } else {
            Text("forumPost.emptyBody")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var attachmentsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("forumPost.attachments.section")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            LmsResourceTreeView(
                nodes: node.post.attachments.resourceTreeNodes,
                onOpenResource: onOpenResource,
                baseLeadingPadding: 0
            )
        }
    }

    private var relativeModifiedAtText: String? {
        guard let modifiedAt = node.post.modifiedAt else {
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
}
