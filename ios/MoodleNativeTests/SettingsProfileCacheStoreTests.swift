import Foundation
import MoodleNativeCore
import MoodleNativeNetworking
import Testing

@testable import MoodleNative

@MainActor
struct SettingsProfileCacheStoreTests {
    @Test func cacheRoundTripForMatchingSession() throws {
        let directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let store = SettingsProfileCacheStore(cacheDirectoryURL: directoryURL)
        let session = makeSession(authenticatedAt: Date(timeIntervalSince1970: 1_744_506_000))
        let profile = try makeProfile(fullName: "Sample Taro", userName: "sample.taro")

        try store.save(profile, for: session)
        let loadedProfile = try store.load(for: session)
        let loaded = try #require(loadedProfile)

        #expect(loaded.fullName == "Sample Taro")
        #expect(loaded.userName == "sample.taro")
        #expect(loaded.siteName == "Moodle")
    }

    @Test func cacheIsIgnoredWhenSessionChanges() throws {
        let directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let store = SettingsProfileCacheStore(cacheDirectoryURL: directoryURL)
        let originalSession = makeSession(authenticatedAt: Date(timeIntervalSince1970: 1_744_506_000))
        let anotherSession = makeSession(authenticatedAt: Date(timeIntervalSince1970: 1_744_606_000))

        try store.save(makeProfile(), for: originalSession)

        #expect(try store.load(for: anotherSession) == nil)
    }

    @Test func viewModelUsesCachedProfileBeforeFetching() async throws {
        let directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let store = SettingsProfileCacheStore(cacheDirectoryURL: directoryURL)
        let session = makeSession(authenticatedAt: Date(timeIntervalSince1970: 1_744_506_000))
        let cachedProfile = try makeProfile(fullName: "Cached Hanako", userName: "cached.hanako")
        try store.save(cachedProfile, for: session)

        let viewModel = SettingsProfileViewModel(
            cacheStore: store,
            fetchProfile: { _ in
                struct UnexpectedFetchError: Error {}
                throw UnexpectedFetchError()
            }
        )

        await viewModel.loadIfNeeded(session: session)

        let profile = try #require(viewModel.profile)
        #expect(profile.fullName == "Cached Hanako")
        #expect(profile.userName == "cached.hanako")
        #expect(viewModel.errorMessage == nil)
    }

    private func makeSession(authenticatedAt: Date) -> LmsAuthenticationSession {
        LmsAuthenticationSession(
            siteURL: "https://lms.example.test",
            token: "ws-token-123",
            privateToken: nil,
            rawCallbackURL: "moodleapp://example?token=ws-token-123",
            authenticatedAt: authenticatedAt
        )
    }

    private func makeProfile(
        fullName: String = "Sample Taro",
        userName: String = "sample.taro"
    ) throws -> LmsWebServiceClient.SiteInfo {
        let json = """
            {
              "sitename": "Moodle",
              "siteurl": "https://lms.example.test",
              "userid": 99,
              "username": "\(userName)",
              "fullname": "\(fullName)",
              "firstname": "Sample",
              "lastname": "Taro",
              "functions": []
            }
            """

        return try JSONDecoder().decode(
            LmsWebServiceClient.SiteInfo.self,
            from: Data(json.utf8)
        )
    }
}
