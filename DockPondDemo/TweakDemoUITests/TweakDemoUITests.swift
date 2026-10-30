import XCTest

@MainActor
final class TweakDemoUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-resetTweaks"]
        app.launch()
    }

    func testEditsCardTweaksAndKeepsThemAfterRelaunch() {
        screenshot("1 Demo with defaults")

        app.buttons["openTweaks"].tap()
        XCTAssertTrue(app.navigationBars["Tweaks"].waitForExistence(timeout: 5))
        screenshot("2 Collections")

        app.buttons["Card"].tap()
        XCTAssertTrue(app.navigationBars["Card"].waitForExistence(timeout: 5))
        screenshot("3 Card collection with defaults")

        let title = app.textFields["Title"]
        title.tap()
        title.typeText("Tweaked ")
        let editedTitle = title.value as? String ?? ""
        XCTAssertTrue(editedTitle.contains("Tweaked"))
        title.typeText("\n")

        increment("Font Size", times: 2)
        increment("Badge Count")

        option("Accent").tap()
        XCTAssertTrue(app.navigationBars["Accent"].waitForExistence(timeout: 5))
        screenshot("4 Accent options")
        app.buttons["purple"].tap()

        app.switches["Shows Shadow"].switches.firstMatch.tap()
        screenshot("5 Card collection after edits")

        app.buttons["Done"].tap()

        assertValue("Title", editedTitle)
        assertValue("Font Size", "22")
        assertValue("Badge Count", "4")
        assertValue("Accent", "purple")
        assertValue("Shows Shadow", "false")
        screenshot("6 Demo after edits")

        app.terminate()
        app.launchArguments = []
        app.launch()
        assertValue("Title", editedTitle)
        assertValue("Badge Count", "4")
    }

    func testRunsActionAndResetsFromTweaksWindow() {
        app.buttons["openTweaksWindow"].tap()
        XCTAssertTrue(app.navigationBars["Tweaks"].waitForExistence(timeout: 5))

        app.buttons["App"].tap()
        app.buttons["Clear Cache"].tap()
        app.switches["Dark Mode"].switches.firstMatch.tap()
        increment("Max Retries")

        option("Environment").tap()
        app.buttons["staging"].tap()
        screenshot("7 App collection after edits")

        app.buttons["Done"].tap()
        assertValue("Cache Cleared", "1")
        assertValue("Dark Mode", "true")
        assertValue("Max Retries", "4")
        assertValue("Environment", "staging")
        screenshot("8 Demo in dark mode")

        app.buttons["openTweaksWindow"].tap()
        app.buttons["Reset All"].tap()
        screenshot("9 Reset confirmation")
        app.buttons["Reset All Tweaks"].tap()
        app.buttons["Done"].tap()
        assertValue("Dark Mode", "false")
        assertValue("Max Retries", "3")
        assertValue("Environment", "production")
    }

    private func increment(_ name: String, times: Int = 1) {
        let button = app.buttons.matching(NSPredicate(format: "identifier == 'Increment' AND label BEGINSWITH %@", name)).firstMatch
        for _ in 0 ..< times {
            button.tap()
        }
    }

    private func option(_ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(name), ")).firstMatch
    }

    private func assertValue(_ name: String, _ expected: String, file: StaticString = #filePath, line: UInt = #line) {
        let element = app.staticTexts["value.\(name)"]
        XCTAssertTrue(element.waitForExistence(timeout: 5), "\(name) is not shown", file: file, line: line)
        XCTAssertEqual(element.label, expected, name, file: file, line: line)
    }

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
