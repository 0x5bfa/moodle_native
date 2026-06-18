import Foundation
import MoodleNativeCore
import MoodleNativeFeatures
import Testing
import MoodleNativeNetworking

@testable import MoodleNativeFeatures

@MainActor
struct LmsAssignmentReferenceTests {
    @Test func mergeCourseModuleAddsCompletionRequirementsAndFallbackURL() throws {
        let reference = LmsAssignmentReference(
            assignmentID: 301,
            courseModuleID: 201,
            courseID: 42,
            courseTitle: "ソフトウェア工学",
            courseShortName: "2026-50001",
            title: "第1回課題",
            introPreview: nil,
            dueDate: nil,
            allowsSubmissionsFromDate: nil,
            cutoffDate: nil,
            updatedAt: nil,
            detailURL: nil,
            completionRequirements: []
        )

        let module = try JSONDecoder().decode(
            LmsWebServiceClient.CourseModule.self,
            from: Data(
                """
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
                    "state": 0,
                    "hascompletion": true,
                    "uservisible": true,
                    "details": [
                      {
                        "rulename": "completionsubmit",
                        "rulevalue": {
                          "status": 0,
                          "description": "提出する"
                        }
                      }
                    ],
                    "isoverallcomplete": false
                  },
                  "contents": [],
                  "dates": []
                }
                """.utf8
            )
        )

        let merged = reference.merging(courseModule: module)

        #expect(
            merged.detailURL?.absoluteString
                == "https://lms.example.test/mod/assign/view.php?id=201"
        )
        #expect(merged.completionRequirements.map(\.text) == ["提出する"])
        #expect(merged.completionRequirements.map(\.isComplete) == [false])
    }

    @Test func assignmentOverviewHelpersHandleTrimmedValues() {
        let emptyReference = LmsAssignmentReference(
            assignmentID: 1,
            courseModuleID: 101,
            courseID: 10,
            courseTitle: "  ",
            courseShortName: "2026-50001",
            title: "課題",
            introPreview: "   ",
            dueDate: nil,
            allowsSubmissionsFromDate: nil,
            cutoffDate: nil,
            updatedAt: nil,
            detailURL: nil,
            completionRequirements: []
        )

        #expect(emptyReference.displayCourseTitle == nil)
        #expect(emptyReference.hasOverviewDetails == false)

        let populatedReference = LmsAssignmentReference(
            assignmentID: 2,
            courseModuleID: 102,
            courseID: 10,
            courseTitle: "ソフトウェア工学",
            courseShortName: "2026-50001",
            title: "課題",
            introPreview: nil,
            dueDate: nil,
            allowsSubmissionsFromDate: nil,
            cutoffDate: Date(timeIntervalSince1970: 1_750_000_000),
            updatedAt: nil,
            detailURL: nil,
            completionRequirements: []
        )

        #expect(populatedReference.displayCourseTitle == "ソフトウェア工学")
        #expect(populatedReference.hasOverviewDetails)
    }
}
