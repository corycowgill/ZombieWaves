// HeroRoster.swift
// ProjectAshfall
//
// Defines the 12 initial heroes available in the game, each with unique
// stats, skills, backstory, and bond partners.

import Foundation

// MARK: - Hero Roster

/// Factory that produces the canonical roster of starter heroes.
/// All heroes begin at level 1, rank 1. UUIDs are deterministic so
/// bond-partner cross-references remain stable across saves.
enum HeroRoster {

    // MARK: Deterministic IDs

    // Fixed UUIDs allow bond partner references to be wired at definition time.
    static let marcusColeID      = UUID(uuidString: "00000001-0001-0001-0001-000000000001")!
    static let elenaVasquezID    = UUID(uuidString: "00000001-0001-0001-0001-000000000002")!
    static let jimTanakaID       = UUID(uuidString: "00000001-0001-0001-0001-000000000003")!
    static let zaraOkaforID      = UUID(uuidString: "00000001-0001-0001-0001-000000000004")!
    static let lenaMorseID       = UUID(uuidString: "00000001-0001-0001-0001-000000000005")!
    static let victorHaleID      = UUID(uuidString: "00000001-0001-0001-0001-000000000006")!
    static let sashaPetrovID     = UUID(uuidString: "00000001-0001-0001-0001-000000000007")!
    static let mayaChenID        = UUID(uuidString: "00000001-0001-0001-0001-000000000008")!
    static let eliWattsID        = UUID(uuidString: "00000001-0001-0001-0001-000000000009")!
    static let priyaNairID       = UUID(uuidString: "00000001-0001-0001-0001-00000000000A")!
    static let tommyRourkeID     = UUID(uuidString: "00000001-0001-0001-0001-00000000000B")!
    static let nadiaKouriID      = UUID(uuidString: "00000001-0001-0001-0001-00000000000C")!

    // MARK: Full Roster

    /// Returns fresh copies of every hero in the initial roster.
    static func allHeroes() -> [Hero] {
        [
            marcusCole(),
            elenaVasquez(),
            ironsideJimTanaka(),
            zaraOkafor(),
            drLenaMorse(),
            victorDeadshotHale(),
            sashaPetrov(),
            mayaChen(),
            reverendEliWatts(),
            gadgetPriyaNair(),
            tommyRourke(),
            nadiaKouri()
        ]
    }

    // MARK: - Individual Hero Definitions

    /// Marcus Cole — Assault, ex-military squad leader.
    static func marcusCole() -> Hero {
        Hero(
            id: marcusColeID,
            name: "Marcus Cole",
            role: .assault,
            rarity: .elite,
            health: 320,
            attack: 85,
            defense: 55,
            speed: 60,
            critChance: 0.12,
            skills: [
                Skill(name: "Suppressive Fire",
                      description: "Lays down covering fire, damaging all enemies and reducing their accuracy.",
                      type: .active, targetType: .allEnemies, cooldown: 3,
                      damage: 45, effectType: .damage, unlockLevel: 1,
                      iconName: "skill_suppressive_fire"),
                Skill(name: "Rally Cry",
                      description: "Boosts attack and morale of all allies for 2 turns.",
                      type: .active, targetType: .allAllies, cooldown: 4,
                      duration: 2, effectType: .buff, unlockLevel: 5,
                      iconName: "skill_rally_cry"),
                Skill(name: "Veteran Instinct",
                      description: "Passively increases crit chance by 8%.",
                      type: .passive, targetType: .`self`, effectType: .buff,
                      unlockLevel: 10, iconName: "skill_veteran_instinct"),
                Skill(name: "Last Stand",
                      description: "Unleashes a devastating barrage when health drops below 30%.",
                      type: .ultimate, targetType: .allEnemies, cooldown: 6,
                      damage: 120, effectType: .damage, unlockLevel: 20,
                      iconName: "skill_last_stand")
            ],
            signatureWeapon: "Old Faithful (Custom M4A1)",
            passiveTraits: [
                PassiveTrait(name: "Born Leader",
                             description: "Squad members gain +5% attack when Marcus is present.",
                             statModifier: StatModifier(stat: .attack, percentBonus: 0.05))
            ],
            bondPartnerIDs: [elenaVasquezID, jimTanakaID],
            backstory: "Former Army sergeant who kept his unit alive through the first weeks of the outbreak. Haunted by the soldiers he lost, Marcus channels his guilt into protecting every survivor under his care.",
            isUnlocked: true,
            morale: 65,
            portraitName: "hero_marcus_cole"
        )
    }

    /// Elena Vasquez — Medic, combat surgeon.
    static func elenaVasquez() -> Hero {
        Hero(
            id: elenaVasquezID,
            name: "Elena Vasquez",
            role: .medic,
            rarity: .elite,
            health: 280,
            attack: 40,
            defense: 50,
            speed: 55,
            critChance: 0.06,
            skills: [
                Skill(name: "Field Surgery",
                      description: "Restores a large amount of health to a single ally.",
                      type: .active, targetType: .single, cooldown: 2,
                      healAmount: 90, effectType: .heal, unlockLevel: 1,
                      iconName: "skill_field_surgery"),
                Skill(name: "Triage Protocol",
                      description: "Heals all allies for a moderate amount over 3 turns.",
                      type: .active, targetType: .allAllies, cooldown: 5,
                      healAmount: 35, duration: 3, effectType: .healOverTime,
                      unlockLevel: 8, iconName: "skill_triage"),
                Skill(name: "Adrenaline Shot",
                      description: "Boosts a single ally's speed and attack for 2 turns.",
                      type: .active, targetType: .single, cooldown: 3,
                      duration: 2, effectType: .buff, unlockLevel: 12,
                      iconName: "skill_adrenaline"),
                Skill(name: "Miracle Save",
                      description: "Revives a downed ally with 40% health.",
                      type: .ultimate, targetType: .single, cooldown: 8,
                      healAmount: 160, effectType: .heal, unlockLevel: 25,
                      iconName: "skill_miracle_save")
            ],
            signatureWeapon: "Mercy (Modified Scalpel Pistol)",
            passiveTraits: [
                PassiveTrait(name: "Hippocratic Resolve",
                             description: "Healing effects increased by 10% when morale is above 50.",
                             statModifier: nil)
            ],
            bondPartnerIDs: [marcusColeID, eliWattsID],
            backstory: "A trauma surgeon stationed at a military field hospital when the outbreak began. Elena watched the wards overflow in hours. Now she treats wounds with whatever she can find, driven by a refusal to lose another patient.",
            isUnlocked: true,
            morale: 60,
            portraitName: "hero_elena_vasquez"
        )
    }

    /// "Ironside" Jim Tanaka — Heavy, riot police veteran.
    static func ironsideJimTanaka() -> Hero {
        Hero(
            id: jimTanakaID,
            name: "\"Ironside\" Jim Tanaka",
            role: .heavy,
            rarity: .rare,
            health: 450,
            attack: 55,
            defense: 80,
            speed: 35,
            critChance: 0.05,
            skills: [
                Skill(name: "Shield Wall",
                      description: "Raises a riot shield, absorbing damage for 2 turns.",
                      type: .active, targetType: .`self`, cooldown: 3,
                      duration: 2, effectType: .shield, unlockLevel: 1,
                      iconName: "skill_shield_wall"),
                Skill(name: "Battering Ram",
                      description: "Charges forward, dealing heavy damage and stunning the target.",
                      type: .active, targetType: .single, cooldown: 4,
                      damage: 70, duration: 1, effectType: .stun, unlockLevel: 6,
                      iconName: "skill_battering_ram"),
                Skill(name: "Hold the Line",
                      description: "Taunts all enemies, forcing them to attack Ironside for 2 turns.",
                      type: .active, targetType: .`self`, cooldown: 5,
                      duration: 2, effectType: .taunt, unlockLevel: 14,
                      iconName: "skill_hold_the_line"),
                Skill(name: "Unbreakable",
                      description: "Becomes immune to damage for 1 turn. Cooldown resets on kill.",
                      type: .ultimate, targetType: .`self`, cooldown: 7,
                      duration: 1, effectType: .shield, unlockLevel: 22,
                      iconName: "skill_unbreakable")
            ],
            signatureWeapon: "The Door (Reinforced Riot Shield)",
            passiveTraits: [
                PassiveTrait(name: "Ironclad",
                             description: "Takes 10% less damage from all sources.",
                             statModifier: StatModifier(stat: .defense, percentBonus: 0.10))
            ],
            bondPartnerIDs: [marcusColeID, tommyRourkeID],
            backstory: "A riot police officer who spent 20 years keeping the peace in the toughest precincts. When civilisation fell, Jim picked up his shield one last time — this time not for the government, but for the people standing behind him.",
            isUnlocked: true,
            morale: 55,
            portraitName: "hero_jim_tanaka"
        )
    }

    /// Zara Okafor — Recon, parkour scout.
    static func zaraOkafor() -> Hero {
        Hero(
            id: zaraOkaforID,
            name: "Zara Okafor",
            role: .recon,
            rarity: .rare,
            health: 220,
            attack: 60,
            defense: 35,
            speed: 90,
            critChance: 0.18,
            skills: [
                Skill(name: "Shadow Step",
                      description: "Enters stealth for 2 turns, increasing crit chance by 25%.",
                      type: .active, targetType: .`self`, cooldown: 3,
                      duration: 2, effectType: .stealth, unlockLevel: 1,
                      iconName: "skill_shadow_step"),
                Skill(name: "Mark Target",
                      description: "Marks an enemy, increasing all damage they take by 20% for 2 turns.",
                      type: .active, targetType: .single, cooldown: 3,
                      duration: 2, effectType: .debuff, unlockLevel: 7,
                      iconName: "skill_mark_target"),
                Skill(name: "Fleet Feet",
                      description: "Passively increases speed by 15%.",
                      type: .passive, targetType: .`self`, effectType: .buff,
                      unlockLevel: 11, iconName: "skill_fleet_feet"),
                Skill(name: "Death from Above",
                      description: "Leaps to a vantage point and strikes with massive critical damage.",
                      type: .ultimate, targetType: .single, cooldown: 6,
                      damage: 150, effectType: .damage, unlockLevel: 18,
                      iconName: "skill_death_from_above",
                      scalingFactor: 2.0)
            ],
            signatureWeapon: "Whisper (Silenced SMG)",
            passiveTraits: [
                PassiveTrait(name: "Rooftop Runner",
                             description: "Cannot be slowed. First attack each combat is a guaranteed crit.",
                             statModifier: StatModifier(stat: .speed, percentBonus: 0.05))
            ],
            bondPartnerIDs: [nadiaKouriID, mayaChenID],
            backstory: "A competitive free-runner and urban explorer before the outbreak. Zara navigates the ruins like a ghost, mapping safe routes and spotting threats long before anyone else.",
            isUnlocked: false,
            morale: 70,
            portraitName: "hero_zara_okafor",
            unlockChapter: "Act 1 - Chapter 3"
        )
    }

    /// Dr. Lena Morse — Engineer, robotics researcher.
    static func drLenaMorse() -> Hero {
        Hero(
            id: lenaMorseID,
            name: "Dr. Lena Morse",
            role: .engineer,
            rarity: .legendary,
            health: 260,
            attack: 50,
            defense: 55,
            speed: 45,
            critChance: 0.08,
            skills: [
                Skill(name: "Deploy Turret",
                      description: "Places an automated turret that attacks each turn for 3 turns.",
                      type: .active, targetType: .area, cooldown: 5,
                      damage: 30, duration: 3, effectType: .summon, unlockLevel: 1,
                      iconName: "skill_deploy_turret"),
                Skill(name: "Repair Drone",
                      description: "Sends a drone to heal a damaged ally or repair a building.",
                      type: .active, targetType: .single, cooldown: 3,
                      healAmount: 55, effectType: .heal, unlockLevel: 8,
                      iconName: "skill_repair_drone"),
                Skill(name: "Overcharge",
                      description: "Boosts all allied turrets and gadgets, doubling their output for 2 turns.",
                      type: .active, targetType: .allAllies, cooldown: 5,
                      duration: 2, effectType: .buff, unlockLevel: 15,
                      iconName: "skill_overcharge"),
                Skill(name: "Omega Protocol",
                      description: "Deploys a massive EMP blast that stuns all enemies and disables shields.",
                      type: .ultimate, targetType: .allEnemies, cooldown: 8,
                      damage: 60, duration: 2, effectType: .stun, unlockLevel: 28,
                      iconName: "skill_omega_protocol")
            ],
            signatureWeapon: "AURA Mk-III (Prototype Drone Swarm)",
            passiveTraits: [
                PassiveTrait(name: "Brilliant Mind",
                             description: "Building and upgrade times reduced by 15% when Lena is at base.",
                             statModifier: nil),
                PassiveTrait(name: "Mechanical Intuition",
                             description: "Deployed gadgets have +20% durability.",
                             statModifier: nil)
            ],
            bondPartnerIDs: [priyaNairID, sashaPetrovID],
            backstory: "A robotics PhD who was months from a breakthrough in autonomous search-and-rescue drones. The outbreak turned her lab into a fortress and her prototypes into weapons. Lena builds because building is the only thing keeping despair at bay.",
            isUnlocked: false,
            morale: 45,
            portraitName: "hero_lena_morse",
            unlockChapter: "Act 1 - Chapter 5"
        )
    }

    /// Victor "Deadshot" Hale — Sniper, hunting guide.
    static func victorDeadshotHale() -> Hero {
        Hero(
            id: victorHaleID,
            name: "Victor \"Deadshot\" Hale",
            role: .sniper,
            rarity: .elite,
            health: 210,
            attack: 100,
            defense: 30,
            speed: 50,
            critChance: 0.22,
            skills: [
                Skill(name: "Precision Shot",
                      description: "A carefully aimed shot that deals massive single-target damage.",
                      type: .active, targetType: .single, cooldown: 2,
                      damage: 95, effectType: .damage, unlockLevel: 1,
                      iconName: "skill_precision_shot",
                      scalingFactor: 1.5),
                Skill(name: "Spotter's Eye",
                      description: "Marks an enemy, making the next attack against them a guaranteed crit.",
                      type: .active, targetType: .single, cooldown: 3,
                      duration: 1, effectType: .debuff, unlockLevel: 6,
                      iconName: "skill_spotters_eye"),
                Skill(name: "Steady Hands",
                      description: "Passively increases crit multiplier by 50%.",
                      type: .passive, targetType: .`self`, effectType: .buff,
                      unlockLevel: 12, iconName: "skill_steady_hands"),
                Skill(name: "One Shot, One Kill",
                      description: "A single devastating round. Instantly kills targets below 15% health.",
                      type: .ultimate, targetType: .single, cooldown: 7,
                      damage: 200, effectType: .damage, unlockLevel: 24,
                      iconName: "skill_one_shot",
                      scalingFactor: 3.0)
            ],
            signatureWeapon: "Longwatch (.338 Lapua Custom Rifle)",
            passiveTraits: [
                PassiveTrait(name: "Patience of a Hunter",
                             description: "First attack each combat deals 30% bonus damage.",
                             statModifier: StatModifier(stat: .attack, percentBonus: 0.10))
            ],
            bondPartnerIDs: [zaraOkaforID, marcusColeID],
            backstory: "A wilderness hunting guide from Montana who could track a deer across bare rock. Victor treats the infected the same way he treated mountain lions — study them, stay downwind, and never miss.",
            isUnlocked: false,
            morale: 60,
            portraitName: "hero_victor_hale",
            unlockChapter: "Act 1 - Chapter 4"
        )
    }

    /// Sasha Petrov — Demolitions, combat engineer.
    static func sashaPetrov() -> Hero {
        Hero(
            id: sashaPetrovID,
            name: "Sasha Petrov",
            role: .demolitions,
            rarity: .rare,
            health: 290,
            attack: 80,
            defense: 45,
            speed: 42,
            critChance: 0.10,
            skills: [
                Skill(name: "Frag Out",
                      description: "Throws a fragmentation grenade dealing area damage.",
                      type: .active, targetType: .area, cooldown: 3,
                      damage: 65, effectType: .damage, unlockLevel: 1,
                      iconName: "skill_frag_out"),
                Skill(name: "Breaching Charge",
                      description: "Places an explosive that stuns and damages a single target.",
                      type: .active, targetType: .single, cooldown: 4,
                      damage: 80, duration: 1, effectType: .stun, unlockLevel: 7,
                      iconName: "skill_breaching_charge"),
                Skill(name: "Demolition Expert",
                      description: "Passively increases all explosive damage by 20%.",
                      type: .passive, targetType: .`self`, effectType: .buff,
                      unlockLevel: 13, iconName: "skill_demo_expert"),
                Skill(name: "Scorched Earth",
                      description: "Carpet-bombs the battlefield, dealing massive damage to all enemies over 2 turns.",
                      type: .ultimate, targetType: .allEnemies, cooldown: 8,
                      damage: 90, duration: 2, effectType: .burn, unlockLevel: 22,
                      iconName: "skill_scorched_earth",
                      statusEffects: ["burn"])
            ],
            signatureWeapon: "Big Bertha (Modified RPG-7)",
            passiveTraits: [
                PassiveTrait(name: "Blast Radius",
                             description: "Area attacks hit one additional target.",
                             statModifier: nil)
            ],
            bondPartnerIDs: [lenaMorseID, tommyRourkeID],
            backstory: "A military combat engineer who could clear a minefield before breakfast and rig a bridge to blow before lunch. Sasha speaks softly, builds carefully, and destroys thoroughly.",
            isUnlocked: false,
            morale: 55,
            portraitName: "hero_sasha_petrov",
            unlockChapter: "Act 2 - Chapter 1"
        )
    }

    /// Maya Chen — Assault, martial arts instructor.
    static func mayaChen() -> Hero {
        Hero(
            id: mayaChenID,
            name: "Maya Chen",
            role: .assault,
            rarity: .rare,
            health: 300,
            attack: 75,
            defense: 50,
            speed: 70,
            critChance: 0.15,
            skills: [
                Skill(name: "Rapid Strikes",
                      description: "Attacks a single target three times in quick succession.",
                      type: .active, targetType: .single, cooldown: 2,
                      damage: 30, effectType: .damage, unlockLevel: 1,
                      iconName: "skill_rapid_strikes",
                      scalingFactor: 3.0),
                Skill(name: "Counter Stance",
                      description: "Enters a defensive stance. Automatically counters the next melee attack.",
                      type: .active, targetType: .`self`, cooldown: 3,
                      duration: 1, effectType: .shield, unlockLevel: 6,
                      iconName: "skill_counter_stance"),
                Skill(name: "Iron Will",
                      description: "Passively increases defense and morale recovery.",
                      type: .passive, targetType: .`self`, effectType: .buff,
                      unlockLevel: 10, iconName: "skill_iron_will"),
                Skill(name: "Dragon's Fury",
                      description: "Unleashes a devastating combo dealing massive damage to all nearby enemies.",
                      type: .ultimate, targetType: .area, cooldown: 6,
                      damage: 130, effectType: .damage, unlockLevel: 20,
                      iconName: "skill_dragons_fury")
            ],
            signatureWeapon: "Twin Fangs (Reinforced Combat Tonfas)",
            passiveTraits: [
                PassiveTrait(name: "Martial Discipline",
                             description: "Gains +5% attack for each consecutive turn without taking damage.",
                             statModifier: StatModifier(stat: .attack, percentBonus: 0.05))
            ],
            bondPartnerIDs: [zaraOkaforID, elenaVasquezID],
            backstory: "A martial arts champion and self-defence instructor who ran a women's shelter before the world ended. Maya fights not because she likes violence, but because the people she protects cannot fight for themselves.",
            isUnlocked: false,
            morale: 70,
            portraitName: "hero_maya_chen",
            unlockChapter: "Act 1 - Chapter 6"
        )
    }

    /// Reverend Eli Watts — Medic, field chaplain and first aid specialist.
    static func reverendEliWatts() -> Hero {
        Hero(
            id: eliWattsID,
            name: "Reverend Eli Watts",
            role: .medic,
            rarity: .common,
            health: 270,
            attack: 35,
            defense: 45,
            speed: 48,
            critChance: 0.04,
            skills: [
                Skill(name: "Mend Wounds",
                      description: "Applies first aid to a single ally, restoring moderate health.",
                      type: .active, targetType: .single, cooldown: 2,
                      healAmount: 65, effectType: .heal, unlockLevel: 1,
                      iconName: "skill_mend_wounds"),
                Skill(name: "Calming Presence",
                      description: "Restores morale to all allies and cleanses debuffs.",
                      type: .active, targetType: .allAllies, cooldown: 4,
                      effectType: .cleanse, unlockLevel: 5,
                      iconName: "skill_calming_presence"),
                Skill(name: "Fortitude",
                      description: "Passively increases all allies' max health by 5% when Eli is present.",
                      type: .passive, targetType: .allAllies, effectType: .buff,
                      unlockLevel: 9, iconName: "skill_fortitude"),
                Skill(name: "Shepherd's Grace",
                      description: "Massively heals all allies and grants a shield for 1 turn.",
                      type: .ultimate, targetType: .allAllies, cooldown: 8,
                      healAmount: 100, duration: 1, effectType: .heal, unlockLevel: 20,
                      iconName: "skill_shepherds_grace")
            ],
            signatureWeapon: "The Good Book (Reinforced Bible with hidden blade)",
            passiveTraits: [
                PassiveTrait(name: "Unwavering Faith",
                             description: "Morale cannot drop below 25 while Eli is alive.",
                             statModifier: StatModifier(stat: .morale, flatBonus: 10))
            ],
            bondPartnerIDs: [elenaVasquezID, nadiaKouriID],
            backstory: "A small-town pastor who doubled as the county's only certified first-aid instructor. Eli lost his congregation but not his calling. He keeps spirits high and bleeding stopped — in that order.",
            isUnlocked: true,
            morale: 75,
            portraitName: "hero_eli_watts"
        )
    }

    /// "Gadget" Priya Nair — Engineer, IT specialist.
    static func gadgetPriyaNair() -> Hero {
        Hero(
            id: priyaNairID,
            name: "\"Gadget\" Priya Nair",
            role: .engineer,
            rarity: .rare,
            health: 240,
            attack: 45,
            defense: 50,
            speed: 52,
            critChance: 0.07,
            skills: [
                Skill(name: "Hack Signal",
                      description: "Jams enemy communications, reducing their speed for 2 turns.",
                      type: .active, targetType: .allEnemies, cooldown: 4,
                      duration: 2, effectType: .slow, unlockLevel: 1,
                      iconName: "skill_hack_signal"),
                Skill(name: "Jury-Rig",
                      description: "Improvises a quick repair, healing a structure or ally.",
                      type: .active, targetType: .single, cooldown: 3,
                      healAmount: 45, effectType: .heal, unlockLevel: 5,
                      iconName: "skill_jury_rig"),
                Skill(name: "Tech Salvage",
                      description: "Passively increases resource yield from missions by 10%.",
                      type: .passive, targetType: .`self`, effectType: .buff,
                      unlockLevel: 10, iconName: "skill_tech_salvage"),
                Skill(name: "System Override",
                      description: "Takes control of enemy tech, turning turrets and drones against their owners.",
                      type: .ultimate, targetType: .area, cooldown: 7,
                      damage: 50, duration: 3, effectType: .debuff, unlockLevel: 22,
                      iconName: "skill_system_override")
            ],
            signatureWeapon: "Neural Spike (Custom Hacking Tablet + Taser)",
            passiveTraits: [
                PassiveTrait(name: "Quick Learner",
                             description: "Gains 15% bonus experience from all sources.",
                             statModifier: nil)
            ],
            bondPartnerIDs: [lenaMorseID, nadiaKouriID],
            backstory: "A network security engineer who spent her career breaking into systems legally. Now she breaks into buildings, hotwires generators, and keeps the camp's cobbled-together electronics running with duct tape and determination.",
            isUnlocked: false,
            morale: 60,
            portraitName: "hero_priya_nair",
            unlockChapter: "Act 1 - Chapter 7"
        )
    }

    /// Tommy Rourke — Heavy, construction foreman.
    static func tommyRourke() -> Hero {
        Hero(
            id: tommyRourkeID,
            name: "Tommy Rourke",
            role: .heavy,
            rarity: .common,
            health: 420,
            attack: 50,
            defense: 70,
            speed: 30,
            critChance: 0.04,
            skills: [
                Skill(name: "Sledgehammer",
                      description: "Smashes a target with a massive blow, dealing heavy damage.",
                      type: .active, targetType: .single, cooldown: 3,
                      damage: 75, effectType: .damage, unlockLevel: 1,
                      iconName: "skill_sledgehammer"),
                Skill(name: "Hard Hat",
                      description: "Braces for impact, reducing incoming damage by 40% for 1 turn.",
                      type: .active, targetType: .`self`, cooldown: 4,
                      duration: 1, effectType: .shield, unlockLevel: 5,
                      iconName: "skill_hard_hat"),
                Skill(name: "Foreman's Grit",
                      description: "Passively regenerates a small amount of health each turn.",
                      type: .passive, targetType: .`self`, effectType: .healOverTime,
                      unlockLevel: 10, iconName: "skill_foremans_grit"),
                Skill(name: "Wrecking Ball",
                      description: "Swings in a devastating arc hitting all nearby enemies.",
                      type: .ultimate, targetType: .area, cooldown: 7,
                      damage: 100, effectType: .damage, unlockLevel: 20,
                      iconName: "skill_wrecking_ball",
                      statusEffects: ["stagger"])
            ],
            signatureWeapon: "Old Reliable (20-lb Sledgehammer)",
            passiveTraits: [
                PassiveTrait(name: "Built Different",
                             description: "Max health increased by 8%.",
                             statModifier: StatModifier(stat: .health, percentBonus: 0.08))
            ],
            bondPartnerIDs: [jimTanakaID, sashaPetrovID],
            backstory: "A construction foreman who built skyscrapers for three decades. Tommy can't shoot straight to save his life, but give him something heavy to swing and a wall to build and there's nobody better.",
            isUnlocked: true,
            morale: 50,
            portraitName: "hero_tommy_rourke"
        )
    }

    /// Nadia Kouri — Recon, journalist and investigator.
    static func nadiaKouri() -> Hero {
        Hero(
            id: nadiaKouriID,
            name: "Nadia Kouri",
            role: .recon,
            rarity: .common,
            health: 230,
            attack: 55,
            defense: 38,
            speed: 78,
            critChance: 0.14,
            skills: [
                Skill(name: "Investigate",
                      description: "Reveals enemy weaknesses, increasing damage they take by 15% for 2 turns.",
                      type: .active, targetType: .single, cooldown: 3,
                      duration: 2, effectType: .debuff, unlockLevel: 1,
                      iconName: "skill_investigate"),
                Skill(name: "Low Profile",
                      description: "Enters stealth for 1 turn, avoiding all attacks.",
                      type: .active, targetType: .`self`, cooldown: 4,
                      duration: 1, effectType: .stealth, unlockLevel: 6,
                      iconName: "skill_low_profile"),
                Skill(name: "Street Smarts",
                      description: "Passively increases evasion and loot discovery chance.",
                      type: .passive, targetType: .`self`, effectType: .buff,
                      unlockLevel: 10, iconName: "skill_street_smarts"),
                Skill(name: "Exposé",
                      description: "Reveals all enemies on the map and strips their buffs.",
                      type: .ultimate, targetType: .allEnemies, cooldown: 6,
                      effectType: .debuff, unlockLevel: 18,
                      iconName: "skill_expose")
            ],
            signatureWeapon: "The Pen (Suppressed Compact Pistol)",
            passiveTraits: [
                PassiveTrait(name: "Investigative Instinct",
                             description: "Side encounters reveal additional intel and loot.",
                             statModifier: StatModifier(stat: .speed, percentBonus: 0.05))
            ],
            bondPartnerIDs: [zaraOkaforID, eliWattsID],
            backstory: "An investigative journalist who was chasing a story about illegal bioweapons research when the outbreak hit. Nadia suspects the infection was no accident — and she intends to prove it.",
            isUnlocked: false,
            morale: 65,
            portraitName: "hero_nadia_kouri",
            unlockChapter: "Act 1 - Chapter 2"
        )
    }
}
