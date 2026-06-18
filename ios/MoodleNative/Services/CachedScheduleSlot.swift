import Foundation

struct CachedScheduleSlot: Codable, Equatable, Sendable {
    let dayIndex: Int
    let periodIndices: [Int]
    let room: String?
}
