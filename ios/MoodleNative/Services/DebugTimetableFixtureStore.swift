#if DEBUG
import Foundation
import MoodleNativeCore
import MoodleNativeFeatures

struct DebugTimetableFixture: Identifiable {
    let id: String
    let title: String
    let siteURL: String
    let summaries: [LmsCourseSummary]
}

enum DebugTimetableFixtureStore {
    static let selectionStorageKey = "debug.timetableFixtureID"
    static let noneFixtureID = "none"

    static let builtInFixtures: [DebugTimetableFixture] = [
        try! decode(Self.edgeCasesFixtureData)
    ]

    static func fixture(id: String) -> DebugTimetableFixture? {
        builtInFixtures.first { $0.id == id }
    }

    static func decode(_ data: Data) throws -> DebugTimetableFixture {
        let decoder = JSONDecoder()
        let payload = try decoder.decode(Payload.self, from: data)
        let siteURL = payload.siteURL ?? "https://lms.example.test"

        return DebugTimetableFixture(
            id: payload.id ?? payload.title,
            title: payload.title,
            siteURL: siteURL,
            summaries: payload.courses.map { $0.lmsCourseSummary(siteURL: siteURL) }
        )
    }

    private struct Payload: Decodable {
        let id: String?
        let title: String
        let siteURL: String?
        let courses: [Course]
    }

    private struct Course: Decodable {
        let id: Int
        let title: String
        let courseCode: String?
        let shortName: String?
        let summary: String?
        let progress: Double?
        let isFavorite: Bool?
        let academicSemester: AcademicSemester?
        let scheduleSlots: [TimetableScheduleSlot]?
        let assignmentCount: Int?
        let unreadAnnouncementCount: Int?
        let unreadForumPostCount: Int?
        let isRecentlyAccessed: Bool?
        let detailURL: URL?

        func lmsCourseSummary(siteURL: String) -> LmsCourseSummary {
            LmsCourseSummary(
                id: id,
                title: title,
                courseCode: courseCode,
                shortName: shortName ?? title,
                summary: summary,
                courseImageURL: nil,
                progress: progress,
                isFavorite: isFavorite ?? false,
                academicSemester: academicSemester,
                scheduleSlots: scheduleSlots ?? [],
                assignmentCount: assignmentCount ?? 0,
                unreadAnnouncementCount: unreadAnnouncementCount ?? 0,
                unreadForumPostCount: unreadForumPostCount ?? 0,
                isRecentlyAccessed: isRecentlyAccessed ?? false,
                detailURL: detailURL ?? URL(string: "\(siteURL)/course/view.php?id=\(id)")
            )
        }
    }

    private static let edgeCasesFixtureData = Data(
        """
        {
          "id": "edge-cases",
          "title": "Edge cases",
          "siteURL": "https://lms.example.test",
          "courses": [
            {
              "id": 1001,
              "title": "Writing for Information Systems Engineering(G1) with Extra Long Course Name",
              "courseCode": "53347",
              "shortName": "Writing for Information Systems Engineering(G1)",
              "isFavorite": true,
              "academicSemester": { "academicYear": 2026, "season": "spring" },
              "scheduleSlots": [
                { "dayIndex": 1, "periodIndices": [0], "room": "H321" }
              ],
              "assignmentCount": 6,
              "unreadAnnouncementCount": 2,
              "unreadForumPostCount": 1,
              "isRecentlyAccessed": true
            },
            {
              "id": 1006,
              "title": "Writing for Information Systems Engineering(G2) Duplicate Registration",
              "courseCode": "53347-DUP",
              "shortName": "Writing duplicate",
              "academicSemester": { "academicYear": 2026, "season": "spring" },
              "scheduleSlots": [
                { "dayIndex": 1, "periodIndices": [0], "room": "H321" }
              ],
              "assignmentCount": 1
            },
            {
              "id": 1002,
              "title": "PBL 3: Creative Design (G2) § 53447:PB...",
              "courseCode": "PB-53447",
              "shortName": "PBL 3",
              "academicSemester": { "academicYear": 2026, "season": "spring" },
              "scheduleSlots": [
                { "dayIndex": 2, "periodIndices": [0, 1], "room": "H321" }
              ]
            },
            {
              "id": 1003,
              "title": "Software Engineering (G1)",
              "courseCode": "53374",
              "shortName": "Software Engineering",
              "academicSemester": { "academicYear": 2026, "season": "spring" },
              "scheduleSlots": [
                { "dayIndex": 2, "periodIndices": [2], "room": "H321" }
              ],
              "assignmentCount": 6
            },
            {
              "id": 1004,
              "title": "Data Structures and Algorithms (G1)",
              "courseCode": "53380",
              "shortName": "Data Structures",
              "isFavorite": true,
              "academicSemester": { "academicYear": 2026, "season": "spring" },
              "scheduleSlots": [
                { "dayIndex": 4, "periodIndices": [4], "room": "H321" }
              ],
              "unreadAnnouncementCount": 1,
              "assignmentCount": 6
            },
            {
              "id": 1005,
              "title": "Intensive Course without a Scheduled Time",
              "courseCode": "INT-100",
              "shortName": "Intensive Course",
              "academicSemester": { "academicYear": 2026, "season": "spring" },
              "scheduleSlots": []
            }
          ]
        }
        """.utf8
    )
}
#endif
