import AppKit
import SwiftUI

// @main 指定程序入口：启动时执行下面的 main()。
@main
enum CodexMonitorApp {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        // 把启动完成等生命周期事件交给我们定义的 AppDelegate 处理。
        application.delegate = delegate
        application.setActivationPolicy(.regular)
        // 在处理应用事件期间保持 delegate 存活。
        withExtendedLifetime(delegate) { application.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var window: NSWindow?

    // 系统完成应用启动准备后自动调用这里；一次启动通常执行一次。
    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        let applicationItem = NSMenuItem()
        let applicationMenu = NSMenu()
        applicationMenu.addItem(withTitle: "退出 Codex Monitor",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q")
        applicationItem.submenu = applicationMenu
        menu.addItem(applicationItem)
        NSApp.mainMenu = menu
        showWindow()
        // 开发检查模式：验证只有一个窗口，然后自动退出。
        if CommandLine.arguments.contains("--smoke-test") {
            DispatchQueue.main.async { [self] in
                showWindow()
                guard let window, window.isVisible,
                      NSApp.windows.filter({ $0.isVisible }).count == 1 else {
                    fatalError("Expected exactly one visible window")
                }
                print("SMOKE PASS: one visible placeholder window; terminating normally")
                NSApp.terminate(nil)
            }
        }
    }

    func showWindow() {
        // 只在还没有窗口时创建，重复调用不会多开一个窗口。
        if window == nil {
            let created = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 360, height: 220),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered, defer: false)
            created.title = "Codex Monitor — 开发占位"
            created.isReleasedWhenClosed = false
            // PlaceholderView 定义内容，NSHostingView 把 SwiftUI 内容装进 AppKit 窗口。
            created.contentView = NSHostingView(rootView: PlaceholderView())
            created.center()
            window = created
        }
        window?.makeKeyAndOrderFront(nil)
    }

    // 最后一个窗口关闭时，系统会询问是否退出；返回 true 表示退出。
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
