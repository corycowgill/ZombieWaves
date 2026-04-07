// SettingsView.swift
// ProjectAshfall
//
// Game settings: audio, accessibility, graphics, haptics, save management, credits.

import SwiftUI

// MARK: - Graphics Quality

enum GraphicsQuality: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var gameState: GameStateManager
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var audio = AudioManager.shared

    // Accessibility
    @AppStorage("textSizeMultiplier") private var textSizeMultiplier: Double = 1.0
    @AppStorage("colorblindMode") private var colorblindMode: Bool = false
    @AppStorage("reducedShake") private var reducedShake: Bool = false
    @AppStorage("graphicsQuality") private var graphicsQualityRaw: String = GraphicsQuality.high.rawValue

    @State private var showDeleteConfirm = false
    @State private var slotToDelete: Int?
    @State private var showCredits = false

    private var graphicsQuality: Binding<GraphicsQuality> {
        Binding(
            get: { GraphicsQuality(rawValue: graphicsQualityRaw) ?? .high },
            set: { graphicsQualityRaw = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                audioSection
                accessibilitySection
                graphicsSection
                hapticsSection
                saveManagementSection
                creditsSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AshfallColors.background.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AshfallColors.accent)
                }
            }
        }
    }

    // MARK: - Audio

    private var audioSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "music.note")
                        .foregroundColor(AshfallColors.accent)
                    Text("Music Volume")
                        .font(AshfallFonts.body(14))
                        .foregroundColor(AshfallColors.textPrimary)
                    Spacer()
                    Text("\(Int(audio.musicVolume * 100))%")
                        .font(AshfallFonts.mono(12))
                        .foregroundColor(AshfallColors.textSecondary)
                }
                Slider(value: $audio.musicVolume, in: 0...1, step: 0.05)
                    .tint(AshfallColors.accent)
            }
            .listRowBackground(AshfallColors.surface)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(AshfallColors.accent)
                    Text("SFX Volume")
                        .font(AshfallFonts.body(14))
                        .foregroundColor(AshfallColors.textPrimary)
                    Spacer()
                    Text("\(Int(audio.sfxVolume * 100))%")
                        .font(AshfallFonts.mono(12))
                        .foregroundColor(AshfallColors.textSecondary)
                }
                Slider(value: $audio.sfxVolume, in: 0...1, step: 0.05)
                    .tint(AshfallColors.accent)
            }
            .listRowBackground(AshfallColors.surface)

            Toggle(isOn: $audio.isMusicMuted) {
                Label("Mute Music", systemImage: "speaker.slash.fill")
                    .font(AshfallFonts.body(14))
                    .foregroundColor(AshfallColors.textPrimary)
            }
            .tint(AshfallColors.accent)
            .listRowBackground(AshfallColors.surface)

            Toggle(isOn: $audio.isSFXMuted) {
                Label("Mute SFX", systemImage: "speaker.slash")
                    .font(AshfallFonts.body(14))
                    .foregroundColor(AshfallColors.textPrimary)
            }
            .tint(AshfallColors.accent)
            .listRowBackground(AshfallColors.surface)
        } header: {
            sectionHeader("Audio")
        }
    }

    // MARK: - Accessibility

    private var accessibilitySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "textformat.size")
                        .foregroundColor(AshfallColors.accent)
                    Text("Text Size")
                        .font(AshfallFonts.body(14))
                        .foregroundColor(AshfallColors.textPrimary)
                    Spacer()
                    Text("\(Int(textSizeMultiplier * 100))%")
                        .font(AshfallFonts.mono(12))
                        .foregroundColor(AshfallColors.textSecondary)
                }
                Slider(value: $textSizeMultiplier, in: 0.8...1.5, step: 0.1)
                    .tint(AshfallColors.accent)
            }
            .listRowBackground(AshfallColors.surface)

            Toggle(isOn: $colorblindMode) {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Colorblind Mode", systemImage: "eye")
                        .font(AshfallFonts.body(14))
                        .foregroundColor(AshfallColors.textPrimary)
                    Text("Adds patterns/icons to color-coded elements")
                        .font(AshfallFonts.caption(11))
                        .foregroundColor(AshfallColors.textSecondary)
                }
            }
            .tint(AshfallColors.accent)
            .listRowBackground(AshfallColors.surface)

            Toggle(isOn: $reducedShake) {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Reduced Screen Shake", systemImage: "waveform.path")
                        .font(AshfallFonts.body(14))
                        .foregroundColor(AshfallColors.textPrimary)
                    Text("Minimizes camera shake effects in combat")
                        .font(AshfallFonts.caption(11))
                        .foregroundColor(AshfallColors.textSecondary)
                }
            }
            .tint(AshfallColors.accent)
            .listRowBackground(AshfallColors.surface)
        } header: {
            sectionHeader("Accessibility")
        }
    }

    // MARK: - Graphics

    private var graphicsSection: some View {
        Section {
            Picker("Quality", selection: graphicsQuality) {
                ForEach(GraphicsQuality.allCases, id: \.self) { quality in
                    Text(quality.rawValue).tag(quality)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(AshfallColors.surface)

            HStack {
                Text("Current")
                    .font(AshfallFonts.body(14))
                    .foregroundColor(AshfallColors.textSecondary)
                Spacer()
                Text(graphicsQualityRaw)
                    .font(AshfallFonts.body(14))
                    .foregroundColor(AshfallColors.textPrimary)
            }
            .listRowBackground(AshfallColors.surface)
        } header: {
            sectionHeader("Graphics")
        }
    }

    // MARK: - Haptics

    private var hapticsSection: some View {
        Section {
            Toggle(isOn: $audio.hapticsEnabled) {
                Label("Haptic Feedback", systemImage: "hand.tap.fill")
                    .font(AshfallFonts.body(14))
                    .foregroundColor(AshfallColors.textPrimary)
            }
            .tint(AshfallColors.accent)
            .listRowBackground(AshfallColors.surface)
        } header: {
            sectionHeader("Haptics")
        }
    }

    // MARK: - Save Management

    private var saveManagementSection: some View {
        Section {
            let saves = SaveManager.shared.listSaves()

            if saves.isEmpty {
                Text("No save files found.")
                    .font(AshfallFonts.body(14))
                    .foregroundColor(AshfallColors.textSecondary)
                    .listRowBackground(AshfallColors.surface)
            } else {
                ForEach(saves) { save in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Slot \(save.id): \(save.playerName)")
                                .font(AshfallFonts.body(14))
                                .foregroundColor(AshfallColors.textPrimary)
                            Text(save.formattedDate)
                                .font(AshfallFonts.caption(11))
                                .foregroundColor(AshfallColors.textSecondary)
                        }

                        Spacer()

                        Button(role: .destructive) {
                            slotToDelete = save.id
                            showDeleteConfirm = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(AshfallColors.danger)
                        }
                    }
                    .listRowBackground(AshfallColors.surface)
                }
            }
        } header: {
            sectionHeader("Save Management")
        }
        .alert("Delete Save?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let slot = slotToDelete {
                    SaveManager.shared.deleteSave(slot: slot)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
    }

    // MARK: - Credits

    private var creditsSection: some View {
        Section {
            Button(action: { showCredits = true }) {
                HStack {
                    Label("Credits", systemImage: "info.circle.fill")
                        .font(AshfallFonts.body(14))
                        .foregroundColor(AshfallColors.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(AshfallColors.textSecondary)
                }
            }
            .listRowBackground(AshfallColors.surface)
        }
        .sheet(isPresented: $showCredits) {
            creditsSheet
        }
    }

    private var creditsSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("PROJECT ASHFALL")
                        .font(AshfallFonts.title(28))
                        .foregroundColor(AshfallColors.textPrimary)
                        .padding(.top, 20)

                    creditEntry("Game Design", "Ashfall Studio")
                    creditEntry("Programming", "Ashfall Studio")
                    creditEntry("Art Direction", "Ashfall Studio")
                    creditEntry("Sound Design", "Ashfall Studio")
                    creditEntry("Quality Assurance", "Ashfall Studio")

                    Divider().background(AshfallColors.surfaceLight)

                    Text("Built with SwiftUI + SpriteKit")
                        .font(AshfallFonts.caption())
                        .foregroundColor(AshfallColors.textSecondary)

                    Text("v0.1.0 alpha")
                        .font(AshfallFonts.caption(10))
                        .foregroundColor(AshfallColors.textSecondary.opacity(0.5))
                }
                .padding()
            }
            .background(AshfallColors.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showCredits = false }
                        .foregroundColor(AshfallColors.accent)
                }
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(AshfallFonts.caption(12))
            .foregroundColor(AshfallColors.accent)
            .tracking(1)
    }

    private func creditEntry(_ role: String, _ name: String) -> some View {
        VStack(spacing: 4) {
            Text(role)
                .font(AshfallFonts.caption())
                .foregroundColor(AshfallColors.textSecondary)
            Text(name)
                .font(AshfallFonts.heading(17))
                .foregroundColor(AshfallColors.textPrimary)
        }
    }
}
