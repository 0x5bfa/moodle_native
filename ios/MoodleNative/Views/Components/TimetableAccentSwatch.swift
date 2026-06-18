import SwiftUI

struct TimetableAccentSwatch: View {
    let accent: TimetableCourseAccent
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(fillColor)
                .frame(width: 28, height: 28)
                .overlay {
                    Circle()
                        .stroke(borderColor, lineWidth: 1)
                }

            if isSelected {
                Image(systemName: accent == .none ? "slash" : "checkmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(accent == .none ? Color.primary : Color.white)
            }
        }
        .frame(width: 36, height: 36)
        .contentShape(Circle())
        .accessibilityLabel(accent.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var fillColor: Color {
        accent == .none ? Color(.tertiarySystemGroupedBackground) : accent.color
    }

    private var borderColor: Color {
        accent == .none ? Color(.separator).opacity(0.45) : Color.clear
    }
}
