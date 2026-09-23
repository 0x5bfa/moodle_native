import Foundation
import MoodleNativeCore
import MoodleNativeNetworking
import Testing

@testable import MoodleNativeNetworking

@Suite(.serialized)
@MainActor
struct LmsWebServiceClientTests {
    @Test func decodeCourseModuleWithoutOptionalArrays() throws {
        let data = Data(
            """
            {
              "id": 42,
              "instance": 314,
              "modname": "forum",
              "name": "Announcements",
              "url": "https://lms.example.test/mod/forum/view.php?id=42"
            }
            """.utf8
        )

        let module = try JSONDecoder().decode(LmsWebServiceClient.CourseModule.self, from: data)

        #expect(module.id == 42)
        #expect(module.instanceID == 314)
        #expect(module.modName == "forum")
        #expect(module.contents.isEmpty)
        #expect(module.dates.isEmpty)
    }

    @Test func decodeCourseModuleCompletionData() throws {
        let data = Data(
            """
            {
              "id": 43,
              "instance": 315,
              "modname": "assign",
              "name": "第1回課題",
              "url": "https://lms.example.test/mod/assign/view.php?id=43",
              "completion": 2,
              "completiondata": {
                "state": 0,
                "hascompletion": true,
                "uservisible": true,
                "details": [
                  {
                    "rulename": "completionview",
                    "rulevalue": {
                      "status": 1,
                      "description": "閲覧する"
                    }
                  },
                  {
                    "rulename": "completionsubmit",
                    "rulevalue": {
                      "status": 0,
                      "description": "提出する"
                    }
                  }
                ],
                "isoverallcomplete": false
              }
            }
            """.utf8
        )

        let module = try JSONDecoder().decode(LmsWebServiceClient.CourseModule.self, from: data)

        #expect(module.completion == 2)

        let completionData = try #require(module.completionData)
        #expect(completionData.state == 0)
        #expect(completionData.hasCompletion)
        #expect(completionData.userVisible)
        #expect(completionData.details.count == 2)
        #expect(completionData.details[0].ruleName == "completionview")
        #expect(completionData.details[0].ruleValue?.status == 1)
        #expect(completionData.details[1].ruleName == "completionsubmit")
        #expect(completionData.details[1].ruleValue?.status == 0)
        #expect(completionData.isOverallComplete == false)
        #expect(completionData.summary?.progress == 0.5)
        #expect(completionData.summary?.isComplete == false)
        #expect(completionData.requirements.map(\.text) == ["閲覧する", "提出する"])
        #expect(completionData.requirements.map(\.isComplete) == [true, false])
    }

    @Test func emptyCourseIDsReturnEmptyCollections() async throws {
        let session = LmsAuthenticationSession(
            siteURL: "https://lms.example.test",
            token: "ws-token-123",
            privateToken: nil,
            rawCallbackURL: "moodleapp://example?token=ws-token-123",
            authenticatedAt: Date(timeIntervalSince1970: 1_744_506_000),
            userID: 99
        )
        let client = LmsWebServiceClient(session: session)

        let assignments = try await client.fetchAssignments(courseIDs: [])

        #expect(assignments.isEmpty)
    }

    @Test func fetchAssignmentsWithoutCourseIDsOmitsCourseIDParameters() async throws {
        let session = LmsAuthenticationSession(
            siteURL: "https://lms.example.test",
            token: "ws-token-123",
            privateToken: nil,
            rawCallbackURL: "moodleapp://example?token=ws-token-123",
            authenticatedAt: Date(timeIntervalSince1970: 1_744_506_000)
        )

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let urlSession = URLSession(configuration: configuration)

        MockURLProtocol.requestHandler = { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.path == "/webservice/rest/server.php")

            let bodyData = try #require(requestBodyData(for: request))
            let body = try #require(String(data: bodyData, encoding: .utf8))

            var components = URLComponents()
            components.percentEncodedQuery = body
            let queryItems = try #require(components.queryItems)
            let parameters: [String: String] = queryItems.reduce(into: [:]) { result, item in
                if let value = item.value {
                    result[item.name] = value
                }
            }

            #expect(parameters["wstoken"] == "ws-token-123")
            #expect(parameters["wsfunction"] == "mod_assign_get_assignments")
            #expect(parameters["moodlewsrestformat"] == "json")
            #expect(parameters.keys.contains { $0.hasPrefix("courseids[") } == false)

            let url = try #require(request.url)
            let response = try #require(
                HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )
            )
            let data = Data(
                """
                {
                  "courses": [
                    {
                      "id": 42,
                      "fullname": "Software Engineering",
                      "shortname": "2026-50001",
                      "assignments": []
                    }
                  ],
                  "warnings": []
                }
                """.utf8
            )

            return (response, data)
        }
        defer {
            MockURLProtocol.requestHandler = nil
            urlSession.invalidateAndCancel()
        }

        let client = LmsWebServiceClient(session: session, urlSession: urlSession)
        let assignments = try await client.fetchAssignments()

        #expect(assignments.count == 1)
        #expect(assignments[0].id == 42)
    }

    @Test func decodeAssignmentSubmissionConfigurationAndEnabledPlugins() throws {
        let data = Data(
            """
            {
              "id": 27625,
              "cmid": 177,
              "course": 42,
              "name": "提出課題",
              "submissiondrafts": 1,
              "requiresubmissionstatement": 1,
              "submissionstatement": "<p>自分の成果物です。</p>",
              "timelimit": 3600,
              "configs": [
                {"plugin": "file", "subtype": "assignsubmission", "name": "enabled", "value": "1"},
                {"plugin": "onlinetext", "subtype": "assignsubmission", "name": "enabled", "value": "1"},
                {"plugin": "onlinetext", "subtype": "assignsubmission", "name": "wordlimitenabled", "value": "1"},
                {"plugin": "onlinetext", "subtype": "assignsubmission", "name": "wordlimit", "value": "500"},
                {"plugin": "comments", "subtype": "assignsubmission", "name": "enabled", "value": "1"}
              ]
            }
            """.utf8
        )

        let assignment = try JSONDecoder().decode(LmsWebServiceClient.Assignment.self, from: data)

        #expect(assignment.submissionDrafts == true)
        #expect(assignment.requiresSubmissionStatement == true)
        #expect(assignment.submissionStatement == "<p>自分の成果物です。</p>")
        #expect(assignment.timeLimit == 3600)
        #expect(assignment.enabledSubmissionPluginTypes == ["file", "onlinetext", "comments"])
        #expect(assignment.onlineTextWordLimit == 500)
    }

    @Test func decodeForumDiscussionsResponse() throws {
        let data = Data(
            """
            {
                "discussions": [
                  {
                    "id": 60937,
                    "discussion": 28473,
                    "name": "【重要】組込み実験の「+R授業」と準備作業について",
                    "subject": "【重要】組込み実験の「+R授業」と準備作業について",
                    "message": "<p>本文です</p>",
                    "userfullname": "山本 寛",
                    "numreplies": 0,
                    "numunread": 2,
                    "pinned": true,
                    "locked": false,
                    "modified": 1775200576,
                    "canreply": true
                  }
                ]
              }
            """.utf8
        )

        let response = try JSONDecoder().decode(
            LmsWebServiceClient.ForumDiscussionsResponse.self,
            from: data
        )

        #expect(response.discussions.count == 1)
        #expect(response.discussions[0].id == 28473)
        #expect(response.discussions[0].rootPostID == 60937)
        #expect(response.discussions[0].name == "【重要】組込み実験の「+R授業」と準備作業について")
        #expect(response.discussions[0].numberOfUnreadPosts == 2)
    }

    @Test func decodeDiscussionPostsResponse() throws {
        let data = Data(
            """
            {
              "posts": [
                {
                  "id": 60937,
                  "discussionid": 28473,
                  "subject": "【重要】組込み実験の「+R授業」と準備作業について",
                  "replysubject": "Re: 【重要】組込み実験の「+R授業」と準備作業について",
                  "message": "<p>本文です</p>",
                  "timecreated": 1775200576,
                  "timemodified": 1775200576,
                  "unread": true,
                  "hasparent": false,
                  "parentid": 0,
                  "isdeleted": false,
                  "isprivatereply": false,
                  "author": {
                    "id": 43583,
                    "fullname": "山本 寛",
                    "isdeleted": false,
                    "urls": {
                      "profile": "https://lms.example.test/user/view.php?id=43583&course=36056",
                      "profileimage": "https://lms.example.test/theme/image.php/test/core/u/f1"
                    }
                  },
                  "urls": {
                    "view": "https://lms.example.test/mod/forum/discuss.php?d=28473#p60937",
                    "viewisolated": "https://lms.example.test/mod/forum/discuss.php?d=28473&parent=60937",
                    "discuss": "https://lms.example.test/mod/forum/discuss.php?d=28473"
                  },
                  "attachments": [
                    {
                      "filename": "guide.pdf",
                      "fileurl": "https://lms.example.test/pluginfile.php/1/mod_forum/post/guide.pdf",
                      "mimetype": "application/pdf"
                    }
                  ]
                }
              ]
            }
            """.utf8
        )

        let response = try JSONDecoder().decode(
            LmsWebServiceClient.DiscussionPostsResponse.self,
            from: data
        )

        #expect(response.posts.count == 1)
        #expect(response.posts[0].discussionID == 28473)
        #expect(response.posts[0].author.fullName == "山本 寛")
        #expect(response.posts[0].attachments[0].fileName == "guide.pdf")
        #expect(
            URL(string: response.posts[0].urls.discuss ?? "")?.absoluteString
                == "https://lms.example.test/mod/forum/discuss.php?d=28473")
    }

    @Test func decodeAssignmentSubmissionStatusResponse() throws {
        let data = Data(
            """
            {
              "lastattempt": {
                "submission": {
                  "id": 501,
                  "userid": 99,
                  "attemptnumber": 1,
                  "timecreated": 1775600000,
                  "timemodified": 1775600300,
                  "status": "submitted",
                  "groupid": 0,
                  "plugins": [
                    {
                      "type": "file",
                      "name": "File submissions",
                      "fileareas": [
                        {
                          "area": "submission_files",
                          "files": [
                            {
                              "filename": "report.pdf",
                              "filepath": "/",
                              "filesize": 2048,
                              "fileurl": "https://lms.example.test/pluginfile.php/10/report.pdf",
                              "mimetype": "application/pdf",
                              "timemodified": 1775600300
                            }
                          ]
                        }
                      ],
                      "editorfields": [
                        {
                          "name": "onlinetext_editor",
                          "description": "Online text",
                          "text": "<p>提出本文</p>",
                          "format": 1
                        }
                      ]
                    }
                  ],
                  "gradingstatus": "notgraded"
                },
                "submissionsenabled": true,
                "locked": false,
                "graded": false,
                "canedit": false,
                "caneditowner": false,
                "cansubmit": false,
                "extensionduedate": 0,
                "blindmarking": false,
                "gradingstatus": "notgraded",
                "usergroups": [8]
              },
              "feedback": {
                "grade": {
                  "id": 22,
                  "userid": 99,
                  "attemptnumber": 1,
                  "timecreated": 1775600400,
                  "timemodified": 1775600500,
                  "grader": 7,
                  "grade": "80.00000",
                  "gradefordisplay": "80 / 100"
                },
                "gradefordisplay": "80 / 100",
                "gradeddate": 1775600500,
                "plugins": [
                  {
                    "type": "comments",
                    "name": "Feedback comments",
                    "editorfields": [
                      {
                        "name": "comment_editor",
                        "description": "コメント",
                        "text": "<p>よくできています</p>",
                        "format": 1
                      }
                    ]
                  }
                ]
              },
              "previousattempts": [
                {
                  "attemptnumber": 0,
                  "submission": {
                    "id": 401,
                    "userid": 99,
                    "attemptnumber": 0,
                    "timecreated": 1775500000,
                    "timemodified": 1775500300,
                    "status": "draft",
                    "groupid": 0,
                    "plugins": [],
                    "gradingstatus": "notgraded"
                  },
                  "feedbackplugins": []
                }
              ],
              "assignmentdata": {
                "attachments": {
                  "activity": [
                    {
                      "filename": "requirements.pdf",
                      "filepath": "/",
                      "filesize": 4096,
                      "fileurl": "https://lms.example.test/pluginfile.php/20/requirements.pdf",
                      "mimetype": "application/pdf",
                      "timemodified": 1775600200
                    }
                  ]
                },
                "activity": "<p>レポートを提出してください。</p>",
                "activityformat": 1
              },
              "warnings": []
            }
            """.utf8
        )

        let response = try JSONDecoder().decode(
            LmsWebServiceClient.AssignmentSubmissionStatus.self,
            from: data
        )

        #expect(response.lastAttempt?.submission?.status == "submitted")
        #expect(
            response.lastAttempt?.submission?.plugins.first?.fileAreas.first?.files.first?.fileName
                == "report.pdf")
        #expect(
            response.lastAttempt?.submission?.plugins.first?.editorFields.first?.text
                == "<p>提出本文</p>")
        #expect(response.feedback?.gradeForDisplay == "80 / 100")
        #expect(
            response.feedback?.plugins.first?.editorFields.first?.text
                == "<p>よくできています</p>")
        #expect(response.assignmentData?.activity == "<p>レポートを提出してください。</p>")
        #expect(response.previousAttempts.count == 1)
    }

    @Test func decodeAssignmentSubmissionStatusWithEmptyAssignmentDataArray() throws {
        let data = Data(
            """
            {
              "lastattempt": {
                "submission": {
                  "id": 830437,
                  "userid": 67797,
                  "attemptnumber": 0,
                  "timecreated": 1778818446,
                  "timemodified": 1778865614,
                  "timestarted": null,
                  "status": "submitted",
                  "groupid": 0,
                  "assignment": 27625,
                  "latest": 1,
                  "plugins": [
                    {
                      "type": "file",
                      "name": "ファイル提出",
                      "fileareas": [
                        {
                          "area": "submission_files",
                          "files": [
                            {
                              "filename": "report.pdf",
                              "filepath": "/",
                              "filesize": 478674,
                              "fileurl": "https://lms.example.test/report.pdf",
                              "mimetype": "application/pdf",
                              "timemodified": 1778865614,
                              "isexternalfile": false
                            }
                          ]
                        }
                      ]
                    },
                    {
                      "type": "comments",
                      "name": "提出コメント"
                    }
                  ]
                },
                "submissionsenabled": true,
                "locked": false,
                "graded": false,
                "canedit": false,
                "caneditowner": false,
                "cansubmit": false,
                "extensionduedate": null,
                "timelimit": 0,
                "blindmarking": false,
                "gradingstatus": "notmarked",
                "usergroups": []
              },
              "assignmentdata": [],
              "warnings": []
            }
            """.utf8
        )

        let response = try JSONDecoder().decode(
            LmsWebServiceClient.AssignmentSubmissionStatus.self,
            from: data
        )

        #expect(response.assignmentData == nil)
        #expect(
            response.lastAttempt?.submission?.plugins.first?.fileAreas.first?.files.first?.fileName
                == "report.pdf")
    }

    @Test func decodePopupNotificationsResponse() throws {
        let data = Data(
            """
            {
              "notifications": [
                {
                  "id": 1201,
                  "useridfrom": 2,
                  "useridto": 99,
                  "subject": "課題の締切が近づいています",
                  "shortenedsubject": "課題の締切",
                  "text": "レポート課題 1 の締切は明日です。",
                  "fullmessage": "レポート課題 1 の締切は明日です。",
                  "fullmessageformat": 1,
                  "fullmessagehtml": "<p><strong>レポート課題 1</strong> の締切は明日です。</p>",
                  "smallmessage": "締切は明日です",
                  "contexturl": "https://lms.example.test/mod/assign/view.php?id=123",
                  "contexturlname": "レポート課題 1",
                  "timecreated": 1775700000,
                  "timeread": 0,
                  "read": false,
                  "deleted": false,
                  "iconurl": "https://lms.example.test/theme/image.php/notification",
                  "component": "mod_assign",
                  "eventtype": "submission_due",
                  "customdata": ""
                }
              ],
              "unreadcount": 4
            }
            """.utf8
        )

        let response = try JSONDecoder().decode(
            LmsWebServiceClient.PopupNotificationsResponse.self,
            from: data
        )

        #expect(response.notifications.count == 1)
        #expect(response.notifications[0].subject == "課題の締切が近づいています")
        #expect(response.notifications[0].read == false)
        #expect(response.notifications[0].component == "mod_assign")
        #expect(response.notifications[0].contextURLName == "レポート課題 1")
    }

    @Test func fetchPopupNotificationsSendsRequiredParameters() async throws {
        let session = LmsAuthenticationSession(
            siteURL: "https://lms.example.test",
            token: "ws-token-123",
            privateToken: nil,
            rawCallbackURL: "moodleapp://example?token=ws-token-123",
            authenticatedAt: Date(timeIntervalSince1970: 1_744_506_000)
        )

        let responseData = Data(
            """
            {
              "notifications": [],
              "unreadcount": 0
            }
            """.utf8
        )

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let urlSession = URLSession(configuration: configuration)

        MockURLProtocol.requestHandler = { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.path == "/webservice/rest/server.php")

            let bodyData = try #require(requestBodyData(for: request))
            let body = try #require(String(data: bodyData, encoding: .utf8))

            var components = URLComponents()
            components.percentEncodedQuery = body
            let queryItems = try #require(components.queryItems)
            let parameters: [String: String] = queryItems.reduce(into: [:]) { result, item in
                if let value = item.value {
                    result[item.name] = value
                }
            }

            #expect(parameters["wstoken"] == "ws-token-123")
            #expect(parameters["wsfunction"] == "message_popup_get_popup_notifications")
            #expect(parameters["moodlewsrestformat"] == "json")
            #expect(parameters["useridto"] == "0")
            #expect(parameters["newestfirst"] == "1")
            #expect(parameters["limit"] == "0")
            #expect(parameters["offset"] == "0")

            let url = try #require(request.url)
            let response = try #require(
                HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )
            )
            return (response, responseData)
        }
        defer {
            MockURLProtocol.requestHandler = nil
            urlSession.invalidateAndCancel()
        }

        let client = LmsWebServiceClient(session: session, urlSession: urlSession)
        let response = try await client.fetchPopupNotifications()

        #expect(response.notifications.isEmpty)
    }

    @Test func fetchUnreadNotificationCountSendsRequiredParameters() async throws {
        let session = LmsAuthenticationSession(
            siteURL: "https://lms.example.test",
            token: "ws-token-123",
            privateToken: nil,
            rawCallbackURL: "moodleapp://example?token=ws-token-123",
            authenticatedAt: Date(timeIntervalSince1970: 1_744_506_000),
            userID: 99
        )

        let responseData = Data("7".utf8)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let urlSession = URLSession(configuration: configuration)

        MockURLProtocol.requestHandler = { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.path == "/webservice/rest/server.php")

            let bodyData = try #require(requestBodyData(for: request))
            let body = try #require(String(data: bodyData, encoding: .utf8))

            var components = URLComponents()
            components.percentEncodedQuery = body
            let queryItems = try #require(components.queryItems)
            let parameters: [String: String] = queryItems.reduce(into: [:]) { result, item in
                if let value = item.value {
                    result[item.name] = value
                }
            }

            #expect(parameters["wstoken"] == "ws-token-123")
            #expect(parameters["wsfunction"] == "core_message_get_unread_notification_count")
            #expect(parameters["moodlewsrestformat"] == "json")
            #expect(parameters["useridto"] == "99")

            let url = try #require(request.url)
            let response = try #require(
                HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )
            )
            return (response, responseData)
        }
        defer {
            MockURLProtocol.requestHandler = nil
            urlSession.invalidateAndCancel()
        }

        let client = LmsWebServiceClient(session: session, urlSession: urlSession)
        let unreadCount = try await client.fetchUnreadNotificationCount()

        #expect(unreadCount == 7)
    }

    @Test func markAllNotificationsReadSendsRequiredParameters() async throws {
        let session = LmsAuthenticationSession(
            siteURL: "https://lms.example.test",
            token: "ws-token-123",
            privateToken: nil,
            rawCallbackURL: "moodleapp://example?token=ws-token-123",
            authenticatedAt: Date(timeIntervalSince1970: 1_744_506_000),
            userID: 99
        )

        let responseData = Data("true".utf8)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let urlSession = URLSession(configuration: configuration)

        MockURLProtocol.requestHandler = { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.path == "/webservice/rest/server.php")

            let bodyData = try #require(requestBodyData(for: request))
            let body = try #require(String(data: bodyData, encoding: .utf8))

            var components = URLComponents()
            components.percentEncodedQuery = body
            let queryItems = try #require(components.queryItems)
            let parameters: [String: String] = queryItems.reduce(into: [:]) { result, item in
                if let value = item.value {
                    result[item.name] = value
                }
            }

            #expect(parameters["wstoken"] == "ws-token-123")
            #expect(parameters["wsfunction"] == "core_message_mark_all_notifications_as_read")
            #expect(parameters["moodlewsrestformat"] == "json")
            #expect(parameters["useridto"] == "99")
            #expect(parameters["useridfrom"] == nil)
            #expect(parameters["timecreatedto"] == nil)

            let url = try #require(request.url)
            let response = try #require(
                HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )
            )
            return (response, responseData)
        }
        defer {
            MockURLProtocol.requestHandler = nil
            urlSession.invalidateAndCancel()
        }

        let client = LmsWebServiceClient(session: session, urlSession: urlSession)
        try await client.markAllNotificationsRead()
    }

    @Test func setFavouriteCoursesSendsCourseIDsAndStates() async throws {
        let session = LmsAuthenticationSession(
            siteURL: "https://lms.example.test",
            token: "ws-token-123",
            privateToken: nil,
            rawCallbackURL: "moodleapp://example?token=ws-token-123",
            authenticatedAt: Date(timeIntervalSince1970: 1_744_506_000)
        )

        let responseData = Data(
            """
            {
              "warnings": []
            }
            """.utf8
        )

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let urlSession = URLSession(configuration: configuration)

        MockURLProtocol.requestHandler = { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.path == "/webservice/rest/server.php")

            let bodyData = try #require(requestBodyData(for: request))
            let body = try #require(String(data: bodyData, encoding: .utf8))

            var components = URLComponents()
            components.percentEncodedQuery = body
            let queryItems = try #require(components.queryItems)
            let parameters: [String: String] = queryItems.reduce(into: [:]) { result, item in
                if let value = item.value {
                    result[item.name] = value
                }
            }

            #expect(parameters["wsfunction"] == "core_course_set_favourite_courses")
            #expect(parameters["courses[0][id]"] == "42")
            #expect(parameters["courses[0][favourite]"] == "1")
            #expect(parameters["courses[1][id]"] == "99")
            #expect(parameters["courses[1][favourite]"] == "0")

            let url = try #require(request.url)
            let response = try #require(
                HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )
            )
            return (response, responseData)
        }
        defer {
            MockURLProtocol.requestHandler = nil
            urlSession.invalidateAndCancel()
        }

        let client = LmsWebServiceClient(session: session, urlSession: urlSession)
        try await client.setFavouriteCourses([
            .init(id: 42, isFavorite: true),
            .init(id: 99, isFavorite: false),
        ])
    }

    @Test func fetchNotificationPreferencesOmitsUserIDAndDecodesProcessors() async throws {
        let session = LmsAuthenticationSession(
            siteURL: "https://lms.example.test",
            token: "ws-token-123",
            privateToken: nil,
            rawCallbackURL: "moodleapp://example?token=ws-token-123",
            authenticatedAt: Date(timeIntervalSince1970: 1_744_506_000),
            userID: 123
        )

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let urlSession = URLSession(configuration: configuration)

        MockURLProtocol.requestHandler = { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.path == "/webservice/rest/server.php")

            let parameters = try formParameters(for: request)
            #expect(parameters["wsfunction"] == "core_message_get_user_notification_preferences")
            #expect(parameters["userid"] == nil)

            let url = try #require(request.url)
            let response = try #require(
                HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )
            )
            let data = Data(
                """
                {
                  "preferences": {
                    "userid": 123,
                    "disableall": 0,
                    "processors": [
                      {
                        "displayname": "Mobile",
                        "name": "airnotifier",
                        "hassettings": true,
                        "contextid": 5,
                        "userconfigured": 1
                      }
                    ],
                    "components": [
                      {
                        "displayname": "Assignments",
                        "notifications": [
                          {
                            "displayname": "Assignment notifications",
                            "preferencekey": "message_provider_mod_assign_assign_notification",
                            "processors": [
                              {
                                "displayname": "Mobile",
                                "name": "airnotifier",
                                "locked": false,
                                "userconfigured": 1,
                                "enabled": true,
                                "loggedin": {
                                  "name": "loggedin",
                                  "displayname": "Online",
                                  "checked": true
                                },
                                "loggedoff": {
                                  "name": "loggedoff",
                                  "displayname": "Offline",
                                  "checked": "0"
                                }
                              }
                            ]
                          }
                        ]
                      }
                    ]
                  },
                  "warnings": []
                }
                """.utf8
            )

            return (response, data)
        }
        defer {
            MockURLProtocol.requestHandler = nil
            urlSession.invalidateAndCancel()
        }

        let client = LmsWebServiceClient(session: session, urlSession: urlSession)
        let preferences = try await client.fetchNotificationPreferences()

        #expect(preferences.userID == 123)
        #expect(preferences.enableAll)
        #expect(preferences.processors.first?.name == "airnotifier")
        #expect(preferences.components.first?.notifications.first?.preferenceKey == "message_provider_mod_assign_assign_notification")
        let processor = try #require(preferences.components.first?.notifications.first?.processors.first)
        #expect(processor.enabled == true)
        #expect(processor.loggedIn?.checked == true)
        #expect(processor.loggedOff?.checked == false)
    }

    @Test func fetchMessagePreferencesDecodesPrivacyAndInstantMessageProcessors() async throws {
        let session = LmsAuthenticationSession(
            siteURL: "https://lms.example.test",
            token: "ws-token-123",
            privateToken: nil,
            rawCallbackURL: "moodleapp://example?token=ws-token-123",
            authenticatedAt: Date(timeIntervalSince1970: 1_744_506_000),
            userID: 123
        )

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let urlSession = URLSession(configuration: configuration)

        MockURLProtocol.requestHandler = { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.path == "/webservice/rest/server.php")

            let parameters = try formParameters(for: request)
            #expect(parameters["wsfunction"] == "core_message_get_user_message_preferences")
            #expect(parameters["wstoken"] == "ws-token-123")
            #expect(parameters["moodlewsrestformat"] == "json")

            let url = try #require(request.url)
            let response = try #require(
                HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )
            )

            return (
                response,
                Data(
                    """
                    {
                      "preferences": {
                        "userid": 123,
                        "disableall": 0,
                        "processors": [
                          {
                            "displayname": "メール",
                            "name": "email",
                            "hassettings": true,
                            "contextid": 456,
                            "userconfigured": 1
                          }
                        ],
                        "components": [
                          {
                            "displayname": "システム",
                            "notifications": [
                              {
                                "displayname": "ユーザ間のパーソナルメッセージ",
                                "preferencekey": "message_provider_moodle_instantmessage",
                                "processors": [
                                  {
                                    "displayname": "メール",
                                    "name": "email",
                                    "locked": false,
                                    "userconfigured": 1,
                                    "enabled": true
                                  }
                                ]
                              }
                            ]
                          }
                        ]
                      },
                      "blocknoncontacts": 1,
                      "entertosend": true,
                      "warnings": []
                    }
                    """.utf8
                )
            )
        }
        defer {
            MockURLProtocol.requestHandler = nil
            urlSession.invalidateAndCancel()
        }

        let client = LmsWebServiceClient(session: session, urlSession: urlSession)
        let preferences = try await client.fetchMessagePreferences()

        #expect(preferences.blockNonContacts == 1)
        #expect(preferences.enterToSend == true)
        #expect(preferences.notificationPreferences.userID == 123)
        #expect(preferences.notificationPreferences.components.first?.notifications.first?.preferenceKey == "message_provider_moodle_instantmessage")
        #expect(preferences.notificationPreferences.components.first?.notifications.first?.processors.first?.enabled == true)
    }

    @Test func updateUserPreferencesSendsPreferenceListAndEmailStop() async throws {
        let session = LmsAuthenticationSession(
            siteURL: "https://lms.example.test",
            token: "ws-token-123",
            privateToken: nil,
            rawCallbackURL: "moodleapp://example?token=ws-token-123",
            authenticatedAt: Date(timeIntervalSince1970: 1_744_506_000),
            userID: 123
        )

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let urlSession = URLSession(configuration: configuration)

        MockURLProtocol.requestHandler = { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.path == "/webservice/rest/server.php")

            let parameters = try formParameters(for: request)
            #expect(parameters["wsfunction"] == "core_user_update_user_preferences")
            #expect(parameters["userid"] == "123")
            #expect(parameters["emailstop"] == "0")
            #expect(parameters["preferences[0][type]"] == "message_provider_mod_assign_assign_notification_enabled")
            #expect(parameters["preferences[0][value]"] == "airnotifier,popup")
            #expect(parameters["preferences[1][type]"] == "message_provider_mod_forum_posts_enabled")
            #expect(parameters["preferences[1][value]"] == "none")

            let url = try #require(request.url)
            let response = try #require(
                HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )
            )

            return (response, Data("null".utf8))
        }
        defer {
            MockURLProtocol.requestHandler = nil
            urlSession.invalidateAndCancel()
        }

        let client = LmsWebServiceClient(session: session, urlSession: urlSession)
        try await client.updateUserPreferences(
            [
                .init(
                    type: "message_provider_mod_assign_assign_notification_enabled",
                    value: "airnotifier,popup"
                ),
                .init(type: "message_provider_mod_forum_posts_enabled", value: "none"),
            ],
            disableNotifications: false
        )
    }

    @Test func fetchUserPreferencesDecodesNumericPreferenceValues() async throws {
        let session = LmsAuthenticationSession(
            siteURL: "https://lms.example.test",
            token: "ws-token-123",
            privateToken: nil,
            rawCallbackURL: "moodleapp://example?token=ws-token-123",
            authenticatedAt: Date(timeIntervalSince1970: 1_744_506_000),
            userID: 123
        )

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let urlSession = URLSession(configuration: configuration)

        MockURLProtocol.requestHandler = { request in
            #expect(request.httpMethod == "POST")

            let parameters = try formParameters(for: request)
            #expect(parameters["wsfunction"] == "core_user_get_user_preferences")

            let url = try #require(request.url)
            let response = try #require(
                HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )
            )

            return (
                response,
                Data(
                    """
                    {
                      "preferences": [
                        {
                          "name": "message_provider_mod_assign_assign_notification_enabled",
                          "value": "popup,email,airnotifier"
                        },
                        {
                          "name": "_lastloaded",
                          "value": 1780502575
                        }
                      ],
                      "warnings": []
                    }
                    """.utf8
                )
            )
        }
        defer {
            MockURLProtocol.requestHandler = nil
            urlSession.invalidateAndCancel()
        }

        let client = LmsWebServiceClient(session: session, urlSession: urlSession)
        let preferences = try await client.fetchUserPreferences()

        #expect(preferences.first { $0.name == "_lastloaded" }?.value == "1780502575")
    }

    @Test func makeCalendarSubscriptionBuildsMoodleExportURL() async throws {
        let session = LmsAuthenticationSession(
            siteURL: "https://lms.example.test",
            token: "ws-token-123",
            privateToken: nil,
            rawCallbackURL: "moodleapp://example?token=ws-token-123",
            authenticatedAt: Date(timeIntervalSince1970: 1_744_506_000),
            userID: 123
        )

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let urlSession = URLSession(configuration: configuration)

        MockURLProtocol.requestHandler = { request in
            #expect(request.httpMethod == "POST")

            let parameters = try formParameters(for: request)
            #expect(parameters["wsfunction"] == "core_calendar_get_calendar_export_token")

            let url = try #require(request.url)
            let response = try #require(
                HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )
            )

            return (
                response,
                Data(
                    """
                    {
                      "token": "calendar-export-token",
                      "warnings": []
                    }
                    """.utf8
                )
            )
        }
        defer {
            MockURLProtocol.requestHandler = nil
            urlSession.invalidateAndCancel()
        }

        let client = LmsWebServiceClient(session: session, urlSession: urlSession)
        let subscription = try await client.makeCalendarSubscription()

        let components = try #require(URLComponents(url: subscription.url, resolvingAgainstBaseURL: false))
        let queryItems = try #require(components.queryItems)
        let query = queryItems.reduce(into: [String: String]()) { result, item in
            result[item.name] = item.value
        }

        #expect(subscription.url.scheme == "https")
        #expect(subscription.url.host == "lms.example.test")
        #expect(subscription.url.path == "/calendar/export_execute.php")
        #expect(query["userid"] == "123")
        #expect(query["authtoken"] == "calendar-export-token")
        #expect(query["preset_what"] == "all")
        #expect(query["preset_time"] == "recentupcoming")
        #expect(subscription.webcalURL.scheme == "webcal")
        #expect(subscription.webcalURL.host == "lms.example.test")
    }

    @Test func fetchNotificationPreferencesFallsBackWhenMoodleReturnsInvalidResponse() async throws {
        let session = LmsAuthenticationSession(
            siteURL: "https://lms.example.test",
            token: "ws-token-123",
            privateToken: nil,
            rawCallbackURL: "moodleapp://example?token=ws-token-123",
            authenticatedAt: Date(timeIntervalSince1970: 1_744_506_000)
        )

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let urlSession = URLSession(configuration: configuration)
        nonisolated(unsafe) var wsFunctions: [String] = []

        MockURLProtocol.requestHandler = { request in
            let parameters = try formParameters(for: request)
            let wsFunction = try #require(parameters["wsfunction"])
            wsFunctions.append(wsFunction)

            let url = try #require(request.url)
            let response = try #require(
                HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )
            )

            switch wsFunction {
            case "core_message_get_user_notification_preferences":
                return (
                    response,
                    Data(
                        """
                        {
                          "exception": "core\\\\exception\\\\invalid_response_exception",
                          "errorcode": "invalidresponse",
                          "message": "無効なレスポンス値が検知されました。"
                        }
                        """.utf8
                    )
                )
            case "core_webservice_get_site_info":
                return (
                    response,
                    Data(
                        """
                        {
                          "userid": 123,
                          "username": "student@example.test",
                          "firstname": "Student",
                          "lastname": "Example",
                          "fullname": "Student Example",
                          "sitename": "Moodle",
                          "siteurl": "https://lms.example.test",
                          "functions": []
                        }
                        """.utf8
                    )
                )
            case "core_user_get_user_preferences":
                return (
                    response,
                    Data(
                        """
                        {
                          "preferences": [
                            {
                              "name": "message_provider_mod_assign_assign_notification_popup",
                              "value": "0"
                            },
                            {
                              "name": "message_provider_mod_assign_assign_notification_airnotifier",
                              "value": "1"
                            },
                            {
                              "name": "message_provider_mod_forum_posts_email",
                              "value": "none"
                            }
                          ],
                          "warnings": []
                        }
                        """.utf8
                    )
                )
            default:
                Issue.record("Unexpected wsfunction \(wsFunction)")
                return (response, Data("null".utf8))
            }
        }
        defer {
            MockURLProtocol.requestHandler = nil
            urlSession.invalidateAndCancel()
        }

        let client = LmsWebServiceClient(session: session, urlSession: urlSession)
        let preferences = try await client.fetchNotificationPreferences()

        #expect(wsFunctions == [
            "core_message_get_user_notification_preferences",
            "core_webservice_get_site_info",
            "core_user_get_user_preferences",
        ])
        #expect(preferences.userID == 123)
        #expect(preferences.processors.map(\.name) == ["popup", "email", "airnotifier"])

        let assignmentNotification = try #require(
            preferences.components
                .first { $0.displayName == "課題" }?
                .notifications
                .first { $0.preferenceKey == "message_provider_mod_assign_assign_notification" }
        )
        #expect(assignmentNotification.processor(named: "popup")?.enabled == false)
        #expect(assignmentNotification.processor(named: "email")?.enabled == true)
        #expect(assignmentNotification.processor(named: "airnotifier")?.enabled == true)

        let forumPosts = try #require(
            preferences.components
                .first { $0.displayName == "フォーラム" }?
                .notifications
                .first { $0.preferenceKey == "message_provider_mod_forum_posts" }
        )
        #expect(forumPosts.processor(named: "popup")?.enabled == true)
        #expect(forumPosts.processor(named: "email")?.enabled == false)
        #expect(forumPosts.processor(named: "airnotifier")?.enabled == true)

        let messageTeacher = try #require(
            preferences.components.first { $0.displayName == "私の先生にメッセージ" }
        )
        #expect(messageTeacher.description == "授業コード、授業名（曜日時限）、学生証番号を明記して送信すること")
    }

    @Test func uploadAssignmentSubmissionFilesSendsMultipartDraftUpload() async throws {
        let session = LmsAuthenticationSession(
            siteURL: "https://lms.example.test",
            token: "ws-token-123",
            privateToken: nil,
            rawCallbackURL: "moodleapp://example?token=ws-token-123",
            authenticatedAt: Date(timeIntervalSince1970: 1_744_506_000)
        )
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let urlSession = URLSession(configuration: configuration)

        MockURLProtocol.requestHandler = { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.path == "/webservice/upload.php")
            #expect(request.value(forHTTPHeaderField: "Content-Type")?.contains("multipart/form-data") == true)

            let body = try #require(requestBodyData(for: request))
            let bodyText = try #require(String(data: body, encoding: .utf8))
            #expect(bodyText.contains("name=\"token\"\r\n\r\nws-token-123"))
            #expect(bodyText.contains("name=\"filearea\"\r\n\r\ndraft"))
            #expect(bodyText.contains("name=\"itemid\"\r\n\r\n0"))
            #expect(bodyText.contains("name=\"file_1\"; filename=\"report.pdf\""))
            #expect(bodyText.contains("Content-Type: application/pdf"))
            #expect(bodyText.contains("file-content"))

            let url = try #require(request.url)
            let response = try #require(
                HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )
            )
            let responseData = Data(
                """
                [
                  {
                    "component": "user",
                    "contextid": 9,
                    "userid": 99,
                    "filearea": "draft",
                    "itemid": 123456,
                    "filename": "report.pdf",
                    "filepath": "/",
                    "filesize": 12
                  }
                ]
                """.utf8
            )
            return (response, responseData)
        }
        defer {
            MockURLProtocol.requestHandler = nil
            urlSession.invalidateAndCancel()
        }

        let client = LmsWebServiceClient(session: session, urlSession: urlSession)
        let uploadedFiles = try await client.uploadAssignmentSubmissionFiles([
            .init(
                fileName: "report.pdf",
                mimeType: "application/pdf",
                data: Data("file-content".utf8)
            )
        ])

        #expect(uploadedFiles.first?.itemID == 123456)
        #expect(uploadedFiles.first?.fileName == "report.pdf")
    }

    @Test func downloadAssignmentSubmissionFileRetainsUploadMetadata() async throws {
        let session = LmsAuthenticationSession(
            siteURL: "https://lms.example.test",
            token: "ws-token-123",
            privateToken: nil,
            rawCallbackURL: "moodleapp://example?token=ws-token-123",
            authenticatedAt: Date(timeIntervalSince1970: 1_744_506_000)
        )
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let urlSession = URLSession(configuration: configuration)
        let file = try JSONDecoder().decode(
            LmsWebServiceClient.AssignmentFile.self,
            from: Data(
                """
                {
                  "filename": "previous.pdf",
                  "fileurl": "https://lms.example.test/pluginfile.php/previous.pdf?token=ws-token-123",
                  "mimetype": "application/pdf"
                }
                """.utf8
            )
        )

        MockURLProtocol.requestHandler = { request in
            #expect(request.url?.path == "/pluginfile.php/previous.pdf")
            let url = try #require(request.url)
            let response = try #require(
                HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/pdf"]
                )
            )
            return (response, Data("previous-content".utf8))
        }
        defer {
            MockURLProtocol.requestHandler = nil
            urlSession.invalidateAndCancel()
        }

        let client = LmsWebServiceClient(session: session, urlSession: urlSession)
        let downloaded = try await client.downloadAssignmentSubmissionFile(file)

        #expect(downloaded.fileName == "previous.pdf")
        #expect(downloaded.mimeType == "application/pdf")
        #expect(downloaded.data == Data("previous-content".utf8))
    }

    @Test func assignmentSubmissionSaveAndConfirmSendRequiredParameters() async throws {
        let session = LmsAuthenticationSession(
            siteURL: "https://lms.example.test",
            token: "ws-token-123",
            privateToken: nil,
            rawCallbackURL: "moodleapp://example?token=ws-token-123",
            authenticatedAt: Date(timeIntervalSince1970: 1_744_506_000)
        )
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let urlSession = URLSession(configuration: configuration)

        MockURLProtocol.requestHandler = { request in
            let parameters = try formParameters(for: request)
            #expect(parameters["wstoken"] == "ws-token-123")
            #expect(parameters["assignmentid"] == "27625")

            switch parameters["wsfunction"] {
            case "mod_assign_save_submission":
                #expect(parameters["plugindata[files_filemanager]"] == "123456")
                #expect(parameters["plugindata[onlinetext_editor][text]"] == "<p>本文</p>")
                #expect(parameters["plugindata[onlinetext_editor][format]"] == "1")
                #expect(parameters["plugindata[onlinetext_editor][itemid]"] == "0")
            case "mod_assign_submit_for_grading":
                #expect(parameters["acceptsubmissionstatement"] == "0")
            default:
                Issue.record("Unexpected wsfunction \(parameters["wsfunction"] ?? "nil")")
            }

            let url = try #require(request.url)
            let response = try #require(
                HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )
            )
            return (response, Data("[]".utf8))
        }
        defer {
            MockURLProtocol.requestHandler = nil
            urlSession.invalidateAndCancel()
        }

        let client = LmsWebServiceClient(session: session, urlSession: urlSession)
        try await client.saveAssignmentSubmission(
            assignmentID: 27625,
            fileDraftItemID: 123456,
            onlineText: .init(text: "<p>本文</p>")
        )
        try await client.submitAssignmentForGrading(
            assignmentID: 27625,
            acceptsSubmissionStatement: false
        )
    }

    @Test func assignmentSubmissionSaveCanClearFileSubmission() async throws {
        let session = LmsAuthenticationSession(
            siteURL: "https://lms.example.test",
            token: "ws-token-123",
            privateToken: nil,
            rawCallbackURL: "moodleapp://example?token=ws-token-123",
            authenticatedAt: Date(timeIntervalSince1970: 1_744_506_000)
        )
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let urlSession = URLSession(configuration: configuration)

        MockURLProtocol.requestHandler = { request in
            let parameters = try formParameters(for: request)
            #expect(parameters["wstoken"] == "ws-token-123")
            #expect(parameters["wsfunction"] == "mod_assign_save_submission")
            #expect(parameters["assignmentid"] == "27625")
            #expect(parameters["plugindata[files_filemanager]"] == "0")

            let url = try #require(request.url)
            let response = try #require(
                HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )
            )
            return (response, Data("[]".utf8))
        }
        defer {
            MockURLProtocol.requestHandler = nil
            urlSession.invalidateAndCancel()
        }

        let client = LmsWebServiceClient(session: session, urlSession: urlSession)
        try await client.saveAssignmentSubmission(
            assignmentID: 27625,
            fileDraftItemID: 0
        )
    }

    @Test func assignmentSubmissionStartAndRemovalDecodeResponses() async throws {
        let session = LmsAuthenticationSession(
            siteURL: "https://lms.example.test",
            token: "ws-token-123",
            privateToken: nil,
            rawCallbackURL: "moodleapp://example?token=ws-token-123",
            authenticatedAt: Date(timeIntervalSince1970: 1_744_506_000)
        )
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let urlSession = URLSession(configuration: configuration)

        MockURLProtocol.requestHandler = { request in
            let parameters = try formParameters(for: request)
            #expect(parameters["assignid"] == "27625")

            let data: Data
            switch parameters["wsfunction"] {
            case "mod_assign_start_submission":
                data = Data(
                    """
                    {
                      "submissionid": 830437,
                      "warnings": [
                        {"warningcode": "opensubmissionexists", "message": "Already started"}
                      ]
                    }
                    """.utf8
                )
            case "mod_assign_remove_submission":
                #expect(parameters["userid"] == "67797")
                data = Data(#"{"status": true, "warnings": []}"#.utf8)
            default:
                Issue.record("Unexpected wsfunction \(parameters["wsfunction"] ?? "nil")")
                data = Data("{}".utf8)
            }

            let url = try #require(request.url)
            let response = try #require(
                HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )
            )
            return (response, data)
        }
        defer {
            MockURLProtocol.requestHandler = nil
            urlSession.invalidateAndCancel()
        }

        let client = LmsWebServiceClient(session: session, urlSession: urlSession)
        let started = try await client.startAssignmentSubmission(assignmentID: 27625)
        try await client.removeAssignmentSubmission(assignmentID: 27625, userID: 67797)

        #expect(started.submissionID == 830437)
    }


    @Test func assignmentNonDraftSubmissionUsesSaveSubmissionOnly() async throws {
        let session = LmsAuthenticationSession(
            siteURL: "https://lms.example.test",
            token: "ws-token-123",
            privateToken: nil,
            rawCallbackURL: "moodleapp://example?token=ws-token-123",
            authenticatedAt: Date(timeIntervalSince1970: 1_744_506_000)
        )
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let urlSession = URLSession(configuration: configuration)

        MockURLProtocol.requestHandler = { request in
            let parameters = try formParameters(for: request)
            #expect(parameters["wstoken"] == "ws-token-123")
            #expect(parameters["assignmentid"] == "27625")
            #expect(parameters["wsfunction"] == "mod_assign_save_submission")
            #expect(parameters["plugindata[files_filemanager]"] == "123456")

            let url = try #require(request.url)
            let response = try #require(
                HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )
            )
            return (response, Data("[]".utf8))
        }
        defer {
            MockURLProtocol.requestHandler = nil
            urlSession.invalidateAndCancel()
        }

        let client = LmsWebServiceClient(session: session, urlSession: urlSession)
        try await client.saveAssignmentSubmission(
            assignmentID: 27625,
            fileDraftItemID: 123456
        )

    }

    @Test func assignmentSubmissionSaveAcceptsNullWarningsResponse() async throws {
        let session = LmsAuthenticationSession(
            siteURL: "https://lms.example.test",
            token: "ws-token-123",
            privateToken: nil,
            rawCallbackURL: "moodleapp://example?token=ws-token-123",
            authenticatedAt: Date(timeIntervalSince1970: 1_744_506_000)
        )
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let urlSession = URLSession(configuration: configuration)

        MockURLProtocol.requestHandler = { request in
            let url = try #require(request.url)
            let response = try #require(
                HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )
            )
            return (response, Data("null".utf8))
        }
        defer {
            MockURLProtocol.requestHandler = nil
            urlSession.invalidateAndCancel()
        }

        let client = LmsWebServiceClient(session: session, urlSession: urlSession)
        try await client.saveAssignmentSubmission(assignmentID: 27625, fileDraftItemID: 123456)
        try await client.submitAssignmentForGrading(assignmentID: 27625)
    }

    @Test func uploadAssignmentSubmissionFilesAcceptsSingleObjectResponse() async throws {
        let session = LmsAuthenticationSession(
            siteURL: "https://lms.example.test",
            token: "ws-token-123",
            privateToken: nil,
            rawCallbackURL: "moodleapp://example?token=ws-token-123",
            authenticatedAt: Date(timeIntervalSince1970: 1_744_506_000)
        )
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let urlSession = URLSession(configuration: configuration)

        MockURLProtocol.requestHandler = { request in
            let url = try #require(request.url)
            let response = try #require(
                HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )
            )
            let responseData = Data(
                """
                {
                  "component": "user",
                  "contextid": "9",
                  "userid": "99",
                  "filearea": "draft",
                  "itemid": "123456",
                  "filename": "report.pdf",
                  "filepath": "/",
                  "filesize": "12"
                }
                """.utf8
            )
            return (response, responseData)
        }
        defer {
            MockURLProtocol.requestHandler = nil
            urlSession.invalidateAndCancel()
        }

        let client = LmsWebServiceClient(session: session, urlSession: urlSession)
        let uploadedFiles = try await client.uploadAssignmentSubmissionFiles([
            .init(fileName: "report.pdf", mimeType: "application/pdf", data: Data("file-content".utf8))
        ])

        #expect(uploadedFiles.first?.itemID == 123456)
    }

    @Test func assignmentSubmissionStartAcceptsStringSubmissionID() throws {
        let data = Data(
            """
            {
              "submissionid": "830437",
              "warnings": []
            }
            """.utf8
        )

        let response = try JSONDecoder().decode(
            LmsWebServiceClient.AssignmentSubmissionStartResponse.self,
            from: data
        )

        #expect(response.submissionID == 830437)
    }

    @Test func requestLoggerCapturesMultipleResponsesWithContext() async throws {
        let session = LmsAuthenticationSession(
            siteURL: "https://lms.example.test",
            token: "ws-token-123",
            privateToken: nil,
            rawCallbackURL: "moodleapp://example?token=ws-token-123",
            authenticatedAt: Date(timeIntervalSince1970: 1_744_506_000)
        )
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let urlSession = URLSession(configuration: configuration)

        MockURLProtocol.requestHandler = { request in
            let bodyData = try #require(requestBodyData(for: request))
            let body = try #require(String(data: bodyData, encoding: .utf8))

            var components = URLComponents()
            components.percentEncodedQuery = body
            let queryItems = try #require(components.queryItems)
            let wsFunction = try #require(queryItems.first(where: { $0.name == "wsfunction" })?.value)
            let url = try #require(request.url)

            let response = try #require(
                HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )
            )

            let data: Data
            switch wsFunction {
            case "core_course_get_contents":
                data = Data(
                    """
                    [
                      {
                        "id": 1,
                        "section": 0,
                        "name": "Topic 1",
                        "summary": null,
                        "modules": []
                      }
                    ]
                    """.utf8
                )
            case "mod_assign_get_assignments":
                data = Data(
                    """
                    {
                      "courses": [
                        {
                          "id": 42,
                          "fullname": "Software Engineering",
                          "shortname": "2026-50001",
                          "assignments": []
                        }
                      ],
                      "warnings": []
                    }
                    """.utf8
                )
            default:
                Issue.record("Unexpected wsfunction \(wsFunction)")
                data = Data("{}".utf8)
            }

            return (response, data)
        }
        defer {
            MockURLProtocol.requestHandler = nil
            urlSession.invalidateAndCancel()
        }

        let context = LmsRequestLogContext(navigationPath: "課題タブ > 課題詳細", pageTitle: "課題 A")
        let requestLogger = TestRequestLogger()
        let client = LmsWebServiceClient(
            session: session,
            urlSession: urlSession,
            requestLogger: requestLogger,
            logContext: context
        )

        _ = try await client.fetchCourseContents(courseID: 42)
        _ = try await client.fetchAssignments(courseIDs: [42])

        let entries = await requestLogger.snapshot()

        #expect(entries.count == 2)
        #expect(entries.allSatisfy { $0.context == context })
        #expect(entries.map(\.wsFunction) == ["core_course_get_contents", "mod_assign_get_assignments"])
        #expect(entries[0].parameters == [.init(name: "courseid", value: "42")])
        #expect(entries[0].statusCode == 200)
        #expect(entries[0].responseBody.contains("\"id\": 1"))
        #expect(entries[1].parameters == [.init(name: "courseids[0]", value: "42")])
        #expect(entries[1].responseBody.contains("\"courses\""))
    }

    @Test func requestLoggerCapturesTransportErrors() async {
        let session = LmsAuthenticationSession(
            siteURL: "https://lms.example.test",
            token: "ws-token-123",
            privateToken: nil,
            rawCallbackURL: "moodleapp://example?token=ws-token-123",
            authenticatedAt: Date(timeIntervalSince1970: 1_744_506_000)
        )
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let urlSession = URLSession(configuration: configuration)

        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }
        defer {
            MockURLProtocol.requestHandler = nil
            urlSession.invalidateAndCancel()
        }

        let requestLogger = TestRequestLogger()
        let client = LmsWebServiceClient(
            session: session,
            urlSession: urlSession,
            requestLogger: requestLogger,
            logContext: LmsRequestLogContext(navigationPath: "通知タブ", pageTitle: "通知")
        )

        await #expect(throws: URLError.self) {
            _ = try await client.fetchPopupNotifications()
        }

        let entries = await requestLogger.snapshot()

        #expect(entries.count == 1)
        #expect(entries[0].wsFunction == "message_popup_get_popup_notifications")
        #expect(entries[0].statusCode == nil)
        #expect(entries[0].responseBody.isEmpty)
        #expect(entries[0].errorMessage?.isEmpty == false)
    }

    @Test func requestLoggerRecordsMalformedJSONOnlyOnce() async {
        let session = LmsAuthenticationSession(
            siteURL: "https://lms.example.test",
            token: "ws-token-123",
            privateToken: nil,
            rawCallbackURL: "moodleapp://example?token=ws-token-123",
            authenticatedAt: Date(timeIntervalSince1970: 1_744_506_000)
        )
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let urlSession = URLSession(configuration: configuration)

        MockURLProtocol.requestHandler = { request in
            let url = try #require(request.url)
            let response = try #require(
                HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )
            )
            return (response, Data("{".utf8))
        }
        defer {
            MockURLProtocol.requestHandler = nil
            urlSession.invalidateAndCancel()
        }

        let requestLogger = TestRequestLogger()
        let client = LmsWebServiceClient(
            session: session,
            urlSession: urlSession,
            requestLogger: requestLogger,
            logContext: LmsRequestLogContext(navigationPath: "課題タブ > 課題詳細", pageTitle: "課題 A")
        )

        await #expect(throws: (any Error).self) {
            _ = try await client.fetchAssignmentSubmissionStatus(assignmentID: 27625)
        }

        let entries = await requestLogger.snapshot()
        #expect(entries.count == 1)
        #expect(entries[0].statusCode == 200)
        #expect(entries[0].errorMessage?.isEmpty == false)
        #expect(entries[0].responseBody == "{")
    }
}

private actor TestRequestLogger: LmsWebServiceRequestLogging {
    private var entries: [LmsRequestLogEntry] = []

    func record(
        context: LmsRequestLogContext,
        wsFunction: String,
        parameters: [URLQueryItem],
        response: HTTPURLResponse?,
        data: Data?,
        error: Error?
    ) {
        entries.append(
            LmsRequestLogEntry(
                context: context,
                wsFunction: wsFunction,
                parameters: parameters.map {
                    LmsRequestLogEntry.Parameter(name: $0.name, value: $0.value)
                },
                statusCode: response?.statusCode,
                errorMessage: error.map(\.localizedDescription),
                responseBody: String(data: data ?? Data(), encoding: .utf8) ?? ""
            )
        )
    }

    func snapshot() -> [LmsRequestLogEntry] {
        entries
    }
}

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let requestHandler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: MockURLProtocolError.missingRequestHandler)
            return
        }

        do {
            let (response, data) = try requestHandler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private enum MockURLProtocolError: Error {
    case missingRequestHandler
}

private func requestBodyData(for request: URLRequest) -> Data? {
    if let httpBody = request.httpBody {
        return httpBody
    }

    guard let httpBodyStream = request.httpBodyStream else {
        return nil
    }

    httpBodyStream.open()
    defer {
        httpBodyStream.close()
    }

    let bufferSize = 1024
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer {
        buffer.deallocate()
    }

    var data = Data()
    while httpBodyStream.hasBytesAvailable {
        let readCount = httpBodyStream.read(buffer, maxLength: bufferSize)
        guard readCount >= 0 else {
            return nil
        }

        guard readCount > 0 else {
            break
        }

        data.append(buffer, count: readCount)
    }

    return data
}

private func formParameters(for request: URLRequest) throws -> [String: String] {
    let components: URLComponents
    if let bodyData = requestBodyData(for: request),
        let body = String(data: bodyData, encoding: .utf8)
    {
        var bodyComponents = URLComponents()
        bodyComponents.percentEncodedQuery = body
        components = bodyComponents
    } else {
        let url = try #require(request.url)
        components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
    }

    let queryItems = try #require(components.queryItems)
    return queryItems.reduce(into: [:]) { result, item in
        if let value = item.value {
            result[item.name] = value
        }
    }
}
