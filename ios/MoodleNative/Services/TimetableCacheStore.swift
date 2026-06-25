import Foundation
import MoodleNativeCore
import MoodleNativeFeatures
import MoodleNativeNetworking
#if !targetEnvironment(macCatalyst)
import WidgetKit
#endif

final class TimetableCacheStore {
    static let defaultAutomaticRefreshInterval: TimeInterval = 60 * 60 * 6

    private let fileManager: FileManager
    private let cacheDirectoryURL: URL?
    private let widgetStore: TimetableWidgetStore?
    private let automaticRefreshInterval: TimeInterval
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    init(
        fileManager: FileManager = .default,
        cacheDirectoryURL: URL? = nil,
        widgetStore: TimetableWidgetStore? = nil,
        automaticRefreshInterval: TimeInterval = TimetableCacheStore.defaultAutomaticRefreshInterval
    ) {
        self.fileManager = fileManager
        self.cacheDirectoryURL = cacheDirectoryURL
        self.widgetStore = widgetStore ?? (cacheDirectoryURL == nil ? TimetableWidgetStore() : nil)
        self.automaticRefreshInterval = automaticRefreshInterval
    }

    func load(for session: LmsAuthenticationSession) throws -> CachedTimetableSnapshot? {
        let fileURL = try cacheFileURL()
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        let snapshot = try decoder.decode(CachedTimetableSnapshot.self, from: data)

        guard snapshot.siteURL == session.siteURL,
            snapshot.authenticatedAt == session.authenticatedAt
        else {
            try? delete()
            return nil
        }

        return snapshot
    }

    func save(
        summaries: [LmsCourseSummary],
        lastUpdatedAt: Date,
        for session: LmsAuthenticationSession
    ) throws {
        let snapshot = CachedTimetableSnapshot(
            siteURL: session.siteURL,
            authenticatedAt: session.authenticatedAt,
            lastUpdatedAt: lastUpdatedAt,
            courses: summaries.map { summary in
                CachedCourseRecord(
                    id: summary.id,
                    title: summary.title,
                    courseCode: summary.courseCode,
                    shortName: summary.shortName,
                    summary: summary.summary,
                    progress: summary.progress,
                    isFavorite: summary.isFavorite,
                    academicSemester: summary.academicSemester,
                    scheduleSlots: summary.scheduleSlots.map {
                        CachedScheduleSlot(
                            dayIndex: $0.dayIndex,
                            periodIndices: $0.periodIndices,
                            room: $0.room
                        )
                    }
                )
            }
        )

        let fileURL = try cacheFileURL()
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: .atomic)

        if let widgetStore {
            let widgetSnapshot = makeWidgetSnapshot(summaries: summaries, lastUpdatedAt: lastUpdatedAt)
            try? widgetStore.save(widgetSnapshot)
#if !targetEnvironment(macCatalyst)
            WidgetCenter.shared.reloadTimelines(ofKind: MoodleNativeWidgetConstants.nextClassKind)

            Task { @MainActor in
                await NextClassLiveActivityManager.shared.sync(with: widgetSnapshot)
            }
#endif
        }
    }

    func shouldRefresh(_ snapshot: CachedTimetableSnapshot, now: Date = .now) -> Bool {
        now.timeIntervalSince(snapshot.lastUpdatedAt) >= automaticRefreshInterval
    }

    private func makeWidgetSnapshot(
        summaries: [LmsCourseSummary],
        lastUpdatedAt: Date
    ) -> TimetableWidgetSnapshot {
        TimetableWidgetSnapshot(
            lastUpdatedAt: lastUpdatedAt,
            courses: summaries.flatMap { summary in
                summary.scheduleSlots.flatMap { slot in
                    slot.periodIndices.map { periodIndex in
                        TimetableWidgetCourse(
                            id: "course-\(summary.id)-\(slot.dayIndex)-\(periodIndex)",
                            title: summary.title,
                            room: slot.room ?? summary.courseCode,
                            dayIndex: slot.dayIndex,
                            periodIndex: periodIndex
                        )
                    }
                }
            }
        )
    }

    func delete() throws {
        let fileURL = try cacheFileURL()
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return
        }

        try fileManager.removeItem(at: fileURL)
        if let widgetStore {
            try? widgetStore.delete()
#if !targetEnvironment(macCatalyst)
            WidgetCenter.shared.reloadTimelines(ofKind: MoodleNativeWidgetConstants.nextClassKind)

            Task { @MainActor in
                await NextClassLiveActivityManager.shared.endAll()
            }
#endif
        }
    }

    private func save(_ snapshot: CachedTimetableSnapshot) throws {
        let fileURL = try cacheFileURL()
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
    }

    private func cacheFileURL() throws -> URL {
        let directoryURL: URL
        if let cacheDirectoryURL {
            directoryURL = cacheDirectoryURL
        } else {
            directoryURL = try fileManager.url(
                for: .cachesDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        }

        return
            directoryURL
            .appending(path: "MoodleNative")
            .appending(path: "timetable-cache.json")
    }
}
