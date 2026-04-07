/**
 * MainMenuScene.ts — Atmospheric main-menu backdrop for Project Ashfall.
 *
 * Renders falling ash/ember particles, drifting smoke, and an ambient
 * flickering light overlay.  The actual menu buttons live in the HTML
 * overlay (index.html), so this scene only provides the visual ambiance.
 */

export default class MainMenuScene extends Phaser.Scene {
  /** Colour tint overlay that flickers to simulate firelight. */
  private lightOverlay!: Phaser.GameObjects.Rectangle;

  /** Timer that drives the flicker effect. */
  private flickerTimer = 0;

  /** Base alpha for the overlay. */
  private readonly FLICKER_BASE = 0.06;

  constructor() {
    super({ key: 'MainMenuScene' });
  }

  // -------------------------------------------------------------------------
  // Phaser lifecycle
  // -------------------------------------------------------------------------

  create(): void {
    const { width, height } = this.scale;

    // -- dark gradient background ----------------------------------------
    this.createGradientBackground(width, height);

    // -- falling ash / ember particles -----------------------------------
    this.createAshEmitters(width, height);

    // -- drifting smoke layers -------------------------------------------
    this.createSmokeLayer(width, height);

    // -- ambient flicker overlay -----------------------------------------
    this.lightOverlay = this.add.rectangle(
      width / 2,
      height / 2,
      width,
      height,
      0xff8833,
      this.FLICKER_BASE,
    );
    this.lightOverlay.setDepth(10);
    this.lightOverlay.setBlendMode(Phaser.BlendModes.ADD);

    // Notify HTML layer that the menu scene is ready
    this.game.events.emit('mainmenu:ready');
  }

  update(_time: number, delta: number): void {
    // Animate flickering light
    this.flickerTimer += delta * 0.004;
    const flicker =
      this.FLICKER_BASE +
      Math.sin(this.flickerTimer * 2.3) * 0.02 +
      Math.sin(this.flickerTimer * 5.7) * 0.01 +
      Math.random() * 0.015;
    this.lightOverlay.setAlpha(Phaser.Math.Clamp(flicker, 0, 0.15));
  }

  // -------------------------------------------------------------------------
  // Visual builders
  // -------------------------------------------------------------------------

  /**
   * Fill the background with a dark vertical gradient simulating a hazy
   * post-apocalyptic sky.
   */
  private createGradientBackground(w: number, h: number): void {
    const bg = this.add.graphics();
    const topColor = Phaser.Display.Color.HexStringToColor('#0d0d14');
    const bottomColor = Phaser.Display.Color.HexStringToColor('#1a1008');

    const steps = 32;
    const sliceH = Math.ceil(h / steps);

    for (let i = 0; i < steps; i++) {
      const t = i / (steps - 1);
      const r = Phaser.Math.Linear(topColor.red, bottomColor.red, t);
      const g = Phaser.Math.Linear(topColor.green, bottomColor.green, t);
      const b = Phaser.Math.Linear(topColor.blue, bottomColor.blue, t);
      const color = Phaser.Display.Color.GetColor(r, g, b);

      bg.fillStyle(color, 1);
      bg.fillRect(0, i * sliceH, w, sliceH + 1);
    }

    bg.setDepth(0);
  }

  /**
   * Create two particle emitters: slow grey ash and faster glowing embers.
   */
  private createAshEmitters(w: number, h: number): void {
    // Ash particles — slow, grey, drifting down
    const ashEmitter = this.add.particles(0, 0, 'particle_ash', {
      x: { min: 0, max: w },
      y: -10,
      lifespan: { min: 6000, max: 10000 },
      speedY: { min: 15, max: 40 },
      speedX: { min: -10, max: 10 },
      scale: { start: 0.8, end: 0.3 },
      alpha: { start: 0.5, end: 0 },
      frequency: 120,
      quantity: 1,
      gravityY: 5,
    });
    ashEmitter.setDepth(2);

    // Ember particles — smaller, orange, slightly faster
    const emberEmitter = this.add.particles(0, 0, 'particle_ember', {
      x: { min: 0, max: w },
      y: h + 10,
      lifespan: { min: 3000, max: 6000 },
      speedY: { min: -30, max: -60 },
      speedX: { min: -20, max: 20 },
      scale: { start: 0.6, end: 0 },
      alpha: { start: 0.8, end: 0 },
      frequency: 300,
      quantity: 1,
      blendMode: Phaser.BlendModes.ADD,
    });
    emberEmitter.setDepth(3);
  }

  /**
   * Create translucent smoke rectangles that slowly drift across the screen
   * to simulate rolling fog.
   */
  private createSmokeLayer(w: number, h: number): void {
    const smokeCount = 5;

    for (let i = 0; i < smokeCount; i++) {
      const smokeW = Phaser.Math.Between(200, 400);
      const smokeH = Phaser.Math.Between(60, 140);
      const y = Phaser.Math.Between(Math.floor(h * 0.3), Math.floor(h * 0.9));
      const startX = Phaser.Math.Between(-smokeW, Math.floor(w));
      const baseAlpha = Phaser.Math.FloatBetween(0.04, 0.1);

      const smoke = this.add.rectangle(startX, y, smokeW, smokeH, 0x888888, baseAlpha);
      smoke.setDepth(1);
      smoke.setBlendMode(Phaser.BlendModes.ADD);

      // Drift the smoke rightward; loop back when off-screen
      const speed = Phaser.Math.FloatBetween(8, 25); // px/sec

      this.tweens.add({
        targets: smoke,
        x: w + smokeW,
        duration: ((w + smokeW * 2 - startX) / speed) * 1000,
        ease: 'Linear',
        repeat: -1,
        onRepeat: () => {
          smoke.x = -smokeW;
          smoke.y = Phaser.Math.Between(Math.floor(h * 0.3), Math.floor(h * 0.9));
        },
      });

      // Gentle alpha pulsing
      this.tweens.add({
        targets: smoke,
        alpha: baseAlpha * 1.6,
        duration: Phaser.Math.Between(3000, 6000),
        yoyo: true,
        repeat: -1,
        ease: 'Sine.easeInOut',
      });
    }
  }
}
