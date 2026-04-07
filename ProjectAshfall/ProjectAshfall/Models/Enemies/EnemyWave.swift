// EnemyWave.swift
// ProjectAshfall
//
// Wave composition and generation for base-defense encounters.
// The WaveGenerator produces escalating waves of enemies with increasing
// difficulty, mixed enemy types, and periodic boss encounters.

import Foundation

// MARK: - Wave Enemy Entry

/// A single group of enemies within a wave, spawned at a specific delay.
struct WaveEnemyEntry: Codable, Hashable {
    /// The type of enemy to spawn.
    let enemyType: EnemyType
    /// Number of enemies in this group.
    let count: Int
    /// Seconds after wave start before this group spawns.
    let spawnDelay: TimeInterval
    /// Level override. Nil uses the wave's base level.
    let levelOverride: Int?

    init(
        enemyType: EnemyType,
        count: Int,
        spawnDelay: TimeInterval = 0,
        levelOverride: Int? = nil
    ) {
        self.enemyType = enemyType
        self.count = count
        self.spawnDelay = spawnDelay
        self.levelOverride = levelOverride
    }
}

// MARK: - Wave Composition

/// Defines the full composition and timing of a single defense wave.
struct WaveComposition: Codable, Identifiable, Hashable {
    let id: UUID
    /// Wave number (1-based).
    let waveNumber: Int
    /// Base enemy level for this wave.
    let baseLevel: Int
    /// All enemy groups in this wave.
    let entries: [WaveEnemyEntry]
    /// Total time in seconds before the next wave begins.
    let durationBeforeNext: TimeInterval
    /// Whether this wave includes a boss encounter.
    let isBossWave: Bool
    /// Bonus resources awarded for clearing this wave.
    let clearRewards: [ResourceCost]

    /// Total enemy count across all entries.
    var totalEnemyCount: Int {
        entries.reduce(0) { $0 + $1.count }
    }

    /// All unique enemy families present in this wave.
    var presentFamilies: Set<EnemyFamily> {
        Set(entries.map { $0.enemyType.family })
    }

    init(
        id: UUID = UUID(),
        waveNumber: Int,
        baseLevel: Int,
        entries: [WaveEnemyEntry],
        durationBeforeNext: TimeInterval = 30,
        isBossWave: Bool = false,
        clearRewards: [ResourceCost] = []
    ) {
        self.id = id
        self.waveNumber = waveNumber
        self.baseLevel = baseLevel
        self.entries = entries
        self.durationBeforeNext = durationBeforeNext
        self.isBossWave = isBossWave
        self.clearRewards = clearRewards
    }
}

// MARK: - Wave Generator

/// Procedurally generates escalating waves of enemies for defense mode.
/// Difficulty scales based on wave number, player power level, and current
/// game act.
final class WaveGenerator {

    /// Base difficulty multiplier (higher = harder).
    let difficultyScale: Double

    /// Number of waves between boss encounters.
    let bossInterval: Int

    init(difficultyScale: Double = 1.0, bossInterval: Int = 5) {
        self.difficultyScale = difficultyScale
        self.bossInterval = max(1, bossInterval)
    }

    // MARK: - Generation

    /// Generates a sequence of waves for a defense encounter.
    /// - Parameters:
    ///   - count: Number of waves to generate.
    ///   - startingLevel: Enemy level for the first wave.
    ///   - families: Enemy families allowed to appear. Defaults to all.
    /// - Returns: An ordered array of wave compositions.
    func generateWaves(
        count: Int,
        startingLevel: Int = 1,
        families: [EnemyFamily] = EnemyFamily.allCases.map { $0 }
    ) -> [WaveComposition] {
        guard count > 0 else { return [] }
        var waves: [WaveComposition] = []

        for i in 1...count {
            let level = startingLevel + Int(Double(i - 1) * 0.8 * difficultyScale)
            let isBoss = (i % bossInterval == 0)
            let wave = generateSingleWave(
                number: i,
                level: level,
                isBoss: isBoss,
                families: families
            )
            waves.append(wave)
        }
        return waves
    }

    /// Generates a single wave composition.
    private func generateSingleWave(
        number: Int,
        level: Int,
        isBoss: Bool,
        families: [EnemyFamily]
    ) -> WaveComposition {
        var entries: [WaveEnemyEntry] = []
        let baseCount = 3 + Int(Double(number) * 1.2 * difficultyScale)

        // Select enemy types from allowed families.
        let availableTypes = EnemyType.allCases.filter { families.contains($0.family) }
        guard !availableTypes.isEmpty else {
            return WaveComposition(waveNumber: number, baseLevel: level, entries: [])
        }

        // Distribute enemies into 2-4 spawn groups with staggered delays.
        let groupCount = min(4, max(2, number / 2 + 1))
        let enemiesPerGroup = max(1, baseCount / groupCount)

        for g in 0..<groupCount {
            let typeIndex = (number + g) % availableTypes.count
            let delay = TimeInterval(g) * (5.0 + Double(number) * 0.5)
            entries.append(WaveEnemyEntry(
                enemyType: availableTypes[typeIndex],
                count: enemiesPerGroup,
                spawnDelay: delay
            ))
        }

        // Add a boss to boss waves.
        if isBoss {
            let bossType = pickBossType(from: families)
            entries.append(WaveEnemyEntry(
                enemyType: bossType,
                count: 1,
                spawnDelay: TimeInterval(groupCount) * 6.0,
                levelOverride: level + 3
            ))
        }

        // Scale rewards with wave number.
        let rewards = generateRewards(waveNumber: number, isBoss: isBoss)

        let pauseDuration: TimeInterval = isBoss ? 45 : 30

        return WaveComposition(
            waveNumber: number,
            baseLevel: level,
            entries: entries,
            durationBeforeNext: pauseDuration,
            isBossWave: isBoss,
            clearRewards: rewards
        )
    }

    /// Picks a suitable boss-tier enemy type from the given families.
    private func pickBossType(from families: [EnemyFamily]) -> EnemyType {
        if families.contains(.infected) { return .bruiser }
        if families.contains(.raider)   { return .raiderBrute }
        if families.contains(.militia)  { return .militiaSoldier }
        return .rogueMutantHandler
    }

    /// Generates resource rewards for clearing a wave.
    private func generateRewards(waveNumber: Int, isBoss: Bool) -> [ResourceCost] {
        let baseScrap = 10 + waveNumber * 5
        var rewards = [ResourceCost(.scrap, baseScrap)]

        if waveNumber >= 3 {
            rewards.append(ResourceCost(.electronics, waveNumber))
        }
        if isBoss {
            rewards.append(ResourceCost(.militaryComponents, 3 + waveNumber / 2))
            rewards.append(ResourceCost(.bioSamples, 2 + waveNumber / 3))
        }
        return rewards
    }
}
