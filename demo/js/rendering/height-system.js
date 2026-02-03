/**
 * THE FADING RAVEN - Height System
 * Manages height levels for isometric rendering
 * Maps tile types to visual height levels
 */

const HeightSystem = {
    // Tile type to height level mapping
    // Using StationGenerator numeric tile types
    TILE_HEIGHT_MAP: {
        0: 0,   // VOID - lowest/space
        1: 1,   // FLOOR - base level
        2: 1,   // WALL - same as floor (rendered differently)
        3: 1,   // FACILITY - base level
        4: 1,   // AIRLOCK - base level
        5: 2,   // ELEVATED - high ground
        6: 0,   // LOWERED - low ground
        7: 1,   // CORRIDOR - base level
        8: 1,   // COVER - base level
        9: 1,   // HAZARD - base level
        10: 1,  // CHOKE - base level
    },

    // String type mapping (for legacy support)
    STRING_HEIGHT_MAP: {
        'void': 0,
        'floor': 1,
        'wall': 1,
        'cover': 1,
        'spawn': 1,
        'deploy': 1,
        'elevated': 2,
        'lowered': 0,
        'corridor': 1,
        'hazard': 1,
        'choke': 1,
        'facility': 1,
        'airlock': 1,
    },

    /**
     * Get height level for a tile type
     * @param {number|string} tileType - Tile type (numeric or string)
     * @returns {number} Height level (0-3)
     */
    getHeightLevel(tileType) {
        if (typeof tileType === 'number') {
            return this.TILE_HEIGHT_MAP[tileType] ?? 1;
        }
        if (typeof tileType === 'string') {
            return this.STRING_HEIGHT_MAP[tileType.toLowerCase()] ?? 1;
        }
        return 1; // Default floor level
    },

    /**
     * Get height level for a tile from grid data
     * @param {Object} tileGrid - TileGrid instance
     * @param {number} x - Tile X position
     * @param {number} y - Tile Y position
     * @returns {number} Height level
     */
    getTileHeight(tileGrid, x, y) {
        if (!tileGrid) return 1;

        const tile = tileGrid.getTile(x, y);
        if (!tile) return 0; // Out of bounds = void

        return this.getHeightLevel(tile.type);
    },

    /**
     * Get height level for a tile from station layout
     * @param {Object} stationLayout - Station layout data
     * @param {number} x - Tile X position
     * @param {number} y - Tile Y position
     * @returns {number} Height level
     */
    getLayoutTileHeight(stationLayout, x, y) {
        if (!stationLayout || !stationLayout.tiles) return 0;
        if (y < 0 || y >= stationLayout.height || x < 0 || x >= stationLayout.width) {
            return 0; // Out of bounds = void
        }

        const tile = stationLayout.tiles[y][x];
        const tileType = typeof tile === 'object' ? tile.type : tile;
        return this.getHeightLevel(tileType);
    },

    /**
     * Get height level for an entity based on its tile position
     * @param {Object} entity - Entity with tileX, tileY properties
     * @param {Object} tileGrid - TileGrid instance
     * @returns {number} Height level
     */
    getEntityHeight(entity, tileGrid) {
        if (!entity) return 1;

        // Use stored tile coordinates if available
        if (entity.tileX !== undefined && entity.tileY !== undefined) {
            return this.getTileHeight(tileGrid, entity.tileX, entity.tileY);
        }

        return 1; // Default to floor level
    },

    /**
     * Get height level for an entity based on pixel position
     * @param {Object} entity - Entity with x, y pixel coordinates
     * @param {Object} stationLayout - Station layout data
     * @param {number} offsetX - Grid offset X
     * @param {number} offsetY - Grid offset Y
     * @param {number} tileSize - Tile size in pixels (for legacy conversion)
     * @returns {number} Height level
     */
    getEntityHeightFromPixel(entity, stationLayout, offsetX, offsetY, tileSize) {
        if (!entity || !stationLayout) return 1;

        // Convert pixel to tile coordinates (legacy grid system)
        const tileX = Math.floor((entity.x - offsetX) / tileSize);
        const tileY = Math.floor((entity.y - offsetY) / tileSize);

        return this.getLayoutTileHeight(stationLayout, tileX, tileY);
    },

    /**
     * Check if there's a height difference between two adjacent tiles
     * @param {Object} stationLayout - Station layout data
     * @param {number} x1 - First tile X
     * @param {number} y1 - First tile Y
     * @param {number} x2 - Second tile X
     * @param {number} y2 - Second tile Y
     * @returns {number} Height difference (positive = first is higher)
     */
    getHeightDifference(stationLayout, x1, y1, x2, y2) {
        const h1 = this.getLayoutTileHeight(stationLayout, x1, y1);
        const h2 = this.getLayoutTileHeight(stationLayout, x2, y2);
        return h1 - h2;
    },

    /**
     * Check if a tile should render side walls
     * @param {Object} stationLayout - Station layout data
     * @param {number} x - Tile X position
     * @param {number} y - Tile Y position
     * @returns {{left: boolean, right: boolean, leftHeight: number, rightHeight: number}}
     */
    getSideRenderInfo(stationLayout, x, y) {
        const currentHeight = this.getLayoutTileHeight(stationLayout, x, y);

        // Check adjacent tiles (in isometric, "left" is +Y, "right" is +X)
        const leftHeight = this.getLayoutTileHeight(stationLayout, x, y + 1);
        const rightHeight = this.getLayoutTileHeight(stationLayout, x + 1, y);

        return {
            left: currentHeight > leftHeight,
            right: currentHeight > rightHeight,
            leftHeight: currentHeight - leftHeight,
            rightHeight: currentHeight - rightHeight,
        };
    },

    /**
     * Get visual Y offset for height
     * @param {number} heightLevel - Height level
     * @returns {number} Y offset in pixels
     */
    getHeightOffset(heightLevel) {
        const heightOffset = IsometricRenderer?.config?.heightOffset || 20;
        return heightLevel * heightOffset;
    },

    /**
     * Check if tile is walkable considering height
     * @param {Object} tileGrid - TileGrid instance
     * @param {number} fromX - Starting tile X
     * @param {number} fromY - Starting tile Y
     * @param {number} toX - Target tile X
     * @param {number} toY - Target tile Y
     * @returns {boolean} True if movement is allowed
     */
    canMoveWithHeight(tileGrid, fromX, fromY, toX, toY) {
        if (!tileGrid) return true;

        const fromTile = tileGrid.getTile(fromX, fromY);
        const toTile = tileGrid.getTile(toX, toY);

        if (!fromTile || !toTile || !toTile.walkable) return false;

        // For now, allow all height differences (entities can climb)
        // Could add restrictions here for more realistic movement
        return true;
    },
};

// Make available globally
window.HeightSystem = HeightSystem;
