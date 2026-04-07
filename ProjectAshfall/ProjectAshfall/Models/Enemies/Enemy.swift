// Enemy.swift
// ProjectAshfall
//
// Hostile units the player fights during combat encounters.

import Foundation

// MARK: - Enemy Classification

/// Broad behavioural archetype that drives AI decisions.
enum EnemyType: String, Codable, CaseIterable {
    case walker       // slow melee swarm
    case runner       // fast melee
    case spitter      // ranged
    case brute        // tanky melee
    case screamer     // support / buff nearby
    case boss         // unique encounter
    case raider       // hostile human
}

/// Threat tier used for difficulty gating and reward scaling.
enum EnemyTier: Int, Codable, CaseIterable, Comparable {
    case fodder   = 0
    case standard = 1
    case elite    = 2
    case miniboss = 3
    case boss     = 4

    static func < (lhs: EnemyTier, rhs: EnemyTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Enemy Stats

/// Combat stats for an enemy instance. Mirrors HeroStats where applicable.
struct EnemyStats: Codable, Hashable {
    var maxHealth: Double
    var currentHealth: Double
    var attack: Double
    var defense: Double
    var speed: Double
    var critChance: Double
    var critMultiplier: Double
    var accuracy: Double
    var evasion: Double

    static let zero = EnemyStats(
        maxHealth: 0, currentHealth: 0, attack: 0, defense: 0,
        speed: 0, critChance: 0, critMultiplier: 0, accuracy: 0, evasion: 0
    )
}

// MARK: - Enemy

/// A hostile combatant spawned by the encounter system.
struct Enemy: Codable, Identifiable, Hashable {

    let id: UUID
    var name: String
    var type: EnemyType
    var tier: EnemyTier
    var level: Int
    var stats: EnemyStats
    var skills: [Skill]
    var spriteName: String

    var isAlive: Bool { stats.currentHealth > 0 }

    /// Flat XP awarded to each surviving hero on kill.
    var experienceReward: Double {
        Double(level) * 10.0 * Double(tier.rawValue + 1)
    }

    init(
        id: UUID = UUID(),
        name: String,
        type: EnemyType,
        tier: EnemyTier = .standard,
        level: Int = 1,
        stats: EnemyStats,
        skills: [Skill] = [],
        spriteName: String = "enemy_default"
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.tier = tier
        self.level = level
        self.stats = stats
        self.skills = skills
        self.spriteName = spriteName
    }
}
