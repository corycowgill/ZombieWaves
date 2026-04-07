/**
 * District.ts — World map district model for Project Ashfall.
 *
 * Districts represent explorable zones on the world map. Each has a biome,
 * threat level, fog of war, missions, resource nodes, and survivor counts.
 */

import { ResourceType } from './Resource';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

export enum BiomeType {
  Suburban = 'Suburban',
  Highway = 'Highway',
  Industrial = 'Industrial',
  Hospital = 'Hospital',
  Military = 'Military',
  Flooded = 'Flooded',
  Underground = 'Underground',
  Farmland = 'Farmland',
  Docks = 'Docks',
  Mall = 'Mall',
}

export enum ThreatLevel {
  Low = 'Low',
  Medium = 'Medium',
  High = 'High',
  Extreme = 'Extreme',
  Boss = 'Boss',
}

/** Numeric power recommendation per threat level. */
export const THREAT_RECOMMENDED_POWER: Readonly<Record<ThreatLevel, number>> = {
  [ThreatLevel.Low]:     500,
  [ThreatLevel.Medium]:  1200,
  [ThreatLevel.High]:    2500,
  [ThreatLevel.Extreme]: 4500,
  [ThreatLevel.Boss]:    7000,
};

// ---------------------------------------------------------------------------
// Serialization shape
// ---------------------------------------------------------------------------

export interface DistrictJSON {
  id: string;
  name: string;
  biome: BiomeType;
  threatLevel: ThreatLevel;
  isCleared: boolean;
  isRevealed: boolean;
  fogLevel: number;
  mainMissionId: string | null;
  sideMissionIds: string[];
  resourceNodeTypes: ResourceType[];
  survivorCount: number;
  position: { x: number; y: number };
}

// ---------------------------------------------------------------------------
// District class
// ---------------------------------------------------------------------------

export class District {
  public id: string;
  public name: string;
  public biome: BiomeType;
  public threatLevel: ThreatLevel;
  public isCleared: boolean;
  public isRevealed: boolean;
  /** Fog of war level: 0 = fully visible, 1 = fully obscured. */
  public fogLevel: number;
  public mainMissionId: string | null;
  public sideMissionIds: string[];
  public resourceNodeTypes: ResourceType[];
  public survivorCount: number;
  public position: { x: number; y: number };

  constructor(params: {
    id: string;
    name: string;
    biome: BiomeType;
    threatLevel: ThreatLevel;
    isCleared?: boolean;
    isRevealed?: boolean;
    fogLevel?: number;
    mainMissionId?: string | null;
    sideMissionIds?: string[];
    resourceNodeTypes?: ResourceType[];
    survivorCount?: number;
    position: { x: number; y: number };
  }) {
    this.id = params.id;
    this.name = params.name;
    this.biome = params.biome;
    this.threatLevel = params.threatLevel;
    this.isCleared = params.isCleared ?? false;
    this.isRevealed = params.isRevealed ?? false;
    this.fogLevel = Math.max(0, Math.min(1, params.fogLevel ?? 1));
    this.mainMissionId = params.mainMissionId ?? null;
    this.sideMissionIds = params.sideMissionIds ?? [];
    this.resourceNodeTypes = params.resourceNodeTypes ?? [];
    this.survivorCount = params.survivorCount ?? 0;
    this.position = { ...params.position };
  }

  // -----------------------------------------------------------------------
  // Convenience
  // -----------------------------------------------------------------------

  /** Whether the district has any remaining missions. */
  hasActiveMissions(): boolean {
    return this.mainMissionId !== null || this.sideMissionIds.length > 0;
  }

  /** Reveal this district, reducing fog to 0. */
  reveal(): void {
    this.isRevealed = true;
    this.fogLevel = 0;
  }

  /** Partially reduce fog by a given fraction (0-1). */
  reduceFog(amount: number): void {
    this.fogLevel = Math.max(0, this.fogLevel - amount);
    if (this.fogLevel <= 0) {
      this.isRevealed = true;
    }
  }

  /** Mark this district as cleared. */
  clear(): void {
    this.isCleared = true;
    this.reveal();
  }

  // -----------------------------------------------------------------------
  // Serialization
  // -----------------------------------------------------------------------

  toJSON(): DistrictJSON {
    return {
      id: this.id,
      name: this.name,
      biome: this.biome,
      threatLevel: this.threatLevel,
      isCleared: this.isCleared,
      isRevealed: this.isRevealed,
      fogLevel: this.fogLevel,
      mainMissionId: this.mainMissionId,
      sideMissionIds: [...this.sideMissionIds],
      resourceNodeTypes: [...this.resourceNodeTypes],
      survivorCount: this.survivorCount,
      position: { ...this.position },
    };
  }

  static fromJSON(data: DistrictJSON): District {
    return new District({
      id: data.id,
      name: data.name,
      biome: data.biome,
      threatLevel: data.threatLevel,
      isCleared: data.isCleared,
      isRevealed: data.isRevealed,
      fogLevel: data.fogLevel,
      mainMissionId: data.mainMissionId,
      sideMissionIds: [...data.sideMissionIds],
      resourceNodeTypes: [...data.resourceNodeTypes],
      survivorCount: data.survivorCount,
      position: { ...data.position },
    });
  }
}
