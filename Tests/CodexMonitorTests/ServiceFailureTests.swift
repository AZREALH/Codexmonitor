import Foundation
import XCTest
@testable import CodexMonitor

final class ServiceFailureTests: XCTestCase {
    func testOnlyExplicitStatusAndNumericRetryHeaderAreRecognized() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertEqual(ServiceFailure.classify(["code": 401]), .authenticationRequired)
        XCTAssertEqual(ServiceFailure.classify(["code": -32000, "message": "HTTP 403"]), .authenticationRequired)
        XCTAssertEqual(ServiceFailure.classify(["code": -32000, "message": "HTTP 429; Retry-After: 120"], now: now),
                       .rateLimited(retryAt: now.addingTimeInterval(120)))
        XCTAssertEqual(ServiceFailure.classify(["code": 429]), .rateLimited(retryAt: nil))
        XCTAssertNil(ServiceFailure.classify(["code": -32000, "message": "unknown 429 text"]))
    }

    func testNotificationDoesNotExpectResponseOrHaveID() async throws {
        let session = CodexSession()
        addTeardownBlock { await session.close() }
        let script = """
        import json, signal, sys
        signal.alarm(5)
        n = json.loads(sys.stdin.readline())
        r = json.loads(sys.stdin.readline())
        print(json.dumps({'id':r['id'],'result':{'method':n['method'],'hasID':'id' in n}}), flush=True)
        """
        try await session.start(executable: URL(fileURLWithPath: "/usr/bin/python3"), arguments: ["-u", "-c", script])
        try await session.notify("initialized")
        let data = try await session.request("check")
        let result = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(result["method"] as? String, "initialized")
        XCTAssertEqual(result["hasID"] as? Bool, false)
    }
}
