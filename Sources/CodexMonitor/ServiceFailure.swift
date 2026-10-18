import Foundation

// 只提取明确的 HTTP 状态和 Retry-After 秒数，不把服务正文带到界面。
enum ServiceFailure {
    static func classify(_ error: [String: Any], now: Date = Date()) -> ReadError? {
        let text = error["message"] as? String ?? ""
        let status = error["code"] as? Int
        let http = capture(#"(?i)\b(?:HTTP(?:/\d(?:\.\d)?)?|status(?: code)?)\s*[:=]?\s*(401|403|429)\b"#, text)
            .flatMap(Int.init) ?? status
        if http == 401 || http == 403 { return .authenticationRequired }
        guard http == 429 else { return nil }
        let seconds = capture(#"(?i)\bRetry-After:\s*(\d+)\b"#, text).flatMap(Double.init)
        return .rateLimited(retryAt: seconds.map { now.addingTimeInterval($0) })
    }

    private static func capture(_ pattern: String, _ text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }
}
