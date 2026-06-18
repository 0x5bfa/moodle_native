import Foundation
import MoodleNativeCore
import MoodleNativeNetworking
import Testing

@testable import MoodleNative

@MainActor
struct AssignmentsViewModelTests {
    @Test func incompleteAssignmentsExcludeCompletedItems() {
        let assignments = [
            LmsAssignmentItem(
                id: 1,
                courseID: 10,
                courseModuleID: 101,
                courseTitle: "情報処理",
                courseShortName: "2026-50002",
                title: "第1回課題",
                introPreview: nil,
                dueDate: nil,
                allowsSubmissionsFromDate: nil,
                cutoffDate: nil,
                updatedAt: nil
            ),
            LmsAssignmentItem(
                id: 2,
                courseID: 10,
                courseModuleID: 102,
                courseTitle: "情報処理",
                courseShortName: "2026-50002",
                title: "第2回課題",
                introPreview: nil,
                dueDate: nil,
                allowsSubmissionsFromDate: nil,
                cutoffDate: nil,
                updatedAt: nil
            ),
        ]

        let visibleAssignments = AssignmentsViewModel.incompleteAssignments(
            from: assignments,
            completedAssignmentIDs: [2]
        )

        #expect(visibleAssignments.map(\.id) == [1])
    }

    @Test func completedSubmissionIncludesTeamSubmission() throws {
        let data = Data(
            """
            {
              "lastattempt": {
                "teamsubmission": {
                  "id": 501,
                  "userid": 99,
                  "attemptnumber": 1,
                  "timecreated": 1775600000,
                  "timemodified": 1775600300,
                  "status": "submitted",
                  "groupid": 1,
                  "plugins": []
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
                "usergroups": []
              },
              "warnings": []
            }
            """.utf8
        )

        let response = try JSONDecoder().decode(
            LmsWebServiceClient.AssignmentSubmissionStatus.self,
            from: data
        )

        #expect(response.hasCompletedSubmission)
    }
}
