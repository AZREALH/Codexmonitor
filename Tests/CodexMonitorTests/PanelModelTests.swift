import Foundation
import XCTest
@testable import CodexMonitor

// 测试自行决定读取何时完成，不依赖真实网络或等待固定时长。
private actor ControlledRead {
    private var pending: CheckedContinuation<QuotaSnapshot, Error>?
    private var started: CheckedContinuation<Void, Never>?
    private(set) var calls = 0

    func read() async throws -> QuotaSnapshot {
        calls += 1
        return try await withCheckedThrowingContinuation {
            pending = $0
            started?.resume()
            started = nil
        }
    }
    func waitUntilStarted() async {
        if pending != nil { return }
        await withCheckedContinuation { started = $0 }
    }
    func finish(_ result: Result<QuotaSnapshot, Error>) {
        let waiter = pending
        pending = nil
        waiter?.resume(with: result)
    }
}

final class PanelModelTests: XCTestCase {
    private let snapshot = QuotaSnapshot(items: [QuotaItem(id: "sample", name: "示例", usedPercent: 25)],
                                         queriedAt: Date(timeIntervalSince1970: 1_800_000_000))

    @MainActor
    func testLoadingPreventsDuplicateReadsAndPublishesSuccess() async {
        let source = ControlledRead()
        let model = PanelModel(read: { try await source.read() })
        XCTAssertEqual(model.state, .idle)
        XCTAssertTrue(model.canRefresh)
        model.refresh()
        let task = model.refreshTask
        XCTAssertEqual(model.state, .loading)
        XCTAssertFalse(model.canRefresh)
        model.refresh()
        await source.waitUntilStarted()
        let calls = await source.calls
        XCTAssertEqual(calls, 1)
        await source.finish(.success(snapshot))
        await task?.value
        XCTAssertEqual(model.state, .loaded(snapshot))
        XCTAssertTrue(model.canRefresh)
    }

    @MainActor
    func testNewRefreshClearsOldSnapshotAndFailureKeepsItsCategory() async {
        let source = ControlledRead()
        let model = PanelModel(read: { try await source.read() })
        model.refresh()
        let first = model.refreshTask
        await source.waitUntilStarted()
        await source.finish(.success(snapshot))
        await first?.value
        model.refresh()
        let second = model.refreshTask
        XCTAssertEqual(model.state, .loading)
        await source.waitUntilStarted()
        await source.finish(.failure(ReadError.timeout))
        await second?.value
        XCTAssertEqual(model.state, .failed(.timeout))
        XCTAssertTrue(model.canRefresh)
    }

    @MainActor
    func testRateLimitBoundaryUsesInjectedClockAndNeverAutoRefreshes() async {
        let source = ControlledRead()
        var now = snapshot.queriedAt
        let retryAt = now.addingTimeInterval(60)
        let model = PanelModel(read: { try await source.read() }, now: { now })
        model.refresh()
        let first = model.refreshTask
        await source.waitUntilStarted()
        await source.finish(.failure(ReadError.rateLimited(retryAt: retryAt)))
        await first?.value
        now = retryAt.addingTimeInterval(-1)
        XCTAssertFalse(model.canRefresh)
        model.refresh()
        let blockedCalls = await source.calls
        XCTAssertEqual(blockedCalls, 1)
        now = retryAt
        XCTAssertTrue(model.canRefresh)
        let beforeClick = await source.calls
        XCTAssertEqual(beforeClick, 1)
        model.refresh()
        let second = model.refreshTask
        await source.waitUntilStarted()
        let calls = await source.calls
        XCTAssertEqual(calls, 2)
        await source.finish(.success(snapshot))
        await second?.value
        XCTAssertEqual(model.state, .loaded(snapshot))
    }

    @MainActor
    func testUnexpectedErrorsUseFixedPublicCategory() async {
        struct PrivateError: Error {}
        let model = PanelModel(read: { throw PrivateError() })
        model.refresh()
        await model.refreshTask?.value
        XCTAssertEqual(model.state, .failed(.serviceUnavailable))
    }
}
