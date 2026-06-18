import Foundation

struct HiddenAssignmentsStore {
    private let userDefaults: UserDefaults
    private let storageKey: String

    init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = "assignments.hiddenAssignmentIDs"
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
    }

    func load() -> Set<Int> {
        Set(userDefaults.array(forKey: storageKey) as? [Int] ?? [])
    }

    func save(_ assignmentIDs: Set<Int>) {
        userDefaults.set(Array(assignmentIDs).sorted(), forKey: storageKey)
    }

    func delete() {
        userDefaults.removeObject(forKey: storageKey)
    }
}
