import SwiftUI

// 只描述窗口内部的内容，不创建窗口，也不读取 Codex 额度。
// View 是 SwiftUI 的界面约定；struct 定义一个叫 PlaceholderView 的类型。
struct PlaceholderView: View {
    // body 是 SwiftUI 读取的界面描述；some View 表示返回某种视图。
    var body: some View {
        // VStack 从上到下排列子视图，间距为 14 个界面点。
        VStack(spacing: 14) {
            Text("Codex Monitor")
                // 点号开头的方法用于调整上面这个视图的样式。
                .font(.title2.bold())
            Text("开发占位")
                .font(.headline)
            Text("应用壳已启动，尚未连接 Codex。")
                // 使用系统的次要文字颜色，让说明与标题有层次。
                .foregroundStyle(.secondary)
        }
        // 以下修饰作用于整个 VStack：四周留白，并填满窗口可用区域。
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
