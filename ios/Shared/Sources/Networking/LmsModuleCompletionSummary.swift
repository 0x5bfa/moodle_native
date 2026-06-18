import Foundation

public struct LmsModuleCompletionSummary: Equatable, Sendable {
    public let progress: Double
    public let completedRequirementCount: Int
    public let totalRequirementCount: Int
    public let isComplete: Bool
    public let accessibilityLabel: String

    public var isInProgress: Bool {
        isComplete == false && progress > 0
    }
}
