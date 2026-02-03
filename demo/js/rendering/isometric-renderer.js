/**
 * THE FADING RAVEN - Isometric Renderer
 * 2.5D isometric rendering system with Bad North style visuals
 * Handles coordinate conversion between tile grid and screen space
 * Supports camera controls: zoom, rotation, pan
 */

const IsometricRenderer = {
    // Configuration
    config: {
        tileWidth: 64,      // Diamond horizontal width
        tileHeight: 32,     // Diamond vertical height (2:1 ratio)
        heightOffset: 20,   // Y offset per height level
        maxHeightLevels: 4, // 0-3 levels
    },

    // Camera state
    camera: {
        zoom: 1.0,          // Zoom level (0.5 ~ 2.0)
        rotation: 0,        // Rotation in 90-degree steps (0, 1, 2, 3)
        panX: 0,            // Pan offset X
        panY: 0,            // Pan offset Y
        targetZoom: 1.0,    // For smooth zoom animation
        targetRotation: 0,  // For smooth rotation animation
        rotationAngle: 0,   // Actual rotation angle in radians
    },

    // Camera limits
    cameraLimits: {
        minZoom: 0.5,
        maxZoom: 2.0,
        zoomStep: 0.1,
        rotationSteps: 4,   // 4 directions (0°, 90°, 180°, 270°)
    },

    // Origin point for centering the grid
    origin: { x: 0, y: 0 },

    // Canvas reference
    canvas: null,
    ctx: null,

    // Grid dimensions
    gridWidth: 0,
    gridHeight: 0,

    // Cached tile cache for performance
    tileCache: null,
    tileCacheDirty: true,

    // Animation state
    isAnimating: false,
    animationFrame: null,

    /**
     * Initialize the isometric renderer
     * @param {HTMLCanvasElement} canvas - The canvas element
     * @param {number} gridWidth - Grid width in tiles
     * @param {number} gridHeight - Grid height in tiles
     */
    init(canvas, gridWidth, gridHeight) {
        this.canvas = canvas;
        this.ctx = canvas.getContext('2d');
        this.gridWidth = gridWidth;
        this.gridHeight = gridHeight;

        // Reset camera
        this.resetCamera();

        // Calculate origin to center the grid
        this.calculateOrigin();

        // Initialize tile cache
        this.initTileCache();

        return this;
    },

    /**
     * Reset camera to default state
     */
    resetCamera() {
        this.camera.zoom = 1.0;
        this.camera.rotation = 0;
        this.camera.panX = 0;
        this.camera.panY = 0;
        this.camera.targetZoom = 1.0;
        this.camera.targetRotation = 0;
        this.camera.rotationAngle = 0;
    },

    /**
     * Calculate the origin point to center the isometric grid
     */
    calculateOrigin() {
        if (!this.canvas) return;

        const { tileWidth, tileHeight } = this.config;

        // Calculate total grid size in screen space
        // The grid forms a diamond shape
        const totalWidth = (this.gridWidth + this.gridHeight) * (tileWidth / 2);
        const totalHeight = (this.gridWidth + this.gridHeight) * (tileHeight / 2);

        // Center the grid on canvas
        this.origin.x = this.canvas.width / 2;
        this.origin.y = (this.canvas.height - totalHeight) / 2 + (this.gridHeight * tileHeight / 2);
    },

    /**
     * Recalculate origin when canvas resizes
     */
    onResize() {
        this.calculateOrigin();
        this.tileCacheDirty = true;
    },

    // ==========================================
    // CAMERA CONTROLS
    // ==========================================

    /**
     * Set zoom level
     * @param {number} zoom - Zoom level (0.5 ~ 2.0)
     * @param {boolean} animate - Whether to animate the transition
     */
    setZoom(zoom, animate = true) {
        const { minZoom, maxZoom } = this.cameraLimits;
        const clampedZoom = Math.max(minZoom, Math.min(maxZoom, zoom));

        if (animate) {
            this.camera.targetZoom = clampedZoom;
            this.startAnimation();
        } else {
            this.camera.zoom = clampedZoom;
            this.camera.targetZoom = clampedZoom;
            this.tileCacheDirty = true;
        }
    },

    /**
     * Zoom in
     * @param {number} steps - Number of steps to zoom in
     */
    zoomIn(steps = 1) {
        const newZoom = this.camera.targetZoom + (this.cameraLimits.zoomStep * steps);
        this.setZoom(newZoom);
    },

    /**
     * Zoom out
     * @param {number} steps - Number of steps to zoom out
     */
    zoomOut(steps = 1) {
        const newZoom = this.camera.targetZoom - (this.cameraLimits.zoomStep * steps);
        this.setZoom(newZoom);
    },

    /**
     * Rotate camera (90-degree steps)
     * @param {number} direction - 1 for clockwise, -1 for counter-clockwise
     * @param {boolean} animate - Whether to animate the transition
     */
    rotate(direction = 1, animate = true) {
        const { rotationSteps } = this.cameraLimits;
        let newRotation = this.camera.targetRotation + direction;

        // Wrap around
        if (newRotation < 0) newRotation = rotationSteps - 1;
        if (newRotation >= rotationSteps) newRotation = 0;

        if (animate) {
            this.camera.targetRotation = newRotation;
            this.startAnimation();
        } else {
            this.camera.rotation = newRotation;
            this.camera.targetRotation = newRotation;
            this.camera.rotationAngle = (newRotation * Math.PI) / 2;
            this.tileCacheDirty = true;
        }
    },

    /**
     * Rotate clockwise
     */
    rotateClockwise() {
        this.rotate(1);
    },

    /**
     * Rotate counter-clockwise
     */
    rotateCounterClockwise() {
        this.rotate(-1);
    },

    /**
     * Pan camera by delta
     * @param {number} dx - Delta X
     * @param {number} dy - Delta Y
     */
    pan(dx, dy) {
        this.camera.panX += dx;
        this.camera.panY += dy;
        this.tileCacheDirty = true;
    },

    /**
     * Reset pan to center
     */
    resetPan() {
        this.camera.panX = 0;
        this.camera.panY = 0;
        this.tileCacheDirty = true;
    },

    /**
     * Start camera animation
     */
    startAnimation() {
        if (this.isAnimating) return;
        this.isAnimating = true;
    },

    /**
     * Update camera animation
     * @param {number} dt - Delta time in ms
     * @returns {boolean} True if camera is still animating
     */
    updateCamera(dt) {
        const lerpSpeed = 0.15;
        let needsUpdate = false;

        // Smooth zoom
        if (Math.abs(this.camera.zoom - this.camera.targetZoom) > 0.001) {
            this.camera.zoom += (this.camera.targetZoom - this.camera.zoom) * lerpSpeed;
            needsUpdate = true;
        } else {
            this.camera.zoom = this.camera.targetZoom;
        }

        // Smooth rotation
        const targetAngle = (this.camera.targetRotation * Math.PI) / 2;
        let angleDiff = targetAngle - this.camera.rotationAngle;

        // Handle wrap-around for smooth rotation
        if (angleDiff > Math.PI) angleDiff -= Math.PI * 2;
        if (angleDiff < -Math.PI) angleDiff += Math.PI * 2;

        if (Math.abs(angleDiff) > 0.01) {
            this.camera.rotationAngle += angleDiff * lerpSpeed;
            needsUpdate = true;
        } else {
            this.camera.rotationAngle = targetAngle;
            this.camera.rotation = this.camera.targetRotation;
        }

        if (needsUpdate) {
            this.tileCacheDirty = true;
        }

        this.isAnimating = needsUpdate;
        return needsUpdate;
    },

    /**
     * Get current zoom level
     * @returns {number} Current zoom level
     */
    getZoom() {
        return this.camera.zoom;
    },

    /**
     * Get current rotation step (0-3)
     * @returns {number} Current rotation step
     */
    getRotation() {
        return this.camera.rotation;
    },

    /**
     * Get rotation angle in radians
     * @returns {number} Rotation angle
     */
    getRotationAngle() {
        return this.camera.rotationAngle;
    },

    // ==========================================
    // COORDINATE CONVERSION (with camera)
    // ==========================================

    /**
     * Apply rotation to tile coordinates
     * @param {number} tileX - Original tile X
     * @param {number} tileY - Original tile Y
     * @returns {{x: number, y: number}} Rotated tile coordinates
     */
    applyRotation(tileX, tileY) {
        const rotation = this.camera.rotation;
        const centerX = (this.gridWidth - 1) / 2;
        const centerY = (this.gridHeight - 1) / 2;

        // Translate to center
        let rx = tileX - centerX;
        let ry = tileY - centerY;

        // Apply rotation (90-degree steps)
        for (let i = 0; i < rotation; i++) {
            const temp = rx;
            rx = -ry;
            ry = temp;
        }

        // Translate back
        return {
            x: rx + centerX,
            y: ry + centerY,
        };
    },

    /**
     * Reverse rotation from tile coordinates
     * @param {number} tileX - Rotated tile X
     * @param {number} tileY - Rotated tile Y
     * @returns {{x: number, y: number}} Original tile coordinates
     */
    reverseRotation(tileX, tileY) {
        const rotation = this.camera.rotation;
        const centerX = (this.gridWidth - 1) / 2;
        const centerY = (this.gridHeight - 1) / 2;

        // Translate to center
        let rx = tileX - centerX;
        let ry = tileY - centerY;

        // Reverse rotation (90-degree steps)
        for (let i = 0; i < (4 - rotation) % 4; i++) {
            const temp = rx;
            rx = -ry;
            ry = temp;
        }

        // Translate back
        return {
            x: rx + centerX,
            y: ry + centerY,
        };
    },

    /**
     * Convert tile coordinates to screen coordinates
     * @param {number} tileX - Tile X position
     * @param {number} tileY - Tile Y position
     * @param {number} heightLevel - Height level (0-3)
     * @returns {{x: number, y: number}} Screen coordinates
     */
    tileToScreen(tileX, tileY, heightLevel = 0) {
        const { tileWidth, tileHeight, heightOffset } = this.config;
        const { zoom, panX, panY } = this.camera;

        // Apply rotation to tile coordinates
        const rotated = this.applyRotation(tileX, tileY);

        const halfW = tileWidth / 2;
        const halfH = tileHeight / 2;

        // Isometric projection formulas
        const isoX = (rotated.x - rotated.y) * halfW;
        const isoY = (rotated.x + rotated.y) * halfH - (heightLevel * heightOffset);

        // Apply zoom and pan
        return {
            x: this.origin.x + (isoX * zoom) + panX,
            y: this.origin.y + (isoY * zoom) + panY,
        };
    },

    /**
     * Convert screen coordinates to tile coordinates
     * @param {number} screenX - Screen X position
     * @param {number} screenY - Screen Y position
     * @param {number} heightLevel - Expected height level (for accurate conversion)
     * @returns {{x: number, y: number}} Tile coordinates (may be fractional)
     */
    screenToTile(screenX, screenY, heightLevel = 0) {
        const { tileWidth, tileHeight, heightOffset } = this.config;
        const { zoom, panX, panY } = this.camera;
        const halfW = tileWidth / 2;
        const halfH = tileHeight / 2;

        // Remove pan and zoom
        const isoX = (screenX - this.origin.x - panX) / zoom;
        const isoY = (screenY - this.origin.y - panY) / zoom + (heightLevel * heightOffset);

        // Inverse isometric projection
        const rotatedX = (isoX / halfW + isoY / halfH) / 2;
        const rotatedY = (isoY / halfH - isoX / halfW) / 2;

        // Reverse rotation
        const original = this.reverseRotation(rotatedX, rotatedY);

        return { x: original.x, y: original.y };
    },

    /**
     * Convert screen coordinates to tile coordinates (integer, snapped to nearest tile)
     * @param {number} screenX - Screen X position
     * @param {number} screenY - Screen Y position
     * @param {number} heightLevel - Expected height level
     * @returns {{x: number, y: number}} Tile coordinates (integer)
     */
    screenToTileInt(screenX, screenY, heightLevel = 0) {
        const tile = this.screenToTile(screenX, screenY, heightLevel);
        return {
            x: Math.floor(tile.x),
            y: Math.floor(tile.y),
        };
    },

    /**
     * Get depth value for sorting (back to front, low to high)
     * Higher depth = rendered later (on top)
     * @param {number} tileX - Tile X position
     * @param {number} tileY - Tile Y position
     * @param {number} heightLevel - Height level
     * @returns {number} Depth value for sorting
     */
    getDepth(tileX, tileY, heightLevel = 0) {
        // Apply rotation for correct depth sorting
        const rotated = this.applyRotation(tileX, tileY);

        // Formula: (tileX + tileY) * 1000 + heightLevel * 100 + tileX
        // This ensures:
        // - Back tiles (lower tileX + tileY sum) render first
        // - Lower heights render before higher heights at same position
        // - tileX as tiebreaker for same row
        return (rotated.x + rotated.y) * 1000 + heightLevel * 100 + rotated.x;
    },

    /**
     * Check if a tile position is visible on screen
     * @param {number} tileX - Tile X position
     * @param {number} tileY - Tile Y position
     * @param {number} heightLevel - Height level
     * @returns {boolean} True if visible
     */
    isTileVisible(tileX, tileY, heightLevel = 0) {
        if (!this.canvas) return false;

        const screen = this.tileToScreen(tileX, tileY, heightLevel);
        const { tileWidth, tileHeight, heightOffset, maxHeightLevels } = this.config;
        const { zoom } = this.camera;

        // Add margin for tile size and potential height (scaled by zoom)
        const margin = (tileWidth + (heightOffset * maxHeightLevels)) * zoom;

        return (
            screen.x >= -margin &&
            screen.x <= this.canvas.width + margin &&
            screen.y >= -margin &&
            screen.y <= this.canvas.height + margin
        );
    },

    /**
     * Apply camera transform to canvas context
     * @param {CanvasRenderingContext2D} ctx - Canvas context
     */
    applyCameraTransform(ctx) {
        // Camera transforms are handled in tileToScreen, no additional transform needed
        // This method is for future use if we want to apply transforms differently
    },

    /**
     * Get effective tile size (with zoom)
     * @returns {{width: number, height: number}} Effective tile dimensions
     */
    getEffectiveTileSize() {
        return {
            width: this.config.tileWidth * this.camera.zoom,
            height: this.config.tileHeight * this.camera.zoom,
        };
    },

    // ==========================================
    // TILE CACHE
    // ==========================================

    /**
     * Initialize tile cache for static tile rendering
     */
    initTileCache() {
        if (!this.canvas) return;

        this.tileCache = document.createElement('canvas');
        this.tileCache.width = this.canvas.width;
        this.tileCache.height = this.canvas.height;
        this.tileCacheDirty = true;
    },

    /**
     * Mark tile cache as dirty (needs re-render)
     */
    invalidateCache() {
        this.tileCacheDirty = true;
    },

    /**
     * Get the tile cache canvas
     * @returns {HTMLCanvasElement} Tile cache canvas
     */
    getTileCache() {
        return this.tileCache;
    },

    /**
     * Check if tile cache needs update
     * @returns {boolean} True if cache is dirty
     */
    isCacheDirty() {
        return this.tileCacheDirty;
    },

    /**
     * Mark cache as clean after rendering
     */
    markCacheClean() {
        this.tileCacheDirty = false;
    },

    /**
     * Get diamond tile vertices for a given position
     * @param {number} centerX - Center X in screen space
     * @param {number} centerY - Center Y in screen space
     * @returns {Array} Array of {x, y} vertices [top, right, bottom, left]
     */
    getDiamondVertices(centerX, centerY) {
        const { zoom } = this.camera;
        const halfW = (this.config.tileWidth / 2) * zoom;
        const halfH = (this.config.tileHeight / 2) * zoom;

        return [
            { x: centerX, y: centerY - halfH },           // Top
            { x: centerX + halfW, y: centerY },           // Right
            { x: centerX, y: centerY + halfH },           // Bottom
            { x: centerX - halfW, y: centerY },           // Left
        ];
    },

    /**
     * Get configuration value
     * @param {string} key - Config key
     * @returns {*} Config value
     */
    getConfig(key) {
        return this.config[key];
    },

    /**
     * Update configuration
     * @param {Object} newConfig - New config values
     */
    updateConfig(newConfig) {
        Object.assign(this.config, newConfig);
        this.calculateOrigin();
        this.tileCacheDirty = true;
    },

    /**
     * Get camera info for UI display
     * @returns {Object} Camera info
     */
    getCameraInfo() {
        return {
            zoom: Math.round(this.camera.zoom * 100),
            rotation: this.camera.rotation * 90,
            panX: Math.round(this.camera.panX),
            panY: Math.round(this.camera.panY),
        };
    },
};

// Make available globally
window.IsometricRenderer = IsometricRenderer;
