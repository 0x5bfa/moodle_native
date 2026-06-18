import Foundation
import MoodleNativeCore
import Security

enum LmsAuthenticationError: LocalizedError {
    case invalidLaunchURL
    case unableToStartAuthentication
    case callbackParsing(LmsAuthenticationCallbackError)
    case invalidStoredSession
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidLaunchURL:
            String(localized: "lmsAuthentication.error.invalidLaunchURL")
        case .unableToStartAuthentication:
            String(localized: "lmsAuthentication.error.unableToStart")
        case .callbackParsing(let error):
            error.errorDescription
        case .invalidStoredSession:
            String(localized: "lmsAuthentication.error.invalidStoredSession")
        case .keychain(let status):
            String.localizedStringWithFormat(
                String(localized: "lmsAuthentication.error.keychain"),
                status
            )
        }
    }
}
