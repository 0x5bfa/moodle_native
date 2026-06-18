import Foundation

enum TimetableCourseEditStore {
    private static let storageKey = "timetable.courseEdits"

    static func load() -> [String: TimetableCourseEdit] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return [:]
        }

        return (try? JSONDecoder().decode([String: TimetableCourseEdit].self, from: data)) ?? [:]
    }

    static func save(_ edits: [String: TimetableCourseEdit]) {
        guard let data = try? JSONEncoder().encode(edits) else {
            return
        }

        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
