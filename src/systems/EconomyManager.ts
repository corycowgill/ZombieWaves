/**
 * EconomyManager.ts — Economy system for Project Ashfall.
 */

import { ResourceType, ResourceInventory } from '../models/Resource';

export class EconomyManager {
  private inventory: ResourceInventory;

  constructor(inventory: ResourceInventory) {
    this.inventory = inventory;
  }

  getProductionRates(): Map<ResourceType, number> {
    const rates = new Map<ResourceType, number>();
    for (const rt of Object.values(ResourceType)) {
      rates.set(rt, 0);
    }
    return rates;
  }

  canAfford(costs: Map<ResourceType, number>): boolean {
    return this.inventory.canAfford(costs);
  }

  spend(costs: Map<ResourceType, number>): boolean {
    return this.inventory.spendMultiple(costs);
  }

  earn(type: ResourceType, amount: number): void {
    this.inventory.add(type, amount);
  }
}
