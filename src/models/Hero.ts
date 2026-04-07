/**
 * Hero.ts — Hero system for Project Ashfall.
 *
 * Defines roles, rarities, skills, gear, stats, and the core Hero class
 * with levelling, equipment, and serialization support.
 */

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

export enum HeroRole {
  Assault = 'Assault',
  Heavy = 'Heavy',
  Recon = 'Recon',
  Medic = 'Medic',
  Engineer = 'Engineer',
  Sniper = 'Sniper',
  Demolitions = 'Demolitions',
}

export enum HeroRarity {
  Common = 'Common',
  Rare = 'Rare',
  Elite = 'Elite',
  Legendary = 'Legendary',
}

// ---------------------------------------------------------------------------
// Skill
// ---------------------------------------------------------------------------

export type SkillType = 'active' | 'passive' | 'ultimate';
export type TargetType = 'single' | 'area' | 'self' | 'allAllies' | 'allEnemies';
export type EffectType =
  | 'damage'
  | 'heal'
  | 'buff'
  | 'debuff'
  | 'dot'
  | 'shield'
  | 'stun'
  | 'taunt'
  | 'stealth'
  | 'deploy'
  | 'morale'
  | 'reveal'
  | 'hack'
  | 'knockback'
  | 'bleed'
  | 'burn'
  | 'explosiveDamage'
  | 'critBoost'
  | 'speedBoost'
  | 'defenseBoost'
  | 'attackBoost';

export interface Skill {
  id: string;
  name: string;
  description: string;
  type: SkillType;
  targetType: TargetType;
  cooldown: number;
  currentCooldown: number;
  damage: number;
  healAmount: number;
  duration: number;
  effectType: EffectType;
  unlockLevel: number;
  iconKey: string;
}

export interface SkillJSON {
  id: string;
  name: string;
  description: string;
  type: SkillType;
  targetType: TargetType;
  cooldown: number;
  currentCooldown: number;
  damage: number;
  healAmount: number;
  duration: number;
  effectType: EffectType;
  unlockLevel: number;
  iconKey: string;
}

// ---------------------------------------------------------------------------
// Gear
// ---------------------------------------------------------------------------

export type GearSlot = 'weapon' | 'armor' | 'accessory' | 'mod';

export interface GearItem {
  id: string;
  name: string;
  slot: GearSlot;
  rarity: HeroRarity;
  statBonuses: Partial<HeroStats>;
  description: string;
}

export interface GearItemJSON {
  id: string;
  name: string;
  slot: GearSlot;
  rarity: string;
  statBonuses: Partial<HeroStats>;
  description: string;
}

// ---------------------------------------------------------------------------
// Stats
// ---------------------------------------------------------------------------

export interface HeroStats {
  health: number;
  maxHealth: number;
  attack: number;
  defense: number;
  speed: number;
  critChance: number;   // 0-1
  critMultiplier: number; // e.g. 1.5 = 150 %
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const MAX_LEVEL = 60;
const MAX_RANK = 5;

/** XP needed to advance FROM `level` to `level + 1`. */
export function xpForLevel(level: number): number {
  return 100 + level * level * 10;
}

/** Rarity-based stat multiplier applied when computing effective stats. */
function rarityMultiplier(rarity: HeroRarity): number {
  switch (rarity) {
    case HeroRarity.Common:    return 1.0;
    case HeroRarity.Rare:      return 1.1;
    case HeroRarity.Elite:     return 1.25;
    case HeroRarity.Legendary: return 1.4;
  }
}

// ---------------------------------------------------------------------------
// Serialization shape
// ---------------------------------------------------------------------------

export interface HeroJSON {
  id: string;
  name: string;
  role: string;
  rarity: string;
  level: number;
  rank: number;
  experience: number;
  baseStats: HeroStats;
  gear: Record<string, GearItemJSON>;
  skills: SkillJSON[];
  signatureWeapon: GearItemJSON | null;
  passiveTraits: string[];
  bondPartnerIds: string[];
  backstory: string;
  isUnlocked: boolean;
  morale: number;
}

// ---------------------------------------------------------------------------
// Hero class
// ---------------------------------------------------------------------------

export class Hero {
  public id: string;
  public name: string;
  public role: HeroRole;
  public rarity: HeroRarity;
  public level: number;
  public rank: number;
  public experience: number;
  public baseStats: HeroStats;
  public gear: Map<GearSlot, GearItem>;
  public skills: Skill[];
  public signatureWeapon: GearItem | null;
  public passiveTraits: string[];
  public bondPartnerIds: string[];
  public backstory: string;
  public isUnlocked: boolean;
  public morale: number;

  constructor(params: {
    id: string;
    name: string;
    role: HeroRole;
    rarity: HeroRarity;
    level?: number;
    rank?: number;
    experience?: number;
    baseStats: HeroStats;
    gear?: Map<GearSlot, GearItem>;
    skills?: Skill[];
    signatureWeapon?: GearItem | null;
    passiveTraits?: string[];
    bondPartnerIds?: string[];
    backstory?: string;
    isUnlocked?: boolean;
    morale?: number;
  }) {
    this.id = params.id;
    this.name = params.name;
    this.role = params.role;
    this.rarity = params.rarity;
    this.level = Math.max(1, Math.min(MAX_LEVEL, params.level ?? 1));
    this.rank = Math.max(1, Math.min(MAX_RANK, params.rank ?? 1));
    this.experience = params.experience ?? 0;
    this.baseStats = { ...params.baseStats };
    this.gear = params.gear ?? new Map<GearSlot, GearItem>();
    this.skills = params.skills ?? [];
    this.signatureWeapon = params.signatureWeapon ?? null;
    this.passiveTraits = params.passiveTraits ?? [];
    this.bondPartnerIds = params.bondPartnerIds ?? [];
    this.backstory = params.backstory ?? '';
    this.isUnlocked = params.isUnlocked ?? false;
    this.morale = Math.max(0, Math.min(100, params.morale ?? 50));
  }

  // -----------------------------------------------------------------------
  // Stats
  // -----------------------------------------------------------------------

  /**
   * Compute effective stats = base * level-scaling * rarity multiplier
   *   + all gear bonuses.
   *
   * Level scaling: each level past 1 gives +2 % compounding.
   */
  getEffectiveStats(): HeroStats {
    const levelScale = 1 + (this.level - 1) * 0.02;
    const rm = rarityMultiplier(this.rarity);

    const eff: HeroStats = {
      health:         Math.round(this.baseStats.health * levelScale * rm),
      maxHealth:      Math.round(this.baseStats.maxHealth * levelScale * rm),
      attack:         Math.round(this.baseStats.attack * levelScale * rm),
      defense:        Math.round(this.baseStats.defense * levelScale * rm),
      speed:          Math.round(this.baseStats.speed * levelScale * rm),
      critChance:     this.baseStats.critChance,
      critMultiplier: this.baseStats.critMultiplier,
    };

    // Accumulate gear bonuses.
    for (const item of this.gear.values()) {
      this.applyBonuses(eff, item.statBonuses);
    }

    // Signature weapon bonus (always active if present).
    if (this.signatureWeapon) {
      this.applyBonuses(eff, this.signatureWeapon.statBonuses);
    }

    // Ensure health does not exceed maxHealth.
    eff.health = Math.min(eff.health, eff.maxHealth);

    return eff;
  }

  private applyBonuses(stats: HeroStats, bonuses: Partial<HeroStats>): void {
    if (bonuses.health !== undefined)         stats.health         += bonuses.health;
    if (bonuses.maxHealth !== undefined)       stats.maxHealth      += bonuses.maxHealth;
    if (bonuses.attack !== undefined)          stats.attack         += bonuses.attack;
    if (bonuses.defense !== undefined)         stats.defense        += bonuses.defense;
    if (bonuses.speed !== undefined)           stats.speed          += bonuses.speed;
    if (bonuses.critChance !== undefined)      stats.critChance     += bonuses.critChance;
    if (bonuses.critMultiplier !== undefined)  stats.critMultiplier += bonuses.critMultiplier;
  }

  // -----------------------------------------------------------------------
  // Experience / levelling
  // -----------------------------------------------------------------------

  /** XP required to reach the next level from the current level. */
  xpToNextLevel(): number {
    if (this.level >= MAX_LEVEL) return Infinity;
    return xpForLevel(this.level);
  }

  /** Whether the hero has accumulated enough XP to level up. */
  canLevelUp(): boolean {
    return this.level < MAX_LEVEL && this.experience >= this.xpToNextLevel();
  }

  /** Grant experience and auto-level as many times as possible. */
  addExperience(amount: number): void {
    if (amount <= 0 || this.level >= MAX_LEVEL) return;
    this.experience += amount;
    while (this.canLevelUp()) {
      this.levelUp();
    }
  }

  /**
   * Advance one level, consuming the required XP.
   * Callers should check `canLevelUp()` first.
   */
  levelUp(): void {
    if (!this.canLevelUp()) return;
    this.experience -= this.xpToNextLevel();
    this.level = Math.min(this.level + 1, MAX_LEVEL);
  }

  // -----------------------------------------------------------------------
  // Gear
  // -----------------------------------------------------------------------

  /** Equip a gear item, replacing whatever currently occupies its slot. */
  equip(item: GearItem): GearItem | null {
    const previous = this.gear.get(item.slot) ?? null;
    this.gear.set(item.slot, item);
    return previous;
  }

  /** Remove and return the item in the given slot (or null). */
  unequip(slot: GearSlot): GearItem | null {
    const item = this.gear.get(slot) ?? null;
    this.gear.delete(slot);
    return item;
  }

  // -----------------------------------------------------------------------
  // Skills
  // -----------------------------------------------------------------------

  /** Return skills whose unlock level is <= the hero's current level. */
  getSkillsAtLevel(): Skill[] {
    return this.skills.filter(s => s.unlockLevel <= this.level);
  }

  // -----------------------------------------------------------------------
  // Serialization
  // -----------------------------------------------------------------------

  toJSON(): HeroJSON {
    const gear: Record<string, GearItemJSON> = {};
    for (const [slot, item] of this.gear) {
      gear[slot] = serializeGearItem(item);
    }

    return {
      id: this.id,
      name: this.name,
      role: this.role,
      rarity: this.rarity,
      level: this.level,
      rank: this.rank,
      experience: this.experience,
      baseStats: { ...this.baseStats },
      gear,
      skills: this.skills.map(serializeSkill),
      signatureWeapon: this.signatureWeapon
        ? serializeGearItem(this.signatureWeapon)
        : null,
      passiveTraits: [...this.passiveTraits],
      bondPartnerIds: [...this.bondPartnerIds],
      backstory: this.backstory,
      isUnlocked: this.isUnlocked,
      morale: this.morale,
    };
  }

  static fromJSON(data: HeroJSON): Hero {
    const gear = new Map<GearSlot, GearItem>();
    for (const [slot, itemData] of Object.entries(data.gear)) {
      gear.set(slot as GearSlot, deserializeGearItem(itemData));
    }

    return new Hero({
      id: data.id,
      name: data.name,
      role: data.role as HeroRole,
      rarity: data.rarity as HeroRarity,
      level: data.level,
      rank: data.rank,
      experience: data.experience,
      baseStats: { ...data.baseStats },
      gear,
      skills: data.skills.map(deserializeSkill),
      signatureWeapon: data.signatureWeapon
        ? deserializeGearItem(data.signatureWeapon)
        : null,
      passiveTraits: [...data.passiveTraits],
      bondPartnerIds: [...data.bondPartnerIds],
      backstory: data.backstory,
      isUnlocked: data.isUnlocked,
      morale: data.morale,
    });
  }
}

// ---------------------------------------------------------------------------
// Serialization helpers
// ---------------------------------------------------------------------------

function serializeSkill(s: Skill): SkillJSON {
  return { ...s };
}

function deserializeSkill(d: SkillJSON): Skill {
  return { ...d };
}

function serializeGearItem(g: GearItem): GearItemJSON {
  return {
    id: g.id,
    name: g.name,
    slot: g.slot,
    rarity: g.rarity,
    statBonuses: { ...g.statBonuses },
    description: g.description,
  };
}

function deserializeGearItem(d: GearItemJSON): GearItem {
  return {
    id: d.id,
    name: d.name,
    slot: d.slot,
    rarity: d.rarity as HeroRarity,
    statBonuses: { ...d.statBonuses },
    description: d.description,
  };
}
