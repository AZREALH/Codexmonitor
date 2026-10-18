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
        // 让系统完成菜单栏布局，再检查真实面板的展开和收起。
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        XCTAssertFalse(panel.isShown)
        panel.statusItem.button?.performClick(nil)
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        XCTAssertTrue(panel.isShown)
        // 重现图标点击先经过外部监听、再触发按钮 action 的顺序。
        let button = try! XCTUnwrap(panel.statusItem.button)
        let window = try! XCTUnwrap(button.window)
        let icon = window.convertToScreen(button.convert(button.bounds, to: nil))
        panel.handleMouseDown(at: NSPoint(x: icon.midX, y: icon.midY), in: nil)
        XCTAssertTrue(panel.isShown)
        button.performClick(nil)
        XCTAssertFalse(panel.isShown)
        button.performClick(nil)
        XCTAssertTrue(panel.isShown)
        // 真正的外部坐标仍需关闭，不能为修复图标而取消外部收起。
        panel.handleMouseDown(at: NSPoint(x: icon.minX - 50, y: icon.minY - 50), in: nil)
        XCTAssertFalse(panel.isShown)
        button.performClick(nil)
        XCTAssertTrue(panel.isShown)
        // 模拟外部关闭路径；清理后还应能重新打开和通过图标收起。
        panel.close()
        panel.close()
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        XCTAssertFalse(panel.isShown)
        panel.statusItem.button?.performClick(nil)
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        XCTAssertTrue(panel.isShown)
        panel.statusItem.button?.performClick(nil)
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        XCTAssertFalse(panel.isShown)
    }
}
