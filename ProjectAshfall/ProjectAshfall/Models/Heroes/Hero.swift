// Hero.swift
// ProjectAshfall
//
// The playable hero unit — a named survivor with stats, skills, and gear.

import Foundation

// MARK: - Hero Classification

/// Tactical role a hero fills on the squad.
enum HeroRole: String, Codable, CaseIterable {
    case assault
    case heavy
    case recon
    case medic
    case engineer
    case sniper
    case demolitions

    /// Short description shown in the hero detail screen.
    var roleDescription: String {
        switch self {
        case .assault:      return "Front-line fighter with balanced offense"
        case .heavy:        return "High-durability tank that absorbs punishment"
        case .recon:        return "Fast scout with high evasion and crit"
        case .medic:        return "Healer and support specialist"
        case .engineer:     return "Builder and gadget specialist"
        case .sniper:       return "Long-range precision damage dealer"
        case .demolitions:  return "Area-of-effect damage specialist"
        }
    }
}

/// Rarity tier that gates base-stat budgets and skill counts.
enum HeroRarity: String, Codable, CaseIterable, Comparable {
    case common
    case rare
    case elite
    case legendary

    private var sortOrder: Int {
        switch self {
        case .common:    return 0
        case .rare:      return 1
        case .elite:     return 2
        case .legendary: return 3
        }
    }

    static func < (lhs: HeroRarity, rhs: HeroRarity) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }

    /// Stat multiplier applied to base stat budgets.
    var statMultiplier: Double {
        switch self {
        case .common:    return 1.0
        case .rare:      return 1.15
        case .elite:     return 1.35
        case .legendary: return 1.6
        }
    }

    /// Maximum number of skill slots available at this rarity.
    var maxSkillSlots: Int {
        switch self {
        case .common:    return 3
        case .rare:      return 4
        case .elite:     return 5
        case .legendary: return 6
        }
    }
}

// MARK: - Gear Slot

/// Named equipment slot on a hero.
enum GearSlot: String, Codable, CaseIterable {
    case weapon
    case armor
    case accessory
    case mod
}

/// A piece of equipment that occupies a gear slot and provides stat bonuses.
struct GearItem: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let slot: GearSlot
    let healthBonus: Double
    let attackBonus: Double
    let defenseBonus: Double
    let speedBonus: Double
    let critChanceBonus: Double
    let rarity: HeroRarity
    let iconName: String

    init(
        id: UUID = UUID(),
        name: String,
        slot: GearSlot,
        healthBonus: Double = 0,
        attackBonus: Double = 0,
        defenseBonus: Double = 0,
        speedBonus: Double = 0,
        critChanceBonus: Double = 0,
        rarity: HeroRarity = .common,
        iconName: String = "gear_default"
    ) {
        self.id = id
        self.name = name
        self.slot = slot
        self.healthBonus = healthBonus
        self.attackBonus = attackBonus
        self.defenseBonus = defenseBonus
        self.speedBonus = speedBonus
        self.critChanceBonus = critChanceBonus
        self.rarity = rarity
        self.iconName = iconName
    }
}

// MARK: - Passive Trait

/// An innate trait that grants a persistent bonus or special behaviour.
struct PassiveTrait: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let description: String
    let statModifier: StatModifier?

    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        statModifier: StatModifier? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.statModifier = statModifier
    }
}

/// Flat or percentage modifier to a specific stat.
struct StatModifier: Codable, Hashable {
    let stat: ModifiableStat
    let flatBonus: Double
    let percentBonus: Double

    init(stat: ModifiableStat, flatBonus: Double = 0, percentBonus: Double = 0) {
        self.stat = stat
        self.flatBonus = flatBonus
        self.percentBonus = percentBonus
    }
}

/// Stats that can be targeted by modifiers.
enum ModifiableStat: String, Codable, CaseIterable {
    case health, attack, defense, speed, critChance, morale
}

// MARK: - Hero

/// A single named survivor that the player can recruit, level, equip, and deploy.
final class Hero: Codable, Identifiable, ObservableObject {

    // MARK: Identity

    let id: UUID
    var name: String
    var role: HeroRole
    var rarity: HeroRarity
    var portraitName: String
    var backstory: String

    // MARK: Progression

    /// Current level, clamped to 1...60.
    var level: Int {
        didSet { level = min(max(level, 1), 60) }
    }

    /// Star rank representing ascension tier, clamped to 1...5.
    var rank: Int {
        didSet { rank = min(max(rank, 1), 5) }
    }

    var experience: Double

    // MARK: Base Stats

    var health: Double
    var attack: Double
    var defense: Double
    var speed: Double

    /// Critical hit chance (0.0 to 1.0).
    var critChance: Double

    /// Morale affects combat performance (0 to 100).
    var morale: Double {
        didSet { morale = min(max(morale, 0), 100) }
    }

    // MARK: Abilities & Equipment

    var skills: [Skill]

    /// Gear currently equipped, keyed by slot.
    var equippedGear: [GearSlot: GearItem]

    /// The hero's unique signature weapon name (unlocked at rank 3).
    var signatureWeapon: String?

    /// Innate traits that provide passive bonuses.
    var passiveTraits: [PassiveTrait]

    /// IDs of heroes this hero has bonds with.
    var bondPartnerIDs: [UUID]

    // MARK: State

    var isUnlocked: Bool

    /// Chapter/act that unlocks this hero in the campaign. Nil = available from start.
    var unlockChapter: String?

    // MARK: - Computed Properties

    /// Total health including gear and bond bonuses.
    var effectiveHealth: Double {
        let gearBonus = equippedGear.values.reduce(0.0) { $0 + $1.healthBonus }
        let traitBonus = traitModifier(for: .health)
        return (health + gearBonus) * (1.0 + traitBonus)
    }

    /// Total attack including gear and bond bonuses.
    var effectiveAttack: Double {
        let gearBonus = equippedGear.values.reduce(0.0) { $0 + $1.attackBonus }
        let traitBonus = traitModifier(for: .attack)
        return (attack + gearBonus) * (1.0 + traitBonus)
    }

    /// Total defense including gear and bond bonuses.
    var effectiveDefense: Double {
        let gearBonus = equippedGear.values.reduce(0.0) { $0 + $1.defenseBonus }
        let traitBonus = traitModifier(for: .defense)
        return (defense + gearBonus) * (1.0 + traitBonus)
    }

    /// Total speed including gear and bond bonuses.
    var effectiveSpeed: Double {
        let gearBonus = equippedGear.values.reduce(0.0) { $0 + $1.speedBonus }
        let traitBonus = traitModifier(for: .speed)
        return (speed + gearBonus) * (1.0 + traitBonus)
    }

    /// Total crit chance including gear bonuses, clamped to 0...1.
    var effectiveCritChance: Double {
        let gearBonus = equippedGear.values.reduce(0.0) { $0 + $1.critChanceBonus }
        return min(1.0, critChance + gearBonus)
    }

    /// Combined power rating for squad strength calculations.
    var powerRating: Double {
        effectiveHealth * 0.3 + effectiveAttack * 0.25 +
        effectiveDefense * 0.2 + effectiveSpeed * 0.15 +
        effectiveCritChance * 50.0 + Double(level) * 2.0
    }

    /// Experience required to reach the next level.
    var experienceToNextLevel: Double {
        100.0 * pow(1.18, Double(level))
    }

    /// Skills available at the current level.
    var unlockedSkills: [Skill] {
        skills.filter { $0.unlockLevel <= level }
    }

    var isAlive: Bool { health > 0 }

    // MARK: - Initializer

    init(
        id: UUID = UUID(),
        name: String,
        role: HeroRole,
        rarity: HeroRarity,
        level: Int = 1,
        rank: Int = 1,
        experience: Double = 0,
        health: Double,
        attack: Double,
        defense: Double,
        speed: Double,
        critChance: Double = 0.05,
        skills: [Skill] = [],
        equippedGear: [GearSlot: GearItem] = [:],
        signatureWeapon: String? = nil,
        passiveTraits: [PassiveTrait] = [],
        bondPartnerIDs: [UUID] = [],
        backstory: String = "",
        isUnlocked: Bool = false,
        morale: Double = 50,
        portraitName: String = "hero_default",
        unlockChapter: String? = nil
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.rarity = rarity
        self.level = min(max(level, 1), 60)
        self.rank = min(max(rank, 1), 5)
        self.experience = experience
        self.health = health
        self.attack = attack
        self.defense = defense
        self.speed = speed
        self.critChance = critChance
        self.skills = skills
        self.equippedGear = equippedGear
        self.signatureWeapon = signatureWeapon
        self.passiveTraits = passiveTraits
        self.bondPartnerIDs = bondPartnerIDs
        self.backstory = backstory
        self.isUnlocked = isUnlocked
        self.morale = min(max(morale, 0), 100)
        self.portraitName = portraitName
        self.unlockChapter = unlockChapter
    }

    // MARK: - Methods

    /// Adds experience and triggers level-ups as needed. Returns the number of levels gained.
    @discardableResult
    func addExperience(_ amount: Double) -> Int {
        guard amount > 0 else { return 0 }
        experience += amount
        var levelsGained = 0
        while level < 60 && experience >= experienceToNextLevel {
            experience -= experienceToNextLevel
            levelUp()
            levelsGained += 1
        }
        return levelsGained
    }

    /// Advances the hero by one level, applying stat growth based on role and rarity.
    func levelUp() {
        guard level < 60 else { return }
        level += 1

        let growth = statGrowthPerLevel()
        health  += growth.health
        attack  += growth.attack
        defense += growth.defense
        speed   += growth.speed
    }

    /// Equips a gear item in its designated slot.
    /// Returns the previously equipped item if any.
    @discardableResult
    func equip(_ item: GearItem) -> GearItem? {
        let previous = equippedGear[item.slot]
        equippedGear[item.slot] = item
        return previous
    }

    /// Removes and returns the gear in the specified slot.
    @discardableResult
    func unequip(_ slot: GearSlot) -> GearItem? {
        let item = equippedGear[slot]
        equippedGear[slot] = nil
        return item
    }

    /// Adjusts morale by the given delta, clamped to 0...100.
    func adjustMorale(by delta: Double) {
        morale = min(100, max(0, morale + delta))
    }

    // MARK: - Helpers

    /// Aggregate percentage bonus from passive traits for a given stat.
    private func traitModifier(for stat: ModifiableStat) -> Double {
        passiveTraits.compactMap { $0.statModifier }
            .filter { $0.stat == stat }
            .reduce(0.0) { $0 + $1.percentBonus }
    }

    /// Per-level stat growth tuned by role.
    private func statGrowthPerLevel() -> (health: Double, attack: Double, defense: Double, speed: Double) {
        let m = rarity.statMultiplier
        switch role {
        case .assault:      return (12 * m,  4.0 * m, 2.5 * m, 1.5 * m)
        case .heavy:        return (18 * m,  2.5 * m, 4.0 * m, 0.8 * m)
        case .recon:        return (8  * m,  3.0 * m, 1.5 * m, 3.0 * m)
        case .medic:        return (10 * m,  2.0 * m, 2.0 * m, 2.0 * m)
        case .engineer:     return (10 * m,  2.5 * m, 3.0 * m, 1.5 * m)
        case .sniper:       return (8  * m,  5.0 * m, 1.5 * m, 1.5 * m)
        case .demolitions:  return (10 * m,  4.5 * m, 2.0 * m, 1.2 * m)
        }
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, name, role, rarity, portraitName, backstory
        case level, rank, experience
        case health, attack, defense, speed, critChance, morale
        case skills, equippedGear, signatureWeapon, passiveTraits, bondPartnerIDs
        case isUnlocked, unlockChapter
    }

    convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decode(UUID.self, forKey: .id),
            name: try c.decode(String.self, forKey: .name),
            role: try c.decode(HeroRole.self, forKey: .role),
            rarity: try c.decode(HeroRarity.self, forKey: .rarity),
            level: try c.decode(Int.self, forKey: .level),
            rank: try c.decode(Int.self, forKey: .rank),
            experience: try c.decode(Double.self, forKey: .experience),
            health: try c.decode(Double.self, forKey: .health),
            attack: try c.decode(Double.self, forKey: .attack),
            defense: try c.decode(Double.self, forKey: .defense),
            speed: try c.decode(Double.self, forKey: .speed),
            critChance: try c.decode(Double.self, forKey: .critChance),
            skills: try c.decode([Skill].self, forKey: .skills),
            equippedGear: try c.decode([GearSlot: GearItem].self, forKey: .equippedGear),
            signatureWeapon: try c.decodeIfPresent(String.self, forKey: .signatureWeapon),
            passiveTraits: try c.decode([PassiveTrait].self, forKey: .passiveTraits),
            bondPartnerIDs: try c.decode([UUID].self, forKey: .bondPartnerIDs),
            backstory: try c.decode(String.self, forKey: .backstory),
            isUnlocked: try c.decode(Bool.self, forKey: .isUnlocked),
            morale: try c.decode(Double.self, forKey: .morale),
            portraitName: try c.decode(String.self, forKey: .portraitName),
            unlockChapter: try c.decodeIfPresent(String.self, forKey: .unlockChapter)
        )
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(role, forKey: .role)
        try c.encode(rarity, forKey: .rarity)
        try c.encode(portraitName, forKey: .portraitName)
        try c.encode(backstory, forKey: .backstory)
        try c.encode(level, forKey: .level)
        try c.encode(rank, forKey: .rank)
        try c.encode(experience, forKey: .experience)
        try c.encode(health, forKey: .health)
        try c.encode(attack, forKey: .attack)
        try c.encode(defense, forKey: .defense)
        try c.encode(speed, forKey: .speed)
        try c.encode(critChance, forKey: .critChance)
        try c.encode(morale, forKey: .morale)
        try c.encode(skills, forKey: .skills)
        try c.encode(equippedGear, forKey: .equippedGear)
        try c.encodeIfPresent(signatureWeapon, forKey: .signatureWeapon)
        try c.encode(passiveTraits, forKey: .passiveTraits)
        try c.encode(bondPartnerIDs, forKey: .bondPartnerIDs)
        try c.encode(isUnlocked, forKey: .isUnlocked)
        try c.encodeIfPresent(unlockChapter, forKey: .unlockChapter)
    }
}

// MARK: - Hashable / Equatable

extension Hero: Hashable {
    static func == (lhs: Hero, rhs: Hero) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
