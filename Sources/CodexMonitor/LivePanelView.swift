import SwiftUI

// 界面随 model.state 切换；展开面板或视图重建都不发起查询。
struct LivePanelView: View {
    let model: PanelModel
    let onQuit: () -> Void

    var body: some View {
        // 仅在限流到期时更新按钮可用性，不是自动查询或定时刷新。
        TimelineView(.explicit(updateDates)) { _ in
            Group {
                if case .loaded(let snapshot) = model.state {
                    PanelView(snapshot: snapshot, isExample: false,
                              onRefresh: model.refresh, onQuit: onQuit)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Codex Monitor").font(.headline)
                        Spacer()
                        if case .loading = model.state {
                            ProgressView("正在读取额度…")
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else if case .failed(let error) = model.state {
                            Text(error.localizedDescription).foregroundStyle(.secondary)
                            if let date = error.retryAt {
                                Text("可重试时间：\(date.formatted(date: .numeric, time: .standard))")
                                    .font(.caption)
                            }
                        } else {
                            Text("等待查询额度").foregroundStyle(.secondary)
                        }
                        Spacer()
                        HStack {
                            Button("刷新", action: model.refresh).disabled(!model.canRefresh)
                            Spacer()
                            Button("退出", action: onQuit)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(20)
                }
            }
            .frame(width: 380, height: 440)
        }
    }

    private var updateDates: [Date] {
        if case .failed(let error) = model.state, let date = error.retryAt {
            return [Date(), date].sorted()
        }
        return [Date()]
    }
}
