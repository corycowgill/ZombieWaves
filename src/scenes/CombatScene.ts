/**
 * CombatScene.ts — Tactical grid-based combat for Project Ashfall.
 *
 * Renders a 10x8 battlefield with player heroes on the left and enemies
 * on the right.  All game logic is delegated to the CombatEngine system;
 * this scene is a pure visual layer responsible for:
 *   - Drawing units with health bars
 *   - Floating damage numbers
 *   - Projectile animations
 *   - Skill targeting UI
 *   - Tactical pause (slow-time)
 *   - Victory / defeat overlays
 *   - Screen shake on heavy hits
 */

import { Hero, HeroRole, Skill } from '../models/Hero';
import { Enemy, EnemyType } from '../models/Enemy';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/** Minimal contract expected from the CombatEngine system. */
interface CombatEngine {
  processFrame(delta: number): void;
  isFinished(): boolean;
  isVictory(): boolean;
  getHeroes(): CombatUnit[];
  getEnemies(): CombatUnit[];
  activateSkill(unitId: string, skillId: string, targetId: string): void;
  setAutoMode(on: boolean): void;
  getXpGained(): number;
  getLoot(): Array<{ name: string; amount: number }>;
}

/** A unit in the combat engine's state (hero or enemy). */
interface CombatUnit {
  id: string;
  name: string;
  hp: number;
  maxHp: number;
  col: number;
  row: number;
  isAlly: boolean;
  skills: Skill[];
  textureKey: string;
}

/** Data passed into this scene on start. */
interface CombatSceneData {
  heroes: Hero[];
  enemies: Enemy[];
  combatEngine?: CombatEngine;
  reducedShake?: boolean;
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const GRID_COLS = 10;
const GRID_ROWS = 8;
const CELL_SIZE = 38;  // px per grid cell
const GRID_ORIGIN_X = 6;
const GRID_ORIGIN_Y = 90;

/** Texture keys by hero role. */
const HERO_TEXTURE: Record<HeroRole, string> = {
  [HeroRole.Assault]:     'hero_assault',
  [HeroRole.Heavy]:       'hero_heavy',
  [HeroRole.Recon]:       'hero_recon',
  [HeroRole.Medic]:       'hero_medic',
  [HeroRole.Engineer]:    'hero_engineer',
  [HeroRole.Sniper]:      'hero_sniper',
  [HeroRole.Demolitions]: 'hero_demolitions',
};

/** Texture keys by enemy type. */
const ENEMY_TEXTURE: Partial<Record<EnemyType, string>> = {
  [EnemyType.Shambler]:    'enemy_shambler',
  [EnemyType.Runner]:      'enemy_runner',
  [EnemyType.Spitter]:     'enemy_spitter',
  [EnemyType.Bruiser]:     'enemy_bruiser',
  [EnemyType.RaiderScout]: 'enemy_raider',
  [EnemyType.RaiderBrute]: 'enemy_militia',
};

// ---------------------------------------------------------------------------
// CombatScene
// ---------------------------------------------------------------------------

export default class CombatScene extends Phaser.Scene {
  // -- State ----------------------------------------------------------------
  private heroes: Hero[] = [];
  private enemies: Enemy[] = [];
  private combatEngine: CombatEngine | null = null;
  private reducedShake = false;

  // -- Visual groups --------------------------------------------------------
  private unitSprites: Map<string, Phaser.GameObjects.Sprite> = new Map();
  private healthBars: Map<string, { bg: Phaser.GameObjects.Rectangle; fill: Phaser.GameObjects.Rectangle }> = new Map();
  private tileGraphics: Phaser.GameObjects.Graphics | null = null;

  // -- Tactical pause -------------------------------------------------------
  private paused = false;
  private timeScale = 1;

  // -- Auto-battle ----------------------------------------------------------
  private autoBattle = false;

  // -- Skill targeting ------------------------------------------------------
  private selectedUnitId: string | null = null;
  private selectedSkill: Skill | null = null;
  private skillButtons: Phaser.GameObjects.Container | null = null;

  // -- Overlay containers ---------------------------------------------------
  private overlayContainer: Phaser.GameObjects.Container | null = null;

  // -- Movement range highlights --------------------------------------------
  private rangeHighlights: Phaser.GameObjects.Rectangle[] = [];

  constructor() {
    super({ key: 'CombatScene' });
  }

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  init(data: CombatSceneData): void {
    this.heroes = data.heroes ?? [];
    this.enemies = data.enemies ?? [];
    this.combatEngine = data.combatEngine ?? null;
    this.reducedShake = data.reducedShake ?? false;

    // Reset state
    this.paused = false;
    this.timeScale = 1;
    this.autoBattle = false;
    this.selectedUnitId = null;
    this.selectedSkill = null;
  }

  create(): void {
    const { width, height } = this.scale;

    this.cameras.main.setBackgroundColor('#1c1c28');

    // Draw grid
    this.drawGrid();

    // Place units
    this.placeHeroes();
    this.placeEnemies();

    // HUD buttons (pause / auto)
    this.createHUD(width);

    // Overlay container for victory/defeat (created but hidden)
    this.overlayContainer = this.add.container(0, 0).setDepth(200).setVisible(false);

    // Emit ready event
    this.game.events.emit('combat:ready');
  }

  update(_time: number, delta: number): void {
    if (!this.combatEngine) return;

    const effectiveDelta = delta * this.timeScale;

    // Process logic
    this.combatEngine.processFrame(effectiveDelta);

    // Sync visuals
    this.syncUnits(this.combatEngine.getHeroes());
    this.syncUnits(this.combatEngine.getEnemies());

    // Check end conditions
    if (this.combatEngine.isFinished()) {
      if (this.combatEngine.isVictory()) {
        this.showVictoryScreen();
      } else {
        this.showDefeatScreen();
      }
    }
  }

  // -------------------------------------------------------------------------
  // Grid rendering
  // -------------------------------------------------------------------------

  private drawGrid(): void {
    this.tileGraphics = this.add.graphics().setDepth(0);

    for (let row = 0; row < GRID_ROWS; row++) {
      for (let col = 0; col < GRID_COLS; col++) {
        const x = GRID_ORIGIN_X + col * CELL_SIZE;
        const y = GRID_ORIGIN_Y + row * CELL_SIZE;

        const shade = (col + row) % 2 === 0 ? 0x2a2a38 : 0x24243a;
        this.tileGraphics.fillStyle(shade, 1);
        this.tileGraphics.fillRect(x, y, CELL_SIZE - 1, CELL_SIZE - 1);

        this.tileGraphics.lineStyle(1, 0x3a3a50, 0.5);
        this.tileGraphics.strokeRect(x, y, CELL_SIZE - 1, CELL_SIZE - 1);
      }
    }
  }

  private cellToScreen(col: number, row: number): { x: number; y: number } {
    return {
      x: GRID_ORIGIN_X + col * CELL_SIZE + CELL_SIZE / 2,
      y: GRID_ORIGIN_Y + row * CELL_SIZE + CELL_SIZE / 2,
    };
  }

  // -------------------------------------------------------------------------
  // Unit placement
  // -------------------------------------------------------------------------

  private placeHeroes(): void {
    this.heroes.forEach((hero, i) => {
      const col = i < 4 ? 1 : 0;
      const row = i < 4 ? i + 2 : (i - 4) + 2;
      const textureKey = HERO_TEXTURE[hero.role] ?? 'hero_assault';
      this.createUnitSprite(hero.id, hero.name, textureKey, col, row, true, hero.getEffectiveStats().maxHealth);
    });
  }

  private placeEnemies(): void {
    this.enemies.forEach((enemy, i) => {
      const col = i < 4 ? GRID_COLS - 2 : GRID_COLS - 1;
      const row = i < 4 ? i + 2 : (i - 4) + 2;
      const textureKey = ENEMY_TEXTURE[enemy.type] ?? 'enemy_shambler';
      this.createUnitSprite(enemy.id, enemy.name, textureKey, col, row, false, enemy.stats.maxHealth);
    });
  }

  private createUnitSprite(
    id: string,
    name: string,
    textureKey: string,
    col: number,
    row: number,
    isAlly: boolean,
    maxHp: number,
  ): void {
    const { x, y } = this.cellToScreen(col, row);

    const sprite = this.add.sprite(x, y, textureKey).setDepth(10);
    sprite.setInteractive();
    sprite.setData('unitId', id);
    sprite.setData('isAlly', isAlly);

    sprite.on('pointerdown', () => this.onUnitTapped(id, isAlly));

    this.unitSprites.set(id, sprite);

    // Health bar
    const barWidth = CELL_SIZE - 8;
    const barHeight = 4;
    const barX = x;
    const barY = y - 18;

    const bg = this.add.rectangle(barX, barY, barWidth, barHeight, 0x333333).setDepth(11).setOrigin(0.5);
    const fill = this.add.rectangle(barX, barY, barWidth, barHeight, isAlly ? 0x44cc44 : 0xcc4444).setDepth(12).setOrigin(0.5);

    this.healthBars.set(id, { bg, fill });

    // Name label (small)
    this.add.text(x, y - 24, name, {
      fontSize: '8px',
      color: isAlly ? '#88ccff' : '#ff8888',
      stroke: '#000000',
      strokeThickness: 2,
    }).setOrigin(0.5).setDepth(13);
  }

  // -------------------------------------------------------------------------
  // Unit sync (per-frame visual update)
  // -------------------------------------------------------------------------

  private syncUnits(units: CombatUnit[]): void {
    for (const unit of units) {
      const sprite = this.unitSprites.get(unit.id);
      if (!sprite) continue;

      // Update position
      const { x, y } = this.cellToScreen(unit.col, unit.row);
      sprite.setPosition(x, y);

      // Update health bar
      const hb = this.healthBars.get(unit.id);
      if (hb) {
        const pct = Math.max(0, unit.hp / unit.maxHp);
        const fullWidth = CELL_SIZE - 8;
        hb.fill.displayWidth = fullWidth * pct;
        hb.fill.setPosition(x, y - 18);
        hb.bg.setPosition(x, y - 18);

        // Low-health tint
        if (pct < 0.3) {
          hb.fill.setFillStyle(0xcc4444);
        }
      }

      // Dead units
      if (unit.hp <= 0) {
        sprite.setAlpha(0.2);
        sprite.disableInteractive();
      }
    }
  }

  // -------------------------------------------------------------------------
  // Unit interaction / skill targeting
  // -------------------------------------------------------------------------

  private onUnitTapped(unitId: string, isAlly: boolean): void {
    // If we're selecting a target for a skill
    if (this.selectedSkill && this.selectedUnitId) {
      this.executeSkill(this.selectedUnitId, this.selectedSkill.id, unitId);
      this.clearSkillSelection();
      return;
    }

    // If tapping an ally, show skill buttons
    if (isAlly) {
      this.selectedUnitId = unitId;
      this.showSkillButtons(unitId);
    }
  }

  private showSkillButtons(unitId: string): void {
    this.clearSkillButtons();

    const hero = this.heroes.find((h) => h.id === unitId);
    if (!hero) return;

    const skills = hero.getSkillsAtLevel();
    if (skills.length === 0) return;

    const { width } = this.scale;
    const container = this.add.container(0, 0).setDepth(150);

    // Panel background at bottom
    const panelY = this.scale.height - 60;
    const panelBg = this.add.rectangle(width / 2, panelY, width - 20, 50, 0x1a1a2e, 0.9)
      .setStrokeStyle(1, 0x5555aa);
    container.add(panelBg);

    const startX = width / 2 - ((skills.length - 1) * 55) / 2;

    skills.forEach((skill, i) => {
      const bx = startX + i * 55;
      const btn = this.add.rectangle(bx, panelY, 48, 40, 0x2a2a4a)
        .setStrokeStyle(1, 0x7777bb)
        .setInteractive();
      container.add(btn);

      const label = this.add.text(bx, panelY, skill.name.substring(0, 5), {
        fontSize: '9px',
        color: '#aaccff',
        stroke: '#000000',
        strokeThickness: 1,
      }).setOrigin(0.5);
      container.add(label);

      // Cooldown indicator
      if (skill.currentCooldown > 0) {
        btn.setAlpha(0.4);
        const cdText = this.add.text(bx, panelY + 12, `${skill.currentCooldown}`, {
          fontSize: '8px',
          color: '#ff6666',
        }).setOrigin(0.5);
        container.add(cdText);
      } else {
        btn.on('pointerdown', () => {
          this.selectedSkill = skill;
          this.highlightTargets(skill);
        });
      }
    });

    this.skillButtons = container;
  }

  private highlightTargets(skill: Skill): void {
    // Simple: highlight all enemies for offensive, all allies for support
    const isOffensive = ['damage', 'dot', 'stun', 'knockback', 'bleed', 'burn', 'explosiveDamage'].includes(skill.effectType);
    const ids = isOffensive
      ? this.enemies.map((e) => e.id)
      : this.heroes.map((h) => h.id);

    for (const id of ids) {
      const sprite = this.unitSprites.get(id);
      if (sprite && sprite.alpha > 0.3) {
        sprite.setTint(isOffensive ? 0xff4444 : 0x44ff44);
      }
    }
  }

  private executeSkill(casterId: string, skillId: string, targetId: string): void {
    if (this.combatEngine) {
      this.combatEngine.activateSkill(casterId, skillId, targetId);
    }

    // Projectile animation
    const casterSprite = this.unitSprites.get(casterId);
    const targetSprite = this.unitSprites.get(targetId);

    if (casterSprite && targetSprite) {
      this.animateProjectile(casterSprite.x, casterSprite.y, targetSprite.x, targetSprite.y);
    }
  }

  private clearSkillSelection(): void {
    this.selectedSkill = null;
    this.selectedUnitId = null;
    this.clearSkillButtons();

    // Remove tints
    for (const sprite of this.unitSprites.values()) {
      sprite.clearTint();
    }
  }

  private clearSkillButtons(): void {
    if (this.skillButtons) {
      this.skillButtons.destroy();
      this.skillButtons = null;
    }
  }

  // -------------------------------------------------------------------------
  // Projectile & damage animations
  // -------------------------------------------------------------------------

  private animateProjectile(fromX: number, fromY: number, toX: number, toY: number): void {
    const bullet = this.add.circle(fromX, fromY, 3, 0xffff00).setDepth(50);

    this.tweens.add({
      targets: bullet,
      x: toX,
      y: toY,
      duration: 200,
      ease: 'Linear',
      onComplete: () => {
        bullet.destroy();
        this.showImpact(toX, toY);
      },
    });
  }

  private showImpact(x: number, y: number): void {
    const impact = this.add.circle(x, y, 8, 0xff6600, 0.8).setDepth(51);
    this.tweens.add({
      targets: impact,
      scaleX: 2,
      scaleY: 2,
      alpha: 0,
      duration: 300,
      onComplete: () => impact.destroy(),
    });

    // Screen shake
    if (!this.reducedShake) {
      this.cameras.main.shake(80, 0.005);
    }
  }

  /** Show a floating damage/heal number that rises and fades. */
  showDamageNumber(x: number, y: number, amount: number, isHeal: boolean = false): void {
    const color = isHeal ? '#44ff44' : '#ff4444';
    const prefix = isHeal ? '+' : '-';

    const txt = this.add.text(
      x + Phaser.Math.Between(-6, 6),
      y - 10,
      `${prefix}${amount}`,
      {
        fontSize: '14px',
        fontStyle: 'bold',
        color,
        stroke: '#000000',
        strokeThickness: 3,
      },
    ).setOrigin(0.5).setDepth(100);

    this.tweens.add({
      targets: txt,
      y: y - 50,
      alpha: 0,
      duration: 1200,
      ease: 'Cubic.easeOut',
      onComplete: () => txt.destroy(),
    });
  }

  // -------------------------------------------------------------------------
  // HUD
  // -------------------------------------------------------------------------

  private createHUD(width: number): void {
    const hudY = 20;

    // Pause button
    const pauseBtn = this.add.text(width - 90, hudY, '|| PAUSE', {
      fontSize: '12px',
      color: '#aaaacc',
      backgroundColor: '#2a2a3e',
      padding: { x: 8, y: 4 },
    }).setDepth(200).setInteractive();

    pauseBtn.on('pointerdown', () => this.togglePause(pauseBtn));

    // Auto-battle button
    const autoBtn = this.add.text(width - 90, hudY + 30, 'AUTO: OFF', {
      fontSize: '12px',
      color: '#aaaacc',
      backgroundColor: '#2a2a3e',
      padding: { x: 8, y: 4 },
    }).setDepth(200).setInteractive();

    autoBtn.on('pointerdown', () => {
      this.autoBattle = !this.autoBattle;
      autoBtn.setText(`AUTO: ${this.autoBattle ? 'ON' : 'OFF'}`);
      autoBtn.setColor(this.autoBattle ? '#44ff44' : '#aaaacc');
      this.combatEngine?.setAutoMode(this.autoBattle);
    });

    // Scene label
    this.add.text(10, hudY, 'COMBAT', {
      fontSize: '14px',
      fontStyle: 'bold',
      color: '#ff8855',
      stroke: '#000000',
      strokeThickness: 2,
    }).setDepth(200);
  }

  // -------------------------------------------------------------------------
  // Tactical pause
  // -------------------------------------------------------------------------

  private togglePause(btn: Phaser.GameObjects.Text): void {
    this.paused = !this.paused;

    if (this.paused) {
      this.timeScale = 0.1; // 10% speed
      btn.setText('>> PLAY');
      btn.setColor('#44ff44');
      this.showMovementRanges();
    } else {
      this.timeScale = 1;
      btn.setText('|| PAUSE');
      btn.setColor('#aaaacc');
      this.clearMovementRanges();
    }
  }

  private showMovementRanges(): void {
    this.clearMovementRanges();

    // Show a 2-cell movement range around each living ally
    if (!this.combatEngine) return;
    const allies = this.combatEngine.getHeroes().filter((u) => u.hp > 0);

    for (const unit of allies) {
      for (let dr = -2; dr <= 2; dr++) {
        for (let dc = -2; dc <= 2; dc++) {
          if (Math.abs(dr) + Math.abs(dc) > 2) continue;
          const c = unit.col + dc;
          const r = unit.row + dr;
          if (c < 0 || c >= GRID_COLS || r < 0 || r >= GRID_ROWS) continue;

          const { x, y } = this.cellToScreen(c, r);
          const highlight = this.add.rectangle(x, y, CELL_SIZE - 2, CELL_SIZE - 2, 0x4488ff, 0.2)
            .setDepth(5)
            .setStrokeStyle(1, 0x4488ff, 0.5);
          this.rangeHighlights.push(highlight);
        }
      }
    }
  }

  private clearMovementRanges(): void {
    for (const h of this.rangeHighlights) h.destroy();
    this.rangeHighlights = [];
  }

  // -------------------------------------------------------------------------
  // End screens
  // -------------------------------------------------------------------------

  private showVictoryScreen(): void {
    if (!this.overlayContainer || this.overlayContainer.visible) return;
    this.timeScale = 0; // freeze combat

    const { width, height } = this.scale;
    const cx = width / 2;
    const cy = height / 2;

    const bg = this.add.rectangle(cx, cy, width, height, 0x000000, 0.7);
    this.overlayContainer.add(bg);

    this.overlayContainer.add(
      this.add.text(cx, cy - 100, 'VICTORY', {
        fontSize: '32px',
        fontStyle: 'bold',
        color: '#ffd700',
        stroke: '#000000',
        strokeThickness: 4,
      }).setOrigin(0.5),
    );

    // XP gained
    const xp = this.combatEngine?.getXpGained() ?? 0;
    this.overlayContainer.add(
      this.add.text(cx, cy - 50, `XP Gained: ${xp}`, {
        fontSize: '16px',
        color: '#88ccff',
      }).setOrigin(0.5),
    );

    // Loot
    const loot = this.combatEngine?.getLoot() ?? [];
    let lootY = cy - 20;
    for (const item of loot) {
      this.overlayContainer.add(
        this.add.text(cx, lootY, `${item.name}: ${item.amount}`, {
          fontSize: '13px',
          color: '#aaffaa',
        }).setOrigin(0.5),
      );
      lootY += 20;
    }

    // Hero performance summary
    const perfY = Math.max(lootY + 20, cy + 30);
    this.heroes.forEach((hero, i) => {
      this.overlayContainer!.add(
        this.add.text(cx, perfY + i * 18, `${hero.name} (${hero.role})`, {
          fontSize: '11px',
          color: '#ccccee',
        }).setOrigin(0.5),
      );
    });

    // Continue button
    const continueBtn = this.add.text(cx, height - 80, 'CONTINUE', {
      fontSize: '18px',
      fontStyle: 'bold',
      color: '#ffffff',
      backgroundColor: '#336633',
      padding: { x: 30, y: 10 },
    }).setOrigin(0.5).setInteractive();

    continueBtn.on('pointerdown', () => {
      this.game.events.emit('combat:victory', {
        xp,
        loot,
        heroes: this.heroes,
      });
      this.scene.start('BaseScene');
    });
    this.overlayContainer.add(continueBtn);

    this.overlayContainer.setVisible(true);
  }

  private showDefeatScreen(): void {
    if (!this.overlayContainer || this.overlayContainer.visible) return;
    this.timeScale = 0;

    const { width, height } = this.scale;
    const cx = width / 2;
    const cy = height / 2;

    const bg = this.add.rectangle(cx, cy, width, height, 0x000000, 0.75);
    this.overlayContainer.add(bg);

    this.overlayContainer.add(
      this.add.text(cx, cy - 80, 'DEFEAT', {
        fontSize: '32px',
        fontStyle: 'bold',
        color: '#cc3333',
        stroke: '#000000',
        strokeThickness: 4,
      }).setOrigin(0.5),
    );

    this.overlayContainer.add(
      this.add.text(cx, cy - 30, 'Your squad has been overwhelmed.', {
        fontSize: '13px',
        color: '#ccaaaa',
      }).setOrigin(0.5),
    );

    // Regroup button
    const regroupBtn = this.add.text(cx, cy + 30, 'REGROUP (-10 Morale)', {
      fontSize: '15px',
      fontStyle: 'bold',
      color: '#ffffff',
      backgroundColor: '#663333',
      padding: { x: 20, y: 8 },
    }).setOrigin(0.5).setInteractive();

    regroupBtn.on('pointerdown', () => {
      this.game.events.emit('combat:defeat', {
        moraleCost: 10,
        heroes: this.heroes,
      });
      this.scene.start('BaseScene');
    });
    this.overlayContainer.add(regroupBtn);

    // Retreat button
    const retreatBtn = this.add.text(cx, cy + 80, 'RETREAT TO BASE', {
      fontSize: '13px',
      color: '#aaaaaa',
      backgroundColor: '#333333',
      padding: { x: 16, y: 6 },
    }).setOrigin(0.5).setInteractive();

    retreatBtn.on('pointerdown', () => {
      this.game.events.emit('combat:retreat');
      this.scene.start('BaseScene');
    });
    this.overlayContainer.add(retreatBtn);

    this.overlayContainer.setVisible(true);
  }
}
