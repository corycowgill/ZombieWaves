/**
 * BaseScene.ts — Isometric base-building view for Project Ashfall.
 *
 * Renders a 12x12 diamond-layout isometric grid where players place,
 * upgrade, and manage buildings.  Provides camera controls (drag-pan,
 * pinch-zoom), floating resource production indicators, idle NPC
 * animations, and emits events so the HTML UI overlay can show build
 * and info panels.
 */

import { Building, BuildingType } from '../models/Building';
import { ResourceType } from '../models/Resource';

// ---------------------------------------------------------------------------
// Types local to this scene
// ---------------------------------------------------------------------------

interface PlacedSprite {
  buildingId: string;
  sprite: Phaser.GameObjects.Sprite;
  label: Phaser.GameObjects.Text;
}

interface IdleNPC {
  sprite: Phaser.GameObjects.Arc;
  targetCol: number;
  targetRow: number;
  speed: number;
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const GRID_COLS = 12;
const GRID_ROWS = 12;
const TILE_W = 64;
const TILE_H = 32;

/** Texture key lookup per BuildingType. */
const BUILDING_TEXTURE: Partial<Record<BuildingType, string>> = {
  [BuildingType.CommandCenter]: 'building_command_center',
  [BuildingType.Barracks]:      'building_barracks',
  [BuildingType.Farm]:          'building_farm',
  [BuildingType.WaterPurifier]: 'building_water_purifier',
  [BuildingType.Workshop]:      'building_workshop',
  [BuildingType.Infirmary]:     'building_hospital',
  [BuildingType.ResearchLab]:   'building_lab',
  [BuildingType.FuelDepot]:     'building_fuel_depot',
  [BuildingType.ScrapYard]:     'building_scrapyard',
  [BuildingType.RadarTower]:    'building_watchtower',
  [BuildingType.HeroQuarters]:  'building_hero_quarters',
  [BuildingType.Wall]:          'building_wall',
  [BuildingType.Turret]:        'building_turret',
  [BuildingType.Trap]:          'building_trap',
  [BuildingType.Garage]:        'building_garage',
};

/** Human-readable emoji for floating production text. */
const RESOURCE_ICON: Partial<Record<ResourceType, string>> = {
  [ResourceType.Food]:         '\uD83C\uDF3E',
  [ResourceType.Water]:        '\uD83D\uDCA7',
  [ResourceType.Fuel]:         '\u26FD',
  [ResourceType.Scrap]:        '\uD83D\uDD29',
  [ResourceType.ResearchData]: '\uD83D\uDCCA',
};

// ---------------------------------------------------------------------------
// BaseScene
// ---------------------------------------------------------------------------

export default class BaseScene extends Phaser.Scene {
  /** Offset so the grid is centred on screen. */
  private offsetX = 0;
  private offsetY = 0;

  /** Grid of tile sprites (for highlight toggling). */
  private tileSprites: Phaser.GameObjects.Image[][] = [];

  /** Currently rendered building sprites, keyed by building id. */
  private buildingSprites: Map<string, PlacedSprite> = new Map();

  /** Idle NPCs that wander between buildings. */
  private npcs: IdleNPC[] = [];

  /** Whether we are in "build mode" (highlighting empty tiles). */
  private buildMode = false;

  /** Timer accumulator for resource production floaters (ms). */
  private productionTimer = 0;
  private readonly PRODUCTION_INTERVAL = 5000; // 5 seconds

  /** Reference to the external building list — pulled from gameState. */
  private buildings: Building[] = [];

  /** Pinch-zoom tracking. */
  private pinchDistance: number | null = null;
  private pinchZoomStart = 1;

  constructor() {
    super({ key: 'BaseScene' });
  }

  // -------------------------------------------------------------------------
  // Phaser lifecycle
  // -------------------------------------------------------------------------

  init(): void {
    // Pull buildings from the central game state
    const gameState = (this.game as any).gameState;
    if (gameState?.baseManager) {
      this.buildings = gameState.baseManager.getBuildings();
    }
  }

  create(): void {
    const { width, height } = this.scale;

    // Centre the grid
    this.offsetX = width / 2;
    this.offsetY = height * 0.18;

    // Dark background
    this.cameras.main.setBackgroundColor('#1a1a24');

    // Draw iso grid
    this.createGrid();

    // Place buildings from state
    this.refreshBuildings();

    // Spawn idle NPCs
    this.spawnIdleNPCs(3);

    // --- Camera controls ---------------------------------------------------
    this.setupCameraControls();

    // Set camera bounds around the grid
    const boundsMargin = 200;
    const gridPixelW = (GRID_COLS + GRID_ROWS) * (TILE_W / 2);
    const gridPixelH = (GRID_COLS + GRID_ROWS) * (TILE_H / 2);
    this.cameras.main.setBounds(
      this.offsetX - gridPixelW / 2 - boundsMargin,
      this.offsetY - boundsMargin,
      gridPixelW + boundsMargin * 2,
      gridPixelH + boundsMargin * 2,
    );

    // Listen for external events
    this.game.events.on('base:enterBuildMode', this.enterBuildMode, this);
    this.game.events.on('base:exitBuildMode', this.exitBuildMode, this);
    this.game.events.on('base:refresh', (buildings: Building[]) => {
      this.buildings = buildings;
      this.refreshBuildings();
    });

    this.events.once(Phaser.Scenes.Events.SHUTDOWN, () => {
      this.game.events.off('base:enterBuildMode', this.enterBuildMode, this);
      this.game.events.off('base:exitBuildMode', this.exitBuildMode, this);
    });
  }

  update(_time: number, delta: number): void {
    // Animate idle NPCs
    this.updateNPCs(delta);

    // Production floaters
    this.productionTimer += delta;
    if (this.productionTimer >= this.PRODUCTION_INTERVAL) {
      this.productionTimer -= this.PRODUCTION_INTERVAL;
      this.showProductionFloaters();
    }
  }

  // -------------------------------------------------------------------------
  // Grid
  // -------------------------------------------------------------------------

  private createGrid(): void {
    this.tileSprites = [];

    for (let row = 0; row < GRID_ROWS; row++) {
      const rowArr: Phaser.GameObjects.Image[] = [];
      for (let col = 0; col < GRID_COLS; col++) {
        const { x, y } = this.isoToScreen(col, row);
        const tile = this.add.image(x, y, 'tile_grass').setDepth(0);
        tile.setInteractive();
        tile.setData('col', col);
        tile.setData('row', row);

        tile.on('pointerdown', () => this.onTileClicked(col, row));

        rowArr.push(tile);
      }
      this.tileSprites.push(rowArr);
    }
  }

  /** Convert grid col/row to screen pixel coordinates. */
  private isoToScreen(col: number, row: number): { x: number; y: number } {
    return {
      x: (col - row) * (TILE_W / 2) + this.offsetX,
      y: (col + row) * (TILE_H / 2) + this.offsetY,
    };
  }

  /** Reverse: find the grid cell under a screen point. */
  private screenToIso(sx: number, sy: number): { col: number; row: number } {
    const rx = sx - this.offsetX;
    const ry = sy - this.offsetY;
    const col = Math.round(rx / TILE_W + ry / TILE_H);
    const row = Math.round(ry / TILE_H - rx / TILE_W);
    return { col, row };
  }

  // -------------------------------------------------------------------------
  // Building rendering
  // -------------------------------------------------------------------------

  /** Re-draw all building sprites from the current building list. */
  refreshBuildings(): void {
    // Pull latest buildings from game state
    const gameState = (this.game as any).gameState;
    if (gameState?.baseManager) {
      this.buildings = gameState.baseManager.getBuildings();
    }

    // Destroy old sprites
    for (const ps of this.buildingSprites.values()) {
      ps.sprite.destroy();
      ps.label.destroy();
    }
    this.buildingSprites.clear();

    for (const b of this.buildings) {
      this.placeBuilding(b);
    }
  }

  private placeBuilding(b: Building): void {
    const { x, y } = this.isoToScreen(b.gridPosition.col, b.gridPosition.row);
    const textureKey = BUILDING_TEXTURE[b.type] ?? 'building_command_center';

    const sprite = this.add.sprite(x, y - TILE_H / 2, textureKey).setDepth(1);
    sprite.setInteractive();
    sprite.setData('buildingId', b.id);

    // Dim if not active
    if (b.hitPoints < b.maxHitPoints) {
      sprite.setTint(0xff6666);
    } else if (b.isUpgrading) {
      sprite.setTint(0xffff66);
    }

    sprite.on('pointerdown', () => {
      this.game.events.emit('base:buildingSelected', b);
      this.events.emit('buildingSelected', b);
    });

    // Level label
    const label = this.add.text(x, y - TILE_H - 10, `Lv${b.level}`, {
      fontSize: '10px',
      color: '#ffffff',
      stroke: '#000000',
      strokeThickness: 2,
    }).setOrigin(0.5).setDepth(2);

    this.buildingSprites.set(b.id, { buildingId: b.id, sprite, label });
  }

  // -------------------------------------------------------------------------
  // Tile interaction
  // -------------------------------------------------------------------------

  private onTileClicked(col: number, row: number): void {
    // Check if a building occupies this tile
    const occupant = this.buildings.find((b) => b.gridPosition.col === col && b.gridPosition.row === row);

    if (occupant) {
      this.game.events.emit('base:buildingSelected', occupant);
      this.events.emit('buildingSelected', occupant);
    } else {
      // Empty tile — open build menu
      this.game.events.emit('base:emptyTileSelected', { col, row });
      this.events.emit('emptyTileSelected', { col, row });
    }
  }

  // -------------------------------------------------------------------------
  // Build mode
  // -------------------------------------------------------------------------

  enterBuildMode(): void {
    this.buildMode = true;
    this.highlightBuildableTiles();
  }

  exitBuildMode(): void {
    this.buildMode = false;
    this.clearTileHighlights();
  }

  /** Highlight tiles that do not have a building. */
  highlightBuildableTiles(): void {
    const occupied = new Set(
      this.buildings.map((b) => `${b.gridPosition.col},${b.gridPosition.row}`),
    );

    for (let row = 0; row < GRID_ROWS; row++) {
      for (let col = 0; col < GRID_COLS; col++) {
        const tile = this.tileSprites[row]?.[col];
        if (!tile) continue;

        if (!occupied.has(`${col},${row}`)) {
          tile.setTint(0x66ff66);
          tile.setAlpha(0.85);
        } else {
          tile.setTint(0xff4444);
          tile.setAlpha(0.5);
        }
      }
    }
  }

  private clearTileHighlights(): void {
    for (let row = 0; row < GRID_ROWS; row++) {
      for (let col = 0; col < GRID_COLS; col++) {
        const tile = this.tileSprites[row]?.[col];
        if (!tile) continue;
        tile.clearTint();
        tile.setAlpha(1);
      }
    }
  }

  // -------------------------------------------------------------------------
  // Production floaters
  // -------------------------------------------------------------------------

  private showProductionFloaters(): void {
    for (const b of this.buildings) {
      const productions = b.getProductionRate();
      if (productions.length === 0) continue;

      for (const entry of productions) {
        const icon = RESOURCE_ICON[entry.resourceType] ?? '';
        const amount = Math.round(entry.amountPerMinute / 12); // per 5-second tick
        if (amount <= 0) continue;

        const { x, y } = this.isoToScreen(b.gridPosition.col, b.gridPosition.row);

        const floater = this.add.text(
          x + Phaser.Math.Between(-8, 8),
          y - TILE_H,
          `+${amount} ${icon}`,
          {
            fontSize: '12px',
            color: '#66ff66',
            stroke: '#000000',
            strokeThickness: 2,
            fontStyle: 'bold',
          },
        ).setOrigin(0.5).setDepth(100);

        this.tweens.add({
          targets: floater,
          y: y - TILE_H - 40,
          alpha: 0,
          duration: 1800,
          ease: 'Cubic.easeOut',
          onComplete: () => floater.destroy(),
        });
      }
    }
  }

  // -------------------------------------------------------------------------
  // Idle NPCs
  // -------------------------------------------------------------------------

  private spawnIdleNPCs(count: number): void {
    for (let i = 0; i < count; i++) {
      const startCol = Phaser.Math.Between(0, GRID_COLS - 1);
      const startRow = Phaser.Math.Between(0, GRID_ROWS - 1);
      const { x, y } = this.isoToScreen(startCol, startRow);

      const npc = this.add.circle(x, y - 6, 4, 0xcccccc, 0.8).setDepth(3);

      this.npcs.push({
        sprite: npc,
        targetCol: Phaser.Math.Between(0, GRID_COLS - 1),
        targetRow: Phaser.Math.Between(0, GRID_ROWS - 1),
        speed: Phaser.Math.FloatBetween(15, 30), // px/sec
      });
    }
  }

  private updateNPCs(delta: number): void {
    const dt = delta / 1000;

    for (const npc of this.npcs) {
      const target = this.isoToScreen(npc.targetCol, npc.targetRow);
      const tx = target.x;
      const ty = target.y - 6;

      const dx = tx - npc.sprite.x;
      const dy = ty - npc.sprite.y;
      const dist = Math.sqrt(dx * dx + dy * dy);

      if (dist < 4) {
        // Pick a new destination
        npc.targetCol = Phaser.Math.Between(0, GRID_COLS - 1);
        npc.targetRow = Phaser.Math.Between(0, GRID_ROWS - 1);
      } else {
        const step = npc.speed * dt;
        npc.sprite.x += (dx / dist) * Math.min(step, dist);
        npc.sprite.y += (dy / dist) * Math.min(step, dist);
      }
    }
  }

  // -------------------------------------------------------------------------
  // Camera controls (drag pan + pinch zoom)
  // -------------------------------------------------------------------------

  private setupCameraControls(): void {
    // Drag to pan
    this.input.on('pointermove', (pointer: Phaser.Input.Pointer) => {
      if (!pointer.isDown) return;
      // Only pan when a single pointer is down
      if (this.input.pointer1.isDown && this.input.pointer2.isDown) return;

      this.cameras.main.scrollX -= (pointer.x - pointer.prevPosition.x) / this.cameras.main.zoom;
      this.cameras.main.scrollY -= (pointer.y - pointer.prevPosition.y) / this.cameras.main.zoom;
    });

    // Pinch zoom (touch)
    this.input.on('pointerdown', () => {
      if (this.input.pointer1.isDown && this.input.pointer2.isDown) {
        const p1 = this.input.pointer1;
        const p2 = this.input.pointer2;
        this.pinchDistance = Phaser.Math.Distance.Between(p1.x, p1.y, p2.x, p2.y);
        this.pinchZoomStart = this.cameras.main.zoom;
      }
    });

    this.input.on('pointermove', () => {
      if (this.input.pointer1.isDown && this.input.pointer2.isDown && this.pinchDistance !== null) {
        const p1 = this.input.pointer1;
        const p2 = this.input.pointer2;
        const dist = Phaser.Math.Distance.Between(p1.x, p1.y, p2.x, p2.y);
        const scale = dist / this.pinchDistance;
        this.cameras.main.setZoom(
          Phaser.Math.Clamp(this.pinchZoomStart * scale, 0.5, 2.5),
        );
      }
    });

    this.input.on('pointerup', () => {
      this.pinchDistance = null;
    });

    // Mouse wheel zoom (desktop)
    this.input.on('wheel', (_pointer: Phaser.Input.Pointer, _gx: number[], _gy: number[], _gz: number[], _event: Event, deltaY: number) => {
      const newZoom = this.cameras.main.zoom - deltaY * 0.001;
      this.cameras.main.setZoom(Phaser.Math.Clamp(newZoom, 0.5, 2.5));
    });
  }
}
