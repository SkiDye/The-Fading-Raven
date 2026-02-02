/**
 * THE FADING RAVEN - Skill System
 * Handles crew skills with cooldowns, targeting, and effects
 */

const SkillSystem = {
    // Active skill instances (for tracking cooldowns per crew)
    activeSkills: new Map(),

    // Skill definitions with execution logic
    skills: {
        // ==========================================
        // GUARDIAN - Shield Bash
        // ==========================================
        shieldBash: {
            id: 'shieldBash',
            name: '실드 배쉬',
            type: 'direction',
            baseCooldown: 10000,

            /**
             * Execute Shield Bash
             * @param {Object} caster - The crew using the skill
             * @param {Object} target - Target position {x, y} or direction
             * @param {Object} battle - Battle controller reference
             * @param {number} level - Skill level (1-3)
             */
            execute(caster, target, battle, level = 1) {
                const effects = this.getEffects(level);
                const direction = Math.atan2(target.y - caster.y, target.x - caster.x);

                // Calculate dash distance
                const maxDist = effects.distance === -1
                    ? 999 // Unlimited
                    : effects.distance * battle.tileSize;

                // Find enemies along dash path
                let dashEndX = caster.x;
                let dashEndY = caster.y;
                const hitEnemies = [];

                // Check each step along the dash
                const steps = Math.ceil(maxDist / 10);
                for (let i = 1; i <= steps; i++) {
                    const checkX = caster.x + Math.cos(direction) * (i * 10);
                    const checkY = caster.y + Math.sin(direction) * (i * 10);

                    // Check for wall collision
                    if (battle.tileGrid) {
                        const tile = battle.tileGrid.pixelToTile(checkX, checkY, battle.offsetX, battle.offsetY);
                        if (!battle.tileGrid.isWalkable(tile.x, tile.y)) {
                            break;
                        }
                    }

                    dashEndX = checkX;
                    dashEndY = checkY;

                    // Check for enemy collision
                    for (const enemy of battle.enemies) {
                        if (hitEnemies.includes(enemy)) continue;
                        const dist = Utils.distance(checkX, checkY, enemy.x, enemy.y);
                        if (dist < enemy.size + 20) {
                            hitEnemies.push(enemy);
                        }
                    }

                    // Stop at max distance
                    if (Utils.distance(caster.x, caster.y, checkX, checkY) >= maxDist) {
                        break;
                    }
                }

                // Move caster to end position
                caster.x = dashEndX;
                caster.y = dashEndY;

                // Apply damage and knockback to hit enemies
                for (const enemy of hitEnemies) {
                    const damage = Math.floor(caster.damage * effects.damage);
                    enemy.health -= damage;
                    battle.addDamageNumber(enemy.x, enemy.y, damage);

                    // Knockback
                    const knockbackDist = effects.knockback * battle.tileSize;
                    enemy.x += Math.cos(direction) * knockbackDist;
                    enemy.y += Math.sin(direction) * knockbackDist;

                    // Stun (level 3)
                    if (effects.stun > 0) {
                        enemy.stunned = true;
                        enemy.stunTimer = effects.stun * 1000;
                    }
                }

                // Visual effect
                battle.addEffect({
                    type: 'dash_trail',
                    startX: caster.x - (dashEndX - caster.x),
                    startY: caster.y - (dashEndY - caster.y),
                    endX: dashEndX,
                    endY: dashEndY,
                    duration: 300,
                    timer: 0,
                    color: caster.color,
                });

                battle.addEffect({
                    type: 'shockwave',
                    x: dashEndX,
                    y: dashEndY,
                    duration: 300,
                    timer: 0,
                    color: caster.color,
                });

                return { success: true, hitCount: hitEnemies.length };
            },

            getEffects(level) {
                const levels = [
                    { distance: 3, knockback: 1, damage: 1.0, stun: 0 },
                    { distance: 5, knockback: 1.5, damage: 1.2, stun: 0 },
                    { distance: -1, knockback: 2, damage: 1.5, stun: 2 },
                ];
                return levels[Math.min(level, 3) - 1];
            },
        },

        // ==========================================
        // SENTINEL - Lance Charge
        // ==========================================
        lanceCharge: {
            id: 'lanceCharge',
            name: '랜스 차지',
            type: 'direction',
            baseCooldown: 12000,

            execute(caster, target, battle, level = 1) {
                const effects = this.getEffects(level);
                const direction = Math.atan2(target.y - caster.y, target.x - caster.x);

                const maxDist = effects.distance === -1
                    ? 999
                    : effects.distance * battle.tileSize;

                const startX = caster.x;
                const startY = caster.y;
                let endX = caster.x;
                let endY = caster.y;
                const hitEnemies = [];

                // Charge through enemies
                const steps = Math.ceil(maxDist / 10);
                for (let i = 1; i <= steps; i++) {
                    const checkX = caster.x + Math.cos(direction) * (i * 10);
                    const checkY = caster.y + Math.sin(direction) * (i * 10);

                    // Wall check
                    if (battle.tileGrid) {
                        const tile = battle.tileGrid.pixelToTile(checkX, checkY, battle.offsetX, battle.offsetY);
                        if (!battle.tileGrid.isWalkable(tile.x, tile.y)) {
                            break;
                        }
                    }

                    endX = checkX;
                    endY = checkY;

                    // Hit enemies (piercing through all)
                    for (const enemy of battle.enemies) {
                        if (hitEnemies.includes(enemy)) continue;
                        const dist = Utils.distance(checkX, checkY, enemy.x, enemy.y);
                        if (dist < enemy.size + 15) {
                            hitEnemies.push(enemy);
                        }
                    }

                    if (Utils.distance(startX, startY, checkX, checkY) >= maxDist) {
                        break;
                    }
                }

                caster.x = endX;
                caster.y = endY;

                // Apply damage - instant kill except brutes (unless level 3)
                for (const enemy of hitEnemies) {
                    const isBrute = enemy.type === 'brute';

                    if (isBrute && !effects.bruteKill) {
                        // Heavy damage but not instant kill
                        const damage = Math.floor(caster.damage * effects.damage);
                        enemy.health -= damage;
                        battle.addDamageNumber(enemy.x, enemy.y, damage);
                    } else {
                        // Instant kill
                        enemy.health = 0;
                        battle.addDamageNumber(enemy.x, enemy.y, '즉사');
                    }
                }

                // Visual
                battle.addEffect({
                    type: 'lance_trail',
                    startX: startX,
                    startY: startY,
                    endX: endX,
                    endY: endY,
                    duration: 400,
                    timer: 0,
                    color: caster.color,
                });

                return { success: true, hitCount: hitEnemies.length };
            },

            getEffects(level) {
                const levels = [
                    { distance: 3, damage: 2.0, bruteKill: false, piercing: true },
                    { distance: -1, damage: 2.5, bruteKill: false, piercing: true },
                    { distance: -1, damage: 3.0, bruteKill: true, piercing: true },
                ];
                return levels[Math.min(level, 3) - 1];
            },
        },

        // ==========================================
        // RANGER - Volley Fire
        // ==========================================
        volleyFire: {
            id: 'volleyFire',
            name: '볼리 파이어',
            type: 'position',
            baseCooldown: 8000,

            execute(caster, target, battle, level = 1) {
                const effects = this.getEffects(level);
                const radius = effects.aoeRadius * battle.tileSize;

                // Find all enemies in radius
                const hitEnemies = battle.enemies.filter(enemy =>
                    Utils.distance(target.x, target.y, enemy.x, enemy.y) <= radius
                );

                // Fire shots at each enemy
                for (const enemy of hitEnemies) {
                    for (let shot = 0; shot < effects.shotsPerUnit; shot++) {
                        setTimeout(() => {
                            // Calculate damage with shield penetration
                            let damage = caster.damage;
                            if (enemy.stats?.frontShield) {
                                damage *= effects.shieldPenetration;
                            }

                            // Create projectile
                            battle.projectiles.push({
                                x: caster.x,
                                y: caster.y,
                                angle: Utils.angleBetween(caster.x, caster.y, enemy.x, enemy.y),
                                speed: 500,
                                damage: damage,
                                target: enemy,
                                color: caster.color,
                                piercing: effects.piercing,
                            });
                        }, shot * 100);
                    }
                }

                // Visual effect
                battle.addEffect({
                    type: 'volley',
                    x: caster.x,
                    y: caster.y,
                    targetX: target.x,
                    targetY: target.y,
                    radius: radius,
                    duration: 500,
                    timer: 0,
                    color: caster.color,
                });

                battle.addEffect({
                    type: 'target_area',
                    x: target.x,
                    y: target.y,
                    radius: radius,
                    duration: 300,
                    timer: 0,
                    color: caster.color,
                });

                return { success: true, hitCount: hitEnemies.length };
            },

            getEffects(level) {
                const levels = [
                    { aoeRadius: 1, shotsPerUnit: 1, shieldPenetration: 0.3, piercing: false },
                    { aoeRadius: 1.5, shotsPerUnit: 2, shieldPenetration: 0.5, piercing: false },
                    { aoeRadius: 2, shotsPerUnit: 3, shieldPenetration: 0.7, piercing: true },
                ];
                return levels[Math.min(level, 3) - 1];
            },
        },

        // ==========================================
        // ENGINEER - Deploy Turret
        // ==========================================
        deployTurret: {
            id: 'deployTurret',
            name: '터렛 배치',
            type: 'position',
            baseCooldown: 15000,

            execute(caster, target, battle, level = 1) {
                const effects = this.getEffects(level);

                // Check current turret count
                const existingTurrets = battle.turrets?.filter(t => t.ownerId === caster.id) || [];
                if (existingTurrets.length >= effects.maxTurrets) {
                    // Remove oldest turret
                    const oldest = existingTurrets[0];
                    battle.turrets = battle.turrets.filter(t => t.id !== oldest.id);
                }

                // Create turret
                const turret = {
                    id: Utils.generateId(),
                    ownerId: caster.id,
                    x: target.x,
                    y: target.y,
                    health: 50 * effects.turretHealth,
                    maxHealth: 50 * effects.turretHealth,
                    damage: 8 * effects.turretDamage,
                    range: effects.turretRange,
                    attackSpeed: 1000,
                    attackTimer: 0,
                    slow: effects.slow,
                    slowAmount: 0.5,
                    slowDuration: 1000,
                    isHacked: false,
                    color: caster.color,
                };

                if (!battle.turrets) battle.turrets = [];
                battle.turrets.push(turret);

                // Visual effect
                battle.addEffect({
                    type: 'deploy',
                    x: target.x,
                    y: target.y,
                    duration: 500,
                    timer: 0,
                    color: caster.color,
                });

                return { success: true, turret: turret };
            },

            getEffects(level) {
                const levels = [
                    { maxTurrets: 1, turretDamage: 1.0, turretHealth: 1.0, turretRange: 150, slow: false },
                    { maxTurrets: 2, turretDamage: 1.5, turretHealth: 1.5, turretRange: 175, slow: false },
                    { maxTurrets: 3, turretDamage: 2.0, turretHealth: 2.0, turretRange: 200, slow: true },
                ];
                return levels[Math.min(level, 3) - 1];
            },
        },

        // ==========================================
        // BIONIC - Blink
        // ==========================================
        blink: {
            id: 'blink',
            name: '블링크',
            type: 'position',
            baseCooldown: 15000,

            execute(caster, target, battle, level = 1) {
                const effects = this.getEffects(level);
                const maxDist = effects.distance * battle.tileSize;

                // Clamp target to max distance
                const dist = Utils.distance(caster.x, caster.y, target.x, target.y);
                let finalX = target.x;
                let finalY = target.y;

                if (dist > maxDist) {
                    const angle = Utils.angleBetween(caster.x, caster.y, target.x, target.y);
                    finalX = caster.x + Math.cos(angle) * maxDist;
                    finalY = caster.y + Math.sin(angle) * maxDist;
                }

                // Check if destination is valid
                if (battle.tileGrid) {
                    const tile = battle.tileGrid.pixelToTile(finalX, finalY, battle.offsetX, battle.offsetY);
                    if (!battle.tileGrid.isWalkable(tile.x, tile.y)) {
                        const nearest = battle.tileGrid.findNearestWalkable(tile.x, tile.y);
                        if (nearest) {
                            const pixel = battle.tileGrid.tileToPixel(nearest.x, nearest.y, battle.offsetX, battle.offsetY);
                            finalX = pixel.x;
                            finalY = pixel.y;
                        }
                    }
                }

                // Store start position for visual
                const startX = caster.x;
                const startY = caster.y;

                // Teleport
                caster.x = finalX;
                caster.y = finalY;

                // Apply invulnerability
                caster.invulnerable = true;
                caster.invulnerableTimer = effects.invulnerabilityTime;

                // Stun on landing (level 3)
                if (effects.stunOnLanding) {
                    const stunRadius = effects.stunRadius * battle.tileSize;
                    for (const enemy of battle.enemies) {
                        if (Utils.distance(finalX, finalY, enemy.x, enemy.y) <= stunRadius) {
                            enemy.stunned = true;
                            enemy.stunTimer = effects.stunDuration * 1000;

                            battle.addEffect({
                                type: 'stun_indicator',
                                x: enemy.x,
                                y: enemy.y,
                                duration: effects.stunDuration * 1000,
                                timer: 0,
                            });
                        }
                    }
                }

                // Visual effects
                battle.addEffect({
                    type: 'blink_start',
                    x: startX,
                    y: startY,
                    duration: 300,
                    timer: 0,
                    color: caster.color,
                });

                battle.addEffect({
                    type: 'blink_end',
                    x: finalX,
                    y: finalY,
                    duration: 300,
                    timer: 0,
                    color: caster.color,
                });

                // Reduced cooldown
                const cooldownMult = 1 - effects.cooldownReduction;
                return { success: true, cooldownMultiplier: cooldownMult };
            },

            getEffects(level) {
                const levels = [
                    { distance: 2, cooldownReduction: 0, stunOnLanding: false, invulnerabilityTime: 200 },
                    { distance: 4, cooldownReduction: 0.2, stunOnLanding: false, invulnerabilityTime: 300 },
                    { distance: 6, cooldownReduction: 0.33, stunOnLanding: true, stunRadius: 1, stunDuration: 1.5, invulnerabilityTime: 500 },
                ];
                return levels[Math.min(level, 3) - 1];
            },
        },
    },

    // ==========================================
    // API Methods
    // ==========================================

    /**
     * Initialize skill tracking for a crew
     */
    initCrew(crew) {
        const skillId = this.getSkillIdForClass(crew.class);
        if (!skillId) return;

        const skill = this.skills[skillId];
        this.activeSkills.set(crew.id, {
            skillId: skillId,
            cooldown: 0,
            maxCooldown: skill.baseCooldown,
            level: crew.skillLevel || 1,
        });
    },

    /**
     * Get skill ID for class
     */
    getSkillIdForClass(classId) {
        const classSkills = {
            guardian: 'shieldBash',
            sentinel: 'lanceCharge',
            ranger: 'volleyFire',
            engineer: 'deployTurret',
            bionic: 'blink',
        };
        return classSkills[classId];
    },

    /**
     * Check if skill is ready
     */
    isSkillReady(crewId) {
        const state = this.activeSkills.get(crewId);
        return state && state.cooldown <= 0;
    },

    /**
     * Get cooldown percentage (0-1)
     */
    getCooldownPercent(crewId) {
        const state = this.activeSkills.get(crewId);
        if (!state) return 0;
        return Math.max(0, state.cooldown / state.maxCooldown);
    },

    /**
     * Get remaining cooldown in seconds
     */
    getRemainingCooldown(crewId) {
        const state = this.activeSkills.get(crewId);
        if (!state) return 0;
        return Math.max(0, Math.ceil(state.cooldown / 1000));
    },

    /**
     * Use a skill
     */
    useSkill(crew, target, battle) {
        const state = this.activeSkills.get(crew.id);
        if (!state || state.cooldown > 0) {
            return { success: false, reason: 'cooldown' };
        }

        const skill = this.skills[state.skillId];
        if (!skill) {
            return { success: false, reason: 'invalid_skill' };
        }

        // Execute skill
        const result = skill.execute(crew, target, battle, state.level);

        if (result.success) {
            // Apply cooldown
            let cooldown = state.maxCooldown;

            // Apply cooldown multiplier if returned
            if (result.cooldownMultiplier) {
                cooldown *= result.cooldownMultiplier;
            }

            // Apply trait bonuses
            if (crew.trait === 'energetic') {
                cooldown *= 0.67; // -33% cooldown
            }

            state.cooldown = cooldown;
        }

        return result;
    },

    /**
     * Update cooldowns
     */
    update(dt) {
        for (const [crewId, state] of this.activeSkills) {
            if (state.cooldown > 0) {
                state.cooldown -= dt;
            }
        }
    },

    /**
     * Get skill info for display
     */
    getSkillInfo(crewId) {
        const state = this.activeSkills.get(crewId);
        if (!state) return null;

        const skill = this.skills[state.skillId];
        if (!skill) return null;

        return {
            id: skill.id,
            name: skill.name,
            type: skill.type,
            ready: state.cooldown <= 0,
            cooldownPercent: this.getCooldownPercent(crewId),
            remainingCooldown: this.getRemainingCooldown(crewId),
            level: state.level,
            effects: skill.getEffects(state.level),
        };
    },

    /**
     * Upgrade skill level
     */
    upgradeSkill(crewId) {
        const state = this.activeSkills.get(crewId);
        if (state && state.level < 3) {
            state.level++;
            return true;
        }
        return false;
    },

    /**
     * Reset all skills
     */
    reset() {
        this.activeSkills.clear();
    },

    /**
     * Get skill targeting info
     */
    getTargetingInfo(crewId) {
        const state = this.activeSkills.get(crewId);
        if (!state) return null;

        const skill = this.skills[state.skillId];
        if (!skill) return null;

        const effects = skill.getEffects(state.level);

        return {
            type: skill.type, // 'direction' or 'position'
            range: effects.distance || effects.aoeRadius || 5,
            radius: effects.aoeRadius || 0,
        };
    },
};

// Make available globally
window.SkillSystem = SkillSystem;
