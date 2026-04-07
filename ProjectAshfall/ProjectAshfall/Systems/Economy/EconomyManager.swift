// EconomyManager.swift
// ProjectAshfall
//
// Manages all resource flows: production income, mission rewards, upgrade
// costs, and transaction logging. Designed to prevent punitive economies —
// wait times are capped and costs scale reasonably.

import Foundation

// MARK: - Transaction Type

/// Classifies a resource movement for ledger reporting.
enum TransactionType: String, Codable {
    case production
    case missionReward
    case scavenging
    case eventGain
    case eventLoss
    case buildingCost
    case upgradeCost
    case demolishRefund
    case trade
    case expeditionCost
    case skillUnlock
}

// MARK: - Resource Transaction

/// An immutable record of a single resource movement (positive or negative).
struct ResourceTransaction: Identifiable, Codable {
    let id: UUID
    let type: TransactionType
    let resourceType: ResourceType
    /// Positive = income, negative = expenditure.
    let amount: Int
    let timestamp: Date
    let note: String

    init(type: TransactionType, resourceType: ResourceType,
         amount: Int, note: String = "") {
        self.id = UUID()
        self.type = type
        self.resourceType = resourceType
        self.amount = amount
        self.timestamp = Date()
        self.note = note
    }
}

// MARK: - Upgrade Cost Estimate

/// Projected cost for a building or hero upgrade, shown in the UI before
/// the player commits.
struct UpgradeCostEstimate {
    let costs: [ResourceCost]
    let buildTime: TimeInterval
    let canAfford: Bool
}

// MARK: - Economy Manager

/// Single source of truth for resource arithmetic. Every system that wants
/// to add or remove resources should go through this manager so that
/// transactions are logged and caps are respected.
final class EconomyManager {

    // MARK: Properties

    /// Shared resource inventory.
    let inventory: ResourceInventory

    /// Rolling transaction log (most recent first). Capped at 500 entries.
    private(set) var transactionLog: [ResourceTransaction] = []
    private let maxLogEntries = 500

    /// Per-resource storage caps. Increased by Storehouse upgrades.
    private var storageCaps: [ResourceType: Int]

    /// Production rates per minute, keyed by resource type. Updated by
    /// BaseManager whenever buildings change.
    private(set) var productionRates: [ResourceType: Double] = [:]

    /// Maximum wait time (in seconds) for any single upgrade. Prevents
    /// punitive idle timers.
    static let maxUpgradeWaitTime: TimeInterval = 1800.0 // 30 minutes

    // MARK: Init

    init(inventory: ResourceInventory = ResourceInventory()) {
        self.inventory = inventory
        // Default storage caps
        self.storageCaps = Dictionary(
            uniqueKeysWithValues: ResourceType.allCases.map { ($0, 500) }
        )
    }

    // MARK: - Affordability

    /// Checks if the player can afford a list of costs without spending.
    func canAfford(_ costs: [ResourceCost]) -> Bool {
        inventory.canAfford(costs)
    }

    // MARK: - Spending

    /// Atomically spends resources and logs the transaction.
    /// Returns `true` on success.
    @discardableResult
    func spend(_ costs: [ResourceCost],
               type: TransactionType,
               note: String = "") -> Bool {
        guard inventory.spend(costs) else { return false }
        for cost in costs {
            record(ResourceTransaction(
                type: type, resourceType: cost.type,
                amount: -cost.amount, note: note
            ))
        }
        return true
    }

    // MARK: - Earning

    /// Adds resources (capped by storage limits) and logs the transaction.
    func earn(_ gains: [ResourceCost],
              type: TransactionType,
              note: String = "") {
        for gain in gains {
            let cap = storageCaps[gain.type] ?? Int.max
            let current = inventory.amount(of: gain.type)
            let effective = min(gain.amount, cap - current)
            guard effective > 0 else { continue }
            inventory.add(gain.type, quantity: effective)
            record(ResourceTransaction(
                type: type, resourceType: gain.type,
                amount: effective, note: note
            ))
        }
    }

    /// Convenience for a single resource type.
    func earn(_ resourceType: ResourceType, amount: Int,
              type: TransactionType, note: String = "") {
        earn([ResourceCost(resourceType, amount)], type: type, note: note)
    }

    // MARK: - Production Rates

    /// Recalculates production rates based on current operational buildings.
    /// Called by `BaseManager` after any building change.
    func updateProductionRates(from buildings: [Building]) {
        var rates: [ResourceType: Double] = [:]
        for building in buildings where building.isOperational {
            guard let resType = building.type.producedResourceType else { continue }
            let perMinute = Double(building.productionPerTick)
            rates[resType, default: 0] += perMinute
        }
        productionRates = rates
    }

    // MARK: - Mission Rewards

    /// Calculates resource rewards for completing a combat mission.
    /// Scales with district threat level and squad performance.
    func missionReward(threatLevel: ThreatLevel,
                       heroCount: Int,
                       perfectClear: Bool) -> [ResourceCost] {
        let baseMultiplier = Double(threatLevel.rawValue + 1)
        let perfBonus = perfectClear ? 1.5 : 1.0

        // Each resource type has a weighted chance of appearing
        var rewards: [ResourceCost] = []

        let food = Int(10.0 * baseMultiplier * perfBonus)
        let scrap = Int(8.0 * baseMultiplier * perfBonus)
        rewards.append(ResourceCost(.food, food))
        rewards.append(ResourceCost(.scrap, scrap))

        if threatLevel >= .moderate {
            let electronics = Int(3.0 * baseMultiplier * perfBonus)
            rewards.append(ResourceCost(.electronics, electronics))
        }
        if threatLevel >= .high {
            let milComp = Int(2.0 * baseMultiplier * perfBonus)
            rewards.append(ResourceCost(.militaryComponents, milComp))
        }
        if threatLevel >= .severe {
            let bio = Int(1.0 * baseMultiplier * perfBonus)
            rewards.append(ResourceCost(.bioSamples, bio))
        }

        return rewards
    }

    // MARK: - Upgrade Cost Scaling

    /// Returns the cost estimate for upgrading a building to the next level.
    /// Uses reasonable scaling: cost * level * 1.3^(level-1), hard-capped
    /// at 10x base cost. Build time is similarly capped.
    func upgradeEstimate(buildingType: BuildingType,
                         currentLevel: Int) -> UpgradeCostEstimate {
        let nextLevel = currentLevel + 1
        let baseCosts = baseCostTable(for: buildingType)
        let scaledCosts = baseCosts.map { cost -> ResourceCost in
            let scaled = Double(cost.amount) * Double(nextLevel)
                * pow(1.3, Double(nextLevel - 1))
            let capped = min(scaled, Double(cost.amount) * 10.0)
            return ResourceCost(cost.type, max(1, Int(capped)))
        }

        let baseTime: TimeInterval = 30.0 * Double(nextLevel)
        let cappedTime = min(baseTime, EconomyManager.maxUpgradeWaitTime)

        return UpgradeCostEstimate(
            costs: scaledCosts,
            buildTime: cappedTime,
            canAfford: canAfford(scaledCosts)
        )
    }

    // MARK: - Storage Caps

    /// Increases the storage cap for all resource types. Called when the
    /// player upgrades a Storehouse.
    func increaseStorageCap(by amount: Int) {
        for key in storageCaps.keys {
            storageCaps[key] = (storageCaps[key] ?? 500) + amount
        }
    }

    /// Returns the current cap for a resource type.
    func storageCap(for type: ResourceType) -> Int {
        storageCaps[type] ?? 500
    }

    // MARK: - Ledger Queries

    /// Returns all transactions of a given type.
    func transactions(ofType type: TransactionType) -> [ResourceTransaction] {
        transactionLog.filter { $0.type == type }
    }

    /// Net income (positive) or expenditure (negative) over the last N
    /// transactions for a given resource.
    func netFlow(for resourceType: ResourceType, last count: Int = 50) -> Int {
        transactionLog
            .filter { $0.resourceType == resourceType }
            .prefix(count)
            .reduce(0) { $0 + $1.amount }
    }

    // MARK: - Queue System

    /// Validates and enqueues a purchase. Returns `false` if unaffordable.
    /// This is the canonical "buy something" entry point; other systems
    /// should prefer this over calling `inventory.spend` directly.
    @discardableResult
    func purchase(costs: [ResourceCost], type: TransactionType,
                  note: String = "") -> Bool {
        spend(costs, type: type, note: note)
    }

    // MARK: - Private

    private func record(_ transaction: ResourceTransaction) {
        transactionLog.insert(transaction, at: 0)
        if transactionLog.count > maxLogEntries {
            transactionLog.removeLast()
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
