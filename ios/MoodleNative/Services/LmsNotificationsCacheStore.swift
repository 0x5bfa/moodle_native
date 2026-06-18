import Foundation
import MoodleNativeCore

final class LmsNotificationsCacheStore {
    static let defaultAutomaticRefreshInterval: TimeInterval = 60 * 10

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
        automaticRefreshInterval: TimeInterval = LmsNotificationsCacheStore.defaultAutomaticRefreshInterval
    ) {
        self.fileManager = fileManager
        self.cacheDirectoryURL = cacheDirectoryURL
        self.automaticRefreshInterval = automaticRefreshInterval
    }

    func load(for session: LmsAuthenticationSession) throws -> CachedNotificationsSnapshot? {
        let fileURL = try cacheFileURL()
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        let snapshot = try decoder.decode(CachedNotificationsSnapshot.self, from: data)

        guard snapshot.siteURL == session.siteURL,
            snapshot.authenticatedAt == session.authenticatedAt
        else {
            try? delete()
            return nil
        }

        return snapshot
    }

    func save(
        notifications: [LmsNotificationItem],
        unreadCount: Int,
        lastUpdatedAt: Date,
        for session: LmsAuthenticationSession
    ) throws {
        let snapshot = CachedNotificationsSnapshot(
            siteURL: session.siteURL,
            authenticatedAt: session.authenticatedAt,
            lastUpdatedAt: lastUpdatedAt,
            unreadCount: unreadCount,
            notifications: notifications.map(CachedNotificationRecord.init)
        )

        let fileURL = try cacheFileURL()
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
    }

    func shouldRefresh(_ snapshot: CachedNotificationsSnapshot, now: Date = .now) -> Bool {
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
            .appending(path: "notifications-cache.json")
    }
}
