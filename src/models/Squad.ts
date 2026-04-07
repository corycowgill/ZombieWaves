/**
 * Squad.ts — Squad system for Project Ashfall.
 *
 * Squads are groups of up to 5 heroes deployed together for combat
 * missions and exploration. Formations and hero bonds provide
 * tactical bonuses.
 */

import { Hero, HeroJSON, HeroStats } from './Hero';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

export enum FormationType {
  Balanced = 'Balanced',
  Aggressive = 'Aggressive',
  Defensive = 'Defensive',
  Flanking = 'Flanking',
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const MAX_SQUAD_SIZE = 5;

/** Stat multipliers applied per formation. */
const FORMATION_BONUSES: Readonly<Record<FormationType, Partial<HeroStats>>> = {
  [FormationType.Balanced]: {
    attack: 5,
    defense: 5,
    speed: 5,
  },
  [FormationType.Aggressive]: {
    attack: 15,
    critChance: 0.05,
    speed: 5,
    defense: -5,
  },
  [FormationType.Defensive]: {
    defense: 15,
    maxHealth: 50,
    attack: -5,
  },
  [FormationType.Flanking]: {
    speed: 15,
    critChance: 0.08,
    critMultiplier: 0.2,
    defense: -10,
  },
};

// ---------------------------------------------------------------------------
// Serialization shape
// ---------------------------------------------------------------------------

export interface SquadJSON {
  id: string;
  name: string;
  memberIds: string[];
  formation: FormationType;
  supportUnits: string[];
  isDeployed: boolean;
}

// ---------------------------------------------------------------------------
// Squad class
// ---------------------------------------------------------------------------

export class Squad {
  public id: string;
  public name: string;
  public heroes: Hero[];
  public formation: FormationType;
  public supportUnits: string[];
  public isDeployed: boolean;

  constructor(
    id: string,
    name: string,
    formation: FormationType = FormationType.Balanced,
  ) {
    this.id = id;
    this.name = name;
    this.heroes = [];
    this.formation = formation;
    this.supportUnits = [];
    this.isDeployed = false;
  }

  // -----------------------------------------------------------------------
  // Hero management
  // -----------------------------------------------------------------------

  /**
   * Add a hero to this squad if there is room and they are not already
   * a member. Returns `true` on success.
   */
  addHero(hero: Hero): boolean {
    if (this.heroes.length >= MAX_SQUAD_SIZE) return false;
    if (this.heroes.some(h => h.id === hero.id)) return false;
    this.heroes.push(hero);
    return true;
  }

  /** Remove a hero by ID. Returns `true` if they were found and removed. */
  removeHero(id: string): boolean {
    const idx = this.heroes.findIndex(h => h.id === id);
    if (idx === -1) return false;
    this.heroes.splice(idx, 1);
    return true;
  }

  isEmpty(): boolean {
    return this.heroes.length === 0;
  }

  isFull(): boolean {
    return this.heroes.length >= MAX_SQUAD_SIZE;
  }

  // -----------------------------------------------------------------------
  // Power calculation
  // -----------------------------------------------------------------------

  /**
   * Compute an aggregate power score for the squad.
   * Sums each hero's effective stats with weighted contribution.
   */
  getTotalPower(): number {
    let total = 0;
    for (const hero of this.heroes) {
      const s = hero.getEffectiveStats();
      total +=
        s.maxHealth +
        s.attack * 3 +
        s.defense * 2 +
        s.speed * 1.5 +
        s.critChance * 100 +
        s.critMultiplier * 50;
    }
    return Math.round(total);
  }

  // -----------------------------------------------------------------------
  // Bond bonuses
  // -----------------------------------------------------------------------

  /**
   * Evaluate bond partnerships within the squad.
   * If two heroes list each other as bond partners and both are present,
   * they each receive a flat stat bonus.
   *
   * Returns an array of { heroId, bonuses } for heroes who have an
   * active bond in this squad.
   */
  getBondBonuses(): Array<{ heroId: string; bonuses: Partial<HeroStats> }> {
    const results: Array<{ heroId: string; bonuses: Partial<HeroStats> }> = [];
    const memberIds = new Set(this.heroes.map(h => h.id));

    for (const hero of this.heroes) {
      let activeBonds = 0;
      for (const partnerId of hero.bondPartnerIds) {
        if (memberIds.has(partnerId)) {
          activeBonds++;
        }
      }

      if (activeBonds > 0) {
        // Each active bond gives +5 ATK, +5 DEF, +3 SPD
        results.push({
          heroId: hero.id,
          bonuses: {
            attack: 5 * activeBonds,
            defense: 5 * activeBonds,
            speed: 3 * activeBonds,
          },
        });
      }
    }

    return results;
  }

  // -----------------------------------------------------------------------
  // Formation bonuses
  // -----------------------------------------------------------------------

  /**
   * Return the stat bonuses granted by the current formation.
   * These are flat values added to each hero's effective stats
   * during combat.
   */
  getFormationBonuses(): Partial<HeroStats> {
    return { ...FORMATION_BONUSES[this.formation] };
  }

  // -----------------------------------------------------------------------
  // Serialization
  // -----------------------------------------------------------------------

  toJSON(): SquadJSON {
    return {
      id: this.id,
      name: this.name,
      memberIds: this.heroes.map(h => h.id),
      formation: this.formation,
      supportUnits: [...this.supportUnits],
      isDeployed: this.isDeployed,
    };
  }

  /**
   * Reconstitute a Squad from serialized data.
   * Requires a lookup map so hero references can be restored.
   */
  static fromJSON(data: SquadJSON, heroLookup: Map<string, Hero>): Squad {
    const squad = new Squad(data.id, data.name, data.formation);
    squad.isDeployed = data.isDeployed;
    squad.supportUnits = [...(data.supportUnits ?? [])];
    for (const hid of data.memberIds) {
      const hero = heroLookup.get(hid);
      if (hero) squad.heroes.push(hero);
    }
    return squad;
  }
}
