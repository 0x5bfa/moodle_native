package dev.example.moodlenative.networking

import java.io.ByteArrayOutputStream
import java.net.URI
import java.net.URLEncoder
import java.time.Instant
import java.util.UUID
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.serializer

class LmsWebServiceClient(
    session: LmsWebServiceSession,
    private val httpClient: LmsHttpClient = HttpUrlConnectionLmsHttpClient(),
    private val json: Json = defaultJson,
) {
    private enum class HTTPMethod(val rawValue: String) {
        GET("GET"),
        POST("POST"),
    }

    private val siteURL = session.siteURL.trimEnd('/')
    private val token = session.token
    private val sessionUserID = session.userID

    suspend fun fetchSiteInfo(): SiteInfo =
        sendRequest(
            wsFunction = "core_webservice_get_site_info",
            method = HTTPMethod.GET,
        )

    suspend fun fetchEnrolledCourses(): List<Course> {
        val userID = sessionUserID ?: fetchSiteInfo().userID
        return fetchEnrolledCourses(userID)
    }

    suspend fun fetchCourseContents(courseID: Int): List<CourseSection> =
        sendRequest<List<CourseSection>>(
            wsFunction = "core_course_get_contents",
            method = HTTPMethod.POST,
            parameters = listOf(FormParameter("courseid", courseID.toString())),
        ).map { section ->
            section.copy(
                modules = section.modules.map { module -> module.authorized() },
            )
        }

    suspend fun fetchDashboardBlocks(returnContents: Boolean = true): List<DashboardBlock> {
        val response: DashboardBlocksResponse = sendRequest(
            wsFunction = "core_block_get_dashboard_blocks",
            method = HTTPMethod.POST,
            parameters = listOf(FormParameter("returncontents", if (returnContents) "1" else "0")),
        )

        return response.blocks
    }

    suspend fun fetchAssignments(courseIDs: List<Int>): List<CourseAssignments> {
        if (courseIDs.isEmpty()) {
            return emptyList()
        }

        return fetchAssignmentsWithParameters(
            parameters = courseIDs.mapIndexed { index, courseID ->
                FormParameter("courseids[$index]", courseID.toString())
            },
        )
    }

    suspend fun fetchAssignments(): List<CourseAssignments> =
        fetchAssignmentsWithParameters(parameters = emptyList())

    suspend fun fetchAssignmentSubmissionStatus(assignmentID: Int): AssignmentSubmissionStatus =
        sendRequest<AssignmentSubmissionStatus>(
            wsFunction = "mod_assign_get_submission_status",
            method = HTTPMethod.POST,
            parameters = listOf(FormParameter("assignid", assignmentID.toString())),
        ).authorized()

    suspend fun uploadAssignmentSubmissionFiles(
        files: List<AssignmentSubmissionUploadFile>,
        draftItemID: Int? = null,
    ): List<AssignmentUploadedDraftFile> {
        if (files.isEmpty()) {
            throw LmsWebServiceError.InvalidSubmissionFiles
        }

        return sendRawRequest(makeAssignmentFileUploadRequest(files = files, draftItemID = draftItemID))
    }

    suspend fun downloadAssignmentSubmissionFile(file: AssignmentFile): AssignmentSubmissionUploadFile {
        val fileURL = file.fileURL?.takeIf { it.isNotBlank() }
            ?: throw LmsWebServiceError.InvalidResponse
        val uri = runCatching { URI(fileURL) }
            .getOrElse { throw LmsWebServiceError.InvalidResponse }
        val response = httpClient.send(
            LmsHttpRequest(
                method = HTTPMethod.GET.rawValue,
                url = uri,
            ),
        )
        if (response.statusCode !in 200..299) {
            throw LmsWebServiceError.Http(statusCode = response.statusCode, response = response.body)
        }

        return AssignmentSubmissionUploadFile(
            fileName = file.fileName?.takeIf { it.isNotBlank() } ?: "submission-file",
            mimeType = file.mimeType?.takeIf { it.isNotBlank() } ?: "application/octet-stream",
            data = response.bodyBytes,
        )
    }

    suspend fun saveAssignmentSubmission(
        assignmentID: Int,
        fileDraftItemID: Int? = null,
        onlineText: AssignmentOnlineTextInput? = null,
    ) {
        val parameters = mutableListOf(FormParameter("assignmentid", assignmentID.toString()))
        if (fileDraftItemID != null) {
            parameters += FormParameter("plugindata[files_filemanager]", fileDraftItemID.toString())
        }
        if (onlineText != null) {
            parameters += listOf(
                FormParameter("plugindata[onlinetext_editor][text]", onlineText.text),
                FormParameter("plugindata[onlinetext_editor][format]", onlineText.format.toString()),
                FormParameter("plugindata[onlinetext_editor][itemid]", onlineText.draftItemID.toString()),
            )
        }

        val warnings: List<AssignmentWarning> = sendRequest(
            wsFunction = "mod_assign_save_submission",
            method = HTTPMethod.POST,
            parameters = parameters,
        )

        throwFirstAssignmentWarning(warnings)
    }

    suspend fun saveAssignmentFileSubmission(assignmentID: Int, draftItemID: Int) {
        saveAssignmentSubmission(
            assignmentID = assignmentID,
            fileDraftItemID = draftItemID,
        )
    }

    suspend fun submitAssignmentForGrading(
        assignmentID: Int,
        acceptsSubmissionStatement: Boolean = true,
    ) {
        val warnings: List<AssignmentWarning> = sendRequest(
            wsFunction = "mod_assign_submit_for_grading",
            method = HTTPMethod.POST,
            parameters = listOf(
                FormParameter("assignmentid", assignmentID.toString()),
                FormParameter("acceptsubmissionstatement", if (acceptsSubmissionStatement) "1" else "0"),
            ),
        )

        throwFirstAssignmentWarning(warnings)
    }

    suspend fun startAssignmentSubmission(assignmentID: Int): AssignmentSubmissionStartResponse {
        val response: AssignmentSubmissionStartResponse = sendRequest(
            wsFunction = "mod_assign_start_submission",
            method = HTTPMethod.POST,
            parameters = listOf(FormParameter("assignid", assignmentID.toString())),
        )

        throwFirstAssignmentWarning(
            response.warnings.filter { warning ->
                when (warning.warningCode?.lowercase()) {
                    "timelimitnotenabled", "opensubmissionexists" -> false
                    else -> true
                }
            },
        )

        return response
    }

    suspend fun removeAssignmentSubmission(assignmentID: Int, userID: Int) {
        val response: AssignmentSubmissionRemovalResponse = sendRequest(
            wsFunction = "mod_assign_remove_submission",
            method = HTTPMethod.POST,
            parameters = listOf(
                FormParameter("userid", userID.toString()),
                FormParameter("assignid", assignmentID.toString()),
            ),
        )

        throwFirstAssignmentWarning(response.warnings)
        if (!response.status) {
            throw LmsWebServiceError.Moodle(
                moodleMessage = "提出を削除できませんでした。",
                debugInfo = null,
            )
        }
    }

    suspend fun fetchForumDiscussions(forumID: Int): List<ForumDiscussion> {
        val response: ForumDiscussionsResponse = sendRequest(
            wsFunction = "mod_forum_get_forum_discussions",
            method = HTTPMethod.POST,
            parameters = listOf(FormParameter("forumid", forumID.toString())),
        )

        return response.discussions
    }

    suspend fun fetchDiscussionPosts(discussionID: Int): List<ForumPost> {
        val response: DiscussionPostsResponse = sendRequest(
            wsFunction = "mod_forum_get_discussion_posts",
            method = HTTPMethod.POST,
            parameters = listOf(FormParameter("discussionid", discussionID.toString())),
        )

        return response.posts.map { it.authorized() }
    }

    suspend fun markForumDiscussionViewed(discussionID: Int) {
        sendRequest<JsonElement>(
            wsFunction = "mod_forum_view_forum_discussion",
            method = HTTPMethod.POST,
            parameters = listOf(FormParameter("discussionid", discussionID.toString())),
        )
    }

    suspend fun setFavouriteCourses(courses: List<FavouriteCourseUpdate>) {
        if (courses.isEmpty()) {
            return
        }

        val response: FavouriteCoursesResponse = sendRequest(
            wsFunction = "core_course_set_favourite_courses",
            method = HTTPMethod.POST,
            parameters = favouriteCourseParameters(courses),
        )
        val warning = response.warnings.firstOrNull() ?: return
        throw LmsWebServiceError.Moodle(
            moodleMessage = warning.message ?: "Favorite の更新に失敗しました。",
            debugInfo = warning.warningCode,
        )
    }

    suspend fun fetchPopupNotifications(): PopupNotificationsResponse =
        sendRequest(
            wsFunction = "message_popup_get_popup_notifications",
            method = HTTPMethod.POST,
            parameters = listOf(
                FormParameter("useridto", "0"),
                FormParameter("newestfirst", "1"),
                FormParameter("limit", "0"),
                FormParameter("offset", "0"),
            ),
        )

    suspend fun fetchUnreadNotificationCount(userIDTo: Int? = null): Int {
        val resolvedUserID = resolveUserID(userIDTo)
        return sendRequest(
            wsFunction = "core_message_get_unread_notification_count",
            method = HTTPMethod.POST,
            parameters = listOf(FormParameter("useridto", resolvedUserID.toString())),
        )
    }

    suspend fun markNotificationRead(
        notificationID: Int,
        timeRead: Int = Instant.now().epochSecond.toInt(),
    ) {
        sendRequest<JsonElement>(
            wsFunction = "core_message_mark_notification_read",
            method = HTTPMethod.POST,
            parameters = listOf(
                FormParameter("notificationid", notificationID.toString()),
                FormParameter("timeread", timeRead.toString()),
            ),
        )
    }

    suspend fun markAllNotificationsRead(
        userIDTo: Int? = null,
        userIDFrom: Int? = null,
        timeCreatedTo: Int? = null,
    ) {
        val parameters = mutableListOf(
            FormParameter("useridto", resolveUserID(userIDTo).toString()),
        )
        if (userIDFrom != null) {
            parameters += FormParameter("useridfrom", userIDFrom.toString())
        }
        if (timeCreatedTo != null) {
            parameters += FormParameter("timecreatedto", timeCreatedTo.toString())
        }

        sendRequest<JsonElement>(
            wsFunction = "core_message_mark_all_notifications_as_read",
            method = HTTPMethod.POST,
            parameters = parameters,
        )
    }

    suspend fun fetchNotificationPreferences(userID: Int? = null): NotificationPreferences =
        try {
            val parameters = if (userID != null) {
                listOf(FormParameter("userid", userID.toString()))
            } else {
                emptyList()
            }
            val response: NotificationPreferencesResponse = sendRequest(
                wsFunction = "core_message_get_user_notification_preferences",
                method = HTTPMethod.POST,
                parameters = parameters,
            )
            response.preferences
        } catch (error: LmsWebServiceError.Moodle) {
            if (!isInvalidNotificationPreferencesResponse(error)) {
                throw error
            }
            fetchFallbackNotificationPreferences()
        }

    suspend fun fetchMessagePreferences(): MessagePreferences {
        val response: MessagePreferencesResponse = sendRequest(
            wsFunction = "core_message_get_user_message_preferences",
            method = HTTPMethod.POST,
        )

        return MessagePreferences(
            notificationPreferences = response.preferences,
            blockNonContacts = response.blockNonContacts,
            enterToSend = response.enterToSend,
        )
    }

    suspend fun updateUserPreferences(
        preferences: List<UserPreferenceUpdate>,
        disableNotifications: Boolean? = null,
        userID: Int? = null,
    ) {
        val resolvedUserID = resolveUserID(userID)
        sendRequest<JsonElement>(
            wsFunction = "core_user_update_user_preferences",
            method = HTTPMethod.POST,
            parameters = updateUserPreferencesParameters(
                preferences = preferences,
                disableNotifications = disableNotifications,
                userID = resolvedUserID,
            ),
        )
    }

    suspend fun fetchUserPreferences(name: String? = null): List<UserPreference> {
        val parameters = if (name == null) {
            emptyList()
        } else {
            listOf(FormParameter("name", name))
        }
        val response: UserPreferencesResponse = sendRequest(
            wsFunction = "core_user_get_user_preferences",
            method = HTTPMethod.POST,
            parameters = parameters,
        )

        return response.preferences
    }

    suspend fun fetchCalendarExportToken(): String {
        val response: CalendarExportTokenResponse = sendRequest(
            wsFunction = "core_calendar_get_calendar_export_token",
            method = HTTPMethod.POST,
        )

        return response.token
    }

    suspend fun makeCalendarSubscription(
        eventPreset: CalendarSubscription.EventPreset = CalendarSubscription.EventPreset.ALL,
        timePreset: CalendarSubscription.TimePreset = CalendarSubscription.TimePreset.RECENT_UPCOMING,
        userID: Int? = null,
    ): CalendarSubscription {
        val resolvedUserID = resolveUserID(userID)
        val exportToken = fetchCalendarExportToken()
        val endpoint = calendarExportURI()
        val query = encodeForm(
            listOf(
                FormParameter("userid", resolvedUserID.toString()),
                FormParameter("authtoken", exportToken),
                FormParameter("preset_what", eventPreset.rawValue),
                FormParameter("preset_time", timePreset.rawValue),
            ),
        )

        val separator = if (endpoint.rawQuery.isNullOrEmpty()) "?" else "&"
        val uri = runCatching { URI("${endpoint}$separator$query") }
            .getOrElse { throw LmsWebServiceError.InvalidSiteURL }
        return CalendarSubscription(uri = uri)
    }

    suspend fun fetchTimetableSnapshot(userID: Int? = null): DashboardSnapshot {
        val resolvedUserID = userID ?: sessionUserID ?: fetchSiteInfo().userID
        val courses = fetchEnrolledCourses(resolvedUserID)
        val dashboardBlocks = try {
            fetchDashboardBlocks(returnContents = true)
        } catch (_: Exception) {
            emptyList()
        }

        return DashboardSnapshot(
            siteURL = siteURL,
            userID = resolvedUserID,
            courses = courses,
            dashboardBlocks = dashboardBlocks,
        )
    }

    private suspend fun fetchEnrolledCourses(userID: Int): List<Course> =
        sendRequest(
            wsFunction = "core_enrol_get_users_courses",
            method = HTTPMethod.POST,
            parameters = listOf(
                FormParameter("userid", userID.toString()),
                FormParameter("returnusercount", "0"),
            ),
        )

    private suspend fun resolveUserID(preferredUserID: Int?): Int =
        preferredUserID ?: sessionUserID ?: fetchSiteInfo().userID

    private suspend fun fetchAssignmentsWithParameters(parameters: List<FormParameter>): List<CourseAssignments> {
        val response: AssignmentsResponse = sendRequest(
            wsFunction = "mod_assign_get_assignments",
            method = HTTPMethod.POST,
            parameters = parameters,
        )

        return response.courses
    }

    private suspend inline fun <reified Response> sendRequest(
        wsFunction: String,
        method: HTTPMethod,
        parameters: List<FormParameter> = emptyList(),
    ): Response {
        val request = makeRequest(
            wsFunction = wsFunction,
            method = method,
            parameters = parameters,
        )
        val response = httpClient.send(request)
        return decodeResponse(response)
    }

    private suspend inline fun <reified Response> sendRawRequest(request: LmsHttpRequest): Response {
        val response = httpClient.send(request)
        return decodeResponse(response)
    }

    private fun makeRequest(
        wsFunction: String,
        method: HTTPMethod,
        parameters: List<FormParameter>,
    ): LmsHttpRequest {
        val endpointURL = endpointURI()
        val authParameters = listOf(
            FormParameter("wstoken", token),
            FormParameter("wsfunction", wsFunction),
            FormParameter("moodlewsrestformat", "json"),
        )
        val allParameters = authParameters + parameters

        return when (method) {
            HTTPMethod.GET -> LmsHttpRequest(
                method = method.rawValue,
                url = appendQuery(endpointURL, encodeForm(allParameters)),
            )

            HTTPMethod.POST -> LmsHttpRequest(
                method = method.rawValue,
                url = endpointURL,
                headers = mapOf("Content-Type" to "application/x-www-form-urlencoded"),
                body = encodeForm(allParameters).toByteArray(Charsets.UTF_8),
            )
        }
    }

    private fun makeAssignmentFileUploadRequest(
        files: List<AssignmentSubmissionUploadFile>,
        draftItemID: Int?,
    ): LmsHttpRequest {
        val boundary = "MoodleNativeBoundary-${UUID.randomUUID()}"
        val body = ByteArrayOutputStream()
        body.appendMultipartField(name = "token", value = token, boundary = boundary)
        body.appendMultipartField(name = "filearea", value = "draft", boundary = boundary)
        body.appendMultipartField(name = "itemid", value = (draftItemID ?: 0).toString(), boundary = boundary)
        body.appendMultipartField(name = "filepath", value = "/", boundary = boundary)

        files.forEachIndexed { index, file ->
            body.appendMultipartFile(
                name = "file_${index + 1}",
                fileName = file.fileName,
                mimeType = file.mimeType,
                data = file.data,
                boundary = boundary,
            )
        }

        body.appendUTF8("--$boundary--\r\n")

        return LmsHttpRequest(
            method = HTTPMethod.POST.rawValue,
            url = uploadEndpointURI(),
            headers = mapOf("Content-Type" to "multipart/form-data; boundary=$boundary"),
            body = body.toByteArray(),
        )
    }

    private fun endpointURI(): URI {
        val base = runCatching { URI(siteURL) }.getOrNull()
        if (base?.scheme.isNullOrEmpty() || base?.host.isNullOrEmpty()) {
            throw LmsWebServiceError.InvalidSiteURL
        }

        return runCatching { URI("$siteURL/webservice/rest/server.php") }
            .getOrElse { throw LmsWebServiceError.InvalidSiteURL }
    }

    private fun uploadEndpointURI(): URI {
        val base = runCatching { URI(siteURL) }.getOrNull()
        if (base?.scheme.isNullOrEmpty() || base?.host.isNullOrEmpty()) {
            throw LmsWebServiceError.InvalidSiteURL
        }

        return runCatching { URI("$siteURL/webservice/upload.php") }
            .getOrElse { throw LmsWebServiceError.InvalidSiteURL }
    }

    private fun calendarExportURI(): URI {
        val base = runCatching { URI(siteURL) }.getOrNull()
        if (base?.scheme.isNullOrEmpty() || base?.host.isNullOrEmpty()) {
            throw LmsWebServiceError.InvalidSiteURL
        }

        return runCatching { URI("$siteURL/calendar/export_execute.php") }
            .getOrElse { throw LmsWebServiceError.InvalidSiteURL }
    }

    private fun appendQuery(uri: URI, encodedQuery: String): URI {
        val separator = if (uri.rawQuery.isNullOrEmpty()) "?" else "&"
        return runCatching { URI("${uri}$separator$encodedQuery") }
            .getOrElse { throw LmsWebServiceError.InvalidSiteURL }
    }

    private fun CourseModule.authorized(): CourseModule =
        copy(
            url = authorizedURLString(url),
            contents = contents.map { content ->
                content.copy(fileURL = authorizedURLString(content.fileURL))
            },
        )

    private fun AssignmentSubmissionStatus.authorized(): AssignmentSubmissionStatus =
        copy(
            lastAttempt = lastAttempt?.authorized(),
            feedback = feedback?.authorized(),
            previousAttempts = previousAttempts.map { it.authorized() },
            assignmentData = assignmentData?.authorized(),
        )

    private fun AssignmentLastAttempt.authorized(): AssignmentLastAttempt =
        copy(
            submission = submission?.authorized(),
            teamSubmission = teamSubmission?.authorized(),
        )

    private fun AssignmentSubmission.authorized(): AssignmentSubmission =
        copy(
            plugins = plugins.map { it.authorized() },
        )

    private fun AssignmentPlugin.authorized(): AssignmentPlugin =
        copy(
            fileAreas = fileAreas.map { it.authorized() },
        )

    private fun AssignmentPluginFileArea.authorized(): AssignmentPluginFileArea =
        copy(
            files = files.map { it.authorized() },
        )

    private fun AssignmentFeedback.authorized(): AssignmentFeedback =
        copy(
            plugins = plugins.map { it.authorized() },
        )

    private fun AssignmentPreviousAttempt.authorized(): AssignmentPreviousAttempt =
        copy(
            submission = submission?.authorized(),
            feedbackPlugins = feedbackPlugins.map { it.authorized() },
        )

    private fun AssignmentData.authorized(): AssignmentData =
        copy(
            attachments = attachments?.authorized(),
        )

    private fun AssignmentDataAttachments.authorized(): AssignmentDataAttachments =
        copy(
            intro = intro.map { it.authorized() },
            activity = activity.map { it.authorized() },
        )

    private fun AssignmentFile.authorized(): AssignmentFile =
        copy(fileURL = authorizedURLString(fileURL))

    private fun ForumPost.authorized(): ForumPost =
        copy(
            attachments = attachments.map { it.withFileURL(authorizedURLString(it.fileURL)) },
        )

    private fun throwFirstAssignmentWarning(warnings: List<AssignmentWarning>) {
        val warning = warnings.firstOrNull() ?: return
        throw LmsWebServiceError.Moodle(
            moodleMessage = warning.message ?: "提出操作を完了できませんでした。",
            debugInfo = warning.warningCode,
        )
    }

    private suspend fun fetchFallbackNotificationPreferences(): NotificationPreferences {
        val userID = resolveUserID(null)
        val savedPreferences = fetchUserPreferences().mapNotNull { preference ->
            preference.value?.let { preference.name to it }
        }.toMap()
        val processors = fallbackNotificationProcessors()

        return NotificationPreferences(
            userID = userID,
            disableAll = false,
            processors = processors,
            components = fallbackNotificationComponents(
                processors = processors,
                savedPreferences = savedPreferences,
            ),
        )
    }

    private fun isInvalidNotificationPreferencesResponse(error: LmsWebServiceError.Moodle): Boolean =
        error.debugInfo == "invalidresponse" ||
            error.moodleMessage.contains("無効なレスポンス値")

    private fun fallbackNotificationProcessors(): List<NotificationPreferencesProcessor> =
        listOf(
            NotificationPreferencesProcessor(
                displayName = "ウェブ",
                name = "popup",
                hasSettings = true,
                contextID = null,
                userConfigured = true,
            ),
            NotificationPreferencesProcessor(
                displayName = "メール",
                name = "email",
                hasSettings = true,
                contextID = null,
                userConfigured = true,
            ),
            NotificationPreferencesProcessor(
                displayName = "モバイル",
                name = "airnotifier",
                hasSettings = true,
                contextID = null,
                userConfigured = true,
            ),
        )

    private fun fallbackNotificationComponents(
        processors: List<NotificationPreferencesProcessor>,
        savedPreferences: Map<String, String>,
    ): List<NotificationPreferencesComponent> {
        val definitions = listOf(
            FallbackNotificationComponentDefinition(
                component = "課題",
                notifications = listOf(
                    "課題通知" to "message_provider_mod_assign_assign_notification",
                    "課題の提出期限到来通知" to "message_provider_mod_assign_assign_due_soon",
                    "課題期限超過通知" to "message_provider_mod_assign_assign_overdue",
                    "課題提出期限7日以内通知" to "message_provider_mod_assign_assign_due_digest",
                ),
            ),
            FallbackNotificationComponentDefinition(
                component = "フォーラム",
                notifications = listOf(
                    "購読済みフォーラム投稿" to "message_provider_mod_forum_posts",
                    "購読済みフォーラムダイジェスト" to "message_provider_mod_forum_digests",
                ),
            ),
            FallbackNotificationComponentDefinition(
                component = "アンケート",
                notifications = listOf(
                    "アンケートリマインダ" to "message_provider_mod_questionnaire_message",
                    "アンケート提出" to "message_provider_mod_questionnaire_notification",
                ),
            ),
            FallbackNotificationComponentDefinition(
                component = "小テスト",
                notifications = listOf(
                    "小テスト公開予定" to "message_provider_mod_quiz_quiz_open_soon",
                ),
            ),
            FallbackNotificationComponentDefinition(
                component = "システム",
                notifications = listOf(
                    "コースコンテンツ変更" to "message_provider_moodle_coursecontentupdated",
                    "評定通知" to "message_provider_moodle_gradenotifications",
                    "カスタムレポートビルダスケジュール" to "message_provider_moodle_reportbuilderschedule",
                ),
            ),
            FallbackNotificationComponentDefinition(
                component = "私の先生にメッセージ",
                description = "授業コード、授業名（曜日時限）、学生証番号を明記して送信すること",
                notifications = listOf(
                    "「私の教師にメッセージ」ブロックで送信されたメッセージ" to
                        "message_provider_block_messageteacher_message",
                ),
            ),
            FallbackNotificationComponentDefinition(
                component = "イベントリマインダ",
                notifications = listOf(
                    "ユーザイベントのリマインダ通知" to "message_provider_local_reminders_reminders_user",
                    "コースイベントのリマインダ通知" to "message_provider_local_reminders_reminders_course",
                    "活動イベントのリマインダ通知" to "message_provider_local_reminders_reminders_due",
                ),
            ),
        )

        return definitions.map { definition ->
            NotificationPreferencesComponent(
                displayName = definition.component,
                description = definition.description,
                notifications = definition.notifications.map { notification ->
                    NotificationPreference(
                        displayName = notification.first,
                        preferenceKey = notification.second,
                        processors = processors.map { processor ->
                            val enabled = isProcessorEnabled(
                                processorName = processor.name,
                                preferenceKey = notification.second,
                                savedPreferences = savedPreferences,
                            )
                            NotificationPreferenceProcessor(
                                displayName = processor.displayName,
                                name = processor.name,
                                locked = false,
                                lockedMessage = null,
                                userConfigured = true,
                                enabled = enabled,
                                loggedIn = null,
                                loggedOff = null,
                            )
                        },
                    )
                },
            )
        }
    }

    private fun isProcessorEnabled(
        processorName: String,
        preferenceKey: String,
        savedPreferences: Map<String, String>,
    ): Boolean {
        val value = savedPreferences["${preferenceKey}_$processorName"] ?: return true
        return value != "0" && value.lowercase() != "false" && value != "none"
    }

    private fun favouriteCourseParameters(courses: List<FavouriteCourseUpdate>): List<FormParameter> =
        courses.flatMapIndexed { index, course ->
            listOf(
                FormParameter("courses[$index][id]", course.id.toString()),
                FormParameter("courses[$index][favourite]", if (course.isFavorite) "1" else "0"),
            )
        }

    private fun updateUserPreferencesParameters(
        preferences: List<UserPreferenceUpdate>,
        disableNotifications: Boolean?,
        userID: Int,
    ): List<FormParameter> {
        val parameters = mutableListOf(FormParameter("userid", userID.toString()))

        if (disableNotifications != null) {
            parameters += FormParameter("emailstop", if (disableNotifications) "1" else "0")
        }

        preferences.forEachIndexed { index, preference ->
            parameters += FormParameter("preferences[$index][type]", preference.type)
            if (preference.value != null) {
                parameters += FormParameter("preferences[$index][value]", preference.value)
            }
        }

        return parameters
    }

    private fun authorizedURLString(value: String?): String? {
        if (value.isNullOrEmpty() || value.contains("token=")) {
            return value
        }

        val separator = if (value.contains("?")) "&" else "?"
        return "$value${separator}token=${token.formEncoded()}"
    }

    private inline fun <reified Response> decodeResponse(response: LmsHttpResponse): Response {
        if (response.statusCode !in 200..299) {
            throw LmsWebServiceError.Http(statusCode = response.statusCode, response = response.body)
        }

        val moodleError = runCatching {
            json.decodeFromString<MoodleErrorResponse>(response.body)
        }.getOrNull()
        if (moodleError?.isError == true) {
            throw LmsWebServiceError.Moodle(
                moodleMessage = moodleError.message
                    ?: moodleError.errorCode
                    ?: moodleError.exception
                    ?: "Unknown Moodle error",
                debugInfo = moodleError.debugInfo,
            )
        }

        try {
            return json.decodeFromString(serializer<Response>(), response.body)
        } catch (error: SerializationException) {
            throw LmsWebServiceError.Decoding(error)
        } catch (error: IllegalArgumentException) {
            throw LmsWebServiceError.Decoding(error)
        }
    }

    private data class FormParameter(
        val name: String,
        val value: String,
    )

    private companion object {
        val defaultJson: Json = Json {
            ignoreUnknownKeys = true
            explicitNulls = false
        }

        fun encodeForm(parameters: List<FormParameter>): String =
            parameters.joinToString("&") { parameter ->
                "${parameter.name.formEncoded()}=${parameter.value.formEncoded()}"
            }

        fun String.formEncoded(): String =
            URLEncoder.encode(this, Charsets.UTF_8)

        fun ByteArrayOutputStream.appendMultipartField(
            name: String,
            value: String,
            boundary: String,
        ) {
            appendUTF8("--$boundary\r\n")
            appendUTF8("Content-Disposition: form-data; name=\"$name\"\r\n\r\n")
            appendUTF8(value)
            appendUTF8("\r\n")
        }

        fun ByteArrayOutputStream.appendMultipartFile(
            name: String,
            fileName: String,
            mimeType: String,
            data: ByteArray,
            boundary: String,
        ) {
            appendUTF8("--$boundary\r\n")
            appendUTF8("Content-Disposition: form-data; name=\"$name\"; filename=\"$fileName\"\r\n")
            appendUTF8("Content-Type: $mimeType\r\n\r\n")
            write(data)
            appendUTF8("\r\n")
        }

        fun ByteArrayOutputStream.appendUTF8(value: String) {
            write(value.toByteArray(Charsets.UTF_8))
        }
    }

    private data class FallbackNotificationComponentDefinition(
        val component: String,
        val description: String? = null,
        val notifications: List<Pair<String, String>>,
    )
}
