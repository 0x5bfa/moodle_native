import Foundation

struct TimetableWidgetStore {
    private let fileManager: FileManager
    private let appGroupIdentifier: String
    private let filename: String
    private let explicitContainerURL: URL?
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
        appGroupIdentifier: String = MoodleNativeWidgetConstants.appGroupIdentifier,
        filename: String = MoodleNativeWidgetConstants.timetableSnapshotFilename,
        containerURL: URL? = nil
    ) {
        self.fileManager = fileManager
        self.appGroupIdentifier = appGroupIdentifier
        self.filename = filename
        self.explicitContainerURL = containerURL
    }

    func load() throws -> TimetableWidgetSnapshot? {
        guard let fileURL = fileURL() else {
            return nil
        }

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(TimetableWidgetSnapshot.self, from: data)
    }

    func save(_ snapshot: TimetableWidgetSnapshot) throws {
        guard let fileURL = fileURL() else {
            return
        }

        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
    }

    func delete() throws {
        guard let fileURL = fileURL(),
            fileManager.fileExists(atPath: fileURL.path)
        else {
            return
        }

        try fileManager.removeItem(at: fileURL)
    }

    private func fileURL() -> URL? {
        let containerURL = explicitContainerURL
            ?? fileManager.containerURL(
                forSecurityApplicationGroupIdentifier: appGroupIdentifier
            )

        return containerURL?.appending(path: filename)
    }
}
