package dev.example.moodlenative.core

import java.net.URI
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class LmsResourceTreeSupportTest {
    @Test
    fun buildTreeNodesFromNestedPaths() {
        val files = listOf(
            LmsResourceTreeFile(
                id = "1",
                title = "guide.pdf",
                url = URI.create("https://example.test/guide.pdf"),
                pathComponents = listOf("Week1"),
            ),
            LmsResourceTreeFile(
                id = "2",
                title = "slides.pdf",
                url = URI.create("https://example.test/slides.pdf"),
                pathComponents = listOf("Week1", "Slides"),
            ),
        )

        val nodes = files.treeNodes()

        assertEquals(1, nodes.size)
        assertEquals("Week1", nodes[0].title)
        assertEquals(2, nodes[0].children.size)
        assertTrue(nodes[0].children.any { it.title == "guide.pdf" })
        assertTrue(nodes[0].children.any { it.title == "Slides" })
    }
}
