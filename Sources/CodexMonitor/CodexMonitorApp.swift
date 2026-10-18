import AppKit
import SwiftUI

@main
enum CodexMonitorApp {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { application.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var window: NSWindow?

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
        if window == nil {
            let created = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 360, height: 220),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered, defer: false)
            created.title = "Codex Monitor — 开发占位"
            created.isReleasedWhenClosed = false
            created.contentView = NSHostingView(rootView: PlaceholderView())
            created.center()
            window = created
        }
        window?.makeKeyAndOrderFront(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
