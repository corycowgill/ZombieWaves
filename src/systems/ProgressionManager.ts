/**
 * ProgressionManager.ts — Progression tracking for Project Ashfall.
 */

export class ProgressionManager {
  public commanderLevel: number = 1;
  public commanderXP: number = 0;
  public completedMissions: string[] = [];

  private xpForLevel(level: number): number {
    return 500 + level * level * 50;
  }

  addCommanderXP(amount: number): void {
    if (amount <= 0) return;
    this.commanderXP += amount;
    while (this.commanderXP >= this.xpForLevel(this.commanderLevel)) {
      this.commanderXP -= this.xpForLevel(this.commanderLevel);
      this.commanderLevel++;
    }
  }

  completeMission(missionId: string): void {
    if (!this.completedMissions.includes(missionId)) {
      this.completedMissions.push(missionId);
    }
  }
}
