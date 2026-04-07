// CombatMap.swift
// ProjectAshfall
//
// Tactical grid for combat encounters. Provides pathfinding (A*),
// line-of-sight checking, cover detection, and spawn zones.

import Foundation

// MARK: - Tile Type

/// Terrain classification for each cell on the combat grid.
enum TileType: String, Codable, CaseIterable {
    /// Open ground — no movement penalty, no cover.
    case open
    /// Partial cover — occupant gains a defense bonus against ranged attacks.
    case cover
    /// Impassable solid wall — blocks movement and line of sight.
    case wall
    /// Environmental hazard — deals damage to occupants each tick.
    case hazard
    /// Water — slows movement (costs 2 move), no cover.
    case water
    /// Explosive barrel / container — can be detonated dealing area damage.
    case explosive

    /// Whether units can stand on this tile.
    var isPassable: Bool {
        switch self {
        case .wall: return false
        default:    return true
        }
    }

    /// Whether this tile blocks line of sight.
    var blocksLoS: Bool {
        switch self {
        case .wall: return true
        default:    return false
        }
    }

    /// Movement cost multiplier (1 = normal).
    var movementCost: Int {
        switch self {
        case .water: return 2
        default:     return 1
        }
    }

    /// Flat cover bonus applied to the defender (0.0–1.0).
    var coverValue: Double {
        switch self {
        case .cover: return 0.25
        default:     return 0.0
        }
    }
}

// MARK: - Combat Tile

/// A single cell in the combat grid.
struct CombatTile: Codable, Hashable {
    let type: TileType
    let position: GridPosition
    /// Elevation (0 = ground level). Higher ground grants accuracy bonuses.
    var elevation: Int
    /// UUID of the CombatParticipant currently standing here, if any.
    var occupantID: UUID?

    var isOccupied: Bool { occupantID != nil }
}

// MARK: - Spawn Zone

/// A rectangular region where units may be placed at combat start.
struct SpawnZone: Codable {
    let origin: GridPosition
    let width: Int
    let height: Int
    let isPlayerZone: Bool

    /// All grid positions inside this zone.
    var positions: [GridPosition] {
        var result: [GridPosition] = []
        for c in origin.col ..< (origin.col + width) {
            for r in origin.row ..< (origin.row + height) {
                result.append(GridPosition(col: c, row: r))
            }
        }
        return result
    }
}

// MARK: - A* Node (internal)

/// Lightweight node used during pathfinding.
private struct PathNode: Comparable {
    let position: GridPosition
    let gCost: Int      // actual cost from start
    let hCost: Int      // heuristic (Manhattan distance)
    let parent: GridPosition?

    var fCost: Int { gCost + hCost }

    static func < (lhs: PathNode, rhs: PathNode) -> Bool {
        lhs.fCost < rhs.fCost
    }
}

// MARK: - Combat Map

/// Grid-based tactical map used by `CombatEngine`.
final class CombatMap {

    // MARK: Properties

    let width: Int
    let height: Int
    private(set) var tiles: [[CombatTile]]
    private(set) var spawnZones: [SpawnZone]

    // MARK: Init

    /// Creates a map filled with `.open` tiles of the given dimensions.
    init(width: Int, height: Int, spawnZones: [SpawnZone] = []) {
        self.width = width
        self.height = height
        self.spawnZones = spawnZones

        var grid: [[CombatTile]] = []
        for row in 0 ..< height {
            var rowTiles: [CombatTile] = []
            for col in 0 ..< width {
                let tile = CombatTile(
                    type: .open,
                    position: GridPosition(col: col, row: row),
                    elevation: 0
                )
                rowTiles.append(tile)
            }
            grid.append(rowTiles)
        }
        tiles = grid
    }

    // MARK: Tile Access

    /// Returns the tile at `pos`, or `nil` if out of bounds.
    func tile(at pos: GridPosition) -> CombatTile? {
        guard isInBounds(pos) else { return nil }
        return tiles[pos.row][pos.col]
    }

    /// Replaces the tile type at a position (for map generation).
    func setTileType(_ type: TileType, at pos: GridPosition) {
        guard isInBounds(pos) else { return }
        tiles[pos.row][pos.col] = CombatTile(
            type: type,
            position: pos,
            elevation: tiles[pos.row][pos.col].elevation,
            occupantID: tiles[pos.row][pos.col].occupantID
        )
    }

    /// Sets the elevation of a tile.
    func setElevation(_ elevation: Int, at pos: GridPosition) {
        guard isInBounds(pos) else { return }
        var t = tiles[pos.row][pos.col]
        t = CombatTile(type: t.type, position: t.position,
                        elevation: elevation, occupantID: t.occupantID)
        tiles[pos.row][pos.col] = t
    }

    // MARK: Occupant Management

    /// Places a participant on the grid.
    func placeOccupant(_ id: UUID, at pos: GridPosition) {
        guard isInBounds(pos) else { return }
        tiles[pos.row][pos.col] = CombatTile(
            type: tiles[pos.row][pos.col].type,
            position: pos,
            elevation: tiles[pos.row][pos.col].elevation,
            occupantID: id
        )
    }

    /// Removes any occupant from the given tile.
    func removeOccupant(at pos: GridPosition) {
        guard isInBounds(pos) else { return }
        let t = tiles[pos.row][pos.col]
        tiles[pos.row][pos.col] = CombatTile(
            type: t.type, position: t.position,
            elevation: t.elevation, occupantID: nil
        )
    }

    /// Whether the tile at `pos` can be walked on and is unoccupied.
    func isPassable(at pos: GridPosition) -> Bool {
        guard let t = tile(at: pos) else { return false }
        return t.type.isPassable && !t.isOccupied
    }

    // MARK: - Pathfinding (A*)

    /// Returns the shortest passable path from `start` to `goal`, excluding
    /// the start position. Returns `nil` if no path exists.
    func findPath(from start: GridPosition,
                  to goal: GridPosition) -> [GridPosition]? {
        guard isInBounds(start), isInBounds(goal) else { return nil }

        var openSet: [PathNode] = []
        var closedSet: Set<Int> = [] // packed position hashes
        var bestG: [Int: Int] = [:]  // packed pos -> best g cost

        func pack(_ p: GridPosition) -> Int { p.row * width + p.col }

        let startNode = PathNode(position: start, gCost: 0,
                                 hCost: start.distance(to: goal),
                                 parent: nil)
        openSet.append(startNode)
        bestG[pack(start)] = 0

        var cameFrom: [Int: GridPosition] = [:]

        while !openSet.isEmpty {
            openSet.sort() // lowest fCost first
            let current = openSet.removeFirst()
            let currentPack = pack(current.position)

            if current.position == goal {
                // Reconstruct
                var path: [GridPosition] = [current.position]
                var key = currentPack
                while let prev = cameFrom[key] {
                    if prev == start { break }
                    path.append(prev)
                    key = pack(prev)
                }
                return path.reversed()
            }

            closedSet.insert(currentPack)

            for neighbor in cardinalNeighbors(of: current.position) {
                let np = pack(neighbor)
                guard !closedSet.contains(np) else { continue }
                guard let t = tile(at: neighbor),
                      t.type.isPassable else { continue }
                // Allow moving into the goal even if occupied (attacker closing in)
                if t.isOccupied && neighbor != goal { continue }

                let tentativeG = current.gCost + t.type.movementCost
                if tentativeG < (bestG[np] ?? Int.max) {
                    bestG[np] = tentativeG
                    cameFrom[np] = current.position
                    let h = neighbor.distance(to: goal)
                    let node = PathNode(position: neighbor, gCost: tentativeG,
                                        hCost: h, parent: current.position)
                    openSet.append(node)
                }
            }
        }

        return nil // no path
    }

    // MARK: - Line of Sight

    /// Bresenham-style ray march from `from` to `to`. Returns `true` if no
    /// wall tile blocks the path.
    func hasLineOfSight(from source: GridPosition,
                        to target: GridPosition) -> Bool {
        let points = bresenhamLine(from: source, to: target)
        for point in points {
            // Skip source and target themselves
            if point == source || point == target { continue }
            guard let t = tile(at: point) else { return false }
            if t.type.blocksLoS { return false }
        }
        return true
    }

    // MARK: - Cover Detection

    /// Returns the cover bonus the defender at `defenderPos` receives against
    /// an attack originating from `attackerPos`.
    func coverBonus(at defenderPos: GridPosition,
                    from attackerPos: GridPosition) -> Double {
        guard let defenderTile = tile(at: defenderPos) else { return 0 }

        // Direct tile cover
        var bonus = defenderTile.type.coverValue

        // Check adjacent tiles between defender and attacker for additional
        // partial cover.
        let dx = attackerPos.col - defenderPos.col
        let dy = attackerPos.row - defenderPos.row
        let shieldCol = defenderPos.col + (dx != 0 ? (dx > 0 ? 1 : -1) : 0)
        let shieldRow = defenderPos.row + (dy != 0 ? (dy > 0 ? 1 : -1) : 0)
        let shieldPos = GridPosition(col: shieldCol, row: shieldRow)

        if let shieldTile = tile(at: shieldPos), shieldTile.type == .wall {
            bonus += 0.30
        }

        // Elevation advantage for the defender
        if let attackerTile = tile(at: attackerPos),
           defenderTile.elevation > attackerTile.elevation {
            bonus += 0.10
        }

        return min(0.75, bonus) // cap total cover
    }

    // MARK: - Spawn Helpers

    /// Returns all unoccupied positions in the player spawn zone.
    func availablePlayerSpawns() -> [GridPosition] {
        spawnZones.filter(\.isPlayerZone)
            .flatMap(\.positions)
            .filter { isPassable(at: $0) }
    }

    /// Returns all unoccupied positions in enemy spawn zones.
    func availableEnemySpawns() -> [GridPosition] {
        spawnZones.filter { !$0.isPlayerZone }
            .flatMap(\.positions)
            .filter { isPassable(at: $0) }
    }

    // MARK: - Hazard Queries

    /// Returns all tiles of a given type (useful for hazard ticking).
    func tiles(ofType type: TileType) -> [CombatTile] {
        tiles.flatMap { $0 }.filter { $0.type == type }
    }

    // MARK: - Private Helpers

    private func isInBounds(_ pos: GridPosition) -> Bool {
        pos.col >= 0 && pos.col < width && pos.row >= 0 && pos.row < height
    }

    private func cardinalNeighbors(of pos: GridPosition) -> [GridPosition] {
        [
            GridPosition(col: pos.col - 1, row: pos.row),
            GridPosition(col: pos.col + 1, row: pos.row),
            GridPosition(col: pos.col, row: pos.row - 1),
            GridPosition(col: pos.col, row: pos.row + 1)
        ].filter { isInBounds($0) }
    }

    /// Bresenham line algorithm returning all grid positions on the ray.
    private func bresenhamLine(from a: GridPosition,
                               to b: GridPosition) -> [GridPosition] {
        var points: [GridPosition] = []
        var x0 = a.col, y0 = a.row
        let x1 = b.col, y1 = b.row
        let dx = abs(x1 - x0)
        let dy = -abs(y1 - y0)
        let sx = x0 < x1 ? 1 : -1
        let sy = y0 < y1 ? 1 : -1
        var err = dx + dy

        while true {
            points.append(GridPosition(col: x0, row: y0))
            if x0 == x1 && y0 == y1 { break }
            let e2 = 2 * err
            if e2 >= dy {
                err += dy
                x0 += sx
            }
            if e2 <= dx {
                err += dx
                y0 += sy
            }
        }
        return points
    }
}
