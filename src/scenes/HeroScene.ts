/**
 * HeroScene.ts — Hero roster management view for Project Ashfall.
 *
 * Displays a scrollable grid of hero cards showing sprite, name, level,
 * role icon, and rank stars.  Supports role-based filtering, sorting,
 * and emits events so the HTML overlay can present detailed hero panels.
 * Locked heroes are shown as dark silhouettes with a "?" placeholder.
 */

import { Hero, HeroRole, HeroRarity } from '../models/Hero';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface HeroCard {
  container: Phaser.GameObjects.Container;
  hero: Hero;
}

type SortMode = 'level' | 'rarity' | 'name' | 'role';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const CARD_W = 105;
const CARD_H = 140;
const CARD_GAP = 10;
const COLS = 3;

/** Colours per hero role (for the role badge). */
const ROLE_COLOR: Record<HeroRole, number> = {
  [HeroRole.Assault]:     0xff4444,
  [HeroRole.Heavy]:       0x999999,
  [HeroRole.Recon]:       0x44cc44,
  [HeroRole.Medic]:       0xffffff,
  [HeroRole.Engineer]:    0xffd700,
  [HeroRole.Sniper]:      0x9966cc,
  [HeroRole.Demolitions]: 0xff8c00,
};

const ROLE_TEXTURE: Record<HeroRole, string> = {
  [HeroRole.Assault]:     'hero_assault',
  [HeroRole.Heavy]:       'hero_heavy',
  [HeroRole.Recon]:       'hero_recon',
  [HeroRole.Medic]:       'hero_medic',
  [HeroRole.Engineer]:    'hero_engineer',
  [HeroRole.Sniper]:      'hero_sniper',
  [HeroRole.Demolitions]: 'hero_demolitions',
};

const RARITY_SORT_ORDER: Record<HeroRarity, number> = {
  [HeroRarity.Common]:    0,
  [HeroRarity.Rare]:      1,
  [HeroRarity.Elite]:     2,
  [HeroRarity.Legendary]: 3,
};

const RARITY_BORDER_COLOR: Record<HeroRarity, number> = {
  [HeroRarity.Common]:    0x888888,
  [HeroRarity.Rare]:      0x4488ff,
  [HeroRarity.Elite]:     0xaa44ff,
  [HeroRarity.Legendary]: 0xffaa00,
};

// ---------------------------------------------------------------------------
// HeroScene
// ---------------------------------------------------------------------------

export default class HeroScene extends Phaser.Scene {
  private heroes: Hero[] = [];
  private cards: HeroCard[] = [];

  /** The scrollable container that holds all cards. */
  private scrollContainer: Phaser.GameObjects.Container | null = null;

  /** Current filter (null = show all). */
  private activeFilter: HeroRole | null = null;

  /** Current sort mode. */
  private sortMode: SortMode = 'level';

  /** Touch-scroll tracking. */
  private scrollY = 0;
  private dragStartY = 0;
  private isDragging = false;
  private maxScrollY = 0;

  /** Filter button references for highlight toggling. */
  private filterButtons: Map<string, Phaser.GameObjects.Text> = new Map();

  constructor() {
    super({ key: 'HeroScene' });
  }

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  init(data?: { heroes?: Hero[] }): void {
    this.heroes = data?.heroes ?? [];
    this.cards = [];
    this.activeFilter = null;
    this.sortMode = 'level';
    this.scrollY = 0;
  }

  create(): void {
    const { width } = this.scale;

    this.cameras.main.setBackgroundColor('#12121e');

    // Header
    this.createHeader(width);

    // Filter bar
    this.createFilterBar(width);

    // Sort bar
    this.createSortBar(width);

    // Scrollable card area
    this.scrollContainer = this.add.container(0, 0).setDepth(1);
    this.rebuildCards();

    // Scroll input
    this.setupScrollInput();

    this.game.events.emit('heroes:ready');
  }

  // -------------------------------------------------------------------------
  // Header
  // -------------------------------------------------------------------------

  private createHeader(width: number): void {
    // Back button
    this.add.text(15, 16, '< BACK', {
      fontSize: '13px',
      color: '#aaaacc',
      backgroundColor: '#2a2a3e',
      padding: { x: 8, y: 5 },
    }).setDepth(100).setInteractive()
      .on('pointerdown', () => this.scene.start('BaseScene'));

    // Title
    this.add.text(width / 2, 18, 'HEROES', {
      fontSize: '16px',
      fontStyle: 'bold',
      color: '#ffcc66',
      stroke: '#000000',
      strokeThickness: 2,
    }).setOrigin(0.5).setDepth(100);
  }

  // -------------------------------------------------------------------------
  // Filter bar
  // -------------------------------------------------------------------------

  private createFilterBar(width: number): void {
    const y = 50;
    const roles: Array<HeroRole | 'ALL'> = ['ALL', ...Object.values(HeroRole)];
    const btnW = Math.floor((width - 20) / roles.length);

    roles.forEach((role, i) => {
      const label = role === 'ALL' ? 'ALL' : role.substring(0, 4).toUpperCase();
      const bx = 10 + i * btnW + btnW / 2;

      const btn = this.add.text(bx, y, label, {
        fontSize: '9px',
        color: role === 'ALL' ? '#ffcc66' : '#aaaacc',
        backgroundColor: '#2a2a3e',
        padding: { x: 4, y: 4 },
      }).setOrigin(0.5).setDepth(100).setInteractive();

      btn.on('pointerdown', () => {
        this.activeFilter = role === 'ALL' ? null : role;
        this.updateFilterHighlights(role === 'ALL' ? 'ALL' : role);
        this.scrollY = 0;
        this.rebuildCards();
      });

      this.filterButtons.set(role, btn);
    });
  }

  private updateFilterHighlights(activeKey: string): void {
    for (const [key, btn] of this.filterButtons) {
      btn.setColor(key === activeKey ? '#ffcc66' : '#aaaacc');
    }
  }

  // -------------------------------------------------------------------------
  // Sort bar
  // -------------------------------------------------------------------------

  private createSortBar(width: number): void {
    const y = 74;
    const modes: SortMode[] = ['level', 'rarity', 'name', 'role'];

    this.add.text(10, y, 'Sort:', {
      fontSize: '9px',
      color: '#777799',
    }).setDepth(100);

    modes.forEach((mode, i) => {
      const bx = 50 + i * 60;
      const btn = this.add.text(bx, y, mode.toUpperCase(), {
        fontSize: '9px',
        color: mode === this.sortMode ? '#ffcc66' : '#888899',
        backgroundColor: '#222233',
        padding: { x: 4, y: 3 },
      }).setDepth(100).setInteractive();

      btn.on('pointerdown', () => {
        this.sortMode = mode;
        this.scrollY = 0;
        this.rebuildCards();
      });
    });
  }

  // -------------------------------------------------------------------------
  // Card grid
  // -------------------------------------------------------------------------

  private rebuildCards(): void {
    // Clear existing
    if (this.scrollContainer) {
      this.scrollContainer.removeAll(true);
    }
    this.cards = [];

    // Filter
    let filtered = this.activeFilter
      ? this.heroes.filter((h) => h.role === this.activeFilter)
      : [...this.heroes];

    // Sort
    filtered = this.sortHeroes(filtered);

    // Layout
    const startY = 95;
    const gridOffsetX = (this.scale.width - (COLS * (CARD_W + CARD_GAP) - CARD_GAP)) / 2;

    filtered.forEach((hero, i) => {
      const col = i % COLS;
      const row = Math.floor(i / COLS);
      const cx = gridOffsetX + col * (CARD_W + CARD_GAP) + CARD_W / 2;
      const cy = startY + row * (CARD_H + CARD_GAP) + CARD_H / 2;

      const card = this.createCard(hero, cx, cy);
      this.cards.push(card);
    });

    // Compute max scroll
    const totalRows = Math.ceil(filtered.length / COLS);
    const contentHeight = startY + totalRows * (CARD_H + CARD_GAP);
    this.maxScrollY = Math.max(0, contentHeight - this.scale.height + 20);
  }

  private createCard(hero: Hero, cx: number, cy: number): HeroCard {
    const container = this.add.container(cx, cy).setDepth(1);
    this.scrollContainer!.add(container);

    if (!hero.isUnlocked) {
      // Locked card — dark silhouette
      const bg = this.add.rectangle(0, 0, CARD_W, CARD_H, 0x111118, 0.9)
        .setStrokeStyle(1, 0x333344);
      container.add(bg);

      const qmark = this.add.text(0, -10, '?', {
        fontSize: '32px',
        fontStyle: 'bold',
        color: '#333344',
      }).setOrigin(0.5);
      container.add(qmark);

      const lockIcon = this.add.image(0, 30, 'ui_lock').setScale(0.8);
      container.add(lockIcon);

      // Make interactive so we can show unlock condition
      bg.setInteractive();
      bg.on('pointerdown', () => {
        this.game.events.emit('heroes:lockedTapped', hero);
        this.events.emit('lockedHeroTapped', hero);
      });

      return { container, hero };
    }

    // Unlocked card
    const rarityBorder = RARITY_BORDER_COLOR[hero.rarity] ?? 0x888888;
    const bg = this.add.rectangle(0, 0, CARD_W, CARD_H, 0x1e1e2e, 0.95)
      .setStrokeStyle(2, rarityBorder);
    container.add(bg);

    // Hero sprite
    const textureKey = ROLE_TEXTURE[hero.role] ?? 'hero_assault';
    const sprite = this.add.sprite(0, -30, textureKey).setScale(1.5);
    container.add(sprite);

    // Role badge (small coloured square)
    const roleColor = ROLE_COLOR[hero.role] ?? 0xaaaaaa;
    const roleBadge = this.add.rectangle(-CARD_W / 2 + 10, -CARD_H / 2 + 10, 14, 14, roleColor, 0.8);
    container.add(roleBadge);

    const roleLabel = this.add.text(-CARD_W / 2 + 10, -CARD_H / 2 + 10, hero.role.charAt(0), {
      fontSize: '8px',
      fontStyle: 'bold',
      color: '#000000',
    }).setOrigin(0.5);
    container.add(roleLabel);

    // Name
    const name = this.add.text(0, 5, hero.name, {
      fontSize: '10px',
      fontStyle: 'bold',
      color: '#ffffff',
      stroke: '#000000',
      strokeThickness: 1,
    }).setOrigin(0.5);
    container.add(name);

    // Level
    const level = this.add.text(0, 20, `Lv ${hero.level}`, {
      fontSize: '9px',
      color: '#88aacc',
    }).setOrigin(0.5);
    container.add(level);

    // Rank stars
    const maxRank = 5;
    const starStartX = -(maxRank * 12) / 2 + 6;
    for (let s = 0; s < maxRank; s++) {
      const filled = s < hero.rank;
      const starKey = filled ? 'ui_star' : 'ui_star_empty';
      const star = this.add.image(starStartX + s * 12, 36, starKey).setScale(0.9);
      container.add(star);
    }

    // Rarity label
    const rarityText = this.add.text(0, 52, hero.rarity, {
      fontSize: '8px',
      color: `#${rarityBorder.toString(16).padStart(6, '0')}`,
    }).setOrigin(0.5);
    container.add(rarityText);

    // Interaction
    bg.setInteractive();
    bg.on('pointerdown', () => {
      this.game.events.emit('heroes:heroSelected', hero);
      this.events.emit('heroSelected', hero);
    });

    return { container, hero };
  }

  // -------------------------------------------------------------------------
  // Sorting
  // -------------------------------------------------------------------------

  private sortHeroes(heroes: Hero[]): Hero[] {
    const copy = [...heroes];
    switch (this.sortMode) {
      case 'level':
        return copy.sort((a, b) => b.level - a.level);
      case 'rarity':
        return copy.sort(
          (a, b) => (RARITY_SORT_ORDER[b.rarity] ?? 0) - (RARITY_SORT_ORDER[a.rarity] ?? 0),
        );
      case 'name':
        return copy.sort((a, b) => a.name.localeCompare(b.name));
      case 'role':
        return copy.sort((a, b) => a.role.localeCompare(b.role));
      default:
        return copy;
    }
  }

  // -------------------------------------------------------------------------
  // Scroll input
  // -------------------------------------------------------------------------

  private setupScrollInput(): void {
    // Touch / mouse drag scrolling
    this.input.on('pointerdown', (pointer: Phaser.Input.Pointer) => {
      // Only scroll from the card area (below filter/sort bars)
      if (pointer.y < 90) return;
      this.isDragging = true;
      this.dragStartY = pointer.y;
    });

    this.input.on('pointermove', (pointer: Phaser.Input.Pointer) => {
      if (!this.isDragging || !pointer.isDown) return;
      const dy = pointer.y - this.dragStartY;
      this.dragStartY = pointer.y;
      this.scrollY = Phaser.Math.Clamp(this.scrollY - dy, 0, this.maxScrollY);
      this.applyScroll();
    });

    this.input.on('pointerup', () => {
      this.isDragging = false;
    });

    // Mouse wheel
    this.input.on('wheel', (_pointer: Phaser.Input.Pointer, _gx: number[], _gy: number[], _gz: number[], _ev: Event, deltaY: number) => {
      this.scrollY = Phaser.Math.Clamp(this.scrollY + deltaY * 0.5, 0, this.maxScrollY);
      this.applyScroll();
    });
  }

  private applyScroll(): void {
    if (this.scrollContainer) {
      this.scrollContainer.y = -this.scrollY;
    }
  }
}
