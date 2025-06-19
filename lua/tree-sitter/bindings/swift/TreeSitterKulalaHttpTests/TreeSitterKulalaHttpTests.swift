import XCTest
import SwiftTreeSitter
import TreeSitterKulalaHttp

final class TreeSitterKulalaHttpTests: XCTestCase {
    func testCanLoadGrammar() throws {
        let parser = Parser()
        let language = Language(language: tree_sitter_kulala_http())
        XCTAssertNoThrow(try parser.setLanguage(language),
                         "Error loading Kulala HTTP grammar")
    }
}
