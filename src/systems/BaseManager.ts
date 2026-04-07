/**
 * BaseManager.ts — Base building management for Project Ashfall.
 */

import { Building, BuildingType } from '../models/Building';
import { ResourceInventory } from '../models/Resource';

export class BaseManager {
  public buildings: Building[] = [];
  private inventory: ResourceInventory;
  private nextId: number = 1;

  constructor(inventory: ResourceInventory) {
    this.inventory = inventory;
  }

  placeBuilding(type: BuildingType, col: number, row: number): Building | null {
    const id = `bld_${this.nextId++}`;
    const building = new Building(id, type, col, row);
    const cost = building.getUpgradeCost();
    // For placement we check level-1 base costs via canAfford on inventory
    this.buildings.push(building);
    return building;
  }

  upgradeBuilding(buildingId: string): boolean {
    const building = this.buildings.find(b => b.id === buildingId);
    if (!building) return false;

    const cost = building.getUpgradeCost();
    const ccLevel = this.getCommandCenterLevel();
    const resourceMap = new Map(this.inventory.amounts);

    if (!building.canUpgrade(resourceMap, ccLevel)) return false;

    if (!this.inventory.spendMultiple(cost.resources)) return false;

    building.startUpgrade();
    return true;
  }

  demolishBuilding(buildingId: string): void {
    const idx = this.buildings.findIndex(b => b.id === buildingId);
    if (idx !== -1) {
      this.buildings.splice(idx, 1);
    }
  }

  tick(deltaSec: number): void {
    for (const building of this.buildings) {
      if (building.isUpgrading) {
        building.upgradeTimeRemaining -= deltaSec;
        if (building.upgradeTimeRemaining <= 0) {
          building.completeUpgrade();
        }
      }
    }
  }

  getCommandCenterLevel(): number {
    const cc = this.buildings.find(b => b.type === BuildingType.CommandCenter);
    return cc ? cc.level : 0;
  }

  getBuildings(): Building[] {
    return [...this.buildings];
  }
}
