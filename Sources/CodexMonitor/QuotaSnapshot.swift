import Foundation

// 一行额度信息；id 由读取层根据额度桶和主／次窗口生成，保持列表稳定。
struct QuotaItem: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let usedPercent: Double?
    let windowDurationMins: Int?
    let resetsAt: Date?

    init(id: String, name: String, usedPercent: Double? = nil,
         windowDurationMins: Int? = nil, resetsAt: Date? = nil) {
        self.id = id
        self.name = name
        // nil 表示未知，不能当成已使用 0%；非法比例也保留为未知。
        self.usedPercent = usedPercent.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
        self.windowDurationMins = windowDurationMins.flatMap { $0 > 0 ? $0 : nil }
        self.resetsAt = resetsAt
    }

    var remainingPercent: Double? {
        // 超额时仍保留真实已用值，但剩余比例最低为 0%。
        usedPercent.map { max(0, 100 - $0) }
    }
}

// 只保存本次成功读取的数据和时刻，不负责网络请求或磁盘缓存。
struct QuotaSnapshot: Equatable, Sendable {
    let items: [QuotaItem]
    let queriedAt: Date
}

// 固定错误文案不回显底层响应，避免把认证信息带到界面上。
enum ReadError: Error, LocalizedError, Equatable, Sendable {
    case executableNotFound
    case authenticationRequired
    case incompatibleProtocol
    case serviceUnavailable
    case rateLimited(retryAt: Date?)
    case timeout

    var retryAt: Date? {
        if case let .rateLimited(retryAt) = self { return retryAt }
        return nil
    }

    var errorDescription: String? {
        switch self {
        case .executableNotFound: "未找到 Codex，请检查本机安装路径。"
        case .authenticationRequired: "请先在 Codex 中完成有效的订阅登录。"
        case .incompatibleProtocol: "当前 Codex 返回格式不兼容，请检查版本。"
        case .serviceUnavailable: "暂时无法读取额度，请检查网络后重试。"
        case .rateLimited: "查询受到限流，请稍后重试。"
        case .timeout: "读取额度超时，请稍后重试。"
        }
    }
}
