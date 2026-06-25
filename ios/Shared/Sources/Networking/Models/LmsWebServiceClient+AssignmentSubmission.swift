import Foundation

extension LmsWebServiceClient {
    public struct AssignmentFile: Decodable, Equatable, Identifiable, Sendable {
        public let fileName: String?
        public let filePath: String?
        public let fileSize: Int?
        public var fileURL: String?
        public let mimeType: String?
        public let timeModified: Int?
        public let isExternalFile: Bool
        public let repositoryType: String?

        public var id: String {
            [fileName, filePath, fileURL, mimeType]
                .compactMap { $0 }
                .joined(separator: "|")
        }

        private enum CodingKeys: String, CodingKey {
            case fileName = "filename"
            case filePath = "filepath"
            case fileSize = "filesize"
            case fileURL = "fileurl"
            case mimeType = "mimetype"
            case timeModified = "timemodified"
            case isExternalFile = "isexternalfile"
            case repositoryType = "repositorytype"
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            fileName = try container.decodeIfPresent(String.self, forKey: .fileName)
            filePath = try container.decodeIfPresent(String.self, forKey: .filePath)
            fileSize = try container.decodeIntishIfPresent(forKey: .fileSize)
            fileURL = try container.decodeIfPresent(String.self, forKey: .fileURL)
            mimeType = try container.decodeIfPresent(String.self, forKey: .mimeType)
            timeModified = try container.decodeIntishIfPresent(forKey: .timeModified)
            isExternalFile = try container.decodeBoolishIfPresent(forKey: .isExternalFile) ?? false
            repositoryType = try container.decodeIfPresent(String.self, forKey: .repositoryType)
        }
    }

    public struct AssignmentPluginFileArea: Decodable, Equatable, Identifiable, Sendable {
        public let area: String
        public var files: [AssignmentFile]

        public var id: String {
            area
        }

        private enum CodingKeys: String, CodingKey {
            case area
            case files
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            area = try container.decodeIfPresent(String.self, forKey: .area) ?? ""
            files = try container.decodeIfPresent([AssignmentFile].self, forKey: .files) ?? []
        }
    }

    public struct AssignmentPluginEditorField: Decodable, Equatable, Identifiable, Sendable {
        public let name: String
        public let description: String
        public let text: String?
        public let format: Int?

        public var id: String {
            name
        }

        private enum CodingKeys: String, CodingKey {
            case name
            case description
            case text
            case format
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
            description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
            text = try container.decodeIfPresent(String.self, forKey: .text)
            format = try container.decodeIfPresent(Int.self, forKey: .format)
        }
    }

    public struct AssignmentPlugin: Decodable, Equatable, Identifiable, Sendable {
        public let type: String
        public let name: String
        public var fileAreas: [AssignmentPluginFileArea]
        public let editorFields: [AssignmentPluginEditorField]

        public var id: String {
            "\(type)|\(name)"
        }

        private enum CodingKeys: String, CodingKey {
            case type
            case name
            case fileAreas = "fileareas"
            case editorFields = "editorfields"
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            type = try container.decodeIfPresent(String.self, forKey: .type) ?? ""
            name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
            fileAreas =
                try container.decodeIfPresent([AssignmentPluginFileArea].self, forKey: .fileAreas) ?? []
            editorFields =
                try container.decodeIfPresent([AssignmentPluginEditorField].self, forKey: .editorFields)
                ?? []
        }
    }

    public struct AssignmentSubmission: Decodable, Equatable, Identifiable, Sendable {
        public let id: Int
        public let userID: Int
        public let attemptNumber: Int
        public let timeCreated: Int
        public let timeModified: Int
        public let timeStarted: Int?
        public let status: String
        public let groupID: Int
        public let assignmentID: Int?
        public let latest: Int?
        public var plugins: [AssignmentPlugin]
        public let gradingStatus: String?

        private enum CodingKeys: String, CodingKey {
            case id
            case userID = "userid"
            case attemptNumber = "attemptnumber"
            case timeCreated = "timecreated"
            case timeModified = "timemodified"
            case timeStarted = "timestarted"
            case status
            case groupID = "groupid"
            case assignmentID = "assignment"
            case latest
            case plugins
            case gradingStatus = "gradingstatus"
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeIntish(forKey: .id)
            userID = try container.decodeIntish(forKey: .userID)
            attemptNumber = try container.decodeIntish(forKey: .attemptNumber)
            timeCreated = try container.decodeIntish(forKey: .timeCreated)
            timeModified = try container.decodeIntish(forKey: .timeModified)
            timeStarted = try container.decodeIntishIfPresent(forKey: .timeStarted)
            status = try container.decodeIfPresent(String.self, forKey: .status) ?? ""
            groupID = try container.decodeIntish(forKey: .groupID)
            assignmentID = try container.decodeIntishIfPresent(forKey: .assignmentID)
            latest = try container.decodeIntishIfPresent(forKey: .latest)
            plugins = try container.decodeIfPresent([AssignmentPlugin].self, forKey: .plugins) ?? []
            gradingStatus = try container.decodeIfPresent(String.self, forKey: .gradingStatus)
        }
    }

    public struct AssignmentGrade: Decodable, Equatable, Sendable {
        public let id: Int
        public let assignmentID: Int?
        public let userID: Int
        public let attemptNumber: Int
        public let timeCreated: Int
        public let timeModified: Int
        public let grader: Int
        public let grade: String
        public let gradeForDisplay: String?

        private enum CodingKeys: String, CodingKey {
            case id
            case assignmentID = "assignment"
            case userID = "userid"
            case attemptNumber = "attemptnumber"
            case timeCreated = "timecreated"
            case timeModified = "timemodified"
            case grader
            case grade
            case gradeForDisplay = "gradefordisplay"
        }
    }

    public struct AssignmentGradingSummary: Decodable, Equatable, Sendable {
        public let participantCount: Int
        public let submissionDraftsCount: Int
        public let submissionsEnabled: Bool
        public let submissionsSubmittedCount: Int
        public let submissionsNeedGradingCount: Int
        public let warningOfUngroupedUsers: String

        private enum CodingKeys: String, CodingKey {
            case participantCount = "participantcount"
            case submissionDraftsCount = "submissiondraftscount"
            case submissionsEnabled = "submissionsenabled"
            case submissionsSubmittedCount = "submissionssubmittedcount"
            case submissionsNeedGradingCount = "submissionsneedgradingcount"
            case warningOfUngroupedUsers = "warnofungroupedusers"
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            participantCount = try container.decodeIfPresent(Int.self, forKey: .participantCount) ?? 0
            submissionDraftsCount =
                try container.decodeIfPresent(Int.self, forKey: .submissionDraftsCount) ?? 0
            submissionsEnabled =
                try container.decodeBoolishIfPresent(forKey: .submissionsEnabled) ?? false
            submissionsSubmittedCount =
                try container.decodeIfPresent(Int.self, forKey: .submissionsSubmittedCount) ?? 0
            submissionsNeedGradingCount =
                try container.decodeIfPresent(Int.self, forKey: .submissionsNeedGradingCount) ?? 0
            warningOfUngroupedUsers =
                try container.decodeIfPresent(String.self, forKey: .warningOfUngroupedUsers) ?? ""
        }
    }

    public struct AssignmentLastAttempt: Decodable, Equatable, Sendable {
        public var submission: AssignmentSubmission?
        public var teamSubmission: AssignmentSubmission?
        public let submissionGroup: Int?
        public let submissionGroupMembersWhoNeedToSubmit: [Int]
        public let submissionsEnabled: Bool
        public let locked: Bool
        public let graded: Bool
        public let canEdit: Bool
        public let canEditOwner: Bool
        public let canSubmit: Bool
        public let extensionDueDate: Int
        public let timeLimit: Int?
        public let blindMarking: Bool
        public let gradingStatus: String
        public let userGroups: [Int]

        private enum CodingKeys: String, CodingKey {
            case submission
            case teamSubmission = "teamsubmission"
            case submissionGroup = "submissiongroup"
            case submissionGroupMembersWhoNeedToSubmit = "submissiongroupmemberswhoneedtosubmit"
            case submissionsEnabled = "submissionsenabled"
            case locked
            case graded
            case canEdit = "canedit"
            case canEditOwner = "caneditowner"
            case canSubmit = "cansubmit"
            case extensionDueDate = "extensionduedate"
            case timeLimit = "timelimit"
            case blindMarking = "blindmarking"
            case gradingStatus = "gradingstatus"
            case userGroups = "usergroups"
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            submission = try container.decodeIfPresent(AssignmentSubmission.self, forKey: .submission)
            teamSubmission = try container.decodeIfPresent(
                AssignmentSubmission.self, forKey: .teamSubmission)
            submissionGroup = try container.decodeIfPresent(Int.self, forKey: .submissionGroup)
            submissionGroupMembersWhoNeedToSubmit =
                try container.decodeIfPresent(
                    [Int].self,
                    forKey: .submissionGroupMembersWhoNeedToSubmit
                ) ?? []
            submissionsEnabled =
                try container.decodeBoolishIfPresent(forKey: .submissionsEnabled) ?? false
            locked = try container.decodeBoolishIfPresent(forKey: .locked) ?? false
            graded = try container.decodeBoolishIfPresent(forKey: .graded) ?? false
            canEdit = try container.decodeBoolishIfPresent(forKey: .canEdit) ?? false
            canEditOwner = try container.decodeBoolishIfPresent(forKey: .canEditOwner) ?? false
            canSubmit = try container.decodeBoolishIfPresent(forKey: .canSubmit) ?? false
            extensionDueDate = try container.decodeIfPresent(Int.self, forKey: .extensionDueDate) ?? 0
            timeLimit = try container.decodeIfPresent(Int.self, forKey: .timeLimit)
            blindMarking = try container.decodeBoolishIfPresent(forKey: .blindMarking) ?? false
            gradingStatus = try container.decodeIfPresent(String.self, forKey: .gradingStatus) ?? ""
            userGroups = try container.decodeIfPresent([Int].self, forKey: .userGroups) ?? []
        }
    }

    public struct AssignmentFeedback: Decodable, Equatable, Sendable {
        public let grade: AssignmentGrade?
        public let gradeForDisplay: String?
        public let gradedDate: Int?
        public var plugins: [AssignmentPlugin]

        private enum CodingKeys: String, CodingKey {
            case grade
            case gradeForDisplay = "gradefordisplay"
            case gradedDate = "gradeddate"
            case plugins
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            grade = try container.decodeIfPresent(AssignmentGrade.self, forKey: .grade)
            gradeForDisplay = try container.decodeIfPresent(String.self, forKey: .gradeForDisplay)
            gradedDate = try container.decodeIfPresent(Int.self, forKey: .gradedDate)
            plugins = try container.decodeIfPresent([AssignmentPlugin].self, forKey: .plugins) ?? []
        }
    }

    public struct AssignmentPreviousAttempt: Decodable, Equatable, Identifiable, Sendable {
        public let attemptNumber: Int
        public var submission: AssignmentSubmission?
        public let grade: AssignmentGrade?
        public var feedbackPlugins: [AssignmentPlugin]

        public var id: Int {
            attemptNumber
        }

        private enum CodingKeys: String, CodingKey {
            case attemptNumber = "attemptnumber"
            case submission
            case grade
            case feedbackPlugins = "feedbackplugins"
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            attemptNumber = try container.decodeIfPresent(Int.self, forKey: .attemptNumber) ?? 0
            submission = try container.decodeIfPresent(AssignmentSubmission.self, forKey: .submission)
            grade = try container.decodeIfPresent(AssignmentGrade.self, forKey: .grade)
            feedbackPlugins =
                try container.decodeIfPresent([AssignmentPlugin].self, forKey: .feedbackPlugins) ?? []
        }
    }

    public struct AssignmentDataAttachments: Decodable, Equatable, Sendable {
        public var intro: [AssignmentFile]
        public var activity: [AssignmentFile]

        private enum CodingKeys: String, CodingKey {
            case intro
            case activity
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            intro = try container.decodeIfPresent([AssignmentFile].self, forKey: .intro) ?? []
            activity = try container.decodeIfPresent([AssignmentFile].self, forKey: .activity) ?? []
        }
    }

    public struct AssignmentData: Decodable, Equatable, Sendable {
        public var attachments: AssignmentDataAttachments?
        public let activity: String?
        public let activityFormat: Int?

        private enum CodingKeys: String, CodingKey {
            case attachments
            case activity
            case activityFormat = "activityformat"
        }
    }

    public struct AssignmentWarning: Decodable, Equatable, Identifiable, Sendable {
        public let item: String?
        public let itemID: Int?
        public let warningCode: String?
        public let message: String?

        public var id: String {
            [
                item ?? "",
                itemID.map { String($0) } ?? "",
                warningCode ?? "",
                message ?? "",
            ].joined(separator: "|")
        }

        private enum CodingKeys: String, CodingKey {
            case item
            case itemID = "itemid"
            case warningCode = "warningcode"
            case message
        }
    }

    public struct AssignmentSubmissionStatus: Decodable, Equatable, Sendable {
        public let gradingSummary: AssignmentGradingSummary?
        public var lastAttempt: AssignmentLastAttempt?
        public var feedback: AssignmentFeedback?
        public var previousAttempts: [AssignmentPreviousAttempt]
        public var assignmentData: AssignmentData?
        public let warnings: [AssignmentWarning]

        private enum CodingKeys: String, CodingKey {
            case gradingSummary = "gradingsummary"
            case lastAttempt = "lastattempt"
            case feedback
            case previousAttempts = "previousattempts"
            case assignmentData = "assignmentdata"
            case warnings
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            gradingSummary = try container.decodeIfPresent(
                AssignmentGradingSummary.self, forKey: .gradingSummary)
            lastAttempt = try container.decodeIfPresent(AssignmentLastAttempt.self, forKey: .lastAttempt)
            feedback = try container.decodeIfPresent(AssignmentFeedback.self, forKey: .feedback)
            previousAttempts =
                try container.decodeIfPresent([AssignmentPreviousAttempt].self, forKey: .previousAttempts)
                ?? []
            assignmentData = try Self.decodeAssignmentData(from: container)
            warnings = try container.decodeIfPresent([AssignmentWarning].self, forKey: .warnings) ?? []
        }

        private static func decodeAssignmentData(
            from container: KeyedDecodingContainer<CodingKeys>
        ) throws -> AssignmentData? {
            guard container.contains(.assignmentData),
                try container.decodeNil(forKey: .assignmentData) == false
            else {
                return nil
            }

            do {
                return try container.decode(AssignmentData.self, forKey: .assignmentData)
            } catch let objectDecodingError {
                do {
                    let emptyArray = try container.superDecoder(forKey: .assignmentData).unkeyedContainer()
                    guard emptyArray.isAtEnd else {
                        throw objectDecodingError
                    }

                    return nil
                } catch {
                    throw objectDecodingError
                }
            }
        }
    }
}
