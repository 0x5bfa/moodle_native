import Foundation
import MoodleNativeCore

public struct LmsNotificationDetailPresentation: Identifiable, Sendable {
    public struct Section: Identifiable, Sendable {
        public struct Row: Identifiable, Sendable {
            public enum Content: Sendable {
                case text(String)
                case html(String)
                case link(title: String, url: URL)
            }

            public let id: String
            public let label: String?
            public let content: Content
        }

        public let id: String
        public let title: String?
        public let rows: [Row]
    }

    public let id: String
    public let sections: [Section]

    public init(notification: LmsNotificationItem) {
        id = notification.id
        sections = Self.makeSections(for: notification)
    }
}

public extension LmsNotificationItem {
    var detailPresentation: LmsNotificationDetailPresentation {
        LmsNotificationDetailPresentation(notification: self)
    }
}

extension LmsNotificationDetailPresentation {
    fileprivate static func makeSections(for notification: LmsNotificationItem) -> [Section] {
        let message = trimmedValue(for: notification.fullMessage) ?? notification.bodyText

        switch normalizedEventType(notification.eventType) {
        case "reminders_due":
            return makeReminderSections(notification: notification, message: message)
        default:
            return makeGenericSections(message: message)
        }
    }

    fileprivate static func makeReminderSections(notification: LmsNotificationItem, message: String)
        -> [Section]
    {
        let lines = messageLines(from: message)
        guard lines.isEmpty == false else {
            return makeGenericSections(message: message)
        }

        var summaryRows: [Section.Row] = []
        var descriptionRows: [Section.Row] = []
        let activityURL = extractReminderActivityURL(from: notification.htmlBody)

        if let firstLine = lines.first {
            let titleInfo = splitReminderTitle(from: firstLine)
            summaryRows.append(
                Section.Row(
                    id: makeRowID(sectionID: "reminder-summary", index: 0, label: "タイトル"),
                    label: "タイトル",
                    content: .text(titleInfo.title)
                )
            )

            if let status = titleInfo.status {
                summaryRows.append(
                    Section.Row(
                        id: makeRowID(sectionID: "reminder-summary", index: 1, label: "状態"),
                        label: "状態",
                        content: .text(status)
                    )
                )
            }
        }

        var rowIndex = summaryRows.count
        for line in lines.dropFirst() {
            guard let labelValue = parseLabelValue(from: line) else {
                continue
            }

            let label = labelValue.label
            let value = decodeHTMLEntities(labelValue.value)
            let labelKey = normalizedLabel(label)

            if labelKey == "説明" {
                descriptionRows.append(
                    Section.Row(
                        id: makeRowID(
                            sectionID: "reminder-description", index: descriptionRows.count, label: nil),
                        label: nil,
                        content: .html(value)
                    )
                )
                continue
            }

            if labelKey == "活動", let activityURL {
                summaryRows.append(
                    Section.Row(
                        id: makeRowID(sectionID: "reminder-summary", index: rowIndex, label: label),
                        label: label,
                        content: .link(title: value, url: activityURL)
                    )
                )
            } else {
                summaryRows.append(
                    Section.Row(
                        id: makeRowID(sectionID: "reminder-summary", index: rowIndex, label: label),
                        label: label,
                        content: .text(value)
                    )
                )
            }

            rowIndex += 1
        }

        var sections: [Section] = []
        if summaryRows.isEmpty == false {
            sections.append(
                Section(
                    id: "reminder-summary",
                    title: "概要",
                    rows: summaryRows
                )
            )
        }

        if descriptionRows.isEmpty == false {
            sections.append(
                Section(
                    id: "reminder-description",
                    title: "説明",
                    rows: descriptionRows
                )
            )
        }

        return sections.isEmpty ? makeGenericSections(message: message) : sections
    }

    fileprivate static func makeGenericSections(message: String) -> [Section] {
        let rows = messageLines(from: message).enumerated().compactMap { index, line in
            makeGenericRow(from: line, sectionID: "body", rowIndex: index)
        }

        guard rows.isEmpty == false else {
            return []
        }

        return [
            Section(
                id: "body",
                title: "本文",
                rows: rows
            )
        ]
    }

    fileprivate static func makeGenericRow(from line: String, sectionID: String, rowIndex: Int)
        -> Section.Row?
    {
        let trimmedLine = trimWhitespace(line)
        guard trimmedLine.isEmpty == false else {
            return nil
        }

        if isSeparatorLine(trimmedLine) || trimmedLine == "Links:" {
            return nil
        }

        if let link = parseLinkLine(trimmedLine) {
            return Section.Row(
                id: makeRowID(sectionID: sectionID, index: rowIndex, label: nil),
                label: nil,
                content: .link(title: link.title, url: link.url)
            )
        }

        if trimmedLine.hasPrefix("* ") || trimmedLine.hasPrefix("• ") {
            return Section.Row(
                id: makeRowID(sectionID: sectionID, index: rowIndex, label: nil),
                label: nil,
                content: .text("• \(trimmedLine.dropFirst(2))")
            )
        }

        return Section.Row(
            id: makeRowID(sectionID: sectionID, index: rowIndex, label: nil),
            label: nil,
            content: .text(decodeHTMLEntities(trimmedLine))
        )
    }

    fileprivate static func parseLabelValue(from line: String) -> (label: String, value: String)? {
        let trimmedLine = trimWhitespace(line)
        guard let separatorIndex = trimmedLine.firstIndex(of: ":") else {
            return nil
        }

        let label = String(trimmedLine[..<separatorIndex]).trimmingCharacters(
            in: .whitespacesAndNewlines)
        let valueStart = trimmedLine.index(after: separatorIndex)
        let value = String(trimmedLine[valueStart...]).trimmingCharacters(in: .whitespacesAndNewlines)

        guard label.isEmpty == false, value.isEmpty == false else {
            return nil
        }

        return (decodeHTMLEntities(label), value)
    }

    fileprivate static func parseLinkLine(_ line: String) -> (title: String, url: URL)? {
        let trimmedLine = trimWhitespace(line)

        if let match = firstRegexMatch(
            in: trimmedLine,
            pattern: #"^\[(\d+)\]\s+(https?://.+)$"#
        ) {
            let number = match[1]
            let urlString = decodeHTMLEntities(match[2])
            if let url = URL(string: urlString) {
                return ("リンク \(number)", url)
            }
        }

        if trimmedLine.hasPrefix("http://") || trimmedLine.hasPrefix("https://") {
            let urlString = decodeHTMLEntities(trimmedLine)
            if let url = URL(string: urlString) {
                return (url.absoluteString, url)
            }
        }

        return nil
    }

    fileprivate static func splitReminderTitle(from line: String) -> (title: String, status: String?) {
        let trimmedLine = trimWhitespace(line)
        guard
            let match = firstRegexMatch(
                in: trimmedLine,
                pattern: #"^(.*?)(?:\s+(\[[^\]]+\]))?$"#
            )
        else {
            return (decodeHTMLEntities(trimmedLine), nil)
        }

        let title = decodeHTMLEntities(match[1].trimmingCharacters(in: .whitespacesAndNewlines))
        let status = match[2].isEmpty ? nil : decodeHTMLEntities(match[2])
        return (title, status)
    }

    fileprivate static func extractReminderActivityURL(from html: String?) -> URL? {
        guard let html, html.isEmpty == false else {
            return nil
        }

        guard
            let rawURL = firstRegexMatch(
                in: html,
                pattern: #"(?is)<tr><td[^>]*>\s*活動\s*</td><td>\s*<a[^>]*href="([^"]+)""#
            )?[1]
        else {
            return nil
        }

        return URL(string: decodeHTMLEntities(rawURL))
    }

    fileprivate static func messageLines(from message: String) -> [String] {
        message
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: .newlines)
            .map(trimWhitespace(_:))
            .filter { $0.isEmpty == false }
    }

    fileprivate static func normalizedEventType(_ value: String?) -> String {
        trimmedValue(for: value)?.lowercased() ?? ""
    }

    fileprivate static func normalizedLabel(_ value: String) -> String {
        trimWhitespace(value).lowercased()
    }

    fileprivate static func trimWhitespace(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    fileprivate static func trimmedValue(for value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = trimWhitespace(value)
        return trimmed.isEmpty ? nil : trimmed
    }

    fileprivate static func decodeHTMLEntities(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
    }

    fileprivate static func isSeparatorLine(_ value: String) -> Bool {
        value.range(of: #"^[\-=＿ー—\s]+$"#, options: .regularExpression) != nil
    }

    fileprivate static func makeRowID(sectionID: String, index: Int, label: String?) -> String {
        if let label, label.isEmpty == false {
            return "\(sectionID)-\(index)-\(label)"
        }

        return "\(sectionID)-\(index)"
    }

    fileprivate static func firstRegexMatch(in value: String, pattern: String) -> [String]? {
        guard
            let regex = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive, .dotMatchesLineSeparators]
            )
        else {
            return nil
        }

        let range = NSRange(value.startIndex..., in: value)
        guard let match = regex.firstMatch(in: value, options: [], range: range) else {
            return nil
        }

        return (0..<match.numberOfRanges).compactMap { index in
            let matchRange = match.range(at: index)
            guard matchRange.location != NSNotFound, let swiftRange = Range(matchRange, in: value) else {
                return nil
            }

            return String(value[swiftRange])
        }
    }
}
