import Foundation
import XCTest
@testable import CodexPulse

@MainActor
final class CodexQuotaServiceTests: XCTestCase {
    func testDecodesModernQuotaResponseAndSelectsCodexBucket() throws {
        let fetchedAt = Date(timeIntervalSince1970: 1_900_000_000)
        let snapshot = try CodexQuotaService.decodeSnapshot(
            from: Data(
                #"""
                {
                  "rateLimits": {
                    "limitId": "legacy",
                    "primary": { "usedPercent": 99 }
                  },
                  "rateLimitsByLimitId": {
                    "other": {
                      "limitId": "other",
                      "limitName": "Other",
                      "primary": { "usedPercent": 40, "windowDurationMins": 300 }
                    },
                    "codex": {
                      "limitId": "codex",
                      "limitName": "Codex",
                      "planType": "plus",
                      "primary": {
                        "usedPercent": 25,
                        "windowDurationMins": 10080,
                        "resetsAt": 2000000000
                      }
                    }
                  },
                  "rateLimitResetCredits": { "availableCount": 3 }
                }
                """#.utf8
            ),
            fetchedAt: fetchedAt
        )

        XCTAssertEqual(snapshot.fetchedAt, fetchedAt)
        XCTAssertEqual(snapshot.buckets.map(\.id), ["codex", "other"])
        XCTAssertEqual(snapshot.primaryBucket?.id, "codex")
        XCTAssertEqual(snapshot.primaryBucket?.primary?.remainingPercent, 75)
        XCTAssertEqual(snapshot.primaryBucket?.primary?.windowDurationMinutes, 10_080)
        XCTAssertEqual(snapshot.primaryBucket?.primary?.resetsAt, Date(timeIntervalSince1970: 2_000_000_000))
        XCTAssertEqual(snapshot.resetCredits, 3)
    }

    func testDecodesLegacyQuotaResponseWhenBucketMapIsMissing() throws {
        let snapshot = try CodexQuotaService.decodeSnapshot(
            from: responseData(primaryUsed: 37, secondaryUsed: 88)
        )

        XCTAssertEqual(snapshot.buckets.count, 1)
        XCTAssertEqual(snapshot.primaryBucket?.id, "codex")
        XCTAssertEqual(snapshot.primaryBucket?.primary?.remainingPercent, 63)
        XCTAssertEqual(snapshot.primaryBucket?.secondary?.remainingPercent, 12)
    }

    func testAcceptsUsedPercentBoundaries() throws {
        let snapshot = try CodexQuotaService.decodeSnapshot(
            from: responseData(primaryUsed: 0, secondaryUsed: 100)
        )

        XCTAssertEqual(snapshot.primaryBucket?.primary?.remainingPercent, 100)
        XCTAssertEqual(snapshot.primaryBucket?.secondary?.remainingPercent, 0)
    }

    func testRejectsPercentOutsideValidRange() {
        for usedPercent in [-1, 101] {
            XCTAssertThrowsError(
                try CodexQuotaService.decodeSnapshot(from: responseData(primaryUsed: usedPercent))
            ) { error in
                XCTAssertEqual(error as? CodexQuotaError, .invalidQuota("百分比超出范围"))
            }
        }
    }

    func testRejectsMalformedAndInvalidQuotaValues() {
        let cases: [(Data, CodexQuotaError)] = [
            (
                Data(#"{"rateLimits":{"limitId":"codex","primary":{}}}"#.utf8),
                .invalidResponse
            ),
            (
                Data(#"{"rateLimits":{"limitId":"codex","primary":{"usedPercent":1,"windowDurationMins":0}}}"#.utf8),
                .invalidQuota("周期长度错误")
            ),
            (
                Data(#"{"rateLimits":{"limitId":"codex","primary":{"usedPercent":1,"resetsAt":0}}}"#.utf8),
                .invalidQuota("重置时间错误")
            ),
            (
                Data(#"{"rateLimits":{"limitId":"codex","primary":{"usedPercent":1}},"rateLimitResetCredits":{"availableCount":-1}}"#.utf8),
                .invalidQuota("重置次数错误")
            ),
            (
                Data(#"{"rateLimits":{"limitId":"codex","primary":null,"secondary":null}}"#.utf8),
                .invalidQuota("没有可用额度窗口")
            )
        ]

        for (data, expectedError) in cases {
            XCTAssertThrowsError(try CodexQuotaService.decodeSnapshot(from: data)) { error in
                XCTAssertEqual(error as? CodexQuotaError, expectedError)
            }
        }
    }

    func testFetchSnapshotSurfacesServerErrorResponse() async throws {
        let executable = try makeFakeCodex(
            response: #"{"id":2,"error":{"code":-32001,"message":"unavailable"}}"#
        )
        let service = CodexQuotaService(executableURL: executable)

        do {
            _ = try await service.fetchSnapshot()
            XCTFail("Expected the app-server error to be surfaced")
        } catch {
            XCTAssertEqual(error as? CodexQuotaError, .serverError(code: -32_001))
        }
        await service.disconnect()
    }

    func testFetchSnapshotTimesOutWhenServerStopsResponding() async throws {
        let executable = try makeSilentCodex()
        let service = CodexQuotaService(executableURL: executable, requestTimeout: .milliseconds(100))

        do {
            _ = try await service.fetchSnapshot()
            XCTFail("Expected the app-server request to time out")
        } catch {
            XCTAssertEqual(error as? CodexQuotaError, .timedOut)
        }
        await service.disconnect()
    }

    private func responseData(primaryUsed: Int, secondaryUsed: Int? = nil) -> Data {
        let secondary = secondaryUsed.map {
            #", "secondary": { "usedPercent": \#($0), "windowDurationMins": 300 }"#
        } ?? ""
        return Data(
            #"{"rateLimits":{"limitId":"codex","limitName":"Codex","primary":{"usedPercent":\#(primaryUsed),"windowDurationMins":10080}\#(secondary)}}"#.utf8
        )
    }

    private func makeFakeCodex(response: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexPulseTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }

        let executable = directory.appendingPathComponent("codex")
        let script = """
        #!/bin/sh
        IFS= read -r initialize_request
        printf '%s\\n' '{"id":1,"result":{"userAgent":"test","platformFamily":"mac","platformOs":"macOS","codexHome":"/tmp"}}'
        IFS= read -r initialized_notification
        IFS= read -r quota_request
        printf '%s\\n' '\(response)'
        IFS= read -r keep_alive
        """
        try Data(script.utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        return executable
    }

    private func makeSilentCodex() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexPulseSilentTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }

        let executable = directory.appendingPathComponent("codex")
        let script = """
        #!/bin/sh
        IFS= read -r initialize_request
        sleep 5
        """
        try Data(script.utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        return executable
    }
}
