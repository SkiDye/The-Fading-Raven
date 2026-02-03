/**
 * THE FADING RAVEN - Depth Sorter
 * Sorts entities for correct isometric rendering order
 * Back-to-front, low-to-high depth sorting
 */

const DepthSorter = {
    /**
     * Calculate depth value for an entity
     * Higher depth = rendered later (on top)
     * @param {Object} entity - Entity with position data
     * @param {Object} stationLayout - Station layout for height lookup
     * @param {number} offsetX - Legacy grid offset X
     * @param {number} offsetY - Legacy grid offset Y
     * @param {number} tileSize - Legacy tile size
     * @returns {number} Depth value
     */
    getEntityDepth(entity, stationLayout, offsetX, offsetY, tileSize) {
        // Get tile coordinates
        let tileX, tileY;

        if (entity.tileX !== undefined && entity.tileY !== undefined) {
            // Use stored tile coordinates
            tileX = entity.tileX;
            tileY = entity.tileY;
        } else {
            // Convert from pixel coordinates (legacy)
            tileX = (entity.x - offsetX) / tileSize;
            tileY = (entity.y - offsetY) / tileSize;
        }

        // Get height level
        const heightLevel = HeightSystem.getLayoutTileHeight(
            stationLayout,
            Math.floor(tileX),
            Math.floor(tileY)
        );

        // Calculate depth
        return IsometricRenderer.getDepth(tileX, tileY, heightLevel);
    },

    /**
     * Sort an array of entities by depth (ascending = back to front)
     * @param {Array} entities - Array of entities to sort
     * @param {Object} stationLayout - Station layout for height lookup
     * @param {number} offsetX - Legacy grid offset X
     * @param {number} offsetY - Legacy grid offset Y
     * @param {number} tileSize - Legacy tile size
     * @returns {Array} Sorted array (new array, original unchanged)
     */
    sortByDepth(entities, stationLayout, offsetX, offsetY, tileSize) {
        if (!entities || entities.length === 0) return [];

        return [...entities].sort((a, b) => {
            const depthA = this.getEntityDepth(a, stationLayout, offsetX, offsetY, tileSize);
            const depthB = this.getEntityDepth(b, stationLayout, offsetX, offsetY, tileSize);
            return depthA - depthB;
        });
    },

    /**
     * Sort entities in place by depth
     * @param {Array} entities - Array of entities to sort
     * @param {Object} stationLayout - Station layout for height lookup
     * @param {number} offsetX - Legacy grid offset X
     * @param {number} offsetY - Legacy grid offset Y
     * @param {number} tileSize - Legacy tile size
     */
    sortByDepthInPlace(entities, stationLayout, offsetX, offsetY, tileSize) {
        if (!entities || entities.length === 0) return;

        entities.sort((a, b) => {
            const depthA = this.getEntityDepth(a, stationLayout, offsetX, offsetY, tileSize);
            const depthB = this.getEntityDepth(b, stationLayout, offsetX, offsetY, tileSize);
            return depthA - depthB;
        });
    },

    /**
     * Merge multiple entity arrays and sort by depth
     * @param {Array} entityArrays - Array of entity arrays
     * @param {Object} stationLayout - Station layout for height lookup
     * @param {number} offsetX - Legacy grid offset X
     * @param {number} offsetY - Legacy grid offset Y
     * @param {number} tileSize - Legacy tile size
     * @returns {Array} Merged and sorted array
     */
    mergeAndSort(entityArrays, stationLayout, offsetX, offsetY, tileSize) {
        const merged = entityArrays.flat().filter(e => e != null);
        return this.sortByDepth(merged, stationLayout, offsetX, offsetY, tileSize);
    },

    /**
     * Create a sorted render list with type tags
     * @param {Object} entityGroups - Object with named entity arrays
     * @param {Object} stationLayout - Station layout for height lookup
     * @param {number} offsetX - Legacy grid offset X
     * @param {number} offsetY - Legacy grid offset Y
     * @param {number} tileSize - Legacy tile size
     * @returns {Array} Array of {entity, type, depth}
     */
    createRenderList(entityGroups, stationLayout, offsetX, offsetY, tileSize) {
        const renderList = [];

        for (const [type, entities] of Object.entries(entityGroups)) {
            if (!Array.isArray(entities)) continue;

            for (const entity of entities) {
                if (!entity) continue;

                const depth = this.getEntityDepth(entity, stationLayout, offsetX, offsetY, tileSize);
                renderList.push({ entity, type, depth });
            }
        }

        // Sort by depth (ascending)
        renderList.sort((a, b) => a.depth - b.depth);

        return renderList;
    },

    /**
     * Get isometric screen position for an entity
     * @param {Object} entity - Entity with position data
     * @param {Object} stationLayout - Station layout for height lookup
     * @param {number} offsetX - Legacy grid offset X
     * @param {number} offsetY - Legacy grid offset Y
     * @param {number} tileSize - Legacy tile size
     * @returns {{x: number, y: number, heightLevel: number}} Screen position and height
     */
    getEntityScreenPosition(entity, stationLayout, offsetX, offsetY, tileSize) {
        // Get tile coordinates
        let tileX, tileY;

        if (entity.tileX !== undefined && entity.tileY !== undefined) {
            tileX = entity.tileX;
            tileY = entity.tileY;
        } else {
            // Convert from pixel coordinates
            tileX = (entity.x - offsetX) / tileSize;
            tileY = (entity.y - offsetY) / tileSize;
        }

        // Get height level
        const heightLevel = HeightSystem.getLayoutTileHeight(
            stationLayout,
            Math.floor(tileX),
            Math.floor(tileY)
        );

        // Convert to isometric screen position
        const screen = IsometricRenderer.tileToScreen(tileX, tileY, heightLevel);

        return {
            x: screen.x,
            y: screen.y,
            heightLevel,
            tileX,
            tileY,
        };
    },

    /**
     * Check if two entities overlap (for selection priority)
     * @param {Object} entityA - First entity
     * @param {Object} entityB - Second entity
     * @param {number} threshold - Distance threshold
     * @returns {boolean} True if overlapping
     */
    entitiesOverlap(entityA, entityB, threshold = 20) {
        const dx = entityA.x - entityB.x;
        const dy = entityA.y - entityB.y;
        return Math.sqrt(dx * dx + dy * dy) < threshold;
    },

    /**
     * Get the topmost entity at a screen position (for click handling)
     * @param {number} screenX - Screen X position
     * @param {number} screenY - Screen Y position
     * @param {Array} entities - Array of entities to check
     * @param {Object} stationLayout - Station layout for height lookup
     * @param {number} offsetX - Legacy grid offset X
     * @param {number} offsetY - Legacy grid offset Y
     * @param {number} tileSize - Legacy tile size
     * @param {number} hitRadius - Hit detection radius
     * @returns {Object|null} Topmost entity or null
     */
    getEntityAtPosition(screenX, screenY, entities, stationLayout, offsetX, offsetY, tileSize, hitRadius = 25) {
        if (!entities || entities.length === 0) return null;

        // Sort by depth descending (topmost first)
        const sorted = this.sortByDepth(entities, stationLayout, offsetX, offsetY, tileSize).reverse();

        for (const entity of sorted) {
            const pos = this.getEntityScreenPosition(entity, stationLayout, offsetX, offsetY, tileSize);
            const dx = screenX - pos.x;
            const dy = screenY - pos.y;
            const dist = Math.sqrt(dx * dx + dy * dy);

            if (dist < hitRadius) {
                return entity;
            }
        }

        return null;
    },

    /**
     * Get tile at screen position (accounting for height)
     * @param {number} screenX - Screen X position
     * @param {number} screenY - Screen Y position
     * @param {Object} stationLayout - Station layout for height lookup
     * @returns {{x: number, y: number, heightLevel: number}|null} Tile info or null
     */
    getTileAtPosition(screenX, screenY, stationLayout) {
        if (!stationLayout) return null;

        // Try each height level from highest to lowest
        for (let h = IsometricRenderer.config.maxHeightLevels - 1; h >= 0; h--) {
            const tile = IsometricRenderer.screenToTileInt(screenX, screenY, h);

            // Check bounds
            if (tile.x < 0 || tile.x >= stationLayout.width ||
                tile.y < 0 || tile.y >= stationLayout.height) {
                continue;
            }

            // Check if this tile's height matches
            const tileHeight = HeightSystem.getLayoutTileHeight(stationLayout, tile.x, tile.y);
            if (tileHeight === h) {
                return { x: tile.x, y: tile.y, heightLevel: h };
            }
        }

        // Fallback: use base level
        const baseTile = IsometricRenderer.screenToTileInt(screenX, screenY, 1);
        if (baseTile.x >= 0 && baseTile.x < stationLayout.width &&
            baseTile.y >= 0 && baseTile.y < stationLayout.height) {
            return {
                x: baseTile.x,
                y: baseTile.y,
                heightLevel: HeightSystem.getLayoutTileHeight(stationLayout, baseTile.x, baseTile.y),
            };
        }

        return null;
    },
};

// Make available globally
window.DepthSorter = DepthSorter;
