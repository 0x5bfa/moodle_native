import Foundation

extension Array where Element == LmsResourceTreeFile {
    public func treeNodes() -> [LmsResourceTreeNode] {
        var nodes: [LmsResourceTreeNode] = []

        for file in self {
            Self.insert(
                file,
                into: &nodes,
                pathComponents: file.pathComponents,
                parentComponents: []
            )
        }

        return nodes
    }

    private static func insert(
        _ file: LmsResourceTreeFile,
        into nodes: inout [LmsResourceTreeNode],
        pathComponents: [String],
        parentComponents: [String]
    ) {
        guard let head = pathComponents.first else {
            nodes.append(
                LmsResourceTreeNode(
                    id: "file:\(file.id)",
                    title: file.title,
                    url: file.url,
                    children: []
                )
            )
            return
        }

        let nextParentComponents = parentComponents + [head]
        let folderID = "folder:\(nextParentComponents.joined(separator: "/"))"

        if let index = nodes.firstIndex(where: { $0.id == folderID }) {
            insert(
                file,
                into: &nodes[index].children,
                pathComponents: [String](pathComponents.dropFirst()),
                parentComponents: nextParentComponents
            )
            return
        }

        var children: [LmsResourceTreeNode] = []
        insert(
            file,
            into: &children,
            pathComponents: [String](pathComponents.dropFirst()),
            parentComponents: nextParentComponents
        )

        nodes.append(
            LmsResourceTreeNode(
                id: folderID,
                title: head,
                url: nil,
                children: children
            )
        )
    }
}
