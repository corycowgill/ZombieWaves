# Project Ashfall -- Gameplay Loop Diagrams

**Version:** 1.0  
**Date:** 2026-04-07

---

## 1. Outer Loop (Campaign Progression)

The macro loop governs the player's long-term arc across the full campaign (~40 hours).

```
+=====================================================================+
|                        CAMPAIGN MAP                                  |
|                                                                      |
|   +------------+    +------------+    +------------+                 |
|   | District 1 |--->| District 2 |--->| District 3 |---> ...        |
|   | Maplewood  |    | Riverside  |    | Old Town   |                |
|   +-----+------+    +-----+------+    +-----+------+                |
|         |                  |                  |                       |
|         v                  v                  v                       |
|   +-----------+      +-----------+      +-----------+                |
|   | Establish |      | Establish |      | Establish |                |
|   |   Base    |      |   Base    |      |   Base    |                |
|   +-----+-----+     +-----+-----+     +-----+-----+                |
|         |                  |                  |                       |
|         v                  v                  v                       |
|   +-----------+      +-----------+      +-----------+                |
|   | Complete  |      | Complete  |      | Complete  |                |
|   | Chapters  |      | Chapters  |      | Chapters  |                |
|   +-----+-----+     +-----+-----+     +-----+-----+                |
|         |                  |                  |                       |
|         v                  v                  v                       |
|   +-----------+      +-----------+      +-----------+                |
|   |  Unlock   |      |  Unlock   |      |  Unlock   |                |
|   |  Next     |----->|  Next     |----->|  Next     |---> ...        |
|   | District  |      | District  |      | District  |                |
|   +-----------+      +-----------+      +-----------+                |
+=====================================================================+
```

---

## 2. Inner Loop (Session Gameplay)

The micro loop governs a single play session (5--30 minutes).

```
                    +------------------+
                    |   START SESSION  |
                    +--------+---------+
                             |
                             v
                  +----------+----------+
                  |  COLLECT RESOURCES  |
                  |  (Supply Depot,     |
                  |   Purifier, etc.)   |
                  +----------+----------+
                             |
                             v
                +------------+-------------+
                |  BUILD / UPGRADE BASE    |
                |  (Spend Supplies, Scrap, |
                |   Water, Fuel, Intel)    |
                +------------+-------------+
                             |
                             v
                +------------+-------------+
                |  EQUIP & LEVEL HEROES    |
                |  (Gear, Skills, Trust)   |
                +------------+-------------+
                             |
                             v
                +------------+-------------+
                |    SELECT MISSION        |
                |  Campaign / Expedition / |
                |  Defense / Recovery      |
                +------------+-------------+
                             |
                             v
                +------------+-------------+
                |     DEPLOY SQUAD         |
                |  (Pick 4 heroes, set     |
                |   formation & loadout)   |
                +------------+-------------+
                             |
                             v
                +------------+-------------+
                |      COMBAT              |
                |  (Real-time w/ tactical  |
                |   pause, 3-8 min)        |
                +------------+-------------+
                             |
                     +-------+-------+
                     |               |
                     v               v
              +------+------+  +-----+-------+
              |   VICTORY   |  |   DEFEAT    |
              +------+------+  +-----+-------+
                     |               |
                     v               v
              +------+------+  +-----+-------+
              | EARN REWARDS|  | LOSE STAMINA|
              | XP, Loot,   |  | Keep 50% XP |
              | Resources   |  | Retry Free  |
              +------+------+  +-----+-------+
                     |               |
                     +-------+-------+
                             |
                             v
                  +----------+----------+
                  |   RETURN TO BASE    |
                  +----------+----------+
                             |
                             v
                  +----------+----------+
                  |   END SESSION or    |
                  |   LOOP AGAIN        |
                  +---------------------+
```

---

## 3. Resource Flow Diagram

How the five resources move through the game's systems.

```
  SOURCES                    RESOURCES                   SINKS
  =======                    =========                   =====

  Supply Depot --------+
  Mission Rewards --+  |
                    |  +---> [ SUPPLIES ] ---+---> Building Construction
                    |                        +---> Hero Gear Crafting
                    |                        +---> Repair Costs
                    |
  Water Purifier ---+
  Mission Rewards --+---> [ WATER ] --------+---> Medical Items
                    |                        +---> Farm Input
                    |                        +---> Hero Healing
                    |
  Fuel Refinery ----+
  Mission Rewards --+---> [ FUEL ] ---------+---> Expedition Launch Cost
                    |                        +---> Rush Timers
                    |                        +---> Vehicle Upgrades
                    |
  Workshop ---------+
  Salvage Drops ----+---> [ SCRAP ] --------+---> Weapon Crafting
                    |                        +---> Armour Crafting
                    |                        +---> Building Upgrades (Lv 7+)
                    |
  Comms Tower ------+
  Story Missions ---+---> [ INTEL ] --------+---> Tech Research
                                             +---> World Map Recon
                                             +---> Unlock Hidden Missions
```

---

## 4. Hero Progression Loop

```
  +-------------------+
  |  DEPLOY ON        |
  |  MISSIONS         |
  +---------+---------+
            |
            |  earns
            v
  +---------+---------+     +-----------------+
  |  XP               |---->| LEVEL UP        |
  |  (combat & quest) |     | +Stats          |
  +-------------------+     | +Skill Points   |
                            +--------+--------+
                                     |
            +------------------------+------------------------+
            |                        |                        |
            v                        v                        v
  +---------+---------+   +----------+---------+   +----------+--------+
  |  UNLOCK SKILLS    |   |  EQUIP BETTER GEAR |   |  PROMOTE (Lv 20, |
  |  (Active/Passive) |   |  (Craft or Loot)   |   |   40, 60)         |
  +---------+---------+   +----------+---------+   +----------+--------+
            |                        |                        |
            +------------------------+------------------------+
                                     |
                                     v
                          +----------+---------+
                          |  INCREASED POWER   |
                          |  RATING            |
                          +----------+---------+
                                     |
                                     v
                          +----------+---------+
                          |  TACKLE HARDER     |
                          |  CONTENT           |
                          +--------------------+
```

---

## 5. Trust / Bond System

```
  HERO A  +------- Co-deploy on missions -------+  HERO B
          |                                      |
          v                                      v
     +----+----+                            +----+----+
     | Bond XP |                            | Bond XP |
     +----+----+                            +----+----+
          |                                      |
          +----> Shared Bond Level <-------------+
                      |
         +------------+------------+-----------+
         |            |            |           |
         v            v            v           v
     Trust Lv 1   Trust Lv 2   Trust Lv 3  Trust Lv 5
     +5% DMG      +10% DMG     Unlock      Ultimate
     when paired  when paired  Side Quest  Bond Skill
```

---

## 6. Full Systems Interconnect

```
+------------------------------------------------------------------+
|                        PLAYER SESSION                             |
|                                                                   |
|  +----------+     +-----------+     +-----------+                 |
|  |  WORLD   |<--->|   BASE    |<--->|  HEROES   |                 |
|  |   MAP    |     | BUILDING  |     | & SQUADS  |                 |
|  +----+-----+     +-----+-----+     +-----+-----+                |
|       |                  |                  |                      |
|       | selects          | produces         | deploys              |
|       | district         | resources        | squad                |
|       v                  v                  v                      |
|  +----+-----+     +-----+-----+     +-----+-----+                |
|  | MISSIONS |<----| RESOURCES |---->| COMBAT    |                 |
|  | (4 modes)|     | (5 types) |     | SYSTEM    |                 |
|  +----+-----+     +-----+-----+     +-----+-----+                |
|       |                  ^                  |                      |
|       |                  |                  |                      |
|       | story outcomes   | rewards loop     | XP & loot           |
|       v                  |                  v                      |
|  +----+-----+            |           +-----+-----+                |
|  |NARRATIVE |            +-----------| REWARDS   |                |
|  |DECISIONS |                        | & LOOT    |                |
|  +----+-----+                        +-----------+                |
|       |                                                           |
|       v                                                           |
|  +----+-----+                                                     |
|  | WORLD    |                                                     |
|  | STATE    |  (affects available missions, NPCs, endings)        |
|  +----------+                                                     |
+------------------------------------------------------------------+
```

---

## 7. Mode Selection Flow

```
                    +------------------+
                    |    MAIN MENU     |
                    +--------+---------+
                             |
              +--------------+--------------+
              |              |              |
              v              v              v
        +-----+----+  +-----+----+  +------+-----+
        | CONTINUE |  | NEW GAME |  | SETTINGS   |
        +-----+----+  +-----+----+  +------------+
              |              |
              +------+-------+
                     |
                     v
              +------+-------+
              |   BASE VIEW  |  <-- Central hub
              +------+-------+
                     |
       +------+------+------+------+
       |      |      |      |      |
       v      v      v      v      v
   +---+--+ +-+--+ +-+--+ +-+--+ +-+------+
   |CAMPGN| |EXPED| | DEF| |RECV| | HEROES |
   +------+ +-----+ +----+ +----+ +--------+
```

---

## 8. Economy Feedback Loop

```
       SCARCITY                          ABUNDANCE
    (early game)                        (late game)
         |                                   |
         v                                   v
  Few buildings -----> Limited resources     Many buildings --> Surplus
         |                   |                    |                |
         v                   v                    v                v
  Must prioritise       Can only do          Can invest in     Tackle top-
  survival buildings    easy missions        research & gear   tier content
         |                   |                    |                |
         v                   v                    v                v
  Tension & stakes      Desire for more      Satisfaction &    New challenges
  (engaging)            (motivating)         agency (fun)      (sustaining)
         |                   |                    |                |
         +------- PROGRESSION OVER TIME ---------+                |
                                                                  |
         +<----------- NEW ACT RESETS SCARCITY -------------------+
         |            (new district, new base, new threats)
         v
  Cycle repeats with higher stakes
```

---

*All diagrams in this document represent design intent. Implementation details may vary. Refer to CombatPrototypeSpec.md and EconomyModel.md for numerical specifics.*
