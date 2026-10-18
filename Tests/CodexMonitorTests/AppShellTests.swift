import AppKit
import XCTest
@testable import CodexMonitor

final class AppShellTests: XCTestCase {
    @MainActor
    func testPanelStartsClosedAndCanBeToggledRepeatedly() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.finishLaunching()
        let panel = MenuBarPanel()
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        XCTAssertFalse(panel.isShown)
        panel.toggle()
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        XCTAssertTrue(panel.isShown)
        panel.toggle()
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        XCTAssertFalse(panel.isShown)
        panel.toggle()
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        XCTAssertTrue(panel.isShown)
        panel.toggle()
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        XCTAssertFalse(panel.isShown)
    }
}
