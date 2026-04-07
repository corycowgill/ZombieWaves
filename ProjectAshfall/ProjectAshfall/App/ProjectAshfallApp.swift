// ProjectAshfallApp.swift
// ProjectAshfall
//
// SwiftUI App entry point. Routes between main menu and active game views
// based on the current game phase.

import SwiftUI

@main
struct ProjectAshfallApp: App {
    @StateObject private var gameState = GameStateManager()
    @StateObject private var audioManager = AudioManager.shared

    var body: some Scene {
        WindowGroup {
            ZStack {
                AshfallColors.background.ignoresSafeArea()

                switch gameState.currentPhase {
                case .mainMenu:
                    MainMenuView()
                        .environmentObject(gameState)
                        .transition(.opacity)

                case .baseView:
                    BaseView()
                        .environmentObject(gameState)
                        .transition(.move(edge: .trailing))

                case .combat:
                    CombatView()
                        .environmentObject(gameState)
                        .transition(.opacity)

                case .worldMap:
                    WorldMapView()
                        .environmentObject(gameState)
                        .transition(.move(edge: .trailing))

                case .playing, .paused:
                    BaseView()
                        .environmentObject(gameState)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: gameState.currentPhase)
            .preferredColorScheme(.dark)
            .onAppear {
                audioManager.playBackgroundMusic(named: "menu_ambient")
            }
        }
    }
}
