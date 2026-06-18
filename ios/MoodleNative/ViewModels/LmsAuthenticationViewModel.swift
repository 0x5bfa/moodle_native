import AuthenticationServices
import Foundation
import Observation
import MoodleNativeCore

@Observable
@MainActor
final class LmsAuthenticationViewModel {
    private(set) var isAuthenticating = false
    private(set) var session: LmsAuthenticationSession?
    private(set) var errorMessage: String?

    private let authenticationService: LmsMobileAuthenticationService
    private let store: LmsAuthenticationStore
    private let timetableCacheStore: TimetableCacheStore
    private let settingsProfileCacheStore: SettingsProfileCacheStore

    convenience init() {
        self.init(
            authenticationService: LmsMobileAuthenticationService(),
            store: LmsAuthenticationStore(),
            timetableCacheStore: TimetableCacheStore(),
            settingsProfileCacheStore: SettingsProfileCacheStore()
        )
    }

    init(
        authenticationService: LmsMobileAuthenticationService,
        store: LmsAuthenticationStore,
        timetableCacheStore: TimetableCacheStore,
        settingsProfileCacheStore: SettingsProfileCacheStore,
        loadStoredSession: Bool = true,
        initialSession: LmsAuthenticationSession? = nil
    ) {
        self.authenticationService = authenticationService
        self.store = store
        self.timetableCacheStore = timetableCacheStore
        self.settingsProfileCacheStore = settingsProfileCacheStore

        if let initialSession {
            session = initialSession
        } else if loadStoredSession {
            do {
                session = try store.load()
            } catch {
                errorMessage = Self.message(for: error)
                try? store.delete()
            }
        }
    }

    var isLoggedIn: Bool {
        session != nil
    }

    func updateSessionUserID(_ userID: Int, for loadedSession: LmsAuthenticationSession) {
        guard session == loadedSession, loadedSession.userID != userID else {
            return
        }

        let updatedSession = loadedSession.withUserID(userID)
        session = updatedSession

        do {
            try store.save(updatedSession)
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    func signIn() {
        guard isAuthenticating == false else {
            return
        }

        Task {
            await authenticate()
        }
    }

    func signOut() {
        do {
            try store.delete()
            try? timetableCacheStore.delete()
            try? settingsProfileCacheStore.delete()
            session = nil
            errorMessage = nil
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    private func authenticate() async {
        isAuthenticating = true
        defer {
            isAuthenticating = false
        }

        do {
            let authenticatedSession = try await authenticationService.authenticate()
            session = authenticatedSession
            errorMessage = nil

            do {
                try store.save(authenticatedSession)
            } catch {
                errorMessage = Self.message(for: error)
            }
        } catch {
            guard Self.isCanceledAuthentication(error) == false else {
                return
            }

            errorMessage = Self.message(for: error)
        }
    }

    private static func isCanceledAuthentication(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == ASWebAuthenticationSessionError.errorDomain
            && nsError.code == ASWebAuthenticationSessionError.Code.canceledLogin.rawValue
    }

    private static func message(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
            let description = localizedError.errorDescription
        {
            return description
        }

        let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if description.isEmpty == false {
            return description
        }

        return String(localized: "lmsAuthentication.error.loginFailed")
    }
}
