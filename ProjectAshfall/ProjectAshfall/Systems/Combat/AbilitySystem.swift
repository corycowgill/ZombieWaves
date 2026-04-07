// AbilitySystem.swift
// ProjectAshfall
//
// Resolves skill activations, applies status effects, and manages cooldowns.
// Works hand-in-hand with CombatEngine — the engine calls into this system
// whenever a skill is used or status effects need to tick.

import Foundation

// MARK: - Ability Effect Category

/// Broad mechanical bucket an ability falls into. Used for stacking rules
/// and UI grouping.
enum AbilityEffect: String, Codable, CaseIterable {
    case damage
    case heal
    case buff
    case debuff
    case summon
    case areaControl
}

// MARK: - Stat Modifier Target

/// Which stat a buff/debuff modifies.
enum StatModifier: String, Codable, CaseIterable {
    case attack
    case defense
    case speed
    case critChance
    case accuracy
    case evasion
    case maxHealth
}

// MARK: - Stacking Rule

/// Controls how multiple instances of the same effect interact.
enum StackingRule: String, Codable {
    /// Each application is tracked independently.
    case stackable
    /// New application refreshes the duration of the existing one.
    case refreshDuration
    /// The stronger magnitude wins; weaker is discarded.
    case strongest
    /// Only one instance allowed; new applications are ignored.
    case unique
}

// MARK: - Status Effect (template)

/// Immutable blueprint for a status effect that can be applied by abilities.
struct StatusEffect: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let abilityEffect: AbilityEffect
    /// Which stat this modifies (nil for pure damage/heal-over-time).
    let modifiedStat: StatModifier?
    /// Flat value change per tick (positive = beneficial, negative = harmful).
    let valuePerTick: Double
    /// Total duration in ticks.
    let duration: Int
    let stackingRule: StackingRule
    /// Maximum number of stacks when `stackingRule == .stackable`.
    let maxStacks: Int
    let iconName: String

    init(
        id: UUID = UUID(),
        name: String,
        abilityEffect: AbilityEffect,
        modifiedStat: StatModifier? = nil,
        valuePerTick: Double = 0,
        duration: Int = 3,
        stackingRule: StackingRule = .refreshDuration,
        maxStacks: Int = 1,
        iconName: String = "icon_effect_default"
    ) {
        self.id = id
        self.name = name
        self.abilityEffect = abilityEffect
        self.modifiedStat = modifiedStat
        self.valuePerTick = valuePerTick
        self.duration = duration
        self.stackingRule = stackingRule
        self.maxStacks = maxStacks
        self.iconName = iconName
    }
}

// MARK: - Active Status Effect (runtime)

/// A live instance of a `StatusEffect` currently applied to a participant.
struct ActiveStatusEffect: Identifiable {
    let id = UUID()
    let effect: StatusEffect
    var remainingTicks: Int
    var currentStacks: Int

    init(effect: StatusEffect) {
        self.effect = effect
        self.remainingTicks = effect.duration
        self.currentStacks = 1
    }
}

// MARK: - Ability Resolution Result

/// Feedback returned to the engine / UI after an ability resolves.
struct AbilityResolutionResult {
    let skillName: String
    let casterID: UUID
    let targetIDs: [UUID]
    let damageDealt: [UUID: Double]
    let healingDone: [UUID: Double]
    let effectsApplied: [UUID: [StatusEffect]]
}

// MARK: - Ability System

/// Stateless resolver that the `CombatEngine` delegates to for all skill
/// and status-effect logic.
final class AbilitySystem {

    // MARK: - Skill Activation

    /// Resolves a skill activation against a set of targets. Applies direct
    /// damage/healing and attaches any status effects.
    @discardableResult
    func activate(skill: Skill,
                  caster: CombatParticipant,
                  targets: [CombatParticipant],
                  map: CombatMap) -> AbilityResolutionResult {

        var damageDealt: [UUID: Double] = [:]
        var healingDone: [UUID: Double] = [:]
        var effectsApplied: [UUID: [StatusEffect]] = [:]

        for target in targets {
            guard target.isAlive else { continue }

            switch skill.effectType {

            // -- Direct damage --
            case .damage, .damageOverTime:
                let dmg = computeSkillDamage(skill: skill, caster: caster,
                                             target: target, map: map)
                target.currentHealth = max(0, target.currentHealth - dmg)
                damageDealt[target.id] = dmg

                if skill.duration > 0 {
                    let dot = makeDamageOverTime(from: skill)
                    applyEffect(dot, to: target)
                    effectsApplied[target.id, default: []].append(dot)
                }

            // -- Healing --
            case .heal, .healOverTime:
                let heal = skill.healAmount * (1.0 + caster.attack * 0.01)
                target.currentHealth = min(target.maxHealth,
                                           target.currentHealth + heal)
                healingDone[target.id] = heal

                if skill.duration > 0 {
                    let hot = makeHealOverTime(from: skill)
                    applyEffect(hot, to: target)
                    effectsApplied[target.id, default: []].append(hot)
                }

            // -- Buffs --
            case .buff, .shield:
                let buff = makeBuff(from: skill)
                applyEffect(buff, to: target)
                effectsApplied[target.id, default: []].append(buff)

            // -- Debuffs / Crowd Control --
            case .debuff, .stun, .taunt:
                let debuff = makeDebuff(from: skill)
                applyEffect(debuff, to: target)
                effectsApplied[target.id, default: []].append(debuff)

            // -- Stealth --
            case .stealth:
                let stealth = StatusEffect(
                    name: "Stealth",
                    abilityEffect: .buff,
                    modifiedStat: .evasion,
                    valuePerTick: 0.50,
                    duration: skill.duration > 0 ? skill.duration : 2,
                    stackingRule: .unique
                )
                applyEffect(stealth, to: target)
                effectsApplied[target.id, default: []].append(stealth)

            // -- Cleanse --
            case .cleanse:
                removeDebuffs(from: target)

            // -- Summon (placeholder — engine handles spawning) --
            case .summon:
                break
            }
        }

        return AbilityResolutionResult(
            skillName: skill.name,
            casterID: caster.id,
            targetIDs: targets.map(\.id),
            damageDealt: damageDealt,
            healingDone: healingDone,
            effectsApplied: effectsApplied
        )
    }

    // MARK: - Status Effect Ticking

    /// Called once per combat tick. Processes each active effect on the
    /// participant: applies per-tick values, decrements timers, and removes
    /// expired effects.
    func tickEffects(on participant: CombatParticipant,
                     elapsed: TimeInterval) {
        var expiredIndices: [Int] = []

        for (index, var active) in participant.statusEffects.enumerated() {
            let effect = active.effect
            let ticks = Double(active.currentStacks)

            switch effect.abilityEffect {
            case .damage:
                // Damage-over-time
                let tickDmg = abs(effect.valuePerTick) * ticks
                participant.currentHealth = max(0,
                    participant.currentHealth - tickDmg)

            case .heal:
                // Heal-over-time
                let tickHeal = effect.valuePerTick * ticks
                participant.currentHealth = min(participant.maxHealth,
                    participant.currentHealth + tickHeal)

            case .buff:
                applyStatModifier(effect, to: participant, sign: +1)

            case .debuff:
                applyStatModifier(effect, to: participant, sign: -1)

            case .summon, .areaControl:
                break
            }

            active.remainingTicks -= 1
            participant.statusEffects[index] = active

            if active.remainingTicks <= 0 {
                // Revert stat modifiers on expiry
                if effect.abilityEffect == .buff {
                    applyStatModifier(effect, to: participant, sign: -1)
                } else if effect.abilityEffect == .debuff {
                    applyStatModifier(effect, to: participant, sign: +1)
                }
                expiredIndices.append(index)
            }
        }

        // Remove expired in reverse order to preserve indices
        for index in expiredIndices.reversed() {
            participant.statusEffects.remove(at: index)
        }
    }

    // MARK: - Cooldown Queries

    /// Returns `true` if the given skill is off cooldown for the participant.
    func isReady(skill: Skill, for participant: CombatParticipant) -> Bool {
        (participant.cooldowns[skill.id] ?? 0) == 0
    }

    /// Returns the number of ticks remaining before a skill can be reused.
    func cooldownRemaining(skill: Skill,
                           for participant: CombatParticipant) -> Int {
        participant.cooldowns[skill.id] ?? 0
    }

    // MARK: - Effect Application (private)

    private func applyEffect(_ effect: StatusEffect,
                             to target: CombatParticipant) {
        // Check stacking rules
        if let existingIndex = target.statusEffects.firstIndex(
            where: { $0.effect.id == effect.id }) {
            var existing = target.statusEffects[existingIndex]

            switch effect.stackingRule {
            case .stackable:
                if existing.currentStacks < effect.maxStacks {
                    existing.currentStacks += 1
                }
                existing.remainingTicks = effect.duration
                target.statusEffects[existingIndex] = existing

            case .refreshDuration:
                existing.remainingTicks = effect.duration
                target.statusEffects[existingIndex] = existing

            case .strongest:
                if effect.valuePerTick > existing.effect.valuePerTick {
                    target.statusEffects[existingIndex] = ActiveStatusEffect(effect: effect)
                }

            case .unique:
                break // ignore duplicate
            }
        } else {
            target.statusEffects.append(ActiveStatusEffect(effect: effect))
        }
    }

    private func removeDebuffs(from target: CombatParticipant) {
        target.statusEffects.removeAll { $0.effect.abilityEffect == .debuff }
    }

    // MARK: - Stat Modifier Helpers

    private func applyStatModifier(_ effect: StatusEffect,
                                   to participant: CombatParticipant,
                                   sign: Int) {
        guard let stat = effect.modifiedStat else { return }
        let delta = effect.valuePerTick * Double(sign)

        switch stat {
        case .attack:     participant.attack += delta
        case .defense:    participant.defense += delta
        case .speed:      participant.speed += delta
        case .critChance: participant.critChance = max(0, min(1, participant.critChance + delta))
        case .accuracy:   participant.accuracy = max(0, min(1, participant.accuracy + delta))
        case .evasion:    participant.evasion = max(0, min(1, participant.evasion + delta))
        case .maxHealth:  participant.maxHealth += delta
        }
    }

    // MARK: - Damage / Healing Calculation

    private func computeSkillDamage(skill: Skill,
                                    caster: CombatParticipant,
                                    target: CombatParticipant,
                                    map: CombatMap) -> Double {
        let base = skill.damage + caster.attack * 0.5
        let defReduction = target.defense / (target.defense + 100.0)
        let cover = map.coverBonus(at: target.position,
                                   from: caster.position)
        let reduction = min(0.90, defReduction + cover)
        return max(1.0, base * (1.0 - reduction))
    }

    // MARK: - Effect Factories

    private func makeDamageOverTime(from skill: Skill) -> StatusEffect {
        StatusEffect(
            name: "\(skill.name) (DoT)",
            abilityEffect: .damage,
            valuePerTick: skill.damage * 0.25,
            duration: skill.duration,
            stackingRule: .refreshDuration
        )
    }

    private func makeHealOverTime(from skill: Skill) -> StatusEffect {
        StatusEffect(
            name: "\(skill.name) (HoT)",
            abilityEffect: .heal,
            valuePerTick: skill.healAmount * 0.3,
            duration: skill.duration,
            stackingRule: .refreshDuration
        )
    }

    private func makeBuff(from skill: Skill) -> StatusEffect {
        StatusEffect(
            name: skill.name,
            abilityEffect: .buff,
            modifiedStat: .defense,
            valuePerTick: skill.damage > 0 ? skill.damage * 0.2 : 10.0,
            duration: max(1, skill.duration),
            stackingRule: .refreshDuration
        )
    }

    private func makeDebuff(from skill: Skill) -> StatusEffect {
        StatusEffect(
            name: skill.name,
            abilityEffect: .debuff,
            modifiedStat: .attack,
            valuePerTick: skill.damage > 0 ? skill.damage * 0.15 : 8.0,
            duration: max(1, skill.duration),
            stackingRule: .refreshDuration
        )
    }
}
