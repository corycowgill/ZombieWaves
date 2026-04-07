// Enemy.swift
// ProjectAshfall
//
// Hostile units the player fights during combat encounters.

import Foundation

// MARK: - Enemy Classification

/// Broad faction grouping that determines AI behaviour patterns and lore.
enum EnemyFamily: String, Codable, CaseIterable {
    case infected
    case raider
    case militia
    case rogueScientist

    /// Human-readable label.
    var displayName: String {
        switch self {
        case .infected:        return "Infected"
        case .raider:          return "Raider"
        case .militia:         return "Militia"
        case .rogueScientist:  return "Rogue Scientist"
        }
    }
}

/// Specific enemy archetype within a family, governing stats and abilities.
enum EnemyType: String, Codable, CaseIterable {
    // Infected family
    case shambler
    case runner
    case spitter
    case bruiser
    case screecher
    case burrower

    // Raider family
    case raiderScout
    case raiderBrute

    // Militia family
    case militiaSoldier
    case militiaSniper

    // Rogue Scientist family
    case rogueLabTech
    case rogueMutantHandler

    /// The family this type belongs to.
    var family: EnemyFamily {
        switch self {
        case .shambler, .runner, .spitter, .bruiser, .screecher, .burrower:
            return .infected
        case .raiderScout, .raiderBrute:
            return .raider
        case .militiaSoldier, .militiaSniper:
            return .militia
        case .rogueLabTech, .rogueMutantHandler:
            return .rogueScientist
        }
    }

    /// Display name for UI.
    var displayName: String {
        switch self {
        case .shambler:            return "Shambler"
        case .runner:              return "Runner"
        case .spitter:             return "Spitter"
        case .bruiser:             return "Bruiser"
        case .screecher:           return "Screecher"
        case .burrower:            return "Burrower"
        case .raiderScout:         return "Raider Scout"
        case .raiderBrute:         return "Raider Brute"
        case .militiaSoldier:      return "Militia Soldier"
        case .militiaSniper:       return "Militia Sniper"
        case .rogueLabTech:        return "Rogue Lab Tech"
        case .rogueMutantHandler:  return "Rogue Mutant Handler"
        }
    }

    /// Base stat template for level 1. Actual stats scale with level.
    var baseStats: EnemyStats {
        switch self {
        case .shambler:
            return EnemyStats(maxHealth: 80, attack: 15, defense: 5, speed: 15, critChance: 0.02)
        case .runner:
            return EnemyStats(maxHealth: 50, attack: 20, defense: 3, speed: 60, critChance: 0.08)
        case .spitter:
            return EnemyStats(maxHealth: 60, attack: 25, defense: 5, speed: 25, critChance: 0.05)
        case .bruiser:
            return EnemyStats(maxHealth: 200, attack: 35, defense: 20, speed: 12, critChance: 0.03)
        case .screecher:
            return EnemyStats(maxHealth: 40, attack: 10, defense: 3, speed: 35, critChance: 0.02)
        case .burrower:
            return EnemyStats(maxHealth: 90, attack: 30, defense: 8, speed: 20, critChance: 0.10)
        case .raiderScout:
            return EnemyStats(maxHealth: 70, attack: 22, defense: 8, speed: 45, critChance: 0.10)
        case .raiderBrute:
            return EnemyStats(maxHealth: 160, attack: 40, defense: 18, speed: 18, critChance: 0.05)
        case .militiaSoldier:
            return EnemyStats(maxHealth: 120, attack: 30, defense: 15, speed: 30, critChance: 0.08)
        case .militiaSniper:
            return EnemyStats(maxHealth: 60, attack: 50, defense: 5, speed: 20, critChance: 0.25)
        case .rogueLabTech:
            return EnemyStats(maxHealth: 80, attack: 18, defense: 10, speed: 25, critChance: 0.05)
        case .rogueMutantHandler:
            return EnemyStats(maxHealth: 140, attack: 28, defense: 12, speed: 22, critChance: 0.06)
        }
    }
}

// MARK: - Enemy Stats

/// Combat statistics for an enemy instance.
struct EnemyStats: Codable, Hashable {
    var maxHealth: Double
    var attack: Double
    var defense: Double
    var speed: Double
    var critChance: Double

    /// Creates stats scaled to a given level from a base template.
    func scaled(toLevel level: Int) -> EnemyStats {
        let multiplier = 1.0 + Double(level - 1) * 0.12
        return EnemyStats(
            maxHealth: maxHealth * multiplier,
            attack: attack * multiplier,
            defense: defense * multiplier,
            speed: speed * (1.0 + Double(level - 1) * 0.03),
            critChance: min(0.6, critChance + Double(level - 1) * 0.005)
        )
    }

    static let zero = EnemyStats(maxHealth: 0, attack: 0, defense: 0, speed: 0, critChance: 0)
}

// MARK: - Loot Drop

/// A potential loot reward from defeating an enemy.
struct LootDrop: Codable, Hashable {
    let resourceType: ResourceType
    let minAmount: Int
    let maxAmount: Int
    /// Probability of this drop occurring (0.0 to 1.0).
    let dropChance: Double

    init(resourceType: ResourceType, minAmount: Int, maxAmount: Int, dropChance: Double = 1.0) {
        self.resourceType = resourceType
        self.minAmount = minAmount
        self.maxAmount = maxAmount
        self.dropChance = min(1.0, max(0.0, dropChance))
    }
}

// MARK: - Boss Phase

/// Defines a single phase in a multi-phase boss encounter.
struct BossPhase: Codable, Hashable {
    /// Phase index (0-based).
    let phaseIndex: Int
    /// Health threshold (fraction 0...1) at which this phase activates.
    let healthThreshold: Double
    /// Abilities available only during this phase.
    let phaseSkills: [Skill]
    /// Stat modifiers applied during this phase.
    let statMultiplier: Double
    /// Description of the phase transition for narrative/UI.
    let transitionText: String

    init(
        phaseIndex: Int,
        healthThreshold: Double,
        phaseSkills: [Skill] = [],
        statMultiplier: Double = 1.0,
        transitionText: String = ""
    ) {
        self.phaseIndex = phaseIndex
        self.healthThreshold = healthThreshold
        self.phaseSkills = phaseSkills
        self.statMultiplier = statMultiplier
        self.transitionText = transitionText
    }
}

// MARK: - Enemy

/// A hostile combatant spawned by the encounter system.
final class Enemy: Codable, Identifiable {

    let id: UUID
    var name: String
    var type: EnemyType
    var family: EnemyFamily
    var level: Int
    var stats: EnemyStats
    var currentHealth: Double
    var abilities: [Skill]
    var lootTable: [LootDrop]
    var isBoss: Bool
    var bossPhases: [BossPhase]
    var spriteName: String

    /// Current boss phase index. Nil for non-boss enemies.
    var currentPhaseIndex: Int?

    // MARK: Computed

    var isAlive: Bool { currentHealth > 0 }

    /// Flat XP awarded to each surviving hero on kill.
    var experienceReward: Double {
        let bossMultiplier = isBoss ? 5.0 : 1.0
        return Double(level) * 10.0 * bossMultiplier
    }

    /// Current health as a fraction of max health (0...1).
    var healthFraction: Double {
        guard stats.maxHealth > 0 else { return 0 }
        return currentHealth / stats.maxHealth
    }

    /// The boss phase that should be active based on current health.
    var activeBossPhase: BossPhase? {
        guard isBoss else { return nil }
        return bossPhases
            .sorted { $0.healthThreshold > $1.healthThreshold }
            .first { healthFraction <= $0.healthThreshold }
    }

    // MARK: Initializer

    init(
        id: UUID = UUID(),
        name: String,
        type: EnemyType,
        level: Int = 1,
        abilities: [Skill] = [],
        lootTable: [LootDrop] = [],
        isBoss: Bool = false,
        bossPhases: [BossPhase] = [],
        spriteName: String = "enemy_default"
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.family = type.family
        self.level = level
        self.stats = type.baseStats.scaled(toLevel: level)
        self.currentHealth = self.stats.maxHealth
        self.abilities = abilities
        self.lootTable = lootTable
        self.isBoss = isBoss
        self.bossPhases = bossPhases
        self.spriteName = spriteName
        self.currentPhaseIndex = isBoss ? 0 : nil
    }

    // MARK: Methods

    /// Applies damage to this enemy and returns the actual damage dealt.
    @discardableResult
    func takeDamage(_ rawDamage: Double) -> Double {
        let mitigated = max(1.0, rawDamage - stats.defense * 0.5)
        currentHealth = max(0, currentHealth - mitigated)
        updateBossPhase()
        return mitigated
    }

    /// Heals the enemy by the given amount, clamped to max health.
    func heal(_ amount: Double) {
        currentHealth = min(stats.maxHealth, currentHealth + amount)
    }

    /// Checks and transitions boss phases based on current health.
    private func updateBossPhase() {
        guard isBoss, let activePhase = activeBossPhase else { return }
        if currentPhaseIndex != activePhase.phaseIndex {
            currentPhaseIndex = activePhase.phaseIndex
            // Apply phase stat multiplier.
            stats = type.baseStats.scaled(toLevel: level)
            stats.attack *= activePhase.statMultiplier
            stats.defense *= activePhase.statMultiplier
        }
    }

    /// Factory method: creates a standard enemy scaled to a level.
    static func standard(type: EnemyType, level: Int) -> Enemy {
        let defaultLoot = defaultLootTable(for: type)
        return Enemy(
            name: type.displayName,
            type: type,
            level: level,
            lootTable: defaultLoot,
            spriteName: "enemy_\(type.rawValue)"
        )
    }

    /// Default loot drops for a given enemy type.
    private static func defaultLootTable(for type: EnemyType) -> [LootDrop] {
        switch type.family {
        case .infected:
            return [
                LootDrop(resourceType: .bioSamples, minAmount: 1, maxAmount: 3, dropChance: 0.3),
                LootDrop(resourceType: .scrap, minAmount: 1, maxAmount: 5, dropChance: 0.5)
            ]
        case .raider:
            return [
                LootDrop(resourceType: .scrap, minAmount: 2, maxAmount: 8, dropChance: 0.6),
                LootDrop(resourceType: .fuel, minAmount: 1, maxAmount: 3, dropChance: 0.3),
                LootDrop(resourceType: .militaryComponents, minAmount: 1, maxAmount: 2, dropChance: 0.15)
            ]
        case .militia:
            return [
                LootDrop(resourceType: .militaryComponents, minAmount: 1, maxAmount: 4, dropChance: 0.4),
                LootDrop(resourceType: .electronics, minAmount: 1, maxAmount: 3, dropChance: 0.3)
            ]
        case .rogueScientist:
            return [
                LootDrop(resourceType: .researchData, minAmount: 1, maxAmount: 3, dropChance: 0.4),
                LootDrop(resourceType: .bioSamples, minAmount: 2, maxAmount: 5, dropChance: 0.5),
                LootDrop(resourceType: .electronics, minAmount: 1, maxAmount: 3, dropChance: 0.3)
            ]
        }
    }
}

// MARK: - Hashable / Equatable

extension Enemy: Hashable {
    static func == (lhs: Enemy, rhs: Enemy) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
