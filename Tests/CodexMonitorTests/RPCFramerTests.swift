import Foundation
import XCTest
@testable import CodexMonitor

final class RPCFramerTests: XCTestCase {
    func testSplitMessageAndEmptyInput() throws {
        var framer = RPCFramer()
        XCTAssertTrue(try framer.append(Data()).isEmpty)
        XCTAssertTrue(try framer.append(Data("{\"id\":".utf8)).isEmpty)
        let frames = try framer.append(Data("1}\n".utf8))
        XCTAssertEqual(frames, [Data("{\"id\":1}".utf8)])
        XCTAssertTrue(try framer.append(Data()).isEmpty)
        try framer.finish()
    }

    func testMultipleFramesKeepOrderAndTrailingPartial() throws {
        var framer = RPCFramer()
        XCTAssertEqual(try framer.append(Data("{\"id\":1}\n{\"id\":2}\r\n{".utf8)),
                       [Data("{\"id\":1}".utf8), Data("{\"id\":2}\r".utf8)])
        XCTAssertEqual(try framer.append(Data("}\n".utf8)), [Data("{}".utf8)])
        try framer.finish()
    }

    func testEveryByteMayArriveSeparatelyIncludingChineseText() throws {
        let payload = Data("{\"text\":\"额度\\n正常\"}".utf8)
        var framer = RPCFramer()
        var frames: [Data] = []
        for byte in payload + Data([0x0A]) {
            frames += try framer.append(Data([byte]))
        }
        XCTAssertEqual(frames, [payload])
    }

    func testInvalidJSONOrNonObjectFailsAndCannotBeReused() {
        // 空行不是有效协议消息；文本、数组和无效 UTF-8 也不能混入 stdout。
        let inputs = [Data("oops\n".utf8), Data("[]\n".utf8), Data("\n".utf8),
                      Data([0x7B, 0xFF, 0x7D, 0x0A])]
        for input in inputs {
            var framer = RPCFramer()
            XCTAssertThrowsError(try framer.append(input)) {
                XCTAssertEqual($0 as? RPCFramer.FramingError, .invalidJSON)
            }
            XCTAssertThrowsError(try framer.append(Data("{}\n".utf8))) {
                XCTAssertEqual($0 as? RPCFramer.FramingError, .unusableAfterFailure)
            }
        }
    }

    func testFrameLimitAcrossChunksAndLimitPerFrame() throws {
        var framer = RPCFramer(maximumFrameBytes: 2)
        XCTAssertEqual(try framer.append(Data("{}\n{}\n".utf8)).count, 2)
        XCTAssertTrue(try framer.append(Data("{".utf8)).isEmpty)
        XCTAssertThrowsError(try framer.append(Data("  ".utf8))) {
            XCTAssertEqual($0 as? RPCFramer.FramingError, .frameTooLarge)
        }
        XCTAssertThrowsError(try framer.finish())
    }

    func testEOFFailsForPartialMessageEvenIfJSONIsOtherwiseValid() {
        for partial in ["{", "{}"] {
            var framer = RPCFramer()
            XCTAssertNoThrow(try framer.append(Data(partial.utf8)))
            XCTAssertThrowsError(try framer.finish()) {
                XCTAssertEqual($0 as? RPCFramer.FramingError, .incompleteFrame)
            }
        }
    }
}
