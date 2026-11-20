import AppKit
import Foundation
import Shared

enum DaemonError: Error {
    case helperBinaryMissing
    case userCanceled
    case scriptFailed(String)

    func localizedMessage(in lang: AppLanguage) -> String {
        switch self {
        case .helperBinaryMissing:
            return L10n.t(
                "내부 플레이어 바이너리(MacBootSoundPlayer)를 찾을 수 없습니다. 앱 번들을 다시 빌드해 주세요.",
                "Internal player binary (MacBootSoundPlayer) was not found. Please rebuild the app bundle.",
                lang: lang
            )
        case .userCanceled:
            return L10n.t(
                "관리자 권한 인증이 취소되었습니다.",
                "Administrator authentication was canceled.",
                lang: lang
            )
        case .scriptFailed(let message):
            return L10n.t(
                "시스템 설정 적용 실패: \(message)",
                "Failed to apply system settings: \(message)",
                lang: lang
            )
        }
    }
}

struct SoundListItem: Identifiable, Equatable {
    let id: UUID
    let displayName: String
    let previewURL: URL
}

@MainActor
final class DaemonManager: ObservableObject {
    @Published private(set) var isInstalled = false
    @Published private(set) var config = BootSoundConfig()
    @Published private(set) var pendingSounds: [SoundListItem] = []
    @Published private(set) var isSystemStartupSoundEnabled = false
    @Published private(set) var isFileVaultEnabled = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?

    var language: AppLanguage = AppLanguage.defaultLanguage()

    init() {
        refresh()
    }

    var soundItems: [SoundListItem] {
        let saved = config.resolvedEntries().map { item in
            SoundListItem(
                id: item.entry.id,
                displayName: item.entry.displayName,
                previewURL: item.url
            )
        }
        return saved + pendingSounds
    }

    var canAddMoreSounds: Bool {
        soundItems.count < BootSoundConfig.maxSounds
    }

    func refresh() {
        let fm = FileManager.default
        isInstalled = fm.fileExists(atPath: BootSoundPaths.launchDaemonPlistPath)
            && fm.fileExists(atPath: BootSoundPaths.helperInstallPath)

        if let loaded = BootSoundConfig.load() {
            config = loaded
            pendingSounds = []
        }

        refreshSystemSettingsState()
    }

    func refreshSystemSettingsState() {
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                let nvram = Self.runCommand("/usr/sbin/nvram", arguments: ["StartupMute"])
                let fde = Self.runCommand("/usr/bin/fdesetup", arguments: ["status"])
                return (
                    SystemStateParser.isSystemStartupSoundEnabled(
                        nvramOutput: nvram.output,
                        exitCode: nvram.exitCode
                    ),
                    SystemStateParser.isFileVaultEnabled(fdesetupOutput: fde.output)
                )
            }.value

            isSystemStartupSoundEnabled = result.0
            isFileVaultEnabled = result.1
        }
    }

    func setSystemStartupSoundEnabled(_ enabled: Bool) {
        errorMessage = nil
        statusMessage = nil

        let muteValue = enabled ? "%00" : "%01"
        do {
            try runPrivilegedShell("/usr/sbin/nvram StartupMute=\(muteValue)")
            refreshSystemSettingsState()
            statusMessage = enabled
                ? L10n.t("시스템 설정의 '시동 시 사운드 재생'이 켜졌습니다.", "System 'Play sound on startup' is now on.", lang: language)
                : L10n.t("시스템 설정의 '시동 시 사운드 재생'을 껐습니다.", "System 'Play sound on startup' has been turned off.", lang: language)
        } catch {
            refreshSystemSettingsState()
            errorMessage = formatError(error)
        }
    }

    func addSounds(from sourceURLs: [URL]) {
        errorMessage = nil
        statusMessage = nil

        let remainingSlots = BootSoundConfig.maxSounds - soundItems.count
        guard remainingSlots > 0 else {
            errorMessage = L10n.t(
                "사운드는 최대 \(BootSoundConfig.maxSounds)개까지 추가할 수 있습니다.",
                "You can add up to \(BootSoundConfig.maxSounds) sounds.",
                lang: language
            )
            return
        }

        let urlsToAdd = Array(sourceURLs.prefix(remainingSlots))
        let skippedCount = sourceURLs.count - urlsToAdd.count
        let fm = FileManager.default

        if fm.isWritableFile(atPath: BootSoundPaths.supportDirectory.path) {
            do {
                var updated = config
                for sourceURL in urlsToAdd {
                    let id = UUID()
                    let fileName = storedFileName(for: id, sourceURL: sourceURL)
                    let targetURL = BootSoundPaths.supportDirectory.appendingPathComponent(fileName)
                    try fm.copyItem(at: sourceURL, to: targetURL)
                    try fm.setAttributes([.posixPermissions: 0o644], ofItemAtPath: targetURL.path)

                    let entry = SoundEntry(id: id, fileName: fileName, displayName: sourceURL.lastPathComponent)
                    updated.sounds.append(entry)
                    if updated.selectedSoundID == nil {
                        updated.selectedSoundID = entry.id
                    }
                }
                try updated.save()
                config = updated

                if skippedCount > 0 {
                    statusMessage = L10n.t(
                        "최대 \(BootSoundConfig.maxSounds)개 제한으로 \(urlsToAdd.count)개만 추가되었습니다.",
                        "Added \(urlsToAdd.count) file(s); maximum of \(BootSoundConfig.maxSounds) reached.",
                        lang: language
                    )
                } else {
                    statusMessage = L10n.t(
                        "사운드가 추가되어 다음 부팅부터 바로 반영됩니다.",
                        "Sound(s) added and ready for next boot.",
                        lang: language
                    )
                }
            } catch {
                errorMessage = L10n.t(
                    "사운드 파일 저장 실패: \(error.localizedDescription)",
                    "Failed to save sound file: \(error.localizedDescription)",
                    lang: language
                )
            }
        } else {
            for sourceURL in urlsToAdd {
                let item = SoundListItem(
                    id: UUID(),
                    displayName: sourceURL.lastPathComponent,
                    previewURL: sourceURL
                )
                pendingSounds.append(item)
                if config.selectedSoundID == nil {
                    config.selectedSoundID = item.id
                }
            }

            if skippedCount > 0 {
                statusMessage = L10n.t(
                    "최대 \(BootSoundConfig.maxSounds)개 제한으로 \(urlsToAdd.count)개만 추가되었습니다.",
                    "Added \(urlsToAdd.count) file(s); maximum of \(BootSoundConfig.maxSounds) reached.",
                    lang: language
                )
            } else {
                statusMessage = L10n.t(
                    "사운드가 추가되었습니다. '부팅 사운드 등록'을 눌러 적용하세요.",
                    "Sound(s) added. Click 'Register Boot Sound' to apply.",
                    lang: language
                )
            }
        }
    }

    func removeSound(id: UUID) {
        errorMessage = nil
        statusMessage = nil

        if let pendingIndex = pendingSounds.firstIndex(where: { $0.id == id }) {
            pendingSounds.remove(at: pendingIndex)
            if config.selectedSoundID == id {
                config.selectedSoundID = soundItems.first?.id
            }
            return
        }

        guard let index = config.sounds.firstIndex(where: { $0.id == id }) else {
            return
        }

        let removed = config.sounds.remove(at: index)
        if config.selectedSoundID == id {
            config.selectedSoundID = config.sounds.first?.id
        }

        if let fileURL = BootSoundConfig.resolveSafeURL(forFileName: removed.fileName) {
            try? FileManager.default.removeItem(at: fileURL)
        }

        saveConfigIfWritable()
        statusMessage = L10n.t("사운드가 목록에서 삭제되었습니다.", "Sound removed from the list.", lang: language)
    }

    func selectSound(id: UUID) {
        config.selectedSoundID = id
        saveConfigIfWritable()
    }

    func updatePlaybackMode(_ mode: PlaybackMode) {
        config.playbackMode = mode
        saveConfigIfWritable()
    }

    func updateEnabled(_ enabled: Bool) {
        config.enabled = enabled
        saveConfigIfWritable()
    }

    func updateVolume(_ volume: Float) {
        config.volume = min(max(volume, 0.0), 1.0)
        saveConfigIfWritable()
    }

    func installOrUpdateDaemon() {
        errorMessage = nil
        statusMessage = nil

        do {
            guard let helperSourceURL = locateHelperBinary() else {
                throw DaemonError.helperBinaryMissing
            }

            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("MacBootSound-stage-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tempDir) }

            var stagedEntries: [SoundEntry] = []
            var stagedAudioPaths: [(source: String, destName: String)] = []

            for item in soundItems.prefix(BootSoundConfig.maxSounds) {
                let fileName = storedFileName(for: item.id, sourceURL: item.previewURL)
                let stagedAudioURL = tempDir.appendingPathComponent(fileName)
                try FileManager.default.copyItem(at: item.previewURL, to: stagedAudioURL)
                stagedEntries.append(SoundEntry(id: item.id, fileName: fileName, displayName: item.displayName))
                stagedAudioPaths.append((stagedAudioURL.path, fileName))
            }

            let selectedID: UUID? = {
                if let existing = config.selectedSoundID, stagedEntries.contains(where: { $0.id == existing }) {
                    return existing
                }
                return stagedEntries.first?.id
            }()

            let configToInstall = BootSoundConfig(
                enabled: config.enabled,
                sounds: stagedEntries,
                selectedSoundID: selectedID,
                playbackMode: config.playbackMode,
                volume: config.volume
            )

            let stagedConfigURL = tempDir.appendingPathComponent("config.json")
            try configToInstall.save(to: stagedConfigURL)

            let stagedPlistURL = tempDir.appendingPathComponent("\(BootSoundPaths.daemonLabel).plist")
            try buildLaunchDaemonPlist().write(to: stagedPlistURL, atomically: true, encoding: .utf8)

            let currentUser = NSUserName()
            let supportPath = BootSoundPaths.supportDirectory.path
            var commands: [String] = [
                "mkdir -p \(shellQuote(supportPath))",
                "chown \(shellQuote(currentUser)):staff \(shellQuote(supportPath))",
                "chmod 755 \(shellQuote(supportPath))",
                "rm -f \(shellQuote(supportPath))/boot_sound.* \(shellQuote(supportPath))/sound_*"
            ]

            for audio in stagedAudioPaths {
                let destSoundPath = BootSoundPaths.supportDirectory.appendingPathComponent(audio.destName).path
                commands.append("cp -f \(shellQuote(audio.source)) \(shellQuote(destSoundPath))")
                commands.append("chown \(shellQuote(currentUser)):staff \(shellQuote(destSoundPath))")
                commands.append("chmod 644 \(shellQuote(destSoundPath))")
            }

            commands.append(contentsOf: [
                "cp -f \(shellQuote(stagedConfigURL.path)) \(shellQuote(BootSoundPaths.configFileURL.path))",
                "chown \(shellQuote(currentUser)):staff \(shellQuote(BootSoundPaths.configFileURL.path))",
                "chmod 644 \(shellQuote(BootSoundPaths.configFileURL.path))",
                "mkdir -p /Library/PrivilegedHelperTools",
                "cp -f \(shellQuote(helperSourceURL.path)) \(shellQuote(BootSoundPaths.helperInstallPath))",
                "chown root:wheel \(shellQuote(BootSoundPaths.helperInstallPath))",
                "chmod 755 \(shellQuote(BootSoundPaths.helperInstallPath))",
                "cp -f \(shellQuote(stagedPlistURL.path)) \(shellQuote(BootSoundPaths.launchDaemonPlistPath))",
                "chown root:wheel \(shellQuote(BootSoundPaths.launchDaemonPlistPath))",
                "chmod 644 \(shellQuote(BootSoundPaths.launchDaemonPlistPath))",
                "plutil -lint \(shellQuote(BootSoundPaths.launchDaemonPlistPath)) >/dev/null",
                "launchctl bootout system/\(BootSoundPaths.daemonLabel) 2>/dev/null || true",
                "launchctl bootstrap system \(shellQuote(BootSoundPaths.launchDaemonPlistPath))"
            ])

            try runPrivilegedShell(commands.joined(separator: " && "))
            pendingSounds = []
            refresh()
            statusMessage = L10n.t(
                "부팅 사운드 LaunchDaemon 등록이 완료되었습니다.",
                "Boot sound LaunchDaemon has been registered.",
                lang: language
            )
        } catch {
            errorMessage = formatError(error)
        }
    }

    func uninstallDaemon() {
        errorMessage = nil
        statusMessage = nil

        let commands = [
            "launchctl bootout system/\(BootSoundPaths.daemonLabel) 2>/dev/null || true",
            "rm -f \(shellQuote(BootSoundPaths.launchDaemonPlistPath))",
            "rm -f \(shellQuote(BootSoundPaths.helperInstallPath))",
            "rm -rf \(shellQuote(BootSoundPaths.supportDirectory.path))"
        ]

        do {
            try runPrivilegedShell(commands.joined(separator: " && "))
            pendingSounds = []
            config = BootSoundConfig()
            refresh()
            statusMessage = L10n.t(
                "부팅 사운드 LaunchDaemon이 완전히 제거되었습니다.",
                "Boot sound LaunchDaemon has been uninstalled.",
                lang: language
            )
        } catch {
            errorMessage = formatError(error)
        }
    }

    func testBackgroundPlayerOnce() {
        errorMessage = nil
        statusMessage = nil

        guard FileManager.default.isExecutableFile(atPath: BootSoundPaths.helperInstallPath) else {
            errorMessage = L10n.t(
                "먼저 '부팅 사운드 등록'을 실행해 주세요.",
                "Please register the boot sound first.",
                lang: language
            )
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: BootSoundPaths.helperInstallPath)

        do {
            try process.run()
            statusMessage = L10n.t(
                "백그라운드 플레이어를 실행했습니다. 재생이 끝나면 자동 종료됩니다.",
                "Background player started. It will exit automatically when finished.",
                lang: language
            )
        } catch {
            errorMessage = L10n.t(
                "백그라운드 플레이어 실행 실패: \(error.localizedDescription)",
                "Failed to run background player: \(error.localizedDescription)",
                lang: language
            )
        }
    }

    private func formatError(_ error: Error) -> String {
        if let daemonError = error as? DaemonError {
            return daemonError.localizedMessage(in: language)
        }
        return error.localizedDescription
    }

    private func saveConfigIfWritable() {
        guard FileManager.default.isWritableFile(atPath: BootSoundPaths.supportDirectory.path) else {
            return
        }
        do {
            try config.save()
        } catch {
            errorMessage = L10n.t(
                "설정 저장 실패: \(error.localizedDescription)",
                "Failed to save config: \(error.localizedDescription)",
                lang: language
            )
        }
    }

    private func storedFileName(for id: UUID, sourceURL: URL) -> String {
        let ext = sourceURL.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        return ext.isEmpty ? "sound_\(id.uuidString).audio" : "sound_\(id.uuidString).\(ext)"
    }

    private func locateHelperBinary() -> URL? {
        let bundledHelper = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/MacBootSoundPlayer")
        if FileManager.default.isExecutableFile(atPath: bundledHelper.path) {
            return bundledHelper
        }

        if let siblingHelper = Bundle.main.executableURL?
            .deletingLastPathComponent()
            .appendingPathComponent("MacBootSoundPlayer"),
           FileManager.default.isExecutableFile(atPath: siblingHelper.path) {
            return siblingHelper
        }

        return nil
    }

    private func buildLaunchDaemonPlist() -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(BootSoundPaths.daemonLabel)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(BootSoundPaths.helperInstallPath)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <false/>
            <key>StandardOutPath</key>
            <string>\(BootSoundPaths.logFilePath)</string>
            <key>StandardErrorPath</key>
            <string>\(BootSoundPaths.logFilePath)</string>
        </dict>
        </plist>
        """
    }

    private func runPrivilegedShell(_ command: String) throws {
        let escapedForAppleScript = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = "do shell script \"\(escapedForAppleScript)\" with administrator privileges"

        guard let script = NSAppleScript(source: source) else {
            throw DaemonError.scriptFailed("AppleScript 생성 실패")
        }

        var errorInfo: NSDictionary?
        script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let errorNumber = errorInfo[NSAppleScript.errorNumber] as? Int ?? 0
            if errorNumber == -128 {
                throw DaemonError.userCanceled
            }
            let message = errorInfo[NSAppleScript.errorMessage] as? String ?? "알 수 없는 오류 (\(errorNumber))"
            throw DaemonError.scriptFailed(message)
        }
    }

    private func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    nonisolated private static func runCommand(_ executablePath: String, arguments: [String]) -> (output: String, exitCode: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let text = String(data: data, encoding: .utf8) ?? ""
            return (text, process.terminationStatus)
        } catch {
            return ("", -1)
        }
    }
}
