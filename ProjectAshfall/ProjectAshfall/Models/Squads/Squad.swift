// Squad.swift
// ProjectAshfall
//
// A deployment group of heroes sent on missions or into combat, with
// formation selection, support-unit slots, and bond-derived bonuses.

import Foundation

// MARK: - Formation Type

/// Tactical formation that modifies squad behaviour in combat.
enum FormationType: String, Codable, CaseIterable {
    case balanced
    case aggressive
    case defensive
    case flanking

    /// Short description for the formation picker UI.
    var description: String {
        switch self {
        case .balanced:   return "Balanced positioning with moderate offense and defense."
        case .aggressive: return "Forward-heavy stance that increases attack at the cost of defense."
        case .defensive:  return "Tight formation that boosts defense and reduces incoming damage."
        case .flanking:   return "Split formation that increases crit chance and speed."
        }
    }

    /// Stat modifiers applied to every squad member while this formation is active.
    var modifiers: (attackPercent: Double, defensePercent: Double, speedPercent: Double, critPercent: Double) {
        switch self {
        case .balanced:   return (0.0,   0.0,   0.0,   0.0)
        case .aggressive: return (0.15, -0.10,  0.05,  0.05)
        case .defensive:  return (-0.05, 0.20, -0.05,  0.0)
        case .flanking:   return (0.05, -0.05,  0.10,  0.10)
        }
    }
}

// MARK: - Support Unit

/// A non-hero asset attached to a squad for extra capability.
struct SupportUnit: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let type: SupportUnitType
    /// Flat stat bonus applied to the entire squad.
    let attackBonus: Double
    let defenseBonus: Double
    let speedBonus: Double

    init(
        id: UUID = UUID(),
        name: String,
        type: SupportUnitType,
        attackBonus: Double = 0,
        defenseBonus: Double = 0,
        speedBonus: Double = 0
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.attackBonus = attackBonus
        self.defenseBonus = defenseBonus
        self.speedBonus = speedBonus
    }
}

/// Category of support unit.
enum SupportUnitType: String, Codable, CaseIterable {
    case drone
    case turretPlatform
    case medicalBot
    case supplyMule
    case armoredVehicle
}

// MARK: - Squad

/// Maximum heroes allowed in a single squad.
let kMaxSquadSize: Int = 5

/// Maximum support units allowed in a single squad.
let kMaxSupportUnits: Int = 2

/// A named group of heroes deployed together with a formation and support units.
struct Squad: Codable, Identifiable, Hashable {

    let id: UUID
    var name: String
    var heroIDs: [UUID]
    var formation: FormationType
    var supportUnits: [SupportUnit]

    var isFull: Bool { heroIDs.count >= kMaxSquadSize }
    var isEmpty: Bool { heroIDs.isEmpty }
    var heroCount: Int { heroIDs.count }

    // MARK: Init

    init(
        id: UUID = UUID(),
        name: String = "Alpha Squad",
        heroIDs: [UUID] = [],
        formation: FormationType = .balanced,
        supportUnits: [SupportUnit] = []
    ) {
        self.id = id
        self.name = name
        self.heroIDs = Array(heroIDs.prefix(kMaxSquadSize))
        self.formation = formation
        self.supportUnits = Array(supportUnits.prefix(kMaxSupportUnits))
    }

    // MARK: Hero Management

    /// Adds a hero to the squad if there is room.
    mutating func addHero(_ heroID: UUID) {
        guard !isFull, !heroIDs.contains(heroID) else { return }
        heroIDs.append(heroID)
    }

    /// Removes a hero from the squad.
    mutating func removeHero(_ heroID: UUID) {
        heroIDs.removeAll { $0 == heroID }
    }

    /// Adds a support unit if there is room.
    mutating func addSupportUnit(_ unit: SupportUnit) {
        guard supportUnits.count < kMaxSupportUnits else { return }
        supportUnits.append(unit)
    }

    /// Removes a support unit by ID.
    mutating func removeSupportUnit(_ unitID: UUID) {
        supportUnits.removeAll { $0.id == unitID }
    }

    // MARK: Bonus Calculations

    /// Computes a combined squad bonus from formation, support units, and hero bonds.
    /// - Parameter heroes: The actual Hero objects in this squad (resolved from heroIDs).
    /// - Parameter bonds: All known hero bonds.
    /// - Returns: A SquadBonus summarising aggregate modifiers.
    func computeBonus(heroes: [Hero], bonds: [HeroBond]) -> SquadBonus {
        let fm = formation.modifiers

        // Support unit bonuses.
        let supportAttack  = supportUnits.reduce(0.0) { $0 + $1.attackBonus }
        let supportDefense = supportUnits.reduce(0.0) { $0 + $1.defenseBonus }
        let supportSpeed   = supportUnits.reduce(0.0) { $0 + $1.speedBonus }

        // Bond bonuses: for every pair of heroes that share a bond, add effects.
        var bondAttack  = 0.0
        var bondDefense = 0.0
        var bondSpeed   = 0.0
        var bondHealth  = 0.0

        let heroIDSet = Set(heroIDs)
        for bond in bonds {
            guard heroIDSet.contains(bond.heroID1) && heroIDSet.contains(bond.heroID2) else { continue }
            for effect in bond.activeEffects {
                switch effect.stat {
                case .attack:  bondAttack  += effect.flatBonus
                case .defense: bondDefense += effect.flatBonus
                case .speed:   bondSpeed   += effect.flatBonus
                case .health:  bondHealth  += effect.flatBonus
                default: break
                }
            }
        }

        return SquadBonus(
            formationAttackPercent:  fm.attackPercent,
            formationDefensePercent: fm.defensePercent,
            formationSpeedPercent:   fm.speedPercent,
            formationCritPercent:    fm.critPercent,
            supportAttackFlat:       supportAttack,
            supportDefenseFlat:      supportDefense,
            supportSpeedFlat:        supportSpeed,
            bondAttackFlat:          bondAttack,
            bondDefenseFlat:         bondDefense,
            bondSpeedFlat:           bondSpeed,
            bondHealthFlat:          bondHealth
        )
    }

    /// Estimates total squad power from resolved heroes.
    func powerRating(heroes: [Hero]) -> Double {
        heroes.reduce(0.0) { $0 + $1.powerRating }
    }
}

// MARK: - Squad Bonus

/// Aggregated bonus values computed from formation, support units, and bonds.
struct SquadBonus: Codable, Hashable {
    let formationAttackPercent: Double
    let formationDefensePercent: Double
    let formationSpeedPercent: Double
    let formationCritPercent: Double
    let supportAttackFlat: Double
    let supportDefenseFlat: Double
    let supportSpeedFlat: Double
    let bondAttackFlat: Double
    let bondDefenseFlat: Double
    let bondSpeedFlat: Double
    let bondHealthFlat: Double

    /// Total attack modifier (flat portion).
    var totalAttackFlat: Double { supportAttackFlat + bondAttackFlat }
    /// Total defense modifier (flat portion).
    var totalDefenseFlat: Double { supportDefenseFlat + bondDefenseFlat }
    /// Total speed modifier (flat portion).
    var totalSpeedFlat: Double { supportSpeedFlat + bondSpeedFlat }

    static let zero = SquadBonus(
        formationAttackPercent: 0, formationDefensePercent: 0,
        formationSpeedPercent: 0, formationCritPercent: 0,
        supportAttackFlat: 0, supportDefenseFlat: 0, supportSpeedFlat: 0,
        bondAttackFlat: 0, bondDefenseFlat: 0, bondSpeedFlat: 0, bondHealthFlat: 0
    )
}
