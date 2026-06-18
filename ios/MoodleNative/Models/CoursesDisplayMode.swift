import Foundation

enum CoursesDisplayMode: String, CaseIterable, Identifiable, Sendable {
    case timetable
    case list

    static let storageKey = "settings.coursesDisplayMode"

    var id: Self {
        self
    }

    var title: LocalizedStringResource {
        switch self {
        case .timetable:
            return "settings.displayMode.timetable"
        case .list:
            return "settings.displayMode.list"
        }
    }
}
