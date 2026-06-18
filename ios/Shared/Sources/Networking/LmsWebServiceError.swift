import Foundation

public enum LmsWebServiceError: LocalizedError {
    case invalidSiteURL
    case invalidResponse
    case invalidSubmissionFiles
    case http(statusCode: Int, response: String)
    case moodle(message: String, debugInfo: String?)
    case decoding(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidSiteURL:
            return "Moodle の API URL を組み立てられませんでした。"
        case .invalidResponse:
            return "Moodle から不正なレスポンスを受け取りました。"
        case .invalidSubmissionFiles:
            return "提出するファイルを選択してください。"
        case .http(let statusCode, let response):
            if response.isEmpty {
                return "Moodle が HTTP \(statusCode) を返しました。"
            }
            return "Moodle が HTTP \(statusCode) を返しました。 \(response)"
        case .moodle(let message, let debugInfo):
            guard let debugInfo, debugInfo.isEmpty == false else {
                return message
            }
            return "\(message) (\(debugInfo))"
        case .decoding:
            return "Moodle のレスポンスを解析できませんでした。"
        }
    }
}
