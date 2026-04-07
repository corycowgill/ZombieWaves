/**
 * AudioManager.ts — Audio system for Project Ashfall.
 */

export class AudioManager {
  public musicVolume: number = 0.6;
  public sfxVolume: number = 0.8;

  setMusicVolume(v: number): void {
    this.musicVolume = Math.max(0, Math.min(1, v));
  }

  setSFXVolume(v: number): void {
    this.sfxVolume = Math.max(0, Math.min(1, v));
  }

  playMusic(key: string): void {
    // Minimal stub — actual audio playback handled by engine
    void key;
  }

  playSFX(key: string): void {
    void key;
  }

  stopMusic(): void {
    // Minimal stub
  }
}
