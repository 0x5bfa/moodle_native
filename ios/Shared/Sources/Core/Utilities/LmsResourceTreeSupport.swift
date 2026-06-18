import Foundation

public struct LmsResourceTreeNode: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let url: URL?
    public var children: [LmsResourceTreeNode]

    public init(id: String, title: String, url: URL?, children: [LmsResourceTreeNode]) {
        self.id = id
        self.title = title
        self.url = url
        self.children = children
    }

    public var isFolder: Bool {
        url == nil
    }
}
