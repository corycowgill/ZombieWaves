// TechTree.swift
// ProjectAshfall
//
// Technology research tree with branching unlock paths across five
// disciplines: military, survival, engineering, medical, and recon.

import Foundation

// MARK: - Tech Category

/// Major research discipline that groups related technologies.
enum TechCategory: String, Codable, CaseIterable {
    case military
    case survival
    case engineering
    case medical
    case recon

    var displayName: String {
        switch self {
        case .military:    return "Military"
        case .survival:    return "Survival"
        case .engineering: return "Engineering"
        case .medical:     return "Medical"
        case .recon:       return "Recon"
        }
    }

    var iconName: String {
        "icon_tech_\(rawValue)"
    }
}

// MARK: - Tech Effect

/// A concrete gameplay effect granted when a tech node is unlocked.
struct TechEffect: Codable, Hashable {
    /// Short machine-readable key for the system to apply (e.g. "hero_attack_percent").
    let effectKey: String
    /// Human-readable description of the effect.
    let description: String
    /// Numeric value of the effect (interpretation depends on effectKey).
    let value: Double

    init(effectKey: String, description: String, value: Double) {
        self.effectKey = effectKey
        self.description = description
        self.value = value
    }
}

// MARK: - Tech Node

/// A single researchable technology in the tree.
struct TechNode: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let category: TechCategory
    /// Tier depth in the tree (0 = root).
    let tier: Int
    /// IDs of nodes that must be unlocked before this one.
    let prerequisiteIDs: [String]
    /// Resource costs to research.
    let costs: [ResourceCost]
    /// Time in seconds to complete research.
    let researchTime: TimeInterval
    /// Effects granted on unlock.
    let effects: [TechEffect]
    /// Minimum research-lab level required.
    let requiredLabLevel: Int
    /// Asset name for the node icon.
    let iconName: String

    init(
        id: String,
        name: String,
        description: String,
        category: TechCategory,
        tier: Int,
        prerequisiteIDs: [String] = [],
        costs: [ResourceCost] = [],
        researchTime: TimeInterval = 60,
        effects: [TechEffect] = [],
        requiredLabLevel: Int = 1,
        iconName: String = "tech_default"
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.tier = tier
        self.prerequisiteIDs = prerequisiteIDs
        self.costs = costs
        self.researchTime = researchTime
        self.effects = effects
        self.requiredLabLevel = requiredLabLevel
        self.iconName = iconName
    }
}

// MARK: - Tech Tree

/// Manages the full technology tree, tracking research progress and
/// providing queries for available / completed nodes.
final class TechTree: Codable {

    /// All nodes in the tree.
    private(set) var nodes: [String: TechNode]

    /// IDs of nodes that have been fully researched.
    private(set) var unlockedNodeIDs: Set<String>

    /// ID of the node currently being researched, if any.
    private(set) var activeResearchID: String?

    /// Remaining research time for the active node.
    private(set) var activeResearchTimeRemaining: TimeInterval

    // MARK: Init

    init(nodes: [TechNode] = TechTree.defaultNodes(), unlockedNodeIDs: Set<String> = []) {
        self.nodes = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        self.unlockedNodeIDs = unlockedNodeIDs
        self.activeResearchID = nil
        self.activeResearchTimeRemaining = 0
    }

    // MARK: Queries

    /// Whether a node has been researched.
    func isUnlocked(_ nodeID: String) -> Bool {
        unlockedNodeIDs.contains(nodeID)
    }

    /// Whether a node's prerequisites are all met.
    func prerequisitesMet(for nodeID: String) -> Bool {
        guard let node = nodes[nodeID] else { return false }
        return node.prerequisiteIDs.allSatisfy { unlockedNodeIDs.contains($0) }
    }

    /// Returns nodes available for research (prerequisites met, not yet unlocked).
    func availableNodes() -> [TechNode] {
        nodes.values.filter { !isUnlocked($0.id) && prerequisitesMet(for: $0.id) }
    }

    /// Returns all nodes in a given category, sorted by tier.
    func nodes(in category: TechCategory) -> [TechNode] {
        nodes.values
            .filter { $0.category == category }
            .sorted { $0.tier < $1.tier }
    }

    /// Accumulated effects from all unlocked nodes.
    func allActiveEffects() -> [TechEffect] {
        unlockedNodeIDs.compactMap { nodes[$0] }.flatMap { $0.effects }
    }

    // MARK: Mutations

    /// Begins researching a node. Returns false if prerequisites or costs are not met.
    @discardableResult
    func beginResearch(_ nodeID: String, inventory: ResourceInventory) -> Bool {
        guard activeResearchID == nil,
              let node = nodes[nodeID],
              !isUnlocked(nodeID),
              prerequisitesMet(for: nodeID),
              inventory.canAfford(node.costs)
        else { return false }

        guard inventory.spend(node.costs) else { return false }
        activeResearchID = nodeID
        activeResearchTimeRemaining = node.researchTime
        return true
    }

    /// Advances the active research timer. Completes research if time reaches zero.
    /// Returns the completed node if research finished this tick.
    @discardableResult
    func tick(deltaTime: TimeInterval) -> TechNode? {
        guard let activeID = activeResearchID else { return nil }
        activeResearchTimeRemaining = max(0, activeResearchTimeRemaining - deltaTime)
        if activeResearchTimeRemaining <= 0 {
            unlockedNodeIDs.insert(activeID)
            let completed = nodes[activeID]
            activeResearchID = nil
            activeResearchTimeRemaining = 0
            return completed
        }
        return nil
    }

    /// Force-unlocks a node (for debugging or story triggers).
    func forceUnlock(_ nodeID: String) {
        unlockedNodeIDs.insert(nodeID)
    }

    // MARK: - Default Tech Tree

    /// Builds the full default technology tree with all five categories.
    static func defaultNodes() -> [TechNode] {
        var all: [TechNode] = []
        all.append(contentsOf: militaryNodes())
        all.append(contentsOf: survivalNodes())
        all.append(contentsOf: engineeringNodes())
        all.append(contentsOf: medicalNodes())
        all.append(contentsOf: reconNodes())
        return all
    }

    // MARK: Military Branch

    private static func militaryNodes() -> [TechNode] {
        [
            TechNode(id: "mil_basic_training", name: "Basic Training",
                     description: "Improves base attack for all heroes.",
                     category: .military, tier: 0,
                     costs: [ResourceCost(.researchData, 20)],
                     researchTime: 60,
                     effects: [TechEffect(effectKey: "hero_attack_flat", description: "+5 attack for all heroes", value: 5)],
                     iconName: "tech_basic_training"),

            TechNode(id: "mil_advanced_tactics", name: "Advanced Tactics",
                     description: "Unlocks flanking formation and improves squad coordination.",
                     category: .military, tier: 1,
                     prerequisiteIDs: ["mil_basic_training"],
                     costs: [ResourceCost(.researchData, 40), ResourceCost(.militaryComponents, 15)],
                     researchTime: 120,
                     effects: [TechEffect(effectKey: "unlock_flanking", description: "Unlocks flanking formation", value: 1)],
                     requiredLabLevel: 2, iconName: "tech_advanced_tactics"),

            TechNode(id: "mil_heavy_ordnance", name: "Heavy Ordnance",
                     description: "Turrets deal 25% more damage.",
                     category: .military, tier: 1,
                     prerequisiteIDs: ["mil_basic_training"],
                     costs: [ResourceCost(.researchData, 35), ResourceCost(.militaryComponents, 20)],
                     researchTime: 100,
                     effects: [TechEffect(effectKey: "turret_damage_percent", description: "+25% turret damage", value: 0.25)],
                     requiredLabLevel: 2, iconName: "tech_heavy_ordnance"),

            TechNode(id: "mil_armor_piercing", name: "Armor-Piercing Rounds",
                     description: "All hero attacks ignore 15% of enemy defense.",
                     category: .military, tier: 2,
                     prerequisiteIDs: ["mil_advanced_tactics"],
                     costs: [ResourceCost(.researchData, 60), ResourceCost(.militaryComponents, 30)],
                     researchTime: 180,
                     effects: [TechEffect(effectKey: "armor_pierce_percent", description: "Ignore 15% enemy defense", value: 0.15)],
                     requiredLabLevel: 3, iconName: "tech_armor_piercing"),

            TechNode(id: "mil_elite_training", name: "Elite Combat Training",
                     description: "Heroes gain +10% crit chance.",
                     category: .military, tier: 3,
                     prerequisiteIDs: ["mil_armor_piercing"],
                     costs: [ResourceCost(.researchData, 100), ResourceCost(.militaryComponents, 50)],
                     researchTime: 300,
                     effects: [TechEffect(effectKey: "hero_crit_percent", description: "+10% crit chance", value: 0.10)],
                     requiredLabLevel: 5, iconName: "tech_elite_training")
        ]
    }

    // MARK: Survival Branch

    private static func survivalNodes() -> [TechNode] {
        [
            TechNode(id: "srv_rationing", name: "Rationing Protocols",
                     description: "Reduces food and water consumption by 15%.",
                     category: .survival, tier: 0,
                     costs: [ResourceCost(.researchData, 15)],
                     researchTime: 45,
                     effects: [TechEffect(effectKey: "resource_consumption_reduce", description: "-15% food/water use", value: 0.15)],
                     iconName: "tech_rationing"),

            TechNode(id: "srv_fortification", name: "Fortified Walls",
                     description: "Walls gain +30% hit points.",
                     category: .survival, tier: 1,
                     prerequisiteIDs: ["srv_rationing"],
                     costs: [ResourceCost(.researchData, 30), ResourceCost(.scrap, 40)],
                     researchTime: 90,
                     effects: [TechEffect(effectKey: "wall_hp_percent", description: "+30% wall HP", value: 0.30)],
                     requiredLabLevel: 2, iconName: "tech_fortification"),

            TechNode(id: "srv_deep_storage", name: "Deep Storage",
                     description: "Increases resource storage capacity by 50%.",
                     category: .survival, tier: 2,
                     prerequisiteIDs: ["srv_fortification"],
                     costs: [ResourceCost(.researchData, 50), ResourceCost(.scrap, 60)],
                     researchTime: 150,
                     effects: [TechEffect(effectKey: "storage_capacity_percent", description: "+50% storage", value: 0.50)],
                     requiredLabLevel: 3, iconName: "tech_deep_storage"),

            TechNode(id: "srv_self_sustaining", name: "Self-Sustaining Base",
                     description: "All production buildings generate 20% more resources.",
                     category: .survival, tier: 3,
                     prerequisiteIDs: ["srv_deep_storage"],
                     costs: [ResourceCost(.researchData, 80), ResourceCost(.electronics, 40)],
                     researchTime: 240,
                     effects: [TechEffect(effectKey: "production_percent", description: "+20% production", value: 0.20)],
                     requiredLabLevel: 4, iconName: "tech_self_sustaining")
        ]
    }

    // MARK: Engineering Branch

    private static func engineeringNodes() -> [TechNode] {
        [
            TechNode(id: "eng_scrap_recycling", name: "Scrap Recycling",
                     description: "Recover 20% of resources from demolished buildings.",
                     category: .engineering, tier: 0,
                     costs: [ResourceCost(.researchData, 15)],
                     researchTime: 45,
                     effects: [TechEffect(effectKey: "demolish_refund_percent", description: "20% resource refund", value: 0.20)],
                     iconName: "tech_recycling"),

            TechNode(id: "eng_rapid_construction", name: "Rapid Construction",
                     description: "Building and upgrade times reduced by 20%.",
                     category: .engineering, tier: 1,
                     prerequisiteIDs: ["eng_scrap_recycling"],
                     costs: [ResourceCost(.researchData, 35), ResourceCost(.electronics, 20)],
                     researchTime: 100,
                     effects: [TechEffect(effectKey: "build_time_reduce_percent", description: "-20% build time", value: 0.20)],
                     requiredLabLevel: 2, iconName: "tech_rapid_construction"),

            TechNode(id: "eng_automated_turrets", name: "Automated Turrets",
                     description: "Turrets no longer require manual targeting.",
                     category: .engineering, tier: 2,
                     prerequisiteIDs: ["eng_rapid_construction"],
                     costs: [ResourceCost(.researchData, 55), ResourceCost(.electronics, 35), ResourceCost(.powerCells, 10)],
                     researchTime: 180,
                     effects: [TechEffect(effectKey: "turret_auto_target", description: "Auto-targeting turrets", value: 1)],
                     requiredLabLevel: 3, iconName: "tech_auto_turrets"),

            TechNode(id: "eng_power_grid", name: "Power Grid",
                     description: "Unlocks power-cell production and energy-dependent buildings.",
                     category: .engineering, tier: 2,
                     prerequisiteIDs: ["eng_rapid_construction"],
                     costs: [ResourceCost(.researchData, 50), ResourceCost(.electronics, 30)],
                     researchTime: 160,
                     effects: [TechEffect(effectKey: "unlock_power_grid", description: "Enables power cell production", value: 1)],
                     requiredLabLevel: 3, iconName: "tech_power_grid"),

            TechNode(id: "eng_masterwork", name: "Masterwork Engineering",
                     description: "All buildings gain +25% max HP and produce 15% faster.",
                     category: .engineering, tier: 3,
                     prerequisiteIDs: ["eng_automated_turrets", "eng_power_grid"],
                     costs: [ResourceCost(.researchData, 100), ResourceCost(.electronics, 60), ResourceCost(.powerCells, 25)],
                     researchTime: 300,
                     effects: [
                        TechEffect(effectKey: "building_hp_percent", description: "+25% building HP", value: 0.25),
                        TechEffect(effectKey: "production_speed_percent", description: "+15% production speed", value: 0.15)
                     ],
                     requiredLabLevel: 5, iconName: "tech_masterwork")
        ]
    }

    // MARK: Medical Branch

    private static func medicalNodes() -> [TechNode] {
        [
            TechNode(id: "med_first_aid", name: "Advanced First Aid",
                     description: "Medic heroes heal 15% more.",
                     category: .medical, tier: 0,
                     costs: [ResourceCost(.researchData, 15), ResourceCost(.medicine, 10)],
                     researchTime: 45,
                     effects: [TechEffect(effectKey: "medic_heal_percent", description: "+15% healing", value: 0.15)],
                     iconName: "tech_first_aid"),

            TechNode(id: "med_field_surgery", name: "Field Surgery",
                     description: "Heroes recover faster between missions.",
                     category: .medical, tier: 1,
                     prerequisiteIDs: ["med_first_aid"],
                     costs: [ResourceCost(.researchData, 30), ResourceCost(.medicine, 20)],
                     researchTime: 90,
                     effects: [TechEffect(effectKey: "recovery_speed_percent", description: "+30% recovery speed", value: 0.30)],
                     requiredLabLevel: 2, iconName: "tech_field_surgery"),

            TechNode(id: "med_pathogen_research", name: "Pathogen Research",
                     description: "Heroes gain +10% resistance to infected debuffs.",
                     category: .medical, tier: 2,
                     prerequisiteIDs: ["med_field_surgery"],
                     costs: [ResourceCost(.researchData, 50), ResourceCost(.bioSamples, 25), ResourceCost(.medicine, 15)],
                     researchTime: 160,
                     effects: [TechEffect(effectKey: "infection_resist_percent", description: "+10% infection resistance", value: 0.10)],
                     requiredLabLevel: 3, iconName: "tech_pathogen"),

            TechNode(id: "med_regeneration", name: "Regenerative Medicine",
                     description: "All heroes passively regenerate 2% HP per turn in combat.",
                     category: .medical, tier: 3,
                     prerequisiteIDs: ["med_pathogen_research"],
                     costs: [ResourceCost(.researchData, 90), ResourceCost(.bioSamples, 40), ResourceCost(.medicine, 30)],
                     researchTime: 280,
                     effects: [TechEffect(effectKey: "hero_regen_percent", description: "2% HP regen per turn", value: 0.02)],
                     requiredLabLevel: 4, iconName: "tech_regeneration")
        ]
    }

    // MARK: Recon Branch

    private static func reconNodes() -> [TechNode] {
        [
            TechNode(id: "rec_basic_scouting", name: "Basic Scouting",
                     description: "Reveals adjacent district threat levels on the world map.",
                     category: .recon, tier: 0,
                     costs: [ResourceCost(.researchData, 15)],
                     researchTime: 45,
                     effects: [TechEffect(effectKey: "reveal_adjacent_threats", description: "See adjacent threat levels", value: 1)],
                     iconName: "tech_scouting"),

            TechNode(id: "rec_signal_intercept", name: "Signal Intercept",
                     description: "Reveals enemy wave composition before defense battles.",
                     category: .recon, tier: 1,
                     prerequisiteIDs: ["rec_basic_scouting"],
                     costs: [ResourceCost(.researchData, 30), ResourceCost(.electronics, 15)],
                     researchTime: 90,
                     effects: [TechEffect(effectKey: "preview_waves", description: "Preview incoming waves", value: 1)],
                     requiredLabLevel: 2, iconName: "tech_signal_intercept"),

            TechNode(id: "rec_network", name: "Survivor Network",
                     description: "Gain intel on survivor locations and side encounters.",
                     category: .recon, tier: 2,
                     prerequisiteIDs: ["rec_signal_intercept"],
                     costs: [ResourceCost(.researchData, 50), ResourceCost(.electronics, 25)],
                     researchTime: 150,
                     effects: [TechEffect(effectKey: "reveal_survivors", description: "Reveals survivor locations", value: 1)],
                     requiredLabLevel: 3, iconName: "tech_network"),

            TechNode(id: "rec_full_spectrum", name: "Full Spectrum Awareness",
                     description: "Reveals the entire world map and all enemy positions.",
                     category: .recon, tier: 3,
                     prerequisiteIDs: ["rec_network"],
                     costs: [ResourceCost(.researchData, 100), ResourceCost(.electronics, 50), ResourceCost(.powerCells, 20)],
                     researchTime: 300,
                     effects: [TechEffect(effectKey: "full_map_reveal", description: "Full map visibility", value: 1)],
                     requiredLabLevel: 5, iconName: "tech_full_spectrum")
        ]
    }
}
