import XCTest

final class OrientationUITests: XCTestCase {
    @MainActor
    func testAppRotatesToEveryOrientation() {
        let app = XCUIApplication()
        app.launch()
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))

        let orientations: [(UIDeviceOrientation, String, Bool)] = [
            (.portrait, "portrait", false),
            (.landscapeLeft, "landscape-left", true),
            (.portraitUpsideDown, "upside-down", false),
            (.landscapeRight, "landscape-right", true),
        ]
        for (orientation, name, isLandscape) in orientations {
            XCUIDevice.shared.orientation = orientation
            Thread.sleep(forTimeInterval: 1.5)
            let frame = window.frame
            print("ORIENTATION \(name): window \(frame.width) x \(frame.height)")
            snapshot("orientation-\(name)")
            XCTAssertEqual(frame.width > frame.height, isLandscape, "Window follows \(name)")
        }
        XCUIDevice.shared.orientation = .portrait
    }
}
