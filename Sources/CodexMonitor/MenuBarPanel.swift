import AppKit
import SwiftUI

// 管理菜单栏图标和点击后展开的内容，不创建桌面窗口。
@MainActor
final class MenuBarPanel: NSObject {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    var isShown: Bool { popover.isShown }

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        popover.contentSize = NSSize(width: 360, height: 240)
        popover.animates = false
        popover.behavior = .transient // 点击面板外部时自动收起，应用继续运行。
        popover.contentViewController = NSHostingController(rootView: PlaceholderView())
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "gauge.with.dots.needle.50percent",
                                accessibilityDescription: "Codex Monitor")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "Codex Monitor"
            button.setAccessibilityLabel("Codex Monitor")
            button.target = self
            button.action = #selector(toggle)
        }
    }

    @objc func toggle() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
