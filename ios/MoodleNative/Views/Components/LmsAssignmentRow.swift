import MoodleNativeCore
import SwiftUI

struct LmsAssignmentRow: View {
    let assignment: LmsAssignmentItem

    private var dueBucket: LmsAssignmentItem.DueBucket {
        assignment.dueBucket()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 4) {
                VStack(alignment: .leading) {
                    Text(assignment.title)
                        .font(.headline)
                        .lineLimit(1)

                    Text(assignment.courseTitle)
                        .font(.body)
                        .lineLimit(1)

                    if let introPreview = assignment.introPreview {
                        Text(introPreview)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                if let badgeTitle = dueBucket.rowBadgeTitle {
                    Text(badgeTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(dueBucket.badgeForegroundColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(dueBucket.badgeBackgroundColor, in: Capsule())
                } else {
                    Text(assignment.dueDateLine())
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .contentShape(Rectangle())
    }
}
