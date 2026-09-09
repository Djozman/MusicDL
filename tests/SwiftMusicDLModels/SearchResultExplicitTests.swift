import XCTest
@testable import SwiftMusicDLModels

final class SearchResultExplicitTests: XCTestCase {

    func testExplicitStatusMapping() {
        XCTAssertEqual(ExplicitStatus(isExplicit: true), .explicit)
        XCTAssertEqual(ExplicitStatus(isExplicit: false), .clean)
        XCTAssertEqual(ExplicitStatus(isExplicit: nil), .unknown)
    }

    func testLabels() {
        XCTAssertEqual(ExplicitStatus.explicit.label, "Explicit")
        XCTAssertEqual(ExplicitStatus.clean.label, "Clean")
        XCTAssertEqual(ExplicitStatus.unknown.label, "Unknown")
    }

    func testDecodesIsExplicitFromJSON() throws {
        let data = Data(#"{"track_url":"x","is_explicit":true}"#.utf8)
        let result = try JSONDecoder().decode(SearchResult.self, from: data)
        XCTAssertEqual(result.isExplicit, true)
        XCTAssertEqual(result.explicitStatus, .explicit)
    }

    func testAbsentIsExplicitDefaultsToUnknown() throws {
        let data = Data(#"{"track_url":"x"}"#.utf8)
        let result = try JSONDecoder().decode(SearchResult.self, from: data)
        XCTAssertNil(result.isExplicit)
        XCTAssertEqual(result.explicitStatus, .unknown)
    }

    func testExplicitRowsOrderAboveCleanRows() {
        let explicit = SearchResult.makeFixture(isExplicit: true, url: "explicit")
        let clean = SearchResult.makeFixture(isExplicit: false, url: "clean")
        let unknown = SearchResult.makeFixture(isExplicit: nil, url: "unknown")
        let results = [clean, unknown, explicit]
        let ordered = results.sorted { lhs, rhs in
            lhs.explicitStatus.rank < rhs.explicitStatus.rank
        }
        XCTAssertEqual(ordered.map { $0.explicitStatus }, [.explicit, .unknown, .clean])
    }
}

extension SearchResult {
    static func makeFixture(isExplicit: Bool?, url: String) -> SearchResult {
        SearchResult(
            type: "track",
            title: "t",
            artist: "a",
            album: nil,
            subtitle: "",
            artworkURL: nil,
            trackURL: url,
            source: "spotify",
            isExplicit: isExplicit
        )
    }
}

extension ExplicitStatus {
    /// 0 = explicit, 1 = unknown, 2 = clean (mirrors the backend ordering contract).
    var rank: Int {
        switch self {
        case .explicit: return 0
        case .unknown: return 1
        case .clean: return 2
        }
    }
}