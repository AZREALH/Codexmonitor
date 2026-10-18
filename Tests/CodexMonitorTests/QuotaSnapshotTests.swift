import Foundation
import XCTest
@testable import CodexMonitor

final class QuotaSnapshotTests: XCTestCase {
    func testRemainingPercentForValidAndOverLimitUsage() {
        let examples: [(Double, Double)] = [(25, 75), (0, 100), (100, 0), (120, 0)]
        for (used, expected) in examples {
            let item = QuotaItem(id: "codex/primary", name: "主窗口", usedPercent: used)
            XCTAssertEqual(item.usedPercent, used)
            XCTAssertEqual(item.remainingPercent, expected)
        }
    }

    func testMissingAndInvalidUsageStayUnknown() {
        // 覆盖缺失、负数、NaN 和无穷大，不能误报为满额或零额度。
        let examples: [Double?] = [nil, -1, .nan, .infinity, -.infinity]
        for used in examples {
            let item = QuotaItem(id: "codex/primary", name: "主窗口", usedPercent: used)
            XCTAssertNil(item.usedPercent)
            XCTAssertNil(item.remainingPercent)
        }
    }

    func testMetadataAndQueryTimeArePreserved() {
        let reset = Date(timeIntervalSince1970: 1_800_000_000)
        let queried = reset.addingTimeInterval(-60)
        let item = QuotaItem(id: "codex/secondary", name: "次窗口", usedPercent: 25,
                             windowDurationMins: 60, resetsAt: reset)
        let snapshot = QuotaSnapshot(items: [item], queriedAt: queried)
        XCTAssertEqual(snapshot.items.first?.id, "codex/secondary")
        XCTAssertEqual(snapshot.items.first?.name, "次窗口")
        XCTAssertEqual(snapshot.items.first?.windowDurationMins, 60)
        XCTAssertEqual(snapshot.items.first?.resetsAt, reset)
        XCTAssertEqual(snapshot.queriedAt, queried)
    }

    func testMissingResetAndInvalidDurationDoNotBecomeDefaults() {
        for duration: Int? in [nil, 0, -1] {
            let item = QuotaItem(id: "codex/primary", name: "主窗口",
                                 windowDurationMins: duration)
            XCTAssertNil(item.windowDurationMins)
            XCTAssertNil(item.resetsAt)
        }
        XCTAssertTrue(QuotaSnapshot(items: [], queriedAt: .distantPast).items.isEmpty)
    }

    func testOnlyRateLimitErrorCarriesRetryTime() {
        let retry = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertEqual(ReadError.rateLimited(retryAt: retry).retryAt, retry)
        XCTAssertNil(ReadError.rateLimited(retryAt: nil).retryAt)
        let others: [ReadError] = [.executableNotFound, .authenticationRequired,
                                  .incompatibleProtocol, .serviceUnavailable, .timeout]
        for error in others {
            XCTAssertNil(error.retryAt)
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
    }
}
