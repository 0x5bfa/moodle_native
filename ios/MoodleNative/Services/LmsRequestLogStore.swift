import Foundation
import MoodleNativeCore
import MoodleNativeNetworking

actor LmsRequestLogStore: LmsWebServiceRequestLogging {
    static let shared = LmsRequestLogStore()

    private let maximumEntryCount = 500
    private let fileURL: URL
    private var cachedEntries: [LmsRequestLogEntry]?

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
    }

    func record(
        context: LmsRequestLogContext,
        wsFunction: String,
        parameters: [URLQueryItem],
        response: HTTPURLResponse?,
        data: Data?,
        error: Error?
    ) {
        var entries = loadEntries()
        entries.insert(
            LmsRequestLogEntry(
                context: context,
                wsFunction: wsFunction,
                parameters: parameters.map {
                    LmsRequestLogEntry.Parameter(name: $0.name, value: $0.value)
                },
                statusCode: response?.statusCode,
                errorMessage: error.map(Self.errorMessage),
                responseBody: Self.responseBody(from: data)
            ),
            at: 0
        )
        if entries.count > maximumEntryCount {
            entries.removeLast(entries.count - maximumEntryCount)
        }

        cachedEntries = entries
        save(entries)
    }

    func entries() -> [LmsRequestLogEntry] {
        loadEntries()
    }

    func clear() {
        cachedEntries = []
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func loadEntries() -> [LmsRequestLogEntry] {
        if let cachedEntries {
            return cachedEntries
        }

        guard let data = try? Data(contentsOf: fileURL) else {
            cachedEntries = []
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let entries = try? decoder.decode([LmsRequestLogEntry].self, from: data) else {
            cachedEntries = []
            return []
        }

        cachedEntries = entries
        return entries
    }

    private func save(_ entries: [LmsRequestLogEntry]) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(entries)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Logging must never make an LMS request fail.
        }
    }

    private static func defaultFileURL() -> URL {
        let applicationSupportDirectory =
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return applicationSupportDirectory
            .appending(path: "MoodleNative", directoryHint: .isDirectory)
            .appending(path: "lms-request-logs.json", directoryHint: .notDirectory)
    }

    private static func responseBody(from data: Data?) -> String {
        guard let data else {
            return ""
        }

        if let object = try? JSONSerialization.jsonObject(with: data),
            JSONSerialization.isValidJSONObject(object),
            let formatted = try? JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .sortedKeys]
            ),
            let text = String(data: formatted, encoding: .utf8)
        {
            return text
        }

        return String(data: data, encoding: .utf8) ?? "<\(data.count) bytes>"
    }

    private static func errorMessage(_ error: Error) -> String {
        if let localizedError = error as? LocalizedError,
            let description = localizedError.errorDescription,
            description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        {
            return description
        }

        let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return description.isEmpty ? String(describing: error) : description
    }
}

extension LmsWebServiceClient {
    static func logged(
        session: LmsAuthenticationSession,
        context: LmsRequestLogContext
    ) -> LmsWebServiceClient {
        LmsWebServiceClient(
            session: session,
            requestLogger: LmsRequestLogStore.shared,
            logContext: context
        )
    }
}
