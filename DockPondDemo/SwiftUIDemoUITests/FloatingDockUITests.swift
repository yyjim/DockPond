import XCTest

final class FloatingDockUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += [
            "-FloatingDock.dev-tools.edge", "trailing", "-FloatingDock.dev-tools.fraction", "0.7",
            "-FloatingDock.gauge.edge", "leading", "-FloatingDock.gauge.fraction", "0.7",
            "-FloatingDock.style.edge", "trailing", "-FloatingDock.style.fraction", "0.35",
        ]
        app.launch()
    }

    @MainActor
    func testButtonDocksToNearestEdgeAfterDrag() {
        let button = app.buttons["FloatingDock.dev-tools.button"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(button.frame.midX, app.frame.midX, "Button starts on the trailing edge")
        snapshot("1-start")

        button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.4)))
        waitForAnimations()
        XCTAssertLessThan(button.frame.minX, app.frame.width * 0.15, "Button docks on the leading edge")
        snapshot("2-docked-leading")

        button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.97)))
        waitForAnimations()
        XCTAssertGreaterThan(button.frame.maxY, app.frame.height * 0.8, "Button docks on the bottom edge")
        snapshot("3-docked-bottom")
    }

    @MainActor
    func testTapExpandsAndOutsideTapCollapses() {
        let button = app.buttons["FloatingDock.dev-tools.button"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))

        button.tap()
        let close = app.buttons["Close"]
        XCTAssertTrue(close.waitForExistence(timeout: 2), "Panel opens on tap")
        snapshot("4-expanded")

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.1)).tap()
        waitForAnimations()
        XCTAssertFalse(close.isHittable, "Panel closes on an outside tap")

        button.tap()
        XCTAssertTrue(close.waitForExistence(timeout: 2))
        close.tap()
        waitForAnimations()
        XCTAssertFalse(close.isHittable, "Panel closes with the close button")
        XCTAssertTrue(button.isHittable)
    }

    @MainActor
    func testHistoryActionClosesPanelAndOpensSheet() throws {
        let button = app.buttons["FloatingDock.dev-tools.button"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))

        button.tap()
        XCTAssertTrue(app.buttons["Controls"].waitForExistence(timeout: 3), "Panel opens on tap")
        try skipWithoutHinge()
        app.buttons["Controls"].tap()
        let history = app.buttons["History"]
        XCTAssertTrue(history.waitForExistence(timeout: 3), "Controls tool shows the History action")
        history.tap()

        XCTAssertTrue(app.navigationBars["Hinge History"].waitForExistence(timeout: 3), "History sheet opens")
        waitForAnimations()
        XCTAssertFalse(app.buttons["Close"].exists && app.buttons["Close"].isHittable, "Panel closes before the sheet opens")
        XCTAssertTrue(button.isHittable, "Button stays available above the sheet")
        snapshot("5-history-with-button")
    }

    @MainActor
    func testControlsChangeTheAppAndKeepThePanelOpen() {
        let button = app.buttons["FloatingDock.dev-tools.button"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()

        let panel = app.descendants(matching: .any)["FloatingDock.dev-tools.panel"]
        XCTAssertTrue(panel.waitForExistence(timeout: 3))
        app.buttons["Controls"].tap()
        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Canyon"].exists, "Next selects the second item")
        app.buttons["Appearance"].tap()
        XCTAssertTrue(app.buttons["Dark"].waitForExistence(timeout: 2), "Appearance tab opens")
        app.buttons["Dark"].tap()
        waitForAnimations()
        XCTAssertTrue(panel.exists && panel.isHittable, "Panel stays open while the controls change the app")
        snapshot("6-controls-dark")
    }

    @MainActor
    func testElementToolsChangeTheAppAndKeepThePanelOpen() throws {
        let button = app.buttons["FloatingDock.dev-tools.button"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()

        let panel = app.descendants(matching: .any)["FloatingDock.dev-tools.panel"]
        XCTAssertTrue(panel.waitForExistence(timeout: 3))
        try skipWithoutHinge()
        app.buttons["General"].tap()
        let foldLine = app.switches["Fold line"]
        XCTAssertTrue(foldLine.waitForExistence(timeout: 2), "General tab shows the element tools")
        let wasOn = foldLine.value as? String == "1"
        foldLine.switches.firstMatch.tap()
        XCTAssertNotEqual(foldLine.value as? String == "1", wasOn, "Fold line toggle changes the value")
        app.buttons["Half"].tap()
        XCTAssertTrue(app.buttons["Half"].isSelected, "Hinge selector selects Half")
        XCTAssertTrue(panel.isHittable, "Panel stays open while the elements change the app")
        snapshot("10-elements")
    }

    @MainActor
    func testStyleDockShowsElementsWithoutTabs() {
        let button = app.buttons["FloatingDock.style.button"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()

        let panel = app.descendants(matching: .any)["FloatingDock.style.panel"]
        XCTAssertTrue(panel.waitForExistence(timeout: 3), "Style panel opens")
        XCTAssertFalse(app.buttons["General"].exists, "Panel with only element tools has no tabs or section header")
        app.buttons["Mono"].tap()
        XCTAssertTrue(app.buttons["Mono"].isSelected, "Fill selector selects Mono")
        app.switches["Summaries"].switches.firstMatch.tap()
        XCTAssertFalse(app.staticTexts["Green ribbons of light move across a polar sky."].exists, "Summaries toggle hides the summaries")
        XCTAssertTrue(panel.isHittable, "Panel stays open while the elements change the app")
        snapshot("11-style")
        app.buttons["Reset"].tap()
        XCTAssertTrue(app.buttons["Gradient"].isSelected, "Reset restores the default style")
    }

    @MainActor
    func testTwoDocksOpenOneAtATime() {
        let duo = app.buttons["FloatingDock.dev-tools.button"]
        let gauge = app.buttons["FloatingDock.gauge.button"]
        XCTAssertTrue(duo.waitForExistence(timeout: 5))
        XCTAssertTrue(gauge.waitForExistence(timeout: 5))
        XCTAssertLessThan(gauge.frame.midX, app.frame.midX, "Gauge dock is on the leading edge")
        XCTAssertGreaterThan(duo.frame.midX, app.frame.midX, "Test controls dock is on the trailing edge")

        let gaugePanel = app.descendants(matching: .any)["FloatingDock.gauge.panel"]
        let duoPanel = app.descendants(matching: .any)["FloatingDock.dev-tools.panel"]

        gauge.tap()
        XCTAssertTrue(gaugePanel.waitForExistence(timeout: 3), "Gauge panel opens")
        XCTAssertTrue(app.staticTexts["Window"].exists, "Gauge panel shows the window row")
        snapshot("8-gauge-panel")

        duo.tap()
        XCTAssertTrue(duoPanel.waitForExistence(timeout: 3), "Test controls panel opens")
        waitForAnimations()
        XCTAssertFalse(gaugePanel.exists && gaugePanel.isHittable, "Opening one dock closes the other")
        app.buttons["Controls"].tap()
        XCTAssertTrue(app.buttons["Next"].exists, "Dev Tools panel shows the Controls tool")
        snapshot("9-controls-panel")
    }

    /// The hinge controls and the History action appear only on a device with a hinge.
    private func skipWithoutHinge() throws {
        try XCTSkipUnless(app.buttons["General"].exists, "Needs a device with a hinge, such as iPhone Duo")
    }

    private func waitForAnimations() {
        Thread.sleep(forTimeInterval: 0.8)
    }
}
