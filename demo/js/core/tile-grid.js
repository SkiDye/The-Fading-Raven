/**
 * THE FADING RAVEN - Tile Grid System
 * Handles tile-based grid, pathfinding (A*), and line of sight
 */

const TileGrid = {
    // Tile type constants (matching StationGenerator)
    TILE_FLOOR: 'floor',
    TILE_WALL: 'wall',
    TILE_COVER: 'cover',
    TILE_SPAWN: 'spawn',
    TILE_DEPLOY: 'deploy',
    TILE_ELEVATED: 'elevated',
    TILE_LOWERED: 'lowered',
    TILE_CORRIDOR: 'corridor',
    TILE_HAZARD: 'hazard',
    TILE_CHOKE: 'choke',
    TILE_FACILITY: 'facility',
    TILE_AIRLOCK: 'airlock',

    // Grid data
    width: 0,
    height: 0,
    tiles: [],
    tileSize: 40,

    // Terrain modifiers
    COVER_REDUCTION: 0.5,
    TERRAIN_MODIFIERS: {
        floor: { defense: 0, range: 0, damage: 0 },
        elevated: { defense: 0, range: 1, damage: 0 },
        lowered: { defense: -10, range: 0, damage: 0 },
        cover: { defense: 25, range: 0, damage: 0 },
        hazard: { defense: 0, range: 0, damage: 5 },
        choke: { defense: 10, range: 0, damage: 0 },
        corridor: { defense: 0, range: 0, damage: 0 },
        facility: { defense: 0, range: 0, damage: 0 },
        airlock: { defense: 0, range: 0, damage: 0 },
    },

    /**
     * Initialize grid from layout data
     */
    init(layout) {
        this.width = layout.width;
        this.height = layout.height;
        this.tiles = [];

        for (let y = 0; y < this.height; y++) {
            this.tiles[y] = [];
            for (let x = 0; x < this.width; x++) {
                const tileData = layout.tiles[y]?.[x] || { type: this.TILE_FLOOR };
                this.tiles[y][x] = {
                    x: x,
                    y: y,
                    type: tileData.type || this.TILE_FLOOR,
                    walkable: tileData.type !== this.TILE_WALL,
                    blocksLOS: tileData.type === this.TILE_WALL,
                    coverValue: tileData.type === this.TILE_COVER ? this.COVER_REDUCTION : 0,
                    occupied: null,
                    effect: null,
                };
            }
        }

        return this;
    },

    /**
     * Initialize from StationGenerator layout (numeric grid)
     */
    initFromStation(stationLayout) {
        this.width = stationLayout.width;
        this.height = stationLayout.height;
        this.tiles = [];

        // Map StationGenerator tile types to TileGrid types
        const tileTypeMap = {
            0: this.TILE_WALL,      // VOID -> Wall (impassable)
            1: this.TILE_FLOOR,     // FLOOR
            2: this.TILE_WALL,      // WALL
            3: this.TILE_FACILITY,  // FACILITY
            4: this.TILE_AIRLOCK,   // AIRLOCK
            5: this.TILE_ELEVATED,  // ELEVATED
            6: this.TILE_LOWERED,   // LOWERED
            7: this.TILE_CORRIDOR,  // CORRIDOR
            8: this.TILE_COVER,     // COVER
            9: this.TILE_HAZARD,    // HAZARD
            10: this.TILE_CHOKE,    // CHOKE
        };

        for (let y = 0; y < this.height; y++) {
            this.tiles[y] = [];
            for (let x = 0; x < this.width; x++) {
                const numericType = stationLayout.grid[y]?.[x] ?? 0;
                const type = tileTypeMap[numericType] || this.TILE_WALL;

                const walkableTypes = [
                    this.TILE_FLOOR, this.TILE_FACILITY, this.TILE_AIRLOCK,
                    this.TILE_ELEVATED, this.TILE_LOWERED, this.TILE_CORRIDOR,
                    this.TILE_COVER, this.TILE_HAZARD, this.TILE_CHOKE,
                ];

                this.tiles[y][x] = {
                    x: x,
                    y: y,
                    type: type,
                    walkable: walkableTypes.includes(type),
                    blocksLOS: type === this.TILE_WALL,
                    coverValue: this._getCoverValue(type),
                    terrainModifier: this.TERRAIN_MODIFIERS[type] || this.TERRAIN_MODIFIERS.floor,
                    occupied: null,
                    effect: null,
                };
            }
        }

        return this;
    },

    /**
     * Get cover value for a tile type
     */
    _getCoverValue(type) {
        switch (type) {
            case this.TILE_COVER: return this.COVER_REDUCTION;
            case this.TILE_CHOKE: return 0.2;
            default: return 0;
        }
    },

    /**
     * Get terrain modifier at position
     */
    getTerrainModifier(x, y) {
        const tile = this.getTile(x, y);
        if (!tile) return { defense: 0, range: 0, damage: 0 };
        return tile.terrainModifier || this.TERRAIN_MODIFIERS.floor;
    },

    /**
     * Create empty grid
     */
    createEmpty(width, height) {
        this.width = width;
        this.height = height;
        this.tiles = [];

        for (let y = 0; y < height; y++) {
            this.tiles[y] = [];
            for (let x = 0; x < width; x++) {
                this.tiles[y][x] = {
                    x: x,
                    y: y,
                    type: this.TILE_FLOOR,
                    walkable: true,
                    blocksLOS: false,
                    coverValue: 0,
                    occupied: null,
                    effect: null,
                };
            }
        }

        return this;
    },

    /**
     * Get tile at position
     */
    getTile(x, y) {
        if (x < 0 || x >= this.width || y < 0 || y >= this.height) {
            return null;
        }
        return this.tiles[y][x];
    },

    /**
     * Set tile type
     */
    setTile(x, y, type) {
        const tile = this.getTile(x, y);
        if (!tile) return false;

        tile.type = type;
        tile.walkable = type !== this.TILE_WALL;
        tile.blocksLOS = type === this.TILE_WALL;
        tile.coverValue = type === this.TILE_COVER ? this.COVER_REDUCTION : 0;

        return true;
    },

    /**
     * Check if tile is walkable
     */
    isWalkable(x, y) {
        const tile = this.getTile(x, y);
        return tile && tile.walkable && !tile.occupied;
    },

    /**
     * Check if position is valid
     */
    isValid(x, y) {
        return x >= 0 && x < this.width && y >= 0 && y < this.height;
    },

    /**
     * Set tile occupant
     */
    setOccupant(x, y, entity) {
        const tile = this.getTile(x, y);
        if (tile) {
            tile.occupied = entity;
        }
    },

    /**
     * Clear tile occupant
     */
    clearOccupant(x, y) {
        const tile = this.getTile(x, y);
        if (tile) {
            tile.occupied = null;
        }
    },

    /**
     * Convert pixel to tile coordinates
     */
    pixelToTile(px, py, offsetX = 0, offsetY = 0) {
        return {
            x: Math.floor((px - offsetX) / this.tileSize),
            y: Math.floor((py - offsetY) / this.tileSize),
        };
    },

    /**
     * Convert tile to pixel coordinates (center of tile)
     */
    tileToPixel(tx, ty, offsetX = 0, offsetY = 0) {
        return {
            x: tx * this.tileSize + this.tileSize / 2 + offsetX,
            y: ty * this.tileSize + this.tileSize / 2 + offsetY,
        };
    },

    // ==========================================
    // A* PATHFINDING
    // ==========================================

    /**
     * Find path using A* algorithm
     * Returns array of {x, y} positions or empty array if no path
     */
    findPath(startX, startY, endX, endY, options = {}) {
        const {
            allowDiagonal = true,
            avoidOccupied = true,
            maxIterations = 1000,
        } = options;

        // Validate start and end
        if (!this.isValid(startX, startY) || !this.isValid(endX, endY)) {
            return [];
        }

        const startTile = this.getTile(startX, startY);
        const endTile = this.getTile(endX, endY);

        if (!endTile.walkable) {
            return [];
        }

        // A* data structures
        const openSet = [];
        const closedSet = new Set();
        const cameFrom = new Map();
        const gScore = new Map();
        const fScore = new Map();

        const key = (x, y) => `${x},${y}`;
        const heuristic = (x1, y1, x2, y2) => {
            // Manhattan distance for non-diagonal, Euclidean for diagonal
            if (allowDiagonal) {
                return Math.sqrt((x2 - x1) ** 2 + (y2 - y1) ** 2);
            }
            return Math.abs(x2 - x1) + Math.abs(y2 - y1);
        };

        // Initialize
        const startKey = key(startX, startY);
        gScore.set(startKey, 0);
        fScore.set(startKey, heuristic(startX, startY, endX, endY));
        openSet.push({ x: startX, y: startY, f: fScore.get(startKey) });

        // Neighbor offsets
        const neighbors = allowDiagonal
            ? [[-1,-1], [0,-1], [1,-1], [-1,0], [1,0], [-1,1], [0,1], [1,1]]
            : [[0,-1], [-1,0], [1,0], [0,1]];

        let iterations = 0;

        while (openSet.length > 0 && iterations < maxIterations) {
            iterations++;

            // Get node with lowest fScore
            openSet.sort((a, b) => a.f - b.f);
            const current = openSet.shift();
            const currentKey = key(current.x, current.y);

            // Reached goal
            if (current.x === endX && current.y === endY) {
                return this._reconstructPath(cameFrom, current);
            }

            closedSet.add(currentKey);

            // Check neighbors
            for (const [dx, dy] of neighbors) {
                const nx = current.x + dx;
                const ny = current.y + dy;
                const neighborKey = key(nx, ny);

                if (closedSet.has(neighborKey)) continue;

                const neighbor = this.getTile(nx, ny);
                if (!neighbor || !neighbor.walkable) continue;
                if (avoidOccupied && neighbor.occupied && !(nx === endX && ny === endY)) continue;

                // Diagonal movement cost
                const moveCost = (dx !== 0 && dy !== 0) ? 1.414 : 1;
                const tentativeG = gScore.get(currentKey) + moveCost;

                if (!gScore.has(neighborKey) || tentativeG < gScore.get(neighborKey)) {
                    cameFrom.set(neighborKey, current);
                    gScore.set(neighborKey, tentativeG);
                    const f = tentativeG + heuristic(nx, ny, endX, endY);
                    fScore.set(neighborKey, f);

                    const existingIndex = openSet.findIndex(n => n.x === nx && n.y === ny);
                    if (existingIndex === -1) {
                        openSet.push({ x: nx, y: ny, f: f });
                    } else {
                        openSet[existingIndex].f = f;
                    }
                }
            }
        }

        return []; // No path found
    },

    /**
     * Reconstruct path from A* result
     */
    _reconstructPath(cameFrom, current) {
        const path = [{ x: current.x, y: current.y }];
        let key = `${current.x},${current.y}`;

        while (cameFrom.has(key)) {
            const prev = cameFrom.get(key);
            path.unshift({ x: prev.x, y: prev.y });
            key = `${prev.x},${prev.y}`;
        }

        return path;
    },

    /**
     * Get path length in tiles
     */
    getPathLength(path) {
        if (path.length < 2) return 0;

        let length = 0;
        for (let i = 1; i < path.length; i++) {
            const dx = path[i].x - path[i-1].x;
            const dy = path[i].y - path[i-1].y;
            length += Math.sqrt(dx * dx + dy * dy);
        }
        return length;
    },

    /**
     * Get tiles within range
     */
    getTilesInRange(centerX, centerY, range, options = {}) {
        const { includeCenter = false, walkableOnly = false } = options;
        const tiles = [];

        for (let y = Math.max(0, centerY - range); y <= Math.min(this.height - 1, centerY + range); y++) {
            for (let x = Math.max(0, centerX - range); x <= Math.min(this.width - 1, centerX + range); x++) {
                const dist = Math.sqrt((x - centerX) ** 2 + (y - centerY) ** 2);
                if (dist <= range) {
                    if (!includeCenter && x === centerX && y === centerY) continue;
                    const tile = this.getTile(x, y);
                    if (walkableOnly && (!tile || !tile.walkable)) continue;
                    tiles.push(tile);
                }
            }
        }

        return tiles;
    },

    // ==========================================
    // LINE OF SIGHT
    // ==========================================

    /**
     * Check line of sight between two tiles using Bresenham's algorithm
     */
    hasLineOfSight(x1, y1, x2, y2) {
        const dx = Math.abs(x2 - x1);
        const dy = Math.abs(y2 - y1);
        const sx = x1 < x2 ? 1 : -1;
        const sy = y1 < y2 ? 1 : -1;
        let err = dx - dy;

        let x = x1;
        let y = y1;

        while (true) {
            // Skip start position
            if (x !== x1 || y !== y1) {
                const tile = this.getTile(x, y);
                // Check if this tile blocks LOS (but allow end tile)
                if (tile && tile.blocksLOS && !(x === x2 && y === y2)) {
                    return false;
                }
            }

            if (x === x2 && y === y2) break;

            const e2 = 2 * err;
            if (e2 > -dy) {
                err -= dy;
                x += sx;
            }
            if (e2 < dx) {
                err += dx;
                y += sy;
            }
        }

        return true;
    },

    /**
     * Check line of sight using pixel coordinates
     */
    hasLineOfSightPixel(px1, py1, px2, py2, offsetX = 0, offsetY = 0) {
        const tile1 = this.pixelToTile(px1, py1, offsetX, offsetY);
        const tile2 = this.pixelToTile(px2, py2, offsetX, offsetY);
        return this.hasLineOfSight(tile1.x, tile1.y, tile2.x, tile2.y);
    },

    /**
     * Get all tiles visible from a position
     */
    getVisibleTiles(centerX, centerY, maxRange) {
        const visible = [];

        for (let y = Math.max(0, centerY - maxRange); y <= Math.min(this.height - 1, centerY + maxRange); y++) {
            for (let x = Math.max(0, centerX - maxRange); x <= Math.min(this.width - 1, centerX + maxRange); x++) {
                const dist = Math.sqrt((x - centerX) ** 2 + (y - centerY) ** 2);
                if (dist <= maxRange && this.hasLineOfSight(centerX, centerY, x, y)) {
                    visible.push(this.getTile(x, y));
                }
            }
        }

        return visible;
    },

    /**
     * Check if target has cover relative to attacker
     */
    hasCover(attackerX, attackerY, targetX, targetY) {
        const targetTile = this.getTile(targetX, targetY);
        if (!targetTile || targetTile.coverValue === 0) {
            return { hasCover: false, reduction: 0 };
        }

        // Check if cover is between attacker and target
        const dx = attackerX - targetX;
        const dy = attackerY - targetY;

        // Check adjacent tile in direction of attacker
        const coverX = targetX + Math.sign(dx);
        const coverY = targetY + Math.sign(dy);
        const coverTile = this.getTile(coverX, coverY);

        if (coverTile && coverTile.type === this.TILE_COVER) {
            return { hasCover: true, reduction: this.COVER_REDUCTION };
        }

        // If standing on cover tile, get partial cover
        if (targetTile.type === this.TILE_COVER) {
            return { hasCover: true, reduction: targetTile.coverValue };
        }

        return { hasCover: false, reduction: 0 };
    },

    // ==========================================
    // UTILITY METHODS
    // ==========================================

    /**
     * Get distance between two tiles
     */
    getDistance(x1, y1, x2, y2) {
        return Math.sqrt((x2 - x1) ** 2 + (y2 - y1) ** 2);
    },

    /**
     * Get Manhattan distance
     */
    getManhattanDistance(x1, y1, x2, y2) {
        return Math.abs(x2 - x1) + Math.abs(y2 - y1);
    },

    /**
     * Get direction from one tile to another
     */
    getDirection(fromX, fromY, toX, toY) {
        const dx = toX - fromX;
        const dy = toY - fromY;
        const length = Math.sqrt(dx * dx + dy * dy);

        if (length === 0) return { x: 0, y: 0 };

        return {
            x: dx / length,
            y: dy / length,
        };
    },

    /**
     * Get angle between two positions in radians
     */
    getAngle(fromX, fromY, toX, toY) {
        return Math.atan2(toY - fromY, toX - fromX);
    },

    /**
     * Find nearest walkable tile to target
     */
    findNearestWalkable(targetX, targetY, maxRange = 5) {
        if (this.isWalkable(targetX, targetY)) {
            return { x: targetX, y: targetY };
        }

        let nearest = null;
        let nearestDist = Infinity;

        const tiles = this.getTilesInRange(targetX, targetY, maxRange, { walkableOnly: true });
        for (const tile of tiles) {
            const dist = this.getDistance(targetX, targetY, tile.x, tile.y);
            if (dist < nearestDist) {
                nearestDist = dist;
                nearest = { x: tile.x, y: tile.y };
            }
        }

        return nearest;
    },

    /**
     * Get tiles along a line (for AoE effects)
     */
    getTilesAlongLine(x1, y1, x2, y2) {
        const tiles = [];
        const dx = Math.abs(x2 - x1);
        const dy = Math.abs(y2 - y1);
        const sx = x1 < x2 ? 1 : -1;
        const sy = y1 < y2 ? 1 : -1;
        let err = dx - dy;

        let x = x1;
        let y = y1;

        while (true) {
            const tile = this.getTile(x, y);
            if (tile) tiles.push(tile);

            if (x === x2 && y === y2) break;

            const e2 = 2 * err;
            if (e2 > -dy) {
                err -= dy;
                x += sx;
            }
            if (e2 < dx) {
                err += dx;
                y += sy;
            }
        }

        return tiles;
    },

    /**
     * Get tiles in a cone (for AoE attacks)
     */
    getTilesInCone(originX, originY, direction, range, angleWidth) {
        const tiles = [];
        const halfAngle = angleWidth / 2;

        for (let y = Math.max(0, originY - range); y <= Math.min(this.height - 1, originY + range); y++) {
            for (let x = Math.max(0, originX - range); x <= Math.min(this.width - 1, originX + range); x++) {
                if (x === originX && y === originY) continue;

                const dist = this.getDistance(originX, originY, x, y);
                if (dist > range) continue;

                const angleToTile = this.getAngle(originX, originY, x, y);
                let angleDiff = Math.abs(angleToTile - direction);

                // Handle angle wrapping
                if (angleDiff > Math.PI) {
                    angleDiff = 2 * Math.PI - angleDiff;
                }

                if (angleDiff <= halfAngle) {
                    tiles.push(this.getTile(x, y));
                }
            }
        }

        return tiles;
    },

    /**
     * Serialize grid for saving
     */
    serialize() {
        return {
            width: this.width,
            height: this.height,
            tiles: this.tiles.map(row =>
                row.map(tile => ({
                    type: tile.type,
                }))
            ),
        };
    },

    /**
     * Deserialize grid from saved data
     */
    deserialize(data) {
        return this.init(data);
    },
};

// Make available globally
window.TileGrid = TileGrid;
