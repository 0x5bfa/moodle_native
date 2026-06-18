import Foundation
import MoodleNativeCore
import MoodleNativeFeatures

struct CachedCourseRecord: Codable, Equatable, Sendable {
    let id: Int
    let title: String
    let courseCode: String?
    let shortName: String
    let summary: String?
    let progress: Double?
    let isFavorite: Bool
    let academicSemester: AcademicSemester?
    let scheduleSlots: [CachedScheduleSlot]

    init(
        id: Int,
        title: String,
        courseCode: String?,
        shortName: String,
        summary: String?,
        progress: Double?,
        isFavorite: Bool,
        academicSemester: AcademicSemester?,
        scheduleSlots: [CachedScheduleSlot]
    ) {
        self.id = id
        self.title = title
        self.courseCode = courseCode
        self.shortName = shortName
        self.summary = summary
        self.progress = progress
        self.isFavorite = isFavorite
        self.academicSemester = academicSemester
        self.scheduleSlots = scheduleSlots
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        courseCode = try container.decodeIfPresent(String.self, forKey: .courseCode)
        shortName = try container.decode(String.self, forKey: .shortName)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        progress = try container.decodeIfPresent(Double.self, forKey: .progress)
        isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
        academicSemester = try container.decodeIfPresent(AcademicSemester.self, forKey: .academicSemester)
        scheduleSlots = try container.decode([CachedScheduleSlot].self, forKey: .scheduleSlots)
    }

    func lmsCourseSummary(siteURL: String) -> LmsCourseSummary {
        LmsCourseSummary(
            id: id,
            title: title,
            courseCode: courseCode,
            shortName: shortName,
            summary: summary,
            courseImageURL: nil,
            progress: progress,
            isFavorite: isFavorite,
            academicSemester: academicSemester,
            scheduleSlots: scheduleSlots.map {
                TimetableScheduleSlot(
                    dayIndex: $0.dayIndex,
                    periodIndices: $0.periodIndices,
                    room: $0.room
                )
            },
            assignmentCount: 0,
            unreadAnnouncementCount: 0,
            unreadForumPostCount: 0,
            isRecentlyAccessed: false,
            detailURL: URL(string: "\(siteURL)/course/view.php?id=\(id)")
        )
    }
}
