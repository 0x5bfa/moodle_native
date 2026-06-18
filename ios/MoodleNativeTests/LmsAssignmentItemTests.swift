import Foundation
import MoodleNativeCore
import MoodleNativeFeatures
import Testing

@testable import MoodleNative

struct LmsAssignmentItemTests {
    @Test func buildAssignmentReferenceDetailURL() {
        let assignment = LmsAssignmentItem(
            id: 42,
            courseID: 10,
            courseModuleID: 314,
            courseTitle: "ソフトウェア工学",
            courseShortName: "2026-50001",
            title: "レポート課題",
            introPreview: "本文",
            dueDate: nil,
            allowsSubmissionsFromDate: nil,
            cutoffDate: nil,
            updatedAt: nil
        )

        let reference = assignment.reference(siteURL: "https://lms.example.test")

        #expect(reference.assignmentID == 42)
        #expect(reference.courseModuleID == 314)
        #expect(
            reference.detailURL?.absoluteString == "https://lms.example.test/mod/assign/view.php?id=314")
        #expect(reference.completionRequirements.isEmpty)
    }

    @MainActor
    @Test func orderAssignmentsForFlatList() {
        let now = Date(timeIntervalSince1970: 1_745_000_000)

        let assignments = [
            LmsAssignmentItem(
                id: 1,
                courseID: 10,
                courseModuleID: 101,
                courseTitle: "情報処理",
                courseShortName: "2026-50002",
                title: "期限切れA",
                introPreview: nil,
                dueDate: now.addingTimeInterval(-60),
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
                title: "期限切れB",
                introPreview: nil,
                dueDate: now.addingTimeInterval(-10),
                allowsSubmissionsFromDate: nil,
                cutoffDate: nil,
                updatedAt: nil
            ),
            LmsAssignmentItem(
                id: 3,
                courseID: 11,
                courseModuleID: 103,
                courseTitle: "英語",
                courseShortName: "2026-50003",
                title: "これからB",
                introPreview: nil,
                dueDate: now.addingTimeInterval(120),
                allowsSubmissionsFromDate: nil,
                cutoffDate: nil,
                updatedAt: nil
            ),
            LmsAssignmentItem(
                id: 4,
                courseID: 11,
                courseModuleID: 104,
                courseTitle: "英語",
                courseShortName: "2026-50003",
                title: "これからA",
                introPreview: nil,
                dueDate: now.addingTimeInterval(30),
                allowsSubmissionsFromDate: nil,
                cutoffDate: nil,
                updatedAt: nil
            ),
            LmsAssignmentItem(
                id: 5,
                courseID: 12,
                courseModuleID: 105,
                courseTitle: "化学",
                courseShortName: "2026-50004",
                title: "期限未設定B",
                introPreview: nil,
                dueDate: nil,
                allowsSubmissionsFromDate: nil,
                cutoffDate: nil,
                updatedAt: now.addingTimeInterval(-5),
            ),
            LmsAssignmentItem(
                id: 6,
                courseID: 11,
                courseModuleID: 106,
                courseTitle: "英語",
                courseShortName: "2026-50003",
                title: "期限未設定A",
                introPreview: nil,
                dueDate: nil,
                allowsSubmissionsFromDate: nil,
                cutoffDate: nil,
                updatedAt: now
            ),
        ]

        let ordered = AssignmentsViewModel.orderedAssignments(from: assignments, now: now)

        #expect(ordered.map(\.id) == [2, 1, 4, 3, 6, 5])
    }

    @Test func buildRelativeDateLines() {
        let now = Date(timeIntervalSince1970: 1_745_000_000)
        let assignment = LmsAssignmentItem(
            id: 10,
            courseID: 20,
            courseModuleID: 30,
            courseTitle: "ソフトウェア工学",
            courseShortName: "2026-50001",
            title: "第3回課題",
            introPreview: nil,
            dueDate: now.addingTimeInterval(7_200),
            allowsSubmissionsFromDate: now.addingTimeInterval(-10_800),
            cutoffDate: nil,
            updatedAt: nil
        )

        let dueDateLine = assignment.dueDateLine(relativeTo: now)
        #expect(dueDateLine.isEmpty == false)
        #expect(dueDateLine.contains("後"))
    }
}
