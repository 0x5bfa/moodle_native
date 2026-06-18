package dev.example.moodlenative.core

import java.net.URI

data class LmsResourceTreeFile(
    val id: String,
    val title: String,
    val url: URI,
    val pathComponents: List<String>,
)

data class LmsResourceTreeNode(
    val id: String,
    val title: String,
    val url: URI?,
    val children: List<LmsResourceTreeNode>,
) {
    val isFolder: Boolean
        get() = url == null
}

fun List<LmsResourceTreeFile>.treeNodes(): List<LmsResourceTreeNode> {
    val nodes = mutableListOf<LmsResourceTreeNode>()
    for (file in this) {
        insertResourceTreeFile(
            file = file,
            nodes = nodes,
            pathComponents = file.pathComponents,
            parentComponents = emptyList(),
        )
    }
    return nodes
}

private fun insertResourceTreeFile(
    file: LmsResourceTreeFile,
    nodes: MutableList<LmsResourceTreeNode>,
    pathComponents: List<String>,
    parentComponents: List<String>,
) {
    val head = pathComponents.firstOrNull()
    if (head == null) {
        nodes.add(
            LmsResourceTreeNode(
                id = "file:${file.id}",
                title = file.title,
                url = file.url,
                children = emptyList(),
            )
        )
        return
    }

    val nextParentComponents = parentComponents + head
    val folderID = "folder:${nextParentComponents.joinToString(separator = "/")}"
    val existingIndex = nodes.indexOfFirst { it.id == folderID }

    if (existingIndex >= 0) {
        val existing = nodes[existingIndex]
        val children = existing.children.toMutableList()
        insertResourceTreeFile(file, children, pathComponents.drop(1), nextParentComponents)
        nodes[existingIndex] = existing.copy(children = children)
        return
    }

    val children = mutableListOf<LmsResourceTreeNode>()
    insertResourceTreeFile(file, children, pathComponents.drop(1), nextParentComponents)
    nodes.add(
        LmsResourceTreeNode(
            id = folderID,
            title = head,
            url = null,
            children = children,
        )
    )
}
