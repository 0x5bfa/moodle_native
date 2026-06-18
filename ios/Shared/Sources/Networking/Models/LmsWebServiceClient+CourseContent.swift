import Foundation

extension LmsWebServiceClient {
    public struct CourseSection: Decodable, Equatable, Identifiable, Sendable {
        public let id: Int
        public let section: Int?
        public let name: String
        public let summary: String?
        public var modules: [CourseModule]

        private enum CodingKeys: String, CodingKey {
            case id
            case section
            case name
            case summary
            case modules
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(Int.self, forKey: .id)
            section = try container.decodeIfPresent(Int.self, forKey: .section)
            name = try container.decode(String.self, forKey: .name)
            summary = try container.decodeIfPresent(String.self, forKey: .summary)
            modules = try container.decodeIfPresent([CourseModule].self, forKey: .modules) ?? []
        }
    }

    public struct CourseModule: Decodable, Equatable, Identifiable, Sendable {
        public let id: Int
        public let instanceID: Int?
        public let modName: String
        public let name: String
        public var url: String?
        public let iconURL: String?
        public let purpose: String?
        public let completion: Int?
        public let completionData: ModuleCompletionData?
        public var contents: [ModuleContent]
        public let dates: [ModuleDate]

        private enum CodingKeys: String, CodingKey {
            case id
            case instanceID = "instance"
            case modName = "modname"
            case name
            case url
            case iconURL = "modicon"
            case purpose
            case completion
            case completionData = "completiondata"
            case contents
            case dates
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(Int.self, forKey: .id)
            instanceID = try container.decodeIfPresent(Int.self, forKey: .instanceID)
            modName = try container.decode(String.self, forKey: .modName)
            name = try container.decode(String.self, forKey: .name)
            url = try container.decodeIfPresent(String.self, forKey: .url)
            iconURL = try container.decodeIfPresent(String.self, forKey: .iconURL)
            purpose = try container.decodeIfPresent(String.self, forKey: .purpose)
            completion = try container.decodeIfPresent(Int.self, forKey: .completion)
            completionData = try container.decodeIfPresent(
                ModuleCompletionData.self, forKey: .completionData)
            contents = try container.decodeIfPresent([ModuleContent].self, forKey: .contents) ?? []
            dates = try container.decodeIfPresent([ModuleDate].self, forKey: .dates) ?? []
        }
    }

    public struct ModuleCompletionData: Decodable, Equatable, Sendable {
        public struct Detail: Decodable, Equatable, Sendable {
            public struct RuleValue: Decodable, Equatable, Sendable {
                public let status: Int?
                public let description: String?
            }

            public let ruleName: String
            public let ruleValue: RuleValue?

            private enum CodingKeys: String, CodingKey {
                case ruleName = "rulename"
                case ruleValue = "rulevalue"
            }
        }

        public let state: Int?
        public let hasCompletion: Bool
        public let userVisible: Bool
        public let details: [Detail]
        public let isOverallComplete: Bool

        private enum CodingKeys: String, CodingKey {
            case state
            case hasCompletion = "hascompletion"
            case userVisible = "uservisible"
            case details
            case isOverallComplete = "isoverallcomplete"
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            state = try container.decodeIfPresent(Int.self, forKey: .state)
            hasCompletion = try container.decodeIfPresent(Bool.self, forKey: .hasCompletion) ?? false
            userVisible = try container.decodeIfPresent(Bool.self, forKey: .userVisible) ?? false
            details = try container.decodeIfPresent([Detail].self, forKey: .details) ?? []
            isOverallComplete =
                try container.decodeIfPresent(Bool.self, forKey: .isOverallComplete) ?? false
        }
    }

    public struct ModuleContent: Decodable, Equatable, Identifiable, Sendable {
        public let type: String?
        public let fileName: String?
        public let filePath: String?
        public let fileSize: Int?
        public var fileURL: String?
        public let mimeType: String?
        public let timeModified: Int?

        public var id: String {
            [type, filePath, fileName, fileURL]
                .compactMap { $0 }
                .joined(separator: "|")
        }

        private enum CodingKeys: String, CodingKey {
            case type
            case fileName = "filename"
            case filePath = "filepath"
            case fileSize = "filesize"
            case fileURL = "fileurl"
            case mimeType = "mimetype"
            case timeModified = "timemodified"
        }
    }

    public struct ModuleDate: Decodable, Equatable, Identifiable, Sendable {
        public let label: String
        public let timestamp: Int
        public let dataID: String

        public var id: String {
            dataID
        }

        private enum CodingKeys: String, CodingKey {
            case label
            case timestamp
            case dataID = "dataid"
        }
    }
}

extension LmsWebServiceClient.ModuleCompletionData {
    public var summary: LmsModuleCompletionSummary? {
        guard hasCompletion, userVisible else {
            return nil
        }

        let ruleStatuses = details.map { max($0.ruleValue?.status ?? 0, 0) }
        let totalRuleCount = max(ruleStatuses.count, 1)

        let completedRuleCount: Int
        if details.isEmpty {
            completedRuleCount = isOverallComplete || state == 1 ? 1 : 0
        } else {
            completedRuleCount = ruleStatuses.filter { $0 > 0 }.count
        }

        let clampedCompletedRuleCount = min(max(completedRuleCount, 0), totalRuleCount)
        let isComplete = isOverallComplete || clampedCompletedRuleCount == totalRuleCount
        let progress = isComplete ? 1 : Double(clampedCompletedRuleCount) / Double(totalRuleCount)

        return LmsModuleCompletionSummary(
            progress: progress,
            completedRequirementCount: clampedCompletedRuleCount,
            totalRequirementCount: totalRuleCount,
            isComplete: isComplete,
            accessibilityLabel: completionAccessibilityLabel(
                completedRequirementCount: clampedCompletedRuleCount,
                totalRequirementCount: totalRuleCount,
                isComplete: isComplete
            )
        )
    }

    public var requirements: [LmsModuleCompletionRequirement] {
        guard hasCompletion, userVisible else {
            return []
        }

        return details.compactMap { detail in
            let text = detail.ruleValue?.description?.trimmingCharacters(in: .whitespacesAndNewlines)
            let fallbackText = fallbackRequirementText(for: detail.ruleName)
            let resolvedText = [text, fallbackText]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first(where: { $0.isEmpty == false })

            guard let resolvedText else {
                return nil
            }

            return LmsModuleCompletionRequirement(
                id: detail.ruleName,
                text: resolvedText,
                isComplete: max(detail.ruleValue?.status ?? 0, 0) > 0
            )
        }
    }

    private func completionAccessibilityLabel(
        completedRequirementCount: Int,
        totalRequirementCount: Int,
        isComplete: Bool
    ) -> String {
        if totalRequirementCount <= 1 {
            return isComplete ? "完了" : "未完了"
        }

        if isComplete {
            return "完了 \(completedRequirementCount)/\(totalRequirementCount)"
        }

        return "\(completedRequirementCount)/\(totalRequirementCount) 条件を完了"
    }

    private func fallbackRequirementText(for ruleName: String) -> String? {
        switch ruleName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "completionview":
            return "閲覧する"
        case "completionsubmit":
            return "提出する"
        case "completionposts":
            return "フォーラム投稿を作成する"
        case "completionreplies":
            return "返信する"
        case "completiondiscussions":
            return "ディスカッションを開始する"
        case "completionminattempts":
            return "受験する"
        default:
            return nil
        }
    }
}
