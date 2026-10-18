import CoreFoundation
import Foundation

// 总数以服务返回为准；明细可能被截断，不能用列表长度代替剩余卡数。
struct ResetCredits: Equatable, Sendable {
    struct Credit: Identifiable, Equatable, Sendable {
        let id: Int
        let title: String
        let description: String?
        let expiresAt: Date?
        let expiryKnown: Bool
    }
    let availableCount: Int?
    let credits: [Credit]?

    init?(json: Any?) {
        guard let value = json as? [String: Any] else { return nil }
        if let count = Self.number(value["availableCount"]), count >= 0 {
            availableCount = Int(exactly: count)
        } else { availableCount = nil }
        credits = (value["credits"] as? [Any])?.enumerated().compactMap { index, raw in
            guard let row = raw as? [String: Any], row["status"] as? String == "available"
            else { return nil }
            let expiry = Self.number(row["expiresAt"]).flatMap {
                $0 >= 0 ? Date(timeIntervalSince1970: $0) : nil
            }
            return Credit(id: index, title: Self.text(row["title"]) ?? "重置卡 \(index + 1)",
                          description: Self.text(row["description"]), expiresAt: expiry,
                          expiryKnown: row["expiresAt"] is NSNull || expiry != nil)
        }
    }

    private static func number(_ raw: Any?) -> Double? {
        guard let value = raw as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID(),
              value.doubleValue.isFinite else { return nil }
        return value.doubleValue
    }

    private static func text(_ raw: Any?) -> String? {
        guard let value = (raw as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }
        return value
    }
}
