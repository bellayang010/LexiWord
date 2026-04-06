import XCTest
import UIKit
@testable import LexiWord

// MARK: - NotebookViewModel filtering

@MainActor
final class NotebookViewModelTests: XCTestCase {

    private func makeEntries() -> [NotebookEntry] {
        [
            NotebookEntry(word: "cat",         sentence: "A cat sat on the mat."),
            NotebookEntry(word: "CAT",          sentence: "A CAT scan was ordered."),
            NotebookEntry(word: "catalogue",    sentence: "Browse the winter catalogue."),
            NotebookEntry(word: "dog",          sentence: "A dog barked loudly."),
            NotebookEntry(word: "concatenate",  sentence: "Concatenate two strings together."),
        ]
    }

    func testSearchCatReturnsThreeMatches() {
        let vm = NotebookViewModel()
        vm.searchText = "cat"
        let result = vm.filtered(makeEntries())
        XCTAssertEqual(result.count, 3, "Expected 'cat', 'CAT', 'catalogue' — got \(result.map(\.word))")
    }

    func testSearchIsCaseInsensitive() {
        let vm = NotebookViewModel()
        vm.searchText = "CAT"
        let result = vm.filtered(makeEntries())
        XCTAssertEqual(result.count, 3)
    }

    func testSearchWithNoMatchReturnsEmpty() {
        let vm = NotebookViewModel()
        vm.searchText = "zebra"
        let result = vm.filtered(makeEntries())
        XCTAssertTrue(result.isEmpty)
    }

    func testEmptySearchTermReturnsAllEntries() {
        let vm = NotebookViewModel()
        vm.searchText = ""
        let result = vm.filtered(makeEntries())
        XCTAssertEqual(result.count, 5)
    }
}

// MARK: - DictionaryService

final class DictionaryServiceTests: XCTestCase {

    func testNonsenseWordHasNoContent() {
        let result = DictionaryService().lookup(word: "xqzptw")
        XCTAssertFalse(result.hasContent, "Nonsense word should produce an empty DictionaryResult")
    }

    func testCommonWordHasDefinition() throws {
        try XCTSkipUnless(
            UIReferenceLibraryViewController.dictionaryHasDefinition(forTerm: "apple"),
            "System dictionary unavailable in this environment — skipping positive lookup test."
        )
        let result = DictionaryService().lookup(word: "apple")
        XCTAssertTrue(result.hasContent, "Expected a non-empty result for 'apple'")
    }
}
