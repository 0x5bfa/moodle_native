import Foundation
import Observation
import MoodleNativeCore
import MoodleNativeNetworking

@Observable
@MainActor
final class SettingsProfileViewModel {
    private(set) var profile: LmsWebServiceClient.SiteInfo?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let cacheStore: SettingsProfileCacheStore
    private let fetchProfile: @Sendable (LmsAuthenticationSession) async throws -> LmsWebServiceClient.SiteInfo
    private var lastSession: LmsAuthenticationSession?
    private var loadGeneration = 0

    convenience init() {
        self.init(
            cacheStore: SettingsProfileCacheStore(),
            fetchProfile: {
                try await LmsWebServiceClient.logged(
                    session: $0,
                    context: LmsRequestLogContext(
                        navigationPath: String(localized: "navigationPath.settings"),
                        pageTitle: String(localized: "settings.title")
                    )
                ).fetchSiteInfo()
            }
        )
    }

    init(
        cacheStore: SettingsProfileCacheStore,
        fetchProfile: @escaping @Sendable (LmsAuthenticationSession) async throws -> LmsWebServiceClient.SiteInfo = {
            try await LmsWebServiceClient.logged(
                session: $0,
                context: LmsRequestLogContext(
                    navigationPath: String(localized: "navigationPath.settings"),
                    pageTitle: String(localized: "settings.title")
                )
            ).fetchSiteInfo()
        }
    ) {
        self.cacheStore = cacheStore
        self.fetchProfile = fetchProfile
    }

    func loadIfNeeded(session: LmsAuthenticationSession?) async {
        guard let session else {
            reset()
            return
        }

        guard profile == nil || lastSession != session else {
            return
        }

        lastSession = session

        if let cachedProfile = try? cacheStore.load(for: session) {
            profile = cachedProfile
            isLoading = false
            errorMessage = nil
            return
        }

        await load(session: session)
    }

    func refresh(session: LmsAuthenticationSession?) async {
        guard let session else {
            reset()
            return
        }

        await load(session: session)
    }

    var profileInitials: String {
        guard let profile else {
            return "?"
        }

        let source = [profile.firstName, profile.lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined()
        let fallback = profile.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = source.isEmpty ? fallback : source
        let initials = text.prefix(2)
        return initials.isEmpty ? "?" : String(initials)
    }

    private func load(session: LmsAuthenticationSession) async {
        let generation = loadGeneration + 1
        loadGeneration = generation
        lastSession = session
        isLoading = true
        errorMessage = nil

        do {
            let siteInfo = try await fetchProfile(session)

            guard generation == loadGeneration else {
                return
            }

            profile = siteInfo
            try? cacheStore.save(siteInfo, for: session)
            isLoading = false
        } catch {
            guard generation == loadGeneration else {
                return
            }

            profile = nil
            errorMessage = Self.message(for: error)
            isLoading = false
        }
    }

    private func reset() {
        loadGeneration += 1
        profile = nil
        isLoading = false
        errorMessage = nil
        lastSession = nil
    }

    private static func message(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
            let description = localizedError.errorDescription,
            description.isEmpty == false
        {
            return description
        }

        let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if description.isEmpty == false {
            return description
        }

        return String(localized: "settings.profile.error.fetchFailed")
    }
}
