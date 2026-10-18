import Foundation
import XCTest
@testable import CodexMonitor

final class QuotaDecoderTests: XCTestCase {
    private let decoder = QuotaDecoder()
    private let queried = Date(timeIntervalSince1970: 1_700_000_000)
    private func decode(_ text: String) throws -> QuotaSnapshot {
        try decoder.decode(Data(text.utf8), queriedAt: queried)
    }

    func testTask31ConstructedFixtureMatchesSessionResultContract() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("docs/fixtures/rate-limits.example.json"))
        let response = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let result = try XCTUnwrap(response["result"])
        let snapshot = try decoder.decode(JSONSerialization.data(withJSONObject: result), queriedAt: queried)
        XCTAssertEqual(snapshot.items.map(\.id), ["example/primary", "example/secondary"])
        XCTAssertEqual(snapshot.items.map(\.remainingPercent), [75, 20])
    }

    func testSingleBucketPreservesValuesAndMissingFields() throws {
        let snapshot = try decode(#"{"rateLimits":{"limitId":"bucket","limitName":"额度","primary":{"usedPercent":25,"windowDurationMins":300,"resetsAt":1800000000},"secondary":{}}}"#)
        XCTAssertEqual(snapshot.items.map(\.id), ["bucket/primary", "bucket/secondary"])
        XCTAssertEqual(snapshot.items[0].name, "额度 · 主窗口")
        XCTAssertEqual(snapshot.items[0].remainingPercent, 75)
        XCTAssertEqual(snapshot.items[0].windowDurationMins, 300)
        XCTAssertEqual(snapshot.items[0].resetsAt, Date(timeIntervalSince1970: 1_800_000_000))
        XCTAssertNil(snapshot.items[1].usedPercent)
        XCTAssertNil(snapshot.items[1].resetsAt)
        XCTAssertEqual(snapshot.queriedAt, queried)
    }

    func testMultiBucketWinsAndHasStableOrderWithoutDuplicatingSingleView() throws {
        let snapshot = try decode(#"{"rateLimits":{"primary":{}},"rateLimitsByLimitId":{"z":{"primary":{}},"a":{"primary":{},"secondary":{}}},"unknown":{"ignored":true}}"#)
        XCTAssertEqual(snapshot.items.map(\.id), ["a/primary", "a/secondary", "z/primary"])
        XCTAssertEqual(snapshot.items[0].name, "a · 主窗口")
        XCTAssertEqual(snapshot.items[1].name, "a · 次窗口")
    }

    func testNullMultiViewFallsBackToSingleAndMissingNameUsesNeutralLabel() throws {
        let snapshot = try decode(#"{"rateLimitsByLimitId":null,"rateLimits":{"limitName":" ","primary":{}}}"#)
        XCTAssertEqual(snapshot.items.first?.id, "single/primary")
        XCTAssertEqual(snapshot.items.first?.name, "single · 主窗口")
    }

    func testEmptyAndNullQuotaViewsAreValidEmptyResults() throws {
        for json in [#"{"rateLimits":null}"#, #"{"rateLimitsByLimitId":{}}"#,
                     #"{"rateLimits":{"primary":null,"secondary":null}}"#,
                     #"{"rateLimitsByLimitId":{},"rateLimits":{"primary":{}}}"#] {
            XCTAssertTrue(try decode(json).items.isEmpty)
        }
    }

    func testMalformedRequiredStructureFailsInsteadOfReturningEmptySuccess() {
        for json in ["oops", "[]", "{}", #"{"rateLimits":[]}"#,
                     #"{"rateLimitsByLimitId":[]}"#, #"{"rateLimitsByLimitId":{"a":null}}"#,
                     #"{"rateLimits":{"primary":42}}"#] {
            XCTAssertThrowsError(try decode(json)) {
                XCTAssertEqual($0 as? ReadError, .incompatibleProtocol)
            }
        }
    }

    func testInvalidOptionalValuesStayUnknownInsteadOfBecomingZeroOrOne() throws {
        let item = try XCTUnwrap(decode(#"{"rateLimits":{"primary":{"usedPercent":true,"windowDurationMins":1.5,"resetsAt":"tomorrow"}}}"#).items.first)
        XCTAssertNil(item.usedPercent)
        XCTAssertNil(item.remainingPercent)
        XCTAssertNil(item.windowDurationMins)
        XCTAssertNil(item.resetsAt)
        let over = try XCTUnwrap(decode(#"{"rateLimits":{"primary":{"usedPercent":120}}}"#).items.first)
        XCTAssertEqual(over.remainingPercent, 0)
    }
}
