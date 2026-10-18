import AppKit
import SwiftUI
import XCTest
@testable import CodexMonitor

private actor ReadCounter {
    private(set) var calls = 0
    func read() -> QuotaSnapshot {
        calls += 1
        return QuotaSnapshot(items: [], queriedAt: Date())
    }
}

final class PanelIntegrationTests: XCTestCase {
    @MainActor
    func testActualOpenRefreshesOnlyStaleData() async throws {
        let source = ReadCounter()
        var now = Date()
        let model = PanelModel(read: { await source.read() }, now: { now })
        model.refresh()
        await model.refreshTask?.value
        let panel = MenuBarPanel(model: model)
        panel.statusItem.isVisible = true
        defer { panel.shutdown() }
        // 等待测试宿主完成真实菜单栏布局，再走产品的展开入口。
        try await Task.sleep(for: .milliseconds(100))
        panel.toggle()
        XCTAssertTrue(panel.isShown)
        XCTAssertNil(model.refreshTask)
        panel.toggle()
        now = now.addingTimeInterval(61)
        XCTAssertNil(model.refreshTask) // 收起时经过一分钟也不会启动请求。
        panel.toggle()
        XCTAssertTrue(model.isRefreshing)
        await model.refreshTask?.value
        let calls = await source.calls
        XCTAssertEqual(calls, 2)
        panel.close()
        panel.toggle()
        XCTAssertNil(model.refreshTask)
    }

    @MainActor
    func testStartupIsOnceAndViewRebuildDoesNotQuery() async {
        let source = ReadCounter()
        let model = PanelModel(read: { await source.read() })
        let delegate = AppDelegate(model: model)
        delegate.startOnce()
        await model.refreshTask?.value
        delegate.startOnce()
        for _ in 0..<3 {
            let host = NSHostingView(rootView: LivePanelView(model: model, onQuit: {}))
            host.frame = NSRect(x: 0, y: 0, width: 380, height: 440)
            host.layoutSubtreeIfNeeded()
        }
        let startupCalls = await source.calls
        XCTAssertEqual(startupCalls, 1)
        model.refresh()
        await model.refreshTask?.value
        let manualCalls = await source.calls
        XCTAssertEqual(manualCalls, 2)
    }
}
