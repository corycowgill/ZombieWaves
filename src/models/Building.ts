/**
 * Building.ts — Building system for Project Ashfall.
 *
 * Defines base-building structures with types, categories, costs, production,
 * upgrade data, hit points, and serialization. Buildings are placed on the
 * base grid and managed by the BaseManager system.
 */

import { ResourceType } from './Resource';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

export enum BuildingType {
  CommandCenter = 'CommandCenter',
  Barracks = 'Barracks',
  Workshop = 'Workshop',
  Infirmary = 'Infirmary',
  ResearchLab = 'ResearchLab',
  Farm = 'Farm',
  WaterPurifier = 'WaterPurifier',
  FuelDepot = 'FuelDepot',
  ScrapYard = 'ScrapYard',
  RadarTower = 'RadarTower',
  HeroQuarters = 'HeroQuarters',
  Wall = 'Wall',
  Turret = 'Turret',
  Trap = 'Trap',
  Garage = 'Garage',
}

export type BuildingCategory = 'production' | 'military' | 'support' | 'defense';

// ---------------------------------------------------------------------------
// Category mapping
// ---------------------------------------------------------------------------

const CATEGORY_MAP: Readonly<Record<BuildingType, BuildingCategory>> = {
  [BuildingType.CommandCenter]: 'support',
  [BuildingType.Barracks]:      'military',
  [BuildingType.Workshop]:      'production',
  [BuildingType.Infirmary]:     'support',
  [BuildingType.ResearchLab]:   'support',
  [BuildingType.Farm]:          'production',
  [BuildingType.WaterPurifier]: 'production',
  [BuildingType.FuelDepot]:     'production',
  [BuildingType.ScrapYard]:     'production',
  [BuildingType.RadarTower]:    'support',
  [BuildingType.HeroQuarters]:  'support',
  [BuildingType.Wall]:          'defense',
  [BuildingType.Turret]:        'defense',
  [BuildingType.Trap]:          'defense',
  [BuildingType.Garage]:        'military',
};

// ---------------------------------------------------------------------------
// Interfaces
// ---------------------------------------------------------------------------

export interface UpgradeRequirement {
  resources: Map<ResourceType, number>;
  timeSeconds: number;
  requiredCommandCenterLevel: number;
}

export interface ProductionEntry {
  resourceType: ResourceType;
  amountPerMinute: number;
}

export interface BuildingJSON {
  id: string;
  type: BuildingType;
  level: number;
  gridPosition: { col: number; row: number };
  isUpgrading: boolean;
  upgradeTimeRemaining: number;
  hitPoints: number;
  maxHitPoints: number;
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const MAX_BUILDING_LEVEL = 10;
const UPGRADE_TIME_CAP_SECONDS = 600;

/** Base build costs at level 1 for each building type. */
const BASE_COSTS: Readonly<Record<BuildingType, ReadonlyMap<ResourceType, number>>> = {
  [BuildingType.CommandCenter]: new Map([[ResourceType.Scrap, 500], [ResourceType.Electronics, 100]]),
  [BuildingType.Barracks]:      new Map([[ResourceType.Scrap, 200], [ResourceType.Electronics, 40]]),
  [BuildingType.Workshop]:      new Map([[ResourceType.Scrap, 150], [ResourceType.Electronics, 30]]),
  [BuildingType.Infirmary]:     new Map([[ResourceType.Scrap, 180], [ResourceType.Medicine, 60]]),
  [BuildingType.ResearchLab]:   new Map([[ResourceType.Scrap, 250], [ResourceType.Electronics, 80]]),
  [BuildingType.Farm]:          new Map([[ResourceType.Scrap, 100], [ResourceType.Water, 50]]),
  [BuildingType.WaterPurifier]: new Map([[ResourceType.Scrap, 120], [ResourceType.Electronics, 20]]),
  [BuildingType.FuelDepot]:     new Map([[ResourceType.Scrap, 140], [ResourceType.Electronics, 25]]),
  [BuildingType.ScrapYard]:     new Map([[ResourceType.Scrap, 80]]),
  [BuildingType.RadarTower]:    new Map([[ResourceType.Scrap, 200], [ResourceType.Electronics, 60]]),
  [BuildingType.HeroQuarters]:  new Map([[ResourceType.Scrap, 160], [ResourceType.Electronics, 35]]),
  [BuildingType.Wall]:          new Map([[ResourceType.Scrap, 50]]),
  [BuildingType.Turret]:        new Map([[ResourceType.Scrap, 120], [ResourceType.MilitaryComponents, 10]]),
  [BuildingType.Trap]:          new Map([[ResourceType.Scrap, 60], [ResourceType.Electronics, 10]]),
  [BuildingType.Garage]:        new Map([[ResourceType.Scrap, 220], [ResourceType.Fuel, 50], [ResourceType.Electronics, 40]]),
};

/** Base upgrade time in seconds at level 1 for each building type. */
const BASE_UPGRADE_TIMES: Readonly<Record<BuildingType, number>> = {
  [BuildingType.CommandCenter]: 120,
  [BuildingType.Barracks]:      60,
  [BuildingType.Workshop]:      50,
  [BuildingType.Infirmary]:     55,
  [BuildingType.ResearchLab]:   80,
  [BuildingType.Farm]:          40,
  [BuildingType.WaterPurifier]: 45,
  [BuildingType.FuelDepot]:     50,
  [BuildingType.ScrapYard]:     35,
  [BuildingType.RadarTower]:    70,
  [BuildingType.HeroQuarters]:  60,
  [BuildingType.Wall]:          20,
  [BuildingType.Turret]:        45,
  [BuildingType.Trap]:          30,
  [BuildingType.Garage]:        75,
};

/** CC level required per building level (1-indexed: index 0 unused). */
const CC_LEVEL_REQUIREMENTS: readonly number[] = [
  0,  // placeholder for index 0
  1,  // level 1 -> CC 1
  1,  // level 2 -> CC 1
  2,  // level 3 -> CC 2
  3,  // level 4 -> CC 3
  4,  // level 5 -> CC 4
  5,  // level 6 -> CC 5
  6,  // level 7 -> CC 6
  7,  // level 8 -> CC 7
  8,  // level 9 -> CC 8
  9,  // level 10 -> CC 9
];

/** Base hit points at level 1 per building type. */
const BASE_HIT_POINTS: Readonly<Record<BuildingType, number>> = {
  [BuildingType.CommandCenter]: 2000,
  [BuildingType.Barracks]:      800,
  [BuildingType.Workshop]:      600,
  [BuildingType.Infirmary]:     500,
  [BuildingType.ResearchLab]:   500,
  [BuildingType.Farm]:          400,
  [BuildingType.WaterPurifier]: 400,
  [BuildingType.FuelDepot]:     450,
  [BuildingType.ScrapYard]:     500,
  [BuildingType.RadarTower]:    350,
  [BuildingType.HeroQuarters]:  600,
  [BuildingType.Wall]:          1500,
  [BuildingType.Turret]:        700,
  [BuildingType.Trap]:          200,
  [BuildingType.Garage]:        800,
};

/** Base production rates at level 1. */
export const PRODUCTION_TABLE: Partial<Record<BuildingType, ProductionEntry[]>> = {
  [BuildingType.Farm]:          [{ resourceType: ResourceType.Food,  amountPerMinute: 5 }],
  [BuildingType.WaterPurifier]: [{ resourceType: ResourceType.Water, amountPerMinute: 5 }],
  [BuildingType.FuelDepot]:     [{ resourceType: ResourceType.Fuel,  amountPerMinute: 3 }],
  [BuildingType.ScrapYard]:     [{ resourceType: ResourceType.Scrap, amountPerMinute: 4 }],
  [BuildingType.Workshop]:      [{ resourceType: ResourceType.Scrap, amountPerMinute: 2 },
                                 { resourceType: ResourceType.Electronics, amountPerMinute: 1 }],
  [BuildingType.ResearchLab]:   [{ resourceType: ResourceType.ResearchData, amountPerMinute: 1 }],
};

// ---------------------------------------------------------------------------
// Building class
// ---------------------------------------------------------------------------

export class Building {
  public id: string;
  public type: BuildingType;
  public level: number;
  public gridPosition: { col: number; row: number };
  public isUpgrading: boolean;
  public upgradeTimeRemaining: number; // seconds
  public hitPoints: number;
  public maxHitPoints: number;

  constructor(
    id: string,
    type: BuildingType,
    col: number,
    row: number,
    level: number = 1,
  ) {
    this.id = id;
    this.type = type;
    this.level = Math.max(1, Math.min(MAX_BUILDING_LEVEL, level));
    this.gridPosition = { col, row };
    this.isUpgrading = false;
    this.upgradeTimeRemaining = 0;
    this.maxHitPoints = Building.computeMaxHitPoints(type, this.level);
    this.hitPoints = this.maxHitPoints;
  }

  // -----------------------------------------------------------------------
  // Production
  // -----------------------------------------------------------------------

  /**
   * Get resource production entries for the current level.
   * Production scales +25 % per level above 1.
   */
  getProductionRate(): ProductionEntry[] {
    const base = PRODUCTION_TABLE[this.type];
    if (!base) return [];
    return base.map(entry => ({
      resourceType: entry.resourceType,
      amountPerMinute: +(entry.amountPerMinute * (1 + (this.level - 1) * 0.25)).toFixed(2),
    }));
  }

  // -----------------------------------------------------------------------
  // Upgrade cost
  // -----------------------------------------------------------------------

  /**
   * Compute the cost to upgrade from the current level to level + 1.
   * Formula: baseCost * 1.35^(level - 1) for each resource.
   * Time capped at UPGRADE_TIME_CAP_SECONDS.
   */
  getUpgradeCost(): UpgradeRequirement {
    const nextLevel = this.level + 1;
    if (nextLevel > MAX_BUILDING_LEVEL) {
      return {
        resources: new Map(),
        timeSeconds: 0,
        requiredCommandCenterLevel: MAX_BUILDING_LEVEL,
      };
    }

    const baseMap = BASE_COSTS[this.type];
    const scaledResources = new Map<ResourceType, number>();
    const scaleFactor = Math.pow(1.35, this.level - 1);

    for (const [rt, base] of baseMap) {
      scaledResources.set(rt, Math.ceil(base * scaleFactor));
    }

    const baseTime = BASE_UPGRADE_TIMES[this.type];
    const time = Math.min(
      UPGRADE_TIME_CAP_SECONDS,
      Math.ceil(baseTime * scaleFactor),
    );

    const requiredCC = CC_LEVEL_REQUIREMENTS[nextLevel] ?? MAX_BUILDING_LEVEL;

    return {
      resources: scaledResources,
      timeSeconds: time,
      requiredCommandCenterLevel: requiredCC,
    };
  }

  // -----------------------------------------------------------------------
  // Upgrade lifecycle
  // -----------------------------------------------------------------------

  /**
   * Whether this building can be upgraded given available resources
   * and the player's Command Center level.
   */
  canUpgrade(
    availableResources: Map<ResourceType, number>,
    commandCenterLevel: number,
  ): boolean {
    if (this.level >= MAX_BUILDING_LEVEL) return false;
    if (this.isUpgrading) return false;

    const cost = this.getUpgradeCost();
    if (commandCenterLevel < cost.requiredCommandCenterLevel) return false;

    for (const [rt, needed] of cost.resources) {
      if ((availableResources.get(rt) ?? 0) < needed) return false;
    }

    return true;
  }

  /** Begin an upgrade. Caller is responsible for deducting resources. */
  startUpgrade(): void {
    if (this.level >= MAX_BUILDING_LEVEL || this.isUpgrading) return;
    const cost = this.getUpgradeCost();
    this.isUpgrading = true;
    this.upgradeTimeRemaining = cost.timeSeconds;
  }

  /** Finalize an upgrade: bump level, recalculate HP, reset upgrade state. */
  completeUpgrade(): void {
    if (!this.isUpgrading) return;
    this.level = Math.min(this.level + 1, MAX_BUILDING_LEVEL);
    this.isUpgrading = false;
    this.upgradeTimeRemaining = 0;
    this.maxHitPoints = Building.computeMaxHitPoints(this.type, this.level);
    this.hitPoints = this.maxHitPoints;
  }

  // -----------------------------------------------------------------------
  // Static helpers
  // -----------------------------------------------------------------------

  /** Maximum level any building can reach. */
  static getMaxLevel(): number {
    return MAX_BUILDING_LEVEL;
  }

  /** Get the category for a given building type. */
  static getCategory(type: BuildingType): BuildingCategory {
    return CATEGORY_MAP[type];
  }

  /** Hit points scale +15 % per level above 1. */
  private static computeMaxHitPoints(type: BuildingType, level: number): number {
    const base = BASE_HIT_POINTS[type];
    return Math.round(base * (1 + (level - 1) * 0.15));
  }

  // -----------------------------------------------------------------------
  // Serialization
  // -----------------------------------------------------------------------

  toJSON(): BuildingJSON {
    return {
      id: this.id,
      type: this.type,
      level: this.level,
      gridPosition: { ...this.gridPosition },
      isUpgrading: this.isUpgrading,
      upgradeTimeRemaining: this.upgradeTimeRemaining,
      hitPoints: this.hitPoints,
      maxHitPoints: this.maxHitPoints,
    };
  }

  static fromJSON(data: BuildingJSON): Building {
    const b = new Building(
      data.id,
      data.type,
      data.gridPosition.col,
      data.gridPosition.row,
      data.level,
    );
    b.isUpgrading = data.isUpgrading;
    b.upgradeTimeRemaining = data.upgradeTimeRemaining;
    b.hitPoints = data.hitPoints;
    b.maxHitPoints = data.maxHitPoints;
    return b;
  }
}
