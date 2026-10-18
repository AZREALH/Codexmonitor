import AppKit
import SwiftUI

// 临时演示容器：用于检查布局和回调，Task4 接入真实状态时替换。
struct ExamplePanelView: View {
    enum Scenario: String, CaseIterable {
        case normal = "正常"
        case missing = "缺失字段"
        case empty = "空列表"
        case long = "长列表"
    }

    @State private var scenario: Scenario = .normal
    @State private var queriedAt = Date()
    @State private var refreshCount = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("示例场景", selection: $scenario) {
                ForEach(Scenario.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top], 20)
            PanelView(snapshot: snapshot, isExample: true, onRefresh: {
                queriedAt = Date()
                refreshCount += 1
            }, onQuit: { NSApp.terminate(nil) })
            Text("尚未连接 Codex · 示例刷新 \(refreshCount) 次")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 14)
        }
        .frame(width: 380, height: 440)
    }

    private var snapshot: QuotaSnapshot {
        let items: [QuotaItem]
        switch scenario {
        case .normal:
            items = [
                QuotaItem(id: "example/primary", name: "示例主窗口", usedPercent: 25,
                          windowDurationMins: 300, resetsAt: queriedAt.addingTimeInterval(7200)),
                QuotaItem(id: "example/secondary", name: "示例次窗口", usedPercent: 80,
                          windowDurationMins: 10080, resetsAt: queriedAt.addingTimeInterval(86400))
            ]
        case .missing:
            items = [QuotaItem(id: "example/unknown", name: "字段缺失的示例额度")]
        case .empty:
            items = []
        case .long:
            items = (1...10).map {
                QuotaItem(id: "example/\($0)", name: "示例额度 \($0)：用于检查较长名称换行及列表滚动的展示效果",
                          usedPercent: Double($0 * 8))
            }
        }
        return QuotaSnapshot(items: items, queriedAt: queriedAt)
    }
}
