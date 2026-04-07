import Foundation
import CoreGraphics

// MARK: - Game Constants

enum GameConstants {

    // MARK: - General
    static let gameTitle = "Project Ashfall"
    static let gameVersion = "1.0.0"
    static let buildNumber = 1

    // MARK: - Grid & Layout
    static let baseGridWidth = 20
    static let baseGridHeight = 20
    static let tileSize: CGFloat = 64.0
    static let isoTileWidth: CGFloat = 128.0
    static let isoTileHeight: CGFloat = 64.0

    // MARK: - Combat
    static let maxSquadSize = 5
    static let maxSupportUnits = 3
    static let combatTickRate: TimeInterval = 1.0 / 60.0
    static let tacticalPauseSlowdown: Double = 0.1
    static let baseCritMultiplier: Double = 1.5
    static let coverDamageReduction: Double = 0.4
    static let flankingDamageBonus: Double = 0.25
    static let missionTimeLimitShort: TimeInterval = 120.0
    static let missionTimeLimitNormal: TimeInterval = 300.0
    static let missionTimeLimitBoss: TimeInterval = 480.0

    // MARK: - Heroes
    static let maxHeroLevel = 60
    static let maxHeroRank = 5
    static let maxMorale = 100
    static let minMorale = 0
    static let moraleBoostPerEvent = 10
    static let moralePenaltyPerDefeat = 5
    static let bondLevelThresholds = [0, 100, 300, 600, 1000]
    static let experiencePerLevel: [Int] = {
        var xp = [Int]()
        for level in 0..<60 {
            xp.append(100 + (level * level * 10))
        }
        return xp
    }()

    // MARK: - Base Building
    static let maxBuildingLevel = 10
    static let maxWalls = 40
    static let maxTurrets = 12
    static let maxTraps = 20
    static let baseUpgradeTimeMultiplier: TimeInterval = 1.0 // seconds per unit
    static let adjacencyBonusPercent: Double = 0.10

    // MARK: - Resources
    static let startingFood = 500
    static let startingWater = 500
    static let startingFuel = 200
    static let startingScrap = 300
    static let startingElectronics = 50
    static let startingMedicine = 100
    static let resourceTickInterval: TimeInterval = 60.0 // seconds between production ticks
    static let maxResourceStorage = 99999

    // MARK: - World Map
    static let totalDistricts = 24
    static let districtsPerAct = 5
    static let fogRevealRadius = 2
    static let expeditionFuelCost = 50

    // MARK: - Campaign
    static let totalActs = 5
    static let chaptersPerAct = 5

    // MARK: - Progression
    static let maxCommanderLevel = 50
    static let commanderXPPerMission = 100
    static let commanderXPPerBoss = 500

    // MARK: - Economy Balance
    static let upgradeCostScaling: Double = 1.35  // cost multiplier per level
    static let missionRewardBase = 100
    static let scavengingLootMultiplierRange: ClosedRange<Double> = 0.8...1.5
    static let maxUpgradeQueueSize = 3

    // MARK: - Save System
    static let maxSaveSlots = 5
    static let autoSaveSlotIndex = 0
    static let saveDirectoryName = "ProjectAshfall_Saves"

    // MARK: - Audio
    static let defaultMusicVolume: Float = 0.6
    static let defaultSFXVolume: Float = 0.8
    static let musicFadeDuration: TimeInterval = 1.5

    // MARK: - Animation
    static let buildingUpgradeAnimationDuration: TimeInterval = 0.5
    static let damageNumberFloatDuration: TimeInterval = 1.0
    static let screenTransitionDuration: TimeInterval = 0.3
    static let zoomTransitionDuration: TimeInterval = 0.4
}

// MARK: - Notification Names

extension Notification.Name {
    static let resourcesUpdated = Notification.Name("resourcesUpdated")
    static let buildingUpgraded = Notification.Name("buildingUpgraded")
    static let heroLeveledUp = Notification.Name("heroLeveledUp")
    static let missionCompleted = Notification.Name("missionCompleted")
    static let campaignChapterUnlocked = Notification.Name("campaignChapterUnlocked")
    static let baseEventTriggered = Notification.Name("baseEventTriggered")
    static let combatStateChanged = Notification.Name("combatStateChanged")
    static let squadUpdated = Notification.Name("squadUpdated")
    static let districtCleared = Notification.Name("districtCleared")
    static let gameStateSaved = Notification.Name("gameStateSaved")
}
