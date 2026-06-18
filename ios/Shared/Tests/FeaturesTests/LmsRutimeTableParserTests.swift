import Testing

@testable import MoodleNativeFeatures

struct LmsRutimeTableParserTests {
    private let siteURL = "https://moodle.example.edu"

    // MARK: - Helpers

    private func subject(
        courseID: Int,
        title: String,
        room: String,
        isFavorite: Bool = false,
        hasUnreadAnnouncement: Bool = false,
        hasPendingAssignment: Bool = false,
        hasUnreadForum: Bool = false
    ) -> String {
        func icon(_ cls: String, on: Bool) -> String {
            let state = on ? "on" : "off"
            return """
                    <span class="\(state)">
                        <img src="https://moodle.example.edu/theme/image.php/boost/block_rutime_table/1/icon" class="\(cls)" alt="">
                    </span>
                """
        }

        return """
            <div class="subject">
                <a href="\(siteURL)/course/view.php?id=\(courseID)" class="active-course-name">\(title)</a>
                <div class="room">\(room)</div>
                \(icon("favouriteicon", on: isFavorite))
                \(icon("newsicon", on: hasUnreadAnnouncement))
                \(icon("assignicon", on: hasPendingAssignment))
                \(icon("forumicon", on: hasUnreadForum))
            </div>
            """
    }

    // MARK: - Placement parsing

    @Test func parseSingleCourseWithScheduledSlot() {
        let content = subject(courseID: 36022, title: "53338:コンピュータネットワーク(K1)", room: "水1:AC237")

        let placements = LmsRutimeTableParser.parse(content: content, siteURL: siteURL)

        #expect(placements.count == 1)
        let p = placements[0]
        #expect(p.courseID == 36022)
        #expect(p.dayIndex == 2)  // 水 = Wednesday = index 2
        #expect(p.periodIndex == 0)  // period 1 → 0-indexed
        #expect(p.room == "AC237")
        #expect(p.title == "53338:コンピュータネットワーク(K1)")
    }

    @Test func parseMultipleCoursesFromRealHTML() {
        let c1 = subject(courseID: 36022, title: "53338:コンピュータネットワーク(K1)", room: "水1:AC237")
        let c2 = subject(courseID: 36057, title: "53374:ユーザビリティ工学(A1)", room: "月2:H301")
        let c3 = subject(courseID: 36018, title: "53334:ソフトウェア工学(K1)", room: "水2:H301")
        let content = "<table>\(c1)\(c2)\(c3)</table>"

        let placements = LmsRutimeTableParser.parse(content: content, siteURL: siteURL)

        #expect(placements.count == 3)
        #expect(placements[0].courseID == 36022)
        #expect(placements[1].courseID == 36057)
        #expect(placements[1].dayIndex == 0)  // 月 = Monday = index 0
        #expect(placements[1].periodIndex == 1)  // period 2 → 0-indexed
        #expect(placements[2].courseID == 36018)
        #expect(placements[2].dayIndex == 2)
        #expect(placements[2].periodIndex == 1)
    }

    @Test func parsesAllWeekdayIndices() {
        let days: [(Character, Int)] = [("月", 0), ("火", 1), ("水", 2), ("木", 3), ("金", 4)]
        for (kanji, expectedIndex) in days {
            let content = subject(courseID: 100, title: "テスト科目", room: "\(kanji)3:Room101")
            let placements = LmsRutimeTableParser.parse(content: content, siteURL: siteURL)
            #expect(placements.first?.dayIndex == expectedIndex, "Failed for \(kanji)")
        }
    }

    @Test func parsesAllPeriodIndices() {
        for period in 1...5 {
            let content = subject(courseID: 100, title: "テスト科目", room: "月\(period):Room")
            let placements = LmsRutimeTableParser.parse(content: content, siteURL: siteURL)
            #expect(placements.first?.periodIndex == period - 1, "Failed for period \(period)")
        }
    }

    @Test func expandsConsecutivePeriodsJoinedByHyphen() {
        let content = subject(courseID: 36099, title: "53347:計算機科学実験(K1)", room: "木3-4:実験室")

        let placements = LmsRutimeTableParser.parse(content: content, siteURL: siteURL)

        #expect(placements.count == 2)
        #expect(placements.map(\.dayIndex) == [3, 3])
        #expect(placements.map(\.periodIndex) == [2, 3])
        #expect(placements.map(\.room) == ["実験室", "実験室"])
    }

    @Test func expandsConsecutivePeriodsJoinedByJapaneseSeparator() {
        let content = subject(courseID: 36099, title: "53347:計算機科学実験(K1)", room: "木3・4:実験室")

        let placements = LmsRutimeTableParser.parse(content: content, siteURL: siteURL)

        #expect(placements.count == 2)
        #expect(placements.map(\.periodIndex) == [2, 3])
    }

    @Test func parsesFullWidthPeriodDigits() {
        let content = subject(courseID: 36099, title: "53347:計算機科学実験(K1)", room: "木３－４：実験室")

        let placements = LmsRutimeTableParser.parse(content: content, siteURL: siteURL)

        #expect(placements.count == 2)
        #expect(placements.map(\.periodIndex) == [2, 3])
        #expect(placements.map(\.room) == ["実験室", "実験室"])
    }

    @Test func doesNotTreatRoomDigitsAsPeriodsWhenRoomSeparatorIsMissing() {
        let content = subject(courseID: 36099, title: "53347:計算機科学実験(K1)", room: "木3 H301")

        let placements = LmsRutimeTableParser.parse(content: content, siteURL: siteURL)

        #expect(placements.count == 1)
        #expect(placements.first?.periodIndex == 2)
    }

    @Test func tableCellPositionOverridesStaleRoomPeriod() {
        let experiment = subject(
            courseID: 36056,
            title: "53373:計算機科学実験１ (B1)",
            room: "木3:H902"
        )
        let content = """
            <table class="timetable">
                <tr>
                    <td class="time">3</td>
                    <td class="empty"><div>&nbsp;</div></td>
                    <td class="empty"><div>&nbsp;</div></td>
                    <td class="empty"><div>&nbsp;</div></td>
                    <td class="highlight">\(experiment)</td>
                    <td class="empty"><div>&nbsp;</div></td>
                </tr>
                <tr>
                    <td class="time">4</td>
                    <td class="empty"><div>&nbsp;</div></td>
                    <td class="empty"><div>&nbsp;</div></td>
                    <td class="empty"><div>&nbsp;</div></td>
                    <td class="highlight">\(experiment)</td>
                    <td class="empty"><div>&nbsp;</div></td>
                </tr>
            </table>
            """

        let placements = LmsRutimeTableParser.parse(content: content, siteURL: siteURL)

        #expect(placements.count == 2)
        #expect(placements.map(\.dayIndex) == [3, 3])
        #expect(placements.map(\.periodIndex) == [2, 3])
        #expect(placements.map(\.room) == ["H902", "H902"])
    }

    // MARK: - Status icons

    @Test func parsesIsFavoriteWhenOn() {
        let content = subject(courseID: 1, title: "課題", room: "月1:H101", isFavorite: true)
        let placements = LmsRutimeTableParser.parse(content: content, siteURL: siteURL)
        #expect(placements.first?.isFavorite == true)
    }

    @Test func parsesIsFavoriteWhenOff() {
        let content = subject(courseID: 1, title: "課題", room: "月1:H101", isFavorite: false)
        let placements = LmsRutimeTableParser.parse(content: content, siteURL: siteURL)
        #expect(placements.first?.isFavorite == false)
    }

    @Test func parsesHasUnreadAnnouncementWhenOn() {
        let content = subject(courseID: 1, title: "課題", room: "火2:AC101", hasUnreadAnnouncement: true)
        let placements = LmsRutimeTableParser.parse(content: content, siteURL: siteURL)
        #expect(placements.first?.hasUnreadAnnouncement == true)
    }

    @Test func parsesHasPendingAssignmentWhenOn() {
        let content = subject(courseID: 1, title: "課題", room: "水3:H201", hasPendingAssignment: true)
        let placements = LmsRutimeTableParser.parse(content: content, siteURL: siteURL)
        #expect(placements.first?.hasPendingAssignment == true)
    }

    @Test func parsesHasUnreadForumWhenOn() {
        let content = subject(courseID: 1, title: "課題", room: "木4:AC110", hasUnreadForum: true)
        let placements = LmsRutimeTableParser.parse(content: content, siteURL: siteURL)
        #expect(placements.first?.hasUnreadForum == true)
    }

    @Test func iconStateDoesNotBleedAcrossSiblingSpans() throws {
        let content = subject(
            courseID: 1,
            title: "課題",
            room: "木4:AC110",
            isFavorite: true,
            hasUnreadAnnouncement: false,
            hasPendingAssignment: false,
            hasUnreadForum: false
        )

        let placement = try #require(LmsRutimeTableParser.parse(content: content, siteURL: siteURL).first)

        #expect(placement.isFavorite == true)
        #expect(placement.hasUnreadAnnouncement == false)
        #expect(placement.hasPendingAssignment == false)
        #expect(placement.hasUnreadForum == false)
    }

    // MARK: - Edge cases

    @Test func returnsEmptyForEmptyContent() {
        let placements = LmsRutimeTableParser.parse(content: "", siteURL: siteURL)
        #expect(placements.isEmpty)
    }

    @Test func skipsSubjectWithoutCourseID() {
        let content = """
            <div class="subject">
                <a href="/other/page">No course ID here</a>
                <div class="room">月1:H101</div>
            </div>
            """
        let placements = LmsRutimeTableParser.parse(content: content, siteURL: siteURL)
        #expect(placements.isEmpty)
    }

    @Test func courseWithNoRoomHasNilDayAndPeriod() {
        let content = """
            <div class="subject">
                <a href="\(siteURL)/course/view.php?id=999" class="active-course-name">オンデマンド授業</a>
                <div class="room"></div>
            </div>
            </table>
            """
        let placements = LmsRutimeTableParser.parse(content: content, siteURL: siteURL)
        #expect(placements.count == 1)
        #expect(placements[0].courseID == 999)
        #expect(placements[0].dayIndex == nil)
        #expect(placements[0].periodIndex == nil)
        #expect(placements[0].room == nil)
    }

    @Test func detailURLIsResolvedToAbsoluteURL() {
        let content = subject(courseID: 36022, title: "テスト", room: "月1:H101")
        let placements = LmsRutimeTableParser.parse(content: content, siteURL: siteURL)
        #expect(placements.first?.detailURL?.absoluteString == "\(siteURL)/course/view.php?id=36022")
    }
}
