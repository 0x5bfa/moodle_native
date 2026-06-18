import Foundation

public enum SemesterSeason: String, Codable, Hashable, Sendable {
    case spring
    case fall
    case unknown

    public var title: String {
        switch self {
        case .spring:
            return "春"
        case .fall:
            return "秋"
        case .unknown:
            return "その他"
        }
    }

    public var sortOrder: Int {
        switch self {
        case .spring:
            return 0
        case .fall:
            return 1
        case .unknown:
            return 2
        }
    }
}
