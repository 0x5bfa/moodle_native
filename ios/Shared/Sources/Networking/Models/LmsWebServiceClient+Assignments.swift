import Foundation

extension LmsWebServiceClient {
    public struct CourseAssignments: Decodable, Equatable, Identifiable, Sendable {
        public let id: Int
        public let fullName: String
        public let shortName: String
        public let assignments: [Assignment]

        private enum CodingKeys: String, CodingKey {
            case id
            case fullName = "fullname"
            case shortName = "shortname"
            case assignments
        }
    }

    public struct Assignment: Decodable, Equatable, Identifiable, Sendable {
        public let id: Int
        public let courseID: Int
        public let courseModuleID: Int
        public let name: String
        public let intro: String?
        public let allowsSubmissionsFromDate: Int?
        public let dueDate: Int?
        public let cutoffDate: Int?
        public let gradingDueDate: Int?
        public let timeModified: Int?
        public let submissionDrafts: Bool?
        public let requiresSubmissionStatement: Bool?
        public let submissionStatement: String?
        public let timeLimit: Int?
        public let enabledSubmissionPluginTypes: [String]?
        public let onlineTextWordLimit: Int?

        private enum CodingKeys: String, CodingKey {
            case id
            case courseID = "course"
            case courseModuleID = "cmid"
            case name
            case intro
            case allowsSubmissionsFromDate = "allowsubmissionsfromdate"
            case dueDate = "duedate"
            case cutoffDate = "cutoffdate"
            case gradingDueDate = "gradingduedate"
            case timeModified = "timemodified"
            case submissionDrafts = "submissiondrafts"
            case requiresSubmissionStatement = "requiresubmissionstatement"
            case submissionStatement = "submissionstatement"
            case timeLimit = "timelimit"
            case configs
        }

        private struct PluginConfig: Decodable {
            let plugin: String
            let subtype: String
            let name: String
            let value: String
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(Int.self, forKey: .id)
            courseID = try container.decode(Int.self, forKey: .courseID)
            courseModuleID = try container.decode(Int.self, forKey: .courseModuleID)
            name = try container.decode(String.self, forKey: .name)
            intro = try container.decodeIfPresent(String.self, forKey: .intro)
            allowsSubmissionsFromDate =
                try container.decodeIfPresent(Int.self, forKey: .allowsSubmissionsFromDate)
            dueDate = try container.decodeIfPresent(Int.self, forKey: .dueDate)
            cutoffDate = try container.decodeIfPresent(Int.self, forKey: .cutoffDate)
            gradingDueDate = try container.decodeIfPresent(Int.self, forKey: .gradingDueDate)
            timeModified = try container.decodeIfPresent(Int.self, forKey: .timeModified)
            submissionDrafts = try container.decodeBoolishIfPresent(forKey: .submissionDrafts)
            requiresSubmissionStatement =
                try container.decodeBoolishIfPresent(forKey: .requiresSubmissionStatement)
            submissionStatement = try container.decodeIfPresent(String.self, forKey: .submissionStatement)
            timeLimit = try container.decodeIfPresent(Int.self, forKey: .timeLimit)
            if let configs = try container.decodeIfPresent([PluginConfig].self, forKey: .configs) {
                enabledSubmissionPluginTypes = configs
                    .filter {
                        $0.subtype == "assignsubmission"
                            && $0.name == "enabled"
                            && $0.value == "1"
                    }
                    .map(\.plugin)
                let onlineTextConfigs = Dictionary(
                    configs
                        .filter { $0.plugin == "onlinetext" && $0.subtype == "assignsubmission" }
                        .map { ($0.name, $0.value) },
                    uniquingKeysWith: { _, last in last }
                )
                if onlineTextConfigs["wordlimitenabled"] == "1",
                    let wordLimit = onlineTextConfigs["wordlimit"].flatMap(Int.init)
                {
                    onlineTextWordLimit = wordLimit
                } else {
                    onlineTextWordLimit = nil
                }
            } else {
                enabledSubmissionPluginTypes = nil
                onlineTextWordLimit = nil
            }
        }
    }

    public struct AssignmentsResponse: Decodable {
        public let courses: [CourseAssignments]
    }
}
