/**
 * TutorialManager.ts — Interactive step-by-step tutorial for Project Ashfall.
 *
 * Guides new players through the core game loop with highlight spotlights,
 * instruction text, and "teach-by-doing" progression. Each step waits for
 * the player to perform the actual action before advancing.
 */

export interface TutorialStep {
  id: string;
  title: string;
  message: string;
  /** CSS selector of the element to spotlight (null = center screen message) */
  highlightSelector: string | null;
  /** Which game event completes this step (null = tap to continue) */
  completionEvent: string | null;
  /** Nav tab to ensure is active before showing this step */
  requiredScene?: string;
  /** Delay in ms before showing this step */
  delayMs?: number;
  /** Arrow direction pointing to the highlight target */
  arrowDirection?: 'up' | 'down' | 'left' | 'right';
}

const TUTORIAL_STEPS: TutorialStep[] = [
  // --- Welcome ---
  {
    id: 'welcome',
    title: 'Welcome, Commander',
    message: 'The world has fallen. You lead the last survivors. This shelter is all that stands between humanity and extinction.\n\nLet me show you how to survive.',
    highlightSelector: null,
    completionEvent: null,
  },

  // --- Resource Bar ---
  {
    id: 'resources-intro',
    title: 'Your Resources',
    message: 'This bar shows your supplies. Food, Water, Fuel, Scrap, Electronics, and Medicine — you need all of them to survive and rebuild.',
    highlightSelector: '#resource-bar',
    completionEvent: null,
    arrowDirection: 'up',
  },

  // --- Base View ---
  {
    id: 'base-intro',
    title: 'Your Base',
    message: 'This is your settlement. The Command Center is already built. Tap on it to see its details.',
    highlightSelector: '#game-container',
    completionEvent: 'buildingSelected',
    requiredScene: 'base',
    arrowDirection: 'down',
  },

  // --- Building Panel ---
  {
    id: 'building-panel',
    title: 'Building Info',
    message: 'Here you can see the building level, what it produces, and the cost to upgrade. Upgrading buildings is key to growing stronger.',
    highlightSelector: '#building-panel',
    completionEvent: null,
    arrowDirection: 'down',
  },

  // --- Build a Farm ---
  {
    id: 'build-farm',
    title: 'Build a Farm',
    message: 'Your survivors need food. Tap an empty tile on the base grid to place a new building, then select "Farm" from the build menu.',
    highlightSelector: '#game-container',
    completionEvent: 'buildingPlaced',
    requiredScene: 'base',
  },

  // --- Production Explanation ---
  {
    id: 'production-explain',
    title: 'Resource Production',
    message: 'Your Farm is now producing Food automatically. You\'ll see floating numbers showing resources being generated. Build more production buildings to increase your output.',
    highlightSelector: null,
    completionEvent: null,
  },

  // --- Navigate to Heroes ---
  {
    id: 'nav-heroes',
    title: 'Meet Your Heroes',
    message: 'Tap the Heroes tab to see your squad. Heroes are the named survivors who fight for you on missions.',
    highlightSelector: '[data-scene="heroes"]',
    completionEvent: 'phaseChanged',
    arrowDirection: 'down',
  },

  // --- Hero Overview ---
  {
    id: 'heroes-overview',
    title: 'Your Roster',
    message: 'Each hero has a unique role — Assault, Heavy, Recon, Medic, Engineer, Sniper, or Demolitions. Tap a hero card to see their full stats, skills, and story.',
    highlightSelector: '#game-container',
    completionEvent: 'heroSelected',
    requiredScene: 'heroes',
  },

  // --- Hero Detail ---
  {
    id: 'hero-detail',
    title: 'Hero Details',
    message: 'Here you can level up heroes, equip gear, unlock skills, and build bonds between squadmates. Stronger heroes mean harder missions become possible.',
    highlightSelector: '#hero-panel',
    completionEvent: null,
    arrowDirection: 'down',
  },

  // --- Navigate to Map ---
  {
    id: 'nav-map',
    title: 'The World Map',
    message: 'Tap the Map tab to see the surrounding territory. Each district holds missions, resources, and survivors waiting to be rescued.',
    highlightSelector: '[data-scene="world"]',
    completionEvent: 'phaseChanged',
    arrowDirection: 'down',
  },

  // --- World Map Overview ---
  {
    id: 'map-overview',
    title: 'Reclaim the Region',
    message: 'Districts glow when they\'re available to explore. Dark zones are hidden by fog of war — upgrade your Radar Tower to reveal them. Tap a district to see its threat level and rewards.',
    highlightSelector: '#game-container',
    completionEvent: null,
    requiredScene: 'world',
  },

  // --- Squad Tab ---
  {
    id: 'nav-squad',
    title: 'Assemble Your Squad',
    message: 'Before deploying on a mission, tap the Squad tab to choose which 5 heroes to bring. Formations and hero bonds give tactical bonuses.',
    highlightSelector: '[data-scene="squad"]',
    completionEvent: null,
    arrowDirection: 'down',
  },

  // --- Combat Preview ---
  {
    id: 'combat-preview',
    title: 'Combat Basics',
    message: 'In combat, your heroes fight in real-time. Tap a hero to select them, then tap a skill to activate it. Use Tactical Pause to plan your moves. Auto-Battle lets the AI handle things if you prefer.',
    highlightSelector: null,
    completionEvent: null,
  },

  // --- Game Loop Summary ---
  {
    id: 'loop-summary',
    title: 'The Survival Loop',
    message: '1. Collect resources from your base\n2. Upgrade buildings and research tech\n3. Level up and equip your heroes\n4. Deploy squads on missions\n5. Clear districts and rescue survivors\n6. Expand your territory\n\nThat\'s the core loop. The rest you\'ll learn by playing.',
    highlightSelector: null,
    completionEvent: null,
  },

  // --- Tips ---
  {
    id: 'final-tips',
    title: 'Survival Tips',
    message: '- No timers or paywalls — play at your own pace\n- Losing a mission costs morale, not progress\n- Bond heroes together for combat bonuses\n- Random base events keep you on your toes\n- Save often — the wasteland is unforgiving\n\nGood luck, Commander. Rebuild what was lost.',
    highlightSelector: null,
    completionEvent: null,
  },
];

export class TutorialManager {
  private steps: TutorialStep[] = [...TUTORIAL_STEPS];
  private currentStepIndex: number = -1;
  private isActive: boolean = false;
  private isComplete: boolean = false;
  private overlay: HTMLElement | null = null;
  private onEventCallback: ((event: string) => void) | null = null;

  /** Callbacks the UIManager can register */
  private listeners: Map<string, ((...args: any[]) => void)[]> = new Map();

  constructor() {
    // Check if tutorial was already completed
    const saved = localStorage.getItem('ashfall_tutorial_complete');
    if (saved === 'true') {
      this.isComplete = true;
    }
  }

  public on(event: string, cb: (...args: any[]) => void): void {
    if (!this.listeners.has(event)) this.listeners.set(event, []);
    this.listeners.get(event)!.push(cb);
  }

  private emit(event: string, ...args: any[]): void {
    this.listeners.get(event)?.forEach(cb => cb(...args));
  }

  /** Start the tutorial sequence */
  public start(): void {
    if (this.isComplete) return;
    this.isActive = true;
    this.currentStepIndex = -1;
    this.createOverlay();
    this.nextStep();
  }

  /** Skip / dismiss the tutorial entirely */
  public skip(): void {
    this.isActive = false;
    this.isComplete = true;
    localStorage.setItem('ashfall_tutorial_complete', 'true');
    this.removeOverlay();
    this.emit('tutorialComplete');
  }

  /** Reset tutorial (for replaying from settings) */
  public reset(): void {
    this.isComplete = false;
    this.currentStepIndex = -1;
    localStorage.removeItem('ashfall_tutorial_complete');
  }

  /** Notify the tutorial that a game event occurred */
  public notifyEvent(event: string): void {
    if (!this.isActive) return;
    const step = this.getCurrentStep();
    if (step && step.completionEvent === event) {
      setTimeout(() => this.nextStep(), step.delayMs || 400);
    }
  }

  /** Whether the tutorial is currently running */
  public isRunning(): boolean {
    return this.isActive;
  }

  /** Whether it was completed previously */
  public wasCompleted(): boolean {
    return this.isComplete;
  }

  public getCurrentStep(): TutorialStep | null {
    if (this.currentStepIndex < 0 || this.currentStepIndex >= this.steps.length) return null;
    return this.steps[this.currentStepIndex];
  }

  // --- Step Progression ---

  private nextStep(): void {
    this.currentStepIndex++;
    if (this.currentStepIndex >= this.steps.length) {
      this.completeTutorial();
      return;
    }
    const step = this.steps[this.currentStepIndex];
    this.renderStep(step);
    this.emit('stepChanged', step);
  }

  private completeTutorial(): void {
    this.isActive = false;
    this.isComplete = true;
    localStorage.setItem('ashfall_tutorial_complete', 'true');
    this.removeOverlay();
    this.emit('tutorialComplete');
  }

  // --- DOM Rendering ---

  private createOverlay(): void {
    if (this.overlay) return;

    this.overlay = document.createElement('div');
    this.overlay.id = 'tutorial-overlay';
    this.overlay.innerHTML = `
      <div class="tutorial-backdrop" id="tutorial-backdrop"></div>
      <div class="tutorial-spotlight" id="tutorial-spotlight"></div>
      <div class="tutorial-card" id="tutorial-card">
        <div class="tutorial-step-indicator" id="tutorial-step-indicator"></div>
        <h3 class="tutorial-title" id="tutorial-title"></h3>
        <p class="tutorial-message" id="tutorial-message"></p>
        <div class="tutorial-actions">
          <button class="btn btn-secondary btn-small" id="tutorial-skip">Skip Tutorial</button>
          <button class="btn btn-primary btn-small" id="tutorial-next">Continue</button>
        </div>
      </div>
      <div class="tutorial-arrow" id="tutorial-arrow"></div>
    `;
    document.body.appendChild(this.overlay);

    document.getElementById('tutorial-skip')!.addEventListener('click', () => this.skip());
    document.getElementById('tutorial-next')!.addEventListener('click', () => {
      const step = this.getCurrentStep();
      if (step && !step.completionEvent) {
        this.nextStep();
      }
    });
  }

  private removeOverlay(): void {
    if (this.overlay) {
      this.overlay.remove();
      this.overlay = null;
    }
  }

  private renderStep(step: TutorialStep): void {
    if (!this.overlay) return;

    const title = document.getElementById('tutorial-title')!;
    const message = document.getElementById('tutorial-message')!;
    const nextBtn = document.getElementById('tutorial-next')!;
    const spotlight = document.getElementById('tutorial-spotlight')!;
    const arrow = document.getElementById('tutorial-arrow')!;
    const backdrop = document.getElementById('tutorial-backdrop')!;
    const indicator = document.getElementById('tutorial-step-indicator')!;
    const card = document.getElementById('tutorial-card')!;

    // Step indicator
    indicator.textContent = `${this.currentStepIndex + 1} / ${this.steps.length}`;

    // Title and message
    title.textContent = step.title;
    message.textContent = step.message;

    // Next button: show "Continue" for tap-to-advance, hide for event-based
    if (step.completionEvent) {
      nextBtn.style.display = 'none';
    } else {
      nextBtn.style.display = 'inline-block';
      nextBtn.textContent = this.currentStepIndex === this.steps.length - 1 ? 'Begin!' : 'Continue';
    }

    // Add passthrough class when the step requires interacting with the game
    if (step.completionEvent && step.highlightSelector) {
      this.overlay!.classList.add('passthrough');
    } else {
      this.overlay!.classList.remove('passthrough');
    }

    // Spotlight positioning
    if (step.highlightSelector) {
      const target = document.querySelector(step.highlightSelector) as HTMLElement;
      if (target) {
        const rect = target.getBoundingClientRect();
        spotlight.style.display = 'block';
        spotlight.style.top = `${rect.top - 8}px`;
        spotlight.style.left = `${rect.left - 8}px`;
        spotlight.style.width = `${rect.width + 16}px`;
        spotlight.style.height = `${rect.height + 16}px`;
        backdrop.style.display = 'block';

        // Position card below or above the spotlight
        if (rect.top > window.innerHeight / 2) {
          card.style.top = `${Math.max(80, rect.top - 220)}px`;
        } else {
          card.style.top = `${Math.min(rect.bottom + 20, window.innerHeight - 260)}px`;
        }
        card.style.left = '50%';
        card.style.transform = 'translateX(-50%)';

        // Arrow
        if (step.arrowDirection) {
          arrow.style.display = 'block';
          arrow.className = `tutorial-arrow arrow-${step.arrowDirection}`;
          switch (step.arrowDirection) {
            case 'up':
              arrow.style.top = `${rect.top - 30}px`;
              arrow.style.left = `${rect.left + rect.width / 2 - 10}px`;
              break;
            case 'down':
              arrow.style.top = `${rect.bottom + 5}px`;
              arrow.style.left = `${rect.left + rect.width / 2 - 10}px`;
              break;
            case 'left':
              arrow.style.top = `${rect.top + rect.height / 2 - 10}px`;
              arrow.style.left = `${rect.left - 30}px`;
              break;
            case 'right':
              arrow.style.top = `${rect.top + rect.height / 2 - 10}px`;
              arrow.style.left = `${rect.right + 5}px`;
              break;
          }
        } else {
          arrow.style.display = 'none';
        }
      } else {
        spotlight.style.display = 'none';
        backdrop.style.display = 'block';
        arrow.style.display = 'none';
        card.style.top = '50%';
        card.style.left = '50%';
        card.style.transform = 'translate(-50%, -50%)';
      }
    } else {
      // No highlight — center the card
      spotlight.style.display = 'none';
      backdrop.style.display = 'block';
      arrow.style.display = 'none';
      card.style.top = '50%';
      card.style.left = '50%';
      card.style.transform = 'translate(-50%, -50%)';
    }
  }
}
