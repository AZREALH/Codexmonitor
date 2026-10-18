import Darwin
import Foundation
import XCTest
@testable import CodexMonitor

final class SessionLifecycleTests: XCTestCase {
    private func waitUntilRequestIsPending(_ session: CodexSession) async throws {
        // 确认已经在等响应，而不是碰巧取消了一个尚未启动的任务。
        for _ in 0..<100 {
            if await session.hasPendingRequests { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Request did not enter waiting state within one second")
    }

    // 替身先确认就绪，再保持运行；闹钟保证测试失败时也不会无限遗留。
    private func readySession(ignoreTermination: Bool = false) async throws -> CodexSession {
        let script = """
        import json, signal, sys, time
        signal.alarm(5)
        \(ignoreTermination ? "signal.signal(signal.SIGTERM, signal.SIG_IGN)" : "")
        r = json.loads(sys.stdin.readline())
        print(json.dumps({'id':r['id'],'result':{'ready':True}}), flush=True)
        while True: time.sleep(1)
        """
        let session = CodexSession()
        addTeardownBlock { await session.close() }
        try await session.start(executable: URL(fileURLWithPath: "/usr/bin/python3"),
                                arguments: ["-u", "-c", script])
        _ = try await session.request("ready")
        return session
    }

    func testCancellationEscalatesAndDoesNotKillUnrelatedProcess() async throws {
        let unrelated = try await readySession()
        let unrelatedPID = await unrelated.processID
        let session = try await readySession(ignoreTermination: true)
        let pid = await session.processID
        let request = Task { try await session.request("wait") }
        try await waitUntilRequestIsPending(session)
        let start = ContinuousClock.now
        request.cancel()
        switch await request.result {
        case .success: XCTFail("Cancelled request must fail")
        case .failure(let error): XCTAssertTrue(error is CancellationError)
        }
        XCTAssertLessThan(start.duration(to: .now), .seconds(2))
        XCTAssertEqual(kill(pid, 0), -1)
        XCTAssertEqual(errno, ESRCH)
        XCTAssertEqual(kill(unrelatedPID, 0), 0)
        let closed = await session.close()
        XCTAssertTrue(closed)
    }

    func testRepeatedCloseEndsPendingRequestsAndRejectsNewOnes() async throws {
        let session = try await readySession()
        let pid = await session.processID
        let request = Task { try await session.request("wait") }
        try await waitUntilRequestIsPending(session)
        let first = await session.close()
        let second = await session.close()
        XCTAssertTrue(first && second)
        switch await request.result {
        case .success: XCTFail("Closed request must fail")
        case .failure(let error):
            XCTAssertEqual(error as? CodexSession.SessionError, .disconnected)
        }
        do {
            _ = try await session.request("late")
            XCTFail("Closed session accepted a request")
        } catch { XCTAssertEqual(error as? CodexSession.SessionError, .disconnected) }
        XCTAssertEqual(kill(pid, 0), -1)
        XCTAssertEqual(errno, ESRCH)
    }

    func testUnexpectedExitCompletesWaitingRequest() async throws {
        let session = CodexSession()
        addTeardownBlock { await session.close() }
        let script = "import os, signal, sys; signal.alarm(5); sys.stdin.readline(); os._exit(7)"
        try await session.start(executable: URL(fileURLWithPath: "/usr/bin/python3"),
                                arguments: ["-u", "-c", script])
        do {
            _ = try await session.request("exit")
            XCTFail("Expected disconnected error")
        } catch { XCTAssertEqual(error as? CodexSession.SessionError, .disconnected) }
        let closed = await session.close()
        XCTAssertTrue(closed)
    }
}
