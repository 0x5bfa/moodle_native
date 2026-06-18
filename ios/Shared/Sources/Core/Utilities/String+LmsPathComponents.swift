import Foundation

extension String {
    public var lmsPathComponents: [String] {
        split(separator: "/")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
    }

    public var singleLineDisplayText: String {
        replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
    }
}

extension Optional where Wrapped == String {
    public var singleLineDisplayText: String? {
        guard let value = self?.singleLineDisplayText,
            value.isEmpty == false
        else {
            return nil
        }

        return value
    }
}
