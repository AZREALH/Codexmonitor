import AppKit
import XCTest
@testable import CodexMonitor

final class AppShellTests: XCTestCase {
    @MainActor
    func testShowingAgainReusesTheVisibleWindow() {
        _ = NSApplication.shared
        let delegate = AppDelegate()
        delegate.showWindow()
        guard let first = delegate.window else {
            XCTFail("Window was not created")
            return
        }
        defer { first.close() }
        delegate.showWindow()
        XCTAssertTrue(delegate.window === first)
        XCTAssertTrue(first.isVisible)
        XCTAssertTrue(first.title.contains("开发占位"))
        XCTAssertNotNil(first.contentView)
        XCTAssertTrue(delegate.applicationShouldTerminateAfterLastWindowClosed(NSApp))
    }
}
