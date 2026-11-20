import AVFoundation
import Foundation
import Shared

@MainActor
final class AudioPreviewer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isPlaying = false
    @Published private(set) var playingItemID: UUID?
    @Published var errorMessage: String?

    var language: AppLanguage = AppLanguage.defaultLanguage()
    private var player: AVAudioPlayer?

    func togglePlayback(itemID: UUID, url: URL, volume: Float) {
        if isPlaying && playingItemID == itemID {
            stop()
            return
        }
        play(itemID: itemID, url: url, volume: volume)
    }

    func play(itemID: UUID, url: URL, volume: Float) {
        stop()
        errorMessage = nil

        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.delegate = self
            newPlayer.volume = min(max(volume, 0.0), 1.0)
            guard newPlayer.prepareToPlay(), newPlayer.play() else {
                errorMessage = L10n.t("오디오를 재생할 수 없습니다.", "Unable to play audio.", lang: language)
                return
            }
            player = newPlayer
            playingItemID = itemID
            isPlaying = true
        } catch {
            errorMessage = L10n.t(
                "오디오 열기 실패: \(error.localizedDescription)",
                "Failed to open audio: \(error.localizedDescription)",
                lang: language
            )
        }
    }

    func updateVolume(_ volume: Float) {
        player?.volume = min(max(volume, 0.0), 1.0)
    }

    func stop() {
        player?.stop()
        player = nil
        playingItemID = nil
        isPlaying = false
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.playingItemID = nil
            self.player = nil
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            self.isPlaying = false
            self.playingItemID = nil
            self.player = nil
            let detail = error?.localizedDescription ?? L10n.t("알 수 없는 오류", "unknown error", lang: self.language)
            self.errorMessage = L10n.t("오디오 디코딩 오류: \(detail)", "Audio decode error: \(detail)", lang: self.language)
        }
    }
}
