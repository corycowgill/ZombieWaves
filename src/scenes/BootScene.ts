/**
 * BootScene.ts — Boot / preload scene for Project Ashfall.
 *
 * Generates all placeholder textures programmatically (colored rectangles,
 * circles, and simple shapes) so the game can run without any external
 * image assets.  Once generation is complete, transitions to MainMenuScene.
 */

export default class BootScene extends Phaser.Scene {
  constructor() {
    super({ key: 'BootScene' });
  }

  // -------------------------------------------------------------------------
  // Phaser lifecycle
  // -------------------------------------------------------------------------

  preload(): void {
    this.generateBuildingTextures();
    this.generateHeroTextures();
    this.generateEnemyTextures();
    this.generateTileTextures();
    this.generateUITextures();
    this.generateProjectileTextures();
  }

  create(): void {
    this.scene.start('MainMenuScene');
  }

  // -------------------------------------------------------------------------
  // Texture generation helpers
  // -------------------------------------------------------------------------

  /**
   * Create a filled-rectangle texture and add it to the texture manager.
   */
  private makeRect(
    key: string,
    width: number,
    height: number,
    color: string,
    borderColor?: string,
  ): void {
    const canvas = this.textures.createCanvas(key, width, height);
    if (!canvas) return;
    const ctx = canvas.context;

    ctx.fillStyle = color;
    ctx.fillRect(0, 0, width, height);

    if (borderColor) {
      ctx.strokeStyle = borderColor;
      ctx.lineWidth = 2;
      ctx.strokeRect(1, 1, width - 2, height - 2);
    }

    canvas.refresh();
  }

  /**
   * Create a filled-circle texture centred on a transparent canvas.
   */
  private makeCircle(
    key: string,
    radius: number,
    color: string,
    borderColor?: string,
  ): void {
    const size = radius * 2;
    const canvas = this.textures.createCanvas(key, size, size);
    if (!canvas) return;
    const ctx = canvas.context;

    ctx.clearRect(0, 0, size, size);
    ctx.beginPath();
    ctx.arc(radius, radius, radius - 1, 0, Math.PI * 2);
    ctx.fillStyle = color;
    ctx.fill();

    if (borderColor) {
      ctx.strokeStyle = borderColor;
      ctx.lineWidth = 2;
      ctx.stroke();
    }

    canvas.refresh();
  }

  /**
   * Create a diamond (isometric tile) texture.
   */
  private makeDiamond(
    key: string,
    width: number,
    height: number,
    fillColor: string,
    strokeColor: string,
  ): void {
    const canvas = this.textures.createCanvas(key, width, height);
    if (!canvas) return;
    const ctx = canvas.context;

    const hw = width / 2;
    const hh = height / 2;

    ctx.clearRect(0, 0, width, height);
    ctx.beginPath();
    ctx.moveTo(hw, 0);
    ctx.lineTo(width, hh);
    ctx.lineTo(hw, height);
    ctx.lineTo(0, hh);
    ctx.closePath();
    ctx.fillStyle = fillColor;
    ctx.fill();
    ctx.strokeStyle = strokeColor;
    ctx.lineWidth = 1;
    ctx.stroke();

    canvas.refresh();
  }

  // -------------------------------------------------------------------------
  // Asset groups
  // -------------------------------------------------------------------------

  private generateBuildingTextures(): void {
    const buildings: Array<[string, string, string?]> = [
      ['building_command_center', '#FFD700', '#B8860B'],   // gold
      ['building_barracks',       '#CC3333', '#8B0000'],   // red
      ['building_farm',           '#228B22', '#006400'],   // green
      ['building_water_purifier', '#4169E1', '#00008B'],   // blue
      ['building_workshop',       '#FF8C00', '#CC7000'],   // orange
      ['building_hospital',       '#FFFFFF', '#AAAAAA'],   // white (infirmary)
      ['building_watchtower',     '#8B8682', '#555555'],   // stone (radar tower)
      ['building_lab',            '#9370DB', '#6A0DAD'],   // purple (research lab)
      ['building_wall',           '#696969', '#333333'],   // gray
      ['building_fuel_depot',     '#FF6347', '#CC4030'],   // tomato
      ['building_scrapyard',      '#B8860B', '#8B6914'],   // dark goldenrod
      ['building_hero_quarters',  '#DA70D6', '#8B008B'],   // orchid
      ['building_turret',         '#556B2F', '#3B4A1F'],   // olive drab
      ['building_trap',           '#CD853F', '#8B5A2B'],   // peru
      ['building_garage',         '#4682B4', '#2F5F8A'],   // steel blue
    ];

    for (const [key, fill, border] of buildings) {
      this.makeRect(key, 48, 48, fill, border);
    }
  }

  private generateHeroTextures(): void {
    const heroes: Array<[string, string, string?]> = [
      ['hero_assault',     '#FF4444', '#CC0000'],
      ['hero_heavy',       '#999999', '#666666'],
      ['hero_recon',       '#44CC44', '#228B22'],
      ['hero_medic',       '#FFFFFF', '#CCCCCC'],
      ['hero_engineer',    '#FFD700', '#DAA520'],
      ['hero_sniper',      '#9966CC', '#6A0DAD'],
      ['hero_demolitions', '#FF8C00', '#CC7000'],
    ];

    for (const [key, fill, border] of heroes) {
      this.makeCircle(key, 16, fill, border);
    }
  }

  private generateEnemyTextures(): void {
    const enemies: Array<[string, string, string?]> = [
      ['enemy_shambler', '#2E4B2E', '#1A2E1A'],  // dark green
      ['enemy_runner',   '#32CD32', '#228B22'],   // lime
      ['enemy_spitter',  '#9ACD32', '#6B8E23'],   // yellow-green
      ['enemy_bruiser',  '#8B4513', '#5C2E0E'],   // brown
      ['enemy_raider',   '#CC3333', '#8B0000'],   // red
      ['enemy_militia',  '#191970', '#0A0A45'],   // dark blue
    ];

    for (const [key, fill, border] of enemies) {
      this.makeCircle(key, 14, fill, border);
    }
  }

  private generateTileTextures(): void {
    // Isometric diamond tiles — 64 x 32 for iso grid
    const tiles: Array<[string, string, string]> = [
      ['tile_grass',    '#4A7C3F', '#3A6430'],
      ['tile_dirt',     '#8B7355', '#6B5335'],
      ['tile_concrete', '#A9A9A9', '#808080'],
      ['tile_cover',    '#6B6B3C', '#4A4A2A'],
      ['tile_wall',     '#555555', '#333333'],
      ['tile_hazard',   '#CC4444', '#992222'],
    ];

    for (const [key, fill, stroke] of tiles) {
      this.makeDiamond(key, 64, 32, fill, stroke);
    }

    // Non-iso flat versions for combat grid
    const flatTiles: Array<[string, string, string?]> = [
      ['flat_grass',    '#4A7C3F', '#3A6430'],
      ['flat_dirt',     '#8B7355', '#6B5335'],
      ['flat_concrete', '#A9A9A9', '#808080'],
      ['flat_cover',    '#6B6B3C', '#4A4A2A'],
      ['flat_wall',     '#555555', '#333333'],
      ['flat_hazard',   '#CC4444', '#992222'],
    ];

    for (const [key, fill, border] of flatTiles) {
      this.makeRect(key, 40, 40, fill, border);
    }
  }

  private generateUITextures(): void {
    // Buttons
    this.makeRect('ui_button', 160, 44, '#3A3A4A', '#6A6A8A');
    this.makeRect('ui_button_highlight', 160, 44, '#5A5A7A', '#8A8ABA');

    // Panel backgrounds
    this.makeRect('ui_panel', 320, 480, 'rgba(20,20,30,0.85)', '#555577');
    this.makeRect('ui_panel_small', 200, 120, 'rgba(20,20,30,0.9)', '#555577');

    // Health bar segments
    this.makeRect('ui_health_bg', 32, 4, '#333333');
    this.makeRect('ui_health_fill', 32, 4, '#44CC44');
    this.makeRect('ui_health_fill_low', 32, 4, '#CC4444');

    // Selection indicator
    this.makeCircle('ui_select_ring', 20, 'rgba(0,0,0,0)', '#00FFFF');

    // Skill button
    this.makeRect('ui_skill_button', 48, 48, '#2A2A3A', '#7777AA');

    // Icon placeholders
    this.makeRect('icon_food', 20, 20, '#228B22');
    this.makeRect('icon_water', 20, 20, '#4169E1');
    this.makeRect('icon_fuel', 20, 20, '#FF8C00');
    this.makeRect('icon_scrap', 20, 20, '#8B8682');

    // Star (rank indicator) — tiny yellow square
    this.makeRect('ui_star', 10, 10, '#FFD700', '#DAA520');
    this.makeRect('ui_star_empty', 10, 10, '#333333', '#555555');

    // Fog overlay
    this.makeRect('ui_fog', 64, 64, 'rgba(10,10,15,0.8)');

    // Checkmark — small green square
    this.makeRect('ui_check', 16, 16, '#44CC44');

    // Lock icon placeholder
    this.makeRect('ui_lock', 24, 24, '#555555', '#888888');
  }

  private generateProjectileTextures(): void {
    // Bullet — small bright rectangle
    this.makeRect('projectile_bullet', 6, 3, '#FFFF00');

    // Explosion — orange circle
    this.makeCircle('projectile_explosion', 12, '#FF6600', '#FF3300');
    this.makeCircle('projectile_explosion_large', 24, '#FF4400', '#CC2200');

    // Heal effect — green circle
    this.makeCircle('effect_heal', 10, '#44FF44', '#22CC22');

    // Shield effect — blue circle
    this.makeCircle('effect_shield', 12, '#4488FF', '#2266CC');

    // Particle textures
    this.makeRect('particle_ember', 4, 4, '#FF6633');
    this.makeRect('particle_ash', 3, 3, '#888888');
    this.makeRect('particle_smoke', 8, 8, 'rgba(100,100,100,0.6)');
    this.makeCircle('particle_glow', 6, 'rgba(255,200,50,0.7)');
  }
}
