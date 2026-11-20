import Foundation

/// Pure parsers for macOS NVRAM startup chime state and FileVault status.
public enum SystemStateParser {
    /// Parses `nvram StartupMute` output.
    /// Per macOS Sound settings semantics, startup sound is enabled unless `StartupMute` exists and is non-zero (`%01`).
    public static func isSystemStartupSoundEnabled(nvramOutput: String, exitCode: Int32) -> Bool {
        guard exitCode == 0 else {
            return true
        }

        let trimmed = nvramOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return true
        }

        let parts = trimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        guard let value = parts.last else {
            return true
        }

        if value == "%00" || value == "0" {
            return true
        }
        return false
    }

    /// Parses `fdesetup status` output.
    public static func isFileVaultEnabled(fdesetupOutput: String) -> Bool {
        fdesetupOutput.localizedCaseInsensitiveContains("FileVault is On")
    }
}
