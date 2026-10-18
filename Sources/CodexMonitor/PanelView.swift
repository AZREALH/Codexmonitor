import SwiftUI

// 只展示传入的数据；读取和退出行为由外部通过回调提供。
struct PanelView: View {
    let snapshot: QuotaSnapshot
    let isExample: Bool
    let onRefresh: () -> Void
    let onQuit: () -> Void
    var isRefreshing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Codex Monitor").font(.headline)
                Spacer()
                if isRefreshing {
                    // 自动刷新保留旧内容和查询时间，用小标识说明正在更新。
                    ProgressView().controlSize(.small)
                    Text("正在更新…").font(.caption).foregroundStyle(.secondary)
                }
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
                    ResetCreditsView(credits: snapshot.resetCredits)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text("查询时间：\(snapshot.queriedAt.formatted(date: .numeric, time: .standard))")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button("刷新", action: onRefresh)
                    .disabled(isRefreshing)
                Spacer()
                Button("退出", action: onQuit)
            }
            .buttonStyle(.bordered)
        }
        .padding(20)
    }

    private func quotaRow(_ item: QuotaItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title(for: item)).font(.system(size: 18, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
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
            Text(item.resetsAt.map {
                "重置时间：\($0.formatted(date: .numeric, time: .shortened))"
            } ?? "重置时间：暂无数据")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func title(for item: QuotaItem) -> String {
        // 隐藏默认 codex 前缀，其他额度组的名称仍保留，便于区分。
        let prefix = "codex · "
        let name = item.name.lowercased().hasPrefix(prefix)
            ? String(item.name.dropFirst(prefix.count)) : item.name
        // 按服务实际返回的周期命名，不固定认为主窗口一定是五小时。
        let label: String
        switch item.windowDurationMins {
        case 300: label = "5h"
        case 10080: label = "Weekly"
        default: return name
        }
        for suffix in ["主窗口", "次窗口"] where name.hasSuffix(suffix) {
            return String(name.dropLast(suffix.count)) + label
        }
        return "\(name) · \(label)"
    }
}
