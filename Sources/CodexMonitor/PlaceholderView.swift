import SwiftUI

struct PlaceholderView: View {
    var body: some View {
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
