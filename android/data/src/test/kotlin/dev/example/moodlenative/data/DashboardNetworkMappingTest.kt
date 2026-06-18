package dev.example.moodlenative.data

import dev.example.moodlenative.networking.Course as NetworkCourse
import dev.example.moodlenative.networking.CourseModule as NetworkCourseModule
import dev.example.moodlenative.networking.DashboardBlock as NetworkDashboardBlock
import dev.example.moodlenative.networking.DashboardSnapshot as NetworkDashboardSnapshot
import dev.example.moodlenative.networking.ModuleCompletionData as NetworkModuleCompletionData
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DashboardNetworkMappingTest {
    @Test
    fun dashboardSnapshotMapsCoursesAndBlocksToFeatureModels() {
        val snapshot = NetworkDashboardSnapshot(
            siteURL = "https://lms.example.test",
            userID = 99,
            courses = listOf(
                NetworkCourse(
                    id = 42,
                    fullName = "53334:ソフトウェア工学(K1)",
                    displayName = "ソフトウェア工学",
                    shortName = "2026-53334",
                    summary = "<p>summary</p>",
                    courseImage = "https://lms.example.test/image.png",
                    progress = 75.0,
                    isFavorite = true,
                ),
            ),
            dashboardBlocks = listOf(
                NetworkDashboardBlock(
                    instanceID = 10,
                    name = "rutime_table",
                    region = "content",
                    positionID = 3,
                    visible = true,
                    contents = NetworkDashboardBlock.Contents(
                        title = "時間割",
                        content = "<div class=\"subject\">...</div>",
                        contentFormat = 1,
                        footer = "footer",
                    ),
                ),
            ),
        ).toLmsDashboardSnapshot()

        assertEquals("https://lms.example.test", snapshot.siteURL)
        assertEquals(99, snapshot.userID)

        val course = snapshot.courses.single()
        assertEquals(42, course.id)
        assertEquals("53334:ソフトウェア工学(K1)", course.fullName)
        assertEquals("ソフトウェア工学", course.displayName)
        assertEquals("2026-53334", course.shortName)
        assertEquals("<p>summary</p>", course.summary)
        assertEquals("https://lms.example.test/image.png", course.courseImage)
        assertEquals(75.0, course.progress)
        assertEquals(true, course.isFavorite)

        val block = snapshot.dashboardBlocks.single()
        assertEquals(10, block.instanceID)
        assertEquals("rutime_table", block.name)
        assertEquals("content", block.region)
        assertEquals(3, block.positionID)
        assertEquals(true, block.visible)
        assertEquals("時間割", block.contents?.title)
        assertEquals("<div class=\"subject\">...</div>", block.contents?.content)
        assertEquals(1, block.contents?.contentFormat)
        assertEquals("footer", block.contents?.footer)
    }

    @Test
    fun courseModuleMapsCompletionRequirementsToFeatureModels() {
        val module = NetworkCourseModule(
            id = 201,
            instanceID = 301,
            modName = "assign",
            name = "第1回課題",
            url = "https://lms.example.test/mod/assign/view.php?id=201",
            completionData = NetworkModuleCompletionData(
                hasCompletion = true,
                userVisible = true,
                details = listOf(
                    NetworkModuleCompletionData.Detail(
                        ruleName = "completionsubmit",
                        ruleValue = NetworkModuleCompletionData.Detail.RuleValue(
                            status = 0,
                            description = "提出する",
                        ),
                    ),
                    NetworkModuleCompletionData.Detail(
                        ruleName = "completionview",
                        ruleValue = NetworkModuleCompletionData.Detail.RuleValue(
                            status = 1,
                            description = "閲覧する",
                        ),
                    ),
                ),
            ),
        ).toLmsCourseModule()

        assertEquals(201, module.id)
        assertEquals(301, module.instanceID)
        assertEquals("assign", module.modName)
        assertEquals("第1回課題", module.name)
        assertEquals("https://lms.example.test/mod/assign/view.php?id=201", module.url)

        assertEquals(listOf("completionsubmit", "completionview"), module.completionRequirements.map { it.id })
        assertEquals(listOf("提出する", "閲覧する"), module.completionRequirements.map { it.text })
        assertFalse(module.completionRequirements[0].isComplete)
        assertTrue(module.completionRequirements[1].isComplete)
    }
}
