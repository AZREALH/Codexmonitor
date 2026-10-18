import CoreFoundation
import Foundation

// 输入是通信层返回的 result，不是带 id 的完整响应；不请求网络或保存数据。
struct QuotaDecoder {
    func decode(_ data: Data, queriedAt: Date) throws -> QuotaSnapshot {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              root.keys.contains("rateLimitsByLimitId") || root.keys.contains("rateLimits")
        else { throw ReadError.incompatibleProtocol }
        let buckets: [String: Any]
        if let multiple = root["rateLimitsByLimitId"], !(multiple is NSNull) {
            guard let value = multiple as? [String: Any] else { throw ReadError.incompatibleProtocol }
            buckets = value // 空字典也是有效结果，不再叠加兼容单桶视图。
        } else if let single = root["rateLimits"], !(single is NSNull) {
            guard let value = single as? [String: Any] else { throw ReadError.incompatibleProtocol }
            buckets = [value["limitId"] as? String ?? "single": value]
        } else {
            buckets = [:]
        }
        var items: [QuotaItem] = []
        // 排序保持展示和列表 ID 稳定，不依赖 JSON 字典的遍历顺序。
        for key in buckets.keys.sorted() {
            guard let bucket = buckets[key] as? [String: Any] else { throw ReadError.incompatibleProtocol }
            let label = (bucket["limitName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            for (role, title) in [("primary", "主窗口"), ("secondary", "次窗口")] {
                guard let raw = bucket[role], !(raw is NSNull) else { continue }
                guard let window = raw as? [String: Any] else { throw ReadError.incompatibleProtocol }
                let minutes = number(window["windowDurationMins"]).flatMap { Int(exactly: $0) }
                items.append(QuotaItem(
                    id: "\(key)/\(role)", name: "\(label.flatMap { $0.isEmpty ? nil : $0 } ?? key) · \(title)",
                    usedPercent: number(window["usedPercent"]), windowDurationMins: minutes,
                    resetsAt: number(window["resetsAt"]).map { Date(timeIntervalSince1970: $0) }))
            }
        }
        return QuotaSnapshot(items: items, queriedAt: queriedAt)
    }

    private func number(_ value: Any?) -> Double? {
        // JSON 的 true 也能桥接为 NSNumber，要排除，不能把它当作 1%。
        guard let value = value as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID(),
              value.doubleValue.isFinite else { return nil }
        return value.doubleValue
    }
}
