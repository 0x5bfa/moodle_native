import Foundation

public enum LmsAuthenticationCallbackError: LocalizedError, Equatable, Sendable {
    case missingCallbackURL
    case invalidCallbackURL
    case missingToken
    case invalidLegacyToken

    public var errorDescription: String? {
        switch self {
        case .missingCallbackURL:
            return "Moodle のコールバック URL を受け取れませんでした。"
        case .invalidCallbackURL:
            return "Moodle のコールバック URL を解析できませんでした。"
        case .missingToken:
            return "Moodle のログイン結果に token が含まれていませんでした。"
        case .invalidLegacyToken:
            return "Moodle の旧形式トークンを復元できませんでした。"
        }
    }
}
