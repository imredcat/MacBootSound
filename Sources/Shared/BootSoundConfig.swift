import Foundation

/// Shared constants for LaunchDaemon, helper binary, and system-wide configuration paths.
public enum BootSoundPaths {
    public static let daemonLabel = "com.leejm.MacBootSound"
    public static let launchDaemonPlistPath = "/Library/LaunchDaemons/com.leejm.MacBootSound.plist"
    public static let helperInstallPath = "/Library/PrivilegedHelperTools/com.leejm.MacBootSound.player"
    public static let logFilePath = "/Library/Logs/MacBootSound.log"
    public static let supportDirectory = URL(
        fileURLWithPath: "/Library/Application Support/MacBootSound",
        isDirectory: true
    )
    public static var configFileURL: URL {
        supportDirectory.appendingPathComponent("config.json")
    }
}

public enum PlaybackMode: String, Codable, CaseIterable, Equatable {
    case selected
    case random
}

public struct SoundEntry: Codable, Equatable, Identifiable {
    public let id: UUID
    public var fileName: String
    public var displayName: String

    public init(id: UUID = UUID(), fileName: String, displayName: String) {
        self.id = id
        self.fileName = fileName
        self.displayName = displayName
    }
}

/// Persistent boot sound configuration shared between the GUI app and root LaunchDaemon player.
public struct BootSoundConfig: Codable, Equatable {
    public static let maxSounds = 5

    public var enabled: Bool
    public var sounds: [SoundEntry]
    public var selectedSoundID: UUID?
    public var playbackMode: PlaybackMode
    public var volume: Float

    private enum CodingKeys: String, CodingKey {
        case enabled
        case sounds
        case selectedSoundID
        case playbackMode
        case volume
        // Legacy single-sound keys for backward-compatible decoding
        case soundFileName
        case originalDisplayName
    }

    public init(
        enabled: Bool = true,
        sounds: [SoundEntry] = [],
        selectedSoundID: UUID? = nil,
        playbackMode: PlaybackMode = .selected,
        volume: Float = 1.0
    ) {
        let capped = Array(sounds.prefix(Self.maxSounds))
        self.enabled = enabled
        self.sounds = capped
        if let selectedSoundID, capped.contains(where: { $0.id == selectedSoundID }) {
            self.selectedSoundID = selectedSoundID
        } else {
            self.selectedSoundID = capped.first?.id
        }
        self.playbackMode = playbackMode
        self.volume = min(max(volume, 0.0), 1.0)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        let volume = try container.decodeIfPresent(Float.self, forKey: .volume) ?? 1.0
        let playbackMode = try container.decodeIfPresent(PlaybackMode.self, forKey: .playbackMode) ?? .selected

        var decodedSounds = try container.decodeIfPresent([SoundEntry].self, forKey: .sounds) ?? []
        var selectedID = try container.decodeIfPresent(UUID.self, forKey: .selectedSoundID)

        if decodedSounds.isEmpty,
           let legacyFile = try container.decodeIfPresent(String.self, forKey: .soundFileName),
           !legacyFile.isEmpty {
            let legacyName = try container.decodeIfPresent(String.self, forKey: .originalDisplayName) ?? legacyFile
            let migrated = SoundEntry(fileName: legacyFile, displayName: legacyName)
            decodedSounds = [migrated]
            selectedID = migrated.id
        }

        self.init(
            enabled: enabled,
            sounds: decodedSounds,
            selectedSoundID: selectedID,
            playbackMode: playbackMode,
            volume: volume
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(sounds, forKey: .sounds)
        try container.encodeIfPresent(selectedSoundID, forKey: .selectedSoundID)
        try container.encode(playbackMode, forKey: .playbackMode)
        try container.encode(volume, forKey: .volume)
    }

    /// Resolves a single stored file name safely inside `baseDirectory`, rejecting traversal or external symlinks.
    public static func resolveSafeURL(forFileName rawName: String, in baseDirectory: URL = BootSoundPaths.supportDirectory) -> URL? {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let fileName = (trimmed as NSString).lastPathComponent
        guard fileName == trimmed, fileName != ".", fileName != ".." else {
            return nil
        }

        let baseResolved = baseDirectory.resolvingSymlinksInPath().standardizedFileURL
        let candidate = baseDirectory.appendingPathComponent(fileName).resolvingSymlinksInPath().standardizedFileURL

        guard candidate.path.hasPrefix(baseResolved.path + "/") else {
            return nil
        }

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDir), !isDir.boolValue else {
            return nil
        }

        return candidate
    }

    /// Resolves all valid audio entries currently stored in `baseDirectory`.
    public func resolvedEntries(in baseDirectory: URL = BootSoundPaths.supportDirectory) -> [(entry: SoundEntry, url: URL)] {
        sounds.compactMap { entry in
            guard let url = Self.resolveSafeURL(forFileName: entry.fileName, in: baseDirectory) else {
                return nil
            }
            return (entry, url)
        }
    }

    /// Selects the audio file to play according to `playbackMode` (`selected` or `random`).
    public func resolvedSoundURL(in baseDirectory: URL = BootSoundPaths.supportDirectory) -> URL? {
        let valid = resolvedEntries(in: baseDirectory)
        guard !valid.isEmpty else {
            return nil
        }

        switch playbackMode {
        case .random:
            return valid.randomElement()?.url
        case .selected:
            if let selectedSoundID,
               let match = valid.first(where: { $0.entry.id == selectedSoundID }) {
                return match.url
            }
            return valid.first?.url
        }
    }

    public static func load(from url: URL = BootSoundPaths.configFileURL) -> BootSoundConfig? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(BootSoundConfig.self, from: data)
    }

    public func save(to url: URL = BootSoundPaths.configFileURL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: url, options: .atomic)
    }
}
