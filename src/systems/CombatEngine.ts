/**
 * CombatEngine.ts — Combat system for Project Ashfall.
 */

import { Hero } from '../models/Hero';
import { Enemy } from '../models/Enemy';

export enum CombatState {
  Preparing = 'Preparing',
  InProgress = 'InProgress',
  Paused = 'Paused',
  Victory = 'Victory',
  Defeat = 'Defeat',
  Retreated = 'Retreated',
}

export class CombatEngine {
  public state: CombatState = CombatState.Preparing;
  public playerUnits: Hero[] = [];
  public enemyUnits: Enemy[] = [];
  public isAutoBattle: boolean = false;

  startCombat(heroes: Hero[], enemies: Enemy[]): void {
    this.playerUnits = [...heroes];
    this.enemyUnits = [...enemies];
    this.state = CombatState.InProgress;
  }

  processFrame(deltaTime: number): void {
    if (this.state !== CombatState.InProgress) return;

    // Check victory / defeat conditions
    const allEnemiesDead = this.enemyUnits.every(e => e.isDead());
    if (allEnemiesDead) {
      this.state = CombatState.Victory;
      return;
    }

    // Minimal auto-battle tick: each hero attacks first alive enemy
    if (this.isAutoBattle) {
      for (const hero of this.playerUnits) {
        const target = this.enemyUnits.find(e => !e.isDead());
        if (target) {
          const stats = hero.getEffectiveStats();
          target.takeDamage(stats.attack * deltaTime);
        }
      }
    }
  }

  activateSkill(unitId: string, skillIndex: number, targetId: string): void {
    if (this.state !== CombatState.InProgress) return;

    const hero = this.playerUnits.find(h => h.id === unitId);
    if (!hero) return;

    const skill = hero.skills[skillIndex];
    if (!skill || skill.currentCooldown > 0) return;

    const target = this.enemyUnits.find(e => e.id === targetId);
    if (target && skill.damage > 0) {
      target.takeDamage(skill.damage);
    }
    skill.currentCooldown = skill.cooldown;
  }

  pause(): void {
    if (this.state === CombatState.InProgress) {
      this.state = CombatState.Paused;
    }
  }

  resume(): void {
    if (this.state === CombatState.Paused) {
      this.state = CombatState.InProgress;
    }
  }

  retreat(): void {
    if (this.state === CombatState.InProgress || this.state === CombatState.Paused) {
      this.state = CombatState.Retreated;
    }
  }

  setAutoMode(on: boolean): void {
    this.isAutoBattle = on;
  }
}
