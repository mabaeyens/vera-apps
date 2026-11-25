import XCTest

/// The sidebar listing (what is shown and hidden), sorting, and the large-CSV preview.
/// Runs against the `-VeraUITestScan` fixture folder.
final class ScanUITests: VeraUITestCase {

    private let bool = ["true": "<true/>", "false": "<false/>"]

    /// Relaunch into the scan fixture, with any extra defaults.
    private func launchScan(_ extra: [String] = []) {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["-VeraUITestSeed", "YES", "-VeraUITestScan", "YES",
                               "-hasSeenOnboarding", "YES"] + extra
        app.launch()
        revealSidebar()
        if !app.staticTexts["Makefile"].firstMatch.waitForExistence(timeout: 3) {
            let root = app.staticTexts["uitest-scan"].firstMatch
            if root.exists { root.tap(); sleep(1) }
        }
        XCTAssertTrue(app.staticTexts["Makefile"].firstMatch.waitForExistence(timeout: 10), "scan fixture not listed")
    }

    private func row(_ name: String) -> XCUIElement { app.staticTexts[name].firstMatch }

    private func y(_ name: String, file: StaticString = #filePath, line: UInt = #line) -> CGFloat {
        let r = row(name)
        XCTAssertTrue(r.waitForExistence(timeout: 5), "\(name) not in sidebar", file: file, line: line)
        return r.frame.minY
    }

    private func sort(_ key: String, ascending: Bool, foldersOnTop: Bool = false) -> [String] {
        ["-sidebarSortKey", key,
         "-sidebarSortAscending", ascending ? bool["true"]! : bool["false"]!,
         "-sidebarFoldersOnTop", foldersOnTop ? bool["true"]! : bool["false"]!,
         "-showHiddenFiles", bool["true"]!]
    }

    // MARK: Listing

    func testListsOpenableFilesAndHidesBinaries() throws {
        launchScan(["-showHiddenFiles", bool["true"]!])
        for name in ["Makefile", "app.conf", ".env", "odd.xyz", "legacy.cfg", "alpha.txt", "big.csv"] {
            XCTAssertTrue(row(name).exists, "\(name) should be listed")
        }
        for name in ["watch.pbw", "book.epub", "doc.pdf", "blob.dat"] {
            XCTAssertFalse(row(name).exists, "\(name) should be hidden")
        }
        XCTAssertTrue(row("folder-a").exists && row("folder-b").exists, "folders should always be listed")
        shot("scan-listing")
    }

    func testHiddenFilesFollowTheSetting() throws {
        launchScan(["-showHiddenFiles", bool["false"]!])
        XCTAssertFalse(row(".env").exists, ".env should be hidden when the setting is off")
        XCTAssertTrue(row("Makefile").exists)
    }

    func testLatin1FileOpens() throws {
        launchScan()
        row("legacy.cfg").tap()
        sleep(2)
        let match = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS 'Configuración' OR value CONTAINS 'Configuración'")).firstMatch
        XCTAssertTrue(match.waitForExistence(timeout: 5), "Latin-1 text did not decode")
        shot("scan-latin1")
    }

    // MARK: Sorting

    func testSortByNameAscending() throws {
        launchScan(sort("name", ascending: true))
        XCTAssertLessThan(y("alpha.txt"), y("bravo.txt"))
        XCTAssertLessThan(y("bravo.txt"), y("charlie.txt"))
    }

    func testSortByNameDescending() throws {
        launchScan(sort("name", ascending: false))
        XCTAssertLessThan(y("charlie.txt"), y("bravo.txt"))
        XCTAssertLessThan(y("bravo.txt"), y("alpha.txt"))
    }

    func testSortByDateNewestFirstIsTheDefault() throws {
        launchScan()
        XCTAssertLessThan(y("bravo.txt"), y("charlie.txt"))
        XCTAssertLessThan(y("charlie.txt"), y("alpha.txt"))
    }

    func testSortByDateOldestFirst() throws {
        launchScan(sort("dateModified", ascending: true))
        XCTAssertLessThan(y("alpha.txt"), y("charlie.txt"))
        XCTAssertLessThan(y("charlie.txt"), y("bravo.txt"))
    }

    func testSortBySizeAscending() throws {
        launchScan(sort("size", ascending: true))
        XCTAssertLessThan(y("bravo.txt"), y("charlie.txt"))
        XCTAssertLessThan(y("charlie.txt"), y("alpha.txt"))
    }

    func testSortBySizeDescending() throws {
        launchScan(sort("size", ascending: false))
        XCTAssertLessThan(y("alpha.txt"), y("charlie.txt"))
        XCTAssertLessThan(y("charlie.txt"), y("bravo.txt"))
    }

    func testFoldersAfterFilesByDefault() throws {
        launchScan()
        XCTAssertLessThan(y("alpha.txt"), y("folder-a"), "folders should sit below files by default")
    }

    func testFoldersOnTop() throws {
        launchScan(sort("name", ascending: true, foldersOnTop: true))
        XCTAssertLessThan(y("folder-a"), y("alpha.txt"), "folders should sit above files")
        XCTAssertLessThan(y("folder-a"), y("folder-b"))
    }

    // MARK: Large CSV preview

    func testLargeCSVOpensAsAReadOnlyPreview() throws {
        launchScan()
        row("big.csv").tap()
        sleep(3)
        shot("scan-big-csv")
        let notice = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Large file: showing the first 100 rows'")).firstMatch
        XCTAssertTrue(notice.waitForExistence(timeout: 5), "no preview notice")
        let has: (String) -> Bool = { marker in
            self.app.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", marker, marker)).firstMatch.exists
        }
        XCTAssertTrue(has("ROW-00099"), "early rows should be present")
        XCTAssertFalse(has("ROW-00101"), "rows past the preview limit should not load")
        XCTAssertFalse(app.buttons["Edit"].firstMatch.exists, "a truncated preview must not be editable")
    }

    func testSmallCSVStaysEditable() throws {
        launchScan()
        row("small.csv").tap()
        sleep(2)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Large file'")).firstMatch.exists)
        XCTAssertTrue(app.buttons["Edit"].firstMatch.waitForExistence(timeout: 5), "small CSV should be editable")
    }
}
