import Foundation

extension LmsWebServiceClient {
    public struct MoodleErrorResponse: Decodable {
        public let exception: String?
        public let errorCode: String?
        public let message: String?
        public let debugInfo: String?

        public var isError: Bool {
            exception != nil || errorCode != nil
        }

        private enum CodingKeys: String, CodingKey {
            case exception
            case errorCode = "errorcode"
            case message
            case debugInfo = "debuginfo"
        }
    }
}
