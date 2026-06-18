import SwiftUI

enum TimetableCourseAccent: String, CaseIterable, Codable, Identifiable {
    case none
    case red
    case orange
    case yellow
    case green
    case mint
    case blue
    case purple
    case pink

    var id: Self { self }

    var title: String {
        switch self {
        case .none:
            String(localized: "common.none")
        case .red:
            "Red"
        case .orange:
            "Orange"
        case .yellow:
            "Yellow"
        case .green:
            "Green"
        case .mint:
            "Mint"
        case .blue:
            "Blue"
        case .purple:
            "Purple"
        case .pink:
            "Pink"
        }
    }

    var color: Color {
        switch self {
        case .none:
            .secondary
        case .red:
            .red
        case .orange:
            .orange
        case .yellow:
            .yellow
        case .green:
            .green
        case .mint:
            .mint
        case .blue:
            .blue
        case .purple:
            .purple
        case .pink:
            .pink
        }
    }
}
