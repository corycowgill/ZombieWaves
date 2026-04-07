// DifficultyManager.swift
// ProjectAshfall
//
// Calculates enemy scaling, recommends power levels per district, and
// provides adaptive difficulty hints. Death mechanics are non-punitive:
// the player loses consumables and morale, never permanent progress.

import Foundation

// MARK: - Difficulty Tier

/// Named difficulty bracket for UI display and internal scaling.
enum DifficultyTier: String, Codable, CaseIterable {
    case story       // relaxed — enemies 20 % weaker
    case normal      // baseline
    case challenging // enemies 15 % stronger
    case nightmare   // enemies 30 % stronger, tighter resource economy
}

// MARK: - Defeat Penalty

/// What the player loses upon a combat defeat. Intentionally lenient:
/// no hero permadeath, no progress wipe.
struct DefeatPenalty {
    /// Fraction of consumable resources lost (0.0–1.0).
    let consumableLossFraction: Double
    /// Flat morale drop applied to all surviving heroes.
    let moralePenalty: Double
    /// Whether the player keeps partial mission rewards.
    let keepsPartialRewards: Bool
    /// Narrative message shown on the defeat screen.
    let message: String
}

// MARK: - Difficulty Hint

/// A suggestion shown after repeated failures on the same mission.
struct DifficultyHint {
    let title: String
    let suggestion: String
}

// MARK: - Failure Record (internal)

/// Tracks how many times the player has failed a particular district.
private struct FailureRecord {
    var districtID: UUID
    var failCount: Int
    var lastSquadPower: Double
}

// MARK: - Difficulty Manager

/// Owns the difficulty curve for the entire game. Other systems query it
/// to scale enemies, calculate penalties, and surface adaptive hints.
final class DifficultyManager {

    // MARK: Properties

    /// Active difficulty tier (player-selectable from settings).
    var tier: DifficultyTier = .normal

    /// Multiplier applied to all enemy stats based on the selected tier.
    var tierMultiplier: Double {
        switch tier {
        case .story:       return 0.80
        case .normal:      return 1.00
        case .challenging: return 1.15
        case .nightmare:   return 1.30
        }
    }

    /// Per-district failure tracking for adaptive hints.
    private var failureRecords: [UUID: FailureRecord] = [:]

    // MARK: - Enemy Scaling

    /// Returns scaled enemy stats for a given base enemy, commander level,
    /// and district threat level.
    func scaledEnemyStats(base: EnemyStats,
                          enemyLevel: Int,
                          commanderLevel: Int,
                          threat: ThreatLevel) -> EnemyStats {
        // Level delta scaling: enemies gain 3 % per level above 1
        let levelFactor = 1.0 + 0.03 * Double(enemyLevel - 1)
        // Threat scaling: each threat tier adds 10 %
        let threatFactor = 1.0 + 0.10 * Double(threat.rawValue)
        // Combined with tier multiplier
        let total = levelFactor * threatFactor * tierMultiplier

        return EnemyStats(
            maxHealth: base.maxHealth * total,
            currentHealth: base.maxHealth * total,
            attack: base.attack * total,
            defense: base.defense * total,
            speed: base.speed * (1.0 + 0.01 * Double(enemyLevel - 1)),
            critChance: min(0.50, base.critChance + 0.005 * Double(enemyLevel)),
            critMultiplier: base.critMultiplier,
            accuracy: min(0.95, base.accuracy + 0.005 * Double(enemyLevel)),
            evasion: min(0.40, base.evasion + 0.003 * Double(enemyLevel))
        )
    }

    // MARK: - Recommended Power

    /// Returns the recommended squad power rating for a district.
    func recommendedPower(forDistrict district: District,
                          commanderLevel: Int) -> Double {
        let base: Double = 100.0
        let threatScale = Double(district.threatLevel.rawValue + 1) * 50.0
        let levelScale = Double(commanderLevel) * 10.0
        return (base + threatScale + levelScale) * tierMultiplier
    }

    /// Returns a human-readable difficulty label comparing squad power
    /// to recommended power.
    func difficultyLabel(squadPower: Double,
                         recommendedPower: Double) -> String {
        let ratio = squadPower / max(1, recommendedPower)
        switch ratio {
        case ..<0.6:     return "Extremely Dangerous"
        case 0.6..<0.8:  return "Very Hard"
        case 0.8..<1.0:  return "Challenging"
        case 1.0..<1.3:  return "Fair Fight"
        case 1.3..<1.6:  return "Easy"
        default:         return "Trivial"
        }
    }

    // MARK: - Defeat Penalties

    /// Builds the penalty struct for a defeat. Intentionally non-punitive.
    func defeatPenalty(for tier: DifficultyTier? = nil) -> DefeatPenalty {
        let activeTier = tier ?? self.tier
        switch activeTier {
        case .story:
            return DefeatPenalty(
                consumableLossFraction: 0.0,
                moralePenalty: 5.0,
                keepsPartialRewards: true,
                message: "Your squad fell back to base. No resources were lost."
            )
        case .normal:
            return DefeatPenalty(
                consumableLossFraction: 0.10,
                moralePenalty: 10.0,
                keepsPartialRewards: true,
                message: "Your squad retreated under fire. Some supplies were lost."
            )
        case .challenging:
            return DefeatPenalty(
                consumableLossFraction: 0.15,
                moralePenalty: 15.0,
                keepsPartialRewards: false,
                message: "A costly defeat. Supplies were abandoned in the field."
            )
        case .nightmare:
            return DefeatPenalty(
                consumableLossFraction: 0.20,
                moralePenalty: 20.0,
                keepsPartialRewards: false,
                message: "A devastating loss. Morale is shaken."
            )
        }
    }

    /// Applies defeat penalties to the resource inventory and hero roster.
    /// Returns the list of resources lost.
    func applyDefeatPenalty(inventory: ResourceInventory,
                            heroes: inout [Hero]) -> [ResourceCost] {
        let penalty = defeatPenalty()
        var losses: [ResourceCost] = []

        // Lose a fraction of consumable resources (food, water, medicine)
        let consumableTypes: [ResourceType] = [.food, .water, .medicine]
        for type in consumableTypes {
            let current = inventory.amount(of: type)
            let loss = Int(Double(current) * penalty.consumableLossFraction)
            if loss > 0 {
                inventory.spend(type, quantity: loss)
                losses.append(ResourceCost(type, loss))
            }
        }

        // Morale drop on all heroes (but never below 10)
        for i in heroes.indices {
            heroes[i].stats.morale = max(10.0,
                heroes[i].stats.morale - penalty.moralePenalty)
        }

        return losses
    }

    // MARK: - Adaptive Difficulty Hints

    /// Records a failure on a district. Call after every defeat.
    func recordFailure(districtID: UUID, squadPower: Double) {
        if var record = failureRecords[districtID] {
            record.failCount += 1
            record.lastSquadPower = squadPower
            failureRecords[districtID] = record
        } else {
            failureRecords[districtID] = FailureRecord(
                districtID: districtID, failCount: 1,
                lastSquadPower: squadPower
            )
        }
    }

    /// Clears failure tracking for a district (call after a victory).
    func clearFailures(forDistrict districtID: UUID) {
        failureRecords.removeValue(forKey: districtID)
    }

    /// Returns adaptive hints if the player has failed a district multiple
    /// times. Returns `nil` if no hint is warranted.
    func adaptiveHint(forDistrict district: District,
                      availableHeroes: [Hero]) -> DifficultyHint? {
        guard let record = failureRecords[district.id],
              record.failCount >= 2 else {
            return nil
        }

        // After 2 failures: suggest squad changes
        if record.failCount == 2 {
            return squadCompositionHint(district: district,
                                       heroes: availableHeroes)
        }

        // After 4 failures: suggest upgrading or changing difficulty
        if record.failCount >= 4 {
            return DifficultyHint(
                title: "Consider a Different Approach",
                suggestion: "This district has proven very difficult. "
                    + "Try upgrading your heroes at the Barracks, improving "
                    + "gear at the Armory, or lowering the difficulty in Settings."
            )
        }

        // 3 failures: generic encouragement
        return DifficultyHint(
            title: "Keep At It",
            suggestion: "Explore other districts for loot and XP, "
                + "then return when your squad is stronger."
        )
    }

    /// Suggests a squad composition tweak based on the district's threats.
    private func squadCompositionHint(district: District,
                                     heroes: [Hero]) -> DifficultyHint {
        let hasMedic = heroes.contains { $0.role == .medic }
        let hasTank = heroes.contains { $0.role == .tank }

        if district.threatLevel >= .high && !hasTank {
            return DifficultyHint(
                title: "Try Adding a Tank",
                suggestion: "High-threat districts hit hard. A Tank hero "
                    + "can absorb damage and protect your squad."
            )
        }
        if !hasMedic {
            return DifficultyHint(
                title: "Bring a Medic",
                suggestion: "A Medic can keep your squad alive through "
                    + "sustained fights. Consider adding one to your roster."
            )
        }
        return DifficultyHint(
            title: "Try a Different Squad",
            suggestion: "Swap in heroes that counter the enemies in this "
                + "district. Check the enemy types in the Intel screen."
        )
    }

    // MARK: - Enemy Count Scaling

    /// Returns how many enemies should spawn in an encounter for the given
    /// district, scaled by threat and tier.
    func enemyCount(forThreat threat: ThreatLevel,
                    baseCount: Int = 4) -> Int {
        let extra = threat.rawValue
        let tierExtra: Int
        switch tier {
        case .story:       tierExtra = -1
        case .normal:      tierExtra = 0
        case .challenging: tierExtra = 1
        case .nightmare:   tierExtra = 2
        }
        return max(1, baseCount + extra + tierExtra)
    }
}
