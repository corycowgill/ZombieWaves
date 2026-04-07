/**
 * Mission.ts — Mission system for Project Ashfall.
 *
 * Defines mission types, difficulties, objectives, rewards, threats, and
 * the core Mission class with progress tracking and serialization.
 */

import { ResourceType } from './Resource';
import { EnemyType } from './Enemy';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

export enum MissionType {
  Story = 'Story',
  Expedition = 'Expedition',
  Defense = 'Defense',
  Recovery = 'Recovery',
}

export enum MissionDifficulty {
  Easy = 'Easy',
  Normal = 'Normal',
  Hard = 'Hard',
  Elite = 'Elite',
  Nightmare = 'Nightmare',
}

/** Minimum recommended squad power per difficulty tier. */
export const DIFFICULTY_RECOMMENDED_POWER: Readonly<Record<MissionDifficulty, number>> = {
  [MissionDifficulty.Easy]:      400,
  [MissionDifficulty.Normal]:    1000,
  [MissionDifficulty.Hard]:      2200,
  [MissionDifficulty.Elite]:     4000,
  [MissionDifficulty.Nightmare]: 6500,
};

// ---------------------------------------------------------------------------
// Objectives
// ---------------------------------------------------------------------------

export interface MissionObjective {
  id: string;
  description: string;
  targetCount: number;
  currentCount: number;
  isOptional: boolean;
}

export interface MissionObjectiveJSON {
  id: string;
  description: string;
  targetCount: number;
  currentCount: number;
  isOptional: boolean;
}

// ---------------------------------------------------------------------------
// Rewards
// ---------------------------------------------------------------------------

export interface MissionReward {
  resources: Map<ResourceType, number>;
  experiencePoints: number;
  heroUnlockId?: string;
  blueprintId?: string;
}

export interface MissionRewardJSON {
  resources: Record<string, number>;
  experiencePoints: number;
  heroUnlockId?: string;
  blueprintId?: string;
}

// ---------------------------------------------------------------------------
// Threats
// ---------------------------------------------------------------------------

export interface MissionThreat {
  enemyComposition: Map<EnemyType, number>;
  hasBoss: boolean;
  bossType?: EnemyType;
}

export interface MissionThreatJSON {
  enemyComposition: Record<string, number>;
  hasBoss: boolean;
  bossType?: string;
}

// ---------------------------------------------------------------------------
// Serialization shape
// ---------------------------------------------------------------------------

export interface MissionJSON {
  id: string;
  name: string;
  description: string;
  type: MissionType;
  difficulty: MissionDifficulty;
  districtId: string;
  objectives: MissionObjectiveJSON[];
  rewards: MissionRewardJSON;
  threat: MissionThreatJSON;
  timeLimit: number;
  elapsedTime: number;
  isStarted: boolean;
  isFailed: boolean;
  isCompleted: boolean;
  recommendedPower: number;
}

// ---------------------------------------------------------------------------
// Mission class
// ---------------------------------------------------------------------------

export class Mission {
  public id: string;
  public name: string;
  public description: string;
  public type: MissionType;
  public difficulty: MissionDifficulty;
  public districtId: string;
  public objectives: MissionObjective[];
  public rewards: MissionReward;
  public threat: MissionThreat;
  /** Time limit in seconds. 0 = no limit. */
  public timeLimit: number;
  /** Elapsed time in seconds. */
  public elapsedTime: number;
  public isStarted: boolean;
  public isFailed: boolean;

  constructor(params: {
    id: string;
    name: string;
    description: string;
    type: MissionType;
    difficulty: MissionDifficulty;
    districtId: string;
    objectives: MissionObjective[];
    rewards: MissionReward;
    threat: MissionThreat;
    timeLimit?: number;
    elapsedTime?: number;
    isStarted?: boolean;
    isFailed?: boolean;
  }) {
    this.id = params.id;
    this.name = params.name;
    this.description = params.description;
    this.type = params.type;
    this.difficulty = params.difficulty;
    this.districtId = params.districtId;
    this.objectives = params.objectives.map(o => ({ ...o }));
    this.rewards = {
      resources: new Map(params.rewards.resources),
      experiencePoints: params.rewards.experiencePoints,
      heroUnlockId: params.rewards.heroUnlockId,
      blueprintId: params.rewards.blueprintId,
    };
    this.threat = {
      enemyComposition: new Map(params.threat.enemyComposition),
      hasBoss: params.threat.hasBoss,
      bossType: params.threat.bossType,
    };
    this.timeLimit = params.timeLimit ?? 0;
    this.elapsedTime = params.elapsedTime ?? 0;
    this.isStarted = params.isStarted ?? false;
    this.isFailed = params.isFailed ?? false;
  }

  // -----------------------------------------------------------------------
  // Computed properties
  // -----------------------------------------------------------------------

  /** Recommended squad power based on difficulty. */
  get recommendedPower(): number {
    return DIFFICULTY_RECOMMENDED_POWER[this.difficulty];
  }

  /**
   * A mission is completed when all required (non-optional) objectives
   * have met their target count and the mission has not failed.
   */
  get isCompleted(): boolean {
    if (this.isFailed) return false;
    return this.objectives
      .filter(o => !o.isOptional)
      .every(o => o.currentCount >= o.targetCount);
  }

  /** Fraction of required objectives completed, 0-1. */
  get progress(): number {
    const required = this.objectives.filter(o => !o.isOptional);
    if (required.length === 0) return 1;
    const total = required.reduce((sum, o) => sum + o.targetCount, 0);
    const current = required.reduce(
      (sum, o) => sum + Math.min(o.currentCount, o.targetCount),
      0,
    );
    return total > 0 ? current / total : 0;
  }

  /** Whether the time limit has been exceeded. */
  get isTimedOut(): boolean {
    return this.timeLimit > 0 && this.elapsedTime >= this.timeLimit;
  }

  // -----------------------------------------------------------------------
  // Progress tracking
  // -----------------------------------------------------------------------

  /**
   * Advance progress on a specific objective.
   * @param objectiveId - ID of the objective to update.
   * @param amount - Increment value.
   */
  advanceObjective(objectiveId: string, amount: number = 1): void {
    const obj = this.objectives.find(o => o.id === objectiveId);
    if (!obj) return;
    obj.currentCount = Math.min(obj.currentCount + amount, obj.targetCount);
  }

  /** Mark the mission as failed. */
  fail(): void {
    this.isFailed = true;
  }

  /** Update elapsed time. If timed out, auto-fail. */
  tick(deltaSeconds: number): void {
    if (!this.isStarted || this.isFailed || this.isCompleted) return;
    this.elapsedTime += deltaSeconds;
    if (this.isTimedOut) {
      this.fail();
    }
  }

  // -----------------------------------------------------------------------
  // Serialization
  // -----------------------------------------------------------------------

  toJSON(): MissionJSON {
    const resourcesObj: Record<string, number> = {};
    for (const [rt, amt] of this.rewards.resources) {
      resourcesObj[rt] = amt;
    }

    const compositionObj: Record<string, number> = {};
    for (const [et, count] of this.threat.enemyComposition) {
      compositionObj[et] = count;
    }

    return {
      id: this.id,
      name: this.name,
      description: this.description,
      type: this.type,
      difficulty: this.difficulty,
      districtId: this.districtId,
      objectives: this.objectives.map(o => ({ ...o })),
      rewards: {
        resources: resourcesObj,
        experiencePoints: this.rewards.experiencePoints,
        heroUnlockId: this.rewards.heroUnlockId,
        blueprintId: this.rewards.blueprintId,
      },
      threat: {
        enemyComposition: compositionObj,
        hasBoss: this.threat.hasBoss,
        bossType: this.threat.bossType,
      },
      timeLimit: this.timeLimit,
      elapsedTime: this.elapsedTime,
      isStarted: this.isStarted,
      isFailed: this.isFailed,
      isCompleted: this.isCompleted,
      recommendedPower: this.recommendedPower,
    };
  }

  static fromJSON(data: MissionJSON): Mission {
    const resources = new Map<ResourceType, number>();
    for (const [key, val] of Object.entries(data.rewards.resources)) {
      resources.set(key as ResourceType, val);
    }

    const enemyComposition = new Map<EnemyType, number>();
    for (const [key, val] of Object.entries(data.threat.enemyComposition)) {
      enemyComposition.set(key as EnemyType, val);
    }

    return new Mission({
      id: data.id,
      name: data.name,
      description: data.description,
      type: data.type,
      difficulty: data.difficulty,
      districtId: data.districtId,
      objectives: data.objectives.map(o => ({ ...o })),
      rewards: {
        resources,
        experiencePoints: data.rewards.experiencePoints,
        heroUnlockId: data.rewards.heroUnlockId,
        blueprintId: data.rewards.blueprintId,
      },
      threat: {
        enemyComposition,
        hasBoss: data.threat.hasBoss,
        bossType: data.threat.bossType as EnemyType | undefined,
      },
      timeLimit: data.timeLimit,
      elapsedTime: data.elapsedTime,
      isStarted: data.isStarted,
      isFailed: data.isFailed,
    });
  }
}
