import Foundation
import MoodleNativeCore
import MoodleNativeNetworking

public struct LmsCourseSummary: Codable, Identifiable, Equatable, Sendable {
    public let id: Int
    public let title: String
    public let courseCode: String?
    public let shortName: String
    public let summary: String?
    public let courseImageURL: URL?
    public let progress: Double?
    public let isFavorite: Bool
    public let academicSemester: AcademicSemester?
    public let scheduleSlots: [TimetableScheduleSlot]
    public let assignmentCount: Int
    public let unreadAnnouncementCount: Int
    public let unreadForumPostCount: Int
    public let isRecentlyAccessed: Bool
    public let detailURL: URL?

    public init(
        id: Int,
        title: String,
        courseCode: String?,
        shortName: String,
        summary: String?,
        courseImageURL: URL?,
        progress: Double?,
        isFavorite: Bool,
        academicSemester: AcademicSemester?,
        scheduleSlots: [TimetableScheduleSlot],
        assignmentCount: Int,
        unreadAnnouncementCount: Int,
        unreadForumPostCount: Int,
        isRecentlyAccessed: Bool,
        detailURL: URL?
    ) {
        self.id = id
        self.title = title
        self.courseCode = courseCode
        self.shortName = shortName
        self.summary = summary
        self.courseImageURL = courseImageURL
        self.progress = progress
        self.isFavorite = isFavorite
        self.academicSemester = academicSemester
        self.scheduleSlots = scheduleSlots
        self.assignmentCount = assignmentCount
        self.unreadAnnouncementCount = unreadAnnouncementCount
        self.unreadForumPostCount = unreadForumPostCount
        self.isRecentlyAccessed = isRecentlyAccessed
        self.detailURL = detailURL
    }

    public var progressFraction: Double? {
        guard let progress else {
            return nil
        }

        return max(0, min(progress, 100)) / 100
    }
}
