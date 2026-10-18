import SwiftUI

// 只定义窗口里的内容；窗口本身由 AppDelegate 创建。
struct PlaceholderView: View {
    var body: some View {
        // 内容从上到下排列。
        VStack(spacing: 14) {
            Text("Codex Monitor")
                .font(.title2.bold())
            Text("开发占位")
                .font(.headline)
            Text("应用壳已启动，尚未连接 Codex。")
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
