import Testing

@testable import MoodleNativeCore

@MainActor
struct TimetableSummaryParserTests {
    @Test func parseJapaneseSpringSemester() {
        let summary = "2026 53374:ユーザビリティ工学 春セメスター:春セメ・月2(3-4)"

        let semester = TimetableSummaryParser.parseAcademicSemester(summary: summary)

        #expect(semester == AcademicSemester(academicYear: 2026, season: .spring))
    }

    @Test func parseEnglishFallSemester() {
        let summary = "2026 53374:Usability Engineering Fall:F Mon2(3-4)"

        let semester = TimetableSummaryParser.parseAcademicSemester(summary: summary)

        #expect(semester == AcademicSemester(academicYear: 2026, season: .fall))
    }

    @Test func parseUnknownSemesterWhenSeasonIsMissing() {
        let summary = "2026 53374:オンデマンド授業"

        let semester = TimetableSummaryParser.parseAcademicSemester(summary: summary)

        #expect(semester == AcademicSemester(academicYear: 2026, season: .unknown))
    }
}
