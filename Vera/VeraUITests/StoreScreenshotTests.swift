import XCTest

/// Captures the App Store listing screenshots from a believable docs repo
/// (`-VeraUITestStore`). Run on the device the listing size is taken from; the images land
/// in the .xcresult as attachments named `NN-...` (export with xcresulttool).
final class StoreScreenshotTests: VeraUITestCase {

    private func relaunchWithStoreFixture() {
        app.terminate()
        app.launchArguments += ["-VeraUITestStore", "YES"]
        app.launch()
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
        shot("01-file-tree")

        openRow("README.md")
        shot("02-markdown-preview")

        // Scroll to the table and the code block.
        app.swipeUp()
        sleep(1)
        shot("03-preview-table-and-code")
        app.swipeDown()

        let outline = app.buttons["Outline"].firstMatch
        if outline.waitForExistence(timeout: 3) {
            outline.tap()
            sleep(1)
            shot("04-outline")
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
            shot("05-editor")
        }
    }
}
