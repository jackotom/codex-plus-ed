import Foundation
import XCTest
@testable import CodexPulse

final class QuotaModelsTests: XCTestCase {
    func testWindowComputesRemainingPercent() {
        let window = RateLimitWindow(usedPercent: 37, windowDurationMinutes: 300, resetsAt: nil)
        XCTAssertEqual(window.remainingPercent, 63)
    }

    func testPrimaryBucketPrefersCodex() {
        let other = RateLimitBucket(id: "other", limitName: nil, planType: nil, primary: nil, secondary: nil)
        let codex = RateLimitBucket(id: "codex", limitName: nil, planType: "plus", primary: nil, secondary: nil)
        let snapshot = QuotaSnapshot(buckets: [other, codex], resetCredits: 1, fetchedAt: Date())
        XCTAssertEqual(snapshot.primaryBucket?.id, "codex")
    }

    func testPrimaryWindowUsesLongestQuotaWindow() {
        let short = RateLimitWindow(usedPercent: 10, windowDurationMinutes: 300, resetsAt: nil)
        let weekly = RateLimitWindow(usedPercent: 40, windowDurationMinutes: 10_080, resetsAt: nil)
        let bucket = RateLimitBucket(
            id: "codex",
            limitName: nil,
            planType: nil,
            primary: short,
            secondary: weekly
        )
        let snapshot = QuotaSnapshot(buckets: [bucket], resetCredits: nil, fetchedAt: Date())

        XCTAssertEqual(snapshot.primaryWindow, weekly)
        XCTAssertEqual(snapshot.primaryWindow?.remainingPercent, 60)
    }

    func testDecodesAndValidatesRateLimits() throws {
        let data = Data(#"{"rateLimits":{"limitId":"legacy","primary":{"usedPercent":1}},"rateLimitsByLimitId":{"codex":{"limitId":"codex","limitName":"Codex","planType":"plus","primary":{"usedPercent":25,"windowDurationMins":300,"resetsAt":1900000000},"secondary":{"usedPercent":40,"windowDurationMins":10080,"resetsAt":1900000001}}},"rateLimitResetCredits":{"availableCount":2}}"#.utf8)
        let snapshot = try CodexQuotaService.decodeSnapshot(from: data, fetchedAt: Date(timeIntervalSince1970: 1))

        XCTAssertEqual(snapshot.primaryBucket?.secondary?.remainingPercent, 60)
        XCTAssertEqual(snapshot.resetCredits, 2)
        XCTAssertEqual(snapshot.fetchedAt, Date(timeIntervalSince1970: 1))
    }

    func testRejectsOutOfRangePercent() {
        let data = Data(#"{"rateLimits":{"limitId":"codex","primary":{"usedPercent":101}}}"#.utf8)

        XCTAssertThrowsError(try CodexQuotaService.decodeSnapshot(from: data))
    }
}
