/**
 * ExplorationManager.ts — Exploration / fog-of-war system for Project Ashfall.
 */

import { District } from '../models/District';

export enum FogState {
  Hidden = 'Hidden',
  Revealed = 'Revealed',
  Explored = 'Explored',
}

export class ExplorationManager {
  public districts: District[] = [];
  public fogMap: Map<string, FogState> = new Map();

  revealDistrict(districtId: string): void {
    const district = this.districts.find(d => d.id === districtId);
    if (district) {
      district.reveal();
      this.fogMap.set(districtId, FogState.Revealed);
    }
  }

  clearDistrict(districtId: string): void {
    const district = this.districts.find(d => d.id === districtId);
    if (district) {
      district.clear();
      this.fogMap.set(districtId, FogState.Explored);
    }
  }

  getDistricts(): District[] {
    return [...this.districts];
  }
}
