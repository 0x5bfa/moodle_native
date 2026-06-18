package dev.example.moodlenative.networking

import java.net.URI
import java.net.URLDecoder
import java.util.concurrent.CountDownLatch
import kotlin.coroutines.Continuation
import kotlin.coroutines.EmptyCoroutineContext
import kotlin.coroutines.startCoroutine
import kotlinx.serialization.json.Json
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class LmsWebServiceClientTest {
    @Test
    fun decodeSiteInfoDefaultsOptionalArrays() {
        val siteInfo = json.decodeFromString<SiteInfo>(
            """
            {
              "sitename": "Moodle",
              "siteurl": "https://lms.example.test",
              "userid": 99,
              "username": "is0000xx",
              "fullname": "テスト 太郎"
            }
            """.trimIndent(),
        )

        assertEquals("Moodle", siteInfo.siteName)
        assertEquals(99, siteInfo.userID)
        assertTrue(siteInfo.functions.isEmpty())
        assertTrue(siteInfo.advancedFeatures.isEmpty())
        assertFalse(siteInfo.isAdvancedFeatureEnabled("messagingallusers"))
    }

    @Test
    fun decodeCourseAndDashboardBlockModels() {
        val course = json.decodeFromString<Course>(
            """
            {
              "id": 42,
              "fullname": "Software Engineering",
              "displayname": "ソフトウェア工学",
              "shortname": "2026-50001",
              "summary": "<p>summary</p>",
              "courseimage": "https://lms.example.test/image.png",
              "progress": 40.0,
              "isfavourite": true
            }
            """.trimIndent(),
        )
        val blocks = json.decodeFromString<DashboardBlocksResponse>(
            """
            {
              "blocks": [
                {
                  "instanceid": 10,
                  "name": "rutime_table",
                  "region": "content",
                  "positionid": 1,
                  "visible": true,
                  "contents": {
                    "title": "My時間割",
                    "content": "<div class=\"subject\">...</div>",
                    "contentformat": 1,
                    "files": [
                      {"filename": "icon.png", "fileurl": "https://lms.example.test/icon.png"}
                    ]
                  },
                  "configs": [
                    {"name": "foo", "value": "bar", "type": "text"}
                  ]
                }
              ]
            }
            """.trimIndent(),
        )

        assertEquals(42, course.id)
        assertEquals("Software Engineering", course.fullName)
        assertEquals(true, course.isFavorite)
        assertEquals(1, blocks.blocks.size)
        assertEquals("rutime_table", blocks.blocks[0].name)
        assertEquals("<div class=\"subject\">...</div>", blocks.blocks[0].contents?.content)
        assertEquals("icon.png", blocks.blocks[0].contents?.files?.firstOrNull()?.fileName)
        assertEquals("bar", blocks.blocks[0].configs?.firstOrNull()?.value)
    }

    @Test
    fun decodeCourseModuleWithoutOptionalArrays() {
        val module = json.decodeFromString<CourseModule>(
            """
            {
              "id": 42,
              "instance": 314,
              "modname": "forum",
              "name": "Announcements",
              "url": "https://lms.example.test/mod/forum/view.php?id=42"
            }
            """.trimIndent(),
        )

        assertEquals(42, module.id)
        assertEquals(314, module.instanceID)
        assertEquals("forum", module.modName)
        assertTrue(module.contents.isEmpty())
        assertTrue(module.dates.isEmpty())
    }

    @Test
    fun decodeCourseModuleCompletionData() {
        val module = json.decodeFromString<CourseModule>(
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
            """.trimIndent(),
        )

        assertEquals(2, module.completion)
        val completionData = requireNotNull(module.completionData)
        assertEquals(0, completionData.state)
        assertTrue(completionData.hasCompletion)
        assertTrue(completionData.userVisible)
        assertEquals(2, completionData.details.size)
        assertEquals("completionview", completionData.details[0].ruleName)
        assertEquals(1, completionData.details[0].ruleValue?.status)
        assertEquals("completionsubmit", completionData.details[1].ruleName)
        assertEquals(0, completionData.details[1].ruleValue?.status)
        assertFalse(completionData.isOverallComplete)
        assertEquals(0.5, completionData.summary?.progress)
        assertEquals(false, completionData.summary?.isComplete)
        assertEquals(listOf("閲覧する", "提出する"), completionData.requirements.map { it.text })
        assertEquals(listOf(true, false), completionData.requirements.map { it.isComplete })
    }

    @Test
    fun completionDataUsesFallbackRequirementTextAndSummaryForOverallState() {
        val completionData = json.decodeFromString<ModuleCompletionData>(
            """
            {
              "state": 1,
              "hascompletion": true,
              "uservisible": true,
              "details": [
                {
                  "rulename": "completionposts",
                  "rulevalue": {
                    "status": 1,
                    "description": "   "
                  }
                }
              ],
              "isoverallcomplete": true
            }
            """.trimIndent(),
        )

        assertEquals(1.0, completionData.summary?.progress)
        assertEquals(true, completionData.summary?.isComplete)
        assertEquals("完了", completionData.summary?.accessibilityLabel)
        assertEquals(listOf("フォーラム投稿を作成する"), completionData.requirements.map { it.text })
        assertEquals(listOf(true), completionData.requirements.map { it.isComplete })
    }

    @Test
    fun decodeForumDiscussionsResponse() {
        val response = json.decodeFromString<ForumDiscussionsResponse>(
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
                  "pinned": "true",
                  "locked": 0,
                  "modified": 1775200576,
                  "canreply": 1
                }
              ]
            }
            """.trimIndent(),
        )

        assertEquals(1, response.discussions.size)
        val discussion = response.discussions[0]
        assertEquals(28473, discussion.id)
        assertEquals(60937, discussion.rootPostID)
        assertEquals("【重要】組込み実験の「+R授業」と準備作業について", discussion.name)
        assertEquals(2, discussion.numberOfUnreadPosts)
        assertTrue(discussion.isPinned)
        assertFalse(discussion.isLocked)
        assertTrue(discussion.canReply)
    }

    @Test
    fun decodeDiscussionPostsResponse() {
        val response = json.decodeFromString<DiscussionPostsResponse>(
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
                  "unread": "yes",
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
                    },
                    {
                      "filename": "fallback.txt",
                      "url": "https://lms.example.test/pluginfile.php/1/mod_forum/post/fallback.txt",
                      "mimetype": "text/plain"
                    }
                  ]
                }
              ]
            }
            """.trimIndent(),
        )

        assertEquals(1, response.posts.size)
        val post = response.posts[0]
        assertEquals(28473, post.discussionID)
        assertEquals("山本 寛", post.author.fullName)
        assertTrue(post.unread)
        assertEquals("guide.pdf", post.attachments[0].fileName)
        assertEquals("https://lms.example.test/pluginfile.php/1/mod_forum/post/fallback.txt", post.attachments[1].fileURL)
        assertEquals("https://lms.example.test/mod/forum/discuss.php?d=28473", post.urls.discuss)
    }

    @Test
    fun decodePopupNotificationsResponse() {
        val response = json.decodeFromString<PopupNotificationsResponse>(
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
                  "read": "false",
                  "deleted": 0,
                  "iconurl": "https://lms.example.test/theme/image.php/notification",
                  "component": "mod_assign",
                  "eventtype": "submission_due",
                  "customdata": ""
                }
              ],
              "unreadcount": 4
            }
            """.trimIndent(),
        )

        assertEquals(1, response.notifications.size)
        assertEquals(4, response.unreadCount)
        assertEquals("課題の締切が近づいています", response.notifications[0].subject)
        assertFalse(response.notifications[0].read)
        assertFalse(response.notifications[0].deleted)
        assertEquals("mod_assign", response.notifications[0].component)
        assertEquals("レポート課題 1", response.notifications[0].contextURLName)
    }

    @Test
    fun decodeNotificationPreferencesResponse() {
        val response = json.decodeFromString<NotificationPreferencesResponse>(
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
            """.trimIndent(),
        )

        val preferences = response.preferences
        assertEquals(123, preferences.userID)
        assertTrue(preferences.enableAll)
        assertEquals("airnotifier", preferences.processors.firstOrNull()?.name)
        assertEquals(true, preferences.processors.firstOrNull()?.hasSettings)
        assertEquals(
            "message_provider_mod_assign_assign_notification",
            preferences.components.firstOrNull()?.notifications?.firstOrNull()?.preferenceKey,
        )

        val processor = preferences.components.first().notifications.first().processors.first()
        assertEquals(true, processor.enabled)
        assertEquals(true, processor.loggedIn?.checked)
        assertEquals(false, processor.loggedOff?.checked)
    }

    @Test
    fun fetchSiteInfoSendsGetParameters() {
        val httpClient = RecordingHttpClient { request ->
            assertEquals("GET", request.method)
            assertEquals("/webservice/rest/server.php", request.url.path)
            assertNull(request.body)

            val parameters = request.parameters()
            assertEquals("ws-token-123", parameters["wstoken"])
            assertEquals("core_webservice_get_site_info", parameters["wsfunction"])
            assertEquals("json", parameters["moodlewsrestformat"])

            LmsHttpResponse(
                statusCode = 200,
                body = """
                    {
                      "sitename": "Moodle",
                      "siteurl": "https://lms.example.test",
                      "userid": 99,
                      "username": "is0000xx",
                      "fullname": "テスト 太郎",
                      "advancedfeatures": [
                        {"name": "messagingallusers", "value": 1}
                      ]
                    }
                """.trimIndent(),
            )
        }
        val client = LmsWebServiceClient(session = session(userID = null), httpClient = httpClient)

        val siteInfo = runSuspend { client.fetchSiteInfo() }

        assertEquals(99, siteInfo.userID)
        assertTrue(siteInfo.isAdvancedFeatureEnabled("messagingallusers"))
        assertEquals(1, httpClient.requests.size)
    }

    @Test
    fun fetchEnrolledCoursesSendsUserParameters() {
        val httpClient = RecordingHttpClient { request ->
            assertEquals("POST", request.method)
            assertEquals("application/x-www-form-urlencoded", request.headers["Content-Type"])

            val parameters = request.parameters()
            assertEquals("ws-token-123", parameters["wstoken"])
            assertEquals("core_enrol_get_users_courses", parameters["wsfunction"])
            assertEquals("json", parameters["moodlewsrestformat"])
            assertEquals("99", parameters["userid"])
            assertEquals("0", parameters["returnusercount"])

            LmsHttpResponse(
                statusCode = 200,
                body = """
                    [
                      {
                        "id": 42,
                        "fullname": "Software Engineering",
                        "shortname": "2026-50001"
                      }
                    ]
                """.trimIndent(),
            )
        }
        val client = LmsWebServiceClient(session = session(userID = 99), httpClient = httpClient)

        val courses = runSuspend { client.fetchEnrolledCourses() }

        assertEquals(1, courses.size)
        assertEquals(42, courses[0].id)
        assertEquals("2026-50001", courses[0].shortName)
    }

    @Test
    fun fetchCourseContentsSendsCourseIDAndAuthorizesModuleURLs() {
        val httpClient = RecordingHttpClient { request ->
            val parameters = request.parameters()
            assertEquals("POST", request.method)
            assertEquals("core_course_get_contents", parameters["wsfunction"])
            assertEquals("42", parameters["courseid"])

            LmsHttpResponse(
                statusCode = 200,
                body = """
                    [
                      {
                        "id": 1,
                        "section": 0,
                        "name": "Topic 1",
                        "summary": null,
                        "modules": [
                          {
                            "id": 201,
                            "instance": 301,
                            "modname": "assign",
                            "name": "第1回課題",
                            "url": "https://lms.example.test/mod/assign/view.php?id=201",
                            "contents": [
                              {
                                "type": "file",
                                "filename": "guide.pdf",
                                "filepath": "/",
                                "filesize": 1000,
                                "fileurl": "https://lms.example.test/pluginfile.php/1/guide.pdf",
                                "mimetype": "application/pdf",
                                "timemodified": 1750000000
                              }
                            ],
                            "dates": [
                              {
                                "label": "期限",
                                "timestamp": 1750000000,
                                "dataid": "duedate"
                              }
                            ]
                          }
                        ]
                      }
                    ]
                """.trimIndent(),
            )
        }
        val client = LmsWebServiceClient(session = session(userID = null), httpClient = httpClient)

        val sections = runSuspend { client.fetchCourseContents(courseID = 42) }

        assertEquals(1, sections.size)
        assertEquals(1, sections[0].modules.size)
        val module = sections[0].modules[0]
        assertEquals("https://lms.example.test/mod/assign/view.php?id=201&token=ws-token-123", module.url)
        assertEquals(
            "https://lms.example.test/pluginfile.php/1/guide.pdf?token=ws-token-123",
            module.contents[0].fileURL,
        )
        assertEquals("file|/|guide.pdf|https://lms.example.test/pluginfile.php/1/guide.pdf?token=ws-token-123", module.contents[0].id)
        assertEquals("duedate", module.dates[0].id)
        assertEquals(1, httpClient.requests.size)
    }

    @Test
    fun fetchDashboardBlocksSendsReturnContentsParameter() {
        val httpClient = RecordingHttpClient { request ->
            val parameters = request.parameters()
            assertEquals("core_block_get_dashboard_blocks", parameters["wsfunction"])
            assertEquals("1", parameters["returncontents"])

            LmsHttpResponse(
                statusCode = 200,
                body = """
                    {
                      "blocks": [
                        {
                          "instanceid": 10,
                          "name": "rutime_table",
                          "contents": {"content": "<table></table>"}
                        }
                      ]
                    }
                """.trimIndent(),
            )
        }
        val client = LmsWebServiceClient(session = session(userID = 99), httpClient = httpClient)

        val blocks = runSuspend { client.fetchDashboardBlocks() }

        assertEquals(1, blocks.size)
        assertEquals("rutime_table", blocks[0].name)
        assertEquals("<table></table>", blocks[0].contents?.content)
    }

    @Test
    fun emptyCourseIDsReturnEmptyAssignmentsWithoutRequest() {
        val httpClient = RecordingHttpClient {
            error("No request should be sent for empty courseIDs")
        }
        val client = LmsWebServiceClient(session = session(userID = 99), httpClient = httpClient)

        val assignments = runSuspend { client.fetchAssignments(courseIDs = emptyList()) }

        assertTrue(assignments.isEmpty())
        assertTrue(httpClient.requests.isEmpty())
    }

    @Test
    fun fetchAssignmentsWithoutCourseIDsOmitsCourseIDParameters() {
        val httpClient = RecordingHttpClient { request ->
            assertEquals("POST", request.method)
            assertEquals("/webservice/rest/server.php", request.url.path)

            val parameters = request.parameters()
            assertEquals("ws-token-123", parameters["wstoken"])
            assertEquals("mod_assign_get_assignments", parameters["wsfunction"])
            assertEquals("json", parameters["moodlewsrestformat"])
            assertFalse(parameters.keys.any { it.startsWith("courseids[") })

            LmsHttpResponse(
                statusCode = 200,
                body = """
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
                """.trimIndent(),
            )
        }
        val client = LmsWebServiceClient(session = session(userID = null), httpClient = httpClient)

        val assignments = runSuspend { client.fetchAssignments() }

        assertEquals(1, assignments.size)
        assertEquals(42, assignments[0].id)
    }

    @Test
    fun fetchAssignmentsWithCourseIDsSendsIndexedParameters() {
        val httpClient = RecordingHttpClient { request ->
            val parameters = request.parameters()
            assertEquals("mod_assign_get_assignments", parameters["wsfunction"])
            assertEquals("42", parameters["courseids[0]"])
            assertEquals("77", parameters["courseids[1]"])

            LmsHttpResponse(
                statusCode = 200,
                body = """
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
                """.trimIndent(),
            )
        }
        val client = LmsWebServiceClient(session = session(userID = null), httpClient = httpClient)

        val assignments = runSuspend { client.fetchAssignments(courseIDs = listOf(42, 77)) }

        assertEquals(1, assignments.size)
        assertEquals(1, httpClient.requests.size)
    }

    @Test
    fun decodeAssignmentSubmissionConfigurationAndEnabledPlugins() {
        val assignment = json.decodeFromString<Assignment>(
            """
            {
              "id": 27625,
              "cmid": 177,
              "course": 42,
              "name": "提出課題",
              "submissiondrafts": 1,
              "requiresubmissionstatement": "true",
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
            """.trimIndent(),
        )

        assertEquals(true, assignment.submissionDrafts)
        assertEquals(true, assignment.requiresSubmissionStatement)
        assertEquals("<p>自分の成果物です。</p>", assignment.submissionStatement)
        assertEquals(3600, assignment.timeLimit)
        assertEquals(listOf("file", "onlinetext", "comments"), assignment.enabledSubmissionPluginTypes)
        assertEquals(500, assignment.onlineTextWordLimit)
    }

    @Test
    fun decodeAssignmentSubmissionStatusResponse() {
        val response = json.decodeFromString<AssignmentSubmissionStatus>(
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
                              "timemodified": 1775600300,
                              "isexternalfile": "0"
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
                "submissionsenabled": "true",
                "locked": 0,
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
            """.trimIndent(),
        )

        assertEquals("submitted", response.lastAttempt?.submission?.status)
        assertEquals(true, response.lastAttempt?.submissionsEnabled)
        assertEquals(false, response.lastAttempt?.locked)
        assertEquals(
            "report.pdf",
            response.lastAttempt?.submission?.plugins?.firstOrNull()?.fileAreas?.firstOrNull()?.files?.firstOrNull()?.fileName,
        )
        assertEquals(
            false,
            response.lastAttempt?.submission?.plugins?.firstOrNull()?.fileAreas?.firstOrNull()?.files?.firstOrNull()?.isExternalFile,
        )
        assertEquals(
            "<p>提出本文</p>",
            response.lastAttempt?.submission?.plugins?.firstOrNull()?.editorFields?.firstOrNull()?.text,
        )
        assertEquals("80 / 100", response.feedback?.gradeForDisplay)
        assertEquals("<p>よくできています</p>", response.feedback?.plugins?.firstOrNull()?.editorFields?.firstOrNull()?.text)
        assertEquals("<p>レポートを提出してください。</p>", response.assignmentData?.activity)
        assertEquals("requirements.pdf", response.assignmentData?.attachments?.activity?.firstOrNull()?.fileName)
        assertEquals(1, response.previousAttempts.size)
    }

    @Test
    fun decodeAssignmentSubmissionStatusWithEmptyAssignmentDataArray() {
        val response = json.decodeFromString<AssignmentSubmissionStatus>(
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
            """.trimIndent(),
        )

        assertNull(response.assignmentData)
        assertEquals(
            "report.pdf",
            response.lastAttempt?.submission?.plugins?.firstOrNull()?.fileAreas?.firstOrNull()?.files?.firstOrNull()?.fileName,
        )
    }

    @Test
    fun fetchAssignmentSubmissionStatusSendsAssignIDAndAuthorizesFileURLs() {
        val httpClient = RecordingHttpClient { request ->
            val parameters = request.parameters()
            assertEquals("POST", request.method)
            assertEquals("mod_assign_get_submission_status", parameters["wsfunction"])
            assertEquals("27625", parameters["assignid"])

            LmsHttpResponse(
                statusCode = 200,
                body = """
                    {
                      "lastattempt": {
                        "submission": {
                          "id": 501,
                          "userid": 99,
                          "attemptnumber": 1,
                          "status": "submitted",
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
                                      "fileurl": "https://lms.example.test/pluginfile.php/10/report.pdf"
                                    }
                                  ]
                                }
                              ]
                            }
                          ]
                        }
                      },
                      "feedback": {
                        "plugins": [
                          {
                            "type": "file",
                            "name": "Feedback files",
                            "fileareas": [
                              {
                                "area": "feedback_files",
                                "files": [
                                  {
                                    "filename": "feedback.pdf",
                                    "fileurl": "https://lms.example.test/pluginfile.php/30/feedback.pdf?forcedownload=1"
                                  }
                                ]
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
                            "plugins": [
                              {
                                "type": "file",
                                "name": "Previous files",
                                "fileareas": [
                                  {
                                    "area": "submission_files",
                                    "files": [
                                      {
                                        "filename": "old.pdf",
                                        "fileurl": "https://lms.example.test/pluginfile.php/40/old.pdf?token=already"
                                      }
                                    ]
                                  }
                                ]
                              }
                            ]
                          }
                        }
                      ],
                      "assignmentdata": {
                        "attachments": {
                          "intro": [
                            {
                              "filename": "intro.pdf",
                              "fileurl": "https://lms.example.test/pluginfile.php/20/intro.pdf"
                            }
                          ]
                        }
                      },
                      "warnings": []
                    }
                """.trimIndent(),
            )
        }
        val client = LmsWebServiceClient(session = session(userID = null), httpClient = httpClient)

        val status = runSuspend { client.fetchAssignmentSubmissionStatus(assignmentID = 27625) }

        assertEquals(
            "https://lms.example.test/pluginfile.php/10/report.pdf?token=ws-token-123",
            status.lastAttempt?.submission?.plugins?.firstOrNull()?.fileAreas?.firstOrNull()?.files?.firstOrNull()?.fileURL,
        )
        assertEquals(
            "https://lms.example.test/pluginfile.php/30/feedback.pdf?forcedownload=1&token=ws-token-123",
            status.feedback?.plugins?.firstOrNull()?.fileAreas?.firstOrNull()?.files?.firstOrNull()?.fileURL,
        )
        assertEquals(
            "https://lms.example.test/pluginfile.php/40/old.pdf?token=already",
            status.previousAttempts.firstOrNull()?.submission?.plugins?.firstOrNull()?.fileAreas?.firstOrNull()?.files?.firstOrNull()?.fileURL,
        )
        assertEquals(
            "https://lms.example.test/pluginfile.php/20/intro.pdf?token=ws-token-123",
            status.assignmentData?.attachments?.intro?.firstOrNull()?.fileURL,
        )
        assertEquals(1, httpClient.requests.size)
    }

    @Test
    fun uploadAssignmentSubmissionFilesSendsMultipartDraftUpload() {
        val httpClient = RecordingHttpClient { request ->
            assertEquals("POST", request.method)
            assertEquals("/webservice/upload.php", request.url.path)
            assertTrue(request.headers["Content-Type"]?.contains("multipart/form-data") == true)

            val body = requireNotNull(request.bodyText)
            assertTrue(body.contains("name=\"token\"\r\n\r\nws-token-123"))
            assertTrue(body.contains("name=\"filearea\"\r\n\r\ndraft"))
            assertTrue(body.contains("name=\"itemid\"\r\n\r\n0"))
            assertTrue(body.contains("name=\"filepath\"\r\n\r\n/"))
            assertTrue(body.contains("name=\"file_1\"; filename=\"report.pdf\""))
            assertTrue(body.contains("Content-Type: application/pdf"))
            assertTrue(body.contains("file-content"))

            LmsHttpResponse(
                statusCode = 200,
                body = """
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
                """.trimIndent(),
            )
        }
        val client = LmsWebServiceClient(session = session(userID = null), httpClient = httpClient)

        val uploadedFiles = runSuspend {
            client.uploadAssignmentSubmissionFiles(
                listOf(
                    AssignmentSubmissionUploadFile(
                        fileName = "report.pdf",
                        mimeType = "application/pdf",
                        data = "file-content".toByteArray(Charsets.UTF_8),
                    ),
                ),
            )
        }

        assertEquals(123456, uploadedFiles.firstOrNull()?.itemID)
        assertEquals("report.pdf", uploadedFiles.firstOrNull()?.fileName)
        assertEquals(1, httpClient.requests.size)
    }

    @Test
    fun uploadAssignmentSubmissionFilesRejectsEmptyFiles() {
        val httpClient = RecordingHttpClient {
            error("No request should be sent for empty upload files")
        }
        val client = LmsWebServiceClient(session = session(userID = null), httpClient = httpClient)

        assertThrows(LmsWebServiceError.InvalidSubmissionFiles::class.java) {
            runSuspend { client.uploadAssignmentSubmissionFiles(emptyList()) }
        }
        assertTrue(httpClient.requests.isEmpty())
    }

    @Test
    fun downloadAssignmentSubmissionFileRetainsUploadMetadata() {
        val httpClient = RecordingHttpClient { request ->
            assertEquals("GET", request.method)
            assertEquals("/pluginfile.php/previous.pdf", request.url.path)
            assertEquals("token=ws-token-123", request.url.rawQuery)

            LmsHttpResponse(
                statusCode = 200,
                body = "ignored-text",
                bodyBytes = byteArrayOf(0x00, 0x01, 0x02, 0x7F),
            )
        }
        val client = LmsWebServiceClient(session = session(userID = null), httpClient = httpClient)

        val downloaded = runSuspend {
            client.downloadAssignmentSubmissionFile(
                AssignmentFile(
                    fileName = "previous.pdf",
                    fileURL = "https://lms.example.test/pluginfile.php/previous.pdf?token=ws-token-123",
                    mimeType = "application/pdf",
                ),
            )
        }

        assertEquals("previous.pdf", downloaded.fileName)
        assertEquals("application/pdf", downloaded.mimeType)
        assertArrayEquals(byteArrayOf(0x00, 0x01, 0x02, 0x7F), downloaded.data)
        assertEquals(1, httpClient.requests.size)
    }

    @Test
    fun assignmentSubmissionSaveAndConfirmSendRequiredParameters() {
        val httpClient = RecordingHttpClient { request ->
            val parameters = request.parameters()
            assertEquals("ws-token-123", parameters["wstoken"])
            assertEquals("27625", parameters["assignmentid"])

            when (parameters["wsfunction"]) {
                "mod_assign_save_submission" -> {
                    assertEquals("123456", parameters["plugindata[files_filemanager]"])
                    assertEquals("<p>本文</p>", parameters["plugindata[onlinetext_editor][text]"])
                    assertEquals("1", parameters["plugindata[onlinetext_editor][format]"])
                    assertEquals("0", parameters["plugindata[onlinetext_editor][itemid]"])
                }

                "mod_assign_submit_for_grading" -> {
                    assertEquals("0", parameters["acceptsubmissionstatement"])
                }

                else -> error("Unexpected wsfunction: ${parameters["wsfunction"]}")
            }

            LmsHttpResponse(statusCode = 200, body = "[]")
        }
        val client = LmsWebServiceClient(session = session(userID = null), httpClient = httpClient)

        runSuspend {
            client.saveAssignmentSubmission(
                assignmentID = 27625,
                fileDraftItemID = 123456,
                onlineText = AssignmentOnlineTextInput(text = "<p>本文</p>"),
            )
            client.submitAssignmentForGrading(
                assignmentID = 27625,
                acceptsSubmissionStatement = false,
            )
        }

        assertEquals(
            listOf("mod_assign_save_submission", "mod_assign_submit_for_grading"),
            httpClient.requests.map { it.parameters()["wsfunction"] },
        )
    }

    @Test
    fun assignmentSubmissionSaveCanClearFileSubmission() {
        val httpClient = RecordingHttpClient { request ->
            val parameters = request.parameters()
            assertEquals("mod_assign_save_submission", parameters["wsfunction"])
            assertEquals("27625", parameters["assignmentid"])
            assertEquals("0", parameters["plugindata[files_filemanager]"])

            LmsHttpResponse(statusCode = 200, body = "[]")
        }
        val client = LmsWebServiceClient(session = session(userID = null), httpClient = httpClient)

        runSuspend {
            client.saveAssignmentSubmission(
                assignmentID = 27625,
                fileDraftItemID = 0,
            )
        }

        assertEquals(1, httpClient.requests.size)
    }

    @Test
    fun assignmentSubmissionStartAndRemovalDecodeResponses() {
        val httpClient = RecordingHttpClient { request ->
            val parameters = request.parameters()
            assertEquals("27625", parameters["assignid"])

            when (parameters["wsfunction"]) {
                "mod_assign_start_submission" -> LmsHttpResponse(
                    statusCode = 200,
                    body = """
                        {
                          "submissionid": 830437,
                          "warnings": [
                            {"warningcode": "opensubmissionexists", "message": "Already started"}
                          ]
                        }
                    """.trimIndent(),
                )

                "mod_assign_remove_submission" -> {
                    assertEquals("67797", parameters["userid"])
                    LmsHttpResponse(statusCode = 200, body = """{"status": true, "warnings": []}""")
                }

                else -> error("Unexpected wsfunction: ${parameters["wsfunction"]}")
            }
        }
        val client = LmsWebServiceClient(session = session(userID = null), httpClient = httpClient)

        val started = runSuspend {
            val response = client.startAssignmentSubmission(assignmentID = 27625)
            client.removeAssignmentSubmission(assignmentID = 27625, userID = 67797)
            response
        }

        assertEquals(830437, started.submissionID)
        assertEquals(
            listOf("mod_assign_start_submission", "mod_assign_remove_submission"),
            httpClient.requests.map { it.parameters()["wsfunction"] },
        )
    }

    @Test
    fun assignmentActionWarningsThrowMoodleError() {
        val httpClient = RecordingHttpClient {
            LmsHttpResponse(
                statusCode = 200,
                body = """
                    [
                      {
                        "warningcode": "cannotedit",
                        "message": "提出操作を完了できませんでした。"
                      }
                    ]
                """.trimIndent(),
            )
        }
        val client = LmsWebServiceClient(session = session(userID = null), httpClient = httpClient)

        val error = assertThrows(LmsWebServiceError.Moodle::class.java) {
            runSuspend { client.saveAssignmentSubmission(assignmentID = 27625) }
        }

        assertEquals("提出操作を完了できませんでした。", error.moodleMessage)
        assertEquals("cannotedit", error.debugInfo)
    }

    @Test
    fun fetchForumDiscussionsSendsForumID() {
        val httpClient = RecordingHttpClient { request ->
            val parameters = request.parameters()
            assertEquals("POST", request.method)
            assertEquals("mod_forum_get_forum_discussions", parameters["wsfunction"])
            assertEquals("777", parameters["forumid"])

            LmsHttpResponse(
                statusCode = 200,
                body = """
                    {
                      "discussions": [
                        {
                          "id": 60937,
                          "discussion": 28473,
                          "subject": "お知らせ",
                          "userfullname": "山本 寛"
                        }
                      ]
                    }
                """.trimIndent(),
            )
        }
        val client = LmsWebServiceClient(session = session(userID = null), httpClient = httpClient)

        val discussions = runSuspend { client.fetchForumDiscussions(forumID = 777) }

        assertEquals(1, discussions.size)
        assertEquals(28473, discussions[0].id)
        assertEquals(1, httpClient.requests.size)
    }

    @Test
    fun fetchDiscussionPostsSendsDiscussionIDAndAuthorizesAttachments() {
        val httpClient = RecordingHttpClient { request ->
            val parameters = request.parameters()
            assertEquals("mod_forum_get_discussion_posts", parameters["wsfunction"])
            assertEquals("28473", parameters["discussionid"])

            LmsHttpResponse(
                statusCode = 200,
                body = """
                    {
                      "posts": [
                        {
                          "id": 60937,
                          "discussionid": 28473,
                          "subject": "お知らせ",
                          "attachments": [
                            {
                              "filename": "guide.pdf",
                              "fileurl": "https://lms.example.test/pluginfile.php/1/guide.pdf"
                            },
                            {
                              "filename": "already.pdf",
                              "fileurl": "https://lms.example.test/pluginfile.php/1/already.pdf?token=already"
                            }
                          ]
                        }
                      ]
                    }
                """.trimIndent(),
            )
        }
        val client = LmsWebServiceClient(session = session(userID = null), httpClient = httpClient)

        val posts = runSuspend { client.fetchDiscussionPosts(discussionID = 28473) }

        assertEquals(
            "https://lms.example.test/pluginfile.php/1/guide.pdf?token=ws-token-123",
            posts[0].attachments[0].fileURL,
        )
        assertEquals(
            "https://lms.example.test/pluginfile.php/1/already.pdf?token=already",
            posts[0].attachments[1].fileURL,
        )
        assertEquals(1, httpClient.requests.size)
    }

    @Test
    fun markForumDiscussionViewedSendsDiscussionID() {
        val httpClient = RecordingHttpClient { request ->
            val parameters = request.parameters()
            assertEquals("mod_forum_view_forum_discussion", parameters["wsfunction"])
            assertEquals("28473", parameters["discussionid"])

            LmsHttpResponse(statusCode = 200, body = "{}")
        }
        val client = LmsWebServiceClient(session = session(userID = null), httpClient = httpClient)

        runSuspend { client.markForumDiscussionViewed(discussionID = 28473) }

        assertEquals(1, httpClient.requests.size)
    }

    @Test
    fun setFavouriteCoursesSendsCourseIDsAndStates() {
        val httpClient = RecordingHttpClient { request ->
            val parameters = request.parameters()
            assertEquals("POST", request.method)
            assertEquals("core_course_set_favourite_courses", parameters["wsfunction"])
            assertEquals("42", parameters["courses[0][id]"])
            assertEquals("1", parameters["courses[0][favourite]"])
            assertEquals("99", parameters["courses[1][id]"])
            assertEquals("0", parameters["courses[1][favourite]"])

            LmsHttpResponse(
                statusCode = 200,
                body = """{"warnings": []}""",
            )
        }
        val client = LmsWebServiceClient(session = session(userID = null), httpClient = httpClient)

        runSuspend {
            client.setFavouriteCourses(
                listOf(
                    FavouriteCourseUpdate(id = 42, isFavorite = true),
                    FavouriteCourseUpdate(id = 99, isFavorite = false),
                ),
            )
        }

        assertEquals(1, httpClient.requests.size)
    }

    @Test
    fun setFavouriteCoursesSkipsRequestWhenEmpty() {
        val httpClient = RecordingHttpClient {
            error("No request should be sent for an empty favorite update list")
        }
        val client = LmsWebServiceClient(session = session(userID = null), httpClient = httpClient)

        runSuspend { client.setFavouriteCourses(emptyList()) }

        assertTrue(httpClient.requests.isEmpty())
    }

    @Test
    fun setFavouriteCoursesWarningThrowsMoodleError() {
        val httpClient = RecordingHttpClient {
            LmsHttpResponse(
                statusCode = 200,
                body = """
                    {
                      "warnings": [
                        {
                          "warningcode": "cannotsetfavourite",
                          "message": "Favorite を更新できませんでした。"
                        }
                      ]
                    }
                """.trimIndent(),
            )
        }
        val client = LmsWebServiceClient(session = session(userID = null), httpClient = httpClient)

        val error = assertThrows(LmsWebServiceError.Moodle::class.java) {
            runSuspend {
                client.setFavouriteCourses(
                    listOf(FavouriteCourseUpdate(id = 42, isFavorite = true)),
                )
            }
        }

        assertEquals("Favorite を更新できませんでした。", error.moodleMessage)
        assertEquals("cannotsetfavourite", error.debugInfo)
    }

    @Test
    fun fetchPopupNotificationsSendsRequiredParameters() {
        val httpClient = RecordingHttpClient { request ->
            val parameters = request.parameters()
            assertEquals("POST", request.method)
            assertEquals("message_popup_get_popup_notifications", parameters["wsfunction"])
            assertEquals("0", parameters["useridto"])
            assertEquals("1", parameters["newestfirst"])
            assertEquals("0", parameters["limit"])
            assertEquals("0", parameters["offset"])

            LmsHttpResponse(
                statusCode = 200,
                body = """
                    {
                      "notifications": [],
                      "unreadcount": 0
                    }
                """.trimIndent(),
            )
        }
        val client = LmsWebServiceClient(session = session(userID = null), httpClient = httpClient)

        val response = runSuspend { client.fetchPopupNotifications() }

        assertTrue(response.notifications.isEmpty())
        assertEquals(0, response.unreadCount)
        assertEquals(1, httpClient.requests.size)
    }

    @Test
    fun fetchUnreadNotificationCountSendsSessionUserID() {
        val httpClient = RecordingHttpClient { request ->
            val parameters = request.parameters()
            assertEquals("core_message_get_unread_notification_count", parameters["wsfunction"])
            assertEquals("99", parameters["useridto"])

            LmsHttpResponse(statusCode = 200, body = "7")
        }
        val client = LmsWebServiceClient(session = session(userID = 99), httpClient = httpClient)

        val unreadCount = runSuspend { client.fetchUnreadNotificationCount() }

        assertEquals(7, unreadCount)
        assertEquals(1, httpClient.requests.size)
    }

    @Test
    fun fetchUnreadNotificationCountResolvesUserIDWhenSessionDoesNotHaveOne() {
        val httpClient = RecordingHttpClient { request ->
            when (request.parameters()["wsfunction"]) {
                "core_webservice_get_site_info" -> LmsHttpResponse(
                    statusCode = 200,
                    body = """
                        {
                          "sitename": "Moodle",
                          "siteurl": "https://lms.example.test",
                          "userid": 77,
                          "username": "is0000xx",
                          "fullname": "テスト 太郎"
                        }
                    """.trimIndent(),
                )

                "core_message_get_unread_notification_count" -> {
                    assertEquals("77", request.parameters()["useridto"])
                    LmsHttpResponse(statusCode = 200, body = "3")
                }

                else -> error("Unexpected wsfunction: ${request.parameters()["wsfunction"]}")
            }
        }
        val client = LmsWebServiceClient(session = session(userID = null), httpClient = httpClient)

        val unreadCount = runSuspend { client.fetchUnreadNotificationCount() }

        assertEquals(3, unreadCount)
        assertEquals(
            listOf("core_webservice_get_site_info", "core_message_get_unread_notification_count"),
            httpClient.requests.map { it.parameters()["wsfunction"] },
        )
    }

    @Test
    fun markNotificationReadSendsRequiredParameters() {
        val httpClient = RecordingHttpClient { request ->
            val parameters = request.parameters()
            assertEquals("core_message_mark_notification_read", parameters["wsfunction"])
            assertEquals("1201", parameters["notificationid"])
            assertEquals("1775700300", parameters["timeread"])

            LmsHttpResponse(statusCode = 200, body = "true")
        }
        val client = LmsWebServiceClient(session = session(userID = null), httpClient = httpClient)

        runSuspend {
            client.markNotificationRead(
                notificationID = 1201,
                timeRead = 1_775_700_300,
            )
        }

        assertEquals(1, httpClient.requests.size)
    }

    @Test
    fun markAllNotificationsReadSendsRequiredParameters() {
        val httpClient = RecordingHttpClient { request ->
            val parameters = request.parameters()
            assertEquals("core_message_mark_all_notifications_as_read", parameters["wsfunction"])
            assertEquals("99", parameters["useridto"])
            assertEquals("2", parameters["useridfrom"])
            assertEquals("1775700300", parameters["timecreatedto"])

            LmsHttpResponse(statusCode = 200, body = "true")
        }
        val client = LmsWebServiceClient(session = session(userID = 99), httpClient = httpClient)

        runSuspend {
            client.markAllNotificationsRead(
                userIDFrom = 2,
                timeCreatedTo = 1_775_700_300,
            )
        }

        assertEquals(1, httpClient.requests.size)
    }

    @Test
    fun fetchNotificationPreferencesOmitsUserIDAndDecodesProcessors() {
        val httpClient = RecordingHttpClient { request ->
            val parameters = request.parameters()
            assertEquals("core_message_get_user_notification_preferences", parameters["wsfunction"])
            assertFalse(parameters.containsKey("userid"))

            LmsHttpResponse(
                statusCode = 200,
                body = """
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
                                    "enabled": true
                                  }
                                ]
                              }
                            ]
                          }
                        ]
                      },
                      "warnings": []
                    }
                """.trimIndent(),
            )
        }
        val client = LmsWebServiceClient(session = session(userID = 123), httpClient = httpClient)

        val preferences = runSuspend { client.fetchNotificationPreferences() }

        assertEquals(123, preferences.userID)
        assertTrue(preferences.enableAll)
        assertEquals("airnotifier", preferences.processors.firstOrNull()?.name)
        assertEquals(
            true,
            preferences.components.firstOrNull()
                ?.notifications
                ?.firstOrNull()
                ?.processor("airnotifier")
                ?.enabled,
        )
    }

    @Test
    fun fetchMessagePreferencesDecodesPrivacyAndInstantMessageProcessors() {
        val httpClient = RecordingHttpClient { request ->
            val parameters = request.parameters()
            assertEquals("core_message_get_user_message_preferences", parameters["wsfunction"])

            LmsHttpResponse(
                statusCode = 200,
                body = """
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
                """.trimIndent(),
            )
        }
        val client = LmsWebServiceClient(session = session(userID = 123), httpClient = httpClient)

        val preferences = runSuspend { client.fetchMessagePreferences() }

        assertEquals(1, preferences.blockNonContacts)
        assertEquals(true, preferences.enterToSend)
        assertEquals(123, preferences.notificationPreferences.userID)
        assertEquals(
            "message_provider_moodle_instantmessage",
            preferences.notificationPreferences.components.firstOrNull()?.notifications?.firstOrNull()?.preferenceKey,
        )
        assertEquals(
            true,
            preferences.notificationPreferences.components.first().notifications.first().processors.first().enabled,
        )
    }

    @Test
    fun updateUserPreferencesSendsPreferenceListAndEmailStop() {
        val httpClient = RecordingHttpClient { request ->
            val parameters = request.parameters()
            assertEquals("core_user_update_user_preferences", parameters["wsfunction"])
            assertEquals("123", parameters["userid"])
            assertEquals("0", parameters["emailstop"])
            assertEquals(
                "message_provider_mod_assign_assign_notification_enabled",
                parameters["preferences[0][type]"],
            )
            assertEquals("airnotifier,popup", parameters["preferences[0][value]"])
            assertEquals("message_provider_mod_forum_posts_enabled", parameters["preferences[1][type]"])
            assertEquals("none", parameters["preferences[1][value]"])

            LmsHttpResponse(statusCode = 200, body = "null")
        }
        val client = LmsWebServiceClient(session = session(userID = 123), httpClient = httpClient)

        runSuspend {
            client.updateUserPreferences(
                preferences = listOf(
                    UserPreferenceUpdate(
                        type = "message_provider_mod_assign_assign_notification_enabled",
                        value = "airnotifier,popup",
                    ),
                    UserPreferenceUpdate(
                        type = "message_provider_mod_forum_posts_enabled",
                        value = "none",
                    ),
                ),
                disableNotifications = false,
            )
        }

        assertEquals(1, httpClient.requests.size)
    }

    @Test
    fun fetchUserPreferencesDecodesNumericPreferenceValues() {
        val httpClient = RecordingHttpClient { request ->
            val parameters = request.parameters()
            assertEquals("core_user_get_user_preferences", parameters["wsfunction"])
            assertEquals("calendar_timeformat", parameters["name"])

            LmsHttpResponse(
                statusCode = 200,
                body = """
                    {
                      "preferences": [
                        {
                          "name": "message_provider_mod_assign_assign_notification_enabled",
                          "value": "popup,email,airnotifier"
                        },
                        {
                          "name": "_lastloaded",
                          "value": 1780502575
                        },
                        {
                          "name": "boolish",
                          "value": false
                        }
                      ],
                      "warnings": []
                    }
                """.trimIndent(),
            )
        }
        val client = LmsWebServiceClient(session = session(userID = 123), httpClient = httpClient)

        val preferences = runSuspend { client.fetchUserPreferences(name = "calendar_timeformat") }

        assertEquals("1780502575", preferences.first { it.name == "_lastloaded" }.value)
        assertEquals("0", preferences.first { it.name == "boolish" }.value)
    }

    @Test
    fun makeCalendarSubscriptionBuildsMoodleExportURL() {
        val httpClient = RecordingHttpClient { request ->
            val parameters = request.parameters()
            assertEquals("core_calendar_get_calendar_export_token", parameters["wsfunction"])

            LmsHttpResponse(
                statusCode = 200,
                body = """
                    {
                      "token": "calendar-export-token",
                      "warnings": []
                    }
                """.trimIndent(),
            )
        }
        val client = LmsWebServiceClient(session = session(userID = 123), httpClient = httpClient)

        val subscription = runSuspend { client.makeCalendarSubscription() }
        val parameters = subscription.uri.rawQuery
            .split("&")
            .associate { pair ->
                val separator = pair.indexOf('=')
                pair.substring(0, separator).formDecoded() to pair.substring(separator + 1).formDecoded()
            }

        assertEquals("https", subscription.uri.scheme)
        assertEquals("lms.example.test", subscription.uri.host)
        assertEquals("/calendar/export_execute.php", subscription.uri.path)
        assertEquals("123", parameters["userid"])
        assertEquals("calendar-export-token", parameters["authtoken"])
        assertEquals("all", parameters["preset_what"])
        assertEquals("recentupcoming", parameters["preset_time"])
        assertEquals("webcal", subscription.webcalURI.scheme)
        assertEquals("lms.example.test", subscription.webcalURI.host)
    }

    @Test
    fun fetchNotificationPreferencesFallsBackWhenMoodleReturnsInvalidResponse() {
        val httpClient = RecordingHttpClient { request ->
            when (val wsFunction = request.parameters()["wsfunction"]) {
                "core_message_get_user_notification_preferences" -> LmsHttpResponse(
                    statusCode = 200,
                    body = """
                        {
                          "exception": "core\\exception\\invalid_response_exception",
                          "errorcode": "invalidresponse",
                          "message": "無効なレスポンス値が検知されました。"
                        }
                    """.trimIndent(),
                )

                "core_webservice_get_site_info" -> LmsHttpResponse(
                    statusCode = 200,
                    body = """
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
                    """.trimIndent(),
                )

                "core_user_get_user_preferences" -> LmsHttpResponse(
                    statusCode = 200,
                    body = """
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
                    """.trimIndent(),
                )

                else -> error("Unexpected wsfunction: $wsFunction")
            }
        }
        val client = LmsWebServiceClient(session = session(userID = null), httpClient = httpClient)

        val preferences = runSuspend { client.fetchNotificationPreferences() }

        assertEquals(
            listOf(
                "core_message_get_user_notification_preferences",
                "core_webservice_get_site_info",
                "core_user_get_user_preferences",
            ),
            httpClient.requests.map { it.parameters()["wsfunction"] },
        )
        assertEquals(123, preferences.userID)
        assertEquals(listOf("popup", "email", "airnotifier"), preferences.processors.map { it.name })

        val assignmentNotification = preferences.components
            .first { it.displayName == "課題" }
            .notifications
            .first { it.preferenceKey == "message_provider_mod_assign_assign_notification" }
        assertEquals(false, assignmentNotification.processor("popup")?.enabled)
        assertEquals(true, assignmentNotification.processor("email")?.enabled)
        assertEquals(true, assignmentNotification.processor("airnotifier")?.enabled)

        val forumPosts = preferences.components
            .first { it.displayName == "フォーラム" }
            .notifications
            .first { it.preferenceKey == "message_provider_mod_forum_posts" }
        assertEquals(true, forumPosts.processor("popup")?.enabled)
        assertEquals(false, forumPosts.processor("email")?.enabled)
        assertEquals(true, forumPosts.processor("airnotifier")?.enabled)

        val messageTeacher = preferences.components.first { it.displayName == "私の先生にメッセージ" }
        assertEquals("授業コード、授業名（曜日時限）、学生証番号を明記して送信すること", messageTeacher.description)
    }

    @Test
    fun decodeMoodleErrorEnvelope() {
        val httpClient = RecordingHttpClient {
            LmsHttpResponse(
                statusCode = 200,
                body = """
                    {
                      "exception": "moodle_exception",
                      "errorcode": "invalidtoken",
                      "message": "Invalid token",
                      "debuginfo": "Token not found"
                    }
                """.trimIndent(),
            )
        }
        val client = LmsWebServiceClient(session = session(userID = null), httpClient = httpClient)

        val error = assertThrows(LmsWebServiceError.Moodle::class.java) {
            runSuspend { client.fetchSiteInfo() }
        }

        assertEquals("Invalid token", error.moodleMessage)
        assertEquals("Token not found", error.debugInfo)
    }

    @Test
    fun classifyHttpErrorBeforeDecoding() {
        val httpClient = RecordingHttpClient {
            LmsHttpResponse(statusCode = 500, body = "server down")
        }
        val client = LmsWebServiceClient(session = session(userID = null), httpClient = httpClient)

        val error = assertThrows(LmsWebServiceError.Http::class.java) {
            runSuspend { client.fetchSiteInfo() }
        }

        assertEquals(500, error.statusCode)
        assertEquals("server down", error.response)
    }

    @Test
    fun fetchTimetableSnapshotSkipsSiteInfoAndFallsBackWhenDashboardFails() {
        val httpClient = RecordingHttpClient { request ->
            when (request.parameters()["wsfunction"]) {
                "core_enrol_get_users_courses" -> LmsHttpResponse(
                    statusCode = 200,
                    body = """
                        [
                          {
                            "id": 42,
                            "fullname": "Software Engineering",
                            "shortname": "2026-50001"
                          }
                        ]
                    """.trimIndent(),
                )

                "core_block_get_dashboard_blocks" -> throw IllegalStateException("dashboard unavailable")

                else -> error("Unexpected wsfunction: ${request.parameters()["wsfunction"]}")
            }
        }
        val client = LmsWebServiceClient(session = session(userID = 99), httpClient = httpClient)

        val snapshot = runSuspend { client.fetchTimetableSnapshot() }

        assertEquals("https://lms.example.test", snapshot.siteURL)
        assertEquals(99, snapshot.userID)
        assertEquals(1, snapshot.courses.size)
        assertTrue(snapshot.dashboardBlocks.isEmpty())
        assertEquals(
            listOf("core_enrol_get_users_courses", "core_block_get_dashboard_blocks"),
            httpClient.requests.map { it.parameters()["wsfunction"] },
        )
    }

    @Test
    fun fetchTimetableSnapshotResolvesUserIDWhenSessionDoesNotHaveOne() {
        val httpClient = RecordingHttpClient { request ->
            when (request.parameters()["wsfunction"]) {
                "core_webservice_get_site_info" -> LmsHttpResponse(
                    statusCode = 200,
                    body = """
                        {
                          "sitename": "Moodle",
                          "siteurl": "https://lms.example.test",
                          "userid": 77,
                          "username": "is0000xx",
                          "fullname": "テスト 太郎"
                        }
                    """.trimIndent(),
                )

                "core_enrol_get_users_courses" -> {
                    assertEquals("77", request.parameters()["userid"])
                    LmsHttpResponse(statusCode = 200, body = "[]")
                }

                "core_block_get_dashboard_blocks" -> LmsHttpResponse(
                    statusCode = 200,
                    body = """{"blocks": []}""",
                )

                else -> error("Unexpected wsfunction: ${request.parameters()["wsfunction"]}")
            }
        }
        val client = LmsWebServiceClient(session = session(userID = null), httpClient = httpClient)

        val snapshot = runSuspend { client.fetchTimetableSnapshot() }

        assertEquals(77, snapshot.userID)
        assertTrue(snapshot.courses.isEmpty())
        assertTrue(snapshot.dashboardBlocks.isEmpty())
        assertEquals(
            listOf(
                "core_webservice_get_site_info",
                "core_enrol_get_users_courses",
                "core_block_get_dashboard_blocks",
            ),
            httpClient.requests.map { it.parameters()["wsfunction"] },
        )
    }

    private fun session(userID: Int?): LmsWebServiceSession =
        LmsWebServiceSession(
            siteURL = "https://lms.example.test",
            token = "ws-token-123",
            userID = userID,
        )

    private class RecordingHttpClient(
        private val handler: (LmsHttpRequest) -> LmsHttpResponse,
    ) : LmsHttpClient {
        val requests = mutableListOf<LmsHttpRequest>()

        override suspend fun send(request: LmsHttpRequest): LmsHttpResponse {
            requests += request
            return handler(request)
        }
    }

    private companion object {
        val json: Json = Json {
            ignoreUnknownKeys = true
            explicitNulls = false
        }

        fun LmsHttpRequest.parameters(): Map<String, String> {
            val encoded = bodyText ?: url.rawQuery.orEmpty()
            if (encoded.isEmpty()) {
                return emptyMap()
            }

            return encoded.split("&").associate { pair ->
                val separator = pair.indexOf('=')
                if (separator < 0) {
                    pair.formDecoded() to ""
                } else {
                    pair.substring(0, separator).formDecoded() to pair.substring(separator + 1).formDecoded()
                }
            }
        }

        fun String.formDecoded(): String =
            URLDecoder.decode(this, Charsets.UTF_8)

        fun <T> runSuspend(block: suspend () -> T): T {
            val latch = CountDownLatch(1)
            var value: T? = null
            var failure: Throwable? = null

            block.startCoroutine(
                object : Continuation<T> {
                    override val context = EmptyCoroutineContext

                    override fun resumeWith(result: Result<T>) {
                        result.fold(
                            onSuccess = { value = it },
                            onFailure = { failure = it },
                        )
                        latch.countDown()
                    }
                },
            )

            latch.await()
            failure?.let { throw it }
            @Suppress("UNCHECKED_CAST")
            return value as T
        }
    }
}
