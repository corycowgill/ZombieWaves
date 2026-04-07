import { GRID } from './Constants';

// --- Isometric Coordinate Helpers ---

export interface ScreenPos {
  x: number;
  y: number;
}

export interface GridPos {
  col: number;
  row: number;
}

/** Convert grid position to isometric screen coordinates */
export function gridToIso(col: number, row: number, offsetX: number = 0, offsetY: number = 0): ScreenPos {
  return {
    x: (col - row) * (GRID.ISO_TILE_WIDTH / 2) + offsetX,
    y: (col + row) * (GRID.ISO_TILE_HEIGHT / 2) + offsetY,
  };
}

/** Convert screen coordinates to grid position */
export function isoToGrid(screenX: number, screenY: number, offsetX: number = 0, offsetY: number = 0): GridPos {
  const adjustedX = screenX - offsetX;
  const adjustedY = screenY - offsetY;
  const col = Math.floor((adjustedX / (GRID.ISO_TILE_WIDTH / 2) + adjustedY / (GRID.ISO_TILE_HEIGHT / 2)) / 2);
  const row = Math.floor((adjustedY / (GRID.ISO_TILE_HEIGHT / 2) - adjustedX / (GRID.ISO_TILE_WIDTH / 2)) / 2);
  return { col, row };
}

/** Check if a grid position is within bounds */
export function isValidGridPos(col: number, row: number, width: number = GRID.BASE_WIDTH, height: number = GRID.BASE_HEIGHT): boolean {
  return col >= 0 && col < width && row >= 0 && row < height;
}

/** Manhattan distance between two grid positions */
export function manhattanDistance(a: GridPos, b: GridPos): number {
  return Math.abs(a.col - b.col) + Math.abs(a.row - b.row);
}

/** Euclidean distance between two points */
export function distance(x1: number, y1: number, x2: number, y2: number): number {
  const dx = x1 - x2;
  const dy = y1 - y2;
  return Math.sqrt(dx * dx + dy * dy);
}

// --- A* Pathfinding ---

interface PathNode {
  pos: GridPos;
  g: number;
  h: number;
  f: number;
  parent: PathNode | null;
}

/** A* pathfinding on a grid */
export function findPath(
  start: GridPos,
  end: GridPos,
  isWalkable: (col: number, row: number) => boolean,
  width: number = GRID.BASE_WIDTH,
  height: number = GRID.BASE_HEIGHT
): GridPos[] | null {
  const key = (p: GridPos) => `${p.col},${p.row}`;

  const openSet: PathNode[] = [];
  const closedSet = new Set<string>();
  const gScores = new Map<string, number>();

  const startNode: PathNode = {
    pos: start,
    g: 0,
    h: manhattanDistance(start, end),
    f: manhattanDistance(start, end),
    parent: null,
  };
  openSet.push(startNode);
  gScores.set(key(start), 0);

  while (openSet.length > 0) {
    // Get node with lowest f-score
    openSet.sort((a, b) => a.f - b.f);
    const current = openSet.shift()!;
    const currentKey = key(current.pos);

    if (current.pos.col === end.col && current.pos.row === end.row) {
      // Reconstruct path
      const path: GridPos[] = [];
      let node: PathNode | null = current;
      while (node) {
        path.unshift(node.pos);
        node = node.parent;
      }
      return path;
    }

    closedSet.add(currentKey);

    // Check 4 neighbors
    const neighbors: GridPos[] = [
      { col: current.pos.col, row: current.pos.row - 1 },
      { col: current.pos.col, row: current.pos.row + 1 },
      { col: current.pos.col - 1, row: current.pos.row },
      { col: current.pos.col + 1, row: current.pos.row },
    ];

    for (const neighbor of neighbors) {
      const nKey = key(neighbor);
      if (closedSet.has(nKey)) continue;
      if (!isValidGridPos(neighbor.col, neighbor.row, width, height)) continue;
      if (!isWalkable(neighbor.col, neighbor.row)) continue;

      const tentativeG = current.g + 1;
      const existingG = gScores.get(nKey) ?? Infinity;

      if (tentativeG < existingG) {
        gScores.set(nKey, tentativeG);
        const h = manhattanDistance(neighbor, end);
        const node: PathNode = {
          pos: neighbor,
          g: tentativeG,
          h,
          f: tentativeG + h,
          parent: current,
        };

        const existingIndex = openSet.findIndex(n => key(n.pos) === nKey);
        if (existingIndex >= 0) {
          openSet[existingIndex] = node;
        } else {
          openSet.push(node);
        }
      }
    }
  }

  return null; // No path found
}

// --- Number Formatting ---

/** Format large numbers with K/M suffixes */
export function abbreviateNumber(n: number): string {
  if (n >= 1_000_000) return (n / 1_000_000).toFixed(1) + 'M';
  if (n >= 10_000) return (n / 1_000).toFixed(1) + 'K';
  return n.toString();
}

/** Format seconds as MM:SS */
export function formatTimer(seconds: number): string {
  const m = Math.floor(seconds / 60);
  const s = Math.floor(seconds % 60);
  return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
}

/** Format seconds as human-readable duration */
export function formatDuration(seconds: number): string {
  if (seconds < 60) return `${Math.floor(seconds)}s`;
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m`;
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  return `${h}h ${m}m`;
}

// --- Random ---

/** Random integer in range [min, max] inclusive */
export function randomInt(min: number, max: number): number {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

/** Random float in range [min, max] */
export function randomFloat(min: number, max: number): number {
  return Math.random() * (max - min) + min;
}

/** Pick random element from array */
export function randomPick<T>(arr: T[]): T {
  return arr[Math.floor(Math.random() * arr.length)];
}

/** Shuffle array in place (Fisher-Yates) */
export function shuffle<T>(arr: T[]): T[] {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

// --- UUID ---

/** Generate a simple UUID v4 */
export function uuid(): string {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}

// --- Clamp ---

export function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}
