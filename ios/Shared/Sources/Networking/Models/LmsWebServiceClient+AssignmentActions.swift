import Foundation

extension LmsWebServiceClient {
    public struct AssignmentSubmissionUploadFile: Equatable, Sendable {
        public let fileName: String
        public let mimeType: String
        public let data: Data

        public init(fileName: String, mimeType: String, data: Data) {
            self.fileName = fileName
            self.mimeType = mimeType
            self.data = data
        }
    }

    public struct AssignmentUploadedDraftFile: Decodable, Equatable, Sendable {
        public let component: String
        public let contextID: Int
        public let userID: Int
        public let fileArea: String
        public let itemID: Int
        public let fileName: String
        public let filePath: String
        public let fileSize: Int?

        private enum CodingKeys: String, CodingKey {
            case component
            case contextID = "contextid"
            case userID = "userid"
            case fileArea = "filearea"
            case itemID = "itemid"
            case fileName = "filename"
            case filePath = "filepath"
            case fileSize = "filesize"
        }
    }

    public struct AssignmentOnlineTextInput: Equatable, Sendable {
        public let text: String
        public let format: Int
        public let draftItemID: Int

        public init(text: String, format: Int = 1, draftItemID: Int = 0) {
            self.text = text
            self.format = format
            self.draftItemID = draftItemID
        }
    }

    public struct AssignmentSubmissionStartResponse: Decodable, Equatable, Sendable {
        public let submissionID: Int
        public let warnings: [AssignmentWarning]

        private enum CodingKeys: String, CodingKey {
            case submissionID = "submissionid"
            case warnings
        }
    }

    public struct AssignmentSubmissionRemovalResponse: Decodable, Equatable, Sendable {
        public let status: Bool
        public let warnings: [AssignmentWarning]
    }
}
