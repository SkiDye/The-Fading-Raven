/**
 * THE FADING RAVEN - Crew AI System
 * Intelligent crew behavior with auto-skill, positioning, and threat assessment
 */

const CrewAI = {
    // AI settings per class
    classProfiles: {
        guardian: {
            preferredRange: 'melee',
            positioning: 'frontline',
            skillPriority: 'defensive',
            retreatThreshold: 0.25,
            aggressiveness: 0.8,
        },
        sentinel: {
            preferredRange: 'melee',
            positioning: 'frontline',
            skillPriority: 'offensive',
            retreatThreshold: 0.2,
            aggressiveness: 0.9,
        },
        ranger: {
            preferredRange: 'ranged',
            positioning: 'backline',
            skillPriority: 'offensive',
            retreatThreshold: 0.3,
            aggressiveness: 0.6,
            optimalRange: 150,
        },
        engineer: {
            preferredRange: 'ranged',
            positioning: 'support',
            skillPriority: 'utility',
            retreatThreshold: 0.35,
            aggressiveness: 0.5,
        },
        bionic: {
            preferredRange: 'melee',
            positioning: 'flanker',
            skillPriority: 'mobility',
            retreatThreshold: 0.15,
            aggressiveness: 0.95,
        },
    },

    // Enable/disable AI per crew
    enabledCrews: new Set(),

    /**
     * Enable AI for a crew
     */
    enable(crewId) {
        this.enabledCrews.add(crewId);
    },

    /**
     * Disable AI for a crew
     */
    disable(crewId) {
        this.enabledCrews.delete(crewId);
    },

    /**
     * Check if AI is enabled for a crew
     */
    isEnabled(crewId) {
        return this.enabledCrews.has(crewId);
    },

    /**
     * Enable AI for all crews
     */
    enableAll(crews) {
        crews.forEach(crew => this.enable(crew.id));
    },

    /**
     * Main AI update for a crew
     */
    update(crew, battle, dt) {
        if (!this.isEnabled(crew.id)) return;
        if (crew.stunned || crew.squadSize <= 0) return;

        const profile = this.classProfiles[crew.class] || this.classProfiles.guardian;
        const threats = this.assessThreats(crew, battle);
        const healthPercent = crew.squadSize / crew.maxSquadSize;

        // Priority 1: Check if should retreat
        if (this.shouldRetreat(crew, profile, healthPercent, threats)) {
            this.executeRetreat(crew, battle, profile);
            return;
        }

        // Priority 2: Auto-use skill if beneficial
        if (this.shouldUseSkill(crew, battle, threats)) {
            this.executeSkill(crew, battle, threats);
            return;
        }

        // Priority 3: Auto-use equipment if beneficial
        if (this.shouldUseEquipment(crew, battle, threats)) {
            this.executeEquipment(crew, battle, threats);
            return;
        }

        // Priority 4: Optimal positioning
        if (this.shouldReposition(crew, battle, profile, threats)) {
            this.executeReposition(crew, battle, profile, threats);
            return;
        }

        // Priority 5: Target selection (if idle or current target dead)
        if (crew.state === 'idle' || !crew.targetEnemy || crew.targetEnemy.health <= 0) {
            const bestTarget = this.selectBestTarget(crew, battle, threats);
            if (bestTarget) {
                crew.targetEnemy = bestTarget;
                crew.state = 'attacking';
            }
        }
    },

    // ==========================================
    // THREAT ASSESSMENT
    // ==========================================

    /**
     * Assess threats in the battlefield
     */
    assessThreats(crew, battle) {
        const threats = [];

        for (const enemy of battle.enemies) {
            if (enemy.health <= 0) continue;

            const dist = Utils.distance(crew.x, crew.y, enemy.x, enemy.y);
            const threat = this.calculateThreatScore(crew, enemy, dist);

            threats.push({
                enemy,
                distance: dist,
                score: threat.score,
                isImmediate: threat.isImmediate,
                type: enemy.type,
            });
        }

        // Sort by threat score (highest first)
        threats.sort((a, b) => b.score - a.score);

        return threats;
    },

    /**
     * Calculate threat score for an enemy
     */
    calculateThreatScore(crew, enemy, distance) {
        let score = 0;
        let isImmediate = false;

        // Base score from distance (closer = more threatening)
        score += Math.max(0, 300 - distance) / 3;

        // Enemy type modifiers
        const typeModifiers = {
            brute: 1.5,
            heavyTrooper: 1.3,
            pirateCaptain: 2.0,
            stormCore: 1.8,
            gunner: 1.2,
            sniper: 1.4,
            hacker: 1.3,
            jumper: 1.2,
            droneCarrier: 1.1,
        };
        score *= typeModifiers[enemy.type] || 1.0;

        // Health modifier (low health enemies are less threatening but good targets)
        const healthPct = enemy.health / enemy.maxHealth;
        score *= (0.5 + healthPct * 0.5);

        // Immediate threat if very close
        if (distance < 80) {
            isImmediate = true;
            score *= 1.5;
        }

        // Threat if enemy is targeting this crew
        if (enemy.targetCrew?.id === crew.id) {
            score *= 1.3;
            isImmediate = true;
        }

        return { score, isImmediate };
    },

    // ==========================================
    // SKILL USAGE
    // ==========================================

    /**
     * Check if crew should use skill
     */
    shouldUseSkill(crew, battle, threats) {
        if (!SkillSystem || !SkillSystem.isSkillReady(crew.id)) return false;

        const profile = this.classProfiles[crew.class];
        const skillInfo = SkillSystem.getSkillInfo(crew.id);
        if (!skillInfo) return false;

        // Class-specific skill logic
        switch (crew.class) {
            case 'guardian':
                // Shield Bash: Use when multiple enemies nearby
                const nearbyCount = threats.filter(t => t.distance < 100).length;
                return nearbyCount >= 2;

            case 'sentinel':
                // Lance Charge: Use when enemies in a line
                return threats.filter(t => t.distance < 200 && t.distance > 50).length >= 1;

            case 'ranger':
                // Volley Fire: Use when enemies clustered
                return this.hasEnemyCluster(battle, 3, 80);

            case 'engineer':
                // Deploy Turret: Use when no turret or turret destroyed
                const turrets = battle.turrets?.filter(t => t.ownerId === crew.id) || [];
                return turrets.length === 0 && threats.length > 0;

            case 'bionic':
                // Blink: Use to escape or engage
                const healthPct = crew.squadSize / crew.maxSquadSize;
                const immediateThreats = threats.filter(t => t.isImmediate);
                return (healthPct < 0.4 && immediateThreats.length >= 2) ||
                       (threats.length > 0 && threats[0].distance > 150);
        }

        return false;
    },

    /**
     * Execute skill usage
     */
    executeSkill(crew, battle, threats) {
        const target = this.getSkillTarget(crew, battle, threats);
        if (!target) return;

        SkillSystem.useSkill(crew, target, battle);
    },

    /**
     * Get optimal target for skill
     */
    getSkillTarget(crew, battle, threats) {
        if (threats.length === 0) return null;

        switch (crew.class) {
            case 'guardian':
            case 'sentinel':
                // Direction towards most enemies
                return this.getDirectionToMostEnemies(crew, battle);

            case 'ranger':
                // Center of enemy cluster
                return this.getEnemyClusterCenter(battle);

            case 'engineer':
                // Safe position for turret
                return this.getTurretPosition(crew, battle);

            case 'bionic':
                // Escape position or flank position
                const healthPct = crew.squadSize / crew.maxSquadSize;
                if (healthPct < 0.4) {
                    return this.getSafePosition(crew, battle);
                }
                return this.getFlankPosition(crew, battle, threats[0]?.enemy);
        }

        return threats[0]?.enemy ? { x: threats[0].enemy.x, y: threats[0].enemy.y } : null;
    },

    // ==========================================
    // EQUIPMENT USAGE
    // ==========================================

    /**
     * Check if crew should use equipment
     */
    shouldUseEquipment(crew, battle, threats) {
        if (!EquipmentEffects || !EquipmentEffects.canUse(crew.id)) return false;

        const state = EquipmentEffects.getState(crew.id);
        if (!state) return false;

        switch (state.equipmentId) {
            case 'fragGrenade':
            case 'proximityMine':
                return this.hasEnemyCluster(battle, 2, 60);

            case 'rallyHorn':
                const healthPct = crew.squadSize / crew.maxSquadSize;
                return healthPct < 0.5;

            case 'shieldGenerator':
                const crewsNeedShield = battle.crews.filter(c =>
                    c.squadSize / c.maxSquadSize < 0.6
                ).length;
                return crewsNeedShield >= 2;

            case 'shockWave':
                return threats.filter(t => t.distance < 80).length >= 3;

            case 'hackingDevice':
                return battle.turrets?.some(t => !t.isHacked && Utils.distance(crew.x, crew.y, t.x, t.y) < 150);

            case 'reviveKit':
                return battle.deadCrews?.length > 0;
        }

        return false;
    },

    /**
     * Execute equipment usage
     */
    executeEquipment(crew, battle, threats) {
        const state = EquipmentEffects.getState(crew.id);
        if (!state) return;

        let target = null;

        switch (state.equipmentId) {
            case 'fragGrenade':
            case 'proximityMine':
                target = this.getEnemyClusterCenter(battle);
                break;

            case 'rallyHorn':
            case 'shieldGenerator':
            case 'shockWave':
                target = { x: crew.x, y: crew.y };
                break;

            case 'hackingDevice':
                const turret = battle.turrets?.find(t =>
                    !t.isHacked && Utils.distance(crew.x, crew.y, t.x, t.y) < 150
                );
                if (turret) target = { x: turret.x, y: turret.y };
                break;

            case 'reviveKit':
                if (battle.deadCrews?.length > 0) {
                    target = { crewId: battle.deadCrews[0].id };
                }
                break;
        }

        if (target) {
            EquipmentEffects.use(crew, target, battle);
        }
    },

    // ==========================================
    // POSITIONING
    // ==========================================

    /**
     * Check if crew should reposition
     */
    shouldReposition(crew, battle, profile, threats) {
        if (crew.state === 'moving') return false;

        // Rangers should maintain distance
        if (profile.preferredRange === 'ranged' && profile.optimalRange) {
            const closestThreat = threats[0];
            if (closestThreat && closestThreat.distance < profile.optimalRange * 0.6) {
                return true;
            }
        }

        // Check for cover usage
        if (threats.length > 0 && !this.isInCover(crew, battle)) {
            const nearestCover = this.findNearestCover(crew, battle);
            if (nearestCover && Utils.distance(crew.x, crew.y, nearestCover.x, nearestCover.y) < 100) {
                return true;
            }
        }

        return false;
    },

    /**
     * Execute repositioning
     */
    executeReposition(crew, battle, profile, threats) {
        let targetPos = null;

        if (profile.preferredRange === 'ranged' && profile.optimalRange) {
            // Kite away from closest enemy
            const closest = threats[0]?.enemy;
            if (closest) {
                targetPos = this.getKitePosition(crew, closest, profile.optimalRange);
            }
        } else {
            // Move to cover
            const cover = this.findNearestCover(crew, battle);
            if (cover) {
                targetPos = cover;
            }
        }

        if (targetPos && battle.moveCrewTo) {
            battle.moveCrewTo(crew, targetPos.x, targetPos.y);
        }
    },

    // ==========================================
    // RETREAT
    // ==========================================

    /**
     * Check if crew should retreat
     */
    shouldRetreat(crew, profile, healthPercent, threats) {
        if (healthPercent > profile.retreatThreshold) return false;

        // Only retreat if there are immediate threats
        const immediateThreats = threats.filter(t => t.isImmediate);
        return immediateThreats.length > 0;
    },

    /**
     * Execute retreat
     */
    executeRetreat(crew, battle, profile) {
        const safePos = this.getSafePosition(crew, battle);
        if (safePos && battle.moveCrewTo) {
            battle.moveCrewTo(crew, safePos.x, safePos.y);
        }
    },

    // ==========================================
    // TARGET SELECTION
    // ==========================================

    /**
     * Select best target based on class and threats
     */
    selectBestTarget(crew, battle, threats) {
        if (threats.length === 0) return null;

        const profile = this.classProfiles[crew.class];

        // Prioritize based on class
        switch (profile.skillPriority) {
            case 'defensive':
                // Target enemies threatening allies
                const threateningEnemy = threats.find(t =>
                    battle.crews.some(c => c.id !== crew.id && t.enemy.targetCrew?.id === c.id)
                );
                if (threateningEnemy) return threateningEnemy.enemy;
                break;

            case 'offensive':
                // Target low health enemies for quick kills
                const lowHealth = threats.find(t =>
                    t.enemy.health / t.enemy.maxHealth < 0.3 && t.distance < crew.attackRange * 2
                );
                if (lowHealth) return lowHealth.enemy;
                break;

            case 'utility':
                // Target special enemies (hackers, carriers, etc.)
                const special = threats.find(t =>
                    ['hacker', 'droneCarrier', 'shieldGenerator'].includes(t.enemy.type)
                );
                if (special) return special.enemy;
                break;
        }

        // Default: highest threat in range
        const inRange = threats.find(t => t.distance < crew.attackRange * 1.5);
        return inRange?.enemy || threats[0]?.enemy;
    },

    // ==========================================
    // HELPER FUNCTIONS
    // ==========================================

    hasEnemyCluster(battle, minCount, radius) {
        for (const enemy of battle.enemies) {
            if (enemy.health <= 0) continue;

            let count = 0;
            for (const other of battle.enemies) {
                if (other.health <= 0 || other === enemy) continue;
                if (Utils.distance(enemy.x, enemy.y, other.x, other.y) < radius) {
                    count++;
                }
            }
            if (count >= minCount - 1) return true;
        }
        return false;
    },

    getEnemyClusterCenter(battle) {
        let bestPos = null;
        let maxCount = 0;

        for (const enemy of battle.enemies) {
            if (enemy.health <= 0) continue;

            let count = 0;
            let sumX = enemy.x;
            let sumY = enemy.y;

            for (const other of battle.enemies) {
                if (other.health <= 0) continue;
                if (Utils.distance(enemy.x, enemy.y, other.x, other.y) < 100) {
                    count++;
                    sumX += other.x;
                    sumY += other.y;
                }
            }

            if (count > maxCount) {
                maxCount = count;
                bestPos = { x: sumX / count, y: sumY / count };
            }
        }

        return bestPos;
    },

    getDirectionToMostEnemies(crew, battle) {
        let avgX = 0, avgY = 0, count = 0;

        for (const enemy of battle.enemies) {
            if (enemy.health <= 0) continue;
            if (Utils.distance(crew.x, crew.y, enemy.x, enemy.y) < 200) {
                avgX += enemy.x;
                avgY += enemy.y;
                count++;
            }
        }

        if (count === 0) return null;

        return { x: avgX / count, y: avgY / count };
    },

    getTurretPosition(crew, battle) {
        // Place turret near crew but with good line of sight
        const offset = 50;
        const positions = [
            { x: crew.x + offset, y: crew.y },
            { x: crew.x - offset, y: crew.y },
            { x: crew.x, y: crew.y + offset },
            { x: crew.x, y: crew.y - offset },
        ];

        // Return position with most enemy visibility
        let bestPos = positions[0];
        let bestScore = 0;

        for (const pos of positions) {
            let score = 0;
            for (const enemy of battle.enemies) {
                if (enemy.health <= 0) continue;
                const dist = Utils.distance(pos.x, pos.y, enemy.x, enemy.y);
                if (dist < 200) score++;
            }
            if (score > bestScore) {
                bestScore = score;
                bestPos = pos;
            }
        }

        return bestPos;
    },

    getSafePosition(crew, battle) {
        // Find position away from all enemies
        const enemies = battle.enemies.filter(e => e.health > 0);
        if (enemies.length === 0) return null;

        // Calculate average enemy position
        let avgX = 0, avgY = 0;
        enemies.forEach(e => { avgX += e.x; avgY += e.y; });
        avgX /= enemies.length;
        avgY /= enemies.length;

        // Move away from average enemy position
        const angle = Utils.angleBetween(avgX, avgY, crew.x, crew.y);
        const distance = 150;

        return {
            x: crew.x + Math.cos(angle) * distance,
            y: crew.y + Math.sin(angle) * distance,
        };
    },

    getFlankPosition(crew, battle, target) {
        if (!target) return null;

        // Get position to the side of the target
        const angle = Utils.angleBetween(target.x, target.y, crew.x, crew.y);
        const flankAngle = angle + (Math.PI / 2); // 90 degrees to the side
        const distance = 80;

        return {
            x: target.x + Math.cos(flankAngle) * distance,
            y: target.y + Math.sin(flankAngle) * distance,
        };
    },

    getKitePosition(crew, enemy, optimalRange) {
        const angle = Utils.angleBetween(enemy.x, enemy.y, crew.x, crew.y);
        const distance = optimalRange;

        return {
            x: enemy.x + Math.cos(angle) * distance,
            y: enemy.y + Math.sin(angle) * distance,
        };
    },

    isInCover(crew, battle) {
        if (!battle.tileGrid) return false;

        const tile = battle.tileGrid.pixelToTile(crew.x, crew.y, battle.offsetX, battle.offsetY);
        return battle.tileGrid.getTile(tile.x, tile.y)?.type === 'cover';
    },

    findNearestCover(crew, battle) {
        if (!battle.tileGrid) return null;

        const coverTiles = [];
        const grid = battle.tileGrid;

        for (let y = 0; y < grid.height; y++) {
            for (let x = 0; x < grid.width; x++) {
                const tile = grid.getTile(x, y);
                if (tile?.type === 'cover') {
                    const pixel = grid.tileToPixel(x, y, battle.offsetX, battle.offsetY);
                    coverTiles.push({ x: pixel.x, y: pixel.y, dist: Utils.distance(crew.x, crew.y, pixel.x, pixel.y) });
                }
            }
        }

        if (coverTiles.length === 0) return null;

        coverTiles.sort((a, b) => a.dist - b.dist);
        return coverTiles[0];
    },

    /**
     * Reset AI state
     */
    reset() {
        this.enabledCrews.clear();
    },
};

// Make available globally
window.CrewAI = CrewAI;
