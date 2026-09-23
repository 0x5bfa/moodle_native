import SwiftUI

enum RootTab: Hashable, CaseIterable, Identifiable {
    case home
    case assignments
    case timetable
    case notifications
    case settings

    var id: Self { self }

    /// Localized title shared by the tab bar, the macOS sidebar, and menu commands.
    var titleKey: LocalizedStringKey {
        switch self {
        case .home:
            return "tab.home"
        case .assignments:
            return "tab.assignments"
        case .timetable:
            return "tab.timetable"
        case .notifications:
            return "tab.notifications"
        case .settings:
            return "tab.settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            return "house"
        case .assignments:
            return "checklist"
        case .timetable:
            return "calendar"
        case .notifications:
            return "bell"
        case .settings:
            return "gearshape"
        }
    }
}
