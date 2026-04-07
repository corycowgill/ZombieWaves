import Foundation
import Combine

// MARK: - Game Phase

enum GamePhase: String, Codable, Equatable {
    case mainMenu
    case playing
    case paused
    case combat
    case worldMap
    case baseView
}

// MARK: - Economy Manager

final class EconomyManager: ObservableObject, Codable {
    @Published var food: Int = 200
    @Published var water: Int = 150
    @Published var fuel: Int = 80
    @Published var scrap: Int = 300
    @Published var electronics: Int = 50
    @Published var medicine: Int = 40

    enum CodingKeys: String, CodingKey {
        case food, water, fuel, scrap, electronics, medicine
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        food = try c.decode(Int.self, forKey: .food)
        water = try c.decode(Int.self, forKey: .water)
        fuel = try c.decode(Int.self, forKey: .fuel)
        scrap = try c.decode(Int.self, forKey: .scrap)
        electronics = try c.decode(Int.self, forKey: .electronics)
        medicine = try c.decode(Int.self, forKey: .medicine)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(food, forKey: .food)
        try c.encode(water, forKey: .water)
        try c.encode(fuel, forKey: .fuel)
        try c.encode(scrap, forKey: .scrap)
        try c.encode(electronics, forKey: .electronics)
        try c.encode(medicine, forKey: .medicine)
    }

    func canAfford(_ costs: [String: Int]) -> Bool {
        for (resource, amount) in costs {
            switch resource {
            case "food": if food < amount { return false }
            case "water": if water < amount { return false }
            case "fuel": if fuel < amount { return false }
            case "scrap": if scrap < amount { return false }
            case "electronics": if electronics < amount { return false }
            case "medicine": if medicine < amount { return false }
            default: break
            }
        }
        return true
    }

    func spend(_ costs: [String: Int]) {
        for (resource, amount) in costs {
            switch resource {
            case "food": food -= amount
            case "water": water -= amount
            case "fuel": fuel -= amount
            case "scrap": scrap -= amount
            case "electronics": electronics -= amount
            case "medicine": medicine -= amount
            default: break
            }
        }
    }

    func gain(_ rewards: [String: Int]) {
        for (resource, amount) in rewards {
            switch resource {
            case "food": food += amount
            case "water": water += amount
            case "fuel": fuel += amount
            case "scrap": scrap += amount
            case "electronics": electronics += amount
            case "medicine": medicine += amount
            default: break
            }
        }
    }
}

// MARK: - Progression Manager

final class ProgressionManager: ObservableObject, Codable {
    @Published var commanderXP: Int = 0
    @Published var commanderLevel: Int = 1
    @Published var unlockedDistricts: [String] = ["haven_district"]
    @Published var completedMissions: [String] = []
    @Published var currentChapter: Int = 1

    enum CodingKeys: String, CodingKey {
        case commanderXP, commanderLevel, unlockedDistricts, completedMissions, currentChapter
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        commanderXP = try c.decode(Int.self, forKey: .commanderXP)
        commanderLevel = try c.decode(Int.self, forKey: .commanderLevel)
        unlockedDistricts = try c.decode([String].self, forKey: .unlockedDistricts)
        completedMissions = try c.decode([String].self, forKey: .completedMissions)
        currentChapter = try c.decode(Int.self, forKey: .currentChapter)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(commanderXP, forKey: .commanderXP)
        try c.encode(commanderLevel, forKey: .commanderLevel)
        try c.encode(unlockedDistricts, forKey: .unlockedDistricts)
        try c.encode(completedMissions, forKey: .completedMissions)
        try c.encode(currentChapter, forKey: .currentChapter)
    }

    var xpForNextLevel: Int { commanderLevel * 500 + 200 }

    func addXP(_ amount: Int) {
        commanderXP += amount
        while commanderXP >= xpForNextLevel {
            commanderXP -= xpForNextLevel
            commanderLevel += 1
        }
    }
}

// MARK: - Campaign Manager

final class CampaignManager: ObservableObject, Codable {
    @Published var activeObjective: String = "Secure the Haven perimeter"
    @Published var sideQuests: [String] = []
    @Published var storyFlags: [String: Bool] = [:]
    @Published var daysSurvived: Int = 1

    enum CodingKeys: String, CodingKey {
        case activeObjective, sideQuests, storyFlags, daysSurvived
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        activeObjective = try c.decode(String.self, forKey: .activeObjective)
        sideQuests = try c.decode([String].self, forKey: .sideQuests)
        storyFlags = try c.decode([String: Bool].self, forKey: .storyFlags)
        daysSurvived = try c.decode(Int.self, forKey: .daysSurvived)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(activeObjective, forKey: .activeObjective)
        try c.encode(sideQuests, forKey: .sideQuests)
        try c.encode(storyFlags, forKey: .storyFlags)
        try c.encode(daysSurvived, forKey: .daysSurvived)
    }
}

// MARK: - Building

struct Building: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var level: Int
    var gridX: Int
    var gridY: Int
    var type: BuildingType

    enum BuildingType: String, Codable {
        case shelter, workshop, farm, waterPump, armory, medBay, watchtower, generator, storage
    }

    var upgradeCost: [String: Int] {
        let multiplier = level + 1
        switch type {
        case .shelter:    return ["scrap": 100 * multiplier, "food": 30 * multiplier]
        case .workshop:   return ["scrap": 150 * multiplier, "electronics": 20 * multiplier]
        case .farm:       return ["scrap": 80 * multiplier, "water": 40 * multiplier]
        case .waterPump:  return ["scrap": 120 * multiplier, "electronics": 15 * multiplier]
        case .armory:     return ["scrap": 200 * multiplier, "electronics": 40 * multiplier]
        case .medBay:     return ["scrap": 130 * multiplier, "medicine": 30 * multiplier]
        case .watchtower: return ["scrap": 90 * multiplier]
        case .generator:  return ["scrap": 160 * multiplier, "fuel": 50 * multiplier]
        case .storage:    return ["scrap": 70 * multiplier]
        }
    }
}

// MARK: - Base Manager

final class BaseManager: ObservableObject, Codable {
    @Published var buildings: [Building] = BaseManager.starterBuildings
    @Published var survivorCount: Int = 12
    @Published var baseMorale: Double = 0.75

    enum CodingKeys: String, CodingKey {
        case buildings, survivorCount, baseMorale
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        buildings = try c.decode([Building].self, forKey: .buildings)
        survivorCount = try c.decode(Int.self, forKey: .survivorCount)
        baseMorale = try c.decode(Double.self, forKey: .baseMorale)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(buildings, forKey: .buildings)
        try c.encode(survivorCount, forKey: .survivorCount)
        try c.encode(baseMorale, forKey: .baseMorale)
    }

    static let starterBuildings: [Building] = [
        Building(id: "shelter_01", name: "Main Shelter", level: 1, gridX: 3, gridY: 3, type: .shelter),
        Building(id: "farm_01", name: "Small Farm", level: 1, gridX: 1, gridY: 2, type: .farm),
        Building(id: "waterpump_01", name: "Water Pump", level: 1, gridX: 5, gridY: 2, type: .waterPump),
        Building(id: "workshop_01", name: "Workshop", level: 1, gridX: 2, gridY: 5, type: .workshop),
        Building(id: "watchtower_01", name: "Watchtower", level: 1, gridX: 0, gridY: 0, type: .watchtower),
    ]

    func upgradeBuilding(_ id: String) {
        if let idx = buildings.firstIndex(where: { $0.id == id }) {
            buildings[idx].level += 1
        }
    }
}

// MARK: - Hero Data

enum HeroRole: String, Codable, CaseIterable {
    case vanguard = "Vanguard"
    case marksman = "Marksman"
    case medic = "Medic"
    case engineer = "Engineer"
    case scout = "Scout"

    var icon: String {
        switch self {
        case .vanguard: return "shield.fill"
        case .marksman: return "scope"
        case .medic:    return "cross.case.fill"
        case .engineer: return "wrench.and.screwdriver.fill"
        case .scout:    return "binoculars.fill"
        }
    }
}

struct HeroSkill: Identifiable, Codable {
    let id: String
    var name: String
    var description: String
    var level: Int
    var maxLevel: Int
    var unlocked: Bool
}

struct GearSlot: Identifiable, Codable {
    let id: String
    var slotType: String          // weapon, armor, accessory
    var equippedItemName: String?
    var statBonus: [String: Int]
}

struct HeroBond: Identifiable, Codable {
    let id: String
    var partnerHeroId: String
    var bondLevel: Int
    var bondName: String
}

struct Hero: Identifiable, Codable {
    let id: String
    var name: String
    var role: HeroRole
    var level: Int
    var rank: Int                  // star rank 1-5
    var xp: Int
    var maxHP: Int
    var attack: Int
    var defense: Int
    var speed: Int
    var critRate: Double
    var skills: [HeroSkill]
    var gear: [GearSlot]
    var bonds: [HeroBond]
    var backstory: String
    var portraitName: String

    var xpForNextLevel: Int { level * 120 + 80 }
    var power: Int { maxHP + attack * 4 + defense * 3 + speed * 2 + Int(critRate * 100) }

    mutating func addXP(_ amount: Int) {
        xp += amount
        while xp >= xpForNextLevel {
            xp -= xpForNextLevel
            level += 1
            maxHP += 15
            attack += 3
            defense += 2
            speed += 1
        }
    }
}

// MARK: - District Data

struct District: Identifiable, Codable {
    let id: String
    var name: String
    var threatLevel: Int        // 1-10
    var isUnlocked: Bool
    var isCleared: Bool
    var gridX: Int
    var gridY: Int
    var connectedTo: [String]
    var rewards: [String: Int]
    var description: String
}

// MARK: - Game State Manager

final class GameStateManager: ObservableObject {
    @Published var currentPhase: GamePhase = .mainMenu
    @Published var playerName: String = "Commander"
    @Published var currentDistrict: String = "haven_district"
    @Published var activeSquad: [String] = []        // hero IDs
    @Published var heroes: [Hero] = GameStateManager.starterHeroes
    @Published var districts: [District] = GameStateManager.defaultDistricts
    @Published var totalPlaytime: TimeInterval = 0

    @Published var economy = EconomyManager()
    @Published var progression = ProgressionManager()
    @Published var campaign = CampaignManager()
    @Published var base = BaseManager()

    private var playtimeTimer: Timer?

    var commanderLevel: Int { progression.commanderLevel }

    // MARK: - Phase Transitions

    func startNewGame(name: String) {
        playerName = name
        economy = EconomyManager()
        progression = ProgressionManager()
        campaign = CampaignManager()
        base = BaseManager()
        heroes = GameStateManager.starterHeroes
        districts = GameStateManager.defaultDistricts
        activeSquad = [heroes[0].id, heroes[1].id]
        totalPlaytime = 0
        currentDistrict = "haven_district"
        currentPhase = .baseView
        startPlaytimeTracking()
    }

    func continueGame() {
        currentPhase = .baseView
        startPlaytimeTracking()
    }

    func enterCombat() {
        currentPhase = .combat
    }

    func exitCombat(victory: Bool) {
        if victory {
            economy.gain(["scrap": 50, "food": 20])
            progression.addXP(100)
        }
        currentPhase = .baseView
    }

    func openWorldMap() {
        currentPhase = .worldMap
    }

    func returnToBase() {
        currentPhase = .baseView
    }

    func returnToMainMenu() {
        stopPlaytimeTracking()
        currentPhase = .mainMenu
    }

    func pauseGame() {
        currentPhase = .paused
    }

    func resumeGame() {
        currentPhase = .playing
    }

    // MARK: - Playtime

    private func startPlaytimeTracking() {
        playtimeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.totalPlaytime += 1
        }
    }

    private func stopPlaytimeTracking() {
        playtimeTimer?.invalidate()
        playtimeTimer = nil
    }

    // MARK: - Save / Load

    func save(to slot: Int) {
        let state = SaveableState(
            playerName: playerName,
            currentDistrict: currentDistrict,
            activeSquad: activeSquad,
            heroes: heroes,
            districts: districts,
            totalPlaytime: totalPlaytime,
            economy: economy,
            progression: progression,
            campaign: campaign,
            base: base
        )
        SaveManager.shared.save(state: state, slot: slot)
    }

    func load(from slot: Int) -> Bool {
        guard let state = SaveManager.shared.load(slot: slot) else { return false }
        playerName = state.playerName
        currentDistrict = state.currentDistrict
        activeSquad = state.activeSquad
        heroes = state.heroes
        districts = state.districts
        totalPlaytime = state.totalPlaytime
        economy = state.economy
        progression = state.progression
        campaign = state.campaign
        base = state.base
        return true
    }

    // MARK: - Default Data

    static let starterHeroes: [Hero] = [
        Hero(
            id: "hero_kira", name: "Kira Voss", role: .vanguard, level: 1, rank: 2, xp: 0,
            maxHP: 320, attack: 45, defense: 38, speed: 22, critRate: 0.08,
            skills: [
                HeroSkill(id: "kira_s1", name: "Shield Wall", description: "Reduces incoming damage by 30% for 2 turns.", level: 1, maxLevel: 5, unlocked: true),
                HeroSkill(id: "kira_s2", name: "Rally Cry", description: "Boosts squad attack by 15%.", level: 0, maxLevel: 5, unlocked: false),
            ],
            gear: [
                GearSlot(id: "kira_w", slotType: "weapon", equippedItemName: "Rusted Machete", statBonus: ["attack": 5]),
                GearSlot(id: "kira_a", slotType: "armor", equippedItemName: "Scrap Vest", statBonus: ["defense": 8]),
                GearSlot(id: "kira_acc", slotType: "accessory", equippedItemName: nil, statBonus: [:]),
            ],
            bonds: [HeroBond(id: "kira_b1", partnerHeroId: "hero_dex", bondLevel: 1, bondName: "Old Partners")],
            backstory: "Former riot officer who held the line when the ash first fell. Now leads the Haven guard with an iron will.",
            portraitName: "portrait_kira"
        ),
        Hero(
            id: "hero_dex", name: "Dex Moreno", role: .marksman, level: 1, rank: 1, xp: 0,
            maxHP: 220, attack: 58, defense: 18, speed: 30, critRate: 0.18,
            skills: [
                HeroSkill(id: "dex_s1", name: "Headshot", description: "High-crit single target attack.", level: 1, maxLevel: 5, unlocked: true),
                HeroSkill(id: "dex_s2", name: "Overwatch", description: "Counter-attacks on enemy advance.", level: 0, maxLevel: 5, unlocked: false),
            ],
            gear: [
                GearSlot(id: "dex_w", slotType: "weapon", equippedItemName: "Hunting Rifle", statBonus: ["attack": 12]),
                GearSlot(id: "dex_a", slotType: "armor", equippedItemName: nil, statBonus: [:]),
                GearSlot(id: "dex_acc", slotType: "accessory", equippedItemName: nil, statBonus: [:]),
            ],
            bonds: [HeroBond(id: "dex_b1", partnerHeroId: "hero_kira", bondLevel: 1, bondName: "Old Partners")],
            backstory: "Resourceful scavenger and dead-eye shot. He was alone in the wastes for two years before Haven found him.",
            portraitName: "portrait_dex"
        ),
        Hero(
            id: "hero_mira", name: "Dr. Mira Chen", role: .medic, level: 1, rank: 2, xp: 0,
            maxHP: 250, attack: 22, defense: 25, speed: 26, critRate: 0.05,
            skills: [
                HeroSkill(id: "mira_s1", name: "Field Mend", description: "Heals one ally for 25% max HP.", level: 1, maxLevel: 5, unlocked: true),
                HeroSkill(id: "mira_s2", name: "Triage", description: "Heals all allies for a small amount.", level: 0, maxLevel: 5, unlocked: false),
            ],
            gear: [
                GearSlot(id: "mira_w", slotType: "weapon", equippedItemName: "Medical Prod", statBonus: ["attack": 3]),
                GearSlot(id: "mira_a", slotType: "armor", equippedItemName: "Lab Coat", statBonus: ["defense": 4]),
                GearSlot(id: "mira_acc", slotType: "accessory", equippedItemName: "First Aid Kit", statBonus: ["speed": 3]),
            ],
            bonds: [],
            backstory: "The last trained surgeon from the old city hospital. Her skills are worth more than gold in the wasteland.",
            portraitName: "portrait_mira"
        ),
        Hero(
            id: "hero_bolt", name: "Bolt", role: .engineer, level: 1, rank: 1, xp: 0,
            maxHP: 240, attack: 35, defense: 30, speed: 20, critRate: 0.10,
            skills: [
                HeroSkill(id: "bolt_s1", name: "Deploy Turret", description: "Places a turret that attacks each turn.", level: 1, maxLevel: 5, unlocked: true),
                HeroSkill(id: "bolt_s2", name: "Repair", description: "Restores an ally's armor.", level: 0, maxLevel: 5, unlocked: false),
            ],
            gear: [
                GearSlot(id: "bolt_w", slotType: "weapon", equippedItemName: "Wrench Hammer", statBonus: ["attack": 7]),
                GearSlot(id: "bolt_a", slotType: "armor", equippedItemName: nil, statBonus: [:]),
                GearSlot(id: "bolt_acc", slotType: "accessory", equippedItemName: nil, statBonus: [:]),
            ],
            bonds: [],
            backstory: "Nobody knows his real name. He showed up at Haven with a truck full of generators and a talent for keeping things running.",
            portraitName: "portrait_bolt"
        ),
        Hero(
            id: "hero_shade", name: "Shade", role: .scout, level: 1, rank: 1, xp: 0,
            maxHP: 200, attack: 42, defense: 15, speed: 38, critRate: 0.22,
            skills: [
                HeroSkill(id: "shade_s1", name: "Ambush", description: "Strike from stealth for double crit chance.", level: 1, maxLevel: 5, unlocked: true),
                HeroSkill(id: "shade_s2", name: "Recon", description: "Reveals enemy weaknesses.", level: 0, maxLevel: 5, unlocked: false),
            ],
            gear: [
                GearSlot(id: "shade_w", slotType: "weapon", equippedItemName: "Silenced Pistol", statBonus: ["attack": 8]),
                GearSlot(id: "shade_a", slotType: "armor", equippedItemName: "Shadow Cloak", statBonus: ["speed": 5]),
                GearSlot(id: "shade_acc", slotType: "accessory", equippedItemName: nil, statBonus: [:]),
            ],
            bonds: [],
            backstory: "She moves like smoke through the ruins. Haven's eyes and ears in the dead zones.",
            portraitName: "portrait_shade"
        ),
    ]

    static let defaultDistricts: [District] = [
        District(id: "haven_district", name: "Haven District", threatLevel: 1, isUnlocked: true, isCleared: true,
                 gridX: 3, gridY: 4, connectedTo: ["industrial_sector", "old_market"],
                 rewards: [:], description: "Your home base. Relatively safe."),
        District(id: "industrial_sector", name: "Industrial Sector", threatLevel: 3, isUnlocked: true, isCleared: false,
                 gridX: 1, gridY: 3, connectedTo: ["haven_district", "rail_yards"],
                 rewards: ["scrap": 120, "fuel": 40], description: "Crumbling factories hold valuable scrap and fuel reserves."),
        District(id: "old_market", name: "Old Market", threatLevel: 2, isUnlocked: true, isCleared: false,
                 gridX: 5, gridY: 3, connectedTo: ["haven_district", "hospital_ruins"],
                 rewards: ["food": 80, "medicine": 30], description: "The market district still has canned goods and medical supplies."),
        District(id: "rail_yards", name: "Rail Yards", threatLevel: 5, isUnlocked: false, isCleared: false,
                 gridX: 0, gridY: 1, connectedTo: ["industrial_sector", "ash_crater"],
                 rewards: ["fuel": 100, "electronics": 60], description: "Derailed cargo trains sit in mountains of ash."),
        District(id: "hospital_ruins", name: "Hospital Ruins", threatLevel: 4, isUnlocked: false, isCleared: false,
                 gridX: 6, gridY: 1, connectedTo: ["old_market", "broadcast_tower"],
                 rewards: ["medicine": 80, "electronics": 30], description: "Once a beacon of hope, now overrun."),
        District(id: "ash_crater", name: "Ash Crater", threatLevel: 8, isUnlocked: false, isCleared: false,
                 gridX: 1, gridY: 0, connectedTo: ["rail_yards"],
                 rewards: ["scrap": 300, "electronics": 100], description: "Ground zero. Extreme danger. Extreme reward."),
        District(id: "broadcast_tower", name: "Broadcast Tower", threatLevel: 6, isUnlocked: false, isCleared: false,
                 gridX: 5, gridY: 0, connectedTo: ["hospital_ruins"],
                 rewards: ["electronics": 120], description: "If the signal tower still works, you could call for help."),
    ]
}

// MARK: - Saveable State

struct SaveableState: Codable {
    let playerName: String
    let currentDistrict: String
    let activeSquad: [String]
    let heroes: [Hero]
    let districts: [District]
    let totalPlaytime: TimeInterval
    let economy: EconomyManager
    let progression: ProgressionManager
    let campaign: CampaignManager
    let base: BaseManager
}
