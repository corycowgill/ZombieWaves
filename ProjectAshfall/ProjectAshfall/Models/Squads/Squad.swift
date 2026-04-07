// Squad.swift
// ProjectAshfall
//
// A deployment group of heroes sent on missions or into combat.

import Foundation

/// Maximum heroes allowed in a single squad.
let kMaxSquadSize: Int = 4

/// A named group of heroes deployed together.
struct Squad: Codable, Identifiable, Hashable {

    let id: UUID
    var name: String
    var heroIDs: [UUID]

    /// Computed squad power for matchmaking and difficulty checks.
    var powerRating: Double = 0

    var isFull: Bool { heroIDs.count >= kMaxSquadSize }
    var isEmpty: Bool { heroIDs.isEmpty }

    init(id: UUID = UUID(), name: String = "Alpha Squad", heroIDs: [UUID] = []) {
        self.id = id
        self.name = name
        self.heroIDs = heroIDs
    }

    mutating func addHero(_ heroID: UUID) {
        guard !isFull, !heroIDs.contains(heroID) else { return }
        heroIDs.append(heroID)
    }

    mutating func removeHero(_ heroID: UUID) {
        heroIDs.removeAll { $0 == heroID }
    }
}
