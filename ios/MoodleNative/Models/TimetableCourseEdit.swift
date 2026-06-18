import Foundation

struct TimetableCourseEdit: Codable, Equatable {
    var accent: TimetableCourseAccent = .none
    var attendanceCounts: [TimetableAttendanceStatus: Int] = [:]
    var memo = ""

    init(
        accent: TimetableCourseAccent = .none,
        attendanceCounts: [TimetableAttendanceStatus: Int] = [:],
        memo: String = ""
    ) {
        self.accent = accent
        self.attendanceCounts = attendanceCounts
        self.memo = memo
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accent = try container.decodeIfPresent(TimetableCourseAccent.self, forKey: .accent) ?? .none
        attendanceCounts = try container.decodeIfPresent(
            [TimetableAttendanceStatus: Int].self,
            forKey: .attendanceCounts
        ) ?? [:]
        memo = try container.decodeIfPresent(String.self, forKey: .memo) ?? ""
    }

    var isEmpty: Bool {
        accent == .none
            && attendanceCounts.values.allSatisfy { $0 <= 0 }
            && memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func attendanceCount(for status: TimetableAttendanceStatus) -> Int {
        max(attendanceCounts[status, default: 0], 0)
    }

    mutating func incrementAttendance(_ status: TimetableAttendanceStatus) {
        attendanceCounts[status] = attendanceCount(for: status) + 1
    }

    mutating func decrementAttendance(_ status: TimetableAttendanceStatus) {
        let updatedCount = attendanceCount(for: status) - 1
        if updatedCount > 0 {
            attendanceCounts[status] = updatedCount
        } else {
            attendanceCounts.removeValue(forKey: status)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case accent
        case attendanceCounts
        case memo
    }
}
