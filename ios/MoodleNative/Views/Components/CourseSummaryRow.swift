import SwiftUI
import MoodleNativeNetworking
import MoodleNativeFeatures

struct CourseSummaryRow: View {
    let course: LmsCourseSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(course.title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    HStack(spacing: 8) {
                        if let courseCode = course.courseCode {
                            Text(courseCode)
                        }

                        Text(course.shortName)
                            .lineLimit(1)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                if course.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.yellow)
                }
            }

            if let summary = course.summary {
                Text(summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 12) {
                if course.assignmentCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "checklist")
                        Text(Self.localizedAssignmentCount(course.assignmentCount))
                    }
                }

                if course.unreadAnnouncementCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "bell.badge")
                        Text(Self.localizedUnreadCount(course.unreadAnnouncementCount))
                    }
                }

                if course.unreadForumPostCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left.and.bubble.right")
                        Text(Self.localizedUnreadCount(course.unreadForumPostCount))
                    }
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let progress = course.progressFraction {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("courseSummary.progress")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(progress * 100))%")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    ProgressView(value: progress)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private static func localizedAssignmentCount(_ count: Int) -> String {
        String.localizedStringWithFormat(String(localized: "courseSummary.assignments.count"), count)
    }

    private static func localizedUnreadCount(_ count: Int) -> String {
        String.localizedStringWithFormat(String(localized: "courseSummary.unread.count"), count)
    }
}
