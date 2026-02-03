/**
 * THE FADING RAVEN - Tile Renderer
 * Renders isometric diamond tiles with height visualization
 * Bad North style 2.5D tile rendering
 */

const TileRenderer = {
    // Tile type colors (matching existing battle.js colors)
    TILE_COLORS: {
        // Numeric tile types (StationGenerator)
        0: '#0a0a12',     // VOID - space/empty
        1: '#1a1a2e',     // FLOOR - base floor
        2: '#2d2d44',     // WALL - impassable
        3: '#1e3a5f',     // FACILITY - special building
        4: '#3d1a1a',     // AIRLOCK - spawn area
        5: '#252538',     // ELEVATED - high ground
        6: '#12121a',     // LOWERED - low ground
        7: '#1a1a2e',     // CORRIDOR
        8: '#252535',     // COVER
        9: '#2a1a1a',     // HAZARD
        10: '#1a2a2a',    // CHOKE

        // String tile types (legacy)
        'void': '#0a0a12',
        'floor': '#1a1a2e',
        'wall': '#2d2d44',
        'cover': '#252535',
        'elevated': '#252538',
        'lowered': '#12121a',
        'corridor': '#1a1a2e',
        'hazard': '#2a1a1a',
        'choke': '#1a2a2a',
        'facility': '#1e3a5f',
        'airlock': '#3d1a1a',
    },

    // Side darkening factors
    LEFT_SIDE_DARKNESS: 0.7,   // 70% brightness (30% darker)
    RIGHT_SIDE_DARKNESS: 0.85, // 85% brightness (15% darker)

    /**
     * Draw a single isometric diamond tile (top face only)
     * @param {CanvasRenderingContext2D} ctx - Canvas context
     * @param {number} screenX - Screen X center
     * @param {number} screenY - Screen Y center
     * @param {number|string} tileType - Tile type
     * @param {Object} options - Additional options
     */
    drawTileTop(ctx, screenX, screenY, tileType, options = {}) {
        const vertices = IsometricRenderer.getDiamondVertices(screenX, screenY);
        const color = this.getTileColor(tileType);

        ctx.beginPath();
        ctx.moveTo(vertices[0].x, vertices[0].y); // Top
        ctx.lineTo(vertices[1].x, vertices[1].y); // Right
        ctx.lineTo(vertices[2].x, vertices[2].y); // Bottom
        ctx.lineTo(vertices[3].x, vertices[3].y); // Left
        ctx.closePath();

        ctx.fillStyle = color;
        ctx.fill();

        // Optional: Add subtle border
        if (options.showBorder) {
            ctx.strokeStyle = this.adjustBrightness(color, 1.2);
            ctx.lineWidth = 1;
            ctx.stroke();
        }

        // Height-based highlights
        const heightLevel = HeightSystem.getHeightLevel(tileType);
        if (heightLevel >= 2) {
            // High ground gets subtle highlight
            ctx.fillStyle = 'rgba(255, 255, 255, 0.08)';
            ctx.fill();
        } else if (heightLevel === 0) {
            // Low ground gets subtle shadow
            ctx.fillStyle = 'rgba(0, 0, 0, 0.15)';
            ctx.fill();
        }
    },

    /**
     * Draw the left side wall of a tile (for height difference)
     * @param {CanvasRenderingContext2D} ctx - Canvas context
     * @param {number} screenX - Screen X center of top face
     * @param {number} screenY - Screen Y center of top face
     * @param {number|string} tileType - Tile type
     * @param {number} heightDiff - Height difference (in levels)
     */
    drawTileLeftSide(ctx, screenX, screenY, tileType, heightDiff = 1) {
        const { tileWidth, tileHeight, heightOffset } = IsometricRenderer.config;
        const zoom = IsometricRenderer.camera?.zoom || 1;
        const halfW = (tileWidth / 2) * zoom;
        const halfH = (tileHeight / 2) * zoom;
        const sideHeight = heightDiff * heightOffset * zoom;

        const color = this.getTileColor(tileType);
        const darkColor = this.adjustBrightness(color, this.LEFT_SIDE_DARKNESS);

        // Left side: from left vertex to bottom vertex, then down
        ctx.beginPath();
        ctx.moveTo(screenX - halfW, screenY);                    // Top-left
        ctx.lineTo(screenX, screenY + halfH);                    // Top-bottom
        ctx.lineTo(screenX, screenY + halfH + sideHeight);       // Bottom-bottom
        ctx.lineTo(screenX - halfW, screenY + sideHeight);       // Bottom-left
        ctx.closePath();

        ctx.fillStyle = darkColor;
        ctx.fill();
    },

    /**
     * Draw the right side wall of a tile (for height difference)
     * @param {CanvasRenderingContext2D} ctx - Canvas context
     * @param {number} screenX - Screen X center of top face
     * @param {number} screenY - Screen Y center of top face
     * @param {number|string} tileType - Tile type
     * @param {number} heightDiff - Height difference (in levels)
     */
    drawTileRightSide(ctx, screenX, screenY, tileType, heightDiff = 1) {
        const { tileWidth, tileHeight, heightOffset } = IsometricRenderer.config;
        const zoom = IsometricRenderer.camera?.zoom || 1;
        const halfW = (tileWidth / 2) * zoom;
        const halfH = (tileHeight / 2) * zoom;
        const sideHeight = heightDiff * heightOffset * zoom;

        const color = this.getTileColor(tileType);
        const darkColor = this.adjustBrightness(color, this.RIGHT_SIDE_DARKNESS);

        // Right side: from bottom vertex to right vertex, then down
        ctx.beginPath();
        ctx.moveTo(screenX, screenY + halfH);                    // Top-bottom
        ctx.lineTo(screenX + halfW, screenY);                    // Top-right
        ctx.lineTo(screenX + halfW, screenY + sideHeight);       // Bottom-right
        ctx.lineTo(screenX, screenY + halfH + sideHeight);       // Bottom-bottom
        ctx.closePath();

        ctx.fillStyle = darkColor;
        ctx.fill();
    },

    /**
     * Draw a complete tile with sides based on height differences
     * @param {CanvasRenderingContext2D} ctx - Canvas context
     * @param {number} screenX - Screen X center
     * @param {number} screenY - Screen Y center
     * @param {number|string} tileType - Tile type
     * @param {Object} sideInfo - Side render info from HeightSystem
     * @param {Object} options - Additional options
     */
    drawTileComplete(ctx, screenX, screenY, tileType, sideInfo, options = {}) {
        // Draw sides first (behind top face)
        if (sideInfo.left && sideInfo.leftHeight > 0) {
            this.drawTileLeftSide(ctx, screenX, screenY, tileType, sideInfo.leftHeight);
        }
        if (sideInfo.right && sideInfo.rightHeight > 0) {
            this.drawTileRightSide(ctx, screenX, screenY, tileType, sideInfo.rightHeight);
        }

        // Draw top face
        this.drawTileTop(ctx, screenX, screenY, tileType, options);
    },

    /**
     * Render all tiles from a station layout
     * @param {CanvasRenderingContext2D} ctx - Canvas context
     * @param {Object} stationLayout - Station layout data
     * @param {Object} options - Render options
     */
    renderAllTiles(ctx, stationLayout, options = {}) {
        if (!stationLayout || !stationLayout.tiles) return;

        const { width, height, tiles } = stationLayout;

        // Render in correct order for depth (back to front)
        // In isometric, we render by row sum (y + x increases towards viewer)
        for (let sum = 0; sum < width + height - 1; sum++) {
            for (let x = 0; x <= sum; x++) {
                const y = sum - x;
                if (x >= width || y >= height || y < 0) continue;

                const tile = tiles[y][x];
                const tileType = typeof tile === 'object' ? tile.type : tile;
                const heightLevel = HeightSystem.getHeightLevel(tileType);

                // Skip void tiles unless showing them
                if (tileType === 0 && !options.showVoid) continue;

                // Get screen position
                const screen = IsometricRenderer.tileToScreen(x, y, heightLevel);

                // Check visibility (culling)
                if (!options.skipCulling && !IsometricRenderer.isTileVisible(x, y, heightLevel)) {
                    continue;
                }

                // Get side render info
                const sideInfo = HeightSystem.getSideRenderInfo(stationLayout, x, y);

                // Draw the tile
                this.drawTileComplete(ctx, screen.x, screen.y, tileType, sideInfo, options);
            }
        }
    },

    /**
     * Render tiles to an offscreen cache canvas
     * @param {Object} stationLayout - Station layout data
     * @returns {HTMLCanvasElement} Cached tile canvas
     */
    renderToCache(stationLayout) {
        const cache = IsometricRenderer.getTileCache();
        if (!cache) return null;

        const ctx = cache.getContext('2d');
        ctx.clearRect(0, 0, cache.width, cache.height);

        this.renderAllTiles(ctx, stationLayout, {
            showBorder: false,
            showVoid: false,
            skipCulling: false,
        });

        IsometricRenderer.markCacheClean();
        return cache;
    },

    /**
     * Draw cached tiles to main canvas
     * @param {CanvasRenderingContext2D} ctx - Main canvas context
     */
    drawFromCache(ctx) {
        const cache = IsometricRenderer.getTileCache();
        if (!cache) return;

        ctx.drawImage(cache, 0, 0);
    },

    /**
     * Get tile color for a tile type
     * @param {number|string} tileType - Tile type
     * @returns {string} CSS color
     */
    getTileColor(tileType) {
        return this.TILE_COLORS[tileType] || this.TILE_COLORS[1]; // Default to floor
    },

    /**
     * Adjust color brightness
     * @param {string} hexColor - Hex color string
     * @param {number} factor - Brightness factor (1 = unchanged, <1 = darker, >1 = lighter)
     * @returns {string} Adjusted hex color
     */
    adjustBrightness(hexColor, factor) {
        // Parse hex color
        let hex = hexColor.replace('#', '');
        if (hex.length === 3) {
            hex = hex[0] + hex[0] + hex[1] + hex[1] + hex[2] + hex[2];
        }

        const r = Math.min(255, Math.max(0, Math.floor(parseInt(hex.substr(0, 2), 16) * factor)));
        const g = Math.min(255, Math.max(0, Math.floor(parseInt(hex.substr(2, 2), 16) * factor)));
        const b = Math.min(255, Math.max(0, Math.floor(parseInt(hex.substr(4, 2), 16) * factor)));

        return '#' + ((1 << 24) + (r << 16) + (g << 8) + b).toString(16).slice(1);
    },

    /**
     * Draw a tile highlight (for selection, hover, etc.)
     * @param {CanvasRenderingContext2D} ctx - Canvas context
     * @param {number} screenX - Screen X center
     * @param {number} screenY - Screen Y center
     * @param {string} color - Highlight color
     * @param {number} alpha - Opacity (0-1)
     */
    drawTileHighlight(ctx, screenX, screenY, color = '#ffffff', alpha = 0.3) {
        const vertices = IsometricRenderer.getDiamondVertices(screenX, screenY);

        ctx.beginPath();
        ctx.moveTo(vertices[0].x, vertices[0].y);
        ctx.lineTo(vertices[1].x, vertices[1].y);
        ctx.lineTo(vertices[2].x, vertices[2].y);
        ctx.lineTo(vertices[3].x, vertices[3].y);
        ctx.closePath();

        ctx.fillStyle = color;
        ctx.globalAlpha = alpha;
        ctx.fill();
        ctx.globalAlpha = 1;
    },

    /**
     * Draw a tile outline (for selection, targeting, etc.)
     * @param {CanvasRenderingContext2D} ctx - Canvas context
     * @param {number} screenX - Screen X center
     * @param {number} screenY - Screen Y center
     * @param {string} color - Outline color
     * @param {number} lineWidth - Line width
     */
    drawTileOutline(ctx, screenX, screenY, color = '#ffffff', lineWidth = 2) {
        const vertices = IsometricRenderer.getDiamondVertices(screenX, screenY);

        ctx.beginPath();
        ctx.moveTo(vertices[0].x, vertices[0].y);
        ctx.lineTo(vertices[1].x, vertices[1].y);
        ctx.lineTo(vertices[2].x, vertices[2].y);
        ctx.lineTo(vertices[3].x, vertices[3].y);
        ctx.closePath();

        ctx.strokeStyle = color;
        ctx.lineWidth = lineWidth;
        ctx.stroke();
    },

    /**
     * Render facilities on the isometric grid
     * @param {CanvasRenderingContext2D} ctx - Canvas context
     * @param {Object} stationLayout - Station layout data
     */
    renderFacilities(ctx, stationLayout) {
        if (!stationLayout || !stationLayout.facilities) return;

        stationLayout.facilities.forEach(facility => {
            if (facility.destroyed) return;

            const heightLevel = 1; // Facilities are on floor level
            const screen = IsometricRenderer.tileToScreen(
                facility.x + (facility.width || 1) / 2 - 0.5,
                facility.y + (facility.height || 1) / 2 - 0.5,
                heightLevel
            );

            // Draw facility highlight on tiles
            for (let fy = 0; fy < (facility.height || 1); fy++) {
                for (let fx = 0; fx < (facility.width || 1); fx++) {
                    const tileScreen = IsometricRenderer.tileToScreen(
                        facility.x + fx,
                        facility.y + fy,
                        heightLevel
                    );
                    this.drawTileHighlight(ctx, tileScreen.x, tileScreen.y, '#48bb78', 0.3);
                    this.drawTileOutline(ctx, tileScreen.x, tileScreen.y, '#48bb78', 2);
                }
            }

            // Draw facility info
            ctx.fillStyle = '#f6e05e';
            ctx.font = 'bold 10px sans-serif';
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';

            if (facility.credits) {
                ctx.fillText(`$${facility.credits}`, screen.x, screen.y);
            }

            // Facility icon
            if (facility.type) {
                const icons = {
                    residential: '🏠',
                    medical: '🏥',
                    armory: '🔫',
                    commTower: '📡',
                    powerPlant: '⚡',
                };
                const icon = icons[facility.type];
                if (icon) {
                    ctx.font = '14px sans-serif';
                    ctx.fillText(icon, screen.x, screen.y - 12);
                }
            }
        });
    },

    /**
     * Render spawn points on the isometric grid
     * @param {CanvasRenderingContext2D} ctx - Canvas context
     * @param {Object} stationLayout - Station layout data
     */
    renderSpawnPoints(ctx, stationLayout) {
        if (!stationLayout || !stationLayout.spawnPoints) return;

        stationLayout.spawnPoints.forEach(spawn => {
            const heightLevel = HeightSystem.getLayoutTileHeight(stationLayout, spawn.x, spawn.y);
            const screen = IsometricRenderer.tileToScreen(spawn.x, spawn.y, heightLevel);

            // Draw spawn indicator
            this.drawTileHighlight(ctx, screen.x, screen.y, '#fc8181', 0.2);

            // Direction indicator
            if (spawn.direction) {
                const dirs = {
                    north: { dx: 0, dy: -1 },
                    south: { dx: 0, dy: 1 },
                    east: { dx: 1, dy: 0 },
                    west: { dx: -1, dy: 0 },
                };
                const dir = dirs[spawn.direction];
                if (dir) {
                    const targetScreen = IsometricRenderer.tileToScreen(
                        spawn.x + dir.dx,
                        spawn.y + dir.dy,
                        heightLevel
                    );

                    ctx.strokeStyle = 'rgba(252, 129, 129, 0.5)';
                    ctx.lineWidth = 2;
                    ctx.beginPath();
                    ctx.moveTo(screen.x, screen.y);
                    ctx.lineTo(
                        screen.x + (targetScreen.x - screen.x) * 0.6,
                        screen.y + (targetScreen.y - screen.y) * 0.6
                    );
                    ctx.stroke();
                }
            }
        });
    },
};

// Make available globally
window.TileRenderer = TileRenderer;
