import XCTest
import SwiftData
@testable import CoreDomain

final class CoreDomainTests: XCTestCase {
    func testScoreCreation() {
        let score = Score(title: "Moonlight Sonata", composer: "Beethoven")
        XCTAssertEqual(score.title, "Moonlight Sonata")
        XCTAssertEqual(score.composer, "Beethoven")
        XCTAssertFalse(score.isFavorite)
        XCTAssertFalse(score.isArchived)
    }

    func testSetListCreation() {
        let setList = SetList(name: "Sunday Service")
        XCTAssertEqual(setList.name, "Sunday Service")
        XCTAssertTrue(setList.items.isEmpty)
    }

    func testBookmarkCreation() {
        let bookmark = Bookmark(name: "Coda", pageIndex: 5)
        XCTAssertEqual(bookmark.name, "Coda")
        XCTAssertEqual(bookmark.pageIndex, 5)
    }

    func testViewingPreferencesDefaults() {
        let prefs = ViewingPreferences()
        XCTAssertEqual(prefs.displayMode, .singlePage)
        XCTAssertEqual(prefs.paperTheme, .light)
        XCTAssertEqual(prefs.zoomLevel, 1.0)
        XCTAssertFalse(prefs.isCropMarginsEnabled)
    }

    func testAllModelTypesPopulated() {
        XCTAssertEqual(allModelTypes.count, 14)
    }
}
