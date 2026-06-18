import Foundation

public enum LmsCourseTitleParser {
    public static func parse(_ value: String) -> (courseCode: String?, title: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let separatorIndex = trimmed.firstIndex(of: ":") else {
            return (nil, trimmed)
        }

        let codeCandidate = trimmed[..<separatorIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        let titleCandidate = trimmed[trimmed.index(after: separatorIndex)...].trimmingCharacters(
            in: .whitespacesAndNewlines)

        let courseCode = codeCandidate.isEmpty ? nil : codeCandidate
        let title = titleCandidate.isEmpty ? trimmed : titleCandidate
        return (courseCode, title)
    }
}
