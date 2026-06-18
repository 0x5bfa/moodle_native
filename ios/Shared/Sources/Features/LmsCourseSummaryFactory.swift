import Foundation
import MoodleNativeCore
import MoodleNativeNetworking

public enum LmsCourseSummaryFactory {
    public static func makeCourseSummaries(
        from snapshot: LmsWebServiceClient.DashboardSnapshot
    ) -> [LmsCourseSummary] {
        return snapshot.courses
            .map { course in
                let titleParts = LmsCourseTitleParser.parse(course.displayName ?? course.fullName)
                let summary = strippedSummary(course.summary)
                return LmsCourseSummary(
                    id: course.id,
                    title: titleParts.title,
                    courseCode: titleParts.courseCode,
                    shortName: course.shortName,
                    summary: summary,
                    courseImageURL: course.courseImage.flatMap(URL.init(string:)),
                    progress: course.progress,
                    isFavorite: course.isFavorite ?? false,
                    academicSemester: TimetableSummaryParser.parseAcademicSemester(
                        summary: summary,
                        fallbackText: course.shortName
                    ),
                    scheduleSlots: [],
                    assignmentCount: 0,
                    unreadAnnouncementCount: 0,
                    unreadForumPostCount: 0,
                    isRecentlyAccessed: false,
                    detailURL: URL(string: "\(snapshot.siteURL)/course/view.php?id=\(course.id)")
                )
            }
            .sorted { lhs, rhs in
                if lhs.isFavorite != rhs.isFavorite {
                    return lhs.isFavorite && rhs.isFavorite == false
                }

                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
    }

    private static func strippedSummary(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let withoutTags = value.replacingOccurrences(
            of: "<[^>]+>",
            with: " ",
            options: .regularExpression
        )

        let unescaped =
            withoutTags
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")

        let collapsed = unescaped.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)

        return collapsed.isEmpty ? nil : collapsed
    }
}
