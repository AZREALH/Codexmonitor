import Darwin
import Foundation
import XCTest
@testable import CodexMonitor

final class CodexReaderTests: XCTestCase {
    // 替身验证消息顺序及只读参数，延迟可模拟累计耗时。
    private func reader(auth: String = "chatgpt", delay: Double = 0, failure: String = "",
                        timeout: Duration = .seconds(2)) -> (CodexReader, CodexSession) {
        let session = CodexSession()
        addTeardownBlock { await session.close() }
        let script = """
        import json, signal, sys, time
        signal.alarm(5)
        for method in ['initialize','initialized','account/read','account/rateLimits/read']:
            r = json.loads(sys.stdin.readline())
            assert r['method'] == method
            if method == 'initialized':
                assert 'id' not in r
                continue
            time.sleep(\(delay))
            if method == 'account/read': assert r['params'] == {'refreshToken':False}
            result = {'account':{'type':'\(auth)'}} if method == 'account/read' else {}
            if method == 'account/rateLimits/read':
                if '\(failure)':
                    print(json.dumps({'id':r['id'],'error':{'code':-32000,'message':'\(failure)'}}), flush=True)
                    continue
                result = {'rateLimits':{'limitId':'test','primary':{'usedPercent':25}}}
            print(json.dumps({'id':r['id'],'result':result}), flush=True)
        """
        return (CodexReader(executable: URL(fileURLWithPath: "/usr/bin/python3"),
            arguments: ["-u", "-c", script], timeout: timeout, makeSession: { session }), session)
    }

    private func assertReaped(_ session: CodexSession) async {
        let pid = await session.processID
        XCTAssertGreaterThan(pid, 0)
        XCTAssertEqual(kill(pid, 0), -1)
        XCTAssertEqual(errno, ESRCH)
    }

    func testSuccessAndAuthenticationRejectionCleanUp() async throws {
        let (success, session) = reader()
        let snapshot = try await success.readSnapshot()
        XCTAssertEqual(snapshot.items.first?.remainingPercent, 75)
        await assertReaped(session)
        for auth in ["apiKey", "unknown"] {
            let (rejected, rejectedSession) = reader(auth: auth)
            do { _ = try await rejected.readSnapshot(); XCTFail("Expected auth rejection") }
            catch { XCTAssertEqual(error as? ReadError, .authenticationRequired) }
            await assertReaped(rejectedSession)
        }
    }

    func testServiceAndRateLimitErrorsCleanUp() async {
        for message in ["upstream failed", "HTTP 429; Retry-After: 120"] {
            let (source, session) = reader(failure: message)
            do { _ = try await source.readSnapshot(); XCTFail("Expected failure") }
            catch let error as ReadError {
                if message.hasPrefix("HTTP") { XCTAssertNotNil(error.retryAt) }
                else { XCTAssertEqual(error, .serviceUnavailable) }
            } catch { XCTFail("Unexpected error type") }
            await assertReaped(session)
        }
    }

    func testTotalDeadlineDoesNotResetBetweenSteps() async {
        // 每步 80ms 小于总上限 230ms，三步累计仍必须超时。
        let (source, session) = reader(delay: 0.08, timeout: .milliseconds(230))
        do { _ = try await source.readSnapshot(); XCTFail("Expected total timeout") }
        catch { XCTAssertEqual(error as? ReadError, .timeout) }
        await assertReaped(session)
    }

    func testCancellationCleansUpRealChild() async throws {
        let (source, session) = reader(delay: 0.2)
        let task = Task { try await source.readSnapshot() }
        for _ in 0..<100 {
            if await session.hasPendingRequests { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        task.cancel()
        do { _ = try await task.value; XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
        await assertReaped(session)
    }

    func testLiveSubscriptionWhenExplicitlyEnabled() async throws {
        guard let executable = ProcessInfo.processInfo.environment["CODEX_MONITOR_LIVE_PATH"]
        else { throw XCTSkip("Live subscription check requires explicit path") }
        let session = CodexSession()
        addTeardownBlock { await session.close() }
        let source = CodexReader(executable: URL(fileURLWithPath: executable), makeSession: { session })
        let snapshot = try await source.readSnapshot()
        XCTAssertFalse(snapshot.items.isEmpty)
        XCTAssertTrue(snapshot.items.allSatisfy { $0.usedPercent != nil })
        await assertReaped(session)
        print("LIVE PASS: windows=\(snapshot.items.count); child process reaped; raw data omitted")
        // 仅记录字段可用性，不打印卡片 ID、描述或完整账户响应。
        print("LIVE reset credits: count=\(snapshot.resetCredits?.availableCount.map(String.init) ?? "unknown"); details=\(snapshot.resetCredits?.credits?.count.description ?? "unknown")")
    }
}
