/** Game-wide constants for Project Ashfall */

export const GAME = {
  TITLE: 'Project Ashfall',
  VERSION: '1.0.0',
  BUILD: 1,
} as const;

export const GRID = {
  BASE_WIDTH: 12,
  BASE_HEIGHT: 12,
  ISO_TILE_WIDTH: 64,
  ISO_TILE_HEIGHT: 32,
  COMBAT_WIDTH: 10,
  COMBAT_HEIGHT: 8,
} as const;

export const COMBAT = {
  MAX_SQUAD_SIZE: 5,
  MAX_SUPPORT_UNITS: 3,
  TICK_RATE_MS: 16, // ~60fps
  TACTICAL_PAUSE_SLOWDOWN: 0.1,
  BASE_CRIT_MULTIPLIER: 1.5,
  COVER_DAMAGE_REDUCTION: 0.4,
  HALF_COVER_REDUCTION: 0.25,
  FLANKING_DAMAGE_BONUS: 0.25,
  ELEVATION_BONUS: 0.15,
  MISSION_TIME_SHORT: 120,
  MISSION_TIME_NORMAL: 300,
  MISSION_TIME_BOSS: 480,
} as const;

export const HEROES = {
  MAX_LEVEL: 60,
  MAX_RANK: 5,
  MAX_MORALE: 100,
  MIN_MORALE: 0,
  MORALE_BOOST_PER_EVENT: 10,
  MORALE_PENALTY_PER_DEFEAT: 5,
  BOND_LEVEL_THRESHOLDS: [0, 100, 300, 600, 1000],
} as const;

export const BASE = {
  MAX_BUILDING_LEVEL: 10,
  MAX_WALLS: 40,
  MAX_TURRETS: 12,
  MAX_TRAPS: 20,
  ADJACENCY_BONUS_PERCENT: 0.10,
  MAX_UPGRADE_TIMER_SECONDS: 600,
  MAX_UPGRADE_QUEUE: 3,
} as const;

export const RESOURCES = {
  STARTING: {
    Food: 500,
    Water: 500,
    Fuel: 200,
    Scrap: 300,
    Electronics: 50,
    Medicine: 100,
  },
  PRODUCTION_TICK_SECONDS: 60,
  MAX_STORAGE: 99999,
} as const;

export const ECONOMY = {
  UPGRADE_COST_SCALING: 1.35,
  MISSION_REWARD_BASE: 100,
  SCAVENGING_LOOT_MIN: 0.8,
  SCAVENGING_LOOT_MAX: 1.5,
} as const;

export const WORLD = {
  TOTAL_DISTRICTS: 24,
  DISTRICTS_PER_ACT: 5,
  FOG_REVEAL_RADIUS: 2,
  EXPEDITION_FUEL_COST: 50,
} as const;

export const CAMPAIGN = {
  TOTAL_ACTS: 5,
  CHAPTERS_PER_ACT: 5,
} as const;

export const PROGRESSION = {
  MAX_COMMANDER_LEVEL: 50,
  COMMANDER_XP_PER_MISSION: 100,
  COMMANDER_XP_PER_BOSS: 500,
} as const;

export const SAVE = {
  MAX_SLOTS: 5,
  AUTO_SAVE_SLOT: 0,
  STORAGE_PREFIX: 'ashfall_save_',
} as const;

export const AUDIO = {
  DEFAULT_MUSIC_VOLUME: 0.6,
  DEFAULT_SFX_VOLUME: 0.8,
  MUSIC_FADE_DURATION: 1500,
} as const;

export const ANIMATION = {
  BUILDING_UPGRADE_MS: 500,
  DAMAGE_NUMBER_MS: 1000,
  SCREEN_TRANSITION_MS: 300,
  ZOOM_TRANSITION_MS: 400,
} as const;

/** XP required to reach each hero level (index = level-1) */
export function xpForHeroLevel(level: number): number {
  return 100 + (level * level * 10);
}

/** XP required for each commander level */
export function xpForCommanderLevel(level: number): number {
  return 500 + (level * level * 50);
}

/** Upgrade cost scaling formula */
export function upgradeCost(baseCost: number, level: number): number {
  return Math.floor(baseCost * Math.pow(ECONOMY.UPGRADE_COST_SCALING, level - 1));
}

/** Upgrade time in seconds (capped at MAX_UPGRADE_TIMER_SECONDS) */
export function upgradeTime(baseTime: number, level: number): number {
  const time = Math.floor(baseTime * Math.pow(1.5, level - 1));
  return Math.min(time, BASE.MAX_UPGRADE_TIMER_SECONDS);
}
