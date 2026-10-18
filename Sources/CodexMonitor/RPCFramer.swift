import Foundation

// 只把字节流切成完整 JSON 消息；请求 ID、通知和额度字段由后续模块处理。
struct RPCFramer {
    enum FramingError: Error, Equatable {
        case frameTooLarge
        case invalidJSON
        case incompleteFrame
        case unusableAfterFailure
    }

    private let maximumFrameBytes: Int
    private var pending = Data()
    private var hasFailed = false

    init(maximumFrameBytes: Int = 1_048_576) {
        precondition(maximumFrameBytes > 0)
        self.maximumFrameBytes = maximumFrameBytes
    }

    mutating func append(_ chunk: Data) throws -> [Data] {
        guard !hasFailed else { throw FramingError.unusableAfterFailure }
        var frames: [Data] = []
        do {
            // 按字节积累，不提前转字符串，UTF-8 字符被分到两次读取也不受影响。
            for byte in chunk {
                if byte == 0x0A {
                    guard let object = try? JSONSerialization.jsonObject(with: pending),
                          object is [String: Any] else { throw FramingError.invalidJSON }
                    frames.append(pending)
                    pending = Data()
                } else {
                    // 先检查再追加，半条消息也不能无限占用缓冲。
                    guard pending.count < maximumFrameBytes else { throw FramingError.frameTooLarge }
                    pending.append(byte)
                }
            }
            return frames
        } catch {
            invalidate()
            throw error
        }
    }

    mutating func finish() throws {
        guard !hasFailed else { throw FramingError.unusableAfterFailure }
        // EOF 时还有残留表示消息被截断，不能当作正常结束。
        guard pending.isEmpty else {
            invalidate()
            throw FramingError.incompleteFrame
        }
    }

    private mutating func invalidate() {
        pending = Data()
        hasFailed = true
    }
}
