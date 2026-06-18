package dev.example.moodlenative.data

import dev.example.moodlenative.features.LmsCourseModule
import dev.example.moodlenative.features.LmsDashboardBlock
import dev.example.moodlenative.features.LmsDashboardCourse
import dev.example.moodlenative.features.LmsDashboardSnapshot
import dev.example.moodlenative.features.LmsModuleCompletionRequirement
import dev.example.moodlenative.networking.Course as NetworkCourse
import dev.example.moodlenative.networking.CourseModule as NetworkCourseModule
import dev.example.moodlenative.networking.DashboardBlock as NetworkDashboardBlock
import dev.example.moodlenative.networking.DashboardSnapshot as NetworkDashboardSnapshot
import dev.example.moodlenative.networking.LmsModuleCompletionRequirement as NetworkLmsModuleCompletionRequirement

internal fun NetworkDashboardSnapshot.toLmsDashboardSnapshot(): LmsDashboardSnapshot =
    LmsDashboardSnapshot(
        siteURL = siteURL,
        userID = userID,
        courses = courses.map { course -> course.toLmsDashboardCourse() },
        dashboardBlocks = dashboardBlocks.map { block -> block.toLmsDashboardBlock() },
    )

private fun NetworkCourse.toLmsDashboardCourse(): LmsDashboardCourse =
    LmsDashboardCourse(
        id = id,
        fullName = fullName,
        displayName = displayName,
        shortName = shortName,
        summary = summary,
        courseImage = courseImage,
        progress = progress,
        isFavorite = isFavorite,
    )

private fun NetworkDashboardBlock.toLmsDashboardBlock(): LmsDashboardBlock =
    LmsDashboardBlock(
        instanceID = instanceID,
        name = name,
        region = region,
        positionID = positionID,
        visible = visible,
        contents = contents?.let { content ->
            LmsDashboardBlock.Contents(
                title = content.title,
                content = content.content,
                contentFormat = content.contentFormat,
                footer = content.footer,
            )
        },
    )

internal fun NetworkCourseModule.toLmsCourseModule(): LmsCourseModule =
    LmsCourseModule(
        id = id,
        instanceID = instanceID,
        modName = modName,
        name = name,
        url = url,
        completionRequirements = completionData?.requirements.orEmpty()
            .map { requirement -> requirement.toLmsModuleCompletionRequirement() },
    )

private fun NetworkLmsModuleCompletionRequirement.toLmsModuleCompletionRequirement(): LmsModuleCompletionRequirement =
    LmsModuleCompletionRequirement(
        id = id,
        text = text,
        isComplete = isComplete,
    )
