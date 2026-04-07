// District.swift
// ProjectAshfall
//
// World-map regions the player explores. Each district has a biome,
// threat level, mission content, resource nodes, and discoverable survivors.

import Foundation

// MARK: - Biome Type

/// Environmental setting that determines visual theme, hazards, and available resources.
enum BiomeType: String, Codable, CaseIterable {
    case suburban
    case highway
    case industrial
    case hospital
    case military
    case flooded
    case underground
    case farmland
    case docks
    case mall

    var displayName: String {
        switch self {
        case .suburban:     return "Suburban"
        case .highway:      return "Highway"
        case .industrial:   return "Industrial"
        case .hospital:     return "Hospital"
        case .military:     return "Military Base"
        case .flooded:      return "Flooded Zone"
        case .underground:  return "Underground"
        case .farmland:     return "Farmland"
        case .docks:        return "Docks"
        case .mall:         return "Shopping Mall"
        }
    }

    /// Primary resource types found in this biome.
    var abundantResources: [ResourceType] {
        switch self {
        case .suburban:     return [.food, .scrap]
        case .highway:      return [.fuel, .scrap]
        case .industrial:   return [.scrap, .electronics]
        case .hospital:     return [.medicine, .bioSamples]
        case .military:     return [.militaryComponents, .fuel]
        case .flooded:      return [.water, .bioSamples]
        case .underground:  return [.electronics, .powerCells]
        case .farmland:     return [.food, .water]
        case .docks:        return [.fuel, .scrap]
        case .mall:         return [.food, .electronics]
        }
    }

    /// Dominant enemy family in this biome.
    var dominantEnemyFamily: EnemyFamily {
        switch self {
        case .suburban, .highway, .farmland, .flooded:
            return .infected
        case .industrial, .docks, .mall:
            return .raider
        case .military:
            return .militia
        case .hospital, .underground:
            return .rogueScientist
        }
    }
}

// MARK: - Threat Level

/// Coarse danger rating shown on the world map.
enum ThreatLevel: Int, Codable, CaseIterable, Comparable {
    case safe       = 0
    case low        = 1
    case moderate   = 2
    case high       = 3
    case severe     = 4
    case critical   = 5

    static func < (lhs: ThreatLevel, rhs: ThreatLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .safe:     return "Safe"
        case .low:      return "Low"
        case .moderate: return "Moderate"
        case .high:     return "High"
        case .severe:   return "Severe"
        case .critical: return "Critical"
        }
    }

    /// Recommended minimum squad power for this threat level.
    var recommendedPower: Double {
        Double(rawValue) * 200.0 + 100.0
    }
}

// MARK: - Resource Node

/// A harvestable resource deposit within a district.
struct ResourceNode: Codable, Identifiable, Hashable {
    let id: UUID
    let resourceType: ResourceType
    var remainingYield: Int
    let maxYield: Int
    let harvestTimeSeconds: TimeInterval
    var isDepleted: Bool { remainingYield <= 0 }

    init(
        id: UUID = UUID(),
        resourceType: ResourceType,
        maxYield: Int,
        harvestTimeSeconds: TimeInterval = 30
    ) {
        self.id = id
        self.resourceType = resourceType
        self.remainingYield = maxYield
        self.maxYield = maxYield
        self.harvestTimeSeconds = harvestTimeSeconds
    }

    /// Harvests up to `amount` units. Returns the actual amount harvested.
    @discardableResult
    mutating func harvest(amount: Int) -> Int {
        let actual = min(amount, remainingYield)
        remainingYield -= actual
        return actual
    }
}

// MARK: - Side Encounter

/// A minor random encounter within a district.
struct SideEncounter: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let description: String
    let enemyTypes: [EnemyType]
    let enemyCount: Int
    let enemyLevel: Int
    let rewards: [ResourceCost]
    var isCompleted: Bool

    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        enemyTypes: [EnemyType] = [],
        enemyCount: Int = 0,
        enemyLevel: Int = 1,
        rewards: [ResourceCost] = [],
        isCompleted: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.enemyTypes = enemyTypes
        self.enemyCount = enemyCount
        self.enemyLevel = enemyLevel
        self.rewards = rewards
        self.isCompleted = isCompleted
    }
}

// MARK: - Mini Boss

/// A district's named mini-boss encounter.
struct MiniBoss: Codable, Hashable {
    let name: String
    let enemyType: EnemyType
    let level: Int
    let bossPhases: [BossPhase]
    let rewards: [ResourceCost]
    var isDefeated: Bool

    init(
        name: String,
        enemyType: EnemyType,
        level: Int,
        bossPhases: [BossPhase] = [],
        rewards: [ResourceCost] = [],
        isDefeated: Bool = false
    ) {
        self.name = name
        self.enemyType = enemyType
        self.level = level
        self.bossPhases = bossPhases
        self.rewards = rewards
        self.isDefeated = isDefeated
    }
}

// MARK: - District

/// One explorable zone on the world map.
final class District: Codable, Identifiable {

    let id: UUID
    var name: String
    var biome: BiomeType
    var threatLevel: ThreatLevel
    var isCleared: Bool
    var fogRevealed: Bool
    var position: GridPosition

    /// The primary story mission in this district (nil if none).
    var mainMission: Mission?

    /// Random side encounters.
    var sideEncounters: [SideEncounter]

    /// Harvestable resource deposits.
    var resourceNodes: [ResourceNode]

    /// Number of rescuable survivors in this district.
    var survivorCount: Int

    /// Optional mini-boss guarding this district.
    var miniBoss: MiniBoss?

    /// IDs of story beats that trigger when this district is first entered.
    var storyTriggerIDs: [String]

    // MARK: Computed

    /// Whether all encounters and the mini-boss have been completed.
    var isFullyExplored: Bool {
        let encountersDone = sideEncounters.allSatisfy { $0.isCompleted }
        let bossDone = miniBoss?.isDefeated ?? true
        return isCleared && encountersDone && bossDone
    }

    /// Remaining harvestable resources across all nodes.
    var totalRemainingResources: Int {
        resourceNodes.reduce(0) { $0 + $1.remainingYield }
    }

    // MARK: Init

    init(
        id: UUID = UUID(),
        name: String,
        biome: BiomeType,
        threatLevel: ThreatLevel = .moderate,
        isCleared: Bool = false,
        fogRevealed: Bool = false,
        position: GridPosition = GridPosition(col: 0, row: 0),
        mainMission: Mission? = nil,
        sideEncounters: [SideEncounter] = [],
        resourceNodes: [ResourceNode] = [],
        survivorCount: Int = 0,
        miniBoss: MiniBoss? = nil,
        storyTriggerIDs: [String] = []
    ) {
        self.id = id
        self.name = name
        self.biome = biome
        self.threatLevel = threatLevel
        self.isCleared = isCleared
        self.fogRevealed = fogRevealed
        self.position = position
        self.mainMission = mainMission
        self.sideEncounters = sideEncounters
        self.resourceNodes = resourceNodes
        self.survivorCount = survivorCount
        self.miniBoss = miniBoss
        self.storyTriggerIDs = storyTriggerIDs
    }
}

// MARK: - Hashable / Equatable

extension District: Hashable {
    static func == (lhs: District, rhs: District) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - District Map

/// Manages the collection of all districts in the world.
final class DistrictMap: Codable {

    private(set) var districts: [UUID: District]

    init(districts: [District] = []) {
        self.districts = Dictionary(uniqueKeysWithValues: districts.map { ($0.id, $0) })
    }

    /// Returns all districts sorted by threat level ascending.
    func allDistrictsByThreat() -> [District] {
        districts.values.sorted { $0.threatLevel < $1.threatLevel }
    }

    /// Returns districts matching a given biome.
    func districts(biome: BiomeType) -> [District] {
        districts.values.filter { $0.biome == biome }
    }

    /// Returns districts that have been revealed but not yet cleared.
    func revealedUncleared() -> [District] {
        districts.values.filter { $0.fogRevealed && !$0.isCleared }
    }

    /// Returns the district at a given grid position, if any.
    func district(at position: GridPosition) -> District? {
        districts.values.first { $0.position == position }
    }

    /// Reveals fog of war for a district and its neighbours within `radius`.
    func revealArea(centeredOn districtID: UUID, radius: Int = 1) {
        guard let center = districts[districtID] else { return }
        for district in districts.values {
            if center.position.distance(to: district.position) <= radius {
                district.fogRevealed = true
            }
        }
    }

    /// Adds a district to the map.
    func addDistrict(_ district: District) {
        districts[district.id] = district
    }
}
