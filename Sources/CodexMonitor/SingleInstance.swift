import Darwin
import Foundation

// 同一用户的应用共用一个锁，命令行启动和 .app 启动也不能重复创建图标。
final class SingleInstance {
    private let descriptor: Int32

    init?(at url: URL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CodexMonitor-\(getuid()).lock")) throws {
        let opened = open(url.path, O_CREAT | O_RDWR | O_NOFOLLOW, mode_t(0o600))
        guard opened >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        guard flock(opened, LOCK_EX | LOCK_NB) == 0 else {
            let code = errno
            Darwin.close(opened)
            if code == EWOULDBLOCK { return nil }
            throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
        }
        descriptor = opened
    }

    deinit {
        // 正常退出或崩溃都会由系统释放锁；保留空文件，避免删除后出现两把锁。
        Darwin.close(descriptor)
    }
}
