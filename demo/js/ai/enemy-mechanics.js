/**
 * THE FADING RAVEN - Enemy Special Mechanics
 * Detailed implementation of special enemy abilities and interactions
 */

/**
 * Enemy Mechanics Manager
 * Handles complex interactions between enemy abilities and game systems
 */
class EnemyMechanicsManager {
    constructor() {
        this.hackingInProgress = new Map(); // enemyId -> hackData
        this.activeShields = new Map(); // generatorId -> Set of shielded enemy IDs
        this.activeDrones = new Map(); // carrierId -> drone array
        this.sniperTargets = new Map(); // sniperId -> target data
        this.explosionQueue = []; // Queued explosions

        this.events = Utils.createEventEmitter();
    }

    /**
     * Update all mechanics
     */
    update(deltaTime, context) {
        this.updateHacking(deltaTime, context);
        this.updateSniperAiming(deltaTime, context);
        this.updateShieldGenerators(context);
        this.updateDroneCarriers(deltaTime, context);
        this.processExplosions(context);
    }

    // ==========================================
    // Hacker Mechanics
    // ==========================================

    /**
     * Start hacking process
     */
    startHacking(hacker, turret) {
        if (this.hackingInProgress.has(hacker.id)) {
            return false;
        }

        const hackData = {
            hackerId: hacker.id,
            turretId: turret.id,
            progress: 0,
            totalTime: hacker.special?.hackTime || 5000,
            startTime: Date.now(),
        };

        this.hackingInProgress.set(hacker.id, hackData);

        this.events.emit('hackingStarted', {
            hacker,
            turret,
            hackTime: hackData.totalTime,
        });

        return true;
    }

    /**
     * Update hacking progress
     */
    updateHacking(deltaTime, context) {
        for (const [hackerId, hackData] of this.hackingInProgress) {
            const hacker = context.enemies?.find(e => e.id === hackerId);
            const turret = context.turrets?.find(t => t.id === hackData.turretId);

            // Cancel if hacker died or turret destroyed
            if (!hacker || hacker.health <= 0 || !turret || turret.health <= 0) {
                this.cancelHacking(hackerId);
                continue;
            }

            // Check if hacker moved out of range
            const hackRange = (hacker.special?.hackRange || 2) * 40;
            const distance = Utils.distance(hacker.x, hacker.y, turret.x, turret.y);

            if (distance > hackRange) {
                this.cancelHacking(hackerId);
                continue;
            }

            // Update progress
            hackData.progress += deltaTime;

            this.events.emit('hackingProgress', {
                hacker,
                turret,
                progress: hackData.progress / hackData.totalTime,
            });

            // Complete hacking
            if (hackData.progress >= hackData.totalTime) {
                this.completeHacking(hackerId, hacker, turret, context);
            }
        }
    }

    /**
     * Complete hacking - turn turret hostile
     * Note: Actual turret state change should be handled by TurretSystem listening to 'hackingComplete' event
     */
    completeHacking(hackerId, hacker, turret, context) {
        this.hackingInProgress.delete(hackerId);

        const effect = hacker.special?.hackEffect || 'turnHostile';

        // Emit event - TurretSystem should handle the actual state change
        this.events.emit('hackingComplete', {
            hacker,
            hackerId,
            turret,
            turretId: turret.id,
            effect,
        });
    }

    /**
     * Cancel hacking
     */
    cancelHacking(hackerId) {
        if (!this.hackingInProgress.has(hackerId)) return;

        const hackData = this.hackingInProgress.get(hackerId);
        this.hackingInProgress.delete(hackerId);

        this.events.emit('hackingCanceled', {
            hackerId,
            turretId: hackData.turretId,
        });
    }

    /**
     * Check if hacker is currently hacking
     */
    isHacking(hackerId) {
        return this.hackingInProgress.has(hackerId);
    }

    // ==========================================
    // Sniper Mechanics
    // ==========================================

    /**
     * Start sniper aiming
     */
    startSniperAiming(sniper, target) {
        if (this.sniperTargets.has(sniper.id)) {
            return false;
        }

        const aimData = {
            sniperId: sniper.id,
            targetId: target.id,
            targetType: target.isCrew ? 'crew' : 'other',
            progress: 0,
            totalTime: sniper.special?.aimTime || 3000,
            laserStart: { x: sniper.x, y: sniper.y },
            laserEnd: { x: target.x, y: target.y },
        };

        this.sniperTargets.set(sniper.id, aimData);

        this.events.emit('sniperAimStart', {
            sniper,
            target,
            aimTime: aimData.totalTime,
        });

        return true;
    }

    /**
     * Update sniper aiming
     */
    updateSniperAiming(deltaTime, context) {
        for (const [sniperId, aimData] of this.sniperTargets) {
            const sniper = context.enemies?.find(e => e.id === sniperId);
            const target = this.findTarget(aimData.targetId, context);

            // Cancel if sniper died or was stunned
            if (!sniper || sniper.health <= 0 || sniper.isStunned) {
                this.cancelSniperAiming(sniperId);
                continue;
            }

            // Target died - find new target or cancel
            if (!target || target.health <= 0) {
                this.cancelSniperAiming(sniperId);
                continue;
            }

            // Update laser endpoint (tracks target)
            aimData.laserStart = { x: sniper.x, y: sniper.y };
            aimData.laserEnd = { x: target.x, y: target.y };
            aimData.progress += deltaTime;

            this.events.emit('sniperAimUpdate', {
                sniper,
                target,
                progress: aimData.progress / aimData.totalTime,
                laserStart: aimData.laserStart,
                laserEnd: aimData.laserEnd,
            });

            // Fire shot
            if (aimData.progress >= aimData.totalTime) {
                this.fireSniperShot(sniperId, sniper, target, context);
            }
        }
    }

    /**
     * Fire sniper shot
     */
    fireSniperShot(sniperId, sniper, target, context) {
        this.sniperTargets.delete(sniperId);

        this.events.emit('sniperFire', {
            sniper,
            target,
            damage: sniper.damage,
            from: { x: sniper.x, y: sniper.y },
            to: { x: target.x, y: target.y },
        });

        // Reset sniper attack cooldown
        sniper.attackCooldown = sniper.attackSpeed;
    }

    /**
     * Cancel sniper aiming
     */
    cancelSniperAiming(sniperId) {
        if (!this.sniperTargets.has(sniperId)) return;

        this.sniperTargets.delete(sniperId);

        this.events.emit('sniperAimCanceled', { sniperId });
    }

    /**
     * Get sniper laser data for rendering
     */
    getSniperLasers() {
        const lasers = [];

        for (const [sniperId, aimData] of this.sniperTargets) {
            lasers.push({
                sniperId,
                from: aimData.laserStart,
                to: aimData.laserEnd,
                progress: aimData.progress / aimData.totalTime,
            });
        }

        return lasers;
    }

    // ==========================================
    // Shield Generator Mechanics
    // ==========================================

    /**
     * Update shield generators
     */
    updateShieldGenerators(context) {
        const enemies = context.enemies || [];
        const generators = enemies.filter(e => e.enemyId === 'shieldGenerator' && e.health > 0);

        // Clear old shields
        this.activeShields.clear();

        for (const generator of generators) {
            const shieldRadius = (generator.special?.shieldRadius || 2) * 40;
            const shielded = new Set();

            for (const enemy of enemies) {
                if (enemy.id === generator.id) continue;
                if (enemy.health <= 0) continue;

                const distance = Utils.distance(generator.x, generator.y, enemy.x, enemy.y);

                if (distance <= shieldRadius) {
                    shielded.add(enemy.id);
                    enemy.hasShield = true;
                    enemy.shieldType = generator.special?.shieldEffect || 'rangedImmunity';
                }
            }

            this.activeShields.set(generator.id, shielded);
        }

        // Remove shields from enemies not in any generator's range
        for (const enemy of enemies) {
            let isShielded = false;

            for (const shieldedSet of this.activeShields.values()) {
                if (shieldedSet.has(enemy.id)) {
                    isShielded = true;
                    break;
                }
            }

            if (!isShielded) {
                enemy.hasShield = false;
                enemy.shieldType = null;
            }
        }
    }

    /**
     * Check if enemy is shielded
     */
    isEnemyShielded(enemyId) {
        for (const shieldedSet of this.activeShields.values()) {
            if (shieldedSet.has(enemyId)) {
                return true;
            }
        }
        return false;
    }

    /**
     * Get shield effect for enemy
     */
    getShieldEffect(enemyId) {
        for (const [generatorId, shieldedSet] of this.activeShields) {
            if (shieldedSet.has(enemyId)) {
                return 'rangedImmunity'; // Default effect
            }
        }
        return null;
    }

    /**
     * Get shield generator visual data
     */
    getShieldVisuals(context) {
        const visuals = [];
        const enemies = context?.enemies || [];

        for (const [generatorId, shieldedSet] of this.activeShields) {
            const generator = enemies.find(e => e.id === generatorId);

            if (generator) {
                const shieldRadius = (generator.special?.shieldRadius || 2) * 40;

                visuals.push({
                    generatorId,
                    generatorPosition: { x: generator.x, y: generator.y },
                    shieldRadius,
                    shieldedCount: shieldedSet.size,
                    shieldedIds: [...shieldedSet],
                    shieldEffect: generator.special?.shieldEffect || 'rangedImmunity',
                    shieldColor: generator.special?.shieldColor || 'rgba(100, 200, 255, 0.3)',
                });
            }
        }

        return visuals;
    }

    // ==========================================
    // Drone Carrier Mechanics
    // ==========================================

    /**
     * Spawn drones from carrier
     */
    spawnDrones(carrier, context) {
        if (!carrier.special) return [];

        const maxDrones = carrier.special.maxDrones || 6;
        const currentDrones = this.activeDrones.get(carrier.id) || [];
        const aliveDrones = currentDrones.filter(d => d.health > 0);

        if (aliveDrones.length >= maxDrones) {
            return [];
        }

        const count = Math.min(
            carrier.special.dronesPerSpawn || 2,
            maxDrones - aliveDrones.length
        );

        const droneStats = carrier.special.droneStats;
        const rng = context.rng || { random: () => Math.random() };

        // Calculate spawn positions first for warning
        const spawnPositions = [];
        for (let i = 0; i < count; i++) {
            const angle = (Math.PI * 2 * i) / count + rng.random() * 0.5;
            const spawnDist = 40;
            spawnPositions.push({
                x: carrier.x + Math.cos(angle) * spawnDist,
                y: carrier.y + Math.sin(angle) * spawnDist,
            });
        }

        // Emit warning before spawn
        this.events.emit('droneSpawnWarning', {
            carrier,
            carrierId: carrier.id,
            spawnPositions,
            count,
            warningDuration: 1000, // 1초 경고
        });

        const newDrones = [];
        for (let i = 0; i < count; i++) {
            const drone = {
                id: Utils.generateId(),
                carrierId: carrier.id,
                x: spawnPositions[i].x,
                y: spawnPositions[i].y,
                health: droneStats.health,
                maxHealth: droneStats.health,
                damage: droneStats.damage,
                speed: droneStats.speed,
                attackRange: droneStats.attackRange,
                target: null,
                state: 'active',
                attackCooldown: 0,
            };

            newDrones.push(drone);
        }

        this.activeDrones.set(carrier.id, [...aliveDrones, ...newDrones]);

        this.events.emit('dronesSpawned', {
            carrier,
            drones: newDrones,
            spawnPositions,
        });

        return newDrones;
    }

    /**
     * Update drone carriers
     */
    updateDroneCarriers(deltaTime, context) {
        const enemies = context.enemies || [];
        const carriers = enemies.filter(e => e.enemyId === 'droneCarrier' && e.health > 0);

        for (const carrier of carriers) {
            // Check if should spawn drones
            if (carrier.shouldUseSpecial && carrier.shouldUseSpecial()) {
                this.spawnDrones(carrier, context);
                carrier.specialCooldown = carrier.special?.spawnInterval || 10000;
            }

            // Update carrier's drones
            const drones = this.activeDrones.get(carrier.id) || [];
            this.updateDrones(drones, deltaTime, context);
        }

        // Clean up drones from dead carriers
        for (const [carrierId, drones] of this.activeDrones) {
            const carrier = enemies.find(e => e.id === carrierId);

            if (!carrier || carrier.health <= 0) {
                // Destroy all drones when carrier dies
                if (carrier?.special?.dronesDisableOnDeath !== false) {
                    this.events.emit('dronesDestroyed', {
                        carrierId,
                        drones,
                    });
                    this.activeDrones.delete(carrierId);
                }
            }
        }
    }

    /**
     * Update individual drones
     */
    updateDrones(drones, deltaTime, context) {
        const crews = context.crews || [];

        for (const drone of drones) {
            if (drone.health <= 0) continue;

            // Update cooldown
            drone.attackCooldown = Math.max(0, drone.attackCooldown - deltaTime);

            // Find target
            if (!drone.target || drone.target.health <= 0) {
                drone.target = this.findNearestTarget(drone, crews);
            }

            if (!drone.target) continue;

            // Move towards target or attack
            const distance = Utils.distance(drone.x, drone.y, drone.target.x, drone.target.y);

            if (distance <= drone.attackRange && drone.attackCooldown <= 0) {
                // Attack
                this.events.emit('droneAttack', {
                    drone,
                    target: drone.target,
                    damage: drone.damage,
                });
                drone.attackCooldown = 1000; // 1 second between attacks
            } else if (distance > drone.attackRange) {
                // Move towards target
                const dx = drone.target.x - drone.x;
                const dy = drone.target.y - drone.y;
                const moveSpeed = (drone.speed * deltaTime) / 1000;

                drone.x += (dx / distance) * moveSpeed;
                drone.y += (dy / distance) * moveSpeed;
            }
        }
    }

    /**
     * Get all active drones
     */
    getAllDrones() {
        const allDrones = [];

        for (const drones of this.activeDrones.values()) {
            allDrones.push(...drones.filter(d => d.health > 0));
        }

        return allDrones;
    }

    /**
     * Damage a drone
     */
    damageDrone(droneId, damage) {
        for (const [carrierId, drones] of this.activeDrones) {
            const drone = drones.find(d => d.id === droneId);

            if (drone) {
                drone.health -= damage;

                if (drone.health <= 0) {
                    this.events.emit('droneDeath', {
                        drone,
                        carrierId,
                    });
                }

                return true;
            }
        }

        return false;
    }

    // ==========================================
    // Explosion Mechanics
    // ==========================================

    /**
     * Queue an explosion (from storm creatures, grenades, etc.)
     */
    queueExplosion(data) {
        this.explosionQueue.push({
            id: Utils.generateId(),
            x: data.x,
            y: data.y,
            radius: data.radius,
            damage: data.damage,
            source: data.source,
            delay: data.delay || 0,
            queueTime: Date.now(),
            damagesCrew: data.damagesCrew !== false,
            damagesEnemies: data.damagesEnemies || false,
        });
    }

    /**
     * Process queued explosions
     */
    processExplosions(context) {
        const now = Date.now();
        const toProcess = [];
        const remaining = [];

        for (const explosion of this.explosionQueue) {
            if (now - explosion.queueTime >= explosion.delay) {
                toProcess.push(explosion);
            } else {
                remaining.push(explosion);
            }
        }

        this.explosionQueue = remaining;

        for (const explosion of toProcess) {
            this.triggerExplosion(explosion, context);
        }
    }

    /**
     * Trigger an explosion
     */
    triggerExplosion(explosion, context) {
        const targets = [];

        // Check crew targets
        if (explosion.damagesCrew) {
            for (const crew of (context.crews || [])) {
                const distance = Utils.distance(explosion.x, explosion.y, crew.x, crew.y);

                if (distance <= explosion.radius) {
                    targets.push({ entity: crew, type: 'crew', distance });
                }
            }
        }

        // Check enemy targets (for friendly fire or special cases)
        if (explosion.damagesEnemies) {
            for (const enemy of (context.enemies || [])) {
                const distance = Utils.distance(explosion.x, explosion.y, enemy.x, enemy.y);

                if (distance <= explosion.radius) {
                    targets.push({ entity: enemy, type: 'enemy', distance });
                }
            }
        }

        // Check station
        if (explosion.damagesCrew && context.station) {
            const distance = Utils.distance(explosion.x, explosion.y, context.station.x, context.station.y);

            if (distance <= explosion.radius) {
                targets.push({ entity: context.station, type: 'station', distance });
            }
        }

        this.events.emit('explosion', {
            ...explosion,
            targets,
        });
    }

    // ==========================================
    // Utility Methods
    // ==========================================

    /**
     * Find target by ID
     */
    findTarget(targetId, context) {
        const crews = context.crews || [];
        const crew = crews.find(c => c.id === targetId);
        if (crew) return crew;

        const enemies = context.enemies || [];
        const enemy = enemies.find(e => e.id === targetId);
        if (enemy) return enemy;

        if (context.station?.id === targetId) {
            return context.station;
        }

        return null;
    }

    /**
     * Find nearest target
     */
    findNearestTarget(entity, targets) {
        let nearest = null;
        let nearestDist = Infinity;

        for (const target of targets) {
            if (target.health <= 0) continue;

            const dist = Utils.distance(entity.x, entity.y, target.x, target.y);

            if (dist < nearestDist) {
                nearestDist = dist;
                nearest = target;
            }
        }

        return nearest;
    }

    /**
     * Subscribe to events
     */
    on(event, callback) {
        this.events.on(event, callback);
    }

    /**
     * Unsubscribe from events
     */
    off(event, callback) {
        this.events.off(event, callback);
    }

    /**
     * Reset all mechanics
     */
    reset() {
        this.hackingInProgress.clear();
        this.activeShields.clear();
        this.activeDrones.clear();
        this.sniperTargets.clear();
        this.explosionQueue = [];
    }
}

/**
 * Damage Calculator
 * Handles damage calculation with special mechanics
 */
const DamageCalculator = {
    /**
     * Calculate damage with all modifiers
     */
    calculate(baseDamage, source, target, context) {
        let damage = baseDamage;
        const modifiers = [];

        // Check shield protection
        if (target.hasShield && target.shieldType === 'rangedImmunity') {
            if (source.damageType === 'ranged') {
                damage = 0;
                modifiers.push({ type: 'shieldBlock', value: 1 });
            }
        }

        // Check frontal shield
        if (target.data?.stats?.frontShield && source) {
            const angleToSource = Utils.angleBetween(target.x, target.y, source.x, source.y);
            const angleDiff = Math.abs(Utils.normalizeAngle(angleToSource) - Utils.normalizeAngle(target.angle || 0));

            const blockAngle = target.special?.blockAngle || 90;

            if (angleDiff <= Utils.degToRad(blockAngle / 2)) {
                if (source.damageType === 'ranged') {
                    const reduction = target.data.stats.frontShield;
                    damage = Math.floor(damage * (1 - reduction));
                    modifiers.push({ type: 'frontalShield', value: reduction });
                }
            }
        }

        // Apply difficulty multiplier for player damage to enemies
        if (target.enemyId && context.difficulty) {
            // No modifier for player damage - enemies have scaled health
        }

        return {
            finalDamage: Math.max(0, Math.floor(damage)),
            baseDamage,
            modifiers,
        };
    },
};

// Make available globally
window.EnemyMechanicsManager = EnemyMechanicsManager;
window.DamageCalculator = DamageCalculator;
