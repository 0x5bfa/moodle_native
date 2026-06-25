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

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            component = try container.decodeIfPresent(String.self, forKey: .component) ?? ""
            contextID = try container.decodeIntish(forKey: .contextID)
            userID = try container.decodeIntish(forKey: .userID)
            fileArea = try container.decodeIfPresent(String.self, forKey: .fileArea) ?? ""
            itemID = try container.decodeIntish(forKey: .itemID)
            fileName = try container.decodeIfPresent(String.self, forKey: .fileName) ?? ""
            filePath = try container.decodeIfPresent(String.self, forKey: .filePath) ?? "/"
            fileSize = try container.decodeIntishIfPresent(forKey: .fileSize)
        }
    }

    struct AssignmentUploadedDraftFilesResponse: Decodable, Sendable {
        let files: [AssignmentUploadedDraftFile]

        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            if container.decodeNil() {
                files = []
                return
            }

            if let files = try? container.decode([AssignmentUploadedDraftFile].self) {
                self.files = files
                return
            }

            if let file = try? container.decode(AssignmentUploadedDraftFile.self) {
                files = [file]
                return
            }

            files = []
        }
    }

    struct AssignmentWarningListResponse: Decodable, Sendable {
        let warnings: [AssignmentWarning]

        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            if container.decodeNil() {
                warnings = []
                return
            }

            warnings = (try? container.decode([AssignmentWarning].self)) ?? []
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

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            submissionID = try container.decodeIntish(forKey: .submissionID)
            warnings = try container.decodeIfPresent([AssignmentWarning].self, forKey: .warnings) ?? []
        }
    }

    public struct AssignmentSubmissionRemovalResponse: Decodable, Equatable, Sendable {
        public let status: Bool
        public let warnings: [AssignmentWarning]

        private enum CodingKeys: String, CodingKey {
            case status
            case warnings
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            status = try container.decodeBoolishIfPresent(forKey: .status) ?? false
            warnings = try container.decodeIfPresent([AssignmentWarning].self, forKey: .warnings) ?? []
        }
    }
}
