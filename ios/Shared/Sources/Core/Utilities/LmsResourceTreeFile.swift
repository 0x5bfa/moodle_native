import Foundation

public struct LmsResourceTreeFile: Equatable {
    public let id: String
    public let title: String
    public let url: URL
    public let pathComponents: [String]

    public init(id: String, title: String, url: URL, pathComponents: [String]) {
        self.id = id
        self.title = title
        self.url = url
        self.pathComponents = pathComponents
    }
}
