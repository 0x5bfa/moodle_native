import Foundation

public struct TimetableScheduleSlot: Codable, Equatable, Hashable, Sendable {
    public let dayIndex: Int
    public let periodIndices: [Int]
    public let room: String?

    public init(dayIndex: Int, periodIndices: [Int], room: String?) {
        self.dayIndex = dayIndex
        self.periodIndices = periodIndices
        self.room = room
    }
}
