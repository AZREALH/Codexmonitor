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
    private(set) var isRefreshing = false
    @ObservationIgnored private(set) var refreshTask: Task<Void, Never>?
    private let read: @Sendable () async throws -> QuotaSnapshot
    private let now: () -> Date
    private var lastSuccessfulRead: Date?

    init(read: @escaping @Sendable () async throws -> QuotaSnapshot,
         now: @escaping () -> Date = Date.init) {
        self.read = read
        self.now = now
    }

    var canRefresh: Bool {
        guard !isStopped, !isRefreshing else { return false }
        if case .loading = state { return false }
        if case .failed(let error) = state, let retryAt = error.retryAt {
            return now() >= retryAt
        }
        return true
    }

    func refresh() {
        beginRefresh(keepingSnapshot: false)
    }

    func refreshOnOpen() {
        // 只在实际展开时检查，不使用定时器；成功读取后 60 秒内复用数据。
        if let date = lastSuccessfulRead, now().timeIntervalSince(date) <= 60 { return }
        beginRefresh(keepingSnapshot: true)
    }

    private func beginRefresh(keepingSnapshot: Bool) {
        // 手动和展开刷新共享入口，读取中、退出后及限流等待期均拒绝请求。
        guard refreshTask == nil, canRefresh else { return }
        isRefreshing = true
        if !keepingSnapshot || !hasSnapshot { state = .loading }
        refreshTask = Task {
            defer { refreshTask = nil; isRefreshing = false }
            do {
                let snapshot = try await read()
                if !isStopped {
                    state = .loaded(snapshot)
                    lastSuccessfulRead = now()
                }
            } catch let error as ReadError {
                if !isStopped { state = .failed(error) }
            } catch {
                if !isStopped { state = .failed(.serviceUnavailable) }
            }
        }
    }

    private var hasSnapshot: Bool {
        if case .loaded = state { return true }
        return false
    }

    func stop() async {
        // 先拒绝新刷新和迟到结果，再取消并等待读取器完成进程清理。
        isStopped = true
        let task = refreshTask
        task?.cancel()
        await task?.value
    }
}
