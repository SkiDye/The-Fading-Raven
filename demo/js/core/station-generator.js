/**
 * THE FADING RAVEN - Station Layout Generator
 * BSP-based procedural station layout generation
 */

const StationGenerator = {
    // Tile types
    TILE: {
        VOID: 0,      // Space - instant death
        FLOOR: 1,     // Basic walkable tile
        WALL: 2,      // Impassable
        FACILITY: 3,  // Facility module (defense target)
        AIRLOCK: 4,   // Entry point / chokepoint
        ELEVATED: 5,  // High ground (range bonus)
        LOWERED: 6,   // Low ground (defense penalty)
        CORRIDOR: 7,  // Narrow passage
        COVER: 8,     // Half cover (defense bonus)
        HAZARD: 9,    // Damage zone (electrical/fire)
        CHOKE: 10,    // Chokepoint (narrow defensible position)
    },

    // Facility types
    FACILITY_TYPE: {
        RESIDENTIAL_S: 'residential_s',  // 1 credit
        RESIDENTIAL_M: 'residential_m',  // 2 credits
        RESIDENTIAL_L: 'residential_l',  // 3 credits
        MEDICAL: 'medical',              // 2 credits
        ARMORY: 'armory',                // 2 credits
        COMM_TOWER: 'commTower',         // 2 credits
        POWER_PLANT: 'powerPlant',       // 3 credits
    },

    // Facility credit values
    FACILITY_CREDITS: {
        residential_s: 1,
        residential_m: 2,
        residential_l: 3,
        medical: 2,
        armory: 2,
        commTower: 2,
        powerPlant: 3,
    },

    // Map size configurations based on difficulty score
    SIZE_CONFIG: {
        small: {
            size: 7, tiles: 49, facilities: [2, 3], spawnPoints: 2,
            maxBspDepth: 2, extraCorridorRate: [0.1, 0.2],
            terrainDensity: 0.1, coverDensity: 0.05, hazardDensity: 0.02,
        },
        medium: {
            size: 9, tiles: 81, facilities: [3, 4], spawnPoints: 3,
            maxBspDepth: 3, extraCorridorRate: [0.15, 0.25],
            terrainDensity: 0.15, coverDensity: 0.08, hazardDensity: 0.04,
        },
        large: {
            size: 11, tiles: 121, facilities: [4, 5], spawnPoints: 4,
            maxBspDepth: 4, extraCorridorRate: [0.2, 0.35],
            terrainDensity: 0.2, coverDensity: 0.1, hazardDensity: 0.06,
        },
        xlarge: {
            size: 13, tiles: 169, facilities: [5, 7], spawnPoints: 5,
            maxBspDepth: 5, extraCorridorRate: [0.25, 0.4],
            terrainDensity: 0.25, coverDensity: 0.12, hazardDensity: 0.08,
        },
    },

    // Special room types for variety
    ROOM_TYPE: {
        NORMAL: 'normal',
        DEFENSE_POST: 'defense_post',    // Elevated center with cover
        STORAGE: 'storage',              // Scattered cover
        HAZARD_ZONE: 'hazard_zone',      // Contains hazard tiles
        CHOKEPOINT: 'chokepoint',        // Narrow defensible area
    },

    /**
     * Generate a station layout
     * @param {SeededRNG} rng - The RNG stream
     * @param {number} difficultyScore - The difficulty score (1.0-6.0+)
     * @param {Object} options - Additional options
     * @returns {Object} Station layout data
     */
    generate(rng, difficultyScore, options = {}) {
        // Determine map size from difficulty
        const sizeKey = this._getSizeKey(difficultyScore);
        const config = this.SIZE_CONFIG[sizeKey];

        // Create base grid
        const grid = this._createGrid(config.size);

        // BSP subdivision with depth based on difficulty
        const rooms = this._bspSubdivide(rng, config.size, config.size, config.maxBspDepth);

        // Assign room types for variety
        this._assignRoomTypes(rng, rooms, difficultyScore);

        // Carve rooms into grid
        this._carveRooms(grid, rooms);

        // Connect rooms with corridors (with config-based extra corridors)
        this._connectRooms(rng, grid, rooms, config);

        // Place facilities
        const facilities = this._placeFacilities(rng, grid, rooms, config);

        // Place spawn points (airlocks)
        const spawnPoints = this._placeSpawnPoints(rng, grid, config, facilities);

        // Add terrain variation (elevated/lowered/cover/hazard)
        this._addTerrainVariation(rng, grid, config);

        // Add room-specific terrain features
        this._addRoomFeatures(rng, grid, rooms, config);

        // Add chokepoints at corridor junctions
        this._addChokepoints(rng, grid, rooms);

        // Calculate total credits
        const totalCredits = facilities.reduce((sum, f) => sum + this.FACILITY_CREDITS[f.type], 0);

        return {
            width: config.size,
            height: config.size,
            grid,
            rooms,
            facilities,
            spawnPoints,
            totalCredits,
            sizeKey,
            difficultyScore,
        };
    },

    /**
     * Determine size key from difficulty score
     */
    _getSizeKey(difficultyScore) {
        if (difficultyScore < 2.0) return 'small';
        if (difficultyScore < 3.0) return 'medium';
        if (difficultyScore < 4.5) return 'large';
        return 'xlarge';
    },

    /**
     * Create empty grid filled with void
     */
    _createGrid(size) {
        const grid = [];
        for (let y = 0; y < size; y++) {
            const row = [];
            for (let x = 0; x < size; x++) {
                row.push(this.TILE.VOID);
            }
            grid.push(row);
        }
        return grid;
    },

    /**
     * BSP subdivision to create rooms
     */
    _bspSubdivide(rng, width, height, maxDepth = 3) {
        const MIN_ROOM_SIZE = 2;
        const rooms = [];

        const subdivide = (x, y, w, h, depth = 0) => {
            // Stop conditions - use configurable max depth
            if (w < MIN_ROOM_SIZE * 2 || h < MIN_ROOM_SIZE * 2 || depth >= maxDepth) {
                // Create room with some padding
                const padding = 0;
                rooms.push({
                    x: x + padding,
                    y: y + padding,
                    width: w - padding * 2,
                    height: h - padding * 2,
                    centerX: Math.floor(x + w / 2),
                    centerY: Math.floor(y + h / 2),
                    type: this.ROOM_TYPE.NORMAL,
                });
                return;
            }

            // Decide split direction
            const splitHorizontal = w < h ? true : (h < w ? false : rng.chance(0.5));

            if (splitHorizontal) {
                // Horizontal split
                const splitY = rng.range(y + MIN_ROOM_SIZE, y + h - MIN_ROOM_SIZE);
                subdivide(x, y, w, splitY - y, depth + 1);
                subdivide(x, splitY, w, y + h - splitY, depth + 1);
            } else {
                // Vertical split
                const splitX = rng.range(x + MIN_ROOM_SIZE, x + w - MIN_ROOM_SIZE);
                subdivide(x, y, splitX - x, h, depth + 1);
                subdivide(splitX, y, x + w - splitX, h, depth + 1);
            }
        };

        // Start subdivision from full grid (with 1-tile border)
        subdivide(1, 1, width - 2, height - 2);

        return rooms;
    },

    /**
     * Assign special room types for variety
     */
    _assignRoomTypes(rng, rooms, difficultyScore) {
        const roomTypeWeights = {
            [this.ROOM_TYPE.NORMAL]: 50,
            [this.ROOM_TYPE.DEFENSE_POST]: 15,
            [this.ROOM_TYPE.STORAGE]: 15,
            [this.ROOM_TYPE.HAZARD_ZONE]: 10 + difficultyScore * 2,
            [this.ROOM_TYPE.CHOKEPOINT]: 10,
        };

        const types = Object.keys(roomTypeWeights);
        const weights = Object.values(roomTypeWeights);

        rooms.forEach((room, idx) => {
            // First room is always normal (player start area)
            if (idx === 0) {
                room.type = this.ROOM_TYPE.NORMAL;
                return;
            }
            // Larger rooms can be defense posts
            if (room.width >= 3 && room.height >= 3 && rng.chance(0.3)) {
                room.type = this.ROOM_TYPE.DEFENSE_POST;
                return;
            }
            // Small rooms can be chokepoints
            if (room.width <= 2 || room.height <= 2) {
                if (rng.chance(0.4)) {
                    room.type = this.ROOM_TYPE.CHOKEPOINT;
                    return;
                }
            }
            // Random assignment for others
            room.type = rng.weightedPick(types, weights);
        });
    },

    /**
     * Carve rooms into the grid
     */
    _carveRooms(grid, rooms) {
        rooms.forEach(room => {
            for (let y = room.y; y < room.y + room.height; y++) {
                for (let x = room.x; x < room.x + room.width; x++) {
                    if (y >= 0 && y < grid.length && x >= 0 && x < grid[0].length) {
                        grid[y][x] = this.TILE.FLOOR;
                    }
                }
            }
        });
    },

    /**
     * Connect rooms with corridors using MST
     */
    _connectRooms(rng, grid, rooms, config = {}) {
        if (rooms.length < 2) return;

        const extraRate = config.extraCorridorRate || [0.2, 0.4];

        // Build MST using Prim's algorithm
        const connected = [0];
        const unconnected = rooms.map((_, i) => i).slice(1);

        while (unconnected.length > 0) {
            let bestDist = Infinity;
            let bestFrom = -1;
            let bestTo = -1;

            // Find shortest edge between connected and unconnected
            connected.forEach(fromIdx => {
                unconnected.forEach(toIdx => {
                    const from = rooms[fromIdx];
                    const to = rooms[toIdx];
                    const dist = Math.abs(from.centerX - to.centerX) + Math.abs(from.centerY - to.centerY);
                    if (dist < bestDist) {
                        bestDist = dist;
                        bestFrom = fromIdx;
                        bestTo = toIdx;
                    }
                });
            });

            if (bestTo !== -1) {
                // Connect the rooms
                this._carveCorridor(grid, rooms[bestFrom], rooms[bestTo], rng);

                // Move to connected
                connected.push(bestTo);
                unconnected.splice(unconnected.indexOf(bestTo), 1);
            }
        }

        // Add extra corridors for loops based on config
        const extraCorridors = Math.floor(rooms.length * rng.rangeFloat(extraRate[0], extraRate[1]));
        for (let i = 0; i < extraCorridors; i++) {
            const from = rng.pick(rooms);
            const to = rng.pick(rooms);
            if (from !== to) {
                this._carveCorridor(grid, from, to, rng);
            }
        }
    },

    /**
     * Carve a corridor between two rooms
     */
    _carveCorridor(grid, from, to, rng) {
        let x = from.centerX;
        let y = from.centerY;
        const targetX = to.centerX;
        const targetY = to.centerY;

        // L-shaped corridor
        const goHorizontalFirst = rng.chance(0.5);

        if (goHorizontalFirst) {
            // Horizontal then vertical
            while (x !== targetX) {
                if (x >= 0 && x < grid[0].length && y >= 0 && y < grid.length) {
                    if (grid[y][x] === this.TILE.VOID) {
                        grid[y][x] = this.TILE.CORRIDOR;
                    }
                }
                x += x < targetX ? 1 : -1;
            }
            while (y !== targetY) {
                if (x >= 0 && x < grid[0].length && y >= 0 && y < grid.length) {
                    if (grid[y][x] === this.TILE.VOID) {
                        grid[y][x] = this.TILE.CORRIDOR;
                    }
                }
                y += y < targetY ? 1 : -1;
            }
        } else {
            // Vertical then horizontal
            while (y !== targetY) {
                if (x >= 0 && x < grid[0].length && y >= 0 && y < grid.length) {
                    if (grid[y][x] === this.TILE.VOID) {
                        grid[y][x] = this.TILE.CORRIDOR;
                    }
                }
                y += y < targetY ? 1 : -1;
            }
            while (x !== targetX) {
                if (x >= 0 && x < grid[0].length && y >= 0 && y < grid.length) {
                    if (grid[y][x] === this.TILE.VOID) {
                        grid[y][x] = this.TILE.CORRIDOR;
                    }
                }
                x += x < targetX ? 1 : -1;
            }
        }
    },

    /**
     * Place facilities in rooms
     */
    _placeFacilities(rng, grid, rooms, config) {
        const facilities = [];
        const facilityCount = rng.range(config.facilities[0], config.facilities[1]);

        // Facility type weights from GDD
        const facilityTypes = [
            this.FACILITY_TYPE.RESIDENTIAL_S,
            this.FACILITY_TYPE.RESIDENTIAL_M,
            this.FACILITY_TYPE.RESIDENTIAL_L,
            this.FACILITY_TYPE.MEDICAL,
            this.FACILITY_TYPE.ARMORY,
            this.FACILITY_TYPE.COMM_TOWER,
            this.FACILITY_TYPE.POWER_PLANT,
        ];
        const weights = [20, 15, 5, 15, 15, 15, 15]; // Residential more common

        // Sort rooms by size (larger rooms get facilities first)
        const sortedRooms = [...rooms].sort((a, b) =>
            (b.width * b.height) - (a.width * a.height)
        );

        // Place facilities
        const usedRooms = new Set();
        for (let i = 0; i < facilityCount && i < sortedRooms.length; i++) {
            const room = sortedRooms[i];
            if (usedRooms.has(room)) continue;

            const type = rng.weightedPick(facilityTypes, weights);
            const x = room.centerX;
            const y = room.centerY;

            if (y >= 0 && y < grid.length && x >= 0 && x < grid[0].length) {
                grid[y][x] = this.TILE.FACILITY;

                facilities.push({
                    id: facilities.length,
                    type,
                    x,
                    y,
                    roomIndex: rooms.indexOf(room),
                    credits: this.FACILITY_CREDITS[type],
                    health: 100,
                    destroyed: false,
                });

                usedRooms.add(room);
            }
        }

        return facilities;
    },

    /**
     * Place spawn points (airlocks) on edges
     */
    _placeSpawnPoints(rng, grid, config, facilities) {
        const spawnPoints = [];
        const size = grid.length;
        const targetCount = config.spawnPoints;

        // Get edge positions
        const edges = [];

        // Top and bottom edges
        for (let x = 1; x < size - 1; x++) {
            edges.push({ x, y: 0, direction: 'south' });
            edges.push({ x, y: size - 1, direction: 'north' });
        }

        // Left and right edges
        for (let y = 1; y < size - 1; y++) {
            edges.push({ x: 0, y, direction: 'east' });
            edges.push({ x: size - 1, y, direction: 'west' });
        }

        // Shuffle and pick
        const shuffled = rng.shuffle(edges);

        // Filter to edges adjacent to walkable tiles
        const validEdges = shuffled.filter(edge => {
            const adjacent = this._getAdjacentTile(grid, edge.x, edge.y, edge.direction);
            return adjacent && adjacent.tile !== this.TILE.VOID;
        });

        // Pick spawn points, ensuring minimum distance from each other and facilities
        for (const edge of validEdges) {
            if (spawnPoints.length >= targetCount) break;

            // Check distance from other spawn points
            const tooClose = spawnPoints.some(sp =>
                Math.abs(sp.x - edge.x) + Math.abs(sp.y - edge.y) < 3
            );

            if (!tooClose) {
                // Mark as airlock
                grid[edge.y][edge.x] = this.TILE.AIRLOCK;

                spawnPoints.push({
                    id: spawnPoints.length,
                    x: edge.x,
                    y: edge.y,
                    direction: edge.direction,
                });
            }
        }

        // Fallback: if not enough spawn points, force some
        while (spawnPoints.length < 2 && validEdges.length > spawnPoints.length) {
            const edge = validEdges[spawnPoints.length];
            grid[edge.y][edge.x] = this.TILE.AIRLOCK;
            spawnPoints.push({
                id: spawnPoints.length,
                x: edge.x,
                y: edge.y,
                direction: edge.direction,
            });
        }

        return spawnPoints;
    },

    /**
     * Get adjacent tile in a direction
     */
    _getAdjacentTile(grid, x, y, direction) {
        const offsets = {
            north: { dx: 0, dy: -1 },
            south: { dx: 0, dy: 1 },
            east: { dx: 1, dy: 0 },
            west: { dx: -1, dy: 0 },
        };

        const offset = offsets[direction];
        if (!offset) return null;

        const nx = x + offset.dx;
        const ny = y + offset.dy;

        if (ny >= 0 && ny < grid.length && nx >= 0 && nx < grid[0].length) {
            return { x: nx, y: ny, tile: grid[ny][nx] };
        }
        return null;
    },

    /**
     * Add terrain variation (elevated/lowered/cover/hazard tiles)
     */
    _addTerrainVariation(rng, grid, config = {}) {
        const size = grid.length;
        const center = Math.floor(size / 2);
        const terrainDensity = config.terrainDensity || 0.15;
        const coverDensity = config.coverDensity || 0.08;
        const hazardDensity = config.hazardDensity || 0.04;

        // First pass: elevated/lowered terrain in clusters
        for (let y = 0; y < size; y++) {
            for (let x = 0; x < size; x++) {
                if (grid[y][x] !== this.TILE.FLOOR) continue;

                const distFromCenter = Math.abs(x - center) + Math.abs(y - center);
                const isNearCenter = distFromCenter < size / 3;
                const isNearEdge = distFromCenter > size / 2;

                // Central areas more likely to be elevated
                if (isNearCenter && rng.chance(terrainDensity * 1.5)) {
                    this._createTerrainCluster(rng, grid, x, y, this.TILE.ELEVATED, 2);
                }
                // Edge areas more likely to be lowered
                else if (isNearEdge && rng.chance(terrainDensity)) {
                    this._createTerrainCluster(rng, grid, x, y, this.TILE.LOWERED, 2);
                }
            }
        }

        // Second pass: cover tiles (strategic positions)
        for (let y = 0; y < size; y++) {
            for (let x = 0; x < size; x++) {
                if (grid[y][x] !== this.TILE.FLOOR) continue;

                // Place cover near corridors and room edges
                const nearCorridor = this._isAdjacentTo(grid, x, y, this.TILE.CORRIDOR);
                const nearWall = this._isAdjacentTo(grid, x, y, this.TILE.VOID) ||
                                 this._isAdjacentTo(grid, x, y, this.TILE.WALL);

                if ((nearCorridor || nearWall) && rng.chance(coverDensity)) {
                    grid[y][x] = this.TILE.COVER;
                }
            }
        }

        // Third pass: hazard tiles (sparingly)
        for (let y = 0; y < size; y++) {
            for (let x = 0; x < size; x++) {
                if (grid[y][x] !== this.TILE.FLOOR) continue;

                // Hazards away from spawn points
                const nearEdge = x <= 1 || y <= 1 || x >= size - 2 || y >= size - 2;
                if (!nearEdge && rng.chance(hazardDensity)) {
                    grid[y][x] = this.TILE.HAZARD;
                }
            }
        }
    },

    /**
     * Create a cluster of terrain tiles
     */
    _createTerrainCluster(rng, grid, startX, startY, tileType, maxSize) {
        const size = grid.length;
        const toVisit = [{ x: startX, y: startY }];
        const visited = new Set();
        let placed = 0;

        while (toVisit.length > 0 && placed < maxSize) {
            const { x, y } = toVisit.shift();
            const key = `${x},${y}`;

            if (visited.has(key)) continue;
            visited.add(key);

            if (x < 0 || x >= size || y < 0 || y >= size) continue;
            if (grid[y][x] !== this.TILE.FLOOR) continue;

            grid[y][x] = tileType;
            placed++;

            // Maybe expand to neighbors
            if (rng.chance(0.5)) {
                const neighbors = [
                    { x: x - 1, y }, { x: x + 1, y },
                    { x, y: y - 1 }, { x, y: y + 1 },
                ];
                rng.shuffle(neighbors).forEach(n => toVisit.push(n));
            }
        }
    },

    /**
     * Check if a tile is adjacent to a specific tile type
     */
    _isAdjacentTo(grid, x, y, tileType) {
        const size = grid.length;
        const neighbors = [
            { dx: -1, dy: 0 }, { dx: 1, dy: 0 },
            { dx: 0, dy: -1 }, { dx: 0, dy: 1 },
        ];

        for (const { dx, dy } of neighbors) {
            const nx = x + dx;
            const ny = y + dy;
            if (nx >= 0 && nx < size && ny >= 0 && ny < size) {
                if (grid[ny][nx] === tileType) return true;
            }
        }
        return false;
    },

    /**
     * Add room-specific terrain features based on room type
     */
    _addRoomFeatures(rng, grid, rooms, config) {
        rooms.forEach(room => {
            switch (room.type) {
                case this.ROOM_TYPE.DEFENSE_POST:
                    this._createDefensePost(rng, grid, room);
                    break;
                case this.ROOM_TYPE.STORAGE:
                    this._createStorage(rng, grid, room);
                    break;
                case this.ROOM_TYPE.HAZARD_ZONE:
                    this._createHazardZone(rng, grid, room);
                    break;
                case this.ROOM_TYPE.CHOKEPOINT:
                    this._createChokepoint(rng, grid, room);
                    break;
            }
        });
    },

    /**
     * Create a defense post room (elevated center with cover around edges)
     */
    _createDefensePost(rng, grid, room) {
        // Elevated center
        if (grid[room.centerY] && grid[room.centerY][room.centerX] === this.TILE.FLOOR) {
            grid[room.centerY][room.centerX] = this.TILE.ELEVATED;
        }

        // Cover at corners
        const corners = [
            { x: room.x, y: room.y },
            { x: room.x + room.width - 1, y: room.y },
            { x: room.x, y: room.y + room.height - 1 },
            { x: room.x + room.width - 1, y: room.y + room.height - 1 },
        ];

        corners.forEach(c => {
            if (c.y >= 0 && c.y < grid.length && c.x >= 0 && c.x < grid[0].length) {
                if (grid[c.y][c.x] === this.TILE.FLOOR) {
                    grid[c.y][c.x] = this.TILE.COVER;
                }
            }
        });
    },

    /**
     * Create a storage room (scattered cover tiles)
     */
    _createStorage(rng, grid, room) {
        for (let y = room.y; y < room.y + room.height; y++) {
            for (let x = room.x; x < room.x + room.width; x++) {
                if (y >= 0 && y < grid.length && x >= 0 && x < grid[0].length) {
                    if (grid[y][x] === this.TILE.FLOOR && rng.chance(0.25)) {
                        grid[y][x] = this.TILE.COVER;
                    }
                }
            }
        }
    },

    /**
     * Create a hazard zone room
     */
    _createHazardZone(rng, grid, room) {
        for (let y = room.y; y < room.y + room.height; y++) {
            for (let x = room.x; x < room.x + room.width; x++) {
                if (y >= 0 && y < grid.length && x >= 0 && x < grid[0].length) {
                    // Leave edges and center safe
                    const isEdge = x === room.x || x === room.x + room.width - 1 ||
                                   y === room.y || y === room.y + room.height - 1;
                    const isCenter = x === room.centerX && y === room.centerY;

                    if (grid[y][x] === this.TILE.FLOOR && !isEdge && !isCenter && rng.chance(0.4)) {
                        grid[y][x] = this.TILE.HAZARD;
                    }
                }
            }
        }
    },

    /**
     * Create a chokepoint room
     */
    _createChokepoint(rng, grid, room) {
        // Mark center as chokepoint tile for special rendering
        if (grid[room.centerY] && grid[room.centerY][room.centerX] === this.TILE.FLOOR) {
            grid[room.centerY][room.centerX] = this.TILE.CHOKE;
        }

        // Add cover at entrance/exit
        if (room.width > room.height) {
            // Horizontal chokepoint
            if (room.x >= 0 && room.x < grid[0].length && grid[room.centerY][room.x] === this.TILE.FLOOR) {
                grid[room.centerY][room.x] = this.TILE.COVER;
            }
            const endX = room.x + room.width - 1;
            if (endX >= 0 && endX < grid[0].length && grid[room.centerY][endX] === this.TILE.FLOOR) {
                grid[room.centerY][endX] = this.TILE.COVER;
            }
        } else {
            // Vertical chokepoint
            if (room.y >= 0 && room.y < grid.length && grid[room.y][room.centerX] === this.TILE.FLOOR) {
                grid[room.y][room.centerX] = this.TILE.COVER;
            }
            const endY = room.y + room.height - 1;
            if (endY >= 0 && endY < grid.length && grid[endY][room.centerX] === this.TILE.FLOOR) {
                grid[endY][room.centerX] = this.TILE.COVER;
            }
        }
    },

    /**
     * Add chokepoints at corridor junctions
     */
    _addChokepoints(rng, grid, rooms) {
        const size = grid.length;

        for (let y = 1; y < size - 1; y++) {
            for (let x = 1; x < size - 1; x++) {
                if (grid[y][x] !== this.TILE.CORRIDOR) continue;

                // Count adjacent corridor/walkable tiles
                const adjacentCorridors = [
                    grid[y - 1][x], grid[y + 1][x],
                    grid[y][x - 1], grid[y][x + 1],
                ].filter(t => t === this.TILE.CORRIDOR || t === this.TILE.FLOOR).length;

                // Junction (3+ connections) becomes chokepoint
                if (adjacentCorridors >= 3 && rng.chance(0.3)) {
                    grid[y][x] = this.TILE.CHOKE;
                }
            }
        }
    },

    /**
     * Get walkable tiles
     */
    getWalkableTiles(layout) {
        const walkable = [];
        const walkableTypes = [
            this.TILE.FLOOR,
            this.TILE.FACILITY,
            this.TILE.AIRLOCK,
            this.TILE.ELEVATED,
            this.TILE.LOWERED,
            this.TILE.CORRIDOR,
            this.TILE.COVER,
            this.TILE.HAZARD,
            this.TILE.CHOKE,
        ];

        for (let y = 0; y < layout.height; y++) {
            for (let x = 0; x < layout.width; x++) {
                if (walkableTypes.includes(layout.grid[y][x])) {
                    walkable.push({ x, y, tile: layout.grid[y][x] });
                }
            }
        }

        return walkable;
    },

    /**
     * Check if a position is walkable
     */
    isWalkable(layout, x, y) {
        if (x < 0 || x >= layout.width || y < 0 || y >= layout.height) {
            return false;
        }

        const walkableTypes = [
            this.TILE.FLOOR,
            this.TILE.FACILITY,
            this.TILE.AIRLOCK,
            this.TILE.ELEVATED,
            this.TILE.LOWERED,
            this.TILE.CORRIDOR,
            this.TILE.COVER,
            this.TILE.HAZARD,
            this.TILE.CHOKE,
        ];

        return walkableTypes.includes(layout.grid[y][x]);
    },

    /**
     * Get terrain bonus/penalty at position
     */
    getTerrainModifier(layout, x, y) {
        const tile = this.getTile(layout, x, y);
        switch (tile) {
            case this.TILE.ELEVATED:
                return { defense: 0, range: 1, damage: 0 }; // Range bonus
            case this.TILE.LOWERED:
                return { defense: -10, range: 0, damage: 0 }; // Defense penalty
            case this.TILE.COVER:
                return { defense: 25, range: 0, damage: 0 }; // Defense bonus
            case this.TILE.HAZARD:
                return { defense: 0, range: 0, damage: 5 }; // Takes damage per turn
            case this.TILE.CHOKE:
                return { defense: 10, range: 0, damage: 0 }; // Slight defense bonus
            default:
                return { defense: 0, range: 0, damage: 0 };
        }
    },

    /**
     * Get tile at position
     */
    getTile(layout, x, y) {
        if (x < 0 || x >= layout.width || y < 0 || y >= layout.height) {
            return this.TILE.VOID;
        }
        return layout.grid[y][x];
    },

    /**
     * Find path between two points (A* pathfinding)
     */
    findPath(layout, startX, startY, endX, endY) {
        const openSet = [{ x: startX, y: startY, g: 0, h: 0, f: 0, parent: null }];
        const closedSet = new Set();
        const getKey = (x, y) => `${x},${y}`;

        const heuristic = (x1, y1, x2, y2) => Math.abs(x1 - x2) + Math.abs(y1 - y2);

        while (openSet.length > 0) {
            // Get node with lowest f
            openSet.sort((a, b) => a.f - b.f);
            const current = openSet.shift();

            if (current.x === endX && current.y === endY) {
                // Reconstruct path
                const path = [];
                let node = current;
                while (node) {
                    path.unshift({ x: node.x, y: node.y });
                    node = node.parent;
                }
                return path;
            }

            closedSet.add(getKey(current.x, current.y));

            // Check neighbors
            const neighbors = [
                { x: current.x - 1, y: current.y },
                { x: current.x + 1, y: current.y },
                { x: current.x, y: current.y - 1 },
                { x: current.x, y: current.y + 1 },
            ];

            for (const neighbor of neighbors) {
                if (closedSet.has(getKey(neighbor.x, neighbor.y))) continue;
                if (!this.isWalkable(layout, neighbor.x, neighbor.y)) continue;

                const g = current.g + 1;
                const h = heuristic(neighbor.x, neighbor.y, endX, endY);
                const f = g + h;

                const existingIdx = openSet.findIndex(n => n.x === neighbor.x && n.y === neighbor.y);
                if (existingIdx !== -1) {
                    if (g < openSet[existingIdx].g) {
                        openSet[existingIdx].g = g;
                        openSet[existingIdx].f = f;
                        openSet[existingIdx].parent = current;
                    }
                } else {
                    openSet.push({ x: neighbor.x, y: neighbor.y, g, h, f, parent: current });
                }
            }
        }

        return null; // No path found
    },

    /**
     * Calculate total potential credits from a layout
     */
    calculateTotalCredits(layout) {
        return layout.facilities.reduce((sum, f) => sum + f.credits, 0);
    },

    /**
     * Get facility at position
     */
    getFacilityAt(layout, x, y) {
        return layout.facilities.find(f => f.x === x && f.y === y);
    },

    /**
     * Convert grid to ASCII for debugging
     */
    toAscii(layout) {
        const chars = {
            [this.TILE.VOID]: ' ',
            [this.TILE.FLOOR]: '.',
            [this.TILE.WALL]: '#',
            [this.TILE.FACILITY]: 'F',
            [this.TILE.AIRLOCK]: 'A',
            [this.TILE.ELEVATED]: '^',
            [this.TILE.LOWERED]: 'v',
            [this.TILE.CORRIDOR]: '+',
            [this.TILE.COVER]: 'C',
            [this.TILE.HAZARD]: '!',
            [this.TILE.CHOKE]: 'X',
        };

        let result = '';
        for (let y = 0; y < layout.height; y++) {
            for (let x = 0; x < layout.width; x++) {
                result += chars[layout.grid[y][x]] || '?';
            }
            result += '\n';
        }
        return result;
    },
};

// Make available globally
window.StationGenerator = StationGenerator;
