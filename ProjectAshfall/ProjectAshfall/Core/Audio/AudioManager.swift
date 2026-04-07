// AudioManager.swift
// ProjectAshfall
//
// Centralized audio playback for background music, sound effects,
// and haptic feedback. Uses AVAudioPlayer for music with crossfade
// support and categorized SFX channels.

import AVFoundation
import UIKit
import Combine

// MARK: - SFX Category

enum SFXCategory: String {
    case combat
    case ui
    case ambient
}

// MARK: - Audio Manager

final class AudioManager: ObservableObject {
    static let shared = AudioManager()

    // MARK: Published Settings

    @Published var musicVolume: Float = 0.6 {
        didSet { currentMusicPlayer?.volume = musicVolume }
    }
    @Published var sfxVolume: Float = 0.8
    @Published var hapticsEnabled: Bool = true
    @Published var isMusicMuted: Bool = false {
        didSet {
            currentMusicPlayer?.volume = isMusicMuted ? 0 : musicVolume
        }
    }
    @Published var isSFXMuted: Bool = false

    // MARK: Private State

    private var currentMusicPlayer: AVAudioPlayer?
    private var crossfadePlayer: AVAudioPlayer?
    private var sfxPlayers: [String: AVAudioPlayer] = [:]
    private var ambientLoopPlayer: AVAudioPlayer?
    private var crossfadeTimer: Timer?
    private let crossfadeDuration: TimeInterval = 1.5

    // Haptic generators — reuse for performance
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    private let selectionFeedback = UISelectionFeedbackGenerator()

    private init() {
        configureAudioSession()
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .ambient,
                mode: .default,
                options: [.mixWithOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[AudioManager] Audio session setup failed: \(error)")
        }
    }

    // MARK: - Background Music

    func playBackgroundMusic(named name: String, fileExtension: String = "mp3") {
        guard let url = Bundle.main.url(forResource: name, withExtension: fileExtension) else {
            print("[AudioManager] Music file not found: \(name).\(fileExtension)")
            return
        }

        // If the same track is already playing, do nothing
        if currentMusicPlayer?.url == url, currentMusicPlayer?.isPlaying == true {
            return
        }

        // Crossfade from current track
        if let current = currentMusicPlayer, current.isPlaying {
            crossfadeTo(url: url)
        } else {
            startMusicPlayer(url: url)
        }
    }

    private func startMusicPlayer(url: URL) {
        do {
            currentMusicPlayer = try AVAudioPlayer(contentsOf: url)
            currentMusicPlayer?.numberOfLoops = -1
            currentMusicPlayer?.volume = isMusicMuted ? 0 : musicVolume
            currentMusicPlayer?.prepareToPlay()
            currentMusicPlayer?.play()
        } catch {
            print("[AudioManager] Failed to start music: \(error)")
        }
    }

    private func crossfadeTo(url: URL) {
        crossfadeTimer?.invalidate()

        do {
            crossfadePlayer = try AVAudioPlayer(contentsOf: url)
            crossfadePlayer?.numberOfLoops = -1
            crossfadePlayer?.volume = 0
            crossfadePlayer?.prepareToPlay()
            crossfadePlayer?.play()
        } catch {
            print("[AudioManager] Failed to create crossfade player: \(error)")
            return
        }

        let steps = 15
        let interval = crossfadeDuration / Double(steps)
        var step = 0
        let targetVolume = isMusicMuted ? Float(0) : musicVolume

        crossfadeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            step += 1
            let progress = Float(step) / Float(steps)

            self.currentMusicPlayer?.volume = targetVolume * (1.0 - progress)
            self.crossfadePlayer?.volume = targetVolume * progress

            if step >= steps {
                timer.invalidate()
                self.currentMusicPlayer?.stop()
                self.currentMusicPlayer = self.crossfadePlayer
                self.crossfadePlayer = nil
            }
        }
    }

    func stopMusic() {
        crossfadeTimer?.invalidate()
        currentMusicPlayer?.stop()
        crossfadePlayer?.stop()
        currentMusicPlayer = nil
        crossfadePlayer = nil
    }

    func pauseMusic() {
        currentMusicPlayer?.pause()
    }

    func resumeMusic() {
        currentMusicPlayer?.play()
    }

    // MARK: - Sound Effects

    func playSFX(named name: String, category: SFXCategory = .ui, fileExtension: String = "wav") {
        guard !isSFXMuted else { return }
        guard let url = Bundle.main.url(forResource: name, withExtension: fileExtension) else {
            print("[AudioManager] SFX not found: \(name).\(fileExtension)")
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = sfxVolume * volumeMultiplier(for: category)
            player.prepareToPlay()
            player.play()
            sfxPlayers[name] = player
        } catch {
            print("[AudioManager] SFX play failed: \(error)")
        }
    }

    private func volumeMultiplier(for category: SFXCategory) -> Float {
        switch category {
        case .combat:  return 1.0
        case .ui:      return 0.7
        case .ambient: return 0.5
        }
    }

    // MARK: - Ambient Loop

    func startAmbientLoop(named name: String, fileExtension: String = "mp3") {
        guard let url = Bundle.main.url(forResource: name, withExtension: fileExtension) else { return }

        do {
            ambientLoopPlayer = try AVAudioPlayer(contentsOf: url)
            ambientLoopPlayer?.numberOfLoops = -1
            ambientLoopPlayer?.volume = sfxVolume * 0.3
            ambientLoopPlayer?.play()
        } catch {
            print("[AudioManager] Ambient loop failed: \(error)")
        }
    }

    func stopAmbientLoop() {
        ambientLoopPlayer?.stop()
        ambientLoopPlayer = nil
    }

    // MARK: - Haptics

    func hapticLight() {
        guard hapticsEnabled else { return }
        lightImpact.impactOccurred()
    }

    func hapticMedium() {
        guard hapticsEnabled else { return }
        mediumImpact.impactOccurred()
    }

    func hapticHeavy() {
        guard hapticsEnabled else { return }
        heavyImpact.impactOccurred()
    }

    func hapticSuccess() {
        guard hapticsEnabled else { return }
        notificationFeedback.notificationOccurred(.success)
    }

    func hapticWarning() {
        guard hapticsEnabled else { return }
        notificationFeedback.notificationOccurred(.warning)
    }

    func hapticError() {
        guard hapticsEnabled else { return }
        notificationFeedback.notificationOccurred(.error)
    }

    func hapticSelection() {
        guard hapticsEnabled else { return }
        selectionFeedback.selectionChanged()
    }
}
