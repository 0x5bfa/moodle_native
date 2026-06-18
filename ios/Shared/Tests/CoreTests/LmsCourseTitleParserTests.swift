import Testing

@testable import MoodleNativeCore

struct LmsCourseTitleParserTests {
    @Test func parseCourseTitleIntoCourseCodeAndTitle() {
        let parsed = LmsCourseTitleParser.parse("54580:中国の国家と社会(GV)")

        #expect(parsed.courseCode == "54580")
        #expect(parsed.title == "中国の国家と社会(GV)")
    }
}
