import AppKit
import Shared
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var daemon = DaemonManager()
    @StateObject private var previewer = AudioPreviewer()
    @StateObject private var languageSettings = LanguageSettings()

    private var lang: AppLanguage { languageSettings.language }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            fileVaultTopBanner
            headerSection
            Divider()
            soundSelectionSection
            optionsSection
            Divider()
            systemStartupSoundSection
            Divider()
            actionSection
            feedbackSection
            Divider()
            languageFooter
        }
        .padding(22)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            syncLanguage()
        }
        .onChange(of: languageSettings.language) { _ in
            syncLanguage()
            daemon.statusMessage = nil
            daemon.errorMessage = nil
            previewer.errorMessage = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            daemon.refresh()
        }
    }

    private func syncLanguage() {
        daemon.language = languageSettings.language
        previewer.language = languageSettings.language
    }

    private var fileVaultTopBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: daemon.isFileVaultEnabled ? "lock.shield.fill" : "checkmark.shield.fill")
                .foregroundStyle(daemon.isFileVaultEnabled ? .blue : .green)
                .font(.system(size: 14))
                .padding(.top, 1)

            Text(
                daemon.isFileVaultEnabled
                    ? L10n.fileVaultOnBanner(lang)
                    : L10n.fileVaultOffBanner(lang)
            )
            .font(.caption)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            (daemon.isFileVaultEnabled ? Color.blue : Color.green).opacity(0.10),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke((daemon.isFileVaultEnabled ? Color.blue : Color.green).opacity(0.28), lineWidth: 1)
        )
    }

    private var headerSection: some View {
        HStack(alignment: .center, spacing: 12) {
            appHeaderIcon

            VStack(alignment: .leading, spacing: 3) {
                Text("MacBootSound")
                    .font(.headline)
                Text(L10n.appSubtitle(lang))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            statusBadge
        }
    }

    @ViewBuilder
    private var appHeaderIcon: some View {
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let nsImage = NSImage(contentsOf: iconURL) {
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 44, height: 44)
        } else {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(
                    Color(red: 0.07, green: 0.07, blue: 0.09),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
        }
    }

    private var statusBadge: some View {
        Text(daemon.isInstalled ? L10n.statusInstalled(lang) : L10n.statusNotInstalled(lang))
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                daemon.isInstalled ? Color.green.opacity(0.16) : Color.secondary.opacity(0.14),
                in: Capsule()
            )
            .foregroundStyle(daemon.isInstalled ? .green : .secondary)
    }

    private var soundSelectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(
                    L10n.soundListTitle(
                        count: daemon.soundItems.count,
                        maxCount: BootSoundConfig.maxSounds,
                        lang: lang
                    )
                )
                .font(.subheadline.weight(.medium))

                Spacer()

                Button {
                    addSoundFiles()
                } label: {
                    Label(L10n.addSoundButton(lang), systemImage: "plus")
                }
                .controlSize(.small)
                .disabled(!daemon.canAddMoreSounds)
            }

            if daemon.soundItems.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "music.note.list")
                        .foregroundStyle(.secondary)
                    Text(L10n.emptySoundList(BootSoundConfig.maxSounds, lang: lang))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(daemon.soundItems.enumerated()), id: \.element.id) { index, item in
                        soundRow(item)
                        if index < daemon.soundItems.count - 1 {
                            Divider()
                        }
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
            }

            HStack {
                Text(L10n.playbackModeLabel(lang))
                    .font(.subheadline)
                Spacer()
                Picker(
                    "",
                    selection: Binding(
                        get: { daemon.config.playbackMode },
                        set: { daemon.updatePlaybackMode($0) }
                    )
                ) {
                    Text(L10n.playbackModeSelected(lang)).tag(PlaybackMode.selected)
                    Text(L10n.playbackModeRandom(lang)).tag(PlaybackMode.random)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 210)
            }
        }
    }

    private func soundRow(_ item: SoundListItem) -> some View {
        let isSelected = daemon.config.selectedSoundID == item.id
        let isThisPlaying = previewer.isPlaying && previewer.playingItemID == item.id

        return HStack(spacing: 10) {
            Button {
                daemon.selectSound(id: item.id)
            } label: {
                HStack(spacing: 8) {
                    Image(
                        systemName: daemon.config.playbackMode == .random
                            ? "shuffle"
                            : (isSelected ? "largecircle.fill.circle" : "circle")
                    )
                    .foregroundStyle(
                        daemon.config.playbackMode == .random
                            ? Color.secondary
                            : (isSelected ? Color.accentColor : Color.secondary)
                    )
                    .font(.system(size: 13))

                    Text(item.displayName)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                previewer.togglePlayback(itemID: item.id, url: item.previewURL, volume: daemon.config.volume)
            } label: {
                Image(systemName: isThisPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: 11))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.borderless)
            .help(isThisPlaying ? L10n.stop(lang) : L10n.preview(lang))

            Button {
                if isThisPlaying {
                    previewer.stop()
                }
                daemon.removeSound(id: item.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(
                L10n.enableBootSound(lang),
                isOn: Binding(
                    get: { daemon.config.enabled },
                    set: { daemon.updateEnabled($0) }
                )
            )

            HStack(spacing: 12) {
                Text(L10n.volume(lang))
                    .font(.subheadline)
                    .frame(width: 68, alignment: .leading)

                Slider(
                    value: Binding(
                        get: { Double(daemon.config.volume) },
                        set: { newValue in
                            let vol = Float(newValue)
                            daemon.updateVolume(vol)
                            previewer.updateVolume(vol)
                        }
                    ),
                    in: 0.0...1.0
                )

                Text("\(Int((daemon.config.volume * 100).rounded()))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 38, alignment: .trailing)
            }
        }
    }

    private var systemStartupSoundSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.systemStartupSoundTitle(lang))
                        .font(.subheadline.weight(.medium))
                    Text(L10n.systemStartupSoundSubtitle(lang))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle(
                    "",
                    isOn: Binding(
                        get: { daemon.isSystemStartupSoundEnabled },
                        set: { daemon.setSystemStartupSoundEnabled($0) }
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
            }

            if daemon.isFileVaultEnabled && daemon.isSystemStartupSoundEnabled {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(L10n.startupOverlapWarning(lang))
                        .font(.caption)
                        .foregroundStyle(.primary)
                    Spacer()
                    Button(L10n.turnOff(lang)) {
                        daemon.setSystemStartupSoundEnabled(false)
                    }
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                .padding(10)
                .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.orange.opacity(0.35), lineWidth: 1)
                )
            } else {
                Label(
                    daemon.isSystemStartupSoundEnabled
                        ? L10n.systemStartupOnCaption(lang)
                        : L10n.systemStartupOffCaption(lang),
                    systemImage: daemon.isSystemStartupSoundEnabled ? "speaker.wave.2" : "checkmark.circle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var actionSection: some View {
        HStack(spacing: 10) {
            Button(daemon.isInstalled ? L10n.reregisterDaemon(lang) : L10n.registerDaemon(lang)) {
                previewer.stop()
                daemon.installOrUpdateDaemon()
            }
            .buttonStyle(.borderedProminent)
            .disabled(daemon.soundItems.isEmpty && !daemon.isInstalled)

            if daemon.isInstalled {
                Button(L10n.testBackground(lang)) {
                    previewer.stop()
                    daemon.testBackgroundPlayerOnce()
                }

                Spacer()

                Button(L10n.unregister(lang), role: .destructive) {
                    previewer.stop()
                    daemon.uninstallDaemon()
                }
            } else {
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var feedbackSection: some View {
        if let error = daemon.errorMessage ?? previewer.errorMessage {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
        } else if let status = daemon.statusMessage {
            Label(status, systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        }
    }

    private var languageFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.languageLabel(lang))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Picker("", selection: $languageSettings.language) {
                    Text(AppLanguage.english.displayName).tag(AppLanguage.english)
                    Text(AppLanguage.korean.displayName).tag(AppLanguage.korean)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 170)
            }

            HStack(spacing: 4) {
                Text("By RedCat")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("·")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Link("https://ioerror.tistory.com", destination: URL(string: "https://ioerror.tistory.com")!)
                    .font(.caption2)
            }
        }
    }

    private func addSoundFiles() {
        let panel = NSOpenPanel()
        panel.title = L10n.openPanelTitle(lang)
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.audio]

        if panel.runModal() == .OK, !panel.urls.isEmpty {
            previewer.stop()
            daemon.addSounds(from: panel.urls)
        }
    }
}
