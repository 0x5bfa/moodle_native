import Foundation

public struct LmsModuleCompletionRequirement: Hashable, Identifiable, Sendable {
    public let id: String
    public let text: String
    public let isComplete: Bool

    public var symbolName: String {
        isComplete ? "checkmark.circle.fill" : "checkmark.circle.dotted"
    }

    public var accessibilityLabel: String {
        "\(text)、\(isComplete ? "完了" : "未完了")"
    }
}
