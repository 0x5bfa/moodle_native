import Foundation

public enum TimetableSummaryParser {
    public static func parseAcademicSemester(
        summary: String?,
        fallbackText: String? = nil
    ) -> AcademicSemester? {
        let combined = [summary, fallbackText]
            .compactMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard combined.isEmpty == false else {
            return nil
        }

        let academicYearPattern = /(20\d{2})/
        let academicYear = combined.firstMatch(of: academicYearPattern).flatMap { Int($0.output.1) }
        let lowercased = combined.lowercased()

        let season: SemesterSeason
        if combined.contains("春セメスター") || lowercased.contains("spring") {
            season = .spring
        } else if combined.contains("秋セメスター") || lowercased.contains("fall")
            || lowercased.contains("autumn")
        {
            season = .fall
        } else {
            season = .unknown
        }

        guard let academicYear else {
            return nil
        }

        return AcademicSemester(academicYear: academicYear, season: season)
    }
}
