import Foundation
import XCTest
@testable import CodexMonitor

final class SingleInstanceTests: XCTestCase {
    func testOnlyOneOwnerAndRestartAfterRelease() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("instance.lock")
        var first = try SingleInstance(at: url)
        XCTAssertNotNil(first)
        XCTAssertNil(try SingleInstance(at: url))
        first = nil
        // 空锁文件仍存在，但上一实例退出后新实例应能取得锁。
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let restarted = try SingleInstance(at: url)
        XCTAssertNotNil(restarted)
        try withExtendedLifetime(restarted) {
            XCTAssertNil(try SingleInstance(at: url))
        }
    }

    func testMissingParentReportsAnErrorInsteadOfStartingUnlocked() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathComponent("instance.lock")
        XCTAssertThrowsError(try SingleInstance(at: url))
    }
}
