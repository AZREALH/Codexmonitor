import SwiftUI

// 只展示传入的数据；读取和退出行为由外部通过回调提供。
struct PanelView: View {
    let snapshot: QuotaSnapshot
    let isExample: Bool
    let onRefresh: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Codex Monitor").font(.headline)
                Spacer()
                if isExample {
                    Text("示例数据")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                }
            }
            // 固定列表区域，额度较多时滚动，不把整个面板撑出屏幕。
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if snapshot.items.isEmpty {
                        Text("暂无额度数据")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 100)
                    }
                    ForEach(snapshot.items) { item in
                        quotaRow(item)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text("查询时间：\(snapshot.queriedAt.formatted(date: .numeric, time: .standard))")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button("刷新", action: onRefresh)
                Spacer()
                Button("退出", action: onQuit)
            }
            .buttonStyle(.bordered)
        }
        .padding(20)
    }

    private func quotaRow(_ item: QuotaItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.name).font(.subheadline.bold()).fixedSize(horizontal: false, vertical: true)
            if let remaining = item.remainingPercent {
                Text("剩余 \(remaining.formatted(.number.precision(.fractionLength(0...1))))%")
                    .monospacedDigit()
                ProgressView(value: remaining, total: 100)
                    .accessibilityLabel("剩余额度")
                    .accessibilityValue("\(remaining)%")
            } else {
                // 未知比例不画进度条，避免被误解为 0% 或仍在加载。
                Text("剩余：暂无数据").foregroundStyle(.secondary)
            }
            if let minutes = item.windowDurationMins {
                Text("额度周期：\(minutes) 分钟").font(.caption)
            }
            Text(item.resetsAt.map {
                "重置时间：\($0.formatted(date: .numeric, time: .shortened))"
            } ?? "重置时间：暂无数据")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
