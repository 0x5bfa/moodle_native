import Foundation
import Testing

@testable import MoodleNativeCore

struct LmsAssignmentItemTests {
    @Test func classifyDueBuckets() {
        let now = Date(timeIntervalSince1970: 1_745_000_000)

        let overdue = LmsAssignmentItem(
            id: 1,
            courseID: 10,
            courseModuleID: 101,
            courseTitle: "ソフトウェア工学",
            courseShortName: "2026-50001",
            title: "第1回課題",
            introPreview: nil,
            dueDate: now.addingTimeInterval(-60),
            allowsSubmissionsFromDate: nil,
            cutoffDate: nil,
            updatedAt: nil
        )
        let upcoming = LmsAssignmentItem(
            id: 2,
            courseID: 10,
            courseModuleID: 102,
            courseTitle: "ソフトウェア工学",
            courseShortName: "2026-50001",
            title: "第2回課題",
            introPreview: nil,
            dueDate: now.addingTimeInterval(60),
            allowsSubmissionsFromDate: nil,
            cutoffDate: nil,
            updatedAt: nil
        )
        let undated = LmsAssignmentItem(
            id: 3,
            courseID: 10,
            courseModuleID: 103,
            courseTitle: "ソフトウェア工学",
            courseShortName: "2026-50001",
            title: "レポート",
            introPreview: nil,
            dueDate: nil,
            allowsSubmissionsFromDate: nil,
            cutoffDate: nil,
            updatedAt: nil
        )

        #expect(overdue.dueBucket(now: now) == .overdue)
        #expect(upcoming.dueBucket(now: now) == .upcoming)
        #expect(undated.dueBucket(now: now) == .undated)
        #expect(overdue.dueBucket(now: now).sectionTitle == "期限切れ")
        #expect(upcoming.dueBucket(now: now).sectionTitle == "これからの課題")
        #expect(undated.dueBucket(now: now).sectionTitle == "期限未設定")
    }
}
