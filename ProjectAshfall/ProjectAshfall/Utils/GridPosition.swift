import Foundation

/// Represents a position on the isometric grid
struct GridPosition: Hashable, Codable, Equatable {
    let col: Int
    let row: Int

    // MARK: - Neighbors

    var north: GridPosition { GridPosition(col: col, row: row - 1) }
    var south: GridPosition { GridPosition(col: col, row: row + 1) }
    var east: GridPosition { GridPosition(col: col + 1, row: row) }
    var west: GridPosition { GridPosition(col: col - 1, row: row) }

    var neighbors: [GridPosition] {
        [north, south, east, west]
    }

    var allNeighbors: [GridPosition] {
        [north, south, east, west,
         GridPosition(col: col - 1, row: row - 1),
         GridPosition(col: col + 1, row: row - 1),
         GridPosition(col: col - 1, row: row + 1),
         GridPosition(col: col + 1, row: row + 1)]
    }

    /// Manhattan distance to another position
    func distance(to other: GridPosition) -> Int {
        abs(col - other.col) + abs(row - other.row)
    }

    /// Check if position is within grid bounds
    func isValid(width: Int, height: Int) -> Bool {
        col >= 0 && col < width && row >= 0 && row < height
    }
}

// MARK: - A* Pathfinding

struct PathFinder {

    struct PathNode: Comparable {
        let position: GridPosition
        let gCost: Int  // cost from start
        let hCost: Int  // estimated cost to end
        var fCost: Int { gCost + hCost }
        let parent: GridPosition?

        static func < (lhs: PathNode, rhs: PathNode) -> Bool {
            lhs.fCost < rhs.fCost
        }
    }

    /// Find shortest path using A* algorithm
    /// - Parameters:
    ///   - from: Starting grid position
    ///   - to: Target grid position
    ///   - isWalkable: Closure that returns whether a position can be traversed
    /// - Returns: Array of positions forming the path, or nil if no path exists
    static func findPath(
        from start: GridPosition,
        to end: GridPosition,
        isWalkable: (GridPosition) -> Bool
    ) -> [GridPosition]? {
        var openSet: [PathNode] = [PathNode(position: start, gCost: 0, hCost: start.distance(to: end), parent: nil)]
        var closedSet: Set<GridPosition> = []
        var cameFrom: [GridPosition: GridPosition] = [:]
        var gScores: [GridPosition: Int] = [start: 0]

        while !openSet.isEmpty {
            openSet.sort()
            let current = openSet.removeFirst()

            if current.position == end {
                // Reconstruct path
                var path: [GridPosition] = [end]
                var pos = end
                while let prev = cameFrom[pos] {
                    path.insert(prev, at: 0)
                    pos = prev
                }
                return path
            }

            closedSet.insert(current.position)

            for neighbor in current.position.neighbors {
                guard !closedSet.contains(neighbor), isWalkable(neighbor) else { continue }

                let tentativeG = current.gCost + 1

                if tentativeG < (gScores[neighbor] ?? Int.max) {
                    gScores[neighbor] = tentativeG
                    cameFrom[neighbor] = current.position

                    if !openSet.contains(where: { $0.position == neighbor }) {
                        openSet.append(PathNode(
                            position: neighbor,
                            gCost: tentativeG,
                            hCost: neighbor.distance(to: end),
                            parent: current.position
                        ))
                    }
                }
            }
        }

        return nil // No path found
    }

    /// Find all positions within a given range
    static func positionsInRange(from center: GridPosition, range: Int, isWalkable: (GridPosition) -> Bool) -> [GridPosition] {
        var result: [GridPosition] = []
        for dc in -range...range {
            for dr in -range...range {
                let pos = GridPosition(col: center.col + dc, row: center.row + dr)
                if center.distance(to: pos) <= range && isWalkable(pos) {
                    result.append(pos)
                }
            }
        }
        return result
    }
}
