// MainMenuView.swift
// ProjectAshfall
//
// Post-apocalyptic main menu with animated ash particles, save slot
// selection, and atmospheric styling.

import SwiftUI
import SpriteKit

// MARK: - Main Menu View

struct MainMenuView: View {
    @EnvironmentObject var gameState: GameStateManager

    @State private var showNewGame = false
    @State private var showLoadGame = false
    @State private var showSettings = false
    @State private var playerNameEntry = ""
    @State private var logoOpacity: Double = 0
    @State private var buttonsOffset: CGFloat = 40
    @State private var particleScene = AshParticleScene(size: CGSize(width: 400, height: 800))

    private var hasSaveData: Bool {
        !SaveManager.shared.listSaves().isEmpty
    }

    var body: some View {
        ZStack {
            // Animated particle background
            SpriteView(scene: particleScene, options: [.allowsTransparency])
                .ignoresSafeArea()
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.06, green: 0.05, blue: 0.04),
                            Color(red: 0.12, green: 0.08, blue: 0.05),
                            Color(red: 0.08, green: 0.06, blue: 0.04)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            VStack(spacing: 0) {
                Spacer()

                // Game logo
                VStack(spacing: 8) {
                    Text("PROJECT")
                        .font(AshfallFonts.caption(14))
                        .tracking(8)
                        .foregroundColor(AshfallColors.textSecondary)

                    Text("ASHFALL")
                        .font(.system(size: 56, weight: .black, design: .serif))
                        .foregroundColor(AshfallColors.textPrimary)
                        .shadow(color: AshfallColors.ember.opacity(0.6), radius: 12, y: 2)

                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, AshfallColors.ember, .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 200, height: 2)
                        .padding(.top, 4)

                    Text("Survive. Rebuild. Reclaim.")
                        .font(AshfallFonts.caption(13))
                        .foregroundColor(AshfallColors.textSecondary)
                        .padding(.top, 6)
                }
                .opacity(logoOpacity)

                Spacer()
                Spacer()

                // Menu buttons
                VStack(spacing: 16) {
                    Button(action: { showNewGame = true }) {
                        menuButtonLabel("New Game", icon: "plus.circle.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    if hasSaveData {
                        Button(action: { showLoadGame = true }) {
                            menuButtonLabel("Continue", icon: "play.circle.fill")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }

                    Button(action: { showSettings = true }) {
                        menuButtonLabel("Settings", icon: "gearshape.fill")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .offset(y: buttonsOffset)
                .opacity(logoOpacity)

                Spacer()

                // Version
                Text("v0.1.0 alpha")
                    .font(AshfallFonts.caption(10))
                    .foregroundColor(AshfallColors.textSecondary.opacity(0.4))
                    .padding(.bottom, 16)
            }
            .padding(.horizontal, AshfallTheme.screenPadding)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) {
                logoOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                buttonsOffset = 0
            }
        }

        // MARK: - Sheets

        .sheet(isPresented: $showNewGame) {
            NewGameSheet(playerName: $playerNameEntry) {
                let name = playerNameEntry.trimmingCharacters(in: .whitespacesAndNewlines)
                gameState.startNewGame(name: name.isEmpty ? "Commander" : name)
                showNewGame = false
            }
            .presentationDetents([.medium])
        }

        .sheet(isPresented: $showLoadGame) {
            SaveSlotSelectionView { slot in
                if gameState.load(from: slot) {
                    gameState.continueGame()
                    showLoadGame = false
                }
            }
            .presentationDetents([.large])
        }

        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(gameState)
        }
    }

    // MARK: - Helpers

    private func menuButtonLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18))
            Text(title)
                .frame(width: 120, alignment: .leading)
        }
    }
}

// MARK: - New Game Sheet

private struct NewGameSheet: View {
    @Binding var playerName: String
    var onStart: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text("Begin Your Story")
                        .font(AshfallFonts.heading(24))
                        .foregroundColor(AshfallColors.textPrimary)

                    Text("The ash has settled. A new commander rises.")
                        .font(AshfallFonts.body())
                        .foregroundColor(AshfallColors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Commander Name")
                        .font(AshfallFonts.caption())
                        .foregroundColor(AshfallColors.textSecondary)

                    TextField("Enter name...", text: $playerName)
                        .font(AshfallFonts.body())
                        .foregroundColor(AshfallColors.textPrimary)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(AshfallColors.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(AshfallColors.ember.opacity(0.3), lineWidth: 1)
                        )
                        .autocorrectionDisabled()
                }
                .padding(.horizontal)

                Button(action: onStart) {
                    HStack {
                        Image(systemName: "flame.fill")
                        Text("Start Campaign")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())

                Spacer()
            }
            .padding(.top, 32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AshfallColors.background.ignoresSafeArea())
        }
    }
}

// MARK: - Save Slot Selection

struct SaveSlotSelectionView: View {
    var onSelect: (Int) -> Void

    @State private var saves: [SaveSlot] = []
    @State private var slotToDelete: SaveSlot?

    var body: some View {
        NavigationStack {
            List {
                ForEach(0..<SaveManager.maxSlots, id: \.self) { slot in
                    if let save = saves.first(where: { $0.id == slot }) {
                        occupiedSlotRow(save)
                            .contentShape(Rectangle())
                            .onTapGesture { onSelect(slot) }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    slotToDelete = save
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    } else {
                        emptySlotRow(slot)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AshfallColors.background.ignoresSafeArea())
            .navigationTitle("Load Game")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { refreshSaves() }
            .alert("Delete Save?", isPresented: Binding(
                get: { slotToDelete != nil },
                set: { if !$0 { slotToDelete = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    if let s = slotToDelete {
                        SaveManager.shared.deleteSave(slot: s.id)
                        refreshSaves()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }

    private func occupiedSlotRow(_ save: SaveSlot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(save.playerName)
                    .font(AshfallFonts.heading(17))
                    .foregroundColor(AshfallColors.textPrimary)
                Spacer()
                Text("Slot \(save.id)")
                    .font(AshfallFonts.caption())
                    .foregroundColor(AshfallColors.textSecondary)
            }
            HStack(spacing: 16) {
                Label("Ch. \(save.chapter)", systemImage: "book.fill")
                Label("Day \(save.daysSurvived)", systemImage: "sun.max.fill")
                Label("Lv.\(save.commanderLevel)", systemImage: "star.fill")
                Spacer()
                Text(save.formattedPlaytime)
            }
            .font(AshfallFonts.caption())
            .foregroundColor(AshfallColors.textSecondary)

            Text(save.formattedDate)
                .font(AshfallFonts.caption(10))
                .foregroundColor(AshfallColors.textSecondary.opacity(0.6))
        }
        .padding(.vertical, 6)
        .listRowBackground(AshfallColors.surface)
    }

    private func emptySlotRow(_ slot: Int) -> some View {
        HStack {
            Text("Slot \(slot) - Empty")
                .font(AshfallFonts.body())
                .foregroundColor(AshfallColors.textSecondary.opacity(0.4))
            Spacer()
        }
        .padding(.vertical, 10)
        .listRowBackground(AshfallColors.surface.opacity(0.5))
    }

    private func refreshSaves() {
        saves = SaveManager.shared.listSaves()
    }
}

// MARK: - Ash Particle Scene

final class AshParticleScene: SKScene {
    override func didMove(to view: SKView) {
        backgroundColor = .clear
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        scaleMode = .resizeFill

        addAshParticles()
        addEmberParticles()
    }

    private func addAshParticles() {
        let emitter = SKEmitterNode()
        emitter.particleBirthRate = 8
        emitter.particleLifetime = 10
        emitter.particleLifetimeRange = 5
        emitter.particlePositionRange = CGVector(dx: size.width * 2, dy: 0)
        emitter.position = CGPoint(x: 0, y: size.height / 2)
        emitter.particleSpeed = 15
        emitter.particleSpeedRange = 10
        emitter.emissionAngle = -.pi / 2
        emitter.emissionAngleRange = 0.4
        emitter.particleAlpha = 0.3
        emitter.particleAlphaRange = 0.2
        emitter.particleAlphaSpeed = -0.02
        emitter.particleScale = 0.04
        emitter.particleScaleRange = 0.03
        emitter.particleColor = .gray
        emitter.particleColorBlendFactor = 1.0
        emitter.particleBlendMode = .alpha
        // Use a small white texture as a stand-in — real asset would be better
        emitter.particleTexture = SKTexture(imageNamed: "spark")
        addChild(emitter)
    }

    private func addEmberParticles() {
        let emitter = SKEmitterNode()
        emitter.particleBirthRate = 2
        emitter.particleLifetime = 6
        emitter.particleLifetimeRange = 3
        emitter.particlePositionRange = CGVector(dx: size.width * 2, dy: size.height)
        emitter.position = CGPoint(x: 0, y: -size.height / 3)
        emitter.particleSpeed = 20
        emitter.particleSpeedRange = 10
        emitter.emissionAngle = .pi / 2
        emitter.emissionAngleRange = 0.6
        emitter.particleAlpha = 0.6
        emitter.particleAlphaRange = 0.3
        emitter.particleAlphaSpeed = -0.08
        emitter.particleScale = 0.02
        emitter.particleScaleRange = 0.015
        emitter.particleColor = UIColor(red: 0.95, green: 0.45, blue: 0.1, alpha: 1)
        emitter.particleColorBlendFactor = 1.0
        emitter.particleBlendMode = .add
        emitter.particleTexture = SKTexture(imageNamed: "spark")
        addChild(emitter)
    }
}
