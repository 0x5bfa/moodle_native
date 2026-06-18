import Foundation

enum TimetableCourseConflictResolutionStore {
    private static let storageKey = "timetable.courseConflictResolutions"

    static func load() -> [String: String] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return [:]
        }

        return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
    }

    static func save(_ resolutions: [String: String]) {
        guard let data = try? JSONEncoder().encode(resolutions) else {
            return
        }

        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
