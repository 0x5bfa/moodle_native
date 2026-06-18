import Foundation
import MoodleNativeCore

public struct HomeRemainingCourse: Identifiable, Equatable, Sendable {
    public let course: LmsCourseSummary
    public let periodIndex: Int
    public let room: String?

    public init(course: LmsCourseSummary, periodIndex: Int, room: String?) {
        self.course = course
        self.periodIndex = periodIndex
        self.room = room
    }

    public var id: String {
        "\(course.id)-\(periodIndex)"
    }

    public var periodTitle: String {
        "\(periodIndex + 1)限"
    }
}
