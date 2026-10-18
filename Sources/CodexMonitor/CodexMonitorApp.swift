import AppKit

// 程序入口：启动应用，并让 AppDelegate 接收系统事件。
@main
enum CodexMonitorApp {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { application.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var panel: MenuBarPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = MenuBarPanel()
        // 检查模式会打开、收起面板，然后正常退出；日常启动不执行。
        if CommandLine.arguments.contains("--smoke-test") {
            // 等待系统把菜单栏按钮放到屏幕上，再打开弹出面板。
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [self] in
                panel?.toggle()
                guard panel?.isShown == true else { fatalError("Popover did not open") }
                panel?.toggle()
                guard panel?.isShown == false else { fatalError("Popover did not close") }
                print("SMOKE PASS: menu bar popover opened and closed; terminating normally")
                NSApp.terminate(nil)
            }
        }
    }
}
