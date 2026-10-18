import Foundation
import XCTest
@testable import CodexMonitor

final class CodexSessionTests: XCTestCase {
    func testOutOfOrderRepliesNotificationsUnsupportedRequestAndStderr() async throws {
        // 替身故意倒序回复、夹入通知和服务端请求，并大量写 stderr。
        let script = """
        import json, os, signal, sys
        signal.alarm(5)
        requests = [json.loads(sys.stdin.readline()) for _ in range(2)]
        print(json.dumps({'method':'notice','params':{}}), flush=True)
        print(json.dumps({'id':'server-1','method':'unknown','params':{}}), flush=True)
        rejection = json.loads(sys.stdin.readline())
        os.write(2, b'x' * 262144)
        for r in reversed(requests):
            print(json.dumps({'id':r['id'],'result':{'method':r['method'],
                'rejection':rejection['error']['code']}}), flush=True)
        """
        let session = CodexSession()
        addTeardownBlock { await session.close() }
        try await session.start(executable: URL(fileURLWithPath: "/usr/bin/python3"),
                                arguments: ["-u", "-c", script])
        async let first = session.request("first")
        async let second = session.request("second")
        let results = try await [first, second]
        for (data, expected) in zip(results, ["first", "second"]) {
            let value = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            XCTAssertEqual(value["method"] as? String, expected)
            XCTAssertEqual(value["rejection"] as? Int, -32601)
        }
    }

    func testServerErrorIsReturnedWithoutResponseText() async throws {
        let script = """
        import json, signal, sys
        signal.alarm(5)
        r = json.loads(sys.stdin.readline())
        print(json.dumps({'id':r['id'],'error':{'code':-32000,'message':'private'}}), flush=True)
        """
        let session = CodexSession()
        addTeardownBlock { await session.close() }
        try await session.start(executable: URL(fileURLWithPath: "/usr/bin/python3"),
                                arguments: ["-u", "-c", script])
        do {
            _ = try await session.request("failure")
            XCTFail("Expected server error")
        } catch { XCTAssertEqual(error as? CodexSession.SessionError, .server(code: -32000)) }
    }

    func testMissingExecutableReturnsLaunchFailure() async {
        let session = CodexSession()
        addTeardownBlock { await session.close() }
        do {
            try await session.start(executable: URL(fileURLWithPath: "/nonexistent/codex-monitor"), arguments: [])
            XCTFail("Expected launch error")
        } catch { XCTAssertEqual(error as? CodexSession.SessionError, .launchFailed) }
    }
}
