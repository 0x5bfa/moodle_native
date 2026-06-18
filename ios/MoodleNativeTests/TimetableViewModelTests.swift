import Foundation
import MoodleNativeCore
import MoodleNativeFeatures
import Testing

@testable import MoodleNative

@MainActor
struct TimetableViewModelTests {
    @Test func contiguousPeriodRangesMergeAdjacentPeriods() {
        let ranges = TimetableViewModel.contiguousPeriodRanges(for: [2, 3, 3, 4])

        #expect(ranges == [2...4])
    }

    @Test func contiguousPeriodRangesKeepGapsSeparate() {
        let ranges = TimetableViewModel.contiguousPeriodRanges(for: [1, 3, 4])

        #expect(ranges == [1...1, 3...4])
    }

    @Test func makeTimetableCoursesBuildsSinglePlacementForMultiPeriodSlot() throws {
        let summary = LmsCourseSummary(
            id: 42,
            title: "計算機科学",
            courseCode: "CS204",
            shortName: "計算機科学",
            summary: nil,
            courseImageURL: nil,
            progress: 0,
            isFavorite: false,
            academicSemester: AcademicSemester(academicYear: 2026, season: .spring),
            scheduleSlots: [
                TimetableScheduleSlot(dayIndex: 3, periodIndices: [2, 3], room: "H902")
            ],
            assignmentCount: 0,
            unreadAnnouncementCount: 0,
            unreadForumPostCount: 0,
            isRecentlyAccessed: false,
            detailURL: URL(string: "https://lms.example.test/course/view.php?id=42")
        )

        let courses = TimetableViewModel.makeTimetableCourses(from: summary)
        let course = try #require(courses.only)

        #expect(course.periodIndex == 2)
        #expect(course.periodSpan == 2)
        #expect(course.room == "H902")
    }

    @Test func makeTimetableCoursesMergesAdjacentSinglePeriodSlots() throws {
        let summary = LmsCourseSummary(
            id: 42,
            title: "計算機科学",
            courseCode: "CS204",
            shortName: "計算機科学",
            summary: nil,
            courseImageURL: nil,
            progress: 0,
            isFavorite: false,
            academicSemester: AcademicSemester(academicYear: 2026, season: .spring),
            scheduleSlots: [
                TimetableScheduleSlot(dayIndex: 3, periodIndices: [2], room: "H902"),
                TimetableScheduleSlot(dayIndex: 3, periodIndices: [3], room: "H902"),
            ],
            assignmentCount: 0,
            unreadAnnouncementCount: 0,
            unreadForumPostCount: 0,
            isRecentlyAccessed: false,
            detailURL: URL(string: "https://lms.example.test/course/view.php?id=42")
        )

        let courses = TimetableViewModel.makeTimetableCourses(from: summary)
        let course = try #require(courses.only)

        #expect(course.periodIndex == 2)
        #expect(course.periodSpan == 2)
    }

    @Test func normalizedScheduleSlotsKeepDifferentRoomsSeparate() {
        let slots = TimetableViewModel.normalizedScheduleSlots([
            TimetableScheduleSlot(dayIndex: 3, periodIndices: [2], room: "H901"),
            TimetableScheduleSlot(dayIndex: 3, periodIndices: [3], room: "H902"),
        ])

        #expect(slots.count == 2)
    }

    @Test func applyingPlacementsUsesRutimeStatusIcons() throws {
        let summary = LmsCourseSummary(
            id: 42,
            title: "計算機科学",
            courseCode: "CS204",
            shortName: "計算機科学",
            summary: nil,
            courseImageURL: nil,
            progress: 0,
            isFavorite: false,
            academicSemester: AcademicSemester(academicYear: 2026, season: .spring),
            scheduleSlots: [],
            assignmentCount: 0,
            unreadAnnouncementCount: 0,
            unreadForumPostCount: 0,
            isRecentlyAccessed: false,
            detailURL: URL(string: "https://lms.example.test/course/view.php?id=42")
        )
        let placements = LmsRutimeTableParser.parse(
            content: """
                <div class="subject">
                    <a href="https://lms.example.test/course/view.php?id=42" class="active-course-name">計算機科学</a>
                    <div class="room">水1:H902</div>
                    <span class="on"><img class="favouriteicon" alt="お気に入り 点灯"></span>
                    <span class="on"><img class="newsicon" alt="未読アナウンスメント 点灯"></span>
                    <span class="on"><img class="assignicon" alt="未提出課題 点灯"></span>
                    <span class="on"><img class="forumicon" alt="未読フォーラム 点灯"></span>
                </div>
                """,
            siteURL: "https://lms.example.test"
        )

        let updatedSummary = try #require(
            TimetableViewModel.applyingPlacements(placements, to: [summary]).only
        )

        #expect(updatedSummary.isFavorite == true)
        #expect(updatedSummary.unreadAnnouncementCount == 1)
        #expect(updatedSummary.assignmentCount == 1)
        #expect(updatedSummary.unreadForumPostCount == 1)
    }

    @Test func makeCourseConflictsDetectsDuplicateSinglePeriodCourses() throws {
        let courses = [
            Self.course(id: "course-1-1-0", title: "Writing G1", dayIndex: 1, periodIndex: 0),
            Self.course(id: "course-2-1-0", title: "Writing G2", dayIndex: 1, periodIndex: 0),
            Self.course(id: "course-3-2-0", title: "PBL", dayIndex: 2, periodIndex: 0),
        ]

        let conflict = try #require(
            TimetableViewModel.makeCourseConflicts(from: courses, selectedSemester: nil).only
        )

        #expect(conflict.dayIndex == 1)
        #expect(conflict.periodIndices == [0])
        #expect(conflict.courses.map(\.id) == ["course-1-1-0", "course-2-1-0"])
    }

    @Test func makeCourseConflictsDetectsOverlappingMultiPeriodCourses() throws {
        let courses = [
            Self.course(id: "course-1-2-0", title: "PBL", dayIndex: 2, periodIndex: 0, periodSpan: 2),
            Self.course(id: "course-2-2-1", title: "Seminar", dayIndex: 2, periodIndex: 1),
        ]

        let conflict = try #require(
            TimetableViewModel.makeCourseConflicts(from: courses, selectedSemester: nil).only
        )

        #expect(conflict.dayIndex == 2)
        #expect(conflict.periodIndices == [0, 1])
        #expect(conflict.courses.map(\.id) == ["course-1-2-0", "course-2-2-1"])
    }

    private static func course(
        id: String,
        title: String,
        dayIndex: Int,
        periodIndex: Int,
        periodSpan: Int = 1
    ) -> TimetableCourse {
        TimetableCourse(
            id: id,
            title: title,
            room: "H321",
            dayIndex: dayIndex,
            periodIndex: periodIndex,
            periodSpan: periodSpan,
            isTentative: false,
            statuses: [],
            detailURL: nil
        )
    }
}

extension Array {
    fileprivate var only: Element? {
        count == 1 ? first : nil
    }
}
