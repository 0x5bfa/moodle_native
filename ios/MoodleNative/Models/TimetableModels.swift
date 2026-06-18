import Foundation

struct TimetableCourse: Identifiable {
    let id: String
    let title: String
    let room: String?
    let dayIndex: Int?
    let periodIndex: Int?
    let periodSpan: Int
    let isTentative: Bool
    let statuses: [TimetableStatus]
    let detailURL: URL?
}
