import Foundation

struct TimetableCourseConflict: Identifiable {
    let id: String
    let dayIndex: Int
    let periodIndices: [Int]
    let courses: [TimetableCourse]

    var periodTitle: String {
        let periods = periodIndices.map { "\($0 + 1)" }
        return periods.joined(separator: ", ")
    }
}
