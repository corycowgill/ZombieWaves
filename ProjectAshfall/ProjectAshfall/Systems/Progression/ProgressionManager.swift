// ProgressionManager.swift
// ProjectAshfall
//
// Tracks commander level, chapter unlocks, achievements, milestone rewards,
// hero unlock schedule, and difficulty scaling. This is the player's
// long-term meta-progression layer.

import Foundation

// MARK: - Commander Level

/// Snapshot of the player's overall progress.
struct CommanderProfile: Codable {
    var level: Int
    var totalExperience: Double
    var currentActExperience: Double
    /// Total missions completed across all acts.
    var missionsCompleted: Int
    /// Total enemies eliminated.
    var enemiesDefeated: Int
    /// Total buildings constructed.
    var buildingsConstructed: Int

    /// Experience required to reach the next commander level.
    /// Smooth curve: 200 * level * 1.12^level.
    var experienceToNextLevel: Double {
        200.0 * Double(level) * pow(1.12, Double(level))
    }

    static let starter = CommanderProfile(
        level: 1, totalExperience: 0, currentActExperience: 0,
        missionsCompleted: 0, enemiesDefeated: 0, buildingsConstructed: 0
    )
}

// MARK: - Chapter Unlock

/// A gated content unlock tied to the campaign.
struct ChapterUnlock: Codable, Identifiable {
    let id: String
    let requiredAct: Int        // 1-5
    let requiredChapter: Int    // chapter within the act
    let description: String
    var isUnlocked: Bool
}

// MARK: - Achievement

/// A trackable achievement with progress and reward.
struct Achievement: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    /// Number of times the condition must be met to complete.
    let targetCount: Int
    var currentCount: Int
    var isCompleted: Bool
    var rewardClaimed: Bool
    /// Resources awarded on completion.
    let rewards: [ResourceCost]

    var progress: Double {
        guard targetCount > 0 else { return 1.0 }
        return min(1.0, Double(currentCount) / Double(targetCount))
    }

    init(id: String, name: String, description: String,
         targetCount: Int, rewards: [ResourceCost] = []) {
        self.id = id
        self.name = name
        self.description = description
        self.targetCount = targetCount
        self.currentCount = 0
        self.isCompleted = false
        self.rewardClaimed = false
        self.rewards = rewards
    }
}

// MARK: - Milestone Reward

/// A reward granted when the commander reaches a specific level.
struct MilestoneReward: Codable {
    let commanderLevel: Int
    let rewards: [ResourceCost]
    let heroUnlockID: UUID?
    let description: String
    var claimed: Bool
}

// MARK: - Hero Unlock Entry

/// Maps a hero to the campaign beat that unlocks them.
struct HeroUnlockSchedule: Codable {
    let heroID: UUID
    let heroName: String
    let requiredAct: Int
    let requiredChapter: Int
    var isUnlocked: Bool
}

// MARK: - Progression Manager

/// Central hub for all meta-progression systems. Other managers report
/// events here; ProgressionManager updates state and fires rewards.
final class ProgressionManager {

    // MARK: Properties

    private(set) var commander: CommanderProfile
    private(set) var chapterUnlocks: [ChapterUnlock]
    private(set) var achievements: [Achievement]
    private(set) var milestones: [MilestoneReward]
    private(set) var heroSchedule: [HeroUnlockSchedule]

    /// Callback fired when the commander levels up. UI can subscribe to
    /// present a level-up animation.
    var onLevelUp: ((Int) -> Void)?

    /// Callback fired when an achievement completes.
    var onAchievementCompleted: ((Achievement) -> Void)?

    // MARK: Init

    init() {
        self.commander = .starter
        self.chapterUnlocks = ProgressionManager.defaultChapterUnlocks()
        self.achievements = ProgressionManager.defaultAchievements()
        self.milestones = ProgressionManager.defaultMilestones()
        self.heroSchedule = []
    }

    // MARK: - Experience

    /// Awards commander XP and checks for level-ups.
    func awardExperience(_ amount: Double) {
        commander.totalExperience += amount
        commander.currentActExperience += amount

        while commander.currentActExperience >= commander.experienceToNextLevel {
            commander.currentActExperience -= commander.experienceToNextLevel
            commander.level += 1
            onLevelUp?(commander.level)
            checkMilestones()
        }
    }

    // MARK: - Mission Tracking

    /// Records a completed mission and updates related achievements.
    func recordMissionCompleted(enemiesDefeated: Int) {
        commander.missionsCompleted += 1
        commander.enemiesDefeated += enemiesDefeated

        incrementAchievement("missions_completed")
        incrementAchievement("enemies_defeated", by: enemiesDefeated)
    }

    /// Records a building being constructed.
    func recordBuildingConstructed() {
        commander.buildingsConstructed += 1
        incrementAchievement("buildings_constructed")
    }

    // MARK: - Chapter Unlocks

    /// Unlocks all content gated behind the given act and chapter.
    func unlockChapter(act: Int, chapter: Int) {
        for i in chapterUnlocks.indices {
            if chapterUnlocks[i].requiredAct <= act
               && chapterUnlocks[i].requiredChapter <= chapter {
                chapterUnlocks[i].isUnlocked = true
            }
        }
        // Also unlock heroes scheduled for this point
        for i in heroSchedule.indices {
            if heroSchedule[i].requiredAct <= act
               && heroSchedule[i].requiredChapter <= chapter {
                heroSchedule[i].isUnlocked = true
            }
        }
    }

    /// Returns `true` if content at the given act/chapter is available.
    func isUnlocked(act: Int, chapter: Int) -> Bool {
        // Everything in act 1, chapter 1 is always available
        if act == 1 && chapter == 1 { return true }
        return chapterUnlocks.contains {
            $0.requiredAct == act && $0.requiredChapter == chapter && $0.isUnlocked
        }
    }

    // MARK: - Achievements

    /// Increments the counter on an achievement by `count`.
    func incrementAchievement(_ id: String, by count: Int = 1) {
        guard let idx = achievements.firstIndex(where: { $0.id == id }) else {
            return
        }
        guard !achievements[idx].isCompleted else { return }

        achievements[idx].currentCount += count
        if achievements[idx].currentCount >= achievements[idx].targetCount {
            achievements[idx].isCompleted = true
            onAchievementCompleted?(achievements[idx])
        }
    }

    /// Claims the reward for a completed achievement. Returns the rewards
    /// if successful, or `nil` if not claimable.
    func claimAchievementReward(_ id: String) -> [ResourceCost]? {
        guard let idx = achievements.firstIndex(where: { $0.id == id }),
              achievements[idx].isCompleted,
              !achievements[idx].rewardClaimed else {
            return nil
        }
        achievements[idx].rewardClaimed = true
        return achievements[idx].rewards
    }

    // MARK: - Milestones

    /// Claims the milestone reward for the given commander level.
    func claimMilestone(forLevel level: Int) -> MilestoneReward? {
        guard let idx = milestones.firstIndex(where: {
            $0.commanderLevel == level && !$0.claimed
        }), commander.level >= level else {
            return nil
        }
        milestones[idx].claimed = true
        return milestones[idx]
    }

    // MARK: - Hero Unlock Schedule

    /// Registers a hero in the unlock schedule.
    func registerHero(_ heroID: UUID, name: String, act: Int, chapter: Int) {
        let entry = HeroUnlockSchedule(
            heroID: heroID, heroName: name,
            requiredAct: act, requiredChapter: chapter,
            isUnlocked: false
        )
        heroSchedule.append(entry)
    }

    /// Returns all heroes unlocked by the given campaign progress.
    func unlockedHeroes(byAct act: Int, chapter: Int) -> [HeroUnlockSchedule] {
        heroSchedule.filter {
            $0.requiredAct <= act && $0.requiredChapter <= chapter
        }
    }

    // MARK: - Difficulty Scaling

    /// Suggests a power level for enemies in a district based on the
    /// player's current commander level and squad strength.
    func recommendedEnemyPower(forCommanderLevel level: Int,
                               squadPower: Double) -> Double {
        // Enemies scale to 90 % of squad power + a per-level bump.
        // This keeps fights challenging but not brutally punishing.
        let basePower = squadPower * 0.90
        let levelBonus = Double(level) * 5.0
        return basePower + levelBonus
    }

    // MARK: - Private Helpers

    private func checkMilestones() {
        for milestone in milestones where !milestone.claimed
            && milestone.commanderLevel == commander.level {
            // Auto-notify (claiming is manual via UI)
            break
        }
    }

    // MARK: - Default Data

    private static func defaultChapterUnlocks() -> [ChapterUnlock] {
        [
            ChapterUnlock(id: "act1_ch1", requiredAct: 1, requiredChapter: 1,
                          description: "Tutorial: Establish Shelter", isUnlocked: true),
            ChapterUnlock(id: "act1_ch2", requiredAct: 1, requiredChapter: 2,
                          description: "First Wave Defense", isUnlocked: false),
            ChapterUnlock(id: "act2_ch1", requiredAct: 2, requiredChapter: 1,
                          description: "The Outbreak Origin", isUnlocked: false),
            ChapterUnlock(id: "act3_ch1", requiredAct: 3, requiredChapter: 1,
                          description: "Rival Factions Emerge", isUnlocked: false),
            ChapterUnlock(id: "act4_ch1", requiredAct: 4, requiredChapter: 1,
                          description: "Reclaim the Grid", isUnlocked: false),
            ChapterUnlock(id: "act5_ch1", requiredAct: 5, requiredChapter: 1,
                          description: "Assault on Origin Site", isUnlocked: false),
        ]
    }

    private static func defaultAchievements() -> [Achievement] {
        [
            Achievement(id: "missions_completed", name: "Field Operator",
                        description: "Complete 10 missions.", targetCount: 10,
                        rewards: [ResourceCost(.scrap, 50)]),
            Achievement(id: "enemies_defeated", name: "Exterminator",
                        description: "Defeat 100 enemies.", targetCount: 100,
                        rewards: [ResourceCost(.militaryComponents, 10)]),
            Achievement(id: "buildings_constructed", name: "Architect",
                        description: "Construct 15 buildings.", targetCount: 15,
                        rewards: [ResourceCost(.electronics, 20)]),
            Achievement(id: "perfect_clear", name: "Flawless Victory",
                        description: "Win a mission with no hero damage.",
                        targetCount: 1,
                        rewards: [ResourceCost(.powerCells, 5)]),
            Achievement(id: "five_heroes", name: "Squad Leader",
                        description: "Unlock 5 different heroes.", targetCount: 5,
                        rewards: [ResourceCost(.scrap, 100)]),
        ]
    }

    private static func defaultMilestones() -> [MilestoneReward] {
        [
            MilestoneReward(commanderLevel: 3,
                            rewards: [ResourceCost(.scrap, 50), ResourceCost(.food, 30)],
                            heroUnlockID: nil,
                            description: "Reached Commander Level 3",
                            claimed: false),
            MilestoneReward(commanderLevel: 5,
                            rewards: [ResourceCost(.electronics, 15)],
                            heroUnlockID: nil,
                            description: "Reached Commander Level 5",
                            claimed: false),
            MilestoneReward(commanderLevel: 10,
                            rewards: [ResourceCost(.militaryComponents, 20),
                                      ResourceCost(.powerCells, 5)],
                            heroUnlockID: nil,
                            description: "Reached Commander Level 10",
                            claimed: false),
            MilestoneReward(commanderLevel: 15,
                            rewards: [ResourceCost(.bioSamples, 10),
                                      ResourceCost(.researchData, 10)],
                            heroUnlockID: nil,
                            description: "Reached Commander Level 15",
                            claimed: false),
        ]
    }
}
