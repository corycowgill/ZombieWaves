// Building.swift
// ProjectAshfall
//
// Structures the player constructs inside their base.

import Foundation

// MARK: - Building Type

/// Every constructable facility in the base.
enum BuildingType: String, Codable, CaseIterable {
    case shelter          // increases survivor capacity
    case farm             // produces food
    case waterPurifier    // produces water
    case workshop         // produces scrap & crafting
    case medBay           // produces medicine, heals heroes
    case armory           // upgrades weapons
    case watchtower       // early warning, defense bonus
    case radarTower       // reveals fog of war
    case generator        // produces fuel / power
    case commandCenter    // unlocks advanced tech
    case wall             // perimeter defense
    case tradingPost      // faction trading
    case lab              // tech research
    case barracks         // hero recruitment speed
    case storehouse       // increases resource cap

    /// Resources this building type produces when operational.
    var producedResourceType: ResourceType? {
        switch self {
        case .farm:           return .food
        case .waterPurifier:  return .water
        case .workshop:       return .scrap
        case .medBay:         return .medicine
        case .generator:      return .fuel
        case .lab:            return .researchData
        default:              return nil
        }
    }
}

// MARK: - Building State

/// Visual / logical phase of a building's lifecycle.
enum BuildingState: String, Codable {
    case underConstruction
    case operational
    case upgrading
    case damaged
    case destroyed
}

// MARK: - Grid Position

/// Column/row on the base-building grid. Also reused for combat tiles.
struct GridPosition: Codable, Hashable {
    let col: Int
    let row: Int

    /// Manhattan distance to another position.
    func distance(to other: GridPosition) -> Int {
        abs(col - other.col) + abs(row - other.row)
    }
}

// MARK: - Building

/// A placed base structure with level, production, and health.
struct Building: Codable, Identifiable, Hashable {

    static func == (lhs: Building, rhs: Building) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    let id: UUID
    var type: BuildingType
    var level: Int
    var state: BuildingState
    var position: GridPosition
    var healthPoints: Double
    var maxHealthPoints: Double

    /// Seconds remaining in current build / upgrade.
    var buildTimeRemaining: TimeInterval
    /// Total seconds the current build / upgrade takes.
    var buildTimeTotal: TimeInterval

    /// Per-tick production quantity (units of the building's produced resource).
    var productionPerTick: Int

    /// Cost to upgrade to the next level.
    var upgradeCost: [ResourceCost]

    var isOperational: Bool { state == .operational }

    init(
        id: UUID = UUID(),
        type: BuildingType,
        level: Int = 1,
        state: BuildingState = .underConstruction,
        position: GridPosition,
        healthPoints: Double = 100,
        maxHealthPoints: Double = 100,
        buildTimeRemaining: TimeInterval = 60,
        buildTimeTotal: TimeInterval = 60,
        productionPerTick: Int = 0,
        upgradeCost: [ResourceCost] = []
    ) {
        self.id = id
        self.type = type
        self.level = level
        self.state = state
        self.position = position
        self.healthPoints = healthPoints
        self.maxHealthPoints = maxHealthPoints
        self.buildTimeRemaining = buildTimeRemaining
        self.buildTimeTotal = buildTimeTotal
        self.productionPerTick = productionPerTick
        self.upgradeCost = upgradeCost
    }
}
