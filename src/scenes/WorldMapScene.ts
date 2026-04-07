/**
 * WorldMapScene.ts — World map exploration view for Project Ashfall.
 *
 * Displays district nodes as coloured hexagons connected by path lines.
 * Supports fog-of-war, pulsing glow on available districts, camera
 * pan/zoom, and emits events for mission briefing flow.
 */

import { District, DistrictBiome } from '../models/District';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface DistrictNode {
  district: District;
  x: number;
  y: number;
  shape: Phaser.GameObjects.Polygon;
  label: Phaser.GameObjects.Text;
  statusIcon: Phaser.GameObjects.Image | Phaser.GameObjects.Text | null;
  glow: Phaser.GameObjects.Arc | null;
}

interface WorldMapData {
  districts: District[];
  /** Screen positions for each district (keyed by district id). */
  positions?: Map<string, { x: number; y: number }>;
  currentDistrictId?: string;
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const HEX_RADIUS = 30;

/** Biome-based fill colours. */
const BIOME_COLOR: Record<DistrictBiome, number> = {
  [DistrictBiome.Urban]:        0x4a6a8a,
  [DistrictBiome.Industrial]:   0x7a6a4a,
  [DistrictBiome.Residential]:  0x5a8a5a,
  [DistrictBiome.Military]:     0x6a4a4a,
  [DistrictBiome.Hospital]:     0x6a6a8a,
  [DistrictBiome.Wasteland]:    0x8a7a5a,
  [DistrictBiome.Underground]:  0x4a4a5a,
};

// ---------------------------------------------------------------------------
// WorldMapScene
// ---------------------------------------------------------------------------

export default class WorldMapScene extends Phaser.Scene {
  private districts: District[] = [];
  private nodes: Map<string, DistrictNode> = new Map();
  private pathLines: Phaser.GameObjects.Graphics | null = null;
  private currentMarker: Phaser.GameObjects.Arc | null = null;
  private currentDistrictId: string | null = null;

  /** Info panel shown when a district is tapped. */
  private infoPanel: Phaser.GameObjects.Container | null = null;

  /** Pinch-zoom state. */
  private pinchDistance: number | null = null;
  private pinchZoomStart = 1;

  constructor() {
    super({ key: 'WorldMapScene' });
  }

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  init(data: WorldMapData): void {
    this.districts = data.districts ?? [];
    this.currentDistrictId = data.currentDistrictId ?? null;
    this.nodes.clear();
  }

  create(): void {
    const { width, height } = this.scale;

    this.cameras.main.setBackgroundColor('#0d0d14');

    // Assign positions if not provided
    this.assignPositions(width, height);

    // Draw connection lines first (below nodes)
    this.drawConnections();

    // Create district nodes
    for (const district of this.districts) {
      this.createDistrictNode(district);
    }

    // Current location marker
    this.createCurrentMarker();

    // Camera controls
    this.setupCameraControls(width, height);

    // Back button
    this.add.text(15, 20, '< BACK', {
      fontSize: '14px',
      color: '#aaaacc',
      backgroundColor: '#2a2a3e',
      padding: { x: 10, y: 6 },
    }).setDepth(300).setInteractive().setScrollFactor(0)
      .on('pointerdown', () => this.scene.start('BaseScene'));

    // Title
    this.add.text(width / 2, 22, 'WORLD MAP', {
      fontSize: '16px',
      fontStyle: 'bold',
      color: '#cc8844',
      stroke: '#000000',
      strokeThickness: 2,
    }).setOrigin(0.5).setDepth(300).setScrollFactor(0);

    this.game.events.emit('worldmap:ready');
  }

  // -------------------------------------------------------------------------
  // Position assignment
  // -------------------------------------------------------------------------

  /**
   * Lay districts out in a rough grid with jitter for an organic feel.
   * Falls back to random if fewer than expected.
   */
  private assignPositions(sceneW: number, sceneH: number): void {
    const cols = Math.ceil(Math.sqrt(this.districts.length));
    const spacingX = Math.max(100, sceneW / (cols + 1));
    const spacingY = Math.max(100, sceneH / (cols + 1));

    this.districts.forEach((d, i) => {
      if (this.nodes.has(d.id)) return; // already placed

      const col = i % cols;
      const row = Math.floor(i / cols);
      const jitterX = Phaser.Math.Between(-15, 15);
      const jitterY = Phaser.Math.Between(-15, 15);

      const x = spacingX * (col + 1) + jitterX;
      const y = spacingY * (row + 1) + jitterY + 60; // offset for header

      // Temporarily stash position
      (d as District & { _sx: number; _sy: number })._sx = x;
      (d as District & { _sx: number; _sy: number })._sy = y;
    });
  }

  private getPos(d: District): { x: number; y: number } {
    const node = this.nodes.get(d.id);
    if (node) return { x: node.x, y: node.y };
    const any = d as District & { _sx?: number; _sy?: number };
    return { x: any._sx ?? 200, y: any._sy ?? 200 };
  }

  // -------------------------------------------------------------------------
  // Connections
  // -------------------------------------------------------------------------

  private drawConnections(): void {
    this.pathLines = this.add.graphics().setDepth(0);

    for (const district of this.districts) {
      const from = this.getPos(district);

      for (const connId of district.connectedDistrictIds) {
        const target = this.districts.find((d) => d.id === connId);
        if (!target) continue;
        const to = this.getPos(target);

        // Avoid drawing each line twice
        if (district.id > connId) continue;

        const accessible = district.isRevealed && target.isRevealed;
        const color = accessible ? 0x556677 : 0x222233;
        const alpha = accessible ? 0.7 : 0.3;

        this.pathLines.lineStyle(2, color, alpha);
        this.pathLines.beginPath();
        this.pathLines.moveTo(from.x, from.y);
        this.pathLines.lineTo(to.x, to.y);
        this.pathLines.strokePath();
      }
    }
  }

  // -------------------------------------------------------------------------
  // District nodes
  // -------------------------------------------------------------------------

  private createDistrictNode(district: District): void {
    const pos = this.getPos(district);

    // Hexagon points
    const points = this.hexPoints(HEX_RADIUS);

    let shape: Phaser.GameObjects.Polygon;
    let label: Phaser.GameObjects.Text;
    let statusIcon: Phaser.GameObjects.Text | null = null;
    let glow: Phaser.GameObjects.Arc | null = null;

    if (!district.isRevealed) {
      // Fog of war — dark silhouette
      shape = this.add.polygon(pos.x, pos.y, points, 0x111118, 0.9)
        .setStrokeStyle(1, 0x222233)
        .setDepth(1);
      shape.setInteractive(
        new Phaser.Geom.Polygon(points),
        Phaser.Geom.Polygon.Contains,
      );

      label = this.add.text(pos.x, pos.y, '?', {
        fontSize: '16px',
        color: '#333344',
        fontStyle: 'bold',
      }).setOrigin(0.5).setDepth(2);
    } else {
      const biomeColor = BIOME_COLOR[district.biome] ?? 0x555555;

      if (district.isCleared) {
        // Bright, with checkmark
        shape = this.add.polygon(pos.x, pos.y, points, biomeColor, 1)
          .setStrokeStyle(2, 0xaaccaa)
          .setDepth(1);

        statusIcon = this.add.text(pos.x + 14, pos.y - 18, '\u2713', {
          fontSize: '14px',
          fontStyle: 'bold',
          color: '#44ff44',
        }).setOrigin(0.5).setDepth(3);
      } else {
        // Available — pulsing glow
        shape = this.add.polygon(pos.x, pos.y, points, biomeColor, 0.9)
          .setStrokeStyle(2, 0xccaa66)
          .setDepth(1);

        glow = this.add.circle(pos.x, pos.y, HEX_RADIUS + 6, 0xffcc44, 0.15)
          .setDepth(0);

        this.tweens.add({
          targets: glow,
          alpha: 0.35,
          scaleX: 1.15,
          scaleY: 1.15,
          duration: 1200,
          yoyo: true,
          repeat: -1,
          ease: 'Sine.easeInOut',
        });
      }

      shape.setInteractive(
        new Phaser.Geom.Polygon(points),
        Phaser.Geom.Polygon.Contains,
      );

      label = this.add.text(pos.x, pos.y, district.name, {
        fontSize: '9px',
        color: '#ffffff',
        stroke: '#000000',
        strokeThickness: 2,
        align: 'center',
        wordWrap: { width: HEX_RADIUS * 2 - 8 },
      }).setOrigin(0.5).setDepth(2);

      // Threat level indicator
      const threatColor = district.threatLevel >= 7 ? '#ff4444' : district.threatLevel >= 4 ? '#ffaa44' : '#88cc88';
      this.add.text(pos.x, pos.y + 16, `\u2620 ${district.threatLevel}`, {
        fontSize: '8px',
        color: threatColor,
        stroke: '#000000',
        strokeThickness: 1,
      }).setOrigin(0.5).setDepth(2);
    }

    // Tap handler
    shape.on('pointerdown', () => this.onDistrictTapped(district));

    const node: DistrictNode = {
      district,
      x: pos.x,
      y: pos.y,
      shape,
      label,
      statusIcon,
      glow,
    };
    this.nodes.set(district.id, node);
  }

  /** Generate flat-top hexagon vertex array. */
  private hexPoints(r: number): number[] {
    const pts: number[] = [];
    for (let i = 0; i < 6; i++) {
      const angle = (Math.PI / 3) * i - Math.PI / 6;
      pts.push(r + r * Math.cos(angle));
      pts.push(r + r * Math.sin(angle));
    }
    return pts;
  }

  // -------------------------------------------------------------------------
  // Current location marker
  // -------------------------------------------------------------------------

  private createCurrentMarker(): void {
    if (!this.currentDistrictId) return;
    const node = this.nodes.get(this.currentDistrictId);
    if (!node) return;

    this.currentMarker = this.add.circle(node.x, node.y - HEX_RADIUS - 12, 6, 0x44aaff, 1)
      .setDepth(10);

    // Bobbing animation
    this.tweens.add({
      targets: this.currentMarker,
      y: node.y - HEX_RADIUS - 18,
      duration: 800,
      yoyo: true,
      repeat: -1,
      ease: 'Sine.easeInOut',
    });
  }

  // -------------------------------------------------------------------------
  // District interaction
  // -------------------------------------------------------------------------

  private onDistrictTapped(district: District): void {
    if (!district.isRevealed) return; // can't interact with hidden districts

    this.showDistrictInfo(district);
    this.game.events.emit('worldmap:districtTapped', district);
    this.events.emit('districtTapped', district);
  }

  private showDistrictInfo(district: District): void {
    // Destroy previous panel
    if (this.infoPanel) {
      this.infoPanel.destroy();
      this.infoPanel = null;
    }

    const { width, height } = this.scale;
    const panelW = width - 40;
    const panelH = 170;
    const px = width / 2;
    const py = height - panelH / 2 - 20;

    const container = this.add.container(0, 0).setDepth(250).setScrollFactor(0);

    // Background
    const bg = this.add.rectangle(px, py, panelW, panelH, 0x1a1a2e, 0.95)
      .setStrokeStyle(1, 0x5555aa);
    container.add(bg);

    // District name
    container.add(
      this.add.text(px, py - panelH / 2 + 18, district.name, {
        fontSize: '16px',
        fontStyle: 'bold',
        color: '#ffcc66',
        stroke: '#000000',
        strokeThickness: 2,
      }).setOrigin(0.5),
    );

    // Biome + threat
    container.add(
      this.add.text(px, py - panelH / 2 + 40, `${district.biome}  |  Threat: ${district.threatLevel}/10`, {
        fontSize: '11px',
        color: '#aaaacc',
      }).setOrigin(0.5),
    );

    // Status
    const statusText = district.isCleared ? 'CLEARED' : 'HOSTILE';
    const statusColor = district.isCleared ? '#44ff44' : '#ff6644';
    container.add(
      this.add.text(px, py - panelH / 2 + 58, statusText, {
        fontSize: '11px',
        fontStyle: 'bold',
        color: statusColor,
      }).setOrigin(0.5),
    );

    // Rewards preview
    if (district.lootTable.length > 0) {
      const rewardStrs = district.lootTable
        .slice(0, 3)
        .map((l) => `${l.resourceType} (${l.minAmount}-${l.maxAmount})`);
      container.add(
        this.add.text(px, py - panelH / 2 + 78, `Rewards: ${rewardStrs.join(', ')}`, {
          fontSize: '9px',
          color: '#88aacc',
          wordWrap: { width: panelW - 30 },
        }).setOrigin(0.5),
      );
    }

    // Enter button (only for uncleared, revealed districts)
    if (!district.isCleared) {
      const enterBtn = this.add.text(px, py + panelH / 2 - 30, 'ENTER DISTRICT', {
        fontSize: '14px',
        fontStyle: 'bold',
        color: '#ffffff',
        backgroundColor: '#444466',
        padding: { x: 20, y: 8 },
      }).setOrigin(0.5).setInteractive();

      enterBtn.on('pointerdown', () => {
        this.game.events.emit('worldmap:enterDistrict', district);
        this.events.emit('enterDistrict', district);
      });
      container.add(enterBtn);
    }

    // Close button
    const closeBtn = this.add.text(px + panelW / 2 - 20, py - panelH / 2 + 8, 'X', {
      fontSize: '14px',
      fontStyle: 'bold',
      color: '#aa6666',
    }).setOrigin(0.5).setInteractive();

    closeBtn.on('pointerdown', () => {
      container.destroy();
      this.infoPanel = null;
    });
    container.add(closeBtn);

    this.infoPanel = container;
  }

  // -------------------------------------------------------------------------
  // Camera controls
  // -------------------------------------------------------------------------

  private setupCameraControls(sceneW: number, sceneH: number): void {
    // Bounds
    const margin = 100;
    this.cameras.main.setBounds(
      -margin,
      -margin,
      sceneW + margin * 2,
      sceneH + margin * 2,
    );

    // Drag to pan
    this.input.on('pointermove', (pointer: Phaser.Input.Pointer) => {
      if (!pointer.isDown) return;
      if (this.input.pointer1.isDown && this.input.pointer2.isDown) return;

      this.cameras.main.scrollX -= (pointer.x - pointer.prevPosition.x) / this.cameras.main.zoom;
      this.cameras.main.scrollY -= (pointer.y - pointer.prevPosition.y) / this.cameras.main.zoom;
    });

    // Pinch zoom
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
        this.cameras.main.setZoom(Phaser.Math.Clamp(this.pinchZoomStart * scale, 0.5, 2));
      }
    });

    this.input.on('pointerup', () => {
      this.pinchDistance = null;
    });

    // Mouse wheel zoom
    this.input.on('wheel', (_pointer: Phaser.Input.Pointer, _gx: number[], _gy: number[], _gz: number[], _ev: Event, deltaY: number) => {
      const newZoom = this.cameras.main.zoom - deltaY * 0.001;
      this.cameras.main.setZoom(Phaser.Math.Clamp(newZoom, 0.5, 2));
    });
  }
}
