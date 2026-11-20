import Foundation
import Shared

private func log(_ message: String) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    fputs("[\(timestamp)] [MacBootSoundPlayer] \(message)\n", stderr)
}

private func runAfplay(soundURL: URL, volume: Float) -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/afplay")
    process.arguments = ["-v", String(format: "%.3f", volume), soundURL.path]

    do {
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    } catch {
        log("Failed to launch afplay: \(error.localizedDescription)")
        return -1
    }
}

private func playBootSound() -> Int32 {
    guard let config = BootSoundConfig.load() else {
        log("No config found at \(BootSoundPaths.configFileURL.path). Exiting.")
        return 0
    }

    guard config.enabled else {
        log("Boot sound is disabled in config. Exiting.")
        return 0
    }

    guard let soundURL = config.resolvedSoundURL() else {
        log("Configured sound file is missing or invalid. Exiting.")
        return 0
    }

    let maxAttempts = 10
    for attempt in 1...maxAttempts {
        let status = runAfplay(soundURL: soundURL, volume: config.volume)
        if status == 0 {
            log("Played \(soundURL.lastPathComponent) via afplay. Exiting.")
            return 0
        }
        log("afplay exited with status \(status) on attempt \(attempt).")
        if attempt < maxAttempts {
            Thread.sleep(forTimeInterval: 0.3)
        }
    }

    log("Failed to play \(soundURL.lastPathComponent) after \(maxAttempts) attempts.")
    return 1
}

exit(playBootSound())
