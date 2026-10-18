import AppKit
import Darwin
import XCTest
@testable import CodexMonitor

private actor LateRead {
    private var continuation: CheckedContinuation<QuotaSnapshot, Never>?
    private var started: CheckedContinuation<Void, Never>?
    func read() async -> QuotaSnapshot {
        await withCheckedContinuation {
            continuation = $0
            started?.resume()
            started = nil
        }
    }
    func waitUntilStarted() async {
        if continuation != nil { return }
        await withCheckedContinuation { started = $0 }
    }
    func complete() {
        continuation?.resume(returning: QuotaSnapshot(items: [], queriedAt: Date()))
        continuation = nil
    }
}

final class PanelExitTests: XCTestCase {
    @MainActor
    func testIdleAndErrorStopRejectFurtherRefresh() async {
        for failFirst in [false, true] {
            let model = PanelModel(read: { throw ReadError.timeout })
            if failFirst { model.refresh(); await model.refreshTask?.value }
            let state = model.state
            await model.stop()
            await model.stop()
            model.refresh()
            XCTAssertFalse(model.canRefresh)
            XCTAssertEqual(model.state, state)
            XCTAssertNil(model.refreshTask)
        }
    }

    @MainActor
    func testLateResultDoesNotChangeStoppedState() async {
        let source = LateRead()
        let model = PanelModel(read: { await source.read() })
        model.refresh()
        await source.waitUntilStarted()
        let stop = Task { await model.stop() }
        for _ in 0..<100 where !model.isStopped { await Task.yield() }
        XCTAssertTrue(model.isStopped)
        let state = model.state
        await source.complete() // 故意忽略取消并迟到返回，状态仍应冻结。
        await stop.value
        await model.stop()
        XCTAssertEqual(model.state, state)
        XCTAssertFalse(model.canRefresh)
    }

    @MainActor
    func testTerminationWaitsForChildAndOnlyRepliesOnce() async throws {
        let session = CodexSession()
        addTeardownBlock { await session.close() }
        let script = "import signal,sys,time; signal.alarm(5); signal.signal(signal.SIGTERM,signal.SIG_IGN); sys.stdin.readline(); time.sleep(10)"
        let reader = CodexReader(executable: URL(fileURLWithPath: "/usr/bin/python3"),
            arguments: ["-u", "-c", script], makeSession: { session })
        let model = PanelModel(read: { try await reader.readSnapshot() })
        var replies = 0
        let delegate = AppDelegate(model: model, replyToTermination: { accepted in
            XCTAssertTrue(accepted)
            replies += 1
        })
        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        for _ in 0..<100 {
            if await session.hasPendingRequests { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        let pending = await session.hasPendingRequests
        XCTAssertTrue(pending)
        let pid = await session.processID
        XCTAssertEqual(delegate.applicationShouldTerminate(NSApp), .terminateCancel)
        XCTAssertEqual(delegate.applicationShouldTerminate(NSApp), .terminateCancel)
        await delegate.terminationTask?.value
        XCTAssertEqual(replies, 1)
        XCTAssertEqual(delegate.applicationShouldTerminate(NSApp), .terminateNow)
        XCTAssertFalse(delegate.panel?.statusItem.isVisible ?? true)
        XCTAssertEqual(kill(pid, 0), -1)
        XCTAssertEqual(errno, ESRCH)
    }
}
