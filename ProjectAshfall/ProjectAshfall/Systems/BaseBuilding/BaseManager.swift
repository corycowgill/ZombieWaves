// BaseManager.swift
// ProjectAshfall
//
// Manages the player's home base: building placement, upgrades, resource
// production ticks, and random base events. The base grid is a fixed-size
// 2D array; buildings occupy single cells (extend later for multi-tile).

import Foundation

// MARK: - Base Event

/// Random events that can strike the player's base between missions.
enum BaseEvent: String, Codable, CaseIterable {
    case raiderAttack
    case survivorArrival
    case supplyDrop
    case diseaseOutbreak
    case structuralFailure
    case tradeCaravan
    case moraleBoost

    /// Narrative description shown in the event dialog.
    var description: String {
        switch self {
        case .raiderAttack:       return "Raiders are approaching the perimeter!"
        case .survivorArrival:    return "A group of survivors has arrived seeking shelter."
        case .supplyDrop:         return "A supply crate was spotted falling nearby."
        case .diseaseOutbreak:    return "An illness is spreading through the camp."
        case .structuralFailure:  return "Part of the base wall has collapsed."
        case .tradeCaravan:       return "A trade caravan has set up outside the gates."
        case .moraleBoost:        return "Survivors found something to celebrate."
        }
    }
}

// MARK: - Base Event Result

/// Outcome after the player resolves (or ignores) a base event.
struct BaseEventResult {
    let event: BaseEvent
    let resourceChanges: [ResourceCost]
    let buildingDamage: [UUID: Double]
    let message: String
}

// MARK: - Adjacency Bonus

/// Describes a bonus granted when two building types are placed next to
/// each other on the grid.
struct AdjacencyBonus {
    let neighborType: BuildingType
    let productionMultiplier: Double // 1.0 = no bonus

    static let bonusTable: [BuildingType: [AdjacencyBonus]] = [
        .farm:          [AdjacencyBonus(neighborType: .waterPurifier, productionMultiplier: 1.20)],
        .workshop:      [AdjacencyBonus(neighborType: .storehouse, productionMultiplier: 1.15)],
        .medBay:        [AdjacencyBonus(neighborType: .lab, productionMultiplier: 1.25)],
        .generator:     [AdjacencyBonus(neighborType: .commandCenter, productionMultiplier: 1.10)],
        .barracks:      [AdjacencyBonus(neighborType: .armory, productionMultiplier: 1.20)],
        .watchtower:    [AdjacencyBonus(neighborType: .wall, productionMultiplier: 1.15)],
        .lab:           [AdjacencyBonus(neighborType: .medBay, productionMultiplier: 1.20)],
    ]
}

// MARK: - Upgrade Queue Entry

/// A pending building upgrade waiting for its timer to expire.
struct UpgradeQueueEntry: Identifiable {
    let id = UUID()
    let buildingID: UUID
    let targetLevel: Int
    var timeRemaining: TimeInterval
    let timeTotal: TimeInterval
}

// MARK: - Base Manager

/// Central controller for the player's base. Owns the building grid,
/// processes production ticks, handles placement validation, and resolves
/// random events.
final class BaseManager {

    // MARK: Properties

    /// All buildings currently placed in the base.
    private(set) var buildings: [Building] = []

    /// Grid tracking which building occupies each cell. `nil` = empty.
    private(set) var buildingGrid: [[UUID?]]

    /// Reference to the shared resource inventory.
    let resources: ResourceInventory

    /// Queued upgrades in progress.
    private(set) var upgradeQueue: [UpgradeQueueEntry] = []

    /// Maximum number of concurrent upgrades (increases with Command Center level).
    var maxConcurrentUpgrades: Int {
        let ccLevel = buildings.first(where: { $0.type == .commandCenter })?.level ?? 0
        return 1 + ccLevel
    }

    let gridWidth: Int
    let gridHeight: Int

    /// Seconds between production ticks.
    private let productionTickInterval: TimeInterval = 60.0
    private var tickAccumulator: TimeInterval = 0

    // MARK: Init

    init(gridWidth: Int = 12, gridHeight: Int = 12,
         resources: ResourceInventory = ResourceInventory()) {
        self.gridWidth = gridWidth
        self.gridHeight = gridHeight
        self.resources = resources
        self.buildingGrid = Array(
            repeating: Array(repeating: nil as UUID?, count: gridWidth),
            count: gridHeight
        )
    }

    // MARK: - Building Placement

    /// Attempts to place a new building. Returns the created `Building` on
    /// success, or `nil` if placement is invalid or unaffordable.
    @discardableResult
    func placeBuilding(type: BuildingType, at position: GridPosition,
                       cost: [ResourceCost]) -> Building? {
        guard isValidPlacement(type: type, at: position) else { return nil }
        guard resources.spend(cost) else { return nil }

        let buildTime = baseBuildTime(for: type)
        var building = Building(
            type: type,
            level: 1,
            state: .underConstruction,
            position: position,
            healthPoints: baseHealth(for: type),
            maxHealthPoints: baseHealth(for: type),
            buildTimeRemaining: buildTime,
            buildTimeTotal: buildTime,
            productionPerTick: baseProduction(for: type)
        )
        building.upgradeCost = upgradeCost(for: type, level: 2)

        buildings.append(building)
        buildingGrid[position.row][position.col] = building.id
        return building
    }

    /// Validates that a building can be placed at the given position.
    func isValidPlacement(type: BuildingType, at position: GridPosition) -> Bool {
        // Bounds check
        guard position.col >= 0, position.col < gridWidth,
              position.row >= 0, position.row < gridHeight else {
            return false
        }
        // Cell must be empty
        guard buildingGrid[position.row][position.col] == nil else {
            return false
        }
        // Only one Command Center allowed
        if type == .commandCenter,
           buildings.contains(where: { $0.type == .commandCenter }) {
            return false
        }
        return true
    }

    // MARK: - Upgrade

    /// Queues an upgrade for a building. Returns `true` on success.
    @discardableResult
    func upgradeBuilding(id: UUID) -> Bool {
        guard var building = buildings.first(where: { $0.id == id }) else {
            return false
        }
        guard building.state == .operational else { return false }
        guard upgradeQueue.count < maxConcurrentUpgrades else { return false }
        guard resources.spend(building.upgradeCost) else { return false }

        let nextLevel = building.level + 1
        let time = baseBuildTime(for: building.type) * Double(nextLevel)
        // Cap upgrade time to 30 minutes maximum
        let cappedTime = min(time, 1800.0)

        building.state = .upgrading
        building.buildTimeRemaining = cappedTime
        building.buildTimeTotal = cappedTime
        updateBuilding(building)

        let entry = UpgradeQueueEntry(
            buildingID: id, targetLevel: nextLevel,
            timeRemaining: cappedTime, timeTotal: cappedTime
        )
        upgradeQueue.append(entry)
        return true
    }

    /// Demolishes a building, returning a fraction of its original cost.
    @discardableResult
    func demolishBuilding(id: UUID) -> Bool {
        guard let index = buildings.firstIndex(where: { $0.id == id }) else {
            return false
        }
        let building = buildings[index]

        // Refund 50 % of level-1 cost
        let refund = upgradeCost(for: building.type, level: 1)
            .map { ResourceCost($0.type, $0.amount / 2) }
        for r in refund {
            resources.add(r.type, quantity: r.amount)
        }

        buildingGrid[building.position.row][building.position.col] = nil
        buildings.remove(at: index)
        upgradeQueue.removeAll { $0.buildingID == id }
        return true
    }

    // MARK: - Resource Collection

    /// Manually collects accumulated resources from all operational producers.
    /// In practice called by the UI "collect" button or automatically via
    /// `processProductionTick`.
    func collectResources() -> [ResourceCost] {
        var collected: [ResourceCost] = []
        for building in buildings where building.isOperational {
            guard let resType = building.type.producedResourceType else { continue }
            let amount = effectiveProduction(for: building)
            guard amount > 0 else { continue }
            resources.add(resType, quantity: amount)
            collected.append(ResourceCost(resType, amount))
        }
        return collected
    }

    // MARK: - Production Tick

    /// Called from the game loop. Accumulates time and fires production ticks,
    /// construction completions, and upgrade timers.
    func update(deltaTime dt: TimeInterval) {
        tickAccumulator += dt

        // Production ticks
        while tickAccumulator >= productionTickInterval {
            tickAccumulator -= productionTickInterval
            _ = collectResources()
        }

        // Construction / upgrade timers
        for i in buildings.indices {
            guard buildings[i].state == .underConstruction
               || buildings[i].state == .upgrading else { continue }

            buildings[i].buildTimeRemaining -= dt

            if buildings[i].buildTimeRemaining <= 0 {
                buildings[i].buildTimeRemaining = 0

                if buildings[i].state == .underConstruction {
                    buildings[i].state = .operational
                } else if buildings[i].state == .upgrading {
                    completeUpgrade(for: buildings[i].id)
                }
            }
        }

        // Tick the upgrade queue timers in sync
        for i in upgradeQueue.indices {
            upgradeQueue[i].timeRemaining -= dt
        }
        upgradeQueue.removeAll { $0.timeRemaining <= 0 }
    }

    // MARK: - Base Events

    /// Generates a random base event weighted by current game state.
    func generateRandomEvent() -> BaseEvent {
        let hasWatchtower = buildings.contains {
            $0.type == .watchtower && $0.isOperational
        }
        // Watchtower reduces raid chance
        var pool: [BaseEvent] = BaseEvent.allCases
        if hasWatchtower {
            pool = pool.filter { $0 != .raiderAttack }
            pool.append(.supplyDrop) // slightly higher supply chance
        }
        return pool.randomElement() ?? .survivorArrival
    }

    /// Resolves a base event, applying resource and building changes.
    func resolveBaseEvent(_ event: BaseEvent) -> BaseEventResult {
        var resourceChanges: [ResourceCost] = []
        var buildingDamage: [UUID: Double] = [:]
        var message = event.description

        switch event {
        case .raiderAttack:
            // Damage outermost buildings, lose some resources
            let wallCount = buildings.filter { $0.type == .wall && $0.isOperational }.count
            let mitigationFactor = max(0.2, 1.0 - Double(wallCount) * 0.1)
            let foodLoss = Int(20.0 * mitigationFactor)
            let scrapLoss = Int(15.0 * mitigationFactor)
            resources.spend(.food, quantity: foodLoss)
            resources.spend(.scrap, quantity: scrapLoss)
            resourceChanges = [ResourceCost(.food, -foodLoss),
                               ResourceCost(.scrap, -scrapLoss)]

            // Damage a random building
            if let target = buildings.filter({ $0.isOperational }).randomElement() {
                let dmg = 25.0 * mitigationFactor
                buildingDamage[target.id] = dmg
                applyDamageToBuilding(target.id, amount: dmg)
            }
            message += " Lost \(foodLoss) food and \(scrapLoss) scrap."

        case .survivorArrival:
            message += " +1 survivor capacity if shelter is operational."

        case .supplyDrop:
            let food = Int.random(in: 15...30)
            let scrap = Int.random(in: 10...20)
            resources.add(.food, quantity: food)
            resources.add(.scrap, quantity: scrap)
            resourceChanges = [ResourceCost(.food, food),
                               ResourceCost(.scrap, scrap)]
            message += " Received \(food) food and \(scrap) scrap."

        case .diseaseOutbreak:
            let medicineCost = 10
            if resources.spend(.medicine, quantity: medicineCost) {
                message += " Spent \(medicineCost) medicine to contain the outbreak."
                resourceChanges = [ResourceCost(.medicine, -medicineCost)]
            } else {
                message += " Not enough medicine! Morale will drop."
            }

        case .structuralFailure:
            if let target = buildings.filter({ $0.isOperational }).randomElement() {
                let dmg = 40.0
                buildingDamage[target.id] = dmg
                applyDamageToBuilding(target.id, amount: dmg)
                message += " \(target.type.rawValue) took \(Int(dmg)) damage."
            }

        case .tradeCaravan:
            message += " Visit the Trading Post to barter resources."

        case .moraleBoost:
            message += " Survivors gain a temporary morale boost."
        }

        return BaseEventResult(event: event, resourceChanges: resourceChanges,
                               buildingDamage: buildingDamage, message: message)
    }

    // MARK: - Queries

    /// Returns all buildings adjacent to the given position.
    func adjacentBuildings(to position: GridPosition) -> [Building] {
        let neighbors = [
            GridPosition(col: position.col - 1, row: position.row),
            GridPosition(col: position.col + 1, row: position.row),
            GridPosition(col: position.col, row: position.row - 1),
            GridPosition(col: position.col, row: position.row + 1)
        ]
        return neighbors.compactMap { pos -> Building? in
            guard pos.col >= 0, pos.col < gridWidth,
                  pos.row >= 0, pos.row < gridHeight,
                  let id = buildingGrid[pos.row][pos.col] else { return nil }
            return buildings.first { $0.id == id }
        }
    }

    /// Total defense rating from walls and watchtowers (used by event system).
    var baseDefenseRating: Double {
        let wallHP = buildings
            .filter { $0.type == .wall && $0.isOperational }
            .reduce(0.0) { $0 + $1.healthPoints }
        let towerBonus = Double(buildings.filter {
            $0.type == .watchtower && $0.isOperational
        }.count) * 20.0
        return wallHP + towerBonus
    }

    // MARK: - Private Helpers

    private func effectiveProduction(for building: Building) -> Int {
        var base = building.productionPerTick
        // Adjacency bonuses
        let adjacent = adjacentBuildings(to: building.position)
        if let bonuses = AdjacencyBonus.bonusTable[building.type] {
            for bonus in bonuses {
                if adjacent.contains(where: { $0.type == bonus.neighborType
                                              && $0.isOperational }) {
                    base = Int(Double(base) * bonus.productionMultiplier)
                }
            }
        }
        // Level scaling: +10 % per level beyond 1
        let levelMultiplier = 1.0 + 0.10 * Double(building.level - 1)
        return Int(Double(base) * levelMultiplier)
    }

    private func completeUpgrade(for buildingID: UUID) {
        guard let idx = buildings.firstIndex(where: { $0.id == buildingID }) else {
            return
        }
        buildings[idx].level += 1
        buildings[idx].state = .operational
        buildings[idx].maxHealthPoints *= 1.15
        buildings[idx].healthPoints = buildings[idx].maxHealthPoints
        buildings[idx].productionPerTick = baseProduction(for: buildings[idx].type)
            + buildings[idx].level
        buildings[idx].upgradeCost = upgradeCost(for: buildings[idx].type,
                                                  level: buildings[idx].level + 1)
    }

    private func applyDamageToBuilding(_ id: UUID, amount: Double) {
        guard let idx = buildings.firstIndex(where: { $0.id == id }) else { return }
        buildings[idx].healthPoints = max(0, buildings[idx].healthPoints - amount)
        if buildings[idx].healthPoints <= 0 {
            buildings[idx].state = .destroyed
        } else if buildings[idx].healthPoints < buildings[idx].maxHealthPoints * 0.5 {
            buildings[idx].state = .damaged
        }
    }

    private func updateBuilding(_ building: Building) {
        guard let idx = buildings.firstIndex(where: { $0.id == building.id }) else {
            return
        }
        buildings[idx] = building
    }

    // MARK: - Cost / Stat Tables

    private func baseBuildTime(for type: BuildingType) -> TimeInterval {
        switch type {
        case .shelter:        return 30
        case .farm:           return 45
        case .waterPurifier:  return 45
        case .workshop:       return 60
        case .medBay:         return 90
        case .armory:         return 120
        case .watchtower:     return 60
        case .radarTower:     return 120
        case .generator:      return 90
        case .commandCenter:  return 180
        case .wall:           return 20
        case .tradingPost:    return 90
        case .lab:            return 120
        case .barracks:       return 60
        case .storehouse:     return 45
        }
    }

    private func baseHealth(for type: BuildingType) -> Double {
        switch type {
        case .wall:           return 200
        case .commandCenter:  return 300
        case .watchtower:     return 120
        default:              return 100
        }
    }

    private func baseProduction(for type: BuildingType) -> Int {
        switch type {
        case .farm:           return 5
        case .waterPurifier:  return 4
        case .workshop:       return 3
        case .medBay:         return 2
        case .generator:      return 2
        case .lab:            return 1
        default:              return 0
        }
    }

    /// Calculates upgrade cost with reasonable (not punitive) scaling:
    /// cost = baseCost * level * 1.3^(level-1), capped so it never exceeds
    /// 10x the base cost.
    func upgradeCost(for type: BuildingType, level: Int) -> [ResourceCost] {
        let base = baseCostTable(for: type)
        return base.map { cost in
            let scaled = Double(cost.amount) * Double(level)
                * pow(1.3, Double(level - 1))
            let capped = min(scaled, Double(cost.amount) * 10.0)
            return ResourceCost(cost.type, max(1, Int(capped)))
        }
    }

    private func baseCostTable(for type: BuildingType) -> [ResourceCost] {
        switch type {
        case .shelter:        return [ResourceCost(.scrap, 20)]
        case .farm:           return [ResourceCost(.scrap, 15), ResourceCost(.water, 5)]
        case .waterPurifier:  return [ResourceCost(.scrap, 20)]
        case .workshop:       return [ResourceCost(.scrap, 30)]
        case .medBay:         return [ResourceCost(.scrap, 25), ResourceCost(.medicine, 10)]
        case .armory:         return [ResourceCost(.scrap, 40), ResourceCost(.militaryComponents, 10)]
        case .watchtower:     return [ResourceCost(.scrap, 25)]
        case .radarTower:     return [ResourceCost(.scrap, 35), ResourceCost(.electronics, 15)]
        case .generator:      return [ResourceCost(.scrap, 30), ResourceCost(.fuel, 10)]
        case .commandCenter:  return [ResourceCost(.scrap, 60), ResourceCost(.electronics, 20)]
        case .wall:           return [ResourceCost(.scrap, 10)]
        case .tradingPost:    return [ResourceCost(.scrap, 30), ResourceCost(.electronics, 5)]
        case .lab:            return [ResourceCost(.scrap, 35), ResourceCost(.electronics, 15)]
        case .barracks:       return [ResourceCost(.scrap, 25)]
        case .storehouse:     return [ResourceCost(.scrap, 20)]
        }
    }
}
