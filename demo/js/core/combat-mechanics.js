/**
 * THE FADING RAVEN - Combat Mechanics System
 * Implements Bad North-style combat mechanics:
 * - Landing knockback system
 * - Shield mechanics (disabled during melee)
 * - Lance raise mechanic (Sentinel weakness)
 * - Recovery/replenish time formula
 */

const CombatMechanics = {
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
     * @param {Object} unit - Unit position { x, y }
     * @param {number} knockbackPx - Knockback distance in pixels
     * @param {number} knockbackAngle - Direction of knockback
     * @param {Object} tileGrid - Reference to TileGrid for checking tiles
     * @returns {boolean} True if would fall into void
     */
    wouldFallIntoVoid(unit, knockbackPx, knockbackAngle, tileGrid) {
        if (!tileGrid) return false;

        // Calculate end position
        const endX = unit.x + Math.cos(knockbackAngle) * knockbackPx;
        const endY = unit.y + Math.sin(knockbackAngle) * knockbackPx;

        // Convert to tile coordinates
        const tileSize = tileGrid.tileSize || 32;
        const tileX = Math.floor(endX / tileSize);
        const tileY = Math.floor(endY / tileSize);

        // Check tile type
        const tile = tileGrid.getTile?.(tileX, tileY);

        // TileType.VOID = 0 (space/instant death)
        return tile === 0 || tile === undefined;
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
     * Get distance between two units
     */
    getDistanceBetween(unit1, unit2) {
        if (!unit1 || !unit2) return Infinity;
        const dx = (unit2.x || 0) - (unit1.x || 0);
        const dy = (unit2.y || 0) - (unit1.y || 0);
        return Math.sqrt(dx * dx + dy * dy);
    },

    /**
     * Get angle from unit1 to unit2
     */
    getAngleBetween(unit1, unit2) {
        if (!unit1 || !unit2) return 0;
        const dx = (unit2.x || 0) - (unit1.x || 0);
        const dy = (unit2.y || 0) - (unit1.y || 0);
        return Math.atan2(dy, dx) * (180 / Math.PI);
    },

    // ==========================================
    // VOID KNOCKBACK COMBO (Bad North Water Death)
    // ==========================================

    /**
     * Process knockback and check for void death
     * @param {Object} unit - Unit being knocked back
     * @param {number} knockbackPx - Knockback distance
     * @param {number} knockbackAngle - Direction of knockback (radians)
     * @param {Object} tileGrid - Reference to TileGrid
     * @returns {Object} { finalPosition, fellIntoVoid, grabbedLedge, rescueWindow }
     */
    processKnockbackWithVoidCheck(unit, knockbackPx, knockbackAngle, tileGrid) {
        const result = {
            finalPosition: { x: unit.x, y: unit.y },
            fellIntoVoid: false,
            grabbedLedge: false,
            rescueWindow: 0,
            knockbackApplied: knockbackPx,
        };

        if (!tileGrid || knockbackPx <= 0) {
            return result;
        }

        // Calculate end position
        const endX = unit.x + Math.cos(knockbackAngle) * knockbackPx;
        const endY = unit.y + Math.sin(knockbackAngle) * knockbackPx;

        // Check if would fall into void
        if (this.wouldFallIntoVoid({ x: endX, y: endY }, 0, 0, tileGrid)) {
            result.fellIntoVoid = true;

            // Check for ledge grab (elite units)
            const unitGrade = unit.rank || 'standard';
            const voidCheck = BalanceData.checkVoidDeath({ x: endX, y: endY }, tileGrid, unitGrade);

            if (voidCheck.canGrabLedge) {
                result.fellIntoVoid = false;
                result.grabbedLedge = true;
                result.rescueWindow = voidCheck.rescueWindow;

                // Position at edge, not in void
                const edgePosition = this.findNearestEdge(unit, endX, endY, tileGrid);
                result.finalPosition = edgePosition;
            }
        } else {
            // Normal knockback - find valid position
            result.finalPosition = { x: endX, y: endY };
        }

        return result;
    },

    /**
     * Find nearest valid edge position (for ledge grab)
     * @param {Object} unit - Original unit position
     * @param {number} targetX - Target X position
     * @param {number} targetY - Target Y position
     * @param {Object} tileGrid - Reference to TileGrid
     * @returns {Object} { x, y } nearest valid edge position
     */
    findNearestEdge(unit, targetX, targetY, tileGrid) {
        // Binary search for last valid position
        let validX = unit.x;
        let validY = unit.y;

        const steps = 10;
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
