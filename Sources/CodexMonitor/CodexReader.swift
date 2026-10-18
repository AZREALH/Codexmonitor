import Foundation

// 一次调用一个会话；不缓存、不重试，成功或失败都确认清理后才返回。
struct CodexReader: Sendable {
    let executable: URL
    var arguments = ["app-server", "--listen", "stdio://"]
    var timeout: Duration = .seconds(20)
    var makeSession: @Sendable () -> CodexSession = { CodexSession() }

    func readSnapshot() async throws -> QuotaSnapshot {
        let session = makeSession()
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        let outcome: Result<QuotaSnapshot, Error>
        do {
            let value = try await withThrowingTaskGroup(of: QuotaSnapshot.self) { group in
                group.addTask { try await read(using: session) }
                group.addTask {
                    try await clock.sleep(until: deadline)
                    throw ReadError.timeout
                }
                defer { group.cancelAll() }
                guard let first = try await group.next() else { throw ReadError.serviceUnavailable }
                return first
            }
            outcome = .success(value)
        } catch { outcome = .failure(error) }
        // 截止时间限制查询本身；终止后的有界清理可能额外花费少量时间。
        guard await session.close() else { throw ReadError.cleanupFailed }
        try Task.checkCancellation()
        do { return try outcome.get() }
        catch let error as ReadError { throw error }
        catch is CancellationError { throw CancellationError() }
        catch let error as CodexSession.SessionError {
            switch error {
            case .service(let productError): throw productError
            case .invalidMessage, .server(code: -32601): throw ReadError.incompatibleProtocol
            default: throw ReadError.serviceUnavailable
            }
        } catch is RPCFramer.FramingError { throw ReadError.incompatibleProtocol }
        catch { throw ReadError.serviceUnavailable }
    }

    private func read(using session: CodexSession) async throws -> QuotaSnapshot {
        try Task.checkCancellation()
        guard FileManager.default.isExecutableFile(atPath: executable.path)
        else { throw ReadError.executableNotFound }
        try await session.start(executable: executable, arguments: arguments)
        _ = try await session.request("initialize", params: Data(#"{"clientInfo":{"name":"codex_monitor","title":"Codex Monitor","version":"0.1.0"}}"#.utf8))
        try await session.notify("initialized")
        let identity = try await session.request("account/read", params: Data(#"{"refreshToken":false}"#.utf8))
        guard let root = (try? JSONSerialization.jsonObject(with: identity)) as? [String: Any],
              root.keys.contains("account") else { throw ReadError.incompatibleProtocol }
        guard let account = root["account"] as? [String: Any], account["type"] as? String == "chatgpt"
        else { throw ReadError.authenticationRequired }
        let limits = try await session.request("account/rateLimits/read")
        return try QuotaDecoder().decode(limits, queriedAt: Date())
    }
}
