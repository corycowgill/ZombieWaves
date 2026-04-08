import { Hero } from '../models/Hero';
import { ResourceType, ResourceInventory } from '../models/Resource';
import { Building, BuildingType } from '../models/Building';
import { Squad, FormationType } from '../models/Squad';
import { District } from '../models/District';
import { Mission } from '../models/Mission';
import { createHeroRoster } from '../models/HeroRoster';
import { BaseManager } from './BaseManager';
import { EconomyManager } from './EconomyManager';
import { CombatEngine } from './CombatEngine';
import { ProgressionManager } from './ProgressionManager';
import { CampaignManager } from './CampaignManager';
import { ExplorationManager } from './ExplorationManager';
import { SaveManager, SaveSlot } from './SaveManager';
import { AudioManager } from './AudioManager';
import { TutorialManager } from './TutorialManager';

export type GamePhase = 'mainMenu' | 'base' | 'combat' | 'worldMap' | 'heroes' | 'squad' | 'mission';

export interface GameState {
  playerName: string;
  commanderLevel: number;
  commanderXP: number;
  currentPhase: GamePhase;
  heroes: Hero[];
  inventory: ResourceInventory;
  buildings: Building[];
  activeSquad: Squad;
  currentDistrictId: string | null;
  playtimeSeconds: number;
}

/**
 * Central game state manager that owns all subsystems and coordinates
 * the game loop. Provides save/load, resource management, and phase transitions.
 */
export class GameStateManager {
  // --- Core State ---
  public playerName: string = 'Commander';
  public currentPhase: GamePhase = 'mainMenu';
  public playtimeSeconds: number = 0;
  private _gameActive: boolean = false;
  private lastTickTime: number = 0;

  // --- Subsystems ---
  public heroes: Hero[] = [];
  public inventory: ResourceInventory;
  public activeSquad: Squad;
  public buildings: Building[] = [];

  public baseManager: BaseManager;
  public economyManager: EconomyManager;
  public combatEngine: CombatEngine;
  public progressionManager: ProgressionManager;
  public campaignManager: CampaignManager;
  public explorationManager: ExplorationManager;
  public saveManager: SaveManager;
  public audioManager: AudioManager;
  public tutorialManager: TutorialManager;

  // --- Event callbacks ---
  private listeners: Map<string, ((...args: any[]) => void)[]> = new Map();

  constructor() {
    this.inventory = new ResourceInventory();
    this.activeSquad = new Squad('squad-main', 'Alpha Squad');
    this.baseManager = new BaseManager(this.inventory);
    this.economyManager = new EconomyManager(this.inventory);
    this.combatEngine = new CombatEngine();
    this.progressionManager = new ProgressionManager();
    this.campaignManager = new CampaignManager();
    this.explorationManager = new ExplorationManager();
    this.saveManager = new SaveManager();
    this.audioManager = new AudioManager();
    this.tutorialManager = new TutorialManager();
  }

  // --- Event System ---

  public on(event: string, callback: (...args: any[]) => void): void {
    if (!this.listeners.has(event)) {
      this.listeners.set(event, []);
    }
    this.listeners.get(event)!.push(callback);
  }

  public emit(event: string, ...args: any[]): void {
    const callbacks = this.listeners.get(event);
    if (callbacks) {
      callbacks.forEach(cb => cb(...args));
    }
    // Forward events to tutorial system
    this.tutorialManager.notifyEvent(event);
  }

  // --- Game Lifecycle ---

  /** Start a new game with fresh state */
  public newGame(playerName: string): void {
    this.playerName = playerName;
    this.playtimeSeconds = 0;
    this._gameActive = true;

    // Initialize starting resources
    this.inventory = new ResourceInventory();
    this.inventory.add(ResourceType.Food, 500);
    this.inventory.add(ResourceType.Water, 500);
    this.inventory.add(ResourceType.Fuel, 200);
    this.inventory.add(ResourceType.Scrap, 300);
    this.inventory.add(ResourceType.Electronics, 50);
    this.inventory.add(ResourceType.Medicine, 100);

    // Create hero roster (first 5 unlocked)
    this.heroes = createHeroRoster();
    this.heroes.forEach((hero, i) => {
      hero.isUnlocked = i < 5;
    });

    // Initialize active squad with first 5 heroes
    this.activeSquad = new Squad('squad-main', 'Alpha Squad');
    this.heroes.filter(h => h.isUnlocked).slice(0, 5).forEach(h => {
      this.activeSquad.addHero(h);
    });

    // Reinitialize subsystems
    this.baseManager = new BaseManager(this.inventory);
    this.economyManager = new EconomyManager(this.inventory);
    this.progressionManager = new ProgressionManager();
    this.campaignManager = new CampaignManager();
    this.explorationManager = new ExplorationManager();

    // Place starting Command Center
    this.baseManager.placeBuilding(BuildingType.CommandCenter, 5, 5);

    // Start campaign
    this.campaignManager.startNewCampaign();

    this.setPhase('base');
    this.lastTickTime = Date.now();
    this.emit('gameStarted');

    // Start tutorial for new games
    if (!this.tutorialManager.wasCompleted()) {
      setTimeout(() => this.tutorialManager.start(), 800);
    }
  }

  /** Load game from save slot */
  public loadGame(slotId: number): boolean {
    const saveData = this.saveManager.load(slotId);
    if (!saveData) return false;

    try {
      const state = JSON.parse(saveData.data) as GameState;
      this.playerName = state.playerName;
      this.playtimeSeconds = state.playtimeSeconds;

      // Restore inventory
      this.inventory = new ResourceInventory();
      if (state.inventory) {
        Object.entries(state.inventory).forEach(([key, value]) => {
          this.inventory.add(key as ResourceType, value as number);
        });
      }

      // Restore heroes
      this.heroes = state.heroes || createHeroRoster();

      // Reinitialize subsystems with loaded state
      this.baseManager = new BaseManager(this.inventory);
      this.economyManager = new EconomyManager(this.inventory);

      this._gameActive = true;
      this.lastTickTime = Date.now();
      this.setPhase('base');
      this.emit('gameLoaded');
      return true;
    } catch {
      console.error('Failed to load save data');
      return false;
    }
  }

  /** Set the current game phase and notify listeners */
  public setPhase(phase: GamePhase): void {
    const previous = this.currentPhase;
    this.currentPhase = phase;
    this.emit('phaseChanged', phase, previous);
  }

  /** Check if game is actively running */
  public isGameActive(): boolean {
    return this._gameActive;
  }

  // --- Game Tick ---

  /** Called each frame to update time-based systems */
  public tick(deltaMs: number): void {
    if (!this._gameActive) return;

    const deltaSec = deltaMs / 1000;
    this.playtimeSeconds += deltaSec;

    // Update resource production
    this.baseManager.tick(deltaSec);

    // Update upgrade timers
    this.buildings.forEach(b => {
      if (b.isUpgrading) {
        b.upgradeTimeRemaining -= deltaSec;
        if (b.upgradeTimeRemaining <= 0) {
          b.completeUpgrade();
          this.emit('buildingUpgraded', b);
        }
      }
    });
  }

  // --- Save System ---

  /** Save current game state */
  public saveGame(slotId: number): void {
    const state: GameState = {
      playerName: this.playerName,
      commanderLevel: this.progressionManager.commanderLevel,
      commanderXP: this.progressionManager.commanderXP,
      currentPhase: this.currentPhase,
      heroes: this.heroes,
      inventory: this.inventory,
      buildings: this.buildings,
      activeSquad: this.activeSquad,
      currentDistrictId: null,
      playtimeSeconds: this.playtimeSeconds,
    };

    this.saveManager.save(slotId, {
      commanderLevel: this.progressionManager.commanderLevel,
      currentAct: this.campaignManager.getCurrentActName(),
      playtime: this.playtimeSeconds,
      data: JSON.stringify(state),
    });

    this.emit('gameSaved');
  }

  /** Auto-save to slot 0 */
  public autoSave(): void {
    this.saveGame(0);
  }

  /** Check if any save data exists */
  public hasSaveData(): boolean {
    return this.saveManager.hasSaveData();
  }

  /** Get all save slot metadata */
  public getSaveSlots(): SaveSlot[] {
    return this.saveManager.listSaves();
  }

  // --- Resource Helpers ---

  /** Get current amount of a resource */
  public getResource(type: ResourceType): number {
    return this.inventory.getAmount(type);
  }

  /** Get all resource amounts for HUD display */
  public getResourceSummary(): Record<string, number> {
    return {
      food: this.inventory.getAmount(ResourceType.Food),
      water: this.inventory.getAmount(ResourceType.Water),
      fuel: this.inventory.getAmount(ResourceType.Fuel),
      scrap: this.inventory.getAmount(ResourceType.Scrap),
      electronics: this.inventory.getAmount(ResourceType.Electronics),
      medicine: this.inventory.getAmount(ResourceType.Medicine),
    };
  }
}
