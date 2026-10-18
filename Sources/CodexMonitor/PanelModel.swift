import Foundation
import Observation

enum PanelState: Equatable {
    case idle
    case loading
    case loaded(QuotaSnapshot)
    case failed(ReadError)
}

// 界面只观察 state；实际读取由传入的异步闭包负责。
@MainActor
@Observable
final class PanelModel {
    private(set) var state: PanelState = .idle
    private(set) var isStopped = false
    @ObservationIgnored private(set) var refreshTask: Task<Void, Never>?
    private let read: @Sendable () async throws -> QuotaSnapshot
    private let now: () -> Date

    init(read: @escaping @Sendable () async throws -> QuotaSnapshot,
         now: @escaping () -> Date = Date.init) {
        self.read = read
        self.now = now
    }

    var canRefresh: Bool {
        guard !isStopped else { return false }
        if case .loading = state { return false }
        if case .failed(let error) = state, let retryAt = error.retryAt {
            return now() >= retryAt
        }
        return true
    }

    func refresh() {
        // 按钮禁用之外，入口也防重复；限流到期只允许手动操作，不自动查询。
        guard refreshTask == nil, canRefresh else { return }
        state = .loading // 状态里不再携带旧快照，失败也不会显示旧额度。
        refreshTask = Task {
            defer { refreshTask = nil }
            do {
                let snapshot = try await read()
                if !isStopped { state = .loaded(snapshot) }
            } catch let error as ReadError {
                if !isStopped { state = .failed(error) }
            } catch {
                if !isStopped { state = .failed(.serviceUnavailable) }
            }
        }
    }

    func stop() async {
        // 先拒绝新刷新和迟到结果，再取消并等待读取器完成进程清理。
        isStopped = true
        let task = refreshTask
        task?.cancel()
        await task?.value
    }
}
