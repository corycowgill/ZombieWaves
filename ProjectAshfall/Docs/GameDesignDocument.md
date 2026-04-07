# Project Ashfall -- Game Design Document

**Version:** 1.0  
**Date:** 2026-04-07  
**Platform:** iOS (iPhone / iPad)  
**Genre:** Post-Apocalyptic Survival Strategy  
**Player Count:** Single-player  
**Target Rating:** T (Teen)

---

## 1. High Concept

Six months after a weaponized fungal pathogen turns 70 % of the global population into hostile Infected, the player commands a small band of survivors tasked with reclaiming the ruined city of Ashfall -- district by district -- while uncovering the conspiracy behind the outbreak. Gameplay blends real-time tactical combat, base building, squad management, and narrative decision-making into a cohesive survival-strategy experience designed for mobile sessions of 5--30 minutes.

---

## 2. Design Pillars

| # | Pillar | Meaning |
|---|--------|---------|
| 1 | **Scarcity Drives Decisions** | Every resource is limited; the player must constantly triage between survival needs. |
| 2 | **Heroes Over Numbers** | A small roster of deeply characterised heroes matters more than disposable units. |
| 3 | **Reclaim, Don't Conquer** | The fantasy is rebuilding civilisation, not dominating enemies. |
| 4 | **Bite-Sized Sessions** | Every interaction must be completable in a single mobile session (<=30 min). |
| 5 | **Narrative Weight** | Player choices permanently alter the world state and available endings. |

---

## 3. Anti-Pillars (What This Game Is NOT)

- **Not a gacha game.** Heroes are earned through gameplay, never purchased randomly.
- **Not an idle game.** Progress requires active player engagement.
- **Not competitive multiplayer.** No PvP, no leaderboards, no social pressure.
- **Not a horror game.** Tone is tense but hopeful; violence is stylised, never gratuitous.
- **Not a city-builder sim.** Base building serves combat readiness, not sandbox creativity.

---

## 4. Target Audience

| Attribute | Detail |
|-----------|--------|
| Primary | Mobile strategy gamers, age 16--35 |
| Secondary | Narrative RPG fans who enjoy character-driven stories |
| Comparables | XCOM (tactics), State of Survival (base building), Darkest Dungeon (hero management) |
| Session length | 5--30 minutes |
| Monetisation tolerance | Premium purchase ($6.99) + optional cosmetic IAP; zero pay-to-win |

---

## 5. Visual Style

- **Art direction:** Stylised realism with a muted, desaturated palette punctuated by vivid accent colours (orange flame, green fungal glow, blue UI).
- **Character art:** Hand-painted 2D portraits for menus; 3D low-poly models with PBR shading in gameplay.
- **Environment:** Isometric 3D with baked lighting and real-time shadows for time-of-day cycle.
- **VFX:** Particle-heavy abilities; screen-shake and chromatic aberration for impacts; spore clouds for Infected zones.
- **UI theme:** Weathered military field-manual aesthetic -- stencil fonts, torn-paper textures, clipboard frames.

---

## 6. Camera System

| Context | Camera |
|---------|--------|
| Base view | Top-down isometric, pinch-to-zoom (3 zoom levels), free pan within base bounds |
| Combat | Isometric with slight tilt; auto-follow active hero; tap-to-snap to any unit |
| World map | 2D stylised satellite view; pinch-to-zoom; district highlights |
| Menus | Fixed 2D overlay; parallax background |

---

## 7. Complete Game Loop

### 7.1 Outer Loop (Macro)

```
Campaign Map --> Select District --> Establish / Upgrade Base --> Deploy Squads --> Complete Missions --> Unlock Next District --> Repeat
```

A full campaign run spans **5 acts, 25 chapters, ~40 hours** of gameplay.

### 7.2 Inner Loop (Session)

```
Collect Resources --> Build / Upgrade Structures --> Equip & Level Heroes --> Launch Mission --> Earn Rewards --> Return to Base
```

Average session: select a mission, resolve combat (3--8 min), spend rewards (2--5 min).

### 7.3 Engagement Hooks

- **Daily supply drop** -- bonus resources for first login each day.
- **Rotating Expeditions** -- procedurally generated maps refreshed every 12 hours.
- **Hero bond events** -- unlock narrative vignettes by pairing specific heroes on missions.

---

## 8. Game Modes

### 8.1 Campaign

The primary story-driven mode. Linear progression through 5 acts (see CampaignOutline.md). Each chapter contains 2--4 missions with branching objectives and decision points that affect world state.

### 8.2 Expedition

Procedurally generated tactical missions with random modifiers (fog, night, toxic spores). Rewards scale with difficulty tier (Bronze / Silver / Gold / Platinum). Refreshed every 12 hours.

### 8.3 Defense

Wave-based survival at the player's base. Waves increase in size and enemy variety. Rewards granted per wave survived; bonus chest at waves 10, 20, 30, 50. Leaderboard is personal-best only (no social).

### 8.4 Recovery

Resource-focused missions. The player sends a squad to scavenge a specific resource type. Success rate depends on squad composition and power rating vs. zone danger level. Missions resolve in real time (15 min -- 2 hr) but can be "rushed" with an in-game Fuel token (earnable, not purchasable).

---

## 9. Base Building

The player's base is a grid-based compound (12 x 12 tiles at max expansion). Buildings fall into four categories:

| Category | Buildings |
|----------|-----------|
| **Production** | Supply Depot, Water Purifier, Fuel Refinery, Farm, Workshop |
| **Military** | Barracks, Armoury, Watchtower, War Room |
| **Research** | Lab, Comms Tower, Archive |
| **Infrastructure** | Generator, Medical Bay, Housing |

Each building has 10 upgrade levels. Higher levels increase output, unlock abilities, and visually evolve (e.g., Barracks Lv 1 is a tent; Lv 10 is a fortified bunker). Full details in TechTree.md.

---

## 10. Resource Economy

Five primary resources:

| Resource | Source | Use |
|----------|--------|-----|
| **Supplies** | Supply Depot, missions | Building construction, hero gear |
| **Water** | Water Purifier, missions | Sustenance, medical items |
| **Fuel** | Fuel Refinery, missions | Expedition launches, rush timers |
| **Scrap** | Workshop salvage, missions | Weapon / armour crafting |
| **Intel** | Comms Tower, story missions | Tech research, world-map recon |

Detailed generation rates, cost curves, and balance formulas are in EconomyModel.md.

---

## 11. Combat System

### 11.1 Overview

Real-time with tactical pause. Squads of up to 4 heroes deploy onto an isometric grid map. The player issues move, attack, and ability commands. When paused, the player can queue orders for all heroes. Combat auto-resolves if the player enables Auto-Battle.

### 11.2 Core Formula

```
Damage = ATK * (100 / (100 + DEF))
```

Critical hits multiply final damage by 1.5. Elemental modifiers apply a +25 % / -25 % layer. Full specification in CombatPrototypeSpec.md.

### 11.3 Cover

- **Half cover:** +30 DEF, blocks LoS for low projectiles.
- **Full cover:** +60 DEF, blocks all non-arcing projectiles, breakable (HP = 150).
- **Elevated position:** +15 % damage dealt, -10 % damage received.

### 11.4 Status Effects

Burn, Poison, Stun, Slow, Bleed, Weaken, Expose, Shield, Regen, Haste. Each has duration (turns), potency, and stacking rules (see CombatPrototypeSpec.md).

---

## 12. Hero System

### 12.1 Roster

12 heroes across 6 classes: Assault, Medic, Heavy, Recon, Engineer, Sniper, Demolitions. Each hero has:

- 6 core stats (HP, ATK, DEF, SPD, CRT, RES)
- 1 signature weapon
- 3 active skills, 1 ultimate skill, 2 passive skills
- Bond partners that grant bonus effects when paired
- A personal side-quest unlocked at Trust Level 3

Full hero details in HeroRoster.md.

### 12.2 Progression

| System | Mechanic |
|--------|----------|
| **Level** | XP from missions; max Lv 60; stat gains per level |
| **Gear** | Weapon + Armour + Accessory; rarity tiers Common / Uncommon / Rare / Epic / Legendary |
| **Skills** | Skill points earned every 5 levels; unlock and upgrade skill tree |
| **Trust** | Bond XP from co-deployment; unlocks bond bonuses and story vignettes at Levels 1--5 |
| **Promotion** | At Lv 20, 40, 60 heroes can be promoted (stat boost + new skin) |

---

## 13. Enemy Roster

### 13.1 Infected

Six archetypes escalating in threat: Shambler (fodder), Runner (fast), Spitter (ranged), Bruiser (tank), Screecher (support/alarm), Burrower (ambush). Each has tactical counters.

### 13.2 Human Hostiles

Raiders (aggressive, low-tech), Militia (organised, medium-tech), Rogue Scientists (high-tech, deploy drones and chemical weapons).

### 13.3 Bosses

Five act bosses plus two optional superbosses. Each boss has 3 phases with unique mechanics. See EnemyRoster.md.

---

## 14. World Map

Ashfall is divided into **8 districts**, each with a distinct biome and enemy composition:

| District | Biome | Primary Threat | Act |
|----------|-------|---------------|-----|
| Maplewood (Suburbs) | Residential ruins | Shamblers, Runners | 1 |
| Riverside | Flooded industrial | Spitters, Burrowers | 1--2 |
| Old Town | Dense urban | Raiders, Militia | 2 |
| The Foundry | Factory complex | Bruisers, Rogue Scientists | 3 |
| Greenhill | Overgrown park | All Infected types | 3 |
| University Quarter | Campus / labs | Rogue Scientists | 4 |
| Power Grid | Energy infrastructure | Militia, Screechers | 4 |
| Ground Zero | Blast crater / origin site | All types, boss gauntlet | 5 |

Districts are unlocked linearly through the campaign but can be revisited for Expeditions and Recovery missions.

---

## 15. Narrative

### 15.1 Premise

The Ashfall Incident: a fungal bio-weapon detonated in the city's centre six months ago. The protagonist (the player, addressed as "Commander") arrives with a small convoy to establish a foothold and find the source.

### 15.2 Five-Act Structure

| Act | Title | Theme | Key Revelation |
|-----|-------|-------|----------------|
| 1 | **Landfall** | Survival, hope | The infection is not natural |
| 2 | **Fault Lines** | Conspiracy, mistrust | A corporation engineered the pathogen |
| 3 | **Broken Alliances** | Faction conflict | Rival survivors have conflicting agendas |
| 4 | **Reclamation** | Rebuilding, sacrifice | A cure prototype exists but requires sacrifice |
| 5 | **Ground Zero** | Confrontation, choice | The player decides the city's fate |

### 15.3 Decision Points

Each act contains at least 2 binary decision points that alter NPC availability, resource flow, and which of 3 endings the player reaches:

- **Restoration Ending** -- cure deployed, city begins recovery.
- **Exodus Ending** -- survivors abandon Ashfall, save themselves.
- **Dominion Ending** -- player seizes control, morally grey.

Full chapter-by-chapter breakdown in CampaignOutline.md.

---

## 16. UX Principles

1. **One-thumb reachability.** All primary actions within thumb arc on standard iPhone.
2. **Glanceable HUD.** No more than 5 elements on-screen during combat; secondary info behind one tap.
3. **Undo safety net.** Building placement and squad assignment can be undone within 5 seconds.
4. **Progressive disclosure.** New systems introduced one per chapter across Act 1; tooltips on first encounter.
5. **Save anywhere.** Auto-save every 30 seconds; manual save available in pause menu.
6. **Colour-blind safe.** All colour-coded information doubled with icons/shapes.

---

## 17. Audio Design

### 17.1 Music

- **Base:** Ambient post-rock; evolves in complexity as base grows.
- **Combat:** Dynamic layered tracks; percussion intensifies with enemy count; brass stings on boss encounters.
- **Menus:** Soft acoustic guitar with environmental ambience.
- **Narrative:** Orchestral swells for key story beats.

### 17.2 SFX

- Per-weapon fire/impact sounds.
- Infected vocalizations unique per archetype (Shambler groan, Runner shriek, Screecher wail).
- Environmental audio: wind, distant explosions, creaking structures.
- UI: tactile click/confirm sounds; satisfying "build complete" chime.

### 17.3 Voice

- Hero barks on deploy, ability use, low HP, kill.
- Full voice acting for campaign cutscenes (estimated 3 hours of VO).
- Commander is silent; NPCs address the player directly.

---

## 18. Accessibility

| Feature | Detail |
|---------|--------|
| Text size | Three settings: Standard, Large, Extra-Large |
| Colour-blind modes | Protanopia, Deuteranopia, Tritanopia filters |
| Subtitles | Always-on option with speaker labels and background opacity slider |
| Controls | Full support for Switch Control and Voice Control on iOS |
| Difficulty | Story (enemies -50 % stats), Normal, Veteran (+25 %), Apocalypse (+50 %, permadeath) |
| Motion | Option to disable screen-shake, camera bob, and particle density |
| Haptics | All haptic feedback can be toggled independently |

---

## 19. Content Pipeline

### 19.1 Asset Categories

| Category | Count (v1.0) | Format |
|----------|-------------|--------|
| Hero 3D models | 12 | FBX, 5 k tris each |
| Enemy 3D models | 14 (6 Infected + 3 Human + 5 Bosses) | FBX, 3--8 k tris |
| Buildings | 15 types x 3 visual tiers | FBX modular kit |
| Tilesets | 8 district themes | 2D sprite atlas 2048x2048 |
| UI screens | ~25 unique layouts | Figma -> Unity prefab |
| VFX | ~40 unique effects | Unity Particle System / VFX Graph |
| Audio tracks | 12 music, ~200 SFX, ~300 VO lines | WAV (source), OGG (runtime) |
| Portraits | 12 hero + 20 NPC | 1024x1024 PNG |

### 19.2 Tools

- **Engine:** Unity 2025 LTS (URP)
- **Art:** Blender, Substance Painter, Photoshop
- **Audio:** FMOD for adaptive music
- **CI/CD:** Unity Cloud Build -> TestFlight
- **Analytics:** Unity Analytics + custom telemetry for economy tuning

### 19.3 Localisation

Day-one languages: English, Spanish, French, German, Japanese, Korean, Simplified Chinese. All text externalised to JSON string tables from day one.

---

## 20. Monetisation

| Item | Type | Price |
|------|------|-------|
| Base game | Premium | $6.99 |
| Cosmetic hero skins (6 at launch) | IAP | $1.99 each |
| Base theme packs (3 at launch) | IAP | $2.99 each |
| "Survivor's Kit" bundle (all cosmetics) | IAP | $14.99 |

**Rules:**
- No loot boxes.
- No gameplay-affecting purchases.
- No energy systems or timers that require payment to skip.
- Fuel tokens (rush currency) are earned in-game only.

---

## 21. Risk Register

| Risk | Impact | Likelihood | Mitigation |
|------|--------|-----------|-----------|
| Combat feels slow on mobile | High | Medium | Tactical pause + 2x speed toggle; aggressive auto-battle tuning |
| Economy too generous / too stingy | High | High | Telemetry-driven live tuning; anti-frustration safety nets |
| Scope creep on hero count | Medium | High | Lock roster at 12 for v1.0; plan 4 DLC heroes |
| Performance on older devices | High | Medium | LOD system; target iPhone 12+ as min spec; aggressive culling |

---

## 22. Milestones (High Level)

| Milestone | Target Date | Deliverable |
|-----------|------------|-------------|
| Vertical Slice | Month 4 | Playable suburb district, 5 heroes, full loop |
| Alpha | Month 8 | Acts 1--3 playable, all systems functional |
| Beta | Month 11 | Full content, polish pass begins |
| Gold | Month 14 | Ship candidate |
| Launch | Month 15 | App Store release |

---

*This is a living document. All section owners are responsible for keeping their areas current as design evolves. Cross-reference companion documents for implementation-level detail.*
