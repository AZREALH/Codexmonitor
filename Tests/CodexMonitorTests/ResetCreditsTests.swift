import Foundation
import XCTest
@testable import CodexMonitor

final class ResetCreditsTests: XCTestCase {
    private func decode(_ field: String) throws -> ResetCredits? {
        let json = "{\"rateLimits\":null,\"rateLimitResetCredits\":\(field)}"
        return try QuotaDecoder().decode(Data(json.utf8), queriedAt: .distantPast).resetCredits
    }

    func testCountRemainsAuthoritativeWhenDetailsArePartial() throws {
        let result = try XCTUnwrap(decode(#"{"availableCount":3,"credits":[{"status":"available","title":"Weekly reset","description":"Use before expiry","expiresAt":1800000000}]}"#))
        XCTAssertEqual(result.availableCount, 3)
        let credit = try XCTUnwrap(result.credits?.first)
        XCTAssertEqual(result.credits?.count, 1)
        XCTAssertEqual(credit.title, "Weekly reset")
        XCTAssertEqual(credit.description, "Use before expiry")
        XCTAssertEqual(credit.expiresAt, Date(timeIntervalSince1970: 1_800_000_000))
        XCTAssertTrue(credit.expiryKnown)
    }

    func testNullAndMissingExpiryHaveDifferentMeaning() throws {
        let rows = try XCTUnwrap(decode(#"{"availableCount":2,"credits":[{"status":"available","expiresAt":null},{"status":"available"},{"status":"redeemed","expiresAt":null}]}"#)?.credits)
        XCTAssertEqual(rows.count, 2)
        XCTAssertTrue(rows[0].expiryKnown) // 只有服务明确返回 null 才表示不到期。
        XCTAssertFalse(rows[1].expiryKnown)
        XCTAssertNil(rows[0].expiresAt)
        XCTAssertNil(rows[1].expiresAt)
    }

    func testMissingInvalidAndZeroCountsAreNotConfused() throws {
        XCTAssertNil(try decode("null"))
        XCTAssertNil(try decode("[]"))
        for count in ["true", "-1", "1.5", "null", "\"3\""] {
            XCTAssertNil(try decode("{\"availableCount\":\(count),\"credits\":null}")?.availableCount)
        }
        let zero = try XCTUnwrap(decode(#"{"availableCount":0,"credits":[]}"#))
        XCTAssertEqual(zero.availableCount, 0)
        XCTAssertEqual(zero.credits?.count, 0)
        let countOnly = try XCTUnwrap(decode(#"{"availableCount":2,"credits":null}"#))
        XCTAssertEqual(countOnly.availableCount, 2)
        XCTAssertNil(countOnly.credits)
    }
}
