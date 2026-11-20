import XCTest
@testable import Shared

final class SystemStateParserTests: XCTestCase {
    func testStartupMuteZeroMeansEnabled() {
        XCTAssertTrue(SystemStateParser.isSystemStartupSoundEnabled(nvramOutput: "StartupMute\t%00\n", exitCode: 0))
    }

    func testStartupMuteMissingMeansEnabled() {
        XCTAssertTrue(
            SystemStateParser.isSystemStartupSoundEnabled(
                nvramOutput: "nvram: Error getting variable - 'StartupMute': (iokit/common) data was not found",
                exitCode: 1
            )
        )
    }

    func testStartupMuteOneMeansDisabled() {
        XCTAssertFalse(SystemStateParser.isSystemStartupSoundEnabled(nvramOutput: "StartupMute\t%01\n", exitCode: 0))
    }

    func testFileVaultStatusParsing() {
        XCTAssertTrue(SystemStateParser.isFileVaultEnabled(fdesetupOutput: "FileVault is On.\n"))
        XCTAssertFalse(SystemStateParser.isFileVaultEnabled(fdesetupOutput: "FileVault is Off.\n"))
    }
}
