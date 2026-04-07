// Skill.swift
// ProjectAshfall
//
// Defines hero abilities: active skills, passives, and ultimates.

import Foundation

// MARK: - Skill Classification

/// Determines when and how a skill activates during combat.
enum SkillType: String, Codable, CaseIterable {
    /// Manually triggered ability with a cooldown.
    case active
    /// Always-on bonus that applies automatically.
    case passive
    /// High-impact ability that charges over the course of a battle.
    case ultimate
}

/// Who or what the skill affects when activated.
enum TargetType: String, Codable, CaseIterable {
    case single
    case area
    case `self`
    case allAllies
    case allEnemies
}

/// The mechanical category of the effect a skill produces.
enum SkillEffectType: String, Codable, CaseIterable {
    case damage
    case heal
    case buff
    case debuff
    case shield
    case stun
    case damageOverTime
    case healOverTime
    case taunt
    case stealth
    case summon
    case cleanse
    case armorBreak
    case slow
    case bleed
    case burn
    case empower
}

// MARK: - Skill

/// A single hero ability with all the data needed for both UI display and
/// combat resolution.
struct Skill: Codable, Identifiable, Hashable {

    let id: UUID
    let name: String
    let description: String
    let type: SkillType
    let targetType: TargetType

    /// Turns before the skill can be used again (0 for passives).
    let cooldown: Int

    /// Base damage dealt. Zero for non-damage skills.
    let damage: Double

    /// Base healing applied. Non-zero only for healing skills.
    let healAmount: Double

    /// Number of turns the effect persists (0 = instant).
    let duration: Int

    let effectType: SkillEffectType

    /// Hero level required to unlock this skill.
    let unlockLevel: Int

    /// Asset name for the skill icon.
    let iconName: String

    /// Percentage multiplier applied to base stat scaling (1.0 = 100%).
    let scalingFactor: Double

    /// Optional status effects applied on hit (e.g. "burn", "slow").
    let statusEffects: [String]

    // MARK: Computed

    /// Whether this skill deals damage.
    var isDamaging: Bool { damage > 0 }

    /// Whether this skill heals.
    var isHealing: Bool { healAmount > 0 }

    /// Whether this skill applies a persistent effect.
    var hasDuration: Bool { duration > 0 }

    // MARK: Initializer

    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        type: SkillType,
        targetType: TargetType,
        cooldown: Int = 0,
        damage: Double = 0,
        healAmount: Double = 0,
        duration: Int = 0,
        effectType: SkillEffectType,
        unlockLevel: Int = 1,
        iconName: String,
        scalingFactor: Double = 1.0,
        statusEffects: [String] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.type = type
        self.targetType = targetType
        self.cooldown = cooldown
        self.damage = damage
        self.healAmount = healAmount
        self.duration = duration
        self.effectType = effectType
        self.unlockLevel = unlockLevel
        self.iconName = iconName
        self.scalingFactor = scalingFactor
        self.statusEffects = statusEffects
    }
}
