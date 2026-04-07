// District.swift
// ProjectAshfall
//
// A region on the world map that the player can explore.

import Foundation

// MARK: - District Threat Level

/// Coarse danger rating shown on the world map.
enum ThreatLevel: Int, Codable, CaseIterable, Comparable {
    case safe       = 0
    case low        = 1
    case moderate   = 2
    case high       = 3
    case severe     = 4
    case critical   = 5

    static func < (lhs: ThreatLevel, rhs: ThreatLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - District

/// One explorable zone on the world map.
struct District: Codable, Identifiable, Hashable {

    let id: UUID
    var name: String
    var threatLevel: ThreatLevel
    var isRevealed: Bool
    var isCleared: Bool
    var recommendedPower: Double
    var position: GridPosition
    /// Potential resource rewards for completing this district.
    var lootTable: [ResourceCost]
    /// IDs of story beats that trigger when this district is first entered.
    var storyTriggerIDs: [String]

    init(
        id: UUID = UUID(),
        name: String,
        threatLevel: ThreatLevel = .moderate,
        isRevealed: Bool = false,
        isCleared: Bool = false,
        recommendedPower: Double = 0,
        position: GridPosition = GridPosition(col: 0, row: 0),
        lootTable: [ResourceCost] = [],
        storyTriggerIDs: [String] = []
    ) {
        self.id = id
        self.name = name
        self.threatLevel = threatLevel
        self.isRevealed = isRevealed
        self.isCleared = isCleared
        self.recommendedPower = recommendedPower
        self.position = position
        self.lootTable = lootTable
        self.storyTriggerIDs = storyTriggerIDs
    }
}
