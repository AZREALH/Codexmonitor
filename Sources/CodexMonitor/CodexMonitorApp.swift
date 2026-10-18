import AppKit

// 程序入口：启动应用，并让 AppDelegate 接收系统事件。
@main
enum CodexMonitorApp {
    @MainActor
    static func main() {
        let instance: SingleInstance
        do {
            guard let acquired = try SingleInstance() else {
                print("Codex Monitor 已在运行，不重复启动。")
                return
            }
            instance = acquired
        } catch {
            print("无法检查应用运行状态，请检查临时目录权限。")
            return
        }
        let application = NSApplication.shared
        // 首版使用 Task3.1 验证的本机路径；扩展升级后可在此集中调整。
        let reader = CodexReader(executable: URL(fileURLWithPath:
            "/Users/shihanxi/.vscode-insiders/extensions/openai.chatgpt-26.1007.21434-darwin-arm64/bin/macos-aarch64/codex"))
        let model = PanelModel(read: {
            if CommandLine.arguments.contains("--smoke-test") {
                return QuotaSnapshot(items: [], queriedAt: Date())
            }
            return try await reader.readSnapshot()
        })
        let delegate = AppDelegate(model: model)
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        // 应用运行期间持续持锁，退出后才能启动下一份。
        withExtendedLifetime((delegate, instance)) { application.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var panel: MenuBarPanel?
    let model: PanelModel
    private var hasStarted = false
    private(set) var terminationTask: Task<Void, Never>?
    private var isReadyToTerminate = false
    private let replyToTermination: (Bool) -> Void

    init(model: PanelModel, replyToTermination: @escaping (Bool) -> Void = {
        if $0 { NSApp.terminate(nil) }
    }) {
        self.model = model
        self.replyToTermination = replyToTermination
        super.init()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if isReadyToTerminate { return .terminateNow }
        // 先取消本次退出，让主队列继续清理；完成后重新请求退出。
        // terminateLater 的嵌套事件循环可能阻塞 MainActor 任务。
        if terminationTask == nil {
            terminationTask = Task {
                await model.stop()
                panel?.shutdown()
                isReadyToTerminate = true
                replyToTermination(true)
            }
        }
        return .terminateCancel
    }

    func startOnce() {
        guard !hasStarted else { return }
        hasStarted = true
        model.refresh()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = MenuBarPanel(model: model)
        startOnce() // 只在应用启动时调用，不放在视图的 onAppear 中。
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
