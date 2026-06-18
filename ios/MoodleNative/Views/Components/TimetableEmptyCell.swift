import SwiftUI

struct TimetableEmptyCell: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color(.tertiarySystemGroupedBackground))
            .overlay {
                Text("-")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
    }
}
