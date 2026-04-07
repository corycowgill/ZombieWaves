/**
 * Resource.ts — Resource types and inventory management for Project Ashfall.
 *
 * Tracks all resource currencies used for building, crafting, upgrading,
 * and mission rewards. Supports serialization for save/load.
 */

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

export enum ResourceType {
  Food = 'Food',
  Water = 'Water',
  Fuel = 'Fuel',
  Scrap = 'Scrap',
  Electronics = 'Electronics',
  Medicine = 'Medicine',
  BioSamples = 'BioSamples',
  MilitaryComponents = 'MilitaryComponents',
  PowerCells = 'PowerCells',
  ResearchData = 'ResearchData',
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const RARE_RESOURCES: ReadonlySet<ResourceType> = new Set([
  ResourceType.BioSamples,
  ResourceType.MilitaryComponents,
  ResourceType.PowerCells,
  ResourceType.ResearchData,
]);

/** Returns `true` when the given resource is classified as rare. */
export function isRare(type: ResourceType): boolean {
  return RARE_RESOURCES.has(type);
}

/** Default amounts granted at game start. */
export const STARTING_RESOURCES: ReadonlyMap<ResourceType, number> = new Map([
  [ResourceType.Food, 500],
  [ResourceType.Water, 500],
  [ResourceType.Fuel, 200],
  [ResourceType.Scrap, 300],
  [ResourceType.Electronics, 50],
  [ResourceType.Medicine, 100],
  [ResourceType.BioSamples, 0],
  [ResourceType.MilitaryComponents, 0],
  [ResourceType.PowerCells, 0],
  [ResourceType.ResearchData, 0],
]);

// ---------------------------------------------------------------------------
// Serialization shape
// ---------------------------------------------------------------------------

export interface ResourceInventoryJSON {
  amounts: Record<string, number>;
}

// ---------------------------------------------------------------------------
// ResourceInventory
// ---------------------------------------------------------------------------

export class ResourceInventory {
  public amounts: Map<ResourceType, number>;

  constructor(initial?: Map<ResourceType, number>) {
    this.amounts = new Map<ResourceType, number>();

    // Seed every resource type with 0, then overlay provided values.
    for (const rt of Object.values(ResourceType)) {
      this.amounts.set(rt, 0);
    }

    if (initial) {
      for (const [rt, amt] of initial) {
        this.amounts.set(rt, amt);
      }
    }
  }

  // -----------------------------------------------------------------------
  // Factory helpers
  // -----------------------------------------------------------------------

  /** Create an inventory pre-loaded with the default starting amounts. */
  static createStartingInventory(): ResourceInventory {
    return new ResourceInventory(new Map(STARTING_RESOURCES));
  }

  // -----------------------------------------------------------------------
  // Accessors / mutators
  // -----------------------------------------------------------------------

  /** Get the current amount of a specific resource. */
  getAmount(type: ResourceType): number {
    return this.amounts.get(type) ?? 0;
  }

  /**
   * Add a positive `amount` of the given resource.
   * Negative values are silently ignored.
   */
  add(type: ResourceType, amount: number): void {
    if (amount <= 0) return;
    this.amounts.set(type, this.getAmount(type) + amount);
  }

  /**
   * Spend `amount` of the given resource.
   * @returns `true` if the spend succeeded, `false` if insufficient.
   */
  spend(type: ResourceType, amount: number): boolean {
    if (amount <= 0) return true;
    const current = this.getAmount(type);
    if (current < amount) return false;
    this.amounts.set(type, current - amount);
    return true;
  }

  /**
   * Check whether the inventory can cover **all** entries in `costs`.
   */
  canAfford(costs: Map<ResourceType, number>): boolean {
    for (const [rt, needed] of costs) {
      if (this.getAmount(rt) < needed) return false;
    }
    return true;
  }

  /**
   * Atomically deduct multiple resource costs.
   * @returns `true` if all costs were deducted, `false` (no-op) otherwise.
   */
  spendMultiple(costs: Map<ResourceType, number>): boolean {
    if (!this.canAfford(costs)) return false;
    for (const [rt, needed] of costs) {
      this.spend(rt, needed);
    }
    return true;
  }

  // -----------------------------------------------------------------------
  // Serialization
  // -----------------------------------------------------------------------

  toJSON(): ResourceInventoryJSON {
    const amounts: Record<string, number> = {};
    for (const [rt, amt] of this.amounts) {
      amounts[rt] = amt;
    }
    return { amounts };
  }

  static fromJSON(data: ResourceInventoryJSON): ResourceInventory {
    const map = new Map<ResourceType, number>();
    for (const [key, val] of Object.entries(data.amounts)) {
      if (Object.values(ResourceType).includes(key as ResourceType)) {
        map.set(key as ResourceType, val);
      }
    }
    return new ResourceInventory(map);
  }
}
