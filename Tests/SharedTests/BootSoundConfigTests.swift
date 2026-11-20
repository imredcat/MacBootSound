import Foundation
import XCTest
@testable import Shared

final class BootSoundConfigTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacBootSoundTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
    }

    func testConfigSaveAndLoadRoundTrip() throws {
        let configURL = tempDir.appendingPathComponent("config.json")
        let entry1 = SoundEntry(fileName: "sound_1.mp3", displayName: "One.mp3")
        let entry2 = SoundEntry(fileName: "sound_2.wav", displayName: "Two.wav")
        let original = BootSoundConfig(
            enabled: true,
            sounds: [entry1, entry2],
            selectedSoundID: entry2.id,
            playbackMode: .random,
            volume: 0.75
        )

        try original.save(to: configURL)
        let loaded = BootSoundConfig.load(from: configURL)
        XCTAssertEqual(loaded, original)
    }

    func testLegacySingleSoundConfigMigratesOnDecode() throws {
        let legacyJSON = """
        {
          "enabled": true,
          "soundFileName": "boot_sound.mp3",
          "originalDisplayName": "OldStartup.mp3",
          "volume": 0.6
        }
        """
        let configURL = tempDir.appendingPathComponent("legacy.json")
        try Data(legacyJSON.utf8).write(to: configURL)

        let loaded = BootSoundConfig.load(from: configURL)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.sounds.count, 1)
        XCTAssertEqual(loaded?.sounds.first?.fileName, "boot_sound.mp3")
        XCTAssertEqual(loaded?.sounds.first?.displayName, "OldStartup.mp3")
        XCTAssertEqual(loaded?.selectedSoundID, loaded?.sounds.first?.id)
        XCTAssertEqual(loaded?.playbackMode, .selected)
    }

    func testSoundsAreCappedAtFive() {
        let many = (1...7).map { SoundEntry(fileName: "sound_\($0).wav", displayName: "Sound \($0)") }
        let config = BootSoundConfig(sounds: many)
        XCTAssertEqual(config.sounds.count, 5)
    }

    func testSelectedAndRandomPlaybackModes() throws {
        let url1 = tempDir.appendingPathComponent("s1.wav")
        let url2 = tempDir.appendingPathComponent("s2.wav")
        try Data("RIFF".utf8).write(to: url1)
        try Data("RIFF".utf8).write(to: url2)

        let e1 = SoundEntry(fileName: "s1.wav", displayName: "s1.wav")
        let e2 = SoundEntry(fileName: "s2.wav", displayName: "s2.wav")

        let selectedConfig = BootSoundConfig(sounds: [e1, e2], selectedSoundID: e2.id, playbackMode: .selected)
        XCTAssertEqual(selectedConfig.resolvedSoundURL(in: tempDir)?.path, url2.resolvingSymlinksInPath().path)

        let randomConfig = BootSoundConfig(sounds: [e1, e2], selectedSoundID: e1.id, playbackMode: .random)
        let validPaths = Set([url1.resolvingSymlinksInPath().path, url2.resolvingSymlinksInPath().path])
        for _ in 0..<10 {
            let picked = randomConfig.resolvedSoundURL(in: tempDir)?.path
            XCTAssertNotNil(picked)
            XCTAssertTrue(validPaths.contains(picked!))
        }
    }

    func testVolumeIsClamped() {
        let low = BootSoundConfig(volume: -0.5)
        let high = BootSoundConfig(volume: 1.8)
        XCTAssertEqual(low.volume, 0.0)
        XCTAssertEqual(high.volume, 1.0)
    }

    func testResolvedSoundURLRejectsTraversalAndSubpaths() throws {
        let outsideFile = FileManager.default.temporaryDirectory.appendingPathComponent("outside-\(UUID().uuidString).wav")
        try Data("RIFF".utf8).write(to: outsideFile)
        defer { try? FileManager.default.removeItem(at: outsideFile) }

        let traversal = BootSoundConfig(sounds: [SoundEntry(fileName: "../\(outsideFile.lastPathComponent)", displayName: "bad")])
        XCTAssertNil(traversal.resolvedSoundURL(in: tempDir))

        let subpath = BootSoundConfig(sounds: [SoundEntry(fileName: "sub/sound.wav", displayName: "bad")])
        XCTAssertNil(subpath.resolvedSoundURL(in: tempDir))

        let symlinkURL = tempDir.appendingPathComponent("escape.wav")
        try FileManager.default.createSymbolicLink(at: symlinkURL, withDestinationURL: outsideFile)
        let symlinkConfig = BootSoundConfig(sounds: [SoundEntry(fileName: "escape.wav", displayName: "bad")])
        XCTAssertNil(symlinkConfig.resolvedSoundURL(in: tempDir))
    }
}
