import MoodleNativeCore
import SwiftUI

struct LmsResourceTreeView: View {
    let nodes: [LmsResourceTreeNode]
    let onOpenResource: (URL) -> Void
    let depth: Int
    let baseLeadingPadding: CGFloat

    init(
        nodes: [LmsResourceTreeNode],
        onOpenResource: @escaping (URL) -> Void,
        depth: Int = 0,
        baseLeadingPadding: CGFloat = 36
    ) {
        self.nodes = nodes
        self.onOpenResource = onOpenResource
        self.depth = depth
        self.baseLeadingPadding = baseLeadingPadding
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(nodes) { node in
                if node.isFolder {
                    LmsResourceFolderRow(
                        title: node.title,
                        depth: depth,
                        baseLeadingPadding: baseLeadingPadding
                    )

                    if node.children.isEmpty == false {
                        LmsResourceTreeView(
                            nodes: node.children,
                            onOpenResource: onOpenResource,
                            depth: depth + 1,
                            baseLeadingPadding: baseLeadingPadding
                        )
                    }
                } else if let url = node.url {
                    Button {
                        onOpenResource(url)
                    } label: {
                        LmsResourceFileRow(
                            title: node.title,
                            depth: depth,
                            baseLeadingPadding: baseLeadingPadding
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct LmsResourceFolderRow: View {
    let title: String
    let depth: Int
    let baseLeadingPadding: CGFloat

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "folder")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.secondary)
                .frame(width: 18, alignment: .center)

            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, leadingPadding)
    }

    private var leadingPadding: CGFloat {
        baseLeadingPadding + CGFloat(depth * 18)
    }
}

private struct LmsResourceFileRow: View {
    let title: String
    let depth: Int
    let baseLeadingPadding: CGFloat

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "doc")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.secondary)
                .frame(width: 18, alignment: .center)

            Text(title)
                .font(.footnote)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "arrow.up.forward.square")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.leading, leadingPadding)
        .contentShape(Rectangle())
    }

    private var leadingPadding: CGFloat {
        baseLeadingPadding + CGFloat(depth * 18)
    }
}
