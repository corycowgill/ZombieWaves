/**
 * Enemy.ts — Enemy system for Project Ashfall.
 *
 * Defines enemy families, types, boss phases, loot tables, and the core
 * Enemy class with combat state, phase tracking, and serialization.
 */

import { ResourceType } from './Resource';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

export enum EnemyFamily {
  Infected = 'Infected',
  Raider = 'Raider',
  Militia = 'Militia',
  RogueScientist = 'RogueScientist',
}

export enum EnemyType {
  // Infected
  Shambler = 'Shambler',
  Runner = 'Runner',
  Spitter = 'Spitter',
  Bruiser = 'Bruiser',
  Screecher = 'Screecher',
  Burrower = 'Burrower',
  // Raider
  RaiderScout = 'RaiderScout',
  RaiderBrute = 'RaiderBrute',
  // Militia
  MilitiaSoldier = 'MilitiaSoldier',
  MilitiaSniper = 'MilitiaSniper',
  // Rogue Scientist
  RogueLabTech = 'RogueLabTech',
  RogueMutantHandler = 'RogueMutantHandler',
}

/** Maps each EnemyType to its family for quick lookup. */
export const ENEMY_FAMILY_MAP: Readonly<Record<EnemyType, EnemyFamily>> = {
  [EnemyType.Shambler]:           EnemyFamily.Infected,
  [EnemyType.Runner]:             EnemyFamily.Infected,
  [EnemyType.Spitter]:            EnemyFamily.Infected,
  [EnemyType.Bruiser]:            EnemyFamily.Infected,
  [EnemyType.Screecher]:          EnemyFamily.Infected,
  [EnemyType.Burrower]:           EnemyFamily.Infected,
  [EnemyType.RaiderScout]:        EnemyFamily.Raider,
  [EnemyType.RaiderBrute]:        EnemyFamily.Raider,
  [EnemyType.MilitiaSoldier]:     EnemyFamily.Militia,
  [EnemyType.MilitiaSniper]:      EnemyFamily.Militia,
  [EnemyType.RogueLabTech]:       EnemyFamily.RogueScientist,
  [EnemyType.RogueMutantHandler]: EnemyFamily.RogueScientist,
};

// ---------------------------------------------------------------------------
// Stats (same shape as HeroStats)
// ---------------------------------------------------------------------------

export interface EnemyStats {
  health: number;
  maxHealth: number;
  attack: number;
  defense: number;
  speed: number;
  critChance: number;     // 0-1
  critMultiplier: number; // e.g. 1.5
}

// ---------------------------------------------------------------------------
// Abilities
// ---------------------------------------------------------------------------

export type EnemyAbilityEffect =
  | 'damage'
  | 'heal'
  | 'buff'
  | 'debuff'
  | 'aoe'
  | 'summon'
  | 'dot'
  | 'stun'
  | 'enrage';

export interface EnemyAbility {
  id: string;
  name: string;
  description: string;
  cooldown: number;
  currentCooldown: number;
  damage: number;
  effectType: EnemyAbilityEffect;
  targetCount: number;
}

// ---------------------------------------------------------------------------
// Boss Phases
// ---------------------------------------------------------------------------

export interface BossPhase {
  phaseNumber: number;
  /** Health threshold (0-1) at which this phase activates. Phase 1 = 1.0. */
  healthThreshold: number;
  abilities: EnemyAbility[];
  behaviorChange: string;
}

// ---------------------------------------------------------------------------
// Loot
// ---------------------------------------------------------------------------

export interface LootDrop {
  resourceType: ResourceType;
  amount: number;
  dropChance: number; // 0-1
}

// ---------------------------------------------------------------------------
// Serialization shape
// ---------------------------------------------------------------------------

export interface EnemyJSON {
  id: string;
  name: string;
  type: EnemyType;
  family: EnemyFamily;
  stats: EnemyStats;
  abilities: EnemyAbility[];
  lootTable: LootDrop[];
  isBoss: boolean;
  phases: BossPhase[];
}

// ---------------------------------------------------------------------------
// Enemy class
// ---------------------------------------------------------------------------

export class Enemy {
  public id: string;
  public name: string;
  public type: EnemyType;
  public family: EnemyFamily;
  public stats: EnemyStats;
  public abilities: EnemyAbility[];
  public lootTable: LootDrop[];
  public isBoss: boolean;
  public phases: BossPhase[];

  constructor(params: {
    id: string;
    name: string;
    type: EnemyType;
    family: EnemyFamily;
    stats: EnemyStats;
    abilities?: EnemyAbility[];
    lootTable?: LootDrop[];
    isBoss?: boolean;
    phases?: BossPhase[];
  }) {
    this.id = params.id;
    this.name = params.name;
    this.type = params.type;
    this.family = params.family;
    this.stats = { ...params.stats };
    this.abilities = params.abilities?.map(a => ({ ...a })) ?? [];
    this.lootTable = params.lootTable?.map(l => ({ ...l })) ?? [];
    this.isBoss = params.isBoss ?? false;
    this.phases = params.phases?.map(p => ({
      phaseNumber: p.phaseNumber,
      healthThreshold: p.healthThreshold,
      abilities: p.abilities.map(a => ({ ...a })),
      behaviorChange: p.behaviorChange,
    })) ?? [];
  }

  // -----------------------------------------------------------------------
  // Combat
  // -----------------------------------------------------------------------

  /**
   * Apply damage to this enemy, accounting for defense.
   * Returns the actual damage dealt after mitigation.
   */
  takeDamage(amount: number): number {
    if (amount <= 0) return 0;

    // Simple mitigation: defense reduces damage by a percentage.
    // Formula: reduction = defense / (defense + 100)
    const reduction = this.stats.defense / (this.stats.defense + 100);
    const mitigated = Math.max(1, Math.round(amount * (1 - reduction)));

    this.stats.health = Math.max(0, this.stats.health - mitigated);
    return mitigated;
  }

  /** Whether this enemy has been killed. */
  isDead(): boolean {
    return this.stats.health <= 0;
  }

  /**
   * Return the current boss phase based on remaining health ratio.
   * Returns `null` for non-boss enemies or if no phases are defined.
   * Phases are checked from highest phaseNumber downward — returns the
   * first phase whose healthThreshold is >= current health ratio.
   */
  getCurrentPhase(): BossPhase | null {
    if (!this.isBoss || this.phases.length === 0) return null;

    const healthRatio = this.stats.maxHealth > 0
      ? this.stats.health / this.stats.maxHealth
      : 0;

    // Sort phases descending by phaseNumber so we check later phases first.
    const sorted = [...this.phases].sort(
      (a, b) => b.phaseNumber - a.phaseNumber,
    );

    for (const phase of sorted) {
      if (healthRatio <= phase.healthThreshold) {
        return phase;
      }
    }

    // Default to first phase if health is above all thresholds.
    return sorted[sorted.length - 1];
  }

  /**
   * Roll loot drops from this enemy's loot table.
   * Each entry is checked independently against its dropChance.
   */
  rollLoot(): Map<ResourceType, number> {
    const drops = new Map<ResourceType, number>();
    for (const entry of this.lootTable) {
      if (Math.random() <= entry.dropChance) {
        const current = drops.get(entry.resourceType) ?? 0;
        drops.set(entry.resourceType, current + entry.amount);
      }
    }
    return drops;
  }

  /** Create a scaled copy at a different power level. */
  scaleToLevel(factor: number): Enemy {
    const scaled: EnemyStats = {
      health:         Math.round(this.stats.health * factor),
      maxHealth:      Math.round(this.stats.maxHealth * factor),
      attack:         Math.round(this.stats.attack * factor),
      defense:        Math.round(this.stats.defense * factor),
      speed:          this.stats.speed,
      critChance:     this.stats.critChance,
      critMultiplier: this.stats.critMultiplier,
    };

    return new Enemy({
      id: this.id,
      name: this.name,
      type: this.type,
      family: this.family,
      stats: scaled,
      abilities: this.abilities,
      lootTable: this.lootTable,
      isBoss: this.isBoss,
      phases: this.phases,
    });
  }

  // -----------------------------------------------------------------------
  // Serialization
  // -----------------------------------------------------------------------

  toJSON(): EnemyJSON {
    return {
      id: this.id,
      name: this.name,
      type: this.type,
      family: this.family,
      stats: { ...this.stats },
      abilities: this.abilities.map(a => ({ ...a })),
      lootTable: this.lootTable.map(l => ({ ...l })),
      isBoss: this.isBoss,
      phases: this.phases.map(p => ({
        phaseNumber: p.phaseNumber,
        healthThreshold: p.healthThreshold,
        abilities: p.abilities.map(a => ({ ...a })),
        behaviorChange: p.behaviorChange,
      })),
    };
  }

  static fromJSON(data: EnemyJSON): Enemy {
    return new Enemy({
      id: data.id,
      name: data.name,
      type: data.type,
      family: data.family,
      stats: { ...data.stats },
      abilities: data.abilities.map(a => ({ ...a })),
      lootTable: data.lootTable.map(l => ({ ...l })),
      isBoss: data.isBoss,
      phases: data.phases.map(p => ({
        phaseNumber: p.phaseNumber,
        healthThreshold: p.healthThreshold,
        abilities: p.abilities.map(a => ({ ...a })),
        behaviorChange: p.behaviorChange,
      })),
    });
  }
}
