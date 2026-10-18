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
    @ObservationIgnored private(set) var refreshTask: Task<Void, Never>?
    private let read: @Sendable () async throws -> QuotaSnapshot
    private let now: () -> Date

    init(read: @escaping @Sendable () async throws -> QuotaSnapshot,
         now: @escaping () -> Date = Date.init) {
        self.read = read
        self.now = now
    }

    var canRefresh: Bool {
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
            do { state = .loaded(try await read()) }
            catch let error as ReadError { state = .failed(error) }
            catch { state = .failed(.serviceUnavailable) }
        }
    }
}
