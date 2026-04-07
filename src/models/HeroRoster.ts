/**
 * HeroRoster.ts — Pre-defined hero roster for Project Ashfall.
 */

import { Hero, HeroRole, HeroRarity, HeroStats, Skill, GearItem } from './Hero';

function makeSkill(
  id: string,
  name: string,
  description: string,
  effectType: Skill['effectType'],
  targetType: Skill['targetType'] = 'single',
  damage: number = 0,
  healAmount: number = 0,
): Skill {
  return {
    id,
    name,
    description,
    type: 'active',
    targetType,
    cooldown: 5,
    currentCooldown: 0,
    damage,
    healAmount,
    duration: 0,
    effectType,
    unlockLevel: 1,
    iconKey: `icon_${id}`,
  };
}

function makeWeapon(id: string, name: string, attack: number): GearItem {
  return {
    id,
    name,
    slot: 'weapon',
    rarity: HeroRarity.Rare,
    statBonuses: { attack },
    description: `Signature weapon: ${name}`,
  };
}

function makeStats(
  health: number,
  attack: number,
  defense: number,
  speed: number,
  critChance: number = 0.1,
  critMultiplier: number = 1.5,
): HeroStats {
  return { health, maxHealth: health, attack, defense, speed, critChance, critMultiplier };
}

export function createHeroRoster(): Hero[] {
  return [
    new Hero({
      id: 'hero_marcus', name: 'Marcus Cole', role: HeroRole.Assault, rarity: HeroRarity.Elite,
      baseStats: makeStats(550, 85, 45, 60, 0.15, 1.6),
      skills: [makeSkill('sk_marcus_1', 'Rapid Fire', 'Fires a burst of rounds', 'damage', 'single', 120)],
      signatureWeapon: makeWeapon('sw_marcus', 'Crimson Fury', 20),
      backstory: 'Former military squad leader who survived the first wave.',
      bondPartnerIds: ['hero_elena'], isUnlocked: false, morale: 100,
    }),
    new Hero({
      id: 'hero_elena', name: 'Elena Vasquez', role: HeroRole.Medic, rarity: HeroRarity.Elite,
      baseStats: makeStats(480, 40, 50, 55, 0.05, 1.3),
      skills: [makeSkill('sk_elena_1', 'Field Triage', 'Heals a single ally', 'heal', 'single', 0, 150)],
      signatureWeapon: makeWeapon('sw_elena', 'Mercy Syringe', 10),
      backstory: 'Combat medic who refused to leave her unit behind.',
      bondPartnerIds: ['hero_marcus'], isUnlocked: false, morale: 100,
    }),
    new Hero({
      id: 'hero_jim', name: 'Jim Tanaka', role: HeroRole.Heavy, rarity: HeroRarity.Rare,
      baseStats: makeStats(700, 70, 65, 35, 0.08, 1.5),
      skills: [makeSkill('sk_jim_1', 'Shield Wall', 'Raises a heavy shield', 'shield', 'self')],
      signatureWeapon: makeWeapon('sw_jim', 'Iron Bastion', 15),
      backstory: 'Former construction foreman turned frontline defender.',
      bondPartnerIds: ['hero_tommy'], isUnlocked: false, morale: 100,
    }),
    new Hero({
      id: 'hero_zara', name: 'Zara Okafor', role: HeroRole.Recon, rarity: HeroRarity.Rare,
      baseStats: makeStats(420, 65, 35, 80, 0.2, 1.8),
      skills: [makeSkill('sk_zara_1', 'Shadow Step', 'Enters stealth mode', 'stealth', 'self')],
      signatureWeapon: makeWeapon('sw_zara', 'Silent Edge', 18),
      backstory: 'Tracker and survivalist from the outer districts.',
      bondPartnerIds: ['hero_nadia'], isUnlocked: false, morale: 100,
    }),
    new Hero({
      id: 'hero_lena', name: 'Dr. Lena Morse', role: HeroRole.Engineer, rarity: HeroRarity.Legendary,
      baseStats: makeStats(460, 50, 55, 50, 0.1, 1.5),
      skills: [makeSkill('sk_lena_1', 'Deploy Turret', 'Deploys an automated turret', 'deploy', 'area', 80)],
      signatureWeapon: makeWeapon('sw_lena', 'Arc Welder', 12),
      backstory: 'Brilliant engineer who designed the base defenses.',
      bondPartnerIds: ['hero_priya'], isUnlocked: false, morale: 100,
    }),
    new Hero({
      id: 'hero_victor', name: 'Victor Hale', role: HeroRole.Sniper, rarity: HeroRarity.Elite,
      baseStats: makeStats(400, 95, 30, 55, 0.25, 2.0),
      skills: [makeSkill('sk_victor_1', 'Headshot', 'A precise lethal shot', 'damage', 'single', 200)],
      signatureWeapon: makeWeapon('sw_victor', 'Whisper', 25),
      backstory: 'Ex-competitive marksman who never misses.',
      bondPartnerIds: ['hero_sasha'], isUnlocked: false, morale: 100,
    }),
    new Hero({
      id: 'hero_sasha', name: 'Sasha Petrov', role: HeroRole.Demolitions, rarity: HeroRarity.Rare,
      baseStats: makeStats(520, 80, 40, 45, 0.12, 1.6),
      skills: [makeSkill('sk_sasha_1', 'Frag Grenade', 'Throws an explosive grenade', 'explosiveDamage', 'area', 150)],
      signatureWeapon: makeWeapon('sw_sasha', 'Boom Stick', 22),
      backstory: 'Demolitions expert with a love for controlled chaos.',
      bondPartnerIds: ['hero_victor'], isUnlocked: false, morale: 100,
    }),
    new Hero({
      id: 'hero_maya', name: 'Maya Chen', role: HeroRole.Assault, rarity: HeroRarity.Common,
      baseStats: makeStats(500, 75, 42, 62, 0.12, 1.5),
      skills: [makeSkill('sk_maya_1', 'Battle Cry', 'Boosts team attack', 'attackBoost', 'allAllies')],
      signatureWeapon: makeWeapon('sw_maya', 'Dragon Fang', 16),
      backstory: 'Street fighter who rallied survivors in the early days.',
      bondPartnerIds: ['hero_eli'], isUnlocked: false, morale: 100,
    }),
    new Hero({
      id: 'hero_eli', name: 'Eli Watts', role: HeroRole.Medic, rarity: HeroRarity.Common,
      baseStats: makeStats(470, 38, 48, 58, 0.06, 1.3),
      skills: [makeSkill('sk_eli_1', 'Healing Wave', 'Heals all allies', 'heal', 'allAllies', 0, 80)],
      signatureWeapon: makeWeapon('sw_eli', 'Pulse Staff', 8),
      backstory: 'Former paramedic who kept people alive against all odds.',
      bondPartnerIds: ['hero_maya'], isUnlocked: false, morale: 100,
    }),
    new Hero({
      id: 'hero_priya', name: 'Priya Nair', role: HeroRole.Engineer, rarity: HeroRarity.Rare,
      baseStats: makeStats(450, 55, 52, 48, 0.1, 1.5),
      skills: [makeSkill('sk_priya_1', 'Repair Drone', 'Deploys a repair drone', 'heal', 'single', 0, 100)],
      signatureWeapon: makeWeapon('sw_priya', 'Nano Wrench', 14),
      backstory: 'Robotics specialist who repurposes scrap into tools.',
      bondPartnerIds: ['hero_lena'], isUnlocked: false, morale: 100,
    }),
    new Hero({
      id: 'hero_tommy', name: 'Tommy Rourke', role: HeroRole.Heavy, rarity: HeroRarity.Common,
      baseStats: makeStats(680, 65, 60, 38, 0.07, 1.4),
      skills: [makeSkill('sk_tommy_1', 'Ground Slam', 'Stuns nearby enemies', 'stun', 'area', 90)],
      signatureWeapon: makeWeapon('sw_tommy', 'War Hammer', 18),
      backstory: 'Brawler with an iron will and unbreakable spirit.',
      bondPartnerIds: ['hero_jim'], isUnlocked: false, morale: 100,
    }),
    new Hero({
      id: 'hero_nadia', name: 'Nadia Kouri', role: HeroRole.Recon, rarity: HeroRarity.Elite,
      baseStats: makeStats(410, 68, 32, 85, 0.22, 1.9),
      skills: [makeSkill('sk_nadia_1', 'Mark Target', 'Reveals and debuffs a target', 'reveal', 'single')],
      signatureWeapon: makeWeapon('sw_nadia', 'Ghost Blade', 20),
      backstory: 'Intelligence operative who maps the dead zones.',
      bondPartnerIds: ['hero_zara'], isUnlocked: false, morale: 100,
    }),
  ];
}
