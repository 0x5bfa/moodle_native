import Foundation
import MoodleNativeCore
import MoodleNativeFeatures
import MoodleNativeNetworking
import Testing

@testable import MoodleNative

@MainActor
struct CourseDetailViewModelTests {
    @Test func buildSectionPresentationsFromCourseContents() throws {
        let sections = try JSONDecoder().decode(
            [LmsWebServiceClient.CourseSection].self,
            from: Data(Self.sampleSectionsJson.utf8)
        )

        let presentations = CourseDetailViewModel.makeSectionPresentations(
            from: sections,
            courseID: 42,
            courseTitle: "ソフトウェア工学",
            courseShortName: "2026-50001"
        )

        let section = try #require(presentations.first)
        #expect(section.title == "セクション 3")
        #expect(section.modules.count == 5)

        let forum = try #require(section.modules.first(where: { $0.id == 200 }))
        #expect(forum.typeName == "フォーラム")
        #expect(forum.iconName == "bubble.left.and.bubble.right")
        #expect(forum.showsNavigationIndicator)
        #expect(forum.showsExternalIndicator == false)
        #expect(forum.dateLines.count == 1)
        #expect(forum.completion?.progress == 0.5)
        #expect(forum.completion?.completedRequirementCount == 1)
        #expect(forum.completion?.totalRequirementCount == 2)
        #expect(forum.completion?.isComplete == false)

        switch try #require(forum.primaryAction) {
        case .forum(let reference):
            #expect(reference.forumID == 300)
            #expect(reference.courseModuleID == 200)
            #expect(reference.title == "お知らせ")
            #expect(reference.completionRequirements.map(\.text) == ["閲覧する", "投稿する: 1"])
            #expect(reference.completionRequirements.map(\.isComplete) == [true, false])
        default:
            Issue.record("Expected forum primary action")
        }

        let assignment = try #require(section.modules.first(where: { $0.id == 201 }))
        #expect(assignment.typeName == "課題")
        #expect(assignment.iconName == "checklist")
        #expect(assignment.attachmentCount == 1)
        #expect(assignment.contentNodes.count == 1)
        #expect(assignment.contentNodes.first?.title == "課題要項.pdf")
        #expect(assignment.contentNodes.first?.isFolder == false)
        #expect(assignment.showsNavigationIndicator)
        #expect(assignment.completion?.progress == 1)
        #expect(assignment.completion?.isComplete == true)
        #expect(assignment.completion?.accessibilityLabel == "完了")

        switch try #require(assignment.primaryAction) {
        case .assignment(let reference):
            #expect(reference.assignmentID == 301)
            #expect(reference.courseID == 42)
            #expect(reference.courseTitle == "ソフトウェア工学")
            #expect(reference.courseShortName == "2026-50001")
            #expect(reference.completionRequirements.map(\.text) == ["提出する"])
            #expect(reference.completionRequirements.map(\.isComplete) == [true])
        default:
            Issue.record("Expected assignment primary action")
        }

        let page = try #require(section.modules.first(where: { $0.id == 202 }))
        #expect(page.typeName == "ページ")
        #expect(page.iconName == "doc.plaintext")
        #expect(page.showsExternalIndicator)
        #expect(page.showsNavigationIndicator == false)
        #expect(page.completion == nil)

        switch try #require(page.primaryAction) {
        case .resource(let url):
            #expect(url.absoluteString == "https://lms.example.test/mod/page/view.php?id=202")
        default:
            Issue.record("Expected resource primary action")
        }

        let folder = try #require(section.modules.first(where: { $0.id == 203 }))
        #expect(folder.typeName == "フォルダー")
        #expect(folder.iconName == "folder")
        #expect(folder.attachmentCount == 3)
        #expect(folder.showsExternalIndicator == false)
        #expect(folder.showsNavigationIndicator == false)
        #expect(folder.contentNodes.map(\.title) == ["講義資料", "README.txt"])
        #expect(folder.completion?.progress == 0)
        #expect(folder.completion?.isComplete == false)

        let lectureFolder = try #require(folder.contentNodes.first(where: { $0.title == "講義資料" }))
        #expect(lectureFolder.isFolder)
        #expect(lectureFolder.children.map(\.title) == ["第1回", "第2回"])

        let firstLecture = try #require(lectureFolder.children.first(where: { $0.title == "第1回" }))
        #expect(firstLecture.isFolder)
        #expect(firstLecture.children.map(\.title) == ["slide1.pdf"])

        let secondLecture = try #require(lectureFolder.children.first(where: { $0.title == "第2回" }))
        #expect(secondLecture.isFolder)
        #expect(secondLecture.children.map(\.title) == ["slide2.pdf"])

        let lti = try #require(section.modules.first(where: { $0.id == 204 }))
        #expect(lti.typeName == "LTI動画")
        #expect(lti.iconName == "play.rectangle")
        #expect(lti.showsExternalIndicator)
        #expect(lti.showsNavigationIndicator == false)
        #expect(lti.completion == nil)

        switch try #require(lti.primaryAction) {
        case .resource(let url):
            #expect(url.absoluteString == "https://lms.example.test/mod/lti/view.php?id=204")
        default:
            Issue.record("Expected LTI primary action")
        }
    }

    @Test func buildSectionPresentationsUsesAssignmentMetadataWhenAvailable() throws {
        let sections = try JSONDecoder().decode(
            [LmsWebServiceClient.CourseSection].self,
            from: Data(Self.sampleSectionsJson.utf8)
        )
        let dueDate = Date(timeIntervalSince1970: 1_776_931_200)
        let startDate = Date(timeIntervalSince1970: 1_776_399_000)
        let cutoffDate = Date(timeIntervalSince1970: 1_777_647_600)

        let presentations = CourseDetailViewModel.makeSectionPresentations(
            from: sections,
            courseID: 42,
            courseTitle: "ソフトウェア工学",
            courseShortName: "2026-50001",
            assignmentReferencesByID: [
                301: LmsAssignmentReference(
                    assignmentID: 301,
                    courseModuleID: 201,
                    courseID: 42,
                    courseTitle: "ソフトウェア工学",
                    courseShortName: "2026-50001",
                    title: "第1回課題",
                    introPreview: "配列の動作を確認する",
                    dueDate: dueDate,
                    allowsSubmissionsFromDate: startDate,
                    cutoffDate: cutoffDate,
                    updatedAt: nil,
                    detailURL: nil,
                    completionRequirements: []
                )
            ]
        )

        let section = try #require(presentations.first)
        let assignment = try #require(section.modules.first(where: { $0.id == 201 }))

        switch try #require(assignment.primaryAction) {
        case .assignment(let reference):
            #expect(reference.assignmentID == 301)
            #expect(reference.courseID == 42)
            #expect(reference.introPreview == "配列の動作を確認する")
            #expect(reference.dueDate == dueDate)
            #expect(reference.allowsSubmissionsFromDate == startDate)
            #expect(reference.cutoffDate == cutoffDate)
            #expect(reference.detailURL?.absoluteString == "https://lms.example.test/mod/assign/view.php?id=201")
            #expect(reference.completionRequirements.map(\.text) == ["提出する"])
        default:
            Issue.record("Expected assignment primary action")
        }
    }

    private static let sampleSectionsJson = """
        [
          {
            "id": 100,
            "section": 3,
            "name": "",
            "summary": null,
            "modules": [
              {
                "id": 200,
                "instance": 300,
                "modname": "forum",
                "name": "お知らせ",
                "url": "https://lms.example.test/mod/forum/view.php?id=200",
                "modicon": null,
                "purpose": null,
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
                      "rulename": "completionposts",
                      "rulevalue": {
                        "status": 0,
                        "description": "投稿する: 1"
                      }
                    }
                  ],
                  "isoverallcomplete": false
                },
                "contents": [],
                "dates": [
                  {
                    "label": "更新",
                    "timestamp": 1740000000,
                    "dataid": "date-1"
                  }
                ]
              },
              {
                "id": 201,
                "instance": 301,
                "modname": "assign",
                "name": "第1回課題",
                "url": "https://lms.example.test/mod/assign/view.php?id=201",
                "modicon": null,
                "purpose": null,
                "completion": 2,
                "completiondata": {
                  "state": 1,
                  "hascompletion": true,
                  "uservisible": true,
                  "details": [
                    {
                      "rulename": "completionsubmit",
                      "rulevalue": {
                        "status": 1,
                        "description": "提出する"
                      }
                    }
                  ],
                  "isoverallcomplete": true
                },
                "contents": [
                  {
                    "type": "file",
                    "filename": "課題要項.pdf",
                    "filepath": "/",
                    "filesize": 12345,
                    "fileurl": "https://lms.example.test/pluginfile.php/1/mod_assign/intro/0/guide.pdf",
                    "mimetype": "application/pdf",
                    "timemodified": 1740000001
                  }
                ],
                "dates": []
              },
              {
                "id": 202,
                "instance": 302,
                "modname": "page",
                "name": "授業ガイド",
                "url": "https://lms.example.test/mod/page/view.php?id=202",
                "modicon": null,
                "purpose": null,
                "contents": [],
                "dates": []
              },
              {
                "id": 203,
                "instance": 303,
                "modname": "folder",
                "name": "講義資料",
                "url": "https://lms.example.test/mod/folder/view.php?id=203",
                "modicon": null,
                "purpose": null,
                "completion": 2,
                "completiondata": {
                  "state": 0,
                  "hascompletion": true,
                  "uservisible": true,
                  "details": [
                    {
                      "rulename": "completionview",
                      "rulevalue": {
                        "status": 0,
                        "description": "閲覧する"
                      }
                    }
                  ],
                  "isoverallcomplete": false
                },
                "contents": [
                  {
                    "type": "file",
                    "filename": "slide1.pdf",
                    "filepath": "/講義資料/第1回/",
                    "filesize": 12345,
                    "fileurl": "https://lms.example.test/pluginfile.php/1/mod_folder/content/1/lecture1/slide1.pdf",
                    "mimetype": "application/pdf",
                    "timemodified": 1740000002
                  },
                  {
                    "type": "file",
                    "filename": "slide2.pdf",
                    "filepath": "/講義資料/第2回/",
                    "filesize": 12345,
                    "fileurl": "https://lms.example.test/pluginfile.php/1/mod_folder/content/1/lecture2/slide2.pdf",
                    "mimetype": "application/pdf",
                    "timemodified": 1740000003
                  },
                  {
                    "type": "file",
                    "filename": "README.txt",
                    "filepath": "/",
                    "filesize": 128,
                    "fileurl": "https://lms.example.test/pluginfile.php/1/mod_folder/content/1/readme.txt",
                    "mimetype": "text/plain",
                    "timemodified": 1740000004
                  }
                ],
                "dates": []
              },
              {
                "id": 204,
                "instance": 304,
                "modname": "lti",
                "name": "講義動画 1",
                "url": "https://lms.example.test/mod/lti/view.php?id=204",
                "modicon": null,
                "purpose": null,
                "contents": [],
                "dates": []
              }
            ]
          }
        ]
        """
}
