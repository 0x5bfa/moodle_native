import Foundation
import MoodleNativeCore

public final class LmsWebServiceClient: Sendable {
    private enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
    }

    private let urlSession: URLSession
    private let siteURL: String
    private let token: String
    private let sessionUserID: Int?
    private let requestLogger: (any LmsWebServiceRequestLogging)?
    private let logContext: LmsRequestLogContext?

    public init(
        session: LmsAuthenticationSession,
        urlSession: URLSession = .shared,
        requestLogger: (any LmsWebServiceRequestLogging)? = nil,
        logContext: LmsRequestLogContext? = nil
    ) {
        self.urlSession = urlSession
        self.siteURL = session.siteURL
        self.token = session.token
        self.sessionUserID = session.userID
        self.requestLogger = requestLogger
        self.logContext = logContext
    }

    public func fetchSiteInfo() async throws -> SiteInfo {
        return try await sendRequest(
            wsFunction: "core_webservice_get_site_info",
            method: .get,
            responseType: SiteInfo.self
        )
    }

    public func fetchEnrolledCourses() async throws -> [Course] {
        if let sessionUserID {
            return try await fetchEnrolledCourses(userID: sessionUserID)
        }

        let siteInfo = try await fetchSiteInfo()
        return try await fetchEnrolledCourses(userID: siteInfo.userID)
    }

    public func fetchCourseContents(courseID: Int) async throws -> [CourseSection] {
        let sections = try await sendRequest(
            wsFunction: "core_course_get_contents",
            method: .post,
            parameters: [URLQueryItem(name: "courseid", value: String(courseID))],
            responseType: [CourseSection].self
        )

        return sections.map { section in
            var section = section
            section.modules = section.modules.map(authorize)
            return section
        }
    }

    public func fetchDashboardBlocks(returnContents: Bool = true) async throws -> [DashboardBlock] {
        let response = try await sendRequest(
            wsFunction: "core_block_get_dashboard_blocks",
            method: .post,
            parameters: [
                URLQueryItem(name: "returncontents", value: returnContents ? "1" : "0")
            ],
            responseType: DashboardBlocksResponse.self
        )

        return response.blocks
    }

    public func fetchAssignments(courseIDs: [Int]) async throws -> [CourseAssignments] {
        guard courseIDs.isEmpty == false else {
            return []
        }

        return try await fetchAssignments(
            parameters: indexedParameters(name: "courseids", values: courseIDs)
        )
    }

    public func fetchAssignments() async throws -> [CourseAssignments] {
        try await fetchAssignments(parameters: [])
    }

    private func fetchAssignments(parameters: [URLQueryItem]) async throws -> [CourseAssignments] {
        let response = try await sendRequest(
            wsFunction: "mod_assign_get_assignments",
            method: .post,
            parameters: parameters,
            responseType: AssignmentsResponse.self
        )

        return response.courses
    }

    public func fetchAssignmentSubmissionStatus(assignmentID: Int) async throws -> AssignmentSubmissionStatus {
        let response = try await sendRequest(
            wsFunction: "mod_assign_get_submission_status",
            method: .post,
            parameters: [URLQueryItem(name: "assignid", value: String(assignmentID))],
            responseType: AssignmentSubmissionStatus.self
        )

        return authorize(response)
    }

    public func uploadAssignmentSubmissionFiles(
        _ files: [AssignmentSubmissionUploadFile],
        draftItemID: Int? = nil
    ) async throws -> [AssignmentUploadedDraftFile] {
        guard files.isEmpty == false else {
            throw LmsWebServiceError.invalidSubmissionFiles
        }

        let parameters = [
            URLQueryItem(name: "itemid", value: String(draftItemID ?? 0)),
            URLQueryItem(name: "files", value: files.map(\.fileName).joined(separator: ", ")),
        ]
        let request = try makeAssignmentFileUploadRequest(files: files, draftItemID: draftItemID)

        return try await send(
            request: request,
            wsFunction: "webservice/upload.php",
            parameters: parameters,
            responseType: [AssignmentUploadedDraftFile].self
        )
    }

    public func downloadAssignmentSubmissionFile(
        _ file: AssignmentFile
    ) async throws -> AssignmentSubmissionUploadFile {
        guard let fileURL = file.fileURL, let url = URL(string: fileURL) else {
            throw LmsWebServiceError.invalidResponse
        }

        let (data, response) = try await urlSession.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LmsWebServiceError.invalidResponse
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            throw LmsWebServiceError.http(
                statusCode: httpResponse.statusCode,
                response: String(data: data, encoding: .utf8) ?? ""
            )
        }

        return AssignmentSubmissionUploadFile(
            fileName: file.fileName ?? "submission-file",
            mimeType: file.mimeType ?? "application/octet-stream",
            data: data
        )
    }

    public func saveAssignmentSubmission(
        assignmentID: Int,
        fileDraftItemID: Int? = nil,
        onlineText: AssignmentOnlineTextInput? = nil
    ) async throws {
        var parameters = [URLQueryItem(name: "assignmentid", value: String(assignmentID))]
        if let fileDraftItemID {
            parameters.append(
                URLQueryItem(name: "plugindata[files_filemanager]", value: String(fileDraftItemID))
            )
        }
        if let onlineText {
            parameters.append(contentsOf: [
                URLQueryItem(name: "plugindata[onlinetext_editor][text]", value: onlineText.text),
                URLQueryItem(name: "plugindata[onlinetext_editor][format]", value: String(onlineText.format)),
                URLQueryItem(name: "plugindata[onlinetext_editor][itemid]", value: String(onlineText.draftItemID)),
            ])
        }

        let warnings = try await sendRequest(
            wsFunction: "mod_assign_save_submission",
            method: .post,
            parameters: parameters,
            responseType: [AssignmentWarning].self
        )

        try throwFirstAssignmentWarning(in: warnings)
    }

    public func saveAssignmentFileSubmission(assignmentID: Int, draftItemID: Int) async throws {
        try await saveAssignmentSubmission(
            assignmentID: assignmentID,
            fileDraftItemID: draftItemID
        )
    }

    public func submitAssignmentForGrading(
        assignmentID: Int,
        acceptsSubmissionStatement: Bool = true
    ) async throws {
        let warnings = try await sendRequest(
            wsFunction: "mod_assign_submit_for_grading",
            method: .post,
            parameters: [
                URLQueryItem(name: "assignmentid", value: String(assignmentID)),
                URLQueryItem(
                    name: "acceptsubmissionstatement",
                    value: acceptsSubmissionStatement ? "1" : "0"
                ),
            ],
            responseType: [AssignmentWarning].self
        )

        try throwFirstAssignmentWarning(in: warnings)
    }

    @discardableResult
    public func startAssignmentSubmission(assignmentID: Int) async throws -> AssignmentSubmissionStartResponse {
        let response = try await sendRequest(
            wsFunction: "mod_assign_start_submission",
            method: .post,
            parameters: [URLQueryItem(name: "assignid", value: String(assignmentID))],
            responseType: AssignmentSubmissionStartResponse.self
        )

        try throwFirstAssignmentWarning(
            in: response.warnings.filter { warning in
                guard let code = warning.warningCode?.lowercased() else {
                    return true
                }

                return code != "timelimitnotenabled" && code != "opensubmissionexists"
            }
        )
        return response
    }

    public func removeAssignmentSubmission(assignmentID: Int, userID: Int) async throws {
        let response = try await sendRequest(
            wsFunction: "mod_assign_remove_submission",
            method: .post,
            parameters: [
                URLQueryItem(name: "userid", value: String(userID)),
                URLQueryItem(name: "assignid", value: String(assignmentID)),
            ],
            responseType: AssignmentSubmissionRemovalResponse.self
        )

        try throwFirstAssignmentWarning(in: response.warnings)
        guard response.status else {
            throw LmsWebServiceError.moodle(message: "提出を削除できませんでした。", debugInfo: nil)
        }
    }

    public func fetchForumDiscussions(forumID: Int) async throws -> [ForumDiscussion] {
        let response = try await sendRequest(
            wsFunction: "mod_forum_get_forum_discussions",
            method: .post,
            parameters: [URLQueryItem(name: "forumid", value: String(forumID))],
            responseType: ForumDiscussionsResponse.self
        )

        return response.discussions
    }

    public func fetchDiscussionPosts(discussionID: Int) async throws -> [ForumPost] {
        let response = try await sendRequest(
            wsFunction: "mod_forum_get_discussion_posts",
            method: .post,
            parameters: [URLQueryItem(name: "discussionid", value: String(discussionID))],
            responseType: DiscussionPostsResponse.self
        )

        return response.posts.map(authorize)
    }

    public func markForumDiscussionViewed(discussionID: Int) async throws {
        _ = try await sendRequest(
            wsFunction: "mod_forum_view_forum_discussion",
            method: .post,
            parameters: [URLQueryItem(name: "discussionid", value: String(discussionID))],
            responseType: IgnoredResponse.self
        )
    }

    public struct FavouriteCourseUpdate: Sendable {
        public let id: Int
        public let isFavorite: Bool

        public init(id: Int, isFavorite: Bool) {
            self.id = id
            self.isFavorite = isFavorite
        }
    }

    public func setFavouriteCourses(_ courses: [FavouriteCourseUpdate]) async throws {
        guard courses.isEmpty == false else {
            return
        }

        let response = try await sendRequest(
            wsFunction: "core_course_set_favourite_courses",
            method: .post,
            parameters: favouriteCourseParameters(courses),
            responseType: FavouriteCoursesResponse.self
        )

        if let warning = response.warnings.first {
            throw LmsWebServiceError.moodle(
                message: warning.message,
                debugInfo: warning.warningCode
            )
        }
    }

    public func fetchPopupNotifications() async throws -> PopupNotificationsResponse {
        return try await sendRequest(
            wsFunction: "message_popup_get_popup_notifications",
            method: .post,
            parameters: [
                URLQueryItem(name: "useridto", value: "0"),
                URLQueryItem(name: "newestfirst", value: "1"),
                URLQueryItem(name: "limit", value: "0"),
                URLQueryItem(name: "offset", value: "0"),
            ],
            responseType: PopupNotificationsResponse.self
        )
    }

    public func fetchUnreadNotificationCount(userIDTo preferredUserIDTo: Int? = nil) async throws -> Int {
        let userIDTo = try await resolveUserID(preferredUserIDTo)

        return try await sendRequest(
            wsFunction: "core_message_get_unread_notification_count",
            method: .post,
            parameters: [
                URLQueryItem(name: "useridto", value: String(userIDTo))
            ],
            responseType: Int.self
        )
    }

    public func fetchNotificationPreferences(userID preferredUserID: Int? = nil) async throws
        -> NotificationPreferences
    {
        do {
            let parameters =
                if let preferredUserID {
                    [URLQueryItem(name: "userid", value: String(preferredUserID))]
                } else {
                    [URLQueryItem]()
                }
            let response = try await sendRequest(
                wsFunction: "core_message_get_user_notification_preferences",
                method: .post,
                parameters: parameters,
                responseType: NotificationPreferencesResponse.self
            )

            return response.preferences
        } catch {
            guard isInvalidNotificationPreferencesResponse(error) else {
                throw error
            }

            return try await fetchFallbackNotificationPreferences()
        }
    }

    public func fetchMessagePreferences() async throws -> MessagePreferences {
        let response = try await sendRequest(
            wsFunction: "core_message_get_user_message_preferences",
            method: .post,
            parameters: [],
            responseType: MessagePreferencesResponse.self
        )

        return MessagePreferences(
            notificationPreferences: response.preferences,
            blockNonContacts: response.blockNonContacts,
            enterToSend: response.enterToSend
        )
    }

    public struct UserPreferenceUpdate: Sendable, Equatable {
        public let type: String
        public let value: String?

        public init(type: String, value: String?) {
            self.type = type
            self.value = value
        }
    }

    public func updateUserPreferences(
        _ preferences: [UserPreferenceUpdate],
        disableNotifications: Bool? = nil,
        userID preferredUserID: Int? = nil
    ) async throws {
        let userID = try await resolveUserID(preferredUserID)

        _ = try await sendRequest(
            wsFunction: "core_user_update_user_preferences",
            method: .post,
            parameters: updateUserPreferencesParameters(
                preferences,
                disableNotifications: disableNotifications,
                userID: userID
            ),
            responseType: IgnoredResponse.self
        )
    }

    public func fetchUserPreferences(name: String? = nil) async throws -> [UserPreference] {
        var parameters: [URLQueryItem] = []
        if let name {
            parameters.append(URLQueryItem(name: "name", value: name))
        }

        let response = try await sendRequest(
            wsFunction: "core_user_get_user_preferences",
            method: .post,
            parameters: parameters,
            responseType: UserPreferencesResponse.self
        )

        return response.preferences
    }

    public func fetchCalendarExportToken() async throws -> String {
        let response = try await sendRequest(
            wsFunction: "core_calendar_get_calendar_export_token",
            method: .post,
            responseType: CalendarExportTokenResponse.self
        )

        return response.token
    }

    public func makeCalendarSubscription(
        eventPreset: CalendarSubscription.EventPreset = .all,
        timePreset: CalendarSubscription.TimePreset = .recentUpcoming,
        userID preferredUserID: Int? = nil
    ) async throws -> CalendarSubscription {
        let userID = try await resolveUserID(preferredUserID)
        let exportToken = try await fetchCalendarExportToken()

        guard let endpointURL = URL(string: siteURL)?.appending(path: "calendar/export_execute.php"),
            var components = URLComponents(url: endpointURL, resolvingAgainstBaseURL: false)
        else {
            throw LmsWebServiceError.invalidSiteURL
        }

        components.queryItems = [
            URLQueryItem(name: "userid", value: String(userID)),
            URLQueryItem(name: "authtoken", value: exportToken),
            URLQueryItem(name: "preset_what", value: eventPreset.rawValue),
            URLQueryItem(name: "preset_time", value: timePreset.rawValue),
        ]

        guard let url = components.url else {
            throw LmsWebServiceError.invalidSiteURL
        }

        return CalendarSubscription(url: url)
    }

    public func markNotificationRead(notificationID: Int, timeRead: Int = Int(Date().timeIntervalSince1970))
        async throws
    {
        _ = try await sendRequest(
            wsFunction: "core_message_mark_notification_read",
            method: .post,
            parameters: [
                URLQueryItem(name: "notificationid", value: String(notificationID)),
                URLQueryItem(name: "timeread", value: String(timeRead)),
            ],
            responseType: IgnoredResponse.self
        )
    }

    public func markAllNotificationsRead(
        userIDTo preferredUserIDTo: Int? = nil,
        userIDFrom: Int? = nil,
        timeCreatedTo: Int? = nil
    ) async throws {
        let userIDTo = try await resolveUserID(preferredUserIDTo)
        var parameters = [
            URLQueryItem(name: "useridto", value: String(userIDTo))
        ]
        if let userIDFrom {
            parameters.append(URLQueryItem(name: "useridfrom", value: String(userIDFrom)))
        }
        if let timeCreatedTo {
            parameters.append(URLQueryItem(name: "timecreatedto", value: String(timeCreatedTo)))
        }

        _ = try await sendRequest(
            wsFunction: "core_message_mark_all_notifications_as_read",
            method: .post,
            parameters: parameters,
            responseType: IgnoredResponse.self
        )
    }

    private func resolveUserID(_ preferredUserID: Int?) async throws -> Int {
        if let preferredUserID {
            return preferredUserID
        }

        if let sessionUserID {
            return sessionUserID
        }

        return try await fetchSiteInfo().userID
    }

    public func fetchTimetableSnapshot(userID preferredUserID: Int? = nil) async throws -> DashboardSnapshot {
        #if DEBUG
        let profiler = LmsWebServiceProfiler(label: "fetchTimetableSnapshot")
        #endif

        let knownUserID = preferredUserID ?? sessionUserID
        let resolvedUserID: Int
        if let knownUserID {
            resolvedUserID = knownUserID
            #if DEBUG
            profiler.mark("site_info skipped userID=\(resolvedUserID)")
            #endif
        } else {
            #if DEBUG
            profiler.mark("site_info start")
            #endif

            let siteInfo = try await fetchSiteInfo()
            resolvedUserID = siteInfo.userID

            #if DEBUG
            profiler.mark("site_info finished userID=\(siteInfo.userID)")
            #endif
        }

        #if DEBUG
        profiler.mark("enrolled_courses start")
        profiler.mark("dashboard_blocks start")
        #endif

        async let coursesTask = fetchEnrolledCourses(userID: resolvedUserID)
        async let dashboardBlocksTask = fetchDashboardBlocks(returnContents: true)

        let courses = try await coursesTask

        #if DEBUG
        profiler.mark("enrolled_courses finished courses=\(courses.count)")
        #endif

        let dashboardBlocks = (try? await dashboardBlocksTask) ?? []

        #if DEBUG
        profiler.mark("dashboard_blocks finished blocks=\(dashboardBlocks.count)")
        profiler.finish("success")
        #endif

        return DashboardSnapshot(
            siteURL: siteURL,
            userID: resolvedUserID,
            courses: courses,
            dashboardBlocks: dashboardBlocks
        )
    }

    private func fetchEnrolledCourses(userID: Int) async throws -> [Course] {
        try await sendRequest(
            wsFunction: "core_enrol_get_users_courses",
            method: .post,
            parameters: [
                URLQueryItem(name: "userid", value: String(userID)),
                URLQueryItem(name: "returnusercount", value: "0"),
            ],
            responseType: [Course].self
        )
    }

    private func sendRequest<Response: Decodable>(
        wsFunction: String,
        method: HTTPMethod,
        parameters: [URLQueryItem] = [],
        responseType: Response.Type
    ) async throws -> Response {
        let request: URLRequest

        do {
            request = try makeRequest(
                wsFunction: wsFunction,
                method: method,
                parameters: parameters
            )
        } catch {
            await recordLog(
                wsFunction: wsFunction, parameters: parameters, response: nil, data: nil, error: error)
            throw error
        }

        return try await send(
            request: request,
            wsFunction: wsFunction,
            parameters: parameters,
            responseType: responseType
        )
    }

    private func send<Response: Decodable>(
        request: URLRequest,
        wsFunction: String,
        parameters: [URLQueryItem],
        responseType: Response.Type
    ) async throws -> Response {
        let data: Data
        let response: URLResponse

        #if DEBUG
        let profiler = LmsWebServiceProfiler(label: wsFunction)
        profiler.mark("urlSession.data start")
        #endif

        do {
            (data, response) = try await urlSession.data(for: request)
            #if DEBUG
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            profiler.mark("urlSession.data finished status=\(statusCode) bytes=\(data.count)")
            #endif
        } catch {
            #if DEBUG
            profiler.mark("urlSession.data failed")
            #endif
            await recordLog(
                wsFunction: wsFunction, parameters: parameters, response: nil, data: nil, error: error)
            #if DEBUG
            profiler.finish("logged transport error")
            #endif
            throw error
        }

        do {
            let decodedResponse = try decodeResponse(
                data: data,
                response: response,
                responseType: responseType
            )
            #if DEBUG
            profiler.mark("decode finished")
            #endif

            await recordLog(
                wsFunction: wsFunction,
                parameters: parameters,
                response: response as? HTTPURLResponse,
                data: data,
                error: nil
            )
            #if DEBUG
            profiler.mark("request log saved")
            profiler.finish("success")
            #endif
            return decodedResponse
        } catch {
            #if DEBUG
            profiler.mark("decode failed")
            #endif
            await recordLog(
                wsFunction: wsFunction,
                parameters: parameters,
                response: response as? HTTPURLResponse,
                data: data,
                error: error
            )
            #if DEBUG
            profiler.finish("logged decode error")
            #endif
            throw error
        }
    }

    private func recordLog(
        wsFunction: String,
        parameters: [URLQueryItem],
        response: HTTPURLResponse?,
        data: Data?,
        error: Error?
    ) async {
        guard let requestLogger, let logContext else {
            return
        }

        await requestLogger.record(
            context: logContext,
            wsFunction: wsFunction,
            parameters: parameters,
            response: response,
            data: data,
            error: error
        )
    }

    private func makeRequest(
        wsFunction: String,
        method: HTTPMethod,
        parameters: [URLQueryItem]
    ) throws -> URLRequest {
        guard let endpointURL = URL(string: siteURL)?.appending(path: "webservice/rest/server.php")
        else {
            throw LmsWebServiceError.invalidSiteURL
        }

        let authParameters = [
            URLQueryItem(name: "wstoken", value: token),
            URLQueryItem(name: "wsfunction", value: wsFunction),
            URLQueryItem(name: "moodlewsrestformat", value: "json"),
        ]

        switch method {
        case .get:
            guard var components = URLComponents(url: endpointURL, resolvingAgainstBaseURL: false) else {
                throw LmsWebServiceError.invalidSiteURL
            }
            components.queryItems = authParameters + parameters

            guard let url = components.url else {
                throw LmsWebServiceError.invalidSiteURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = method.rawValue
            return request
        case .post:
            var request = URLRequest(url: endpointURL)
            request.httpMethod = method.rawValue
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

            var components = URLComponents()
            components.queryItems = authParameters + parameters
            request.httpBody = components.percentEncodedQuery?.data(using: .utf8)
            return request
        }
    }

    private func makeAssignmentFileUploadRequest(
        files: [AssignmentSubmissionUploadFile],
        draftItemID: Int?
    ) throws -> URLRequest {
        guard let endpointURL = URL(string: siteURL)?.appending(path: "webservice/upload.php")
        else {
            throw LmsWebServiceError.invalidSiteURL
        }

        let boundary = "MoodleNativeBoundary-\(UUID().uuidString)"
        var body = Data()
        body.appendMultipartField(name: "token", value: token, boundary: boundary)
        body.appendMultipartField(name: "filearea", value: "draft", boundary: boundary)
        body.appendMultipartField(name: "itemid", value: String(draftItemID ?? 0), boundary: boundary)
        body.appendMultipartField(name: "filepath", value: "/", boundary: boundary)

        for (index, file) in files.enumerated() {
            body.appendMultipartFile(
                name: "file_\(index + 1)",
                fileName: file.fileName,
                mimeType: file.mimeType,
                data: file.data,
                boundary: boundary
            )
        }

        body.appendUTF8("--\(boundary)--\r\n")

        var request = URLRequest(url: endpointURL)
        request.httpMethod = HTTPMethod.post.rawValue
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        return request
    }

    private func decodeResponse<Response: Decodable>(
        data: Data,
        response: URLResponse,
        responseType: Response.Type
    ) throws -> Response {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LmsWebServiceError.invalidResponse
        }

        let responseText = String(data: data, encoding: .utf8) ?? ""
        guard 200..<300 ~= httpResponse.statusCode else {
            throw LmsWebServiceError.http(statusCode: httpResponse.statusCode, response: responseText)
        }

        if let moodleError = try? JSONDecoder().decode(MoodleErrorResponse.self, from: data),
            moodleError.isError
        {
            throw LmsWebServiceError.moodle(
                message: moodleError.message ?? moodleError.errorCode ?? moodleError.exception
                    ?? "Unknown Moodle error",
                debugInfo: moodleError.debugInfo
            )
        }

        do {
            return try JSONDecoder().decode(responseType, from: data)
        } catch {
            throw LmsWebServiceError.decoding(error)
        }
    }

    private func indexedParameters(name: String, values: [Int]) -> [URLQueryItem] {
        values.enumerated().map { index, value in
            URLQueryItem(name: "\(name)[\(index)]", value: String(value))
        }
    }

    private func favouriteCourseParameters(_ courses: [FavouriteCourseUpdate]) -> [URLQueryItem] {
        courses.enumerated().flatMap { index, course in
            [
                URLQueryItem(name: "courses[\(index)][id]", value: String(course.id)),
                URLQueryItem(
                    name: "courses[\(index)][favourite]",
                    value: course.isFavorite ? "1" : "0"
                ),
            ]
        }
    }

    private func updateUserPreferencesParameters(
        _ preferences: [UserPreferenceUpdate],
        disableNotifications: Bool?,
        userID: Int
    ) -> [URLQueryItem] {
        var parameters = [
            URLQueryItem(name: "userid", value: String(userID))
        ]

        if let disableNotifications {
            parameters.append(
                URLQueryItem(name: "emailstop", value: disableNotifications ? "1" : "0")
            )
        }

        parameters.append(
            contentsOf: preferences.enumerated().flatMap { index, preference in
                var items = [
                    URLQueryItem(name: "preferences[\(index)][type]", value: preference.type)
                ]

                if let value = preference.value {
                    items.append(
                        URLQueryItem(name: "preferences[\(index)][value]", value: value)
                    )
                }

                return items
            }
        )

        return parameters
    }

    private func fetchFallbackNotificationPreferences() async throws -> NotificationPreferences {
        let userID = try await resolveUserID(nil)
        let savedPreferences = Dictionary(
            uniqueKeysWithValues: (try await fetchUserPreferences()).compactMap { preference in
                preference.value.map { (preference.name, $0) }
            }
        )
        let processors = fallbackNotificationProcessors()

        return NotificationPreferences(
            userID: userID,
            disableAll: false,
            processors: processors,
            components: fallbackNotificationComponents(
                processors: processors,
                savedPreferences: savedPreferences
            )
        )
    }

    private func isInvalidNotificationPreferencesResponse(_ error: Error) -> Bool {
        guard case LmsWebServiceError.moodle(let message, let debugInfo) = error else {
            return false
        }

        return debugInfo == "invalidresponse" || message.contains("無効なレスポンス値")
    }

    private func fallbackNotificationProcessors() -> [NotificationPreferencesProcessor] {
        [
            NotificationPreferencesProcessor(
                displayName: "ウェブ",
                name: "popup",
                hasSettings: true,
                contextID: nil,
                userConfigured: true
            ),
            NotificationPreferencesProcessor(
                displayName: "メール",
                name: "email",
                hasSettings: true,
                contextID: nil,
                userConfigured: true
            ),
            NotificationPreferencesProcessor(
                displayName: "モバイル",
                name: "airnotifier",
                hasSettings: true,
                contextID: nil,
                userConfigured: true
            ),
        ]
    }

    private func fallbackNotificationComponents(
        processors: [NotificationPreferencesProcessor],
        savedPreferences: [String: String]
    ) -> [NotificationPreferencesComponent] {
        let definitions: [(component: String, description: String?, notifications: [(String, String)])] = [
            (
                "課題",
                nil,
                [
                    ("課題通知", "message_provider_mod_assign_assign_notification"),
                    ("課題の提出期限到来通知", "message_provider_mod_assign_assign_due_soon"),
                    ("課題期限超過通知", "message_provider_mod_assign_assign_overdue"),
                    ("課題提出期限7日以内通知", "message_provider_mod_assign_assign_due_digest"),
                ]
            ),
            (
                "フォーラム",
                nil,
                [
                    ("購読済みフォーラム投稿", "message_provider_mod_forum_posts"),
                    ("購読済みフォーラムダイジェスト", "message_provider_mod_forum_digests"),
                ]
            ),
            (
                "アンケート",
                nil,
                [
                    ("アンケートリマインダ", "message_provider_mod_questionnaire_message"),
                    ("アンケート提出", "message_provider_mod_questionnaire_notification"),
                ]
            ),
            (
                "小テスト",
                nil,
                [
                    ("小テスト公開予定", "message_provider_mod_quiz_quiz_open_soon")
                ]
            ),
            (
                "システム",
                nil,
                [
                    ("コースコンテンツ変更", "message_provider_moodle_coursecontentupdated"),
                    ("評定通知", "message_provider_moodle_gradenotifications"),
                    ("カスタムレポートビルダスケジュール", "message_provider_moodle_reportbuilderschedule"),
                ]
            ),
            (
                "私の先生にメッセージ",
                "授業コード、授業名（曜日時限）、学生証番号を明記して送信すること",
                [
                    ("「私の教師にメッセージ」ブロックで送信されたメッセージ", "message_provider_block_messageteacher_message")
                ]
            ),
            (
                "イベントリマインダ",
                nil,
                [
                    ("ユーザイベントのリマインダ通知", "message_provider_local_reminders_reminders_user"),
                    ("コースイベントのリマインダ通知", "message_provider_local_reminders_reminders_course"),
                    ("活動イベントのリマインダ通知", "message_provider_local_reminders_reminders_due"),
                ]
            ),
        ]

        return definitions.map { component in
            NotificationPreferencesComponent(
                displayName: component.component,
                description: component.description,
                notifications: component.notifications.map { notification in
                    NotificationPreference(
                        displayName: notification.0,
                        preferenceKey: notification.1,
                        processors: processors.map { processor in
                            let enabled = isProcessorEnabled(
                                processor.name,
                                preferenceKey: notification.1,
                                savedPreferences: savedPreferences
                            )
                            return NotificationPreferenceProcessor(
                                displayName: processor.displayName,
                                name: processor.name,
                                locked: false,
                                lockedMessage: nil,
                                userConfigured: true,
                                enabled: enabled,
                                loggedIn: nil,
                                loggedOff: nil
                            )
                        }
                    )
                }
            )
        }
    }

    private func isProcessorEnabled(
        _ processorName: String,
        preferenceKey: String,
        savedPreferences: [String: String]
    ) -> Bool {
        guard let value = savedPreferences["\(preferenceKey)_\(processorName)"] else {
            return true
        }

        return value != "0" && value.lowercased() != "false" && value != "none"
    }

    private func throwFirstAssignmentWarning(in warnings: [AssignmentWarning]) throws {
        guard let warning = warnings.first else {
            return
        }

        throw LmsWebServiceError.moodle(
            message: warning.message ?? "提出操作を完了できませんでした。",
            debugInfo: warning.warningCode
        )
    }

    private func authorize(_ module: CourseModule) -> CourseModule {
        var module = module
        module.url = authorizedURLString(module.url)
        module.contents = module.contents.map(authorize)
        return module
    }

    private func authorize(_ content: ModuleContent) -> ModuleContent {
        var content = content
        content.fileURL = authorizedURLString(content.fileURL)
        return content
    }

    private func authorize(_ assignmentStatus: AssignmentSubmissionStatus)
        -> AssignmentSubmissionStatus
    {
        var assignmentStatus = assignmentStatus
        assignmentStatus.lastAttempt = assignmentStatus.lastAttempt.map(authorize)
        assignmentStatus.feedback = assignmentStatus.feedback.map(authorize)
        assignmentStatus.previousAttempts = assignmentStatus.previousAttempts.map(authorize)
        assignmentStatus.assignmentData = assignmentStatus.assignmentData.map(authorize)
        return assignmentStatus
    }

    private func authorize(_ lastAttempt: AssignmentLastAttempt) -> AssignmentLastAttempt {
        var lastAttempt = lastAttempt
        lastAttempt.submission = lastAttempt.submission.map(authorize)
        lastAttempt.teamSubmission = lastAttempt.teamSubmission.map(authorize)
        return lastAttempt
    }

    private func authorize(_ submission: AssignmentSubmission) -> AssignmentSubmission {
        var submission = submission
        submission.plugins = submission.plugins.map(authorize)
        return submission
    }

    private func authorize(_ plugin: AssignmentPlugin) -> AssignmentPlugin {
        var plugin = plugin
        plugin.fileAreas = plugin.fileAreas.map(authorize)
        return plugin
    }

    private func authorize(_ fileArea: AssignmentPluginFileArea) -> AssignmentPluginFileArea {
        var fileArea = fileArea
        fileArea.files = fileArea.files.map(authorize)
        return fileArea
    }

    private func authorize(_ feedback: AssignmentFeedback) -> AssignmentFeedback {
        var feedback = feedback
        feedback.plugins = feedback.plugins.map(authorize)
        return feedback
    }

    private func authorize(_ previousAttempt: AssignmentPreviousAttempt) -> AssignmentPreviousAttempt {
        var previousAttempt = previousAttempt
        previousAttempt.submission = previousAttempt.submission.map(authorize)
        previousAttempt.feedbackPlugins = previousAttempt.feedbackPlugins.map(authorize)
        return previousAttempt
    }

    private func authorize(_ assignmentData: AssignmentData) -> AssignmentData {
        var assignmentData = assignmentData
        assignmentData.attachments = assignmentData.attachments.map(authorize)
        return assignmentData
    }

    private func authorize(_ attachments: AssignmentDataAttachments) -> AssignmentDataAttachments {
        var attachments = attachments
        attachments.intro = attachments.intro.map(authorize)
        attachments.activity = attachments.activity.map(authorize)
        return attachments
    }

    private func authorize(_ file: AssignmentFile) -> AssignmentFile {
        var file = file
        file.fileURL = authorizedURLString(file.fileURL)
        return file
    }

    private func authorize(_ post: ForumPost) -> ForumPost {
        var post = post
        post.attachments = post.attachments.map(authorize)
        return post
    }

    private func authorize(_ attachment: ForumPostAttachment) -> ForumPostAttachment {
        var attachment = attachment
        attachment.fileURL = authorizedURLString(attachment.fileURL)
        return attachment
    }

    private func authorizedURLString(_ value: String?) -> String? {
        guard let value, value.isEmpty == false else {
            return value
        }

        guard value.contains("token=") == false else {
            return value
        }

        let separator = value.contains("?") ? "&" : "?"
        guard let encodedToken = token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else {
            return value
        }

        return "\(value)\(separator)token=\(encodedToken)"
    }
}

#if DEBUG
private final class LmsWebServiceProfiler {
    private let label: String
    private let startedAt: CFAbsoluteTime
    private var lastMarkedAt: CFAbsoluteTime

    init(label: String) {
        self.label = label
        let now = CFAbsoluteTimeGetCurrent()
        startedAt = now
        lastMarkedAt = now
        log("\(label) started")
    }

    func mark(_ name: String) {
        let now = CFAbsoluteTimeGetCurrent()
        log(
            "\(label) \(name): +\(Self.milliseconds(now - lastMarkedAt))ms total=\(Self.milliseconds(now - startedAt))ms"
        )
        lastMarkedAt = now
    }

    func finish(_ name: String) {
        let now = CFAbsoluteTimeGetCurrent()
        log("\(label) \(name): total=\(Self.milliseconds(now - startedAt))ms")
    }

    private func log(_ message: String) {
        print("[LmsWebServicePerformance] \(message)")
    }

    private static func milliseconds(_ seconds: CFTimeInterval) -> Int {
        Int((seconds * 1000).rounded())
    }
}
#endif

private extension Data {
    mutating func appendMultipartField(name: String, value: String, boundary: String) {
        appendUTF8("--\(boundary)\r\n")
        appendUTF8("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        appendUTF8("\(value)\r\n")
    }

    mutating func appendMultipartFile(
        name: String,
        fileName: String,
        mimeType: String,
        data: Data,
        boundary: String
    ) {
        let sanitizedFileName =
            fileName
            .replacingOccurrences(of: "\"", with: "_")
            .replacingOccurrences(of: "\r", with: "_")
            .replacingOccurrences(of: "\n", with: "_")

        appendUTF8("--\(boundary)\r\n")
        appendUTF8(
            "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(sanitizedFileName)\"\r\n"
        )
        appendUTF8("Content-Type: \(mimeType)\r\n\r\n")
        append(data)
        appendUTF8("\r\n")
    }

    mutating func appendUTF8(_ string: String) {
        append(Data(string.utf8))
    }
}

extension LmsWebServiceClient {
    private struct FavouriteCoursesResponse: Decodable, Sendable {
        let warnings: [Warning]

        struct Warning: Decodable, Sendable {
            let message: String
            let warningCode: String?

            private enum CodingKeys: String, CodingKey {
                case message
                case warningCode = "warningcode"
            }
        }
    }
}
