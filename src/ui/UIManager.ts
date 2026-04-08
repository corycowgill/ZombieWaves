import Phaser from 'phaser';
import { GameStateManager, GamePhase } from '../systems/GameStateManager';
import { ResourceType } from '../models/Resource';

/**
 * UIManager bridges the HTML/CSS overlay UI with the Phaser game scenes.
 * It handles all DOM events and communicates with scenes via the game event bus.
 */
export class UIManager {
  private game: Phaser.Game;
  private gameState: GameStateManager;
  private resourceUpdateInterval: number = 0;

  // DOM element refs
  private mainMenu!: HTMLElement;
  private hudOverlay!: HTMLElement;
  private buildingPanel!: HTMLElement;
  private heroPanel!: HTMLElement;
  private missionBriefing!: HTMLElement;
  private dialogueOverlay!: HTMLElement;
  private settingsPanel!: HTMLElement;

  constructor(game: Phaser.Game, gameState: GameStateManager) {
    this.game = game;
    this.gameState = gameState;
  }

  /** Initialize all UI event listeners */
  public init(): void {
    this.cacheElements();
    this.setupMainMenu();
    this.setupNavBar();
    this.setupBuildingPanel();
    this.setupHeroPanel();
    this.setupSettings();
    this.setupDialogue();
    this.setupGameStateListeners();
    this.setupTutorialBridge();
  }

  private cacheElements(): void {
    this.mainMenu = document.getElementById('main-menu')!;
    this.hudOverlay = document.getElementById('hud-overlay')!;
    this.buildingPanel = document.getElementById('building-panel')!;
    this.heroPanel = document.getElementById('hero-panel')!;
    this.missionBriefing = document.getElementById('mission-briefing')!;
    this.dialogueOverlay = document.getElementById('dialogue-overlay')!;
    this.settingsPanel = document.getElementById('settings-panel')!;
  }

  // --- Main Menu ---

  private setupMainMenu(): void {
    const btnNew = document.getElementById('btn-new-game')!;
    const btnContinue = document.getElementById('btn-continue')!;
    const btnSettings = document.getElementById('btn-settings')!;

    // Enable continue if save exists
    if (this.gameState.hasSaveData()) {
      btnContinue.removeAttribute('disabled');
    }

    btnNew.addEventListener('click', () => {
      const name = prompt('Enter your Commander name:') || 'Commander';
      this.gameState.newGame(name);
    });

    btnContinue.addEventListener('click', () => {
      if (this.gameState.loadGame(0)) {
        // Game loaded successfully
      }
    });

    btnSettings.addEventListener('click', () => {
      this.showPanel(this.settingsPanel);
    });
  }

  // --- Navigation Bar ---

  private setupNavBar(): void {
    const navBtns = document.querySelectorAll('.nav-btn');
    navBtns.forEach(btn => {
      btn.addEventListener('click', () => {
        const sceneName = (btn as HTMLElement).dataset.scene;
        if (!sceneName) return;

        // Update active state
        navBtns.forEach(b => b.classList.remove('active'));
        btn.classList.add('active');

        // Switch scene
        const sceneMap: Record<string, string> = {
          base: 'BaseScene',
          heroes: 'HeroScene',
          world: 'WorldMapScene',
          squad: 'BaseScene', // Squad builder opens as overlay on base
        };

        const targetScene = sceneMap[sceneName];
        if (targetScene) {
          this.game.scene.getScenes(true).forEach(s => {
            if (s.scene.key !== 'BootScene') {
              this.game.scene.stop(s.scene.key);
            }
          });
          this.game.scene.start(targetScene);
          this.gameState.setPhase(sceneName as GamePhase);
        }
      });
    });
  }

  // --- Building Panel ---

  private setupBuildingPanel(): void {
    document.getElementById('close-building-panel')!.addEventListener('click', () => {
      this.hidePanel(this.buildingPanel);
    });

    document.getElementById('btn-upgrade-building')!.addEventListener('click', () => {
      this.game.events.emit('upgradeSelectedBuilding');
    });

    // Listen for building selection from Phaser scene
    this.game.events.on('buildingSelected', (building: any) => {
      this.showBuildingInfo(building);
    });
  }

  public showBuildingInfo(building: any): void {
    document.getElementById('building-name')!.textContent = building.type;
    document.getElementById('building-level')!.innerHTML =
      `<span class="stat-label">Level</span><span class="stat-value">${building.level} / 10</span>`;
    document.getElementById('building-production')!.innerHTML =
      `<span class="stat-label">Production</span><span class="stat-value">${building.productionRate || '—'}/min</span>`;

    const costs = building.upgradeCost || {};
    const costHtml = Object.entries(costs)
      .map(([res, amt]) => {
        const canAfford = this.gameState.inventory.getAmount(res as ResourceType) >= (amt as number);
        return `<div class="cost-item ${canAfford ? '' : 'insufficient'}">${res}: ${amt}</div>`;
      })
      .join('');
    document.getElementById('building-upgrade-cost')!.innerHTML = costHtml;

    this.showPanel(this.buildingPanel);
  }

  // --- Hero Panel ---

  private setupHeroPanel(): void {
    document.getElementById('close-hero-panel')!.addEventListener('click', () => {
      this.hidePanel(this.heroPanel);
    });

    // Tab switching
    this.heroPanel.querySelectorAll('.tab-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        this.heroPanel.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        const tab = (btn as HTMLElement).dataset.tab!;
        this.renderHeroTab(tab);
      });
    });

    // Listen for hero selection
    this.game.events.on('heroSelected', (hero: any) => {
      this.showHeroDetail(hero);
    });
  }

  public showHeroDetail(hero: any): void {
    document.getElementById('hero-name')!.textContent = hero.name;

    const stats = hero.getEffectiveStats ? hero.getEffectiveStats() : hero.baseStats || {};
    const statsHtml = Object.entries(stats)
      .filter(([key]) => ['health', 'attack', 'defense', 'speed', 'critChance'].includes(key))
      .map(([key, val]) => `
        <div class="hero-stat-item">
          <span class="stat-label">${key.toUpperCase()}</span>
          <span class="stat-value">${typeof val === 'number' && val < 1 ? (val * 100).toFixed(0) + '%' : val}</span>
        </div>
      `)
      .join('');
    document.getElementById('hero-stats')!.innerHTML = statsHtml;

    this.renderHeroTab('skills');
    this.showPanel(this.heroPanel);
  }

  private renderHeroTab(tab: string): void {
    const content = document.getElementById('hero-tab-content')!;
    switch (tab) {
      case 'skills':
        content.innerHTML = '<p style="color: var(--text-dim);">Skills will be displayed here.</p>';
        break;
      case 'gear':
        content.innerHTML = `
          <div class="gear-slot"><span class="slot-label">Weapon</span><span class="gear-name">— Empty —</span></div>
          <div class="gear-slot"><span class="slot-label">Armor</span><span class="gear-name">— Empty —</span></div>
          <div class="gear-slot"><span class="slot-label">Accessory</span><span class="gear-name">— Empty —</span></div>
          <div class="gear-slot"><span class="slot-label">Mod</span><span class="gear-name">— Empty —</span></div>
        `;
        break;
      case 'bonds':
        content.innerHTML = '<p style="color: var(--text-dim);">Bond relationships will be shown here.</p>';
        break;
      case 'story':
        content.innerHTML = '<p style="color: var(--text-dim);">Hero backstory will appear here.</p>';
        break;
    }
  }

  // --- Dialogue ---

  private setupDialogue(): void {
    this.dialogueOverlay.addEventListener('click', () => {
      this.game.events.emit('advanceDialogue');
    });

    this.game.events.on('showDialogue', (speaker: string, text: string, choices?: any[]) => {
      this.showDialogue(speaker, text, choices);
    });

    this.game.events.on('hideDialogue', () => {
      this.hidePanel(this.dialogueOverlay);
    });
  }

  public showDialogue(speaker: string, text: string, choices?: { text: string; id: string }[]): void {
    document.getElementById('dialogue-speaker')!.textContent = speaker;
    document.getElementById('dialogue-text')!.textContent = text;

    const choicesEl = document.getElementById('dialogue-choices')!;
    if (choices && choices.length > 0) {
      choicesEl.style.display = 'flex';
      choicesEl.innerHTML = choices
        .map(c => `<button class="dialogue-choice-btn" data-choice="${c.id}">${c.text}</button>`)
        .join('');
      choicesEl.querySelectorAll('.dialogue-choice-btn').forEach(btn => {
        btn.addEventListener('click', (e) => {
          const choiceId = (e.target as HTMLElement).dataset.choice;
          this.game.events.emit('dialogueChoice', choiceId);
          this.hidePanel(this.dialogueOverlay);
        });
      });
    } else {
      choicesEl.style.display = 'none';
    }

    this.dialogueOverlay.style.display = 'flex';
  }

  // --- Settings ---

  private setupSettings(): void {
    document.getElementById('close-settings')!.addEventListener('click', () => {
      this.hidePanel(this.settingsPanel);
    });

    document.getElementById('music-volume')!.addEventListener('input', (e) => {
      const vol = parseInt((e.target as HTMLInputElement).value) / 100;
      this.gameState.audioManager.setMusicVolume(vol);
    });

    document.getElementById('sfx-volume')!.addEventListener('input', (e) => {
      const vol = parseInt((e.target as HTMLInputElement).value) / 100;
      this.gameState.audioManager.setSFXVolume(vol);
    });

    document.getElementById('large-text')!.addEventListener('change', (e) => {
      document.body.classList.toggle('large-text', (e.target as HTMLInputElement).checked);
    });

    document.getElementById('colorblind-mode')!.addEventListener('change', (e) => {
      document.body.classList.toggle('colorblind', (e.target as HTMLInputElement).checked);
    });

    document.getElementById('reduced-shake')!.addEventListener('change', (e) => {
      this.game.events.emit('setReducedShake', (e.target as HTMLInputElement).checked);
    });

    document.getElementById('btn-save')!.addEventListener('click', () => {
      this.gameState.saveGame(1);
      this.showToast('Game Saved');
    });

    document.getElementById('btn-load')!.addEventListener('click', () => {
      if (this.gameState.loadGame(1)) {
        this.showToast('Game Loaded');
        this.hidePanel(this.settingsPanel);
      } else {
        this.showToast('No save found');
      }
    });

    document.getElementById('btn-replay-tutorial')!.addEventListener('click', () => {
      this.gameState.tutorialManager.reset();
      this.gameState.tutorialManager.start();
      this.hidePanel(this.settingsPanel);
    });
  }

  // --- Game State Listeners ---

  private setupGameStateListeners(): void {
    this.gameState.on('phaseChanged', (phase: GamePhase) => {
      if (phase === 'mainMenu') {
        this.mainMenu.style.display = 'flex';
        this.hudOverlay.style.display = 'none';
      } else {
        this.mainMenu.style.display = 'none';
        this.hudOverlay.style.display = 'block';
      }
    });

    this.gameState.on('gameStarted', () => {
      this.startResourceUpdates();
      // Enable continue button for future
      const btnContinue = document.getElementById('btn-continue')!;
      btnContinue.removeAttribute('disabled');
    });

    this.gameState.on('gameLoaded', () => {
      this.startResourceUpdates();
    });

    this.gameState.on('gameSaved', () => {
      this.showToast('Game Saved');
    });
  }

  // --- Resource HUD Updates ---

  private startResourceUpdates(): void {
    if (this.resourceUpdateInterval) {
      clearInterval(this.resourceUpdateInterval);
    }
    this.resourceUpdateInterval = window.setInterval(() => {
      this.updateResourceBar();
    }, 1000);
    this.updateResourceBar();
  }

  private updateResourceBar(): void {
    const resources = this.gameState.getResourceSummary();
    for (const [key, value] of Object.entries(resources)) {
      const el = document.getElementById(`res-${key}`);
      if (el) {
        el.textContent = this.formatNumber(value);
      }
    }
  }

  // --- Tutorial Bridge ---

  private setupTutorialBridge(): void {
    const tutorial = this.gameState.tutorialManager;

    // Forward Phaser scene events to tutorial
    this.game.events.on('buildingSelected', () => tutorial.notifyEvent('buildingSelected'));
    this.game.events.on('buildingPlaced', () => tutorial.notifyEvent('buildingPlaced'));
    this.game.events.on('heroSelected', () => tutorial.notifyEvent('heroSelected'));

    // Forward phase changes to tutorial
    this.gameState.on('phaseChanged', () => tutorial.notifyEvent('phaseChanged'));

    // When tutorial completes, show toast
    tutorial.on('tutorialComplete', () => {
      this.showToast('Tutorial complete — good luck, Commander!');
    });
  }

  // --- Utilities ---

  private showPanel(panel: HTMLElement): void {
    panel.style.display = panel.classList.contains('dialogue') ? 'flex' : 'block';
  }

  private hidePanel(panel: HTMLElement): void {
    panel.style.display = 'none';
  }

  public showToast(message: string): void {
    const toast = document.createElement('div');
    toast.className = 'toast';
    toast.textContent = message;
    document.body.appendChild(toast);
    setTimeout(() => toast.remove(), 3000);
  }

  private formatNumber(n: number): string {
    if (n >= 1_000_000) return (n / 1_000_000).toFixed(1) + 'M';
    if (n >= 10_000) return (n / 1_000).toFixed(1) + 'K';
    return n.toString();
  }
}
