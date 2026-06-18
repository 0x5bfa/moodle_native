import SwiftUI

enum TimetableStatus: Hashable {
    case favorite
    case unreadAnnouncement
    case pendingAssignment
    case unreadForum

    var systemImage: String {
        switch self {
        case .favorite:
            return "star.fill"
        case .unreadAnnouncement:
            return "bell.badge.fill"
        case .pendingAssignment:
            return "checklist.checked"
        case .unreadForum:
            return "bubble.left.and.text.bubble.right.fill"
        }
    }

    var color: Color {
        switch self {
        case .favorite:
            return .yellow
        case .unreadAnnouncement:
            return .orange
        case .pendingAssignment:
            return .red
        case .unreadForum:
            return .blue
        }
    }

    var displayName: String {
        switch self {
        case .favorite:
            return String(localized: "timetableStatus.favorite")
        case .unreadAnnouncement:
            return String(localized: "timetableStatus.unreadAnnouncement")
        case .pendingAssignment:
            return String(localized: "timetableStatus.pendingAssignment")
        case .unreadForum:
            return String(localized: "timetableStatus.unreadForum")
        }
    }
}
