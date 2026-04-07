// Mission.swift
// ProjectAshfall
//
// Defines missions the player undertakes -- story arcs, expeditions,
// base-defense waves, and resource-recovery runs.

import Foundation

// MARK: - Mission Type

/// Broad category of a mission that determines rules and win conditions.
enum MissionType: String, Codable, CaseIterable {
    /// Main storyline missions that advance the campaign.
    case story
    /// Open-ended exploration missions into the world map.
    case expedition
    /// Base-defense encounters with escalating enemy waves.
    case defense
    /// Resource-recovery runs to salvage specific materials.
    case recovery

    var displayName: String {
        switch self {
        case .story:      return "Story"
        case .expedition: return "Expedition"
        case .defense:    return "Defense"
        case .recovery:   return "Recovery"
        }
    }
}

// MARK: - Mission Difficulty

/// Difficulty tier that scales enemy stats, loot, and experience.
enum MissionDifficulty: String, Codable, CaseIterable, Comparable {
    case easy
    case normal
    case hard
    case elite
    case nightmare

    private var sortOrder: Int {
        switch self {
        case .easy:      return 0
        case .normal:    return 1
        case .hard:      return 2
        case .elite:     return 3
        case .nightmare: return 4
        }
    }

    static func < (lhs: MissionDifficulty, rhs: MissionDifficulty) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }

    /// Multiplier applied to enemy stats at this difficulty.
    var enemyStatMultiplier: Double {
        switch self {
        case .easy:      return 0.8
        case .normal:    return 1.0
        case .hard:      return 1.25
        case .elite:     return 1.6
        case .nightmare: return 2.0
        }
    }

    /// Multiplier applied to loot and XP rewards.
    var rewardMultiplier: Double {
        switch self {
        case .easy:      return 0.7
        case .normal:    return 1.0
        case .hard:      return 1.3
        case .elite:     return 1.7
        case .nightmare: return 2.5
        }
    }

    /// Minimum squad power recommended for this difficulty.
    var recommendedPower: Double {
        switch self {
        case .easy:      return 200
        case .normal:    return 400
        case .hard:      return 700
        case .elite:     return 1100
        case .nightmare: return 1600
        }
    }
}

// MARK: - Mission Objective

/// A single win/fail condition within a mission.
struct MissionObjective: Codable, Identifiable, Hashable {
    let id: UUID
    let description: String
    let targetCount: Int
    var currentCount: Int
    let isOptional: Bool

    /// Whether this objective has been satisfied.
    var isCompleted: Bool { currentCount >= targetCount }

    /// Progress fraction (0...1).
    var progress: Double {
        guard targetCount > 0 else { return 1.0 }
        return min(1.0, Double(currentCount) / Double(targetCount))
    }

    init(
        id: UUID = UUID(),
        description: String,
        targetCount: Int = 1,
        currentCount: Int = 0,
        isOptional: Bool = false
    ) {
        self.id = id
        self.description = description
        self.targetCount = targetCount
        self.currentCount = currentCount
        self.isOptional = isOptional
    }
}

// MARK: - Mission Reward

/// Rewards granted on mission completion.
struct MissionReward: Codable, Hashable {
    /// Resource payouts keyed by type.
    let resources: [ResourceType: Int]
    /// Experience points awarded to each participating hero.
    let experiencePoints: Int
    /// ID of a hero that becomes recruitable on completion.
    let heroUnlockID: String?
    /// ID of a blueprint unlocked on completion.
    let blueprintID: String?

    init(
        resources: [ResourceType: Int] = [:],
        experiencePoints: Int = 0,
        heroUnlockID: String? = nil,
        blueprintID: String? = nil
    ) {
        self.resources = resources
        self.experiencePoints = experiencePoints
        self.heroUnlockID = heroUnlockID
        self.blueprintID = blueprintID
    }

    /// Convenience: total resource units across all types.
    var totalResourceCount: Int {
        resources.values.reduce(0, +)
    }

    /// Returns a new reward with every resource amount scaled by the given multiplier.
    func scaled(by multiplier: Double) -> MissionReward {
        let scaledResources = resources.mapValues { Int(Double($0) * multiplier) }
        return MissionReward(
            resources: scaledResources,
            experiencePoints: Int(Double(experiencePoints) * multiplier),
            heroUnlockID: heroUnlockID,
            blueprintID: blueprintID
        )
    }
}

// MARK: - Mission Threat

/// Describes the hostile forces the player will face in a mission.
struct MissionThreat: Codable, Hashable {
    /// Enemy types and how many of each appear.
    let enemyTypes: [EnemyType: Int]
    /// Whether the mission culminates in a boss encounter.
    let hasBoss: Bool
    /// The specific boss enemy type, if applicable.
    let bossType: EnemyType?

    init(
        enemyTypes: [EnemyType: Int] = [:],
        hasBoss: Bool = false,
        bossType: EnemyType? = nil
    ) {
        self.enemyTypes = enemyTypes
        self.hasBoss = hasBoss
        self.bossType = bossType
    }

    /// Total number of non-boss enemies.
    var totalEnemyCount: Int {
        enemyTypes.values.reduce(0, +)
    }

    /// All distinct enemy families represented in the threat.
    var enemyFamilies: Set<EnemyFamily> {
        Set(enemyTypes.keys.map { $0.family })
    }
}

// MARK: - Mission

/// A complete mission definition including objectives, enemies, rewards, and setting.
struct Mission: Codable, Identifiable, Hashable {

    let id: UUID
    let name: String
    let description: String
    let type: MissionType
    let difficulty: MissionDifficulty

    /// Ordered objectives. Non-optional ones must all be completed to win.
    var objectives: [MissionObjective]

    /// Rewards granted on successful completion.
    let rewards: MissionReward

    /// Hostile forces deployed in this mission.
    let threats: MissionThreat

    /// The biome where this mission takes place.
    let biome: BiomeType

    /// Campaign story chapter identifier (nil for non-story missions).
    let storyChapterID: String?

    /// Whether this mission has been completed by the player.
    var isCompleted: Bool

    /// Whether the mission is available for the player to start.
    var isUnlocked: Bool

    /// Estimated time to complete the mission, in minutes.
    let estimatedMinutes: Int

    /// Active environmental hazards during the mission (e.g. "toxic_fog", "acid_rain").
    let environmentalHazards: [String]

    // MARK: Computed

    /// Whether all required (non-optional) objectives are complete.
    var allRequiredObjectivesComplete: Bool {
        objectives.filter { !$0.isOptional }.allSatisfy { $0.isCompleted }
    }

    /// Whether every objective including optional ones is complete.
    var isPerfectClear: Bool {
        objectives.allSatisfy { $0.isCompleted }
    }

    /// Overall progress across required objectives (0...1).
    var progress: Double {
        let required = objectives.filter { !$0.isOptional }
        guard !required.isEmpty else { return 1.0 }
        return required.reduce(0.0) { $0 + $1.progress } / Double(required.count)
    }

    // MARK: Init

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        type: MissionType,
        difficulty: MissionDifficulty = .normal,
        objectives: [MissionObjective] = [],
        rewards: MissionReward = MissionReward(),
        threats: MissionThreat = MissionThreat(),
        biome: BiomeType = .suburban,
        storyChapterID: String? = nil,
        isCompleted: Bool = false,
        isUnlocked: Bool = false,
        estimatedMinutes: Int = 10,
        environmentalHazards: [String] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.type = type
        self.difficulty = difficulty
        self.objectives = objectives
        self.rewards = rewards
        self.threats = threats
        self.biome = biome
        self.storyChapterID = storyChapterID
        self.isCompleted = isCompleted
        self.isUnlocked = isUnlocked
        self.estimatedMinutes = estimatedMinutes
        self.environmentalHazards = environmentalHazards
    }

    // MARK: Mutation

    /// Advances the first incomplete objective whose description contains `keyword`.
    /// Returns `true` if that objective became complete as a result.
    @discardableResult
    mutating func advanceObjective(matching keyword: String, by amount: Int = 1) -> Bool {
        guard let index = objectives.firstIndex(where: {
            $0.description.localizedCaseInsensitiveContains(keyword) && !$0.isCompleted
        }) else {
            return false
        }
        let wasDone = objectives[index].isCompleted
        objectives[index].currentCount = min(
            objectives[index].targetCount,
            objectives[index].currentCount + amount
        )
        return !wasDone && objectives[index].isCompleted
    }

    /// Advances the first incomplete non-optional objective by `amount`.
    /// Returns `true` if that objective became complete as a result.
    @discardableResult
    mutating func advanceNextObjective(by amount: Int = 1) -> Bool {
        guard let index = objectives.firstIndex(where: { !$0.isOptional && !$0.isCompleted }) else {
            return false
        }
        let wasDone = objectives[index].isCompleted
        objectives[index].currentCount = min(
            objectives[index].targetCount,
            objectives[index].currentCount + amount
        )
        return !wasDone && objectives[index].isCompleted
    }
}

// MARK: - Mission Factory

/// Generates pre-configured missions with appropriate difficulty scaling.
final class MissionFactory {

    // MARK: - Story Missions

    /// Generates a story mission for the given chapter, biome, and difficulty.
    static func createStoryMission(
        chapterID: String,
        name: String,
        description: String,
        biome: BiomeType,
        difficulty: MissionDifficulty
    ) -> Mission {
        let level = difficultyLevel(for: difficulty)

        let objectives = [
            MissionObjective(
                description: "Complete the primary objective",
                targetCount: 1
            ),
            MissionObjective(
                description: "Eliminate hostile forces",
                targetCount: 8 + level * 2
            ),
            MissionObjective(
                description: "Discover hidden intel",
                targetCount: 1,
                isOptional: true
            )
        ]

        let threats = buildThreats(
            for: biome,
            difficulty: difficulty,
            includeBoss: difficulty >= .hard
        )

        let rewards = MissionReward(
            resources: storyRewards(biome: biome, difficulty: difficulty),
            experiencePoints: 100 + level * 50,
            heroUnlockID: nil,
            blueprintID: nil
        ).scaled(by: difficulty.rewardMultiplier)

        return Mission(
            name: name,
            description: description,
            type: .story,
            difficulty: difficulty,
            objectives: objectives,
            rewards: rewards,
            threats: threats,
            biome: biome,
            storyChapterID: chapterID,
            isUnlocked: false,
            estimatedMinutes: 15 + level * 5,
            environmentalHazards: hazards(for: biome)
        )
    }

    // MARK: - Expeditions

    /// Generates an open-world expedition for the given biome and difficulty.
    static func createExpedition(
        biome: BiomeType,
        difficulty: MissionDifficulty
    ) -> Mission {
        let level = difficultyLevel(for: difficulty)

        let objectives = [
            MissionObjective(
                description: "Explore the region",
                targetCount: 3 + level
            ),
            MissionObjective(
                description: "Collect resource caches",
                targetCount: 2 + level,
                isOptional: false
            ),
            MissionObjective(
                description: "Rescue stranded survivors",
                targetCount: 1 + level / 2,
                isOptional: true
            )
        ]

        let threats = buildThreats(
            for: biome,
            difficulty: difficulty,
            includeBoss: false
        )

        let abundant = biome.abundantResources
        var resourceRewards: [ResourceType: Int] = [:]
        for res in abundant {
            resourceRewards[res] = (15 + level * 10)
        }

        let rewards = MissionReward(
            resources: resourceRewards,
            experiencePoints: 60 + level * 30
        ).scaled(by: difficulty.rewardMultiplier)

        return Mission(
            name: "\(biome.displayName) Expedition",
            description: "Scout the \(biome.displayName.lowercased()) for supplies and survivors.",
            type: .expedition,
            difficulty: difficulty,
            objectives: objectives,
            rewards: rewards,
            threats: threats,
            biome: biome,
            isUnlocked: true,
            estimatedMinutes: 10 + level * 3,
            environmentalHazards: hazards(for: biome)
        )
    }

    // MARK: - Defense Waves

    /// Generates a base-defense mission with escalating enemy waves.
    static func createDefenseWave(
        waveName: String,
        difficulty: MissionDifficulty,
        waveCount: Int = 3
    ) -> Mission {
        let level = difficultyLevel(for: difficulty)
        let totalEnemies = waveCount * (5 + level * 3)

        let objectives = [
            MissionObjective(
                description: "Survive all \(waveCount) waves",
                targetCount: waveCount
            ),
            MissionObjective(
                description: "Eliminate attackers",
                targetCount: totalEnemies
            ),
            MissionObjective(
                description: "Prevent critical structure damage",
                targetCount: 1,
                isOptional: true
            )
        ]

        // Defense waves draw from multiple enemy families.
        var enemyCounts: [EnemyType: Int] = [:]
        let infectedTypes: [EnemyType] = [.shambler, .runner, .spitter]
        for enemyType in infectedTypes {
            enemyCounts[enemyType] = (3 + level * 2)
        }
        if difficulty >= .hard {
            enemyCounts[.bruiser] = (1 + level)
        }

        let hasBoss = difficulty >= .elite
        let bossType: EnemyType? = hasBoss ? .bruiser : nil

        let threats = MissionThreat(
            enemyTypes: enemyCounts,
            hasBoss: hasBoss,
            bossType: bossType
        )

        let rewards = MissionReward(
            resources: [
                .scrap: 20 + level * 15,
                .militaryComponents: 5 + level * 5,
                .fuel: 10 + level * 5
            ],
            experiencePoints: 80 + level * 40
        ).scaled(by: difficulty.rewardMultiplier)

        return Mission(
            name: waveName,
            description: "Defend the base against \(waveCount) incoming waves of hostiles.",
            type: .defense,
            difficulty: difficulty,
            objectives: objectives,
            rewards: rewards,
            threats: threats,
            biome: .suburban,
            isUnlocked: true,
            estimatedMinutes: 8 + waveCount * 3 + level * 2,
            environmentalHazards: []
        )
    }

    // MARK: - Recovery Operations

    /// Generates a resource-recovery mission targeting specific materials.
    static func createRecoveryOp(
        targetResources: [ResourceType],
        biome: BiomeType,
        difficulty: MissionDifficulty
    ) -> Mission {
        let level = difficultyLevel(for: difficulty)

        let objectives = [
            MissionObjective(
                description: "Secure the supply zone",
                targetCount: 1
            ),
            MissionObjective(
                description: "Collect target resources",
                targetCount: 3 + level * 2
            ),
            MissionObjective(
                description: "Reach extraction point",
                targetCount: 1
            ),
            MissionObjective(
                description: "Eliminate all hostiles for bonus loot",
                targetCount: 5 + level * 3,
                isOptional: true
            )
        ]

        let threats = buildThreats(
            for: biome,
            difficulty: difficulty,
            includeBoss: false
        )

        var resourceRewards: [ResourceType: Int] = [:]
        for res in targetResources {
            resourceRewards[res] = (20 + level * 12)
        }
        // Bonus scrap is always present in recovery ops.
        resourceRewards[.scrap] = (resourceRewards[.scrap] ?? 0) + 10 + level * 5

        let rewards = MissionReward(
            resources: resourceRewards,
            experiencePoints: 50 + level * 25
        ).scaled(by: difficulty.rewardMultiplier)

        let resourceNames = targetResources.map { $0.displayName }.joined(separator: ", ")

        return Mission(
            name: "\(biome.displayName) Recovery",
            description: "Recover \(resourceNames) from the \(biome.displayName.lowercased()).",
            type: .recovery,
            difficulty: difficulty,
            objectives: objectives,
            rewards: rewards,
            threats: threats,
            biome: biome,
            isUnlocked: true,
            estimatedMinutes: 8 + level * 3,
            environmentalHazards: hazards(for: biome)
        )
    }

    // MARK: - Internal Helpers

    /// Maps difficulty to an integer level for scaling formulas.
    private static func difficultyLevel(for difficulty: MissionDifficulty) -> Int {
        switch difficulty {
        case .easy:      return 1
        case .normal:    return 2
        case .hard:      return 3
        case .elite:     return 4
        case .nightmare: return 5
        }
    }

    /// Builds a threat profile appropriate for the given biome and difficulty.
    private static func buildThreats(
        for biome: BiomeType,
        difficulty: MissionDifficulty,
        includeBoss: Bool
    ) -> MissionThreat {
        let level = difficultyLevel(for: difficulty)
        let family = biome.dominantEnemyFamily
        let types = enemyTypesForFamily(family)

        var counts: [EnemyType: Int] = [:]
        for (index, enemyType) in types.enumerated() {
            // Earlier types in the list are more common.
            let base = max(1, 6 - index * 2)
            counts[enemyType] = base + level * 2
        }

        let bossType: EnemyType? = includeBoss ? bossForFamily(family) : nil

        return MissionThreat(
            enemyTypes: counts,
            hasBoss: includeBoss,
            bossType: bossType
        )
    }

    /// Returns enemy types belonging to a given family, ordered by ascending threat.
    private static func enemyTypesForFamily(_ family: EnemyFamily) -> [EnemyType] {
        switch family {
        case .infected:
            return [.shambler, .runner, .spitter, .screecher, .burrower, .bruiser]
        case .raider:
            return [.raiderScout, .raiderBrute]
        case .militia:
            return [.militiaSoldier, .militiaSniper]
        case .rogueScientist:
            return [.rogueLabTech, .rogueMutantHandler]
        }
    }

    /// Returns the default boss type for a given enemy family.
    private static func bossForFamily(_ family: EnemyFamily) -> EnemyType {
        switch family {
        case .infected:       return .bruiser
        case .raider:         return .raiderBrute
        case .militia:        return .militiaSniper
        case .rogueScientist: return .rogueMutantHandler
        }
    }

    /// Builds default resource rewards for story missions based on biome.
    private static func storyRewards(biome: BiomeType, difficulty: MissionDifficulty) -> [ResourceType: Int] {
        let level = difficultyLevel(for: difficulty)
        var rewards: [ResourceType: Int] = [:]
        for res in biome.abundantResources {
            rewards[res] = 20 + level * 10
        }
        // Story missions always grant some research data.
        rewards[.researchData] = 5 + level * 3
        return rewards
    }

    /// Returns environmental hazards typical of a biome.
    private static func hazards(for biome: BiomeType) -> [String] {
        switch biome {
        case .flooded:      return ["rising_water", "toxic_runoff"]
        case .industrial:   return ["chemical_spill", "unstable_structure"]
        case .underground:  return ["cave_in_risk", "low_visibility"]
        case .hospital:     return ["biohazard_zone", "quarantine_lockdown"]
        case .military:     return ["minefield", "automated_turrets"]
        case .highway:      return ["vehicle_wreckage", "exposed_terrain"]
        case .docks:        return ["slippery_surfaces", "high_winds"]
        case .farmland:     return ["open_sightlines", "brush_fire"]
        case .mall:         return ["collapsing_floors", "tight_corridors"]
        case .suburban:     return []
        }
    }
}
