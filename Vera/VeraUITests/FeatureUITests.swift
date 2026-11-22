import XCTest
import UIKit

final class FeatureUITests: VeraUITestCase {

    func testOpenAndOutline() throws {
        open("welcome.md")
        shot("welcome-preview")
        let outline = app.buttons["Outline"].firstMatch
        XCTAssertTrue(outline.waitForExistence(timeout: 5), "no Outline button")
        outline.tap()
        sleep(1)
        shot("outline-sheet")
        XCTAssertTrue(app.staticTexts["Second Part"].firstMatch.waitForExistence(timeout: 3))
        app.staticTexts["Second Part"].firstMatch.tap()
        sleep(1)
        shot("after-outline-jump")
    }

    func testRelativeLinkWithAnchor() throws {
        open("welcome.md")
        let link = app.links["link to other"].firstMatch
        XCTAssertTrue(link.waitForExistence(timeout: 5), "link not in tree")
        link.tap()
        sleep(2)
        shot("after-relative-link")
        XCTAssertTrue(app.staticTexts["Other"].firstMatch.waitForExistence(timeout: 5),
                      "other.md not shown after tapping the link")
        XCTAssertFalse(app.alerts.firstMatch.exists, "link raised an error alert")
    }

    func testWikiLink() throws {
        open("welcome.md")
        let link = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Ideas'")).firstMatch
        XCTAssertTrue(link.waitForExistence(timeout: 5), "wikilink not in tree")
        link.tap()
        sleep(2)
        shot("after-wikilink")
        XCTAssertTrue(app.staticTexts["one"].firstMatch.exists, "Ideas.md content not shown")
        XCTAssertFalse(app.alerts.firstMatch.exists, "wikilink raised an error alert")
    }

    func testListContinuation() throws {
        open("welcome.md")
        let edit = app.buttons["Edit"].firstMatch
        XCTAssertTrue(edit.waitForExistence(timeout: 5), "no Edit button")
        edit.tap()
        sleep(1)
        let tv = app.textViews.firstMatch
        XCTAssertTrue(tv.waitForExistence(timeout: 5), "no text view")
        // Tap on the first line of text; the centre of the view is empty space.
        tv.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.02)).tap()
        dismissKeyboardTip()
        sleep(1)
        shot("editor-focused")
        // Jump to the very end, start a bullet and press Return twice.
        tv.typeText("\n\n- one\ntwo\n")
        sleep(1)
        shot("list-continuation")
        let value = (tv.value as? String) ?? ""
        XCTAssertTrue(value.contains("- one\n- two\n- "), "bullet not continued: \(value.suffix(40))")
        tv.typeText("\n")
        let after = (tv.value as? String) ?? ""
        XCTAssertFalse(after.hasSuffix("- \n- "), "empty bullet should end the list: \(after.suffix(40))")
    }

    func testQuickSwitcher() throws {
        // iPad portrait starts with the sidebar collapsed; the switcher lives in its menu.
        let sidebar = app.buttons["Show Sidebar"].firstMatch
        if sidebar.waitForExistence(timeout: 3) { sidebar.tap(); sleep(1) }
        let more = app.buttons["More options"].firstMatch
        XCTAssertTrue(more.waitForExistence(timeout: 5), "no More options button")
        more.tap()
        sleep(1)
        shot("overflow-menu")
        let item = app.buttons["Go to File…"].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 3), "no Go to File item")
        item.tap()
        sleep(1)
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.typeText("ide")
        dismissKeyboardTip()
        sleep(1)
        shot("quick-switcher")
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Ideas'")).firstMatch.exists, "Ideas not found by fuzzy query")
    }

    func testRename() throws {
        revealSidebar()
        expandFixtureIfNeeded(expecting: "other.md")
        let row = app.staticTexts["other.md"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        // A long press sometimes registers as a tap on a device and opens the file instead.
        var rename = app.buttons["Rename…"].firstMatch
        for attempt in 1...3 {
            row.press(forDuration: 1.5)
            if rename.waitForExistence(timeout: 2) { break }
            print("LONGPRESS attempt \(attempt) did not show the menu")
            let back = app.navigationBars.buttons.firstMatch
            if !row.exists, back.exists { back.tap(); sleep(1); expandFixtureIfNeeded(expecting: "other.md") }
            rename = app.buttons["Rename…"].firstMatch
        }
        shot("context-menu")
        XCTAssertTrue(rename.exists, "no Rename item")
        rename.tap()
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        dismissKeyboardTip()
        let current = (field.value as? String) ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count) + "renamed")
        shot("rename-alert")
        let confirm = app.alerts.buttons["Rename"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 3), "no Rename button in the alert")
        confirm.tap()
        sleep(2)
        if app.alerts.firstMatch.exists {
            // Record it: a tap that doesn't dismiss the alert is worth knowing about.
            print("RENAME-ALERT-STILL-UP after first tap")
            shot("alert-still-up")
            app.alerts.buttons["Rename"].firstMatch.tap()
            sleep(2)
        }
        shot("after-rename")
        XCTAssertTrue(app.staticTexts["renamed.md"].firstMatch.waitForExistence(timeout: 5), "renamed.md missing")
        XCTAssertFalse(app.staticTexts["other.md"].firstMatch.exists, "old name still listed")
    }
}

private extension XCUIElement {
    var hasKeyboardFocus: Bool { (value(forKey: "hasKeyboardFocus") as? Bool) ?? false }
}
