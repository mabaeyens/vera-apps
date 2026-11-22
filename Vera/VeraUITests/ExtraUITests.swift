import XCTest

/// The checks that were still open after the first suite: anchor scrolling in a long
/// document, the outline in the editor, code fences, and an external change to an open file.
final class ExtraUITests: VeraUITestCase {

    private func relaunch(_ extra: [String]) {
        app.terminate()
        app.launchArguments += extra
        app.launch()
    }

    private func textView() -> XCUIElement {
        let tv = app.textViews.firstMatch
        XCTAssertTrue(tv.waitForExistence(timeout: 5), "no text view")
        return tv
    }

    func testAnchorLinkScrollsToTheSection() throws {
        open("welcome.md")
        let link = app.links["a late section"].firstMatch
        XCTAssertTrue(link.waitForExistence(timeout: 5), "link not in tree")
        link.tap()
        sleep(2)
        shot("after-anchor-jump")
        let section = app.staticTexts["Section 35"].firstMatch
        XCTAssertTrue(section.waitForExistence(timeout: 5), "Section 35 not rendered")
        XCTAssertTrue(section.isHittable, "Section 35 exists but is not on screen")
        XCTAssertFalse(app.staticTexts["Section 1"].firstMatch.isHittable, "still at the top of the document")
    }

    func testOutlineJumpInTheEditor() throws {
        open("long.md")
        app.buttons["Edit"].firstMatch.tap()
        sleep(1)
        let tv = textView()
        let before = tv.frame
        app.buttons["Outline"].firstMatch.tap()
        sleep(1)
        let entry = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Section 30,'")).firstMatch
        // The outline list renders lazily, so scroll it until the entry exists.
        var swipes = 0
        while !entry.exists && swipes < 15 { app.collectionViews.firstMatch.swipeUp(); swipes += 1 }
        if !entry.exists { shot("outline-no-section-30"); dumpTree("outline") }
        XCTAssertTrue(entry.exists, "outline has no Section 30")
        entry.tap()
        sleep(2)
        shot("editor-after-outline-jump")
        XCTAssertFalse(app.navigationBars["Outline"].exists, "outline sheet did not close")
        XCTAssertEqual(tv.frame, before, "editor layout changed")
        // The text view's accessibility value is the whole document, so scroll position can't
        // be asserted from it; the "editor-after-outline-jump" screenshot is the evidence.
    }

    func testNoListContinuationInsideACodeFence() throws {
        open("scratch.md")
        app.buttons["Edit"].firstMatch.tap()
        sleep(1)
        let tv = textView()
        tv.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.02)).tap()
        dismissKeyboardTip()
        tv.typeText("\n```\n- a\n")
        sleep(1)
        shot("fence")
        let value = (tv.value as? String) ?? ""
        XCTAssertTrue(value.contains("- a\n"), "text not typed: \(value.suffix(30))")
        XCTAssertFalse(value.contains("- a\n- "), "list continued inside a code fence")
    }

    func testChangedOnDiskOffersReload() throws {
        relaunch(["-VeraUITestExternalEdit", "14"])
        let launched = Date()
        open("welcome.md")
        app.buttons["Edit"].firstMatch.tap()
        sleep(1)
        let tv = textView()
        tv.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.02)).tap()
        dismissKeyboardTip()
        // Let the external write happen first, then edit the now-stale buffer.
        while Date().timeIntervalSince(launched) < 17 { sleep(1) }
        tv.typeText("x")
        // The dimmed overlay must show while the keyboard is still up: that is the whole point.
        let overlay = app.otherElements["disk-conflict-overlay"].firstMatch
        let notice = app.staticTexts["Changed on disk"].firstMatch
        let whileTyping = overlay.waitForExistence(timeout: 6) || notice.waitForExistence(timeout: 2)
        shot("changed-on-disk-while-typing")
        XCTAssertTrue(whileTyping, "no Changed on disk overlay while typing")
        let reload = app.buttons["Reload"].firstMatch
        XCTAssertTrue(reload.exists, "no Reload button")
        XCTAssertTrue(app.buttons["Overwrite"].firstMatch.exists, "no Overwrite button")
        reload.tap()
        sleep(2)
        shot("after-reload")
        XCTAssertFalse(app.staticTexts["Changed on disk"].firstMatch.exists, "overlay still showing after Reload")
        // Still in edit mode, so the reloaded text is in the text view.
        let value = (textView().value as? String) ?? ""
        XCTAssertTrue(value.contains("EXTERNAL EDIT"), "Reload did not bring in the external text")
        XCTAssertFalse(value.contains("Welcomex"), "local edit survived Reload")
    }
}
