// Resource.swift
// ProjectAshfall
//
// Economy layer: resource types, costs, and a central inventory.

import Foundation

// MARK: - Resource Type

/// Every material that can be gathered, spent, or traded.
enum ResourceType: String, Codable, CaseIterable {
    case food
    case water
    case fuel
    case scrap
    case electronics
    case medicine
    case bioSamples
    case militaryComponents
    case powerCells
    case researchData

    /// Human-readable label for UI.
    var displayName: String {
        switch self {
        case .food:                return "Food"
        case .water:               return "Water"
        case .fuel:                return "Fuel"
        case .scrap:               return "Scrap"
        case .electronics:         return "Electronics"
        case .medicine:            return "Medicine"
        case .bioSamples:          return "Bio-Samples"
        case .militaryComponents:  return "Military Components"
        case .powerCells:          return "Power Cells"
        case .researchData:        return "Research Data"
        }
    }

    /// Asset name for the resource icon.
    var iconName: String {
        "icon_resource_\(rawValue)"
    }

    /// Base rarity weight — higher means harder to find in the world.
    var scarcity: Int {
        switch self {
        case .food, .water:                          return 1
        case .scrap, .fuel:                          return 2
        case .electronics, .medicine:                return 3
        case .bioSamples, .militaryComponents:       return 4
        case .powerCells, .researchData:             return 5
        }
    }
}

// MARK: - Resource Cost

/// A bill of materials used for building, upgrading, and crafting.
struct ResourceCost: Codable, Hashable {
    let type: ResourceType
    let amount: Int

    init(_ type: ResourceType, _ amount: Int) {
        self.type = type
        self.amount = amount
    }
}

// MARK: - Resource Inventory

/// Central store for the player's accumulated resources. Thread-safety is
/// the caller's responsibility (e.g. wrap in an actor at the system level).
final class ResourceInventory: Codable {

    // MARK: Storage

    private var storage: [ResourceType: Int]
    private var capacities: [ResourceType: Int]

    // MARK: Init

    init(defaultCapacity: Int = 9999) {
        storage = Dictionary(uniqueKeysWithValues: ResourceType.allCases.map { ($0, 0) })
        capacities = Dictionary(uniqueKeysWithValues: ResourceType.allCases.map { ($0, defaultCapacity) })
    }

    // MARK: Queries

    /// Current amount of a single resource.
    func amount(of type: ResourceType) -> Int {
        storage[type, default: 0]
    }

    /// Maximum storable amount for a resource type.
    func capacity(of type: ResourceType) -> Int {
        capacities[type, default: 9999]
    }

    /// Whether the inventory contains enough to cover every entry in `costs`.
    func canAfford(_ costs: [ResourceCost]) -> Bool {
        for cost in costs {
            if amount(of: cost.type) < cost.amount { return false }
        }
        return true
    }

    /// Returns a snapshot dictionary of all resource amounts.
    func allAmounts() -> [ResourceType: Int] {
        storage
    }

    // MARK: Mutations

    /// Adds `quantity` units, clamped to the current capacity.
    /// Negative values are silently ignored.
    @discardableResult
    func add(_ type: ResourceType, quantity: Int) -> Int {
        guard quantity > 0 else { return amount(of: type) }
        let cap = capacity(of: type)
        let current = storage[type, default: 0]
        storage[type] = min(cap, current + quantity)
        return storage[type, default: 0]
    }

    /// Spends `quantity` units if available.
    /// - Returns: `true` when the spend succeeded.
    @discardableResult
    func spend(_ type: ResourceType, quantity: Int) -> Bool {
        guard quantity > 0, amount(of: type) >= quantity else { return false }
        storage[type, default: 0] -= quantity
        return true
    }

    /// Attempts to deduct an array of costs atomically.
    /// Either all costs are deducted or none are.
    @discardableResult
    func spend(_ costs: [ResourceCost]) -> Bool {
        guard canAfford(costs) else { return false }
        for cost in costs {
            storage[cost.type, default: 0] -= cost.amount
        }
        return true
    }

    /// Sets the quantity of a resource directly (useful for save/load).
    func set(_ type: ResourceType, quantity: Int) {
        storage[type] = max(0, min(quantity, capacity(of: type)))
    }

    /// Increases the storage capacity for a given resource.
    func setCapacity(_ type: ResourceType, capacity: Int) {
        capacities[type] = max(0, capacity)
    }
}
