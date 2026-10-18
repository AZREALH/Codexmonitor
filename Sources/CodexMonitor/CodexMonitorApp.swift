import AppKit   // 管理 macOS 应用、菜单和窗口。
import SwiftUI  // 描述窗口里的文字、布局等内容。

// @main 指定程序入口：启动时执行下面的 main()。
@main
enum CodexMonitorApp {
    // 界面相关操作放在主线程上执行。
    @MainActor
    static func main() {
        // shared 是当前应用共用的管理对象，不是新建一个应用。
        let application = NSApplication.shared
        let delegate = AppDelegate()
        // 把启动完成等生命周期事件交给我们定义的 AppDelegate 处理。
        application.delegate = delegate
        // 以普通 Mac 应用的方式运行，可拥有 Dock 图标和应用菜单。
        application.setActivationPolicy(.regular)
        // run() 开始处理鼠标、键盘等事件，直到应用退出。
        // 同时保持 delegate 存活，避免它在应用运行期间被提前释放。
        withExtendedLifetime(delegate) { application.run() }
    }
}

@MainActor
// NSApplicationDelegate 约定了一组系统可以调用的应用事件方法。
final class AppDelegate: NSObject, NSApplicationDelegate {
    // 保存窗口，便于下次重复使用；? 表示它可以暂时不存在（nil）。
    // private(set) 表示外部可以读取，但只能在这个类里面修改。
    private(set) var window: NSWindow?

    // 系统完成应用启动准备后自动调用这里；一次启动通常执行一次。
    // 当前顺序：建立退出菜单 → 显示窗口 → 按需执行开发检查。
    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        let applicationItem = NSMenuItem()
        let applicationMenu = NSMenu()
        // #selector 指定菜单点击后调用的方法；Command-Q 使用同一退出操作。
        applicationMenu.addItem(withTitle: "退出 Codex Monitor",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q")
        applicationItem.submenu = applicationMenu
        menu.addItem(applicationItem)
        // NSApp 是访问当前 NSApplication 的简写。
        NSApp.mainMenu = menu
        showWindow()
        // 只有启动时传入 --smoke-test 才执行：检查单窗口后自动退出。
        // 正常查看应用时不传这个参数。
        if CommandLine.arguments.contains("--smoke-test") {
            // 把检查放到主线程下一轮执行，给窗口完成显示的机会。
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

    // 这是我们自己定义的方法，不是系统回调：需要显示窗口时调用它。
    func showWindow() {
        // 只在还没有窗口时创建，重复调用不会多开一个窗口。
        if window == nil {
            let created = NSWindow(
                // 窗口内容区域宽 360、高 220；单位是界面点，不一定等于像素。
                contentRect: NSRect(x: 0, y: 0, width: 360, height: 220),
                // 普通窗口：有标题栏、关闭按钮和最小化按钮。
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered, defer: false)
            created.title = "Codex Monitor — 开发占位"
            created.isReleasedWhenClosed = false
            // PlaceholderView 定义内容，NSHostingView 把 SwiftUI 内容装进 AppKit 窗口。
            created.contentView = NSHostingView(rootView: PlaceholderView())
            created.center()
            window = created
        }
        // 如果窗口存在，就显示到前面并让它接收键盘操作。
        // 这是普通应用壳的行为；后续桌面面板任务会调整窗口层级和焦点行为。
        window?.makeKeyAndOrderFront(nil)
    }

    // 最后一个窗口关闭时，系统会询问是否退出；返回 true 表示退出。
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
