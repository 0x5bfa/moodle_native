import Foundation
import MoodleNativeNetworking

public enum LmsRutimeTableParser {
    public struct CoursePlacement: Equatable, Sendable {
        public let courseID: Int
        public let title: String
        public let room: String?
        public let dayIndex: Int?
        public let periodIndex: Int?
        public let detailURL: URL?
        public let isFavorite: Bool
        public let hasUnreadAnnouncement: Bool
        public let hasPendingAssignment: Bool
        public let hasUnreadForum: Bool
    }

    private static let dayMap: [Character: Int] = [
        "月": 0,
        "火": 1,
        "水": 2,
        "木": 3,
        "金": 4,
    ]

    public static func parse(from snapshot: LmsWebServiceClient.DashboardSnapshot) -> [CoursePlacement] {
        parse(dashboardBlocks: snapshot.dashboardBlocks, siteURL: snapshot.siteURL)
    }

    public static func parse(
        dashboardBlocks: [LmsWebServiceClient.DashboardBlock],
        siteURL: String
    ) -> [CoursePlacement] {
        let block = dashboardBlocks.first { block in
            if block.name == "rutime_table" {
                return true
            }

            guard let content = block.contents?.content else {
                return false
            }

            return content.contains("class=\"subject\"")
                && content.contains("active-course-name")
        }

        guard let content = block?.contents?.content, content.isEmpty == false else {
            return []
        }

        return parse(content: content, siteURL: siteURL)
    }

    public static func parse(content: String, siteURL: String) -> [CoursePlacement] {
        let normalized = content.replacingOccurrences(of: "\r\n", with: "\n")

        let tablePlacements = parseTablePlacements(content: normalized, siteURL: siteURL)
        if tablePlacements.isEmpty == false {
            return tablePlacements
        }

        let subjects = captureGroups(
            pattern: #"<div\s+class=\"subject\">([\s\S]*?)(?=<div\s+class=\"subject\">|</table>|$)"#,
            in: normalized
        )

        var placements: [CoursePlacement] = []

        for subject in subjects {
            placements.append(contentsOf: parseSubjectPlacements(subject, siteURL: siteURL))
        }

        return placements
    }

    private static func parseTablePlacements(content: String, siteURL: String) -> [CoursePlacement] {
        let rows = captureGroups(pattern: #"<tr[^>]*>([\s\S]*?)</tr>"#, in: content)
        var placements: [CoursePlacement] = []

        for row in rows {
            guard
                let periodText = firstMatch(pattern: #"<td\s+class=\"time\"[^>]*>([\s\S]*?)</td>"#, in: row),
                let periodNumber = Int(normalizedDigits(decodeHTMLText(periodText).trimmingCharacters(in: .whitespacesAndNewlines)))
            else {
                continue
            }

            let cells = captureGroups(
                pattern: #"<td\s+class=\"(?:highlight|empty)[^\"]*\"[^>]*>([\s\S]*?)</td>"#,
                in: row
            )

            for (cellIndex, cell) in cells.enumerated() {
                let subjects = captureGroups(
                    pattern: #"<div\s+class=\"subject\">([\s\S]*?)(?=<div\s+class=\"subject\">|$)"#,
                    in: cell
                )

                for subject in subjects {
                    placements.append(
                        contentsOf: parseSubjectPlacements(
                            subject,
                            siteURL: siteURL,
                            dayIndexOverride: cellIndex < 5 ? cellIndex : nil,
                            periodIndexOverride: periodNumber - 1
                        )
                    )
                }
            }
        }

        return placements
    }

    private static func parseSubjectPlacements(
        _ subject: String,
        siteURL: String,
        dayIndexOverride: Int? = nil,
        periodIndexOverride: Int? = nil
    ) -> [CoursePlacement] {
        guard
            let courseIDString = firstMatch(
                pattern: #"course/view\.php\?id=(\d+)"#,
                in: subject
            ),
            let courseID = Int(courseIDString)
        else {
            return []
        }

        let title = decodeHTMLText(
            firstMatch(
                pattern: #"<a[^>]*class=\"active-course-name\"[^>]*>([\s\S]*?)</a>"#,
                in: subject
            ) ?? ""
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)

        let roomText = decodeHTMLText(
            firstMatch(
                pattern: #"<div\s+class=\"room\">([\s\S]*?)</div>"#,
                in: subject
            ) ?? ""
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)

        let (parsedDayIndex, parsedPeriodIndices, room) = parseRoom(roomText)
        let detailURL: URL?
        if let href = firstMatch(pattern: #"<a[^>]*href=\"([^\"]+)\""#, in: subject) {
            detailURL = resolvedURL(from: href, siteURL: siteURL)
        } else {
            detailURL = URL(string: "\(siteURL)/course/view.php?id=\(courseID)")
        }

        let dayIndex = dayIndexOverride ?? parsedDayIndex
        let periodIndices = if let periodIndexOverride {
            [periodIndexOverride]
        } else {
            parsedPeriodIndices
        }

        if periodIndices.isEmpty {
            return [
                CoursePlacement(
                    courseID: courseID,
                    title: title,
                    room: room,
                    dayIndex: dayIndex,
                    periodIndex: nil,
                    detailURL: detailURL,
                    isFavorite: isIconOn("favouriteicon", in: subject),
                    hasUnreadAnnouncement: isIconOn("newsicon", in: subject),
                    hasPendingAssignment: isIconOn("assignicon", in: subject),
                    hasUnreadForum: isIconOn("forumicon", in: subject)
                )
            ]
        }

        return periodIndices.map { periodIndex in
            CoursePlacement(
                courseID: courseID,
                title: title,
                room: room,
                dayIndex: dayIndex,
                periodIndex: periodIndex,
                detailURL: detailURL,
                isFavorite: isIconOn("favouriteicon", in: subject),
                hasUnreadAnnouncement: isIconOn("newsicon", in: subject),
                hasPendingAssignment: isIconOn("assignicon", in: subject),
                hasUnreadForum: isIconOn("forumicon", in: subject)
            )
        }
    }

    private static func parseRoom(_ value: String) -> (Int?, [Int], String?) {
        guard value.isEmpty == false else {
            return (nil, [], nil)
        }

        let parts = splitScheduleAndRoom(value)
        let scheduleText = parts.schedule
        let pattern = #"([月火水木金])"#
        guard let dayToken = firstMatch(pattern: pattern, in: scheduleText, group: 1),
            let dayCharacter = dayToken.first,
            let dayIndex = dayMap[dayCharacter]
        else {
            return (nil, [], value)
        }

        let room = parts.room?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return (
            dayIndex,
            periodNumbers(in: scheduleText).map { $0 - 1 },
            room?.isEmpty == true ? nil : room
        )
    }

    private static func splitScheduleAndRoom(_ value: String) -> (schedule: String, room: String?) {
        guard let separatorIndex = value.firstIndex(where: { $0 == ":" || $0 == "：" }) else {
            return (value, nil)
        }

        let schedule = String(value[..<separatorIndex])
        let roomStartIndex = value.index(after: separatorIndex)
        let room = String(value[roomStartIndex...])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return (schedule, room)
    }

    private static func periodNumbers(in text: String) -> [Int] {
        guard let periodText = firstMatch(
            pattern: #"([月火水木金])\s*([0-9０-９]+(?:\s*[-－〜~～・･,，/／、]\s*[月火水木金]?\s*[0-9０-９]+)*)"#,
            in: text,
            group: 2
        ) else {
            return []
        }

        return captureGroups(pattern: #"([0-9０-９]+)"#, in: periodText)
            .compactMap { Int(normalizedDigits($0)) }
            .filter { $0 > 0 }
    }

    private static func normalizedDigits(_ value: String) -> String {
        value.unicodeScalars.map { scalar in
            let value = scalar.value
            if (0xFF10...0xFF19).contains(value),
                let scalar = UnicodeScalar(value - 0xFF10 + 0x30)
            {
                return String(scalar)
            }

            return String(scalar)
        }
        .joined()
    }

    private static func isIconOn(_ iconClass: String, in text: String) -> Bool {
        let escapedIconClass = NSRegularExpression.escapedPattern(for: iconClass)
        let pattern =
            #"(<span\s+class=\"on\">(?:(?!</span>)[\s\S])*?class=\"[^\"]*\b"# + escapedIconClass
            + #"\b[^\"]*\")"#
        return firstMatch(pattern: pattern, in: text) != nil
    }

    private static func decodeHTMLText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
    }

    private static func resolvedURL(from href: String, siteURL: String) -> URL? {
        if let absoluteURL = URL(string: href), absoluteURL.scheme != nil {
            return absoluteURL
        }

        guard let baseURL = URL(string: siteURL) else {
            return nil
        }

        return URL(string: href, relativeTo: baseURL)?.absoluteURL
    }

    private static func captureGroups(pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }

        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)

        return regex.matches(in: text, options: [], range: range).compactMap { match in
            guard match.numberOfRanges > 1 else {
                return nil
            }

            let groupRange = match.range(at: 1)
            guard groupRange.location != NSNotFound else {
                return nil
            }

            return nsText.substring(with: groupRange)
        }
    }

    private static func firstMatch(pattern: String, in text: String, group: Int = 1) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }

        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)

        guard let match = regex.firstMatch(in: text, options: [], range: range),
            match.numberOfRanges > group
        else {
            return nil
        }

        let groupRange = match.range(at: group)
        guard groupRange.location != NSNotFound else {
            return nil
        }

        return nsText.substring(with: groupRange)
    }
}
