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
