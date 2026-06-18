import SwiftUI

enum TimetableAttendanceStatus: String, CaseIterable, Codable, Identifiable {
    case attended
    case absent
    case late
    case canceled

    var id: Self { self }

    var title: String {
        switch self {
        case .attended:
            String(localized: "attendanceStatus.attended")
        case .absent:
            String(localized: "attendanceStatus.absent")
        case .late:
            String(localized: "attendanceStatus.late")
        case .canceled:
            String(localized: "attendanceStatus.canceled")
        }
    }

    var systemImage: String {
        switch self {
        case .attended:
            "checkmark.circle.fill"
        case .absent:
            "xmark.circle.fill"
        case .late:
            "clock.fill"
        case .canceled:
            "minus.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .attended:
            .green
        case .absent:
            .red
        case .late:
            .orange
        case .canceled:
            .secondary
        }
    }
}
