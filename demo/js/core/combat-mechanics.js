/**
 * THE FADING RAVEN - Combat Mechanics System
 * Implements Bad North-style combat mechanics:
 * - Landing knockback system
 * - Shield mechanics (disabled during melee)
 * - Lance raise mechanic (Sentinel weakness)
 * - Recovery/replenish time formula
 *
 * Coordinate System Notes:
 * - Supports both tile coordinates (tileX, tileY) and pixel coordinates (x, y)
 * - Integrates with IsometricRenderer for 2.5D coordinate conversion
 * - Uses HeightSystem for elevation-aware calculations
 */

const CombatMechanics = {
    // ==========================================
    // COORDINATE SYSTEM UTILITIES
    // ==========================================

    /**
     * Get tile coordinates from unit (supports both formats)
     * @param {Object} unit - Unit with position data
     * @param {Object} tileGrid - Optional tile grid for pixel conversion
     * @returns {{tileX: number, tileY: number}} Tile coordinates
     */
    getUnitTilePosition(unit, tileGrid = null) {
        // If unit has tile coordinates, use them directly
        if (unit.tileX !== undefined && unit.tileY !== undefined) {
            return { tileX: unit.tileX, tileY: unit.tileY };
        }

        // Convert pixel coordinates to tile coordinates
        if (unit.x !== undefined && unit.y !== undefined) {
            // Use IsometricRenderer if available
            if (typeof IsometricRenderer !== 'undefined' && IsometricRenderer.screenToTileInt) {
                const tile = IsometricRenderer.screenToTileInt(unit.x, unit.y, 0);
                return { tileX: tile.x, tileY: tile.y };
            }

            // Fallback to simple grid conversion
            const tileSize = tileGrid?.tileSize || 32;
            return {
                tileX: Math.floor(unit.x / tileSize),
                tileY: Math.floor(unit.y / tileSize),
            };
        }

        return { tileX: 0, tileY: 0 };
    },

    /**
     * Get height level for a unit's position
     * @param {Object} unit - Unit with position data
     * @param {Object} stationLayout - Station layout for height lookup
     * @returns {number} Height level (0-3)
     */
    getUnitHeight(unit, stationLayout) {
        // Use HeightSystem if available
        if (typeof HeightSystem !== 'undefined' && HeightSystem.getEntityHeight) {
            return HeightSystem.getEntityHeight(unit, stationLayout);
        }

        // Fallback: no height
        return 0;
    },

    /**
     * Calculate knockback direction accounting for camera rotation
     * @param {Object} attacker - Attacking unit
     * @param {Object} defender - Defending unit
     * @returns {number} Knockback angle in radians
     */
    getKnockbackDirection(attacker, defender) {
        const attackerPos = this.getUnitTilePosition(attacker);
        const defenderPos = this.getUnitTilePosition(defender);

        // Calculate base angle in tile space
        const dx = defenderPos.tileX - attackerPos.tileX;
        const dy = defenderPos.tileY - attackerPos.tileY;
        let angle = Math.atan2(dy, dx);

        // Apply camera rotation if IsometricRenderer is available
        if (typeof IsometricRenderer !== 'undefined') {
            const rotation = IsometricRenderer.camera?.rotation || 0;
            angle += (rotation * Math.PI) / 2;
        }

        return angle;
    },

    /**
     * Convert knockback distance from pixels to tiles
     * @param {number} knockbackPx - Knockback in pixels
     * @returns {number} Knockback in tiles
     */
    knockbackPxToTiles(knockbackPx) {
        const tileSize = IsometricRenderer?.config?.tileWidth || 64;
        return knockbackPx / tileSize;
    },

    // ==========================================
    // LANDING KNOCKBACK SYSTEM
    // ==========================================

    /**
     * Apply landing knockback when enemies spawn from airlock
     * @param {Object} crew - The crew being affected
     * @param {Object} spawnData - { enemyCount, spawnPoint }
     * @returns {Object} { knockback, stun, message }
     */
    applyLandingKnockback(crew, spawnData) {
        if (!crew || !spawnData) return null;

        const { enemyCount = 5 } = spawnData;
        const boatSize = BalanceData.getBoatSizeCategory(enemyCount);

        // Get crew traits
        const hasSteadyStance = crew.traits?.includes('steadyStance') || false;

        // Calculate knockback
        const result = BalanceData.calculateLandingKnockback({
            boatSize,
            enemyCount,
            unitGrade: crew.rank || 'standard',
            hasSteadyStance,
        });

        // Build result
        const knockbackResult = {
            knockbackPx: result.knockbackPx,
            stunDuration: result.stunDuration,
            applied: false,
            message: null,
        };

        if (result.isWeak) {
            knockbackResult.message = 'slight_push';
            knockbackResult.applied = true;
        } else if (result.isStrong) {
            knockbackResult.message = 'strong_knockback';
            knockbackResult.applied = true;
            // Check for void/space death
            knockbackResult.checkVoidDeath = true;
        } else {
            knockbackResult.message = 'moderate_push';
            knockbackResult.applied = true;
        }

        return knockbackResult;
    },

    /**
     * Check if knockback would push unit into void (instant death)
     * Supports both pixel coordinates and tile coordinates
     * @param {Object} unit - Unit position { x, y } or { tileX, tileY }
     * @param {number} knockbackPx - Knockback distance in pixels
     * @param {number} knockbackAngle - Direction of knockback (radians)
     * @param {Object} tileGrid - Reference to TileGrid/StationLayout for checking tiles
     * @returns {boolean} True if would fall into void
     */
    wouldFallIntoVoid(unit, knockbackPx, knockbackAngle, tileGrid) {
        if (!tileGrid) return false;

        // Get unit's current tile position
        const currentPos = this.getUnitTilePosition(unit, tileGrid);

        // Convert knockback to tiles
        const knockbackTiles = this.knockbackPxToTiles(knockbackPx);

        // Calculate end tile position
        const endTileX = Math.floor(currentPos.tileX + Math.cos(knockbackAngle) * knockbackTiles);
        const endTileY = Math.floor(currentPos.tileY + Math.sin(knockbackAngle) * knockbackTiles);

        // Check tile type using appropriate method
        let tile;
        if (tileGrid.getTile) {
            tile = tileGrid.getTile(endTileX, endTileY);
        } else if (tileGrid.tiles && Array.isArray(tileGrid.tiles)) {
            // StationLayout format: tiles[y][x]
            tile = tileGrid.tiles[endTileY]?.[endTileX];
        }

        // TileType.VOID = 0 (space/instant death), undefined = out of bounds
        return tile === 0 || tile === undefined;
    },

    /**
     * Check if moving between tiles would cross a height barrier
     * @param {number} fromX - Starting tile X
     * @param {number} fromY - Starting tile Y
     * @param {number} toX - Ending tile X
     * @param {number} toY - Ending tile Y
     * @param {Object} stationLayout - Station layout for height lookup
     * @returns {boolean} True if movement is blocked by height
     */
    isHeightBlocked(fromX, fromY, toX, toY, stationLayout) {
        if (typeof HeightSystem === 'undefined') return false;

        const fromHeight = HeightSystem.getLayoutTileHeight?.(stationLayout, fromX, fromY) || 0;
        const toHeight = HeightSystem.getLayoutTileHeight?.(stationLayout, toX, toY) || 0;

        // Can't be knocked UP to higher ground (can fall down)
        const heightDiff = toHeight - fromHeight;
        return heightDiff > 1; // Allow 1 level climb, block 2+ levels
    },

    // ==========================================
    // SHIELD MECHANICS
    // ==========================================

    /**
     * Calculate damage after shield reduction
     * @param {Object} defender - The defending crew
     * @param {Object} attacker - The attacking enemy
     * @param {number} baseDamage - Incoming damage
     * @param {string} attackType - 'ranged' | 'melee'
     * @returns {Object} { finalDamage, blocked, reason }
     */
    calculateShieldedDamage(defender, attacker, baseDamage, attackType) {
        const result = {
            finalDamage: baseDamage,
            blocked: false,
            reason: null,
        };

        // Only Guardian has shield
        if (defender.classId !== 'guardian') {
            return result;
        }

        // Shield only blocks ranged attacks
        if (attackType !== 'ranged') {
            result.reason = 'melee_attack';
            return result;
        }

        // Check if in melee combat (shield disabled)
        const distanceToEnemy = this.getDistanceBetween(defender, attacker);
        const isInMelee = BalanceData.isInMeleeCombat(distanceToEnemy);

        if (isInMelee) {
            result.reason = 'shield_disabled_melee';
            return result;
        }

        // Calculate facing angle for shield block
        const facingAngle = defender.facingAngle || 0;
        const attackAngle = this.getAngleBetween(attacker, defender);

        const shieldCheck = BalanceData.checkShieldBlock({
            isInMelee,
            facingAngle,
            attackAngle,
        });

        if (shieldCheck.blocked) {
            result.finalDamage = Math.floor(baseDamage * (1 - shieldCheck.damageReduction));
            result.blocked = true;
            result.reason = 'shield_block';
        }

        return result;
    },

    // ==========================================
    // LANCE (SENTINEL) MECHANICS
    // ==========================================

    /**
     * Update Sentinel lance state based on enemy proximity
     * @param {Object} sentinel - The sentinel crew
     * @param {Array} enemies - Array of nearby enemies
     * @returns {Object} { lanceRaised, canAttack, nearestEnemy }
     */
    updateLanceState(sentinel, enemies) {
        if (sentinel.classId !== 'sentinel') {
            return { lanceRaised: false, canAttack: true, nearestEnemy: null };
        }

        // Find nearest enemy
        let nearestEnemy = null;
        let nearestDistance = Infinity;

        for (const enemy of enemies) {
            const dist = this.getDistanceBetween(sentinel, enemy);
            if (dist < nearestDistance) {
                nearestDistance = dist;
                nearestEnemy = enemy;
            }
        }

        // Check lance state
        const lanceState = BalanceData.checkLanceState(nearestDistance);

        return {
            lanceRaised: lanceState.lanceRaised,
            canAttack: lanceState.canAttack,
            damageMultiplier: lanceState.damageMultiplier,
            nearestEnemy,
            nearestDistance,
        };
    },

    /**
     * Check if Sentinel can escape raised lance state
     * @param {Object} sentinel - The sentinel crew
     * @param {Array} enemies - Nearby enemies
     * @returns {Object} { canEscape, escapeMethod }
     */
    checkLanceEscapeOptions(sentinel, enemies) {
        const options = {
            canEscape: false,
            methods: [],
        };

        // Method 1: Use Shock Wave equipment
        if (sentinel.equipment?.id === 'shockWave') {
            const canUse = EquipmentEffects?.canUse?.(sentinel) ?? false;
            if (canUse) {
                options.methods.push({
                    type: 'equipment',
                    name: 'Shock Wave',
                    description: '충격파로 적을 밀어내 랜스 사거리 확보',
                });
            }
        }

        // Method 2: Move away (if not surrounded)
        const surroundedThreshold = 3;
        const closeEnemies = enemies.filter(e =>
            this.getDistanceBetween(sentinel, e) < 50
        );

        if (closeEnemies.length < surroundedThreshold) {
            options.methods.push({
                type: 'move',
                name: '후퇴',
                description: '후방으로 이동하여 적과 거리 확보',
            });
        }

        // Method 3: Allied unit engages close enemies
        options.methods.push({
            type: 'ally_support',
            name: '아군 지원',
            description: '다른 크루가 근접 적을 교전하여 처리',
        });

        options.canEscape = options.methods.length > 0;
        return options;
    },

    // ==========================================
    // RECOVERY/REPLENISH SYSTEM
    // ==========================================

    /**
     * Calculate recovery time for a crew at a facility
     * Bad North formula: 2 seconds × squad size
     * @param {Object} crew - The crew to recover
     * @returns {Object} { timeMs, description }
     */
    calculateRecoveryTime(crew) {
        if (!crew) return { timeMs: 0, description: '' };

        const squadSize = crew.squadSize || crew.members?.length || 8;
        const hasQuickRecovery = crew.traits?.includes('quickRecovery') || false;

        const timeMs = BalanceData.calculateRecoveryTime(squadSize, hasQuickRecovery);
        const timeSeconds = Math.ceil(timeMs / 1000);

        let description = `${timeSeconds}초 (${squadSize}명 × 2초)`;
        if (hasQuickRecovery) {
            description += ' [-33% 빠른 회복]';
        }

        return {
            timeMs,
            timeSeconds,
            squadSize,
            hasQuickRecovery,
            description,
        };
    },

    /**
     * Check if crew can start recovery
     * @param {Object} crew - The crew
     * @param {Object} facility - The facility to recover at
     * @returns {Object} { canRecover, reason }
     */
    canStartRecovery(crew, facility) {
        if (!crew || !facility) {
            return { canRecover: false, reason: 'invalid_input' };
        }

        // Check if facility is destroyed
        if (facility.destroyed) {
            return { canRecover: false, reason: 'facility_destroyed' };
        }

        // Check if crew needs recovery
        const currentMembers = crew.currentSquadSize || crew.members?.filter(m => m.alive).length || 0;
        const maxMembers = crew.squadSize || 8;

        if (currentMembers >= maxMembers) {
            return { canRecover: false, reason: 'squad_full' };
        }

        // Check if already recovering
        if (crew.isRecovering) {
            return { canRecover: false, reason: 'already_recovering' };
        }

        return { canRecover: true, reason: null };
    },

    /**
     * Handle facility destruction during recovery
     * @param {Object} crew - The recovering crew
     * @param {Object} facility - The destroyed facility
     * @returns {Object} { survived, lostMembers, message }
     */
    handleRecoveryInterruption(crew, facility) {
        // If facility destroyed during recovery, crew is in danger
        // In harder difficulties, this can mean squad loss

        const difficulty = GameState?.currentRun?.difficulty || 'normal';

        const result = {
            survived: true,
            lostMembers: 0,
            message: '',
            permanentLoss: false,
        };

        // Difficulty scaling for recovery interruption
        switch (difficulty) {
            case 'normal':
                // Crew survives but recovery cancelled
                result.message = '회복 중단됨 - 크루 생존';
                break;

            case 'hard':
                // Lose some recovered members
                result.lostMembers = Math.floor(crew.currentSquadSize * 0.2);
                result.message = `회복 중단 - ${result.lostMembers}명 손실`;
                break;

            case 'veryhard':
            case 'nightmare':
                // Risk of permanent squad loss
                const rng = Math.random();
                if (rng < 0.3) { // 30% chance of permanent loss
                    result.survived = false;
                    result.permanentLoss = true;
                    result.message = '회복 중 시설 파괴 - 분대 영구 손실!';
                } else {
                    result.lostMembers = Math.floor(crew.currentSquadSize * 0.4);
                    result.message = `회복 중단 - ${result.lostMembers}명 손실`;
                }
                break;
        }

        return result;
    },

    // ==========================================
    // UTILITY FUNCTIONS
    // ==========================================

    /**
     * Get distance between two units (supports both pixel and tile coordinates)
     * @param {Object} unit1 - First unit
     * @param {Object} unit2 - Second unit
     * @param {boolean} useTiles - If true, calculate in tile space
     * @returns {number} Distance (in pixels or tiles)
     */
    getDistanceBetween(unit1, unit2, useTiles = false) {
        if (!unit1 || !unit2) return Infinity;

        let dx, dy;

        if (useTiles || (unit1.tileX !== undefined && unit2.tileX !== undefined)) {
            // Use tile coordinates
            const pos1 = this.getUnitTilePosition(unit1);
            const pos2 = this.getUnitTilePosition(unit2);
            dx = pos2.tileX - pos1.tileX;
            dy = pos2.tileY - pos1.tileY;
        } else {
            // Use pixel coordinates
            dx = (unit2.x || 0) - (unit1.x || 0);
            dy = (unit2.y || 0) - (unit1.y || 0);
        }

        return Math.sqrt(dx * dx + dy * dy);
    },

    /**
     * Get distance in tiles between two units
     * @param {Object} unit1 - First unit
     * @param {Object} unit2 - Second unit
     * @returns {number} Distance in tiles
     */
    getTileDistance(unit1, unit2) {
        return this.getDistanceBetween(unit1, unit2, true);
    },

    /**
     * Get angle from unit1 to unit2 (supports both coordinate systems)
     * @param {Object} unit1 - Source unit
     * @param {Object} unit2 - Target unit
     * @param {boolean} useTiles - If true, calculate in tile space
     * @returns {number} Angle in degrees
     */
    getAngleBetween(unit1, unit2, useTiles = false) {
        if (!unit1 || !unit2) return 0;

        let dx, dy;

        if (useTiles || (unit1.tileX !== undefined && unit2.tileX !== undefined)) {
            const pos1 = this.getUnitTilePosition(unit1);
            const pos2 = this.getUnitTilePosition(unit2);
            dx = pos2.tileX - pos1.tileX;
            dy = pos2.tileY - pos1.tileY;
        } else {
            dx = (unit2.x || 0) - (unit1.x || 0);
            dy = (unit2.y || 0) - (unit1.y || 0);
        }

        return Math.atan2(dy, dx) * (180 / Math.PI);
    },

    // ==========================================
    // VOID KNOCKBACK COMBO (Bad North Water Death)
    // ==========================================

    /**
     * Process knockback and check for void death
     * Supports both pixel and tile coordinate systems
     * @param {Object} unit - Unit being knocked back
     * @param {number} knockbackPx - Knockback distance in pixels
     * @param {number} knockbackAngle - Direction of knockback (radians)
     * @param {Object} tileGrid - Reference to TileGrid/StationLayout
     * @returns {Object} { finalPosition, finalTilePosition, fellIntoVoid, grabbedLedge, rescueWindow }
     */
    processKnockbackWithVoidCheck(unit, knockbackPx, knockbackAngle, tileGrid) {
        // Get current position in both formats
        const currentTile = this.getUnitTilePosition(unit, tileGrid);
        const hasTileCoords = unit.tileX !== undefined;

        const result = {
            finalPosition: { x: unit.x || 0, y: unit.y || 0 },
            finalTilePosition: { tileX: currentTile.tileX, tileY: currentTile.tileY },
            fellIntoVoid: false,
            grabbedLedge: false,
            rescueWindow: 0,
            knockbackApplied: knockbackPx,
        };

        if (!tileGrid || knockbackPx <= 0) {
            return result;
        }

        // Convert knockback to tiles for tile-based checking
        const knockbackTiles = this.knockbackPxToTiles(knockbackPx);

        // Calculate end tile position
        const endTileX = currentTile.tileX + Math.cos(knockbackAngle) * knockbackTiles;
        const endTileY = currentTile.tileY + Math.sin(knockbackAngle) * knockbackTiles;

        // Check if would fall into void using tile coordinates
        const endUnit = { tileX: Math.floor(endTileX), tileY: Math.floor(endTileY) };
        if (this.wouldFallIntoVoid(endUnit, 0, 0, tileGrid)) {
            result.fellIntoVoid = true;

            // Check for ledge grab (elite units)
            const unitGrade = unit.rank || 'standard';
            const voidCheck = BalanceData.checkVoidDeath(endUnit, tileGrid, unitGrade);

            if (voidCheck.canGrabLedge) {
                result.fellIntoVoid = false;
                result.grabbedLedge = true;
                result.rescueWindow = voidCheck.rescueWindow;

                // Find edge position in tile space
                const edgeTile = this.findNearestEdgeTile(currentTile, endTileX, endTileY, tileGrid);
                result.finalTilePosition = edgeTile;

                // Convert to screen position if IsometricRenderer available
                if (typeof IsometricRenderer !== 'undefined' && IsometricRenderer.tileToScreen) {
                    const screen = IsometricRenderer.tileToScreen(edgeTile.tileX, edgeTile.tileY, 0);
                    result.finalPosition = { x: screen.x, y: screen.y };
                }
            }
        } else {
            // Normal knockback - update both position formats
            result.finalTilePosition = { tileX: Math.floor(endTileX), tileY: Math.floor(endTileY) };

            // Calculate pixel position
            if (typeof IsometricRenderer !== 'undefined' && IsometricRenderer.tileToScreen) {
                const screen = IsometricRenderer.tileToScreen(endTileX, endTileY, 0);
                result.finalPosition = { x: screen.x, y: screen.y };
            } else {
                // Fallback pixel calculation
                result.finalPosition = {
                    x: (unit.x || 0) + Math.cos(knockbackAngle) * knockbackPx,
                    y: (unit.y || 0) + Math.sin(knockbackAngle) * knockbackPx,
                };
            }
        }

        return result;
    },

    /**
     * Find nearest valid edge position in tile coordinates (for ledge grab)
     * @param {Object} startTile - Starting tile { tileX, tileY }
     * @param {number} targetTileX - Target tile X
     * @param {number} targetTileY - Target tile Y
     * @param {Object} tileGrid - Reference to TileGrid/StationLayout
     * @returns {Object} { tileX, tileY } nearest valid edge tile
     */
    findNearestEdgeTile(startTile, targetTileX, targetTileY, tileGrid) {
        // Linear search for last valid tile position
        let validTileX = startTile.tileX;
        let validTileY = startTile.tileY;

        const steps = 10;
        const dx = (targetTileX - startTile.tileX) / steps;
        const dy = (targetTileY - startTile.tileY) / steps;

        for (let i = 1; i <= steps; i++) {
            const testTileX = startTile.tileX + dx * i;
            const testTileY = startTile.tileY + dy * i;

            const testUnit = { tileX: Math.floor(testTileX), tileY: Math.floor(testTileY) };
            if (this.wouldFallIntoVoid(testUnit, 0, 0, tileGrid)) {
                break;
            }

            validTileX = testTileX;
            validTileY = testTileY;
        }

        return { tileX: validTileX, tileY: validTileY };
    },

    /**
     * Find nearest valid edge position (legacy pixel-based, kept for compatibility)
     * @param {Object} unit - Original unit position
     * @param {number} targetX - Target X position (pixels)
     * @param {number} targetY - Target Y position (pixels)
     * @param {Object} tileGrid - Reference to TileGrid
     * @returns {Object} { x, y } nearest valid edge position (pixels)
     */
    findNearestEdge(unit, targetX, targetY, tileGrid) {
        // Convert to tile-based calculation
        const startTile = this.getUnitTilePosition(unit, tileGrid);
        const targetTile = this.getUnitTilePosition({ x: targetX, y: targetY }, tileGrid);

        const edgeTile = this.findNearestEdgeTile(startTile, targetTile.tileX, targetTile.tileY, tileGrid);

        // Convert back to pixels if possible
        if (typeof IsometricRenderer !== 'undefined' && IsometricRenderer.tileToScreen) {
            const screen = IsometricRenderer.tileToScreen(edgeTile.tileX, edgeTile.tileY, 0);
            return { x: screen.x, y: screen.y };
        }

        // Fallback: interpolate pixel position
        const steps = 10;
        let validX = unit.x;
        let validY = unit.y;
        const dx = (targetX - unit.x) / steps;
        const dy = (targetY - unit.y) / steps;

        for (let i = 1; i <= steps; i++) {
            const testX = unit.x + dx * i;
            const testY = unit.y + dy * i;

            if (this.wouldFallIntoVoid({ x: testX, y: testY }, 0, 0, tileGrid)) {
                break;
            }
            validX = testX;
            validY = testY;
        }

        return { x: validX, y: validY };
    },

    /**
     * Handle ledge grab rescue attempt
     * @param {Object} unit - Unit grabbing ledge
     * @param {Object} rescuer - Allied unit attempting rescue (optional)
     * @returns {Object} { rescued, method }
     */
    attemptLedgeRescue(unit, rescuer = null) {
        if (!unit.grabbingLedge) {
            return { rescued: false, method: null };
        }

        // Method 1: Allied unit nearby
        if (rescuer) {
            const distance = this.getDistanceBetween(unit, rescuer);
            if (distance < 50) {
                return { rescued: true, method: 'ally_rescue' };
            }
        }

        // Method 2: Self rescue (elite only, requires no nearby enemies)
        if (unit.rank === 'elite' && !unit.nearbyEnemies?.length) {
            return { rescued: true, method: 'self_rescue' };
        }

        return { rescued: false, method: null };
    },

    /**
     * Get full combat state for a crew
     * @param {Object} crew - The crew to evaluate
     * @param {Array} enemies - Nearby enemies
     * @returns {Object} Complete combat state
     */
    getFullCombatState(crew, enemies = []) {
        if (!crew) return null;

        // Find nearest enemy
        let nearestEnemy = null;
        let nearestDistance = Infinity;

        for (const enemy of enemies) {
            const dist = this.getDistanceBetween(crew, enemy);
            if (dist < nearestDistance) {
                nearestDistance = dist;
                nearestEnemy = enemy;
            }
        }

        // Get base combat state
        const baseState = BalanceData.getCombatState({
            classId: crew.classId,
            distanceToEnemy: nearestDistance,
            unitGrade: crew.rank || 'standard',
            traits: crew.traits || [],
        });

        // Add class-specific details
        const state = {
            ...baseState,
            nearestEnemy,
            nearestDistance,
            warnings: [],
        };

        // Add warnings
        if (state.lanceRaised) {
            state.warnings.push({
                type: 'lance_raised',
                message: '랜스 들어올림 - 공격 불가',
                severity: 'high',
            });
        }

        if (crew.classId === 'guardian' && state.isInMelee) {
            state.warnings.push({
                type: 'shield_disabled',
                message: '근접전 중 - 실드 비활성',
                severity: 'medium',
            });
        }

        if (crew.classId === 'ranger' && state.isInMelee) {
            state.warnings.push({
                type: 'melee_penalty',
                message: '근접전 중 - 사격 불가',
                severity: 'high',
            });
        }

        return state;
    },

    // ==========================================
    // UNIT GRADE COMBAT SCALING
    // ==========================================

    /**
     * Calculate damage with grade scaling
     * @param {Object} attacker - Attacking unit
     * @param {Object} defender - Defending unit
     * @param {number} baseDamage - Base damage value
     * @returns {Object} { finalDamage, attackerBonus, defenderReduction }
     */
    calculateGradeScaledDamage(attacker, defender, baseDamage) {
        const attackerGrade = attacker?.rank || 'standard';
        const defenderGrade = defender?.rank || 'standard';

        // Get grade stats
        const attackerStats = BalanceData.getUnitGradeStats(attackerGrade);
        const defenderStats = BalanceData.getUnitGradeStats(defenderGrade);

        // Apply attack power bonus
        const attackBonus = attackerStats.attackPower;

        // Apply defense reduction
        const defenseReduction = 1 / defenderStats.defense;

        // Calculate final damage
        const finalDamage = Math.floor(baseDamage * attackBonus * defenseReduction);

        return {
            finalDamage: Math.max(1, finalDamage), // minimum 1 damage
            attackerBonus: attackBonus,
            defenderReduction: defenderStats.defense,
            breakdown: {
                base: baseDamage,
                afterAttack: Math.floor(baseDamage * attackBonus),
                afterDefense: finalDamage,
            },
        };
    },

    /**
     * Get unit movement speed with grade scaling
     * @param {Object} unit - The unit
     * @param {number} baseSpeed - Base movement speed
     * @returns {number} Modified movement speed
     */
    getGradeScaledMoveSpeed(unit, baseSpeed) {
        const grade = unit?.rank || 'standard';
        return BalanceData.applyGradeModifier(baseSpeed, grade, 'moveSpeed');
    },

    /**
     * Get unit attack speed with grade scaling
     * @param {Object} unit - The unit
     * @param {number} baseAttackSpeed - Base attack speed (ms between attacks)
     * @returns {number} Modified attack speed (lower = faster)
     */
    getGradeScaledAttackSpeed(unit, baseAttackSpeed) {
        const grade = unit?.rank || 'standard';
        const modifier = BalanceData.getUnitGradeStats(grade).attackSpeed;
        // Inverse because higher modifier = faster attacks = lower delay
        return Math.floor(baseAttackSpeed / modifier);
    },

    /**
     * Check morale status based on grade and casualties
     * @param {Object} crew - The crew
     * @returns {Object} { morale, status, fleeing }
     */
    checkMorale(crew) {
        if (!crew) return { morale: 100, status: 'steady', fleeing: false };

        const grade = crew.rank || 'standard';
        const gradeStats = BalanceData.getUnitGradeStats(grade);

        // Calculate current morale
        const currentMembers = crew.currentSquadSize || crew.members?.filter(m => m.alive).length || 0;
        const maxMembers = crew.squadSize || 8;
        const casualtyRate = 1 - (currentMembers / maxMembers);

        // Base morale drops with casualties
        let morale = 100 - (casualtyRate * 100);

        // Apply grade morale bonus
        morale = morale * gradeStats.morale;
        morale = Math.min(100, Math.max(0, morale));

        // Determine status
        let status = 'steady';
        let fleeing = false;

        if (morale < 25) {
            status = 'breaking';
            fleeing = true;
        } else if (morale < 50) {
            status = 'wavering';
        } else if (morale < 75) {
            status = 'shaken';
        }

        return {
            morale: Math.floor(morale),
            status,
            fleeing,
            casualties: maxMembers - currentMembers,
            gradeBonus: gradeStats.morale,
        };
    },

    /**
     * Get maximum squad size for grade
     * @param {string} grade - Unit grade
     * @returns {number} Maximum squad size
     */
    getMaxSquadSize(grade = 'standard') {
        return BalanceData.getUnitGradeStats(grade).maxSquadSize;
    },
};

// Make available globally
window.CombatMechanics = CombatMechanics;
