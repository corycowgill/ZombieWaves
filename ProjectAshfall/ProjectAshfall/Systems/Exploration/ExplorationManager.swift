// ExplorationManager.swift
// ProjectAshfall
//
// Manages the world map: fog of war, district reveals, scavenging run
// generation, survivor rescues, environmental hazards, and expedition
// timers. Feeds into CombatEngine for encounters and EconomyManager for
// loot distribution.

import Foundation

// MARK: - Fog of War State

/// Visibility state for each district on the world map.
enum FogState: String, Codable {
    /// Completely hidden — player has no information.
    case hidden
    /// Outline visible, threat level shown, but details are unknown.
    case revealed
    /// Fully explored — all content visible.
    case explored
}

// MARK: - Scavenging Event

/// A procedurally generated event encountered during a scavenging run.
enum ScavengingEventType: String, Codable, CaseIterable {
    case lootCache
    case ambush
    case traderEncounter
    case survivorRescue
    case environmentalHazard
    case abandonedVehicle
    case infectedZone
    case hiddenBunker
}

/// Full description of one scavenging event, including rewards and
/// potential combat encounter.
struct ScavengingEvent: Identifiable, Codable {
    let id: UUID
    let type: ScavengingEventType
    let description: String
    /// Resources gained if the event resolves favorably.
    let rewards: [ResourceCost]
    /// If non-nil, the player must fight this encounter first.
    let combatEncounter: ScavengingCombatEncounter?
    /// If true, the player can choose to skip this event.
    let isOptional: Bool

    init(type: ScavengingEventType, description: String,
         rewards: [ResourceCost] = [],
         combatEncounter: ScavengingCombatEncounter? = nil,
         isOptional: Bool = true) {
        self.id = UUID()
        self.type = type
        self.description = description
        self.rewards = rewards
        self.combatEncounter = combatEncounter
        self.isOptional = isOptional
    }
}

/// Lightweight combat descriptor embedded in a scavenging event.
struct ScavengingCombatEncounter: Codable {
    let enemyTypes: [EnemyType]
    let enemyCount: Int
    let threatLevel: ThreatLevel
}

// MARK: - Survivor Rescue

/// A rescuable survivor discovered during exploration.
struct SurvivorRescue: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    /// If non-nil this is a named hero, not a generic survivor.
    let heroID: UUID?
    let districtID: UUID
    var isRescued: Bool

    init(name: String, description: String, heroID: UUID? = nil,
         districtID: UUID) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.heroID = heroID
        self.districtID = districtID
        self.isRescued = false
    }
}

// MARK: - Environmental Hazard

/// A persistent hazard affecting a district until cleared.
enum HazardType: String, Codable, CaseIterable {
    case radiation
    case toxicGas
    case fireStorm
    case flooding
    case electricalStorm

    /// Per-tick damage applied to heroes in the hazard zone.
    var damagePerTick: Double {
        switch self {
        case .radiation:       return 5.0
        case .toxicGas:        return 8.0
        case .fireStorm:       return 12.0
        case .flooding:        return 3.0
        case .electricalStorm: return 10.0
        }
    }

    /// Resource cost to neutralize the hazard.
    var clearingCost: [ResourceCost] {
        switch self {
        case .radiation:       return [ResourceCost(.medicine, 10), ResourceCost(.bioSamples, 5)]
        case .toxicGas:        return [ResourceCost(.medicine, 8)]
        case .fireStorm:       return [ResourceCost(.water, 15)]
        case .flooding:        return [ResourceCost(.scrap, 20)]
        case .electricalStorm: return [ResourceCost(.electronics, 10)]
        }
    }
}

struct EnvironmentalHazard: Identifiable, Codable {
    let id: UUID
    let type: HazardType
    let districtID: UUID
    var isCleared: Bool

    init(type: HazardType, districtID: UUID) {
        self.id = UUID()
        self.type = type
        self.districtID = districtID
        self.isCleared = false
    }
}

// MARK: - Expedition

/// An active scavenging run sent to a district.
struct Expedition: Identifiable, Codable {
    let id: UUID
    let districtID: UUID
    let squadID: UUID
    let events: [ScavengingEvent]
    /// Total time (seconds) the expedition takes.
    let duration: TimeInterval
    var timeRemaining: TimeInterval
    /// Resources spent to launch (fuel, food).
    let cost: [ResourceCost]
    var isComplete: Bool { timeRemaining <= 0 }

    init(districtID: UUID, squadID: UUID, events: [ScavengingEvent],
         duration: TimeInterval, cost: [ResourceCost]) {
        self.id = UUID()
        self.districtID = districtID
        self.squadID = squadID
        self.events = events
        self.duration = duration
        self.timeRemaining = duration
        self.cost = cost
    }
}

// MARK: - Exploration Manager

/// Owns the fog-of-war map, generates scavenging content, and manages
/// active expeditions.
final class ExplorationManager {

    // MARK: Properties

    /// Fog state per district ID.
    private(set) var fogMap: [UUID: FogState] = [:]

    /// All known districts (set during game init or save load).
    private(set) var districts: [District]

    /// Active expeditions in progress.
    private(set) var activeExpeditions: [Expedition] = []

    /// Discovered survivors awaiting rescue.
    private(set) var pendingRescues: [SurvivorRescue] = []

    /// Active environmental hazards keyed by district ID.
    private(set) var hazards: [EnvironmentalHazard] = []

    /// Current radar tower level — determines how many tiles are revealed
    /// per scan.
    var radarTowerLevel: Int = 0

    /// Maximum concurrent expeditions (scales with command center level).
    var maxExpeditions: Int = 1

    // MARK: Init

    init(districts: [District] = []) {
        self.districts = districts
        for district in districts {
            fogMap[district.id] = district.isRevealed ? .revealed : .hidden
        }
    }

    // MARK: - Fog of War

    /// Reveals a district (shows outline + threat level on the map).
    func revealDistrict(_ districtID: UUID) {
        guard fogMap[districtID] == .hidden else { return }
        fogMap[districtID] = .revealed
        if let idx = districts.firstIndex(where: { $0.id == districtID }) {
            districts[idx].isRevealed = true
        }
    }

    /// Marks a district as fully explored.
    func markExplored(_ districtID: UUID) {
        fogMap[districtID] = .explored
        if let idx = districts.firstIndex(where: { $0.id == districtID }) {
            districts[idx].isRevealed = true
        }
    }

    /// Uses the Radar Tower to reveal nearby districts. Number of reveals
    /// scales with `radarTowerLevel`.
    func performRadarScan(centerDistrictID: UUID) -> [UUID] {
        guard let center = districts.first(where: { $0.id == centerDistrictID })
        else { return [] }

        let radius = 1 + radarTowerLevel // level 0 = adjacent only
        let candidates = districts.filter {
            $0.id != centerDistrictID
            && fogMap[$0.id] == .hidden
            && $0.position.distance(to: center.position) <= radius
        }

        var revealed: [UUID] = []
        for district in candidates {
            revealDistrict(district.id)
            revealed.append(district.id)
        }
        return revealed
    }

    // MARK: - Scavenging Run Generation

    /// Generates a procedural scavenging run (list of events) for a district.
    func generateScavengingRun(for district: District) -> [ScavengingEvent] {
        let eventCount = 2 + district.threatLevel.rawValue // 2-7 events
        var events: [ScavengingEvent] = []

        for _ in 0 ..< eventCount {
            let event = randomEvent(threat: district.threatLevel)
            events.append(event)
        }

        // Guarantee at least one loot event
        if !events.contains(where: { $0.type == .lootCache }) {
            events[0] = makeLootEvent(threat: district.threatLevel)
        }

        return events
    }

    // MARK: - Expeditions

    /// Launches an expedition to a district. Returns the expedition on
    /// success, or `nil` if preconditions aren't met.
    func launchExpedition(districtID: UUID, squadID: UUID,
                          inventory: ResourceInventory) -> Expedition? {
        guard activeExpeditions.count < maxExpeditions else { return nil }
        guard let district = districts.first(where: { $0.id == districtID }),
              fogMap[districtID] != .hidden else { return nil }

        let cost = expeditionCost(for: district)
        guard inventory.canAfford(cost) else { return nil }
        guard inventory.spend(cost) else { return nil }

        let events = generateScavengingRun(for: district)
        let duration = expeditionDuration(for: district)

        let expedition = Expedition(
            districtID: districtID, squadID: squadID,
            events: events, duration: duration, cost: cost
        )
        activeExpeditions.append(expedition)
        return expedition
    }

    /// Tick expeditions forward. Call from the game loop.
    func update(deltaTime dt: TimeInterval) {
        for i in activeExpeditions.indices {
            activeExpeditions[i].timeRemaining -= dt
        }
    }

    /// Collects completed expeditions. The caller should resolve events
    /// and distribute loot.
    func collectCompletedExpeditions() -> [Expedition] {
        let completed = activeExpeditions.filter(\.isComplete)
        activeExpeditions.removeAll(where: \.isComplete)

        for expedition in completed {
            markExplored(expedition.districtID)
        }
        return completed
    }

    // MARK: - Survivor Rescues

    /// Adds a pending rescue to a district (discovered during expedition).
    func addRescue(_ rescue: SurvivorRescue) {
        pendingRescues.append(rescue)
    }

    /// Completes a rescue, returning the survivor info.
    func completeRescue(id: UUID) -> SurvivorRescue? {
        guard let idx = pendingRescues.firstIndex(where: { $0.id == id })
        else { return nil }
        pendingRescues[idx].isRescued = true
        return pendingRescues.remove(at: idx)
    }

    // MARK: - Environmental Hazards

    /// Adds a hazard to a district.
    func addHazard(type: HazardType, districtID: UUID) {
        let hazard = EnvironmentalHazard(type: type, districtID: districtID)
        hazards.append(hazard)
    }

    /// Returns all active hazards in a district.
    func hazards(in districtID: UUID) -> [EnvironmentalHazard] {
        hazards.filter { $0.districtID == districtID && !$0.isCleared }
    }

    /// Clears a hazard if the player spends the required resources.
    @discardableResult
    func clearHazard(id: UUID, inventory: ResourceInventory) -> Bool {
        guard let idx = hazards.firstIndex(where: { $0.id == id }),
              !hazards[idx].isCleared else { return false }
        let cost = hazards[idx].type.clearingCost
        guard inventory.spend(cost) else { return false }
        hazards[idx].isCleared = true
        return true
    }

    // MARK: - District Queries

    /// Returns districts the player can currently send expeditions to.
    func availableDistricts() -> [District] {
        districts.filter { fogMap[$0.id] == .revealed }
    }

    /// Returns districts that have been fully explored.
    func exploredDistricts() -> [District] {
        districts.filter { fogMap[$0.id] == .explored }
    }

    // MARK: - Private: Event Generation

    private func randomEvent(threat: ThreatLevel) -> ScavengingEvent {
        let type = ScavengingEventType.allCases.randomElement() ?? .lootCache
        switch type {
        case .lootCache:
            return makeLootEvent(threat: threat)
        case .ambush:
            return makeAmbushEvent(threat: threat)
        case .traderEncounter:
            return ScavengingEvent(
                type: .traderEncounter,
                description: "A lone trader offers supplies for barter.",
                rewards: [ResourceCost(.scrap, 10)]
            )
        case .survivorRescue:
            return ScavengingEvent(
                type: .survivorRescue,
                description: "Survivors spotted in a nearby building.",
                rewards: []
            )
        case .environmentalHazard:
            return ScavengingEvent(
                type: .environmentalHazard,
                description: "The area is covered in toxic fumes.",
                rewards: [],
                isOptional: true
            )
        case .abandonedVehicle:
            return ScavengingEvent(
                type: .abandonedVehicle,
                description: "An abandoned vehicle with salvageable parts.",
                rewards: [ResourceCost(.fuel, 5 + threat.rawValue * 2),
                          ResourceCost(.scrap, 8)]
            )
        case .infectedZone:
            return makeAmbushEvent(threat: threat)
        case .hiddenBunker:
            return ScavengingEvent(
                type: .hiddenBunker,
                description: "A hidden bunker with supplies inside.",
                rewards: [ResourceCost(.food, 15),
                          ResourceCost(.medicine, 5),
                          ResourceCost(.electronics, 3)]
            )
        }
    }

    private func makeLootEvent(threat: ThreatLevel) -> ScavengingEvent {
        let multi = threat.rawValue + 1
        return ScavengingEvent(
            type: .lootCache,
            description: "A stash of supplies found among the rubble.",
            rewards: [
                ResourceCost(.food, 8 * multi),
                ResourceCost(.scrap, 6 * multi),
                ResourceCost(.water, 4 * multi)
            ]
        )
    }

    private func makeAmbushEvent(threat: ThreatLevel) -> ScavengingEvent {
        let encounter = ScavengingCombatEncounter(
            enemyTypes: [.walker, .runner, .spitter],
            enemyCount: 2 + threat.rawValue,
            threatLevel: threat
        )
        return ScavengingEvent(
            type: .ambush,
            description: "Hostiles emerge from the shadows!",
            rewards: [ResourceCost(.scrap, 5 * (threat.rawValue + 1))],
            combatEncounter: encounter,
            isOptional: false
        )
    }

    // MARK: - Private: Cost / Duration

    private func expeditionCost(for district: District) -> [ResourceCost] {
        let fuelCost = 5 + district.threatLevel.rawValue * 3
        let foodCost = 3 + district.threatLevel.rawValue * 2
        return [ResourceCost(.fuel, fuelCost), ResourceCost(.food, foodCost)]
    }

    /// Expedition duration in seconds. Capped at 10 minutes to avoid
    /// excessive idle time.
    private func expeditionDuration(for district: District) -> TimeInterval {
        let base: TimeInterval = 60.0
        let threatBonus = TimeInterval(district.threatLevel.rawValue) * 30.0
        return min(base + threatBonus, 600.0) // max 10 minutes
    }
}
