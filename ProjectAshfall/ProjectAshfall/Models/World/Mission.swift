// Mission.swift
// ProjectAshfall
//
// Defines missions the player undertakes — story arcs, expeditions,
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
    let type: ObjectiveType
    let targetCount: Int
    var currentCount: Int
    let isOptional: Bool

    var isComplete: Bool { currentCount >= targetCount }
    var progress: Double {
        guard targetCount > 0 else { return 1.0 }
        return min(1.0, Double(currentCount) / Double(targetCount))
    }

    init(
        id: UUID = UUID(),
        description: String,
        type: ObjectiveType,
        targetCount: Int = 1,
        currentCount: Int = 0,
        isOptional: Bool = false
    ) {
        self.id = id
        self.description = description
        self.type = type
        self.targetCount = targetCount
        self.currentCount = currentCount
        self.isOptional = isOptional
    }
}

/// Kind of objective for gameplay-system resolution.
enum ObjectiveType: String, Codable, CaseIterable {
    case eliminateAll
    case eliminateTarget
    case survive
    case collectResource
    case rescueSurvivors
    case reachExtraction
    case defendBuilding
    case escortNPC
}

// MARK: - Mission Reward

/// Rewards granted on mission completion.
struct MissionReward: Codable, Hashable {
    let resources: [ResourceCost]
    let experiencePerHero: Double
    let unlockedHeroID: UUID?
    let unlockedTechID: String?
    let storyUnlockID: String?

    init(
        resources: [ResourceCost] = [],
        experiencePerHero: Double = 0,
        unlockedHeroID: UUID? = nil,
        unlockedTechID: String? = nil,
        storyUnlockID: String? = nil
    ) {
        self.resources = resources
        self.experiencePerHero = experiencePerHero
        self.unlockedHeroID = unlockedHeroID
        self.unlockedTechID = unlockedTechID
        self.storyUnlockID = storyUnlockID
    }
}

// MARK: - Mission Enemy Group

/// A predefined group of enemies placed in the mission map.
struct MissionEnemyGroup: Codable, Hashable {
    let enemyType: EnemyType
    let count: Int
    let level: Int
    let position: GridPosition?

    init(enemyType: EnemyType, count: Int, level: Int = 1, position: GridPosition? = nil) {
        self.enemyType = enemyType
        self.count = count
        self.level = level
        self.position = position
    }
}

// MARK: - Map Layout

/// Lightweight description of the combat map for a mission.
struct MissionMapLayout: Codable, Hashable {
    let width: Int
    let height: Int
    let spawnPoints: [GridPosition]
    let extractionPoint: GridPosition?
    let environmentHazards: [String]

    init(
        width: Int = 12,
        height: Int = 8,
        spawnPoints: [GridPosition] = [],
        extractionPoint: GridPosition? = nil,
        environmentHazards: [String] = []
    ) {
        self.width = width
        self.height = height
        self.spawnPoints = spawnPoints
        self.extractionPoint = extractionPoint
        self.environmentHazards = environmentHazards
    }
}

// MARK: - Mission

/// A complete mission definition including objectives, enemies, rewards, and layout.
struct Mission: Codable, Identifiable, Hashable {

    let id: UUID
    let name: String
    let description: String
    let type: MissionType
    let difficulty: MissionDifficulty

    /// Ordered objectives. Non-optional ones must all be complete to win.
    var objectives: [MissionObjective]

    /// Rewards granted on successful completion.
    let rewards: MissionReward

    /// Enemy groups placed in the mission.
    let enemies: [MissionEnemyGroup]

    /// Combat map layout.
    let mapLayout: MissionMapLayout

    /// Time limit in seconds. Zero means unlimited.
    let timeLimit: TimeInterval

    /// Narrative text shown before the mission starts.
    let storyBeat: String?

    /// Whether this mission has been completed by the player.
    var isCompleted: Bool

    /// Act and chapter tag for campaign ordering (e.g. "1-3").
    let campaignTag: String?

    // MARK: Computed

    /// Whether all required objectives are complete.
    var allRequiredObjectivesComplete: Bool {
        objectives.filter { !$0.isOptional }.allSatisfy { $0.isComplete }
    }

    /// Whether all objectives (including optional) are complete.
    var isPerfectClear: Bool {
        objectives.allSatisfy { $0.isComplete }
    }

    /// Overall progress across required objectives (0...1).
    var progress: Double {
        let required = objectives.filter { !$0.isOptional }
        guard !required.isEmpty else { return 1.0 }
        return required.reduce(0.0) { $0 + $1.progress } / Double(required.count)
    }

    /// Whether this mission has a time constraint.
    var isTimed: Bool { timeLimit > 0 }

    // MARK: Init

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        type: MissionType,
        difficulty: MissionDifficulty = .normal,
        objectives: [MissionObjective] = [],
        rewards: MissionReward = MissionReward(),
        enemies: [MissionEnemyGroup] = [],
        mapLayout: MissionMapLayout = MissionMapLayout(),
        timeLimit: TimeInterval = 0,
        storyBeat: String? = nil,
        isCompleted: Bool = false,
        campaignTag: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.type = type
        self.difficulty = difficulty
        self.objectives = objectives
        self.rewards = rewards
        self.enemies = enemies
        self.mapLayout = mapLayout
        self.timeLimit = timeLimit
        self.storyBeat = storyBeat
        self.isCompleted = isCompleted
        self.campaignTag = campaignTag
    }

    // MARK: Mutation

    /// Updates progress on an objective by type. Returns true if the objective completed.
    @discardableResult
    mutating func advanceObjective(type: ObjectiveType, by amount: Int = 1) -> Bool {
        guard let index = objectives.firstIndex(where: { $0.type == type && !$0.isComplete }) else {
            return false
        }
        let wasDone = objectives[index].isComplete
        objectives[index].currentCount = min(
            objectives[index].targetCount,
            objectives[index].currentCount + amount
        )
        return !wasDone && objectives[index].isComplete
    }
}
