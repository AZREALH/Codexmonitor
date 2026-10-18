import AppKit
import SwiftUI

// 只定义展开面板里的内容；菜单栏和面板由 MenuBarPanel 管理。
struct PlaceholderView: View {
    @State private var interactionCount = 0

    var body: some View {
        // 内容从上到下排列。
        VStack(spacing: 14) {
            Text("Codex Monitor")
                .font(.title2.bold())
            Text("开发占位")
                .font(.headline)
            Text("应用壳已启动，尚未连接 Codex。")
                .foregroundStyle(.secondary)
            Text("交互检查：\(interactionCount) 次")
                .font(.caption)
            HStack {
                Button("检查交互") { interactionCount += 1 }
                Button("退出") { NSApp.terminate(nil) }
            }
            .buttonStyle(.bordered)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }
}
