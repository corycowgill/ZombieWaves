/**
 * SaveManager.ts — Save / load system for Project Ashfall.
 */

export interface SaveSlot {
  id: number;
  name: string;
  timestamp: number;
  playtime: number;
  commanderLevel: number;
  currentAct: string;
  data: string;
}

export class SaveManager {
  private slots: Map<number, SaveSlot> = new Map();

  save(
    slotId: number,
    data: { commanderLevel: number; currentAct: string; playtime: number; data: string },
  ): void {
    const slot: SaveSlot = {
      id: slotId,
      name: `Save ${slotId}`,
      timestamp: Date.now(),
      playtime: data.playtime,
      commanderLevel: data.commanderLevel,
      currentAct: data.currentAct,
      data: data.data,
    };
    this.slots.set(slotId, slot);
  }

  load(slotId: number): SaveSlot | null {
    return this.slots.get(slotId) ?? null;
  }

  listSaves(): SaveSlot[] {
    return Array.from(this.slots.values());
  }

  deleteSave(slotId: number): void {
    this.slots.delete(slotId);
  }

  hasSaveData(): boolean {
    return this.slots.size > 0;
  }
}
