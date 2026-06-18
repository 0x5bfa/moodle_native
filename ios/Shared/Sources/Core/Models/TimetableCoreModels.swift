import Foundation

public struct AcademicSemester: Codable, Hashable, Identifiable, Sendable {
    public let academicYear: Int
    public let season: SemesterSeason

    public init(academicYear: Int, season: SemesterSeason) {
        self.academicYear = academicYear
        self.season = season
    }

    public var id: String {
        "\(academicYear)-\(season.rawValue)"
    }

    public var displayName: String {
        "\(academicYear)年度\(season.title)セメスター"
    }

    public var compactDisplayName: String {
        let shortAcademicYear = academicYear % 100
        return "\(shortAcademicYear) 年度\(season.title)セメスター"
    }
}
