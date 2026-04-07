// HeroBond.swift
// ProjectAshfall
//
// Tracks the relationship between two heroes, granting stat bonuses as
// their bond deepens through shared missions and events.

import Foundation

// MARK: - Bond Level

/// Progressive tiers of a bond between two heroes.
enum BondLevel: Int, Codable, CaseIterable, Comparable {
    case stranger   = 0
    case acquainted = 1
    case trusted    = 2
    case bonded     = 3
    case unbreakable = 4

    static func < (lhs: BondLevel, rhs: BondLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Experience points required to reach this level from the previous one.
    var threshold: Double {
        switch self {
        case .stranger:    return 0
        case .acquainted:  return 100
        case .trusted:     return 300
        case .bonded:      return 700
        case .unbreakable: return 1500
        }
    }

    /// Cumulative experience needed to reach this level.
    var cumulativeThreshold: Double {
        BondLevel.allCases
            .filter { $0.rawValue <= self.rawValue }
            .reduce(0) { $0 + $1.threshold }
    }

    /// Human-readable display name.
    var displayName: String {
        switch self {
        case .stranger:    return "Stranger"
        case .acquainted:  return "Acquainted"
        case .trusted:     return "Trusted"
        case .bonded:      return "Bonded"
        case .unbreakable: return "Unbreakable"
        }
    }
}

// MARK: - Bond Effect

/// A stat bonus granted when two bonded heroes are deployed together.
struct BondEffect: Codable, Hashable {
    let stat: ModifiableStat
    let flatBonus: Double
    let percentBonus: Double
    let requiredLevel: BondLevel
    let description: String

    init(
        stat: ModifiableStat,
        flatBonus: Double = 0,
        percentBonus: Double = 0,
        requiredLevel: BondLevel = .acquainted,
        description: String = ""
    ) {
        self.stat = stat
        self.flatBonus = flatBonus
        self.percentBonus = percentBonus
        self.requiredLevel = requiredLevel
        self.description = description
    }
}

// MARK: - Hero Bond

/// Tracks the relationship progress between two specific heroes.
final class HeroBond: Codable, Identifiable {

    let id: UUID

    /// The two heroes involved, stored as sorted IDs for consistency.
    let heroID1: UUID
    let heroID2: UUID

    /// Accumulated bond experience.
    private(set) var experience: Double

    /// Current bond level derived from accumulated experience.
    var level: BondLevel {
        var highest = BondLevel.stranger
        for bl in BondLevel.allCases {
            if experience >= bl.cumulativeThreshold {
                highest = bl
            }
        }
        return highest
    }

    /// Effects that are active based on the current bond level.
    var activeEffects: [BondEffect] {
        effects.filter { $0.requiredLevel <= level }
    }

    /// All possible effects this bond can grant across all levels.
    let effects: [BondEffect]

    /// Short narrative flavour for the bond.
    let narrative: String

    /// Experience needed to reach the next bond level. Returns 0 if maxed.
    var experienceToNextLevel: Double {
        guard let nextLevel = BondLevel(rawValue: level.rawValue + 1) else { return 0 }
        return nextLevel.cumulativeThreshold - experience
    }

    /// Progress toward the next level as a fraction 0...1.
    var progressToNextLevel: Double {
        guard let nextLevel = BondLevel(rawValue: level.rawValue + 1) else { return 1.0 }
        let currentThreshold = level.cumulativeThreshold
        let nextThreshold = nextLevel.cumulativeThreshold
        let range = nextThreshold - currentThreshold
        guard range > 0 else { return 1.0 }
        return min(1.0, (experience - currentThreshold) / range)
    }

    // MARK: Initializer

    init(
        id: UUID = UUID(),
        heroID1: UUID,
        heroID2: UUID,
        experience: Double = 0,
        effects: [BondEffect] = [],
        narrative: String = ""
    ) {
        self.id = id
        // Always store smaller UUID first for consistent lookup.
        if heroID1.uuidString < heroID2.uuidString {
            self.heroID1 = heroID1
            self.heroID2 = heroID2
        } else {
            self.heroID1 = heroID2
            self.heroID2 = heroID1
        }
        self.experience = experience
        self.effects = effects
        self.narrative = narrative
    }

    // MARK: Methods

    /// Awards bond experience from shared missions or events.
    /// Returns true if a new bond level was reached.
    @discardableResult
    func addExperience(_ amount: Double) -> Bool {
        guard amount > 0 else { return false }
        let previousLevel = level
        experience += amount
        return level > previousLevel
    }

    /// Checks whether this bond involves the given hero ID.
    func involves(heroID: UUID) -> Bool {
        heroID1 == heroID || heroID2 == heroID
    }

    /// Returns the partner's ID given one hero in the bond.
    func partner(of heroID: UUID) -> UUID? {
        if heroID == heroID1 { return heroID2 }
        if heroID == heroID2 { return heroID1 }
        return nil
    }
}

// MARK: - Hashable / Equatable

extension HeroBond: Hashable {
    static func == (lhs: HeroBond, rhs: HeroBond) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
