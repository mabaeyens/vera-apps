import XCTest

/// Shared setup: a throwaway fixture folder, an app launched into it, and helpers to
/// dump the accessibility tree and attach screenshots (they land in the .xcresult).
class VeraUITestCase: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments = ["-VeraUITestSeed", "YES", "-hasSeenOnboarding", "YES"]
        app.launch()
    }

    /// The first-keyboard "slide to type" tip covers the screen and steals focus.
    func dismissKeyboardTip() {
        let cont = app.buttons["Continue"].firstMatch
        if cont.waitForExistence(timeout: 2) { cont.tap() }
    }

    /// iPad portrait starts with the sidebar collapsed.
    func revealSidebar() {
        let show = app.buttons["Show Sidebar"].firstMatch
        if show.waitForExistence(timeout: 2) { show.tap(); sleep(1) }
    }

    /// The fixture's root folder can start collapsed (it did on a physical device).
    func expandFixtureIfNeeded(expecting name: String) {
        if app.staticTexts[name].firstMatch.waitForExistence(timeout: 3) { return }
        let root = app.staticTexts["uitest-fixture"].firstMatch
        if root.exists { root.tap(); sleep(1) }
    }

    func open(_ name: String) {
        revealSidebar()
        expandFixtureIfNeeded(expecting: name)
        let row = app.staticTexts[name].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "\(name) not in sidebar")
        row.tap()
        sleep(2)
    }


    func shot(_ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    /// Print the accessibility tree so identifiers and labels can be discovered.
    func dumpTree(_ tag: String) {
        print("TREE[\(tag)]\n\(app.debugDescription)")
    }
}
