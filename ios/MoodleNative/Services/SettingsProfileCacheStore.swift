import Foundation
import MoodleNativeCore
import MoodleNativeNetworking

final class SettingsProfileCacheStore {
    private let fileManager: FileManager
    private let cacheDirectoryURL: URL?
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(
        fileManager: FileManager = .default,
        cacheDirectoryURL: URL? = nil
    ) {
        self.fileManager = fileManager
        self.cacheDirectoryURL = cacheDirectoryURL
    }

    func load(for session: LmsAuthenticationSession) throws -> LmsWebServiceClient.SiteInfo? {
        let fileURL = try cacheFileURL()
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        let snapshot = try decoder.decode(CachedSettingsProfile.self, from: data)

        guard snapshot.siteURL == session.siteURL,
            snapshot.authenticatedAt == session.authenticatedAt
        else {
            try? delete()
            return nil
        }

        return snapshot.siteInfo.asSiteInfo
    }

    func save(_ profile: LmsWebServiceClient.SiteInfo, for session: LmsAuthenticationSession) throws {
        let snapshot = CachedSettingsProfile(
            siteURL: session.siteURL,
            authenticatedAt: session.authenticatedAt,
            siteInfo: CachedSiteInfo(profile)
        )

        let fileURL = try cacheFileURL()
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
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

        return
            directoryURL
            .appending(path: "MoodleNative")
            .appending(path: "settings-profile-cache.json")
    }
}

private struct CachedSettingsProfile: Codable, Equatable {
    let siteURL: String
    let authenticatedAt: Date
    let siteInfo: CachedSiteInfo
}

private struct CachedSiteInfo: Codable, Equatable {
    struct Function: Codable, Equatable {
        let name: String
        let version: String?
    }

    let siteName: String
    let siteURL: String
    let userID: Int
    let userName: String
    let fullName: String
    let firstName: String?
    let lastName: String?
    let functions: [Function]

    init(_ siteInfo: LmsWebServiceClient.SiteInfo) {
        siteName = siteInfo.siteName
        siteURL = siteInfo.siteURL
        userID = siteInfo.userID
        userName = siteInfo.userName
        fullName = siteInfo.fullName
        firstName = siteInfo.firstName
        lastName = siteInfo.lastName
        functions = siteInfo.functions.map { Function(name: $0.name, version: $0.version) }
    }

    var asSiteInfo: LmsWebServiceClient.SiteInfo {
        let jsonObject: [String: Any] = [
            "sitename": siteName,
            "siteurl": siteURL,
            "userid": userID,
            "username": userName,
            "fullname": fullName,
            "firstname": firstName as Any,
            "lastname": lastName as Any,
            "functions": functions.map { ["name": $0.name, "version": $0.version as Any] },
        ]

        let data = try? JSONSerialization.data(withJSONObject: jsonObject)
        let decoded = data.flatMap { try? JSONDecoder().decode(LmsWebServiceClient.SiteInfo.self, from: $0) }
        return decoded ?? fallbackSiteInfo
    }

    private var fallbackSiteInfo: LmsWebServiceClient.SiteInfo {
        let json = """
            {
              "sitename": "\(siteName)",
              "siteurl": "\(siteURL)",
              "userid": \(userID),
              "username": "\(userName)",
              "fullname": "\(fullName)",
              "firstname": \(jsonStringOrNull(firstName)),
              "lastname": \(jsonStringOrNull(lastName)),
              "functions": [\(functionsJSON)]
            }
            """

        return (try? JSONDecoder().decode(LmsWebServiceClient.SiteInfo.self, from: Data(json.utf8)))
            ?? (try! JSONDecoder().decode(
                LmsWebServiceClient.SiteInfo.self,
                from: Data("{\"sitename\":\"\",\"siteurl\":\"\",\"userid\":0,\"username\":\"\",\"fullname\":\"\",\"firstname\":null,\"lastname\":null,\"functions\":[]}".utf8)))
    }

    private func jsonStringOrNull(_ value: String?) -> String {
        guard let value else {
            return "null"
        }

        let escaped =
            value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private var functionsJSON: String {
        functions.map { function in
            let versionJSON = jsonStringOrNull(function.version)
            return "{\"name\":\"\(function.name)\",\"version\":\(versionJSON)}"
        }
        .joined(separator: ",")
    }
}
