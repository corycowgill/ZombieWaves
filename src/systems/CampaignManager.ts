/**
 * CampaignManager.ts — Campaign / story progression for Project Ashfall.
 */

export enum CampaignAct {
  Act1 = 'Act1',
  Act2 = 'Act2',
  Act3 = 'Act3',
  Act4 = 'Act4',
  Act5 = 'Act5',
}

const ACT_NAMES: Record<CampaignAct, string> = {
  [CampaignAct.Act1]: 'The Fall',
  [CampaignAct.Act2]: 'Rising Smoke',
  [CampaignAct.Act3]: 'Dead Zone',
  [CampaignAct.Act4]: 'The Reckoning',
  [CampaignAct.Act5]: 'Ashfall',
};

const ACT_ORDER: CampaignAct[] = [
  CampaignAct.Act1,
  CampaignAct.Act2,
  CampaignAct.Act3,
  CampaignAct.Act4,
  CampaignAct.Act5,
];

export class CampaignManager {
  public currentAct: CampaignAct = CampaignAct.Act1;
  public currentChapter: number = 1;
  public storyFlags: Map<string, boolean> = new Map();

  startNewCampaign(): void {
    this.currentAct = CampaignAct.Act1;
    this.currentChapter = 1;
    this.storyFlags.clear();
  }

  advanceStory(): void {
    this.currentChapter++;
    // After chapter 5, advance to next act
    if (this.currentChapter > 5) {
      const idx = ACT_ORDER.indexOf(this.currentAct);
      if (idx < ACT_ORDER.length - 1) {
        this.currentAct = ACT_ORDER[idx + 1];
        this.currentChapter = 1;
      }
    }
  }

  getCurrentActName(): string {
    return ACT_NAMES[this.currentAct];
  }

  makeDecision(decisionId: string, choiceIndex: number): void {
    this.storyFlags.set(`${decisionId}_choice`, true);
    this.storyFlags.set(`${decisionId}_index_${choiceIndex}`, true);
  }
}
