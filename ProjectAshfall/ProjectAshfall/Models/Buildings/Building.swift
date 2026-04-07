// Building.swift
// ProjectAshfall
//
// Structures the player constructs inside their base.

import Foundation

// MARK: - Building Type

/// Every constructable facility in the base.
enum BuildingType: String, Codable, CaseIterable {
    case commandCenter
    case barracks
    case workshop
    case infirmary
    case researchLab
    case farm
    case waterPurifier
    case fuelDepot
    case scrapYard
    case radarTower
    case heroQuarters
    case wall
    case turret
    case trap
    case garage

    /// Human-readable label for UI.
    var displayName: String {
        switch self {
        case .commandCenter:  return "Command Center"
        case .barracks:       return "Barracks"
        case .workshop:       return "Workshop"
        case .infirmary:      return "Infirmary"
        case .researchLab:    return "Research Lab"
        case .farm:           return "Farm"
        case .waterPurifier:  return "Water Purifier"
        case .fuelDepot:      return "Fuel Depot"
        case .scrapYard:      return "Scrap Yard"
        case .radarTower:     return "Radar Tower"
        case .heroQuarters:   return "Hero Quarters"
        case .wall:           return "Wall"
        case .turret:         return "Turret"
        case .trap:           return "Trap"
        case .garage:         return "Garage"
        }
    }

    /// Resources this building type produces when operational.
    var producedResourceType: ResourceType? {
        switch self {
        case .farm:           return .food
        case .waterPurifier:  return .water
        case .fuelDepot:      return .fuel
        case .scrapYard:      return .scrap
        case .workshop:       return .electronics
        case .infirmary:      return .medicine
        case .researchLab:    return .researchData
        default:              return nil
        }
    }

    /// Whether this building can be placed multiple times.
    var allowMultiple: Bool {
        switch self {
        case .commandCenter, .radarTower, .garage:
            return false
        default:
            return true
        }
    }

    /// Grid footprint size (columns x rows).
    var footprint: (cols: Int, rows: Int) {
        switch self {
        case .commandCenter:  return (3, 3)
        case .barracks, .researchLab, .heroQuarters, .garage:
            return (2, 2)
        case .wall, .trap:    return (1, 1)
        case .turret:         return (1, 1)
        default:              return (2, 1)
        }
    }

    /// Base construction time in seconds for level 1.
    var baseConstructionTime: TimeInterval {
        switch self {
        case .commandCenter:  return 300
        case .barracks:       return 180
        case .workshop:       return 150
        case .infirmary:      return 180
        case .researchLab:    return 240
        case .farm:           return 90
        case .waterPurifier:  return 120
        case .fuelDepot:      return 120
        case .scrapYard:      return 90
        case .radarTower:     return 200
        case .heroQuarters:   return 160
        case .wall:           return 30
        case .turret:         return 60
        case .trap:           return 45
        case .garage:         return 240
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

// MARK: - Upgrade Requirements

/// Requirements and costs to upgrade a building to a specific level.
struct UpgradeRequirement: Codable, Hashable {
    let targetLevel: Int
    let costs: [ResourceCost]
    let timeSeconds: TimeInterval
    /// Minimum command-center level required.
    let requiredCommandCenterLevel: Int
    /// Other buildings that must exist at a minimum level.
    let prerequisiteBuildings: [BuildingType: Int]

    init(
        targetLevel: Int,
        costs: [ResourceCost],
        timeSeconds: TimeInterval,
        requiredCommandCenterLevel: Int = 1,
        prerequisiteBuildings: [BuildingType: Int] = [:]
    ) {
        self.targetLevel = targetLevel
        self.costs = costs
        self.timeSeconds = timeSeconds
        self.requiredCommandCenterLevel = requiredCommandCenterLevel
        self.prerequisiteBuildings = prerequisiteBuildings
    }
}

// MARK: - Building

/// A placed base structure with level, production, and health.
final class Building: Codable, Identifiable {

    let id: UUID
    var type: BuildingType
    /// Current level, clamped to 1...10.
    var level: Int {
        didSet { level = min(max(level, 1), 10) }
    }
    var state: BuildingState
    var position: GridPosition
    var hitPoints: Double
    var maxHitPoints: Double

    /// Whether this building is currently being upgraded.
    var isUpgrading: Bool { state == .upgrading }

    /// Seconds remaining in current build / upgrade.
    var upgradeTimeRemaining: TimeInterval

    /// Per-tick production quantity (units of the building's produced resource).
    var productionRate: Int

    /// Cost to build this structure at level 1.
    var constructionCost: [ResourceCost]

    var isOperational: Bool { state == .operational }

    // MARK: Computed

    /// Health as a fraction 0...1.
    var healthFraction: Double {
        guard maxHitPoints > 0 else { return 0 }
        return hitPoints / maxHitPoints
    }

    /// Returns the upgrade requirements for the next level, or nil if max.
    var nextUpgradeRequirement: UpgradeRequirement? {
        guard level < 10 else { return nil }
        return Building.upgradeRequirements(for: type, toLevel: level + 1)
    }

    // MARK: Initializer

    init(
        id: UUID = UUID(),
        type: BuildingType,
        level: Int = 1,
        state: BuildingState = .underConstruction,
        position: GridPosition,
        hitPoints: Double = 100,
        maxHitPoints: Double = 100,
        upgradeTimeRemaining: TimeInterval = 0,
        productionRate: Int = 0,
        constructionCost: [ResourceCost] = []
    ) {
        self.id = id
        self.type = type
        self.level = min(max(level, 1), 10)
        self.state = state
        self.position = position
        self.hitPoints = hitPoints
        self.maxHitPoints = maxHitPoints
        self.upgradeTimeRemaining = upgradeTimeRemaining
        self.productionRate = productionRate
        self.constructionCost = constructionCost
    }

    // MARK: Methods

    /// Begins an upgrade if requirements are met. Returns true on success.
    @discardableResult
    func beginUpgrade(inventory: ResourceInventory) -> Bool {
        guard let req = nextUpgradeRequirement,
              inventory.canAfford(req.costs) else { return false }
        guard inventory.spend(req.costs) else { return false }
        state = .upgrading
        upgradeTimeRemaining = req.timeSeconds
        return true
    }

    /// Called each game tick to advance construction/upgrade timers.
    func tick(deltaTime: TimeInterval) {
        guard state == .underConstruction || state == .upgrading else { return }
        upgradeTimeRemaining = max(0, upgradeTimeRemaining - deltaTime)
        if upgradeTimeRemaining <= 0 {
            if state == .upgrading { level += 1 }
            state = .operational
            recalculateStats()
        }
    }

    /// Takes damage during a base attack. Transitions to damaged/destroyed.
    func takeDamage(_ amount: Double) {
        hitPoints = max(0, hitPoints - amount)
        if hitPoints <= 0 {
            state = .destroyed
        } else if healthFraction < 0.3 {
            state = .damaged
        }
    }

    /// Repairs the building by the given amount.
    func repair(_ amount: Double) {
        hitPoints = min(maxHitPoints, hitPoints + amount)
        if state == .damaged && hitPoints > maxHitPoints * 0.3 {
            state = .operational
        }
    }

    /// Recalculates derived stats after level-up.
    private func recalculateStats() {
        let levelMultiplier = 1.0 + Double(level - 1) * 0.15
        maxHitPoints = Building.baseHitPoints(for: type) * levelMultiplier
        hitPoints = maxHitPoints
        productionRate = Building.baseProductionRate(for: type) + (level - 1) * 2
    }

    // MARK: - Static Helpers

    /// Base hit points for a building type at level 1.
    static func baseHitPoints(for type: BuildingType) -> Double {
        switch type {
        case .commandCenter:  return 500
        case .barracks:       return 300
        case .workshop:       return 200
        case .infirmary:      return 250
        case .researchLab:    return 200
        case .farm:           return 150
        case .waterPurifier:  return 180
        case .fuelDepot:      return 200
        case .scrapYard:      return 180
        case .radarTower:     return 150
        case .heroQuarters:   return 250
        case .wall:           return 400
        case .turret:         return 200
        case .trap:           return 80
        case .garage:         return 300
        }
    }

    /// Base production rate for a building type at level 1.
    static func baseProductionRate(for type: BuildingType) -> Int {
        switch type {
        case .farm:           return 10
        case .waterPurifier:  return 8
        case .fuelDepot:      return 5
        case .scrapYard:      return 6
        case .workshop:       return 4
        case .infirmary:      return 3
        case .researchLab:    return 2
        default:              return 0
        }
    }

    /// Upgrade requirements for a specific building type and target level.
    static func upgradeRequirements(for type: BuildingType, toLevel level: Int) -> UpgradeRequirement {
        let scaleFactor = Double(level)
        let timeMultiplier = type.baseConstructionTime * scaleFactor * 0.8

        let baseCosts: [ResourceCost]
        switch type {
        case .commandCenter:
            baseCosts = [
                ResourceCost(.scrap, Int(80 * scaleFactor)),
                ResourceCost(.electronics, Int(40 * scaleFactor)),
                ResourceCost(.militaryComponents, Int(20 * scaleFactor))
            ]
        case .barracks, .heroQuarters:
            baseCosts = [
                ResourceCost(.scrap, Int(50 * scaleFactor)),
                ResourceCost(.electronics, Int(15 * scaleFactor))
            ]
        case .workshop, .scrapYard:
            baseCosts = [
                ResourceCost(.scrap, Int(60 * scaleFactor)),
                ResourceCost(.electronics, Int(20 * scaleFactor))
            ]
        case .infirmary:
            baseCosts = [
                ResourceCost(.scrap, Int(40 * scaleFactor)),
                ResourceCost(.medicine, Int(20 * scaleFactor))
            ]
        case .researchLab:
            baseCosts = [
                ResourceCost(.scrap, Int(50 * scaleFactor)),
                ResourceCost(.electronics, Int(30 * scaleFactor)),
                ResourceCost(.researchData, Int(10 * scaleFactor))
            ]
        case .farm, .waterPurifier, .fuelDepot:
            baseCosts = [
                ResourceCost(.scrap, Int(30 * scaleFactor)),
                ResourceCost(.electronics, Int(5 * scaleFactor))
            ]
        case .radarTower:
            baseCosts = [
                ResourceCost(.scrap, Int(40 * scaleFactor)),
                ResourceCost(.electronics, Int(25 * scaleFactor)),
                ResourceCost(.powerCells, Int(5 * scaleFactor))
            ]
        case .wall:
            baseCosts = [ResourceCost(.scrap, Int(20 * scaleFactor))]
        case .turret:
            baseCosts = [
                ResourceCost(.scrap, Int(35 * scaleFactor)),
                ResourceCost(.militaryComponents, Int(10 * scaleFactor))
            ]
        case .trap:
            baseCosts = [
                ResourceCost(.scrap, Int(15 * scaleFactor)),
                ResourceCost(.electronics, Int(5 * scaleFactor))
            ]
        case .garage:
            baseCosts = [
                ResourceCost(.scrap, Int(70 * scaleFactor)),
                ResourceCost(.fuel, Int(30 * scaleFactor)),
                ResourceCost(.electronics, Int(20 * scaleFactor))
            ]
        }

        let requiredCC = max(1, level / 2)

        return UpgradeRequirement(
            targetLevel: level,
            costs: baseCosts,
            timeSeconds: timeMultiplier,
            requiredCommandCenterLevel: requiredCC
        )
    }
}

// MARK: - Hashable / Equatable

extension Building: Hashable {
    static func == (lhs: Building, rhs: Building) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
