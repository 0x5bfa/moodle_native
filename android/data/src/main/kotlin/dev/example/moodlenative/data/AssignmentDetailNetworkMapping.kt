package dev.example.moodlenative.data

import dev.example.moodlenative.features.LmsAssignmentData
import dev.example.moodlenative.features.LmsAssignmentDataAttachments
import dev.example.moodlenative.features.LmsAssignmentFeedback
import dev.example.moodlenative.features.LmsAssignmentFile
import dev.example.moodlenative.features.LmsAssignmentGrade
import dev.example.moodlenative.features.LmsAssignmentLastAttempt
import dev.example.moodlenative.features.LmsAssignmentPlugin
import dev.example.moodlenative.features.LmsAssignmentPluginEditorField
import dev.example.moodlenative.features.LmsAssignmentPluginFileArea
import dev.example.moodlenative.features.LmsAssignmentSubmission
import dev.example.moodlenative.features.LmsAssignmentSubmissionStatus
import dev.example.moodlenative.features.LmsAssignmentWarning
import dev.example.moodlenative.networking.AssignmentData as NetworkAssignmentData
import dev.example.moodlenative.networking.AssignmentDataAttachments as NetworkAssignmentDataAttachments
import dev.example.moodlenative.networking.AssignmentFeedback as NetworkAssignmentFeedback
import dev.example.moodlenative.networking.AssignmentFile as NetworkAssignmentFile
import dev.example.moodlenative.networking.AssignmentGrade as NetworkAssignmentGrade
import dev.example.moodlenative.networking.AssignmentLastAttempt as NetworkAssignmentLastAttempt
import dev.example.moodlenative.networking.AssignmentPlugin as NetworkAssignmentPlugin
import dev.example.moodlenative.networking.AssignmentPluginEditorField as NetworkAssignmentPluginEditorField
import dev.example.moodlenative.networking.AssignmentPluginFileArea as NetworkAssignmentPluginFileArea
import dev.example.moodlenative.networking.AssignmentSubmission as NetworkAssignmentSubmission
import dev.example.moodlenative.networking.AssignmentSubmissionStatus as NetworkAssignmentSubmissionStatus
import dev.example.moodlenative.networking.AssignmentWarning as NetworkAssignmentWarning

internal fun NetworkAssignmentSubmissionStatus.toLmsAssignmentSubmissionStatus(): LmsAssignmentSubmissionStatus =
    LmsAssignmentSubmissionStatus(
        lastAttempt = lastAttempt?.toLmsAssignmentLastAttempt(),
        feedback = feedback?.toLmsAssignmentFeedback(),
        assignmentData = assignmentData?.toLmsAssignmentData(),
        warnings = warnings.map { warning -> warning.toLmsAssignmentWarning() },
    )

private fun NetworkAssignmentLastAttempt.toLmsAssignmentLastAttempt(): LmsAssignmentLastAttempt =
    LmsAssignmentLastAttempt(
        submission = submission?.toLmsAssignmentSubmission(),
        teamSubmission = teamSubmission?.toLmsAssignmentSubmission(),
        submissionGroup = submissionGroup,
        submissionGroupMembersWhoNeedToSubmit = submissionGroupMembersWhoNeedToSubmit,
        submissionsEnabled = submissionsEnabled,
        locked = locked,
        graded = graded,
        canEdit = canEdit,
        canEditOwner = canEditOwner,
        canSubmit = canSubmit,
        extensionDueDate = extensionDueDate,
        timeLimit = timeLimit,
        blindMarking = blindMarking,
        gradingStatus = gradingStatus,
        userGroups = userGroups,
    )

private fun NetworkAssignmentSubmission.toLmsAssignmentSubmission(): LmsAssignmentSubmission =
    LmsAssignmentSubmission(
        id = id,
        userID = userID,
        attemptNumber = attemptNumber,
        timeCreated = timeCreated,
        timeModified = timeModified,
        timeStarted = timeStarted,
        status = status,
        groupID = groupID,
        assignmentID = assignmentID,
        latest = latest,
        plugins = plugins.map { plugin -> plugin.toLmsAssignmentPlugin() },
        gradingStatus = gradingStatus,
    )

private fun NetworkAssignmentPlugin.toLmsAssignmentPlugin(): LmsAssignmentPlugin =
    LmsAssignmentPlugin(
        type = type,
        name = name,
        fileAreas = fileAreas.map { fileArea -> fileArea.toLmsAssignmentPluginFileArea() },
        editorFields = editorFields.map { editorField -> editorField.toLmsAssignmentPluginEditorField() },
    )

private fun NetworkAssignmentPluginFileArea.toLmsAssignmentPluginFileArea(): LmsAssignmentPluginFileArea =
    LmsAssignmentPluginFileArea(
        area = area,
        files = files.map { file -> file.toLmsAssignmentFile() },
    )

private fun NetworkAssignmentPluginEditorField.toLmsAssignmentPluginEditorField(): LmsAssignmentPluginEditorField =
    LmsAssignmentPluginEditorField(
        name = name,
        description = description,
        text = text,
        format = format,
    )

private fun NetworkAssignmentFile.toLmsAssignmentFile(): LmsAssignmentFile =
    LmsAssignmentFile(
        fileName = fileName,
        filePath = filePath,
        fileSize = fileSize,
        fileURL = fileURL,
        mimeType = mimeType,
        timeModified = timeModified,
        isExternalFile = isExternalFile,
        repositoryType = repositoryType,
    )

private fun NetworkAssignmentFeedback.toLmsAssignmentFeedback(): LmsAssignmentFeedback =
    LmsAssignmentFeedback(
        grade = grade?.toLmsAssignmentGrade(),
        gradeForDisplay = gradeForDisplay,
        gradedDate = gradedDate,
        plugins = plugins.map { plugin -> plugin.toLmsAssignmentPlugin() },
    )

private fun NetworkAssignmentGrade.toLmsAssignmentGrade(): LmsAssignmentGrade =
    LmsAssignmentGrade(
        id = id,
        assignmentID = assignmentID,
        userID = userID,
        attemptNumber = attemptNumber,
        timeCreated = timeCreated,
        timeModified = timeModified,
        grader = grader,
        grade = grade,
        gradeForDisplay = gradeForDisplay,
    )

private fun NetworkAssignmentData.toLmsAssignmentData(): LmsAssignmentData =
    LmsAssignmentData(
        attachments = attachments?.toLmsAssignmentDataAttachments(),
        activity = activity,
        activityFormat = activityFormat,
    )

private fun NetworkAssignmentDataAttachments.toLmsAssignmentDataAttachments(): LmsAssignmentDataAttachments =
    LmsAssignmentDataAttachments(
        intro = intro.map { file -> file.toLmsAssignmentFile() },
        activity = activity.map { file -> file.toLmsAssignmentFile() },
    )

private fun NetworkAssignmentWarning.toLmsAssignmentWarning(): LmsAssignmentWarning =
    LmsAssignmentWarning(
        item = item,
        itemID = itemID,
        warningCode = warningCode,
        message = message,
    )
