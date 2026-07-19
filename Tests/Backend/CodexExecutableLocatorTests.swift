import Foundation
import XCTest
@testable import CodexPulse

@MainActor
final class CodexExecutableLocatorTests: XCTestCase {
    func testFindsFirstExecutableCandidate() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexExecutableLocatorTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }

        let nonExecutable = directory.appendingPathComponent("not-executable")
        let firstExecutable = directory.appendingPathComponent("first-executable")
        let secondExecutable = directory.appendingPathComponent("second-executable")
        for file in [nonExecutable, firstExecutable, secondExecutable] {
            try Data().write(to: file)
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: nonExecutable.path)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: firstExecutable.path)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: secondExecutable.path)

        let found = CodexQuotaService.findCodexExecutable(
            candidates: [nonExecutable, firstExecutable, secondExecutable]
        )

        XCTAssertEqual(found, firstExecutable)
    }

    func testFallsBackWhenNoCandidateIsExecutable() throws {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-codex-\(UUID().uuidString)")

        XCTAssertEqual(
            CodexQuotaService.findCodexExecutable(candidates: [missing]),
            URL(fileURLWithPath: "/usr/bin/codex")
        )
    }
}
