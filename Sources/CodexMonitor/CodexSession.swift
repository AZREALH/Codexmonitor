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
    private var closing = false
    private var cleanup: Task<Bool, Never>?
    var processID: Int32 { process.processIdentifier }
    var hasPendingRequests: Bool { !pending.isEmpty }

    func start(executable: URL, arguments: [String]) throws {
        guard reader == nil, !closing else { throw SessionError.launchFailed }
        process.executableURL = executable
        process.arguments = arguments
        process.standardInput = input
        process.standardOutput = output
        // stderr 单独丢弃，不混入 JSON，也不会因无人读取而塞满管道。
        process.standardError = FileHandle.nullDevice
        // 对端提前退出时让写入抛错，不让 SIGPIPE 终止整个应用。
        guard fcntl(input.fileHandleForWriting.fileDescriptor, F_SETNOSIGPIPE, 1) != -1
        else { throw SessionError.launchFailed }
        let descriptor = output.fileHandleForReading.fileDescriptor
        guard fcntl(descriptor, F_SETFL, fcntl(descriptor, F_GETFL) | O_NONBLOCK) != -1
        else { throw SessionError.launchFailed }
        do { try process.run() } catch { throw SessionError.launchFailed }
        reader = Task.detached { [weak self, process] in
            var bytes = [UInt8](repeating: 0, count: 4096)
            while !Task.isCancelled {
                let count = Darwin.read(descriptor, &bytes, bytes.count)
                if count > 0 {
                    await self?.receive(Data(bytes.prefix(count)))
                } else if count == 0 || !process.isRunning || (errno != EAGAIN && errno != EINTR) {
                    break
                } else {
                    // 非阻塞读取可取消，不会卡在没有数据的管道上。
                    try? await Task.sleep(for: .milliseconds(10))
                }
            }
            if !Task.isCancelled { await self?.reachedEOF() }
        }
    }

    func request(_ method: String, params: Data = Data("{}".utf8)) async throws -> Data {
        guard process.isRunning, !closing else { throw SessionError.disconnected }
        let parameters = try JSONSerialization.jsonObject(with: params)
        nextID += 1
        let id = nextID
        do {
            return try await withTaskCancellationHandler {
                try Task.checkCancellation()
                return try await withCheckedThrowingContinuation { continuation in
                    pending[id] = continuation
                    do { try send(["id": id, "method": method, "params": parameters]) }
                    catch { pending.removeValue(forKey: id)?.resume(throwing: error) }
                }
            } onCancel: {
                Task { await self.cancelRequests() }
            }
        } catch {
            if Task.isCancelled { await close(); throw CancellationError() }
            throw error
        }
    }

    private func cancelRequests() async {
        fail(CancellationError())
        await close()
    }

    private func send(_ message: [String: Any]) throws {
        var data = try JSONSerialization.data(withJSONObject: message)
        data.append(0x0A)
        try input.fileHandleForWriting.write(contentsOf: data)
    }

    private func receive(_ chunk: Data) {
        guard !closing else { return }
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
        } catch { fail(error); Task { await close() } }
    }

    private func reachedEOF() {
        do { try framer.finish(); fail(SessionError.disconnected) }
        catch { fail(error) }
        Task { await close() }
    }

    private func fail(_ error: Error) {
        let waiters = pending.values
        pending.removeAll()
        for waiter in waiters { waiter.resume(throwing: error) }
    }

    // 共享同一个清理任务：重复关闭和并发取消不会重复发送信号。
    @discardableResult
    func close() async -> Bool {
        if let cleanup { return await cleanup.value }
        closing = true
        fail(SessionError.disconnected)
        reader?.cancel()
        let task = Task { [process, input, output, reader] in
            try? input.fileHandleForWriting.close()
            await reader?.value
            // 依次等待正常退出、普通终止和强制终止，每阶段最多约 0.2 秒。
            for stage in 0..<3 {
                if process.isRunning {
                    if stage == 1 { process.terminate() }
                    if stage == 2 { kill(process.processIdentifier, SIGKILL) }
                }
                for _ in 0..<20 {
                    if !process.isRunning { break }
                    try? await Task.sleep(for: .milliseconds(10))
                }
            }
            try? output.fileHandleForReading.close()
            try? output.fileHandleForWriting.close()
            try? input.fileHandleForReading.close()
            return !process.isRunning
        }
        cleanup = task
        return await task.value
    }
}
