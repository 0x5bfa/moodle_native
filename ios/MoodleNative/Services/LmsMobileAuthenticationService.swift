import AuthenticationServices
import Foundation
import MoodleNativeCore

@MainActor
final class LmsMobileAuthenticationService: NSObject {
    private let siteURL: URL
    private let callbackScheme: String
    private let presentationContextProvider = AuthenticationPresentationContextProvider()
    private var authenticationSession: ASWebAuthenticationSession?

    init(
        siteURL: URL = AppSettings.MoodleSite.resolvedURL(),
        callbackScheme: String = "moodlemobile"
    ) {
        self.siteURL = siteURL
        self.callbackScheme = callbackScheme
    }

    func authenticate() async throws -> LmsAuthenticationSession {
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
