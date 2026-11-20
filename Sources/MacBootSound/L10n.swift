import Foundation
import Shared

@MainActor
final class LanguageSettings: ObservableObject {
    private static let storageKey = "MacBootSound.selectedLanguage"

    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey)
        }
    }

    init() {
        if let saved = UserDefaults.standard.string(forKey: Self.storageKey),
           let parsed = AppLanguage(rawValue: saved) {
            self.language = parsed
        } else {
            self.language = AppLanguage.defaultLanguage()
        }
    }
}

enum L10n {
    static func t(_ ko: String, _ en: String, lang: AppLanguage) -> String {
        lang == .korean ? ko : en
    }

    static func appSubtitle(_ lang: AppLanguage) -> String {
        t(
            "부팅 시 사운드를 재생하고 즉시 종료되는 LaunchDaemon 설정",
            "LaunchDaemon setup that plays a sound at boot and exits immediately",
            lang: lang
        )
    }

    static func statusInstalled(_ lang: AppLanguage) -> String {
        t("등록됨", "Installed", lang: lang)
    }

    static func statusNotInstalled(_ lang: AppLanguage) -> String {
        t("미등록", "Not Installed", lang: lang)
    }

    static func fileVaultOnBanner(_ lang: AppLanguage) -> String {
        t(
            "FileVault가 켜져 있습니다. 암호를 입력해 디스크 잠금을 해제한 뒤 macOS 부팅 시점에 사운드가 재생됩니다.",
            "FileVault is enabled. Your sound will play during macOS startup after unlocking the disk with your password.",
            lang: lang
        )
    }

    static func fileVaultOffBanner(_ lang: AppLanguage) -> String {
        t(
            "FileVault가 꺼져 있어 전원 인가 후 로그인 전 시동 완료 시점에 사운드가 재생됩니다.",
            "FileVault is disabled. Your sound will play at startup before user login.",
            lang: lang
        )
    }

    static func soundListTitle(count: Int, maxCount: Int, lang: AppLanguage) -> String {
        t("사운드 목록 (\(count)/\(maxCount))", "Sound List (\(count)/\(maxCount))", lang: lang)
    }

    static func addSoundButton(_ lang: AppLanguage) -> String {
        t("추가...", "Add...", lang: lang)
    }

    static func emptySoundList(_ maxCount: Int, lang: AppLanguage) -> String {
        t("사운드 파일을 최대 \(maxCount)개까지 추가할 수 있습니다.", "Add up to \(maxCount) audio files.", lang: lang)
    }

    static func playbackModeLabel(_ lang: AppLanguage) -> String {
        t("재생 방식", "Playback", lang: lang)
    }

    static func playbackModeSelected(_ lang: AppLanguage) -> String {
        t("선택한 사운드", "Selected", lang: lang)
    }

    static func playbackModeRandom(_ lang: AppLanguage) -> String {
        t("랜덤 재생", "Random", lang: lang)
    }

    static func openPanelTitle(_ lang: AppLanguage) -> String {
        t("부팅 시 재생할 사운드(음악) 추가", "Add Boot Sound Audio Files", lang: lang)
    }

    static func preview(_ lang: AppLanguage) -> String {
        t("미리듣기", "Preview", lang: lang)
    }

    static func stop(_ lang: AppLanguage) -> String {
        t("정지", "Stop", lang: lang)
    }

    static func enableBootSound(_ lang: AppLanguage) -> String {
        t("부팅 시 사운드 재생 활성화", "Enable boot sound playback", lang: lang)
    }

    static func volume(_ lang: AppLanguage) -> String {
        t("재생 음량", "Volume", lang: lang)
    }

    static func systemStartupSoundTitle(_ lang: AppLanguage) -> String {
        t("시스템 설정 · 시동 시 사운드 재생", "System Settings · Play sound on startup", lang: lang)
    }

    static func systemStartupSoundSubtitle(_ lang: AppLanguage) -> String {
        t("macOS 기본 시동음 (사운드 설정과 실시간 동기화)", "macOS built-in startup chime (synced with Sound settings)", lang: lang)
    }

    static func startupOverlapWarning(_ lang: AppLanguage) -> String {
        t(
            "기존 시스템 설정의 '시동 시 사운드 재생'이 켜져 있습니다. 부팅 시 소리가 겹치지 않도록 꺼 주세요.",
            "macOS 'Play sound on startup' is enabled. Turn it off so boot sounds don't overlap.",
            lang: lang
        )
    }

    static func turnOff(_ lang: AppLanguage) -> String {
        t("끄기", "Turn Off", lang: lang)
    }

    static func systemStartupOffCaption(_ lang: AppLanguage) -> String {
        t("기존 macOS '시동 시 사운드 재생'이 꺼져 있습니다.", "macOS built-in 'Play sound on startup' is off.", lang: lang)
    }

    static func systemStartupOnCaption(_ lang: AppLanguage) -> String {
        t("기존 macOS '시동 시 사운드 재생'이 켜져 있습니다.", "macOS built-in 'Play sound on startup' is on.", lang: lang)
    }

    static func registerDaemon(_ lang: AppLanguage) -> String {
        t("부팅 사운드 등록", "Register Boot Sound", lang: lang)
    }

    static func reregisterDaemon(_ lang: AppLanguage) -> String {
        t("데몬 재등록", "Re-register Daemon", lang: lang)
    }

    static func testBackground(_ lang: AppLanguage) -> String {
        t("백그라운드 실행 테스트", "Test Background Player", lang: lang)
    }

    static func unregister(_ lang: AppLanguage) -> String {
        t("등록 해제", "Uninstall", lang: lang)
    }

    static func languageLabel(_ lang: AppLanguage) -> String {
        t("언어", "Language", lang: lang)
    }
}
