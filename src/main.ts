import Phaser from 'phaser';
import BootScene from './scenes/BootScene';
import MainMenuScene from './scenes/MainMenuScene';
import BaseScene from './scenes/BaseScene';
import CombatScene from './scenes/CombatScene';
import WorldMapScene from './scenes/WorldMapScene';
import HeroScene from './scenes/HeroScene';
import { GameStateManager } from './systems/GameStateManager';
import { UIManager } from './ui/UIManager';

// --- Phaser Game Configuration ---
const config: Phaser.Types.Core.GameConfig = {
  type: Phaser.AUTO,
  parent: 'game-container',
  width: 390,
  height: 844,
  backgroundColor: '#0a0a1a',
  scale: {
    mode: Phaser.Scale.FIT,
    autoCenter: Phaser.Scale.CENTER_BOTH,
  },
  physics: {
    default: 'arcade',
    arcade: {
      debug: false,
    },
  },
  scene: [BootScene, MainMenuScene, BaseScene, CombatScene, WorldMapScene, HeroScene],
  input: {
    activePointers: 3, // Support multi-touch
  },
  render: {
    pixelArt: false,
    antialias: true,
  },
};

// --- Initialize Game ---
window.addEventListener('DOMContentLoaded', () => {
  const game = new Phaser.Game(config);

  // Create the central game state manager
  const gameState = new GameStateManager();

  // Create the UI manager that bridges HTML UI ↔ Phaser scenes
  const uiManager = new UIManager(game, gameState);

  // Store references globally for scene access
  (game as any).gameState = gameState;
  (game as any).uiManager = uiManager;

  // Initialize UI event listeners
  uiManager.init();

  // Handle visibility change (auto-save when app goes to background)
  document.addEventListener('visibilitychange', () => {
    if (document.hidden && gameState.isGameActive()) {
      gameState.autoSave();
    }
  });

  // Handle resize
  window.addEventListener('resize', () => {
    game.scale.resize(window.innerWidth, window.innerHeight);
  });
});
