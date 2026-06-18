import XCTest

final class MoodleNativeUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    func testMainTabsAreAccessible() throws {
        let app = XCUIApplication()
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        XCTAssertTrue(tabBar.buttons["ホーム"].exists)
        XCTAssertTrue(tabBar.buttons["課題"].exists)
        XCTAssertTrue(tabBar.buttons["時間割"].exists)
        XCTAssertTrue(tabBar.buttons["通知"].exists)
        XCTAssertTrue(tabBar.buttons["設定"].exists)
    }

    @MainActor
    func testNotificationsLoginPromptIsAccessible() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_FORCE_LOGGED_OUT"]
        app.launch()

        XCTAssertTrue(app.staticTexts["ようこそ Moodle Native へ"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["続ける"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["学内情報をまとめて確認"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testTimetableCourseDetailNavigationIsAccessible() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_SAMPLE_TIMETABLE", "UITEST_START_TIMETABLE"]
        app.launch()

        let timetableTab = app.tabBars.buttons["時間割"]
        XCTAssertTrue(timetableTab.waitForExistence(timeout: 5))
        timetableTab.tap()

        let courseButton = app.buttons.containing(.staticText, identifier: "ユーザビリティ工学").firstMatch
        XCTAssertTrue(courseButton.waitForExistence(timeout: 5))
        courseButton.tap()

        XCTAssertTrue(app.navigationBars["ユーザビリティ工学"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["概要"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["課題"].exists)
        XCTAssertTrue(app.staticTexts["未読アナウンスメント"].exists)
    }
}
