import AppKit
import SwiftUI

// 管理菜单栏图标和点击后展开的内容，不创建桌面窗口。
@MainActor
final class MenuBarPanel: NSObject, NSPopoverDelegate {
    let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?
    var isShown: Bool { popover.isShown }

    init(model: PanelModel) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        popover.contentSize = NSSize(width: 380, height: 440)
        popover.animates = false
        popover.delegate = self
        // 统一由图标和点击监听关闭，避免系统先收起、图标回调又重新打开。
        popover.behavior = .applicationDefined
        popover.contentViewController = NSHostingController(
            rootView: LivePanelView(model: model, onQuit: { NSApp.terminate(nil) }))
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "gauge.with.dots.needle.50percent",
                                accessibilityDescription: "Codex Monitor")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "Codex Monitor"
            button.setAccessibilityLabel("Codex Monitor")
            button.target = self
            button.action = #selector(toggle)
            button.sendAction(on: .leftMouseDown)
        }
    }

    @objc func toggle() {
        if popover.isShown {
            close()
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            startClickMonitoring()
        }
    }

    func close() {
        popover.performClose(nil)
        stopClickMonitoring()
    }

    func popoverDidClose(_ notification: Notification) {
        // 系统自动收起也会走这里，确保不只在主动 close() 时清理。
        stopClickMonitoring()
    }

    func handleMouseDown(at screenPoint: NSPoint, in window: NSWindow?) {
        // 菜单栏事件的 window 不一定是按钮窗口，用屏幕坐标排除自身图标。
        // 否则监听先收起面板，紧接着图标回调又会把它打开。
        if let button = statusItem.button, let buttonWindow = button.window {
            let iconFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
            if iconFrame.contains(screenPoint) { return }
        }
        if let window, window === popover.contentViewController?.view.window { return }
        close()
    }

    private func startClickMonitoring() {
        // 每次展开重新安装，避免重复注册；只监听鼠标按下，不记录内容。
        stopClickMonitoring()
        let clicks: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        // 全局监听负责其他应用，包括其他菜单栏组件；不拦截原本的点击。
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: clicks) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleMouseDown(at: NSEvent.mouseLocation, in: nil)
            }
        }
        // 全局监听不接收本应用的事件，因此还需要本地监听。
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: clicks) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self else { return }
                let point = event.window?.convertPoint(toScreen: event.locationInWindow)
                    ?? NSEvent.mouseLocation
                self.handleMouseDown(at: point, in: event.window)
            }
            return event // 原样传回，继续把点击交给原目标处理。
        }
    }

    private func stopClickMonitoring() {
        // 面板收起后不再监听；置空引用也让重复清理保持安全。
        if let globalClickMonitor { NSEvent.removeMonitor(globalClickMonitor) }
        if let localClickMonitor { NSEvent.removeMonitor(localClickMonitor) }
        globalClickMonitor = nil
        localClickMonitor = nil
    }
}
