import AuthenticationServices
import Foundation
import MoodleNativeCore

@MainActor
final class LmsMobileAuthenticationService: NSObject {
    private let siteURL: URL
    private let callbackScheme: String
    private let presentationContextProvider = AuthenticationPresentationContextProvider()
    private var authenticationSession: ASWebAuthenticationSession?
    private var pendingContinuation: CheckedContinuation<LmsAuthenticationSession, Error>?

    init(
        siteURL: URL = AppSettings.MoodleSite.resolvedURL(),
        callbackScheme: String = "moodleapp"
    ) {
        self.siteURL = siteURL
        self.callbackScheme = callbackScheme
    }

    func makeLaunchURL() throws -> URL {
        try buildLaunchURL()
    }

    func authenticate() async throws -> LmsAuthenticationSession {
        #if targetEnvironment(macCatalyst)
        return try await authenticateOnMacCatalyst()
        #else
        return try await authenticateWithSystemSession()
        #endif
    }

    func deliverCallbackURL(_ callbackURL: URL) throws {
        try deliverCallbackURLString(callbackURL.absoluteString)
    }

    func deliverCallbackURLString(_ rawCallbackURLString: String) throws {
        do {
            let authenticatedSession = try LmsAuthenticationCallbackParser.parse(
                rawCallbackURLString: rawCallbackURLString,
                fallbackSiteURL: siteURL
            )
            completePending(with: .success(authenticatedSession))
        } catch let error as LmsAuthenticationError {
            completePending(with: .failure(error))
            throw error
        } catch let error as LmsAuthenticationCallbackError {
            let wrapped = LmsAuthenticationError.callbackParsing(error)
            completePending(with: .failure(wrapped))
            throw wrapped
        } catch {
            completePending(with: .failure(error))
            throw error
        }
    }

    func cancelPendingAuthentication() {
        authenticationSession?.cancel()
        authenticationSession = nil
        completePending(with: .failure(LmsAuthenticationError.canceledLogin))
    }

    private func authenticateOnMacCatalyst() async throws -> LmsAuthenticationSession {
        try await withCheckedThrowingContinuation { continuation in
            pendingContinuation = continuation
            LmsAuthenticationCallbackCoordinator.shared.register(handler: { [weak self] callbackURL in
                guard let self else {
                    return
                }

                do {
                    try self.deliverCallbackURL(callbackURL)
                } catch let error as LmsAuthenticationError {
                    self.completePending(with: .failure(error))
                } catch {
                    self.completePending(with: .failure(error))
                }
            }, owner: self)
        }
    }

    private func authenticateWithSystemSession() async throws -> LmsAuthenticationSession {
        let launchURL = try buildLaunchURL()
        let fallbackSiteURL = siteURL

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: launchURL,
                callbackURLScheme: callbackScheme
            ) { [weak self] callbackURL, error in
                self?.authenticationSession = nil

                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let callbackURL else {
                    continuation.resume(
                        throwing: LmsAuthenticationError.callbackParsing(.missingCallbackURL)
                    )
                    return
                }

                do {
                    let authenticatedSession = try LmsAuthenticationCallbackParser.parse(
                        callbackURL: callbackURL,
                        fallbackSiteURL: fallbackSiteURL
                    )
                    continuation.resume(returning: authenticatedSession)
                } catch let error as LmsAuthenticationCallbackError {
                    continuation.resume(throwing: LmsAuthenticationError.callbackParsing(error))
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            session.prefersEphemeralWebBrowserSession = false
            session.presentationContextProvider = presentationContextProvider
            authenticationSession = session

            guard session.start() else {
                authenticationSession = nil
                continuation.resume(throwing: LmsAuthenticationError.unableToStartAuthentication)
                return
            }
        }
    }

    private func completePending(with result: Result<LmsAuthenticationSession, Error>) {
        guard let continuation = pendingContinuation else {
            return
        }

        pendingContinuation = nil
        LmsAuthenticationCallbackCoordinator.shared.unregister(owner: self)

        switch result {
        case .success(let session):
            continuation.resume(returning: session)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }

    private func buildLaunchURL() throws -> URL {
        let normalizedSiteURL: String
        if siteURL.absoluteString.hasSuffix("/") {
            normalizedSiteURL = String(siteURL.absoluteString.dropLast())
        } else {
            normalizedSiteURL = siteURL.absoluteString
        }

        guard
            var components = URLComponents(string: normalizedSiteURL + "/admin/tool/mobile/launch.php")
        else {
            throw LmsAuthenticationError.invalidLaunchURL
        }

        components.queryItems = [
            URLQueryItem(name: "service", value: "moodle_mobile_app"),
            URLQueryItem(
                name: "passport",
                value: UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()),
            URLQueryItem(name: "urlscheme", value: callbackScheme),
            URLQueryItem(name: "confirmed", value: "1"),
        ]

        guard let launchURL = components.url else {
            throw LmsAuthenticationError.invalidLaunchURL
        }

        return launchURL
    }
}
