import Foundation
import Testing

@testable import MoodleNativeCore

struct LmsResourceTreeSupportTests {
    @Test func buildTreeNodesFromNestedPaths() throws {
        let files = [
            LmsResourceTreeFile(
                id: "1",
                title: "guide.pdf",
                url: try #require(URL(string: "https://example.test/guide.pdf")),
                pathComponents: ["Week1"]
            ),
            LmsResourceTreeFile(
                id: "2",
                title: "slides.pdf",
                url: try #require(URL(string: "https://example.test/slides.pdf")),
                pathComponents: ["Week1", "Slides"]
            ),
        ]

        let nodes = files.treeNodes()

        #expect(nodes.count == 1)
        #expect(nodes[0].title == "Week1")
        #expect(nodes[0].children.count == 2)
        #expect(nodes[0].children.contains(where: { $0.title == "guide.pdf" }))
        #expect(nodes[0].children.contains(where: { $0.title == "Slides" }))
    }
}
