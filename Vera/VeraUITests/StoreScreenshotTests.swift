import XCTest

/// Captures the App Store listing screenshots from a believable docs repo
/// (`-VeraUITestStore`). Run on the device the listing size is taken from; the images land
/// in the .xcresult as attachments named `NN-...` (export with xcresulttool).
final class StoreScreenshotTests: VeraUITestCase {

    /// `VERA_SHOT_MODE` (passed as `TEST_RUNNER_VERA_SHOT_MODE`) is a comma list of `landscape`
    /// and `dark`; empty means the portrait light listing set.
    private var mode: Set<String> {
        Set((ProcessInfo.processInfo.environment["VERA_SHOT_MODE"] ?? "")
            .split(separator: ",").map(String.init))
    }

    /// Filename prefix for the active mode, so variants never overwrite each other.
    private var prefix: String {
        (mode.contains("landscape") ? "landscape-" : "") + (mode.contains("dark") ? "dark-" : "light-")
    }

    private func relaunchWithStoreFixture() {
        app.terminate()
        XCUIDevice.shared.orientation = mode.contains("landscape") ? .landscapeLeft : .portrait
        app.launchArguments += ["-VeraUITestStore", "YES"]
        app.launch()
        sleep(2)
    }

    /// On a rotated iPad simulator XCUIScreenshot returns a broken composite (portrait canvas
    /// with a black band). When `VERA_SHOT_SIGNAL` names a file, append the shot name to it and
    /// pause so an outside script can grab the real display with `simctl io screenshot`.
    private func capture(_ name: String) {
        shot(prefix + name)
        if let signal = ProcessInfo.processInfo.environment["VERA_SHOT_SIGNAL"] {
            if let h = FileHandle(forWritingAtPath: signal) {
                h.seekToEndOfFile(); h.write((prefix + name + "\n").data(using: .utf8)!); h.closeFile()
            }
            sleep(4)
        }
    }

    private func openRow(_ name: String) {
        let row = app.staticTexts[name].firstMatch
        if !row.waitForExistence(timeout: 3) {
            let root = app.staticTexts["northwind-docs"].firstMatch
            if root.exists { root.tap(); sleep(1) }
        }
        XCTAssertTrue(row.waitForExistence(timeout: 10), "\(name) not in sidebar")
        row.tap()
        sleep(2)
    }

    func testCaptureListingScreenshots() throws {
        relaunchWithStoreFixture()
        revealSidebar()

        // Make sure the folders are open so the tree looks like a real project.
        let root = app.staticTexts["northwind-docs"].firstMatch
        if !app.staticTexts["README.md"].firstMatch.waitForExistence(timeout: 3), root.exists {
            root.tap(); sleep(1)
        }
        for folder in ["docs", "config"] {
            let f = app.staticTexts[folder].firstMatch
            if f.exists, !app.staticTexts[folder == "docs" ? "architecture.md" : "settings.yaml"].firstMatch.exists {
                f.tap(); sleep(1)
            }
        }
        capture("01-file-tree")

        openRow("README.md")
        capture("02-markdown-preview")

        // Scroll to the table and the code block.
        // Drag inside the document pane (right of the sidebar), so it scrolls on iPad landscape
        // as well as on a phone.
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.8))
        let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.2))
        // A wide iPad shows the whole README at once (table and code already in the first
        // shot), so there is nothing to scroll to and a second shot would repeat it.
        if !mode.contains("landscape") {
            from.press(forDuration: 0.1, thenDragTo: to)
            sleep(1)
            from.press(forDuration: 0.1, thenDragTo: to)
            sleep(1)
            capture("03-preview-table-and-code")
            to.press(forDuration: 0.1, thenDragTo: from)
            to.press(forDuration: 0.1, thenDragTo: from)
        }

        let outline = app.buttons["Outline"].firstMatch
        if outline.waitForExistence(timeout: 3) {
            outline.tap()
            sleep(1)
            capture("04-outline")
            app.buttons["Close"].firstMatch.tap()
            sleep(1)
        }

        let edit = app.buttons["Edit"].firstMatch
        if edit.waitForExistence(timeout: 3) {
            edit.tap()
            sleep(1)
            let tv = app.textViews.firstMatch
            if tv.waitForExistence(timeout: 5) {
                tv.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.02)).tap()
                dismissKeyboardTip()
                sleep(1)
            }
            capture("05-editor")
        }
    }
}
