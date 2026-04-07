// CombatEngine.swift
// ProjectAshfall
//
// Core real-time-with-pause combat system. Manages turn resolution, damage
// calculation, unit actions, and tactical pause. Designed for SpriteKit's
// frame-driven update loop.

import Foundation
import SpriteKit

// MARK: - Combat State

/// High-level phase of an ongoing encounter.
enum CombatState: String, Codable {
    case preparing
    case inProgress
    case paused
    case victory
    case defeat
    case retreated
}

// MARK: - Combat Participant

/// Wrapper that unifies heroes and enemies on the battlefield. Each
/// participant occupies a tile, tracks cooldowns, and records active
/// status effects.
final class CombatParticipant: Identifiable {

    let id: UUID
    var name: String
    var isPlayerControlled: Bool

    // Stats (mutable copies taken at combat start)
    var maxHealth: Double
    var currentHealth: Double
    var attack: Double
    var defense: Double
    var speed: Double
    var critChance: Double
    var critMultiplier: Double
    var accuracy: Double
    var evasion: Double

    /// Current tile position on the CombatMap.
    var position: GridPosition
    /// Remaining cooldowns keyed by Skill.id.
    var cooldowns: [UUID: Int] = [:]
    /// Active status effects applied to this participant.
    var statusEffects: [ActiveStatusEffect] = []
    /// Source hero or enemy ID for post-combat bookkeeping.
    var sourceID: UUID

    var isAlive: Bool { currentHealth > 0 }

    // MARK: Factory

    /// Creates a participant from a Hero model.
    static func fromHero(_ hero: Hero, at position: GridPosition) -> CombatParticipant {
        CombatParticipant(
            id: UUID(),
            name: hero.name,
            isPlayerControlled: true,
            maxHealth: hero.stats.maxHealth,
            currentHealth: hero.stats.currentHealth,
            attack: hero.stats.attack,
            defense: hero.stats.defense,
            speed: hero.stats.speed,
            critChance: hero.stats.critChance,
            critMultiplier: hero.stats.critMultiplier,
            accuracy: hero.stats.accuracy,
            evasion: hero.stats.evasion,
            position: position,
            sourceID: hero.id
        )
    }

    /// Creates a participant from an Enemy model.
    static func fromEnemy(_ enemy: Enemy, at position: GridPosition) -> CombatParticipant {
        CombatParticipant(
            id: UUID(),
            name: enemy.name,
            isPlayerControlled: false,
            maxHealth: enemy.stats.maxHealth,
            currentHealth: enemy.stats.currentHealth,
            attack: enemy.stats.attack,
            defense: enemy.stats.defense,
            speed: enemy.stats.speed,
            critChance: enemy.stats.critChance,
            critMultiplier: enemy.stats.critMultiplier,
            accuracy: enemy.stats.accuracy,
            evasion: enemy.stats.evasion,
            position: position,
            sourceID: enemy.id
        )
    }

    private init(
        id: UUID, name: String, isPlayerControlled: Bool,
        maxHealth: Double, currentHealth: Double, attack: Double,
        defense: Double, speed: Double, critChance: Double,
        critMultiplier: Double, accuracy: Double, evasion: Double,
        position: GridPosition, sourceID: UUID
    ) {
        self.id = id
        self.name = name
        self.isPlayerControlled = isPlayerControlled
        self.maxHealth = maxHealth
        self.currentHealth = currentHealth
        self.attack = attack
        self.defense = defense
        self.speed = speed
        self.critChance = critChance
        self.critMultiplier = critMultiplier
        self.accuracy = accuracy
        self.evasion = evasion
        self.position = position
        self.sourceID = sourceID
    }
}

// MARK: - Damage Calculation

/// Pure-function damage pipeline. All randomness is seeded through the
/// provided closure so combat can be replayed deterministically.
struct DamageCalculation {

    /// Result of a single attack resolution.
    struct Result {
        let rawDamage: Double
        let mitigatedDamage: Double
        let isCrit: Bool
        let isHit: Bool
        let coverReduction: Double
    }

    /// Resolves an attack from `attacker` against `defender` with optional
    /// cover bonus and a caller-supplied RNG closure (0.0 ..< 1.0).
    static func resolve(
        attacker: CombatParticipant,
        defender: CombatParticipant,
        coverBonus: Double = 0.0,
        random: () -> Double = { Double.random(in: 0.0 ..< 1.0) }
    ) -> Result {
        // Hit check
        let hitChance = max(0.05, min(0.95, attacker.accuracy - defender.evasion))
        let isHit = random() < hitChance
        guard isHit else {
            return Result(rawDamage: 0, mitigatedDamage: 0, isCrit: false,
                          isHit: false, coverReduction: 0)
        }

        // Crit check
        let isCrit = random() < attacker.critChance
        let critFactor = isCrit ? attacker.critMultiplier : 1.0

        // Raw damage with +/-10 % variance
        let variance = 0.9 + random() * 0.2
        let rawDamage = attacker.attack * critFactor * variance

        // Defense mitigation: defense / (defense + 100) scaling
        let defenseReduction = defender.defense / (defender.defense + 100.0)

        // Cover adds a flat percentage on top of defense mitigation
        let coverReduction = coverBonus
        let totalReduction = min(0.90, defenseReduction + coverReduction)

        let mitigated = rawDamage * (1.0 - totalReduction)
        let finalDamage = max(1.0, mitigated) // always deal at least 1

        return Result(rawDamage: rawDamage, mitigatedDamage: finalDamage,
                      isCrit: isCrit, isHit: true, coverReduction: coverReduction)
    }
}

// MARK: - Combat Log Entry

/// A single recorded event for the post-combat replay and UI feed.
struct CombatLogEntry: Identifiable {
    let id = UUID()
    let timestamp: TimeInterval
    let message: String
    let involvedIDs: [UUID]
}

// MARK: - Combat Outcome

/// Summary delivered when combat ends.
struct CombatOutcome {
    let state: CombatState
    let survivingHeroIDs: [UUID]
    let defeatedEnemyIDs: [UUID]
    let experienceEarned: Double
    let loot: [ResourceCost]
    let log: [CombatLogEntry]
}

// MARK: - Pending Command

/// A command queued by the player during tactical pause.
enum PendingCommand {
    case move(participantID: UUID, destination: GridPosition)
    case attack(participantID: UUID, targetID: UUID)
    case skill(participantID: UUID, skillID: UUID, targetID: UUID?)
    case retreat(participantID: UUID)
}

// MARK: - Combat Engine

/// Orchestrates a single combat encounter. Feed `processFrame(deltaTime:)`
/// from your SpriteKit scene's `update(_:)`.
final class CombatEngine {

    // MARK: Public State

    private(set) var state: CombatState = .preparing
    private(set) var participants: [CombatParticipant] = []
    private(set) var combatLog: [CombatLogEntry] = []

    /// When true the engine resolves player actions automatically.
    var isAutoBattle: Bool = false

    // MARK: Dependencies

    private let map: CombatMap
    private let abilitySystem: AbilitySystem

    /// Elapsed combat time in seconds.
    private var elapsedTime: TimeInterval = 0

    /// Time between individual turn ticks (seconds).
    private let tickInterval: TimeInterval = 1.0
    private var tickAccumulator: TimeInterval = 0

    /// Commands issued during a tactical pause, resolved on resume.
    private var pendingCommands: [PendingCommand] = []

    /// Skills keyed by owning hero/enemy source ID for quick lookup.
    private var skillsBySource: [UUID: [Skill]] = [:]

    // MARK: Init

    init(map: CombatMap, abilitySystem: AbilitySystem = AbilitySystem()) {
        self.map = map
        self.abilitySystem = abilitySystem
    }

    // MARK: - Setup

    /// Registers heroes and enemies for the encounter. Call before
    /// `startCombat()`.
    func registerParticipants(heroes: [(Hero, GridPosition)],
                              enemies: [(Enemy, GridPosition)]) {
        for (hero, pos) in heroes {
            let p = CombatParticipant.fromHero(hero, at: pos)
            participants.append(p)
            skillsBySource[p.sourceID] = hero.skills
            map.placeOccupant(p.id, at: pos)
        }
        for (enemy, pos) in enemies {
            let p = CombatParticipant.fromEnemy(enemy, at: pos)
            participants.append(p)
            skillsBySource[p.sourceID] = enemy.skills
            map.placeOccupant(p.id, at: pos)
        }
    }

    // MARK: - Flow Control

    /// Transitions from `.preparing` to `.inProgress`.
    func startCombat() {
        guard state == .preparing else { return }
        state = .inProgress
        log("Combat started.")
    }

    /// Pauses the simulation — player may issue commands while paused.
    func pause() {
        guard state == .inProgress else { return }
        state = .paused
        log("Combat paused.")
    }

    /// Resumes from pause, flushing any queued commands first.
    func resume() {
        guard state == .paused else { return }
        resolvePendingCommands()
        state = .inProgress
        log("Combat resumed.")
    }

    /// Player-initiated retreat — surviving heroes lose morale.
    func retreat() {
        guard state == .inProgress || state == .paused else { return }
        state = .retreated
        log("Player retreated from combat.")
    }

    // MARK: - Player Commands (issued during pause or real-time)

    /// Queues a move order for `participantID`.
    func moveUnit(_ participantID: UUID, to destination: GridPosition) {
        pendingCommands.append(.move(participantID: participantID,
                                     destination: destination))
    }

    /// Queues a basic attack order.
    func orderAttack(_ participantID: UUID, targetID: UUID) {
        pendingCommands.append(.attack(participantID: participantID,
                                       targetID: targetID))
    }

    /// Queues a skill activation. `targetID` may be nil for self-targeted
    /// abilities.
    func activateSkill(_ participantID: UUID, skillID: UUID,
                       targetID: UUID? = nil) {
        pendingCommands.append(.skill(participantID: participantID,
                                      skillID: skillID,
                                      targetID: targetID))
    }

    // MARK: - Frame Processing

    /// Drive from SpriteKit's `update(_:)`. Advances simulation when
    /// `.inProgress`.
    func processFrame(deltaTime dt: TimeInterval) {
        guard state == .inProgress else { return }

        elapsedTime += dt
        tickAccumulator += dt

        // Resolve queued real-time commands
        if !pendingCommands.isEmpty {
            resolvePendingCommands()
        }

        // Tick-based resolution
        while tickAccumulator >= tickInterval {
            tickAccumulator -= tickInterval
            processTick()
        }

        // Win / loss check
        evaluateOutcome()
    }

    // MARK: - Outcome

    /// Builds a `CombatOutcome` once combat has ended.
    func buildOutcome() -> CombatOutcome? {
        guard state == .victory || state == .defeat || state == .retreated else {
            return nil
        }
        let surviving = participants.filter { $0.isPlayerControlled && $0.isAlive }
            .map(\.sourceID)
        let defeated = participants.filter { !$0.isPlayerControlled && !$0.isAlive }
            .map(\.sourceID)
        let xp = defeated.isEmpty ? 0.0 : Double(defeated.count) * 25.0

        return CombatOutcome(
            state: state,
            survivingHeroIDs: surviving,
            defeatedEnemyIDs: defeated,
            experienceEarned: xp,
            loot: [], // populated by caller from loot tables
            log: combatLog
        )
    }

    // MARK: - Private: Tick Resolution

    private func processTick() {
        // Sort participants by speed (descending) for turn order.
        let ordered = participants.filter(\.isAlive).sorted { $0.speed > $1.speed }

        for participant in ordered {
            guard participant.isAlive else { continue }

            // 1. Tick status effects
            abilitySystem.tickEffects(on: participant, elapsed: tickInterval)

            // 2. Tick cooldowns
            for (skillID, remaining) in participant.cooldowns {
                participant.cooldowns[skillID] = max(0, remaining - 1)
            }

            // 3. AI or auto-battle action
            if !participant.isPlayerControlled || isAutoBattle {
                resolveAIAction(for: participant)
            }
        }
    }

    /// Simple AI: move toward nearest enemy, attack if adjacent or in range.
    private func resolveAIAction(for participant: CombatParticipant) {
        let opponents = participants.filter {
            $0.isAlive && $0.isPlayerControlled != participant.isPlayerControlled
        }
        guard let nearest = opponents.min(by: {
            participant.position.distance(to: $0.position)
                < participant.position.distance(to: $1.position)
        }) else { return }

        let distance = participant.position.distance(to: nearest.position)

        if distance <= 1 {
            // Melee range — attack
            resolveAttack(from: participant, to: nearest)
        } else {
            // Move toward target
            if let path = map.findPath(from: participant.position,
                                       to: nearest.position) {
                let step = path.prefix(2).last ?? participant.position
                executeMove(participant, to: step)
            }
        }
    }

    // MARK: - Private: Command Resolution

    private func resolvePendingCommands() {
        let commands = pendingCommands
        pendingCommands.removeAll()

        for command in commands {
            switch command {
            case .move(let pid, let dest):
                guard let p = participant(for: pid), p.isAlive else { continue }
                executeMove(p, to: dest)

            case .attack(let pid, let tid):
                guard let p = participant(for: pid), p.isAlive,
                      let t = participant(for: tid), t.isAlive else { continue }
                resolveAttack(from: p, to: t)

            case .skill(let pid, let sid, let tid):
                guard let p = participant(for: pid), p.isAlive else { continue }
                let skills = skillsBySource[p.sourceID] ?? []
                guard let skill = skills.first(where: { $0.id == sid }) else {
                    continue
                }
                let target = tid.flatMap { participant(for: $0) }
                resolveSkill(skill, caster: p, target: target)

            case .retreat(let pid):
                guard let p = participant(for: pid), p.isAlive else { continue }
                p.currentHealth = 0 // removed from combat
                log("\(p.name) retreated from the fight.")
            }
        }
    }

    // MARK: - Private: Attack Resolution

    private func resolveAttack(from attacker: CombatParticipant,
                               to defender: CombatParticipant) {
        // Line-of-sight check
        guard map.hasLineOfSight(from: attacker.position,
                                 to: defender.position) else {
            log("\(attacker.name) cannot see \(defender.name). Attack blocked.")
            return
        }

        let coverBonus = map.coverBonus(at: defender.position,
                                        from: attacker.position)
        let result = DamageCalculation.resolve(
            attacker: attacker,
            defender: defender,
            coverBonus: coverBonus
        )

        if result.isHit {
            defender.currentHealth = max(0, defender.currentHealth - result.mitigatedDamage)
            let critLabel = result.isCrit ? " (CRIT)" : ""
            log("\(attacker.name) hit \(defender.name) for "
                + "\(Int(result.mitigatedDamage)) damage\(critLabel).")
            if !defender.isAlive {
                log("\(defender.name) has been eliminated.")
                map.removeOccupant(at: defender.position)
            }
        } else {
            log("\(attacker.name) missed \(defender.name).")
        }
    }

    // MARK: - Private: Skill Resolution

    private func resolveSkill(_ skill: Skill, caster: CombatParticipant,
                              target: CombatParticipant?) {
        guard (caster.cooldowns[skill.id] ?? 0) == 0 else {
            log("\(caster.name) tried to use \(skill.name) but it is on cooldown.")
            return
        }

        // Delegate to AbilitySystem for effect resolution
        let targets = determineTargets(for: skill, caster: caster, chosen: target)
        abilitySystem.activate(skill: skill, caster: caster, targets: targets,
                               map: map)

        caster.cooldowns[skill.id] = skill.cooldown
        log("\(caster.name) used \(skill.name).")
    }

    /// Expands a skill's `targetType` into the concrete set of participants.
    private func determineTargets(for skill: Skill,
                                  caster: CombatParticipant,
                                  chosen: CombatParticipant?) -> [CombatParticipant] {
        switch skill.targetType {
        case .single:
            if let t = chosen { return [t] }
            return []
        case .`self`:
            return [caster]
        case .allAllies:
            return participants.filter {
                $0.isAlive && $0.isPlayerControlled == caster.isPlayerControlled
            }
        case .allEnemies:
            return participants.filter {
                $0.isAlive && $0.isPlayerControlled != caster.isPlayerControlled
            }
        case .area:
            guard let center = chosen?.position ?? Optional(caster.position) else {
                return []
            }
            // Area = all units within 2-tile radius
            return participants.filter {
                $0.isAlive && $0.position.distance(to: center) <= 2
            }
        }
    }

    // MARK: - Private: Movement

    private func executeMove(_ participant: CombatParticipant,
                             to destination: GridPosition) {
        guard map.isPassable(at: destination) else { return }
        map.removeOccupant(at: participant.position)
        participant.position = destination
        map.placeOccupant(participant.id, at: destination)
    }

    // MARK: - Private: Outcome Evaluation

    private func evaluateOutcome() {
        let heroesAlive = participants.contains { $0.isPlayerControlled && $0.isAlive }
        let enemiesAlive = participants.contains { !$0.isPlayerControlled && $0.isAlive }

        if !enemiesAlive && heroesAlive {
            state = .victory
            log("Victory! All enemies eliminated.")
        } else if !heroesAlive {
            state = .defeat
            log("Defeat. All heroes have fallen.")
        }
    }

    // MARK: - Helpers

    private func participant(for id: UUID) -> CombatParticipant? {
        participants.first { $0.id == id }
    }

    private func log(_ message: String) {
        let entry = CombatLogEntry(timestamp: elapsedTime,
                                   message: message, involvedIDs: [])
        combatLog.append(entry)
    }
}
