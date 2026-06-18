import Foundation
import MoodleNativeCore

final class AssignmentsCacheStore {
    static let defaultAutomaticRefreshInterval: TimeInterval = 60 * 30

    private let fileManager: FileManager
    private let cacheDirectoryURL: URL?
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
        automaticRefreshInterval: TimeInterval = AssignmentsCacheStore.defaultAutomaticRefreshInterval
    ) {
        self.fileManager = fileManager
        self.cacheDirectoryURL = cacheDirectoryURL
        self.automaticRefreshInterval = automaticRefreshInterval
    }

    func load(for session: LmsAuthenticationSession) throws -> CachedAssignmentsSnapshot? {
        let fileURL = try cacheFileURL()
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        let snapshot = try decoder.decode(CachedAssignmentsSnapshot.self, from: data)

        guard snapshot.siteURL == session.siteURL,
            snapshot.authenticatedAt == session.authenticatedAt
        else {
            try? delete()
            return nil
        }

        return snapshot
    }

    func save(assignments: [LmsAssignmentItem], lastUpdatedAt: Date, for session: LmsAuthenticationSession) throws {
        let snapshot = CachedAssignmentsSnapshot(
            siteURL: session.siteURL,
            authenticatedAt: session.authenticatedAt,
            lastUpdatedAt: lastUpdatedAt,
            assignments: assignments.map(CachedAssignmentRecord.init)
        )

        let fileURL = try cacheFileURL()
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
    }

    func shouldRefresh(_ snapshot: CachedAssignmentsSnapshot, now: Date = .now) -> Bool {
        now.timeIntervalSince(snapshot.lastUpdatedAt) >= automaticRefreshInterval
    }

    func delete() throws {
        let fileURL = try cacheFileURL()
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return
        }

        try fileManager.removeItem(at: fileURL)
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

        return directoryURL
            .appending(path: "MoodleNative")
            .appending(path: "assignments-cache.json")
    }
}
