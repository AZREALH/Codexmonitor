import Darwin
import Foundation

// 独立 actor 负责进程通信，界面主线程不用同步等待管道。
actor CodexSession {
    enum SessionError: Error, Equatable {
        case launchFailed, disconnected, invalidMessage
        case server(code: Int)
    }

    private let process = Process()
    private let input = Pipe()
    private let output = Pipe()
    private var framer = RPCFramer()
    private var nextID = 0
    private var pending: [Int: CheckedContinuation<Data, Error>] = [:]
    private var reader: Task<Void, Never>?

    func start(executable: URL, arguments: [String]) throws {
        guard reader == nil else { throw SessionError.launchFailed }
        process.executableURL = executable
        process.arguments = arguments
        process.standardInput = input
        process.standardOutput = output
        // stderr 单独丢弃，不混入 JSON，也不会因无人读取而塞满管道。
        process.standardError = FileHandle.nullDevice
        // 对端提前退出时让写入抛错，不让 SIGPIPE 终止整个应用。
        guard fcntl(input.fileHandleForWriting.fileDescriptor, F_SETNOSIGPIPE, 1) != -1
        else { throw SessionError.launchFailed }
        do { try process.run() } catch { throw SessionError.launchFailed }
        let handle = output.fileHandleForReading
        reader = Task.detached { [weak self] in
            while true {
                let chunk = handle.availableData
                if chunk.isEmpty { break }
                // 读取已有数据后立即交给分帧器，不等凑满固定长度才处理。
                await self?.receive(chunk)
            }
            await self?.reachedEOF()
        }
    }

    func request(_ method: String, params: Data = Data("{}".utf8)) async throws -> Data {
        guard process.isRunning else { throw SessionError.disconnected }
        let parameters = try JSONSerialization.jsonObject(with: params)
        nextID += 1
        let id = nextID
        return try await withCheckedThrowingContinuation { continuation in
            // 先登记等待者，再发送，避免很快的响应找不到请求。
            pending[id] = continuation
            do { try send(["id": id, "method": method, "params": parameters]) }
            catch { pending.removeValue(forKey: id)?.resume(throwing: error) }
        }
    }

    private func send(_ message: [String: Any]) throws {
        var data = try JSONSerialization.data(withJSONObject: message)
        data.append(0x0A)
        try input.fileHandleForWriting.write(contentsOf: data)
    }

    private func receive(_ chunk: Data) {
        do {
            for frame in try framer.append(chunk) {
                guard let message = try JSONSerialization.jsonObject(with: frame) as? [String: Any]
                else { throw SessionError.invalidMessage }
                if message["method"] != nil {
                    if let id = message["id"] {
                        // 只读客户端不执行服务端工具或授权请求。
                        try send(["id": id, "error": ["code": -32601, "message": "Unsupported request"]])
                    }
                    continue // 没有 id 的是通知，当前无需处理。
                }
                guard let id = message["id"] as? Int, let waiter = pending[id] else { continue }
                if let error = message["error"] as? [String: Any] {
                    pending.removeValue(forKey: id)
                    waiter.resume(throwing: SessionError.server(code: error["code"] as? Int ?? -32603))
                } else if let result = message["result"] {
                    let data = try JSONSerialization.data(withJSONObject: result, options: .fragmentsAllowed)
                    pending.removeValue(forKey: id)
                    waiter.resume(returning: data)
                } else { throw SessionError.invalidMessage }
            }
        } catch { fail(error) }
    }

    private func reachedEOF() {
        do { try framer.finish(); fail(SessionError.disconnected) }
        catch { fail(error) }
    }

    private func fail(_ error: Error) {
        let waiters = pending.values
        pending.removeAll()
        for waiter in waiters { waiter.resume(throwing: error) }
    }

    // 当前提供局部测试所需的基本关闭；有界取消和强制回收由 Task3.4 补齐。
    func close() {
        try? input.fileHandleForWriting.close()
        if process.isRunning { process.terminate(); process.waitUntilExit() }
        reader?.cancel()
        fail(SessionError.disconnected)
    }
}
