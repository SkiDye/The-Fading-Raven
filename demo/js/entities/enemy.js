/**
 * THE FADING RAVEN - Enemy Entity System
 * Base enemy class and type-specific behaviors for 15 enemy types
 */

/**
 * Enemy states
 */
const EnemyState = {
    SPAWNING: 'spawning',
    IDLE: 'idle',
    MOVING: 'moving',
    ATTACKING: 'attacking',
    USING_ABILITY: 'using_ability',
    STUNNED: 'stunned',
    DYING: 'dying',
    DEAD: 'dead',
};

/**
 * Base Enemy class
 */
class Enemy {
    constructor(enemyId, x, y, difficulty = 'normal') {
        this.id = Utils.generateId();
        this.enemyId = enemyId;
        this.data = EnemyData.get(enemyId);

        if (!this.data) {
            throw new Error(`Unknown enemy type: ${enemyId}`);
        }

        // Position and movement
        this.x = x;
        this.y = y;
        this.targetX = x;
        this.targetY = y;
        this.angle = 0;
        this.velocity = { x: 0, y: 0 };

        // Apply difficulty scaling
        const diffMultiplier = BalanceData.getDifficultyMultiplier(difficulty, 'enemyHealth');
        const damageMultiplier = BalanceData.getDifficultyMultiplier(difficulty, 'enemyDamage');

        // Stats (scaled by difficulty)
        this.maxHealth = Math.ceil(this.data.stats.health * diffMultiplier);
        this.health = this.maxHealth;
        this.damage = Math.ceil(this.data.stats.damage * damageMultiplier);
        this.speed = this.data.stats.speed;
        this.attackSpeed = this.data.stats.attackSpeed;
        this.attackRange = this.data.stats.attackRange;

        // Combat state
        this.state = EnemyState.SPAWNING;
        this.target = null;
        this.lastAttackTime = 0;
        this.attackCooldown = 0;

        // Special mechanics
        this.special = this.data.behavior.special ? { ...this.data.behavior.special } : null;
        this.specialCooldown = 0;
        this.specialState = null;

        // Status effects
        this.statusEffects = [];
        this.isStunned = false;
        this.stunEndTime = 0;
        this.slowMultiplier = 1;

        // Visual
        this.visual = { ...this.data.visual };
        this.flashTime = 0;
        this.alpha = 1;

        // Flags
        this.isBoss = this.data.isBoss || false;
        this.invulnerable = this.data.invulnerable || false;
        this.markedForDeath = false;

        // Boss phase tracking
        if (this.isBoss && this.data.behavior.phases) {
            this.currentPhase = 0;
            this.phases = this.data.behavior.phases;
        }

        // Spawn animation
        this.spawnTimer = 500; // 500ms spawn animation

        // Death animation timer
        this.deathTimer = 0;
        this.deathDuration = 300; // 300ms death animation

        // Damage tracking for kill info
        this.totalDamageReceived = 0;
        this.damageBySource = new Map(); // sourceId -> total damage
        this.lastDamageSource = null;
        this.lastDamageTime = 0;

        // Event emitter storage
        this._events = {};
    }

    /**
     * Update enemy each frame
     */
    update(deltaTime, gameContext) {
        // Handle spawn animation
        if (this.state === EnemyState.SPAWNING) {
            this.spawnTimer -= deltaTime;
            if (this.spawnTimer <= 0) {
                this.state = EnemyState.IDLE;
            }
            return;
        }

        // Handle death animation
        if (this.state === EnemyState.DYING) {
            this.deathTimer += deltaTime;
            if (this.deathTimer >= this.deathDuration) {
                this.state = EnemyState.DEAD;
                this.emit('removed', { enemy: this });
            }
            return;
        }

        // Skip if already dead
        if (this.state === EnemyState.DEAD) {
            return;
        }

        // Update status effects
        this.updateStatusEffects(deltaTime);

        // Check stun
        if (this.isStunned) {
            if (Date.now() >= this.stunEndTime) {
                this.isStunned = false;
                this.state = EnemyState.IDLE;
            } else {
                this.state = EnemyState.STUNNED;
                return;
            }
        }

        // Update cooldowns
        this.attackCooldown = Math.max(0, this.attackCooldown - deltaTime);
        this.specialCooldown = Math.max(0, this.specialCooldown - deltaTime);

        // Boss phase check
        if (this.isBoss) {
            this.updateBossPhase();
        }

        // Behavior update (handled by BehaviorTree)
        // This will be called by the AI system
    }

    /**
     * Update boss phase based on health
     */
    updateBossPhase() {
        if (!this.phases) return;

        const healthPercent = this.health / this.maxHealth;

        for (let i = this.phases.length - 1; i >= 0; i--) {
            if (healthPercent <= this.phases[i].healthThreshold) {
                if (this.currentPhase !== i) {
                    this.currentPhase = i;
                    this.onPhaseChange(this.phases[i]);
                }
                break;
            }
        }
    }

    /**
     * Handle boss phase change
     */
    onPhaseChange(phase) {
        const phaseInfo = {
            enemy: this,
            phase,
            phaseNumber: this.currentPhase + 1,
            totalPhases: this.phases.length,
            healthThreshold: phase.healthThreshold,
            currentHealth: this.health,
            maxHealth: this.maxHealth,
            healthPercent: this.health / this.maxHealth,
            newAbilities: phase.abilities || [],
            statChanges: phase.statChanges || {},
            isEnraged: phase.enraged || false,
            phaseName: phase.name || `Phase ${this.currentPhase + 1}`,
        };

        // Emit phase change event with detailed info
        this.emit('phaseChange', phaseInfo);

        // Emit warning for UI display
        this.emit('bossPhaseWarning', {
            enemy: this,
            phaseName: phaseInfo.phaseName,
            isEnraged: phaseInfo.isEnraged,
            message: phaseInfo.isEnraged ? '보스 광폭화!' : `보스 ${phaseInfo.phaseName} 돌입!`,
        });
    }

    /**
     * Move towards target position
     */
    moveTowards(targetX, targetY, deltaTime) {
        const dx = targetX - this.x;
        const dy = targetY - this.y;
        const distance = Math.sqrt(dx * dx + dy * dy);

        if (distance < 1) {
            this.velocity.x = 0;
            this.velocity.y = 0;
            return true; // Arrived
        }

        // Calculate movement
        const effectiveSpeed = this.speed * this.slowMultiplier;
        const moveDistance = (effectiveSpeed * deltaTime) / 1000;

        if (moveDistance >= distance) {
            this.x = targetX;
            this.y = targetY;
            this.velocity.x = 0;
            this.velocity.y = 0;
            return true;
        }

        // Normalize and apply movement
        const normalX = dx / distance;
        const normalY = dy / distance;

        this.velocity.x = normalX * effectiveSpeed;
        this.velocity.y = normalY * effectiveSpeed;

        this.x += normalX * moveDistance;
        this.y += normalY * moveDistance;

        // Update facing angle
        this.angle = Math.atan2(dy, dx);

        this.state = EnemyState.MOVING;
        return false;
    }

    /**
     * Check if target is in attack range
     */
    isInAttackRange(target) {
        if (!target) return false;

        const distance = Utils.distance(this.x, this.y, target.x, target.y);
        return distance <= this.attackRange;
    }

    /**
     * Perform attack on target
     */
    attack(target) {
        if (!target || this.attackCooldown > 0) return false;

        this.state = EnemyState.ATTACKING;
        this.target = target;
        this.attackCooldown = this.attackSpeed;
        this.lastAttackTime = Date.now();

        // Face target
        this.angle = Utils.angleBetween(this.x, this.y, target.x, target.y);

        // Deal damage (will be handled by combat system)
        this.emit('attack', {
            enemy: this,
            target: target,
            damage: this.damage,
        });

        return true;
    }

    /**
     * Use special ability
     */
    useSpecialAbility(context) {
        if (!this.special || this.specialCooldown > 0) return false;

        this.state = EnemyState.USING_ABILITY;

        // Set cooldown based on special type
        const cooldownKey = this.special.type + 'Cooldown';
        this.specialCooldown = this.special[cooldownKey] || 5000;

        this.emit('specialAbility', {
            enemy: this,
            special: this.special,
            context: context,
        });

        return true;
    }

    /**
     * Take damage
     */
    takeDamage(amount, source = null, damageType = 'normal') {
        if (this.invulnerable) return 0;
        if (this.state === EnemyState.DYING || this.state === EnemyState.DEAD) return 0;

        // Check frontal shield
        if (this.data.stats.frontShield && source) {
            const angleToSource = Utils.angleBetween(this.x, this.y, source.x, source.y);
            // Calculate angle difference and normalize to -PI to PI range
            let angleDiff = angleToSource - this.angle;
            while (angleDiff > Math.PI) angleDiff -= Math.PI * 2;
            while (angleDiff < -Math.PI) angleDiff += Math.PI * 2;
            angleDiff = Math.abs(angleDiff);

            const blockAngle = this.special?.blockAngle || 90;
            if (angleDiff <= Utils.degToRad(blockAngle / 2)) {
                // Frontal attack blocked
                if (damageType === 'ranged') {
                    amount = Math.floor(amount * (1 - this.data.stats.frontShield));
                    this.emit('shieldBlock', { enemy: this, blocked: true });
                }
            }
        }

        // Apply damage
        const actualDamage = Math.min(amount, this.health);
        this.health -= actualDamage;

        // Track damage for kill info
        this.totalDamageReceived += actualDamage;
        this.lastDamageSource = source;
        this.lastDamageTime = Date.now();

        if (source && source.id) {
            const currentDamage = this.damageBySource.get(source.id) || 0;
            this.damageBySource.set(source.id, currentDamage + actualDamage);
        }

        // Visual feedback
        this.flashTime = 100;

        this.emit('damaged', {
            enemy: this,
            damage: actualDamage,
            source: source,
            remainingHealth: this.health,
            totalDamageReceived: this.totalDamageReceived,
        });

        // Check death
        if (this.health <= 0) {
            this.die(source);
        }

        return actualDamage;
    }

    /**
     * Heal enemy
     */
    heal(amount) {
        const actualHeal = Math.min(amount, this.maxHealth - this.health);
        this.health += actualHeal;

        this.emit('healed', {
            enemy: this,
            amount: actualHeal,
        });

        return actualHeal;
    }

    /**
     * Apply stun
     */
    applyStun(duration) {
        this.isStunned = true;
        this.stunEndTime = Date.now() + duration;
        this.state = EnemyState.STUNNED;

        this.emit('stunned', {
            enemy: this,
            duration: duration,
        });
    }

    /**
     * Apply slow effect
     */
    applySlow(multiplier, duration) {
        this.addStatusEffect({
            type: 'slow',
            multiplier: multiplier,
            duration: duration,
            startTime: Date.now(),
        });
    }

    /**
     * Add status effect
     */
    addStatusEffect(effect) {
        effect.id = Utils.generateId();
        effect.startTime = Date.now();
        this.statusEffects.push(effect);
        this.recalculateStatusEffects();
    }

    /**
     * Remove status effect
     */
    removeStatusEffect(effectId) {
        this.statusEffects = this.statusEffects.filter(e => e.id !== effectId);
        this.recalculateStatusEffects();
    }

    /**
     * Update status effects
     */
    updateStatusEffects(deltaTime) {
        const now = Date.now();
        const expiredEffects = this.statusEffects.filter(e =>
            e.duration && (now - e.startTime >= e.duration)
        );

        if (expiredEffects.length > 0) {
            this.statusEffects = this.statusEffects.filter(e =>
                !expiredEffects.includes(e)
            );
            this.recalculateStatusEffects();
        }
    }

    /**
     * Recalculate combined status effects
     */
    recalculateStatusEffects() {
        this.slowMultiplier = 1;

        for (const effect of this.statusEffects) {
            if (effect.type === 'slow') {
                this.slowMultiplier = Math.min(this.slowMultiplier, effect.multiplier);
            }
        }
    }

    /**
     * Handle enemy death
     */
    die(killer = null) {
        if (this.state === EnemyState.DYING || this.state === EnemyState.DEAD) return;

        this.state = EnemyState.DYING;
        this.markedForDeath = true;
        this.deathTimer = 0; // Reset death timer for animation

        // Build damage contribution data
        const damageContributions = [];
        for (const [sourceId, damage] of this.damageBySource) {
            damageContributions.push({
                sourceId,
                damage,
                percent: (damage / this.totalDamageReceived) * 100,
            });
        }
        damageContributions.sort((a, b) => b.damage - a.damage);

        // Find top damage dealer
        const topDamageDealer = damageContributions.length > 0 ? damageContributions[0] : null;

        this.emit('death', {
            enemy: this,
            enemyId: this.enemyId,
            killer: killer,
            killerId: killer?.id || null,
            killerName: killer?.name || killer?.classId || null,
            position: { x: this.x, y: this.y },
            isBoss: this.isBoss,
            // Kill statistics
            totalDamageReceived: this.totalDamageReceived,
            maxHealth: this.maxHealth,
            overkillDamage: Math.max(0, this.totalDamageReceived - this.maxHealth),
            damageContributions,
            topDamageDealer,
            // Reward info
            creditValue: this.data?.value || 0,
            tier: this.data?.tier || 1,
        });

        // Death animation handled in update() loop
    }

    /**
     * Get current behavior data
     */
    getBehaviorData() {
        return this.data.behavior;
    }

    /**
     * Check if enemy can attack station
     */
    canAttackStation() {
        return this.data.behavior.attacksStation;
    }

    /**
     * Get distance to target
     */
    distanceTo(target) {
        if (!target) return Infinity;
        return Utils.distance(this.x, this.y, target.x, target.y);
    }

    /**
     * Check if should use special ability
     */
    shouldUseSpecial() {
        if (!this.special || this.specialCooldown > 0) return false;
        return true;
    }

    /**
     * Get visual render data
     */
    getRenderData() {
        return {
            x: this.x,
            y: this.y,
            angle: this.angle,
            color: this.flashTime > 0 ? '#ffffff' : this.visual.color,
            size: this.visual.size,
            icon: this.visual.icon,
            health: this.health,
            maxHealth: this.maxHealth,
            state: this.state,
            alpha: this.alpha,
            isBoss: this.isBoss,
            // Shield status (set by EnemyMechanicsManager)
            hasShield: this.hasShield || false,
            shieldType: this.shieldType || null,
            // Boss phase info
            currentPhase: this.currentPhase,
            totalPhases: this.phases?.length || 0,
        };
    }

    // Simple event emitter
    on(event, callback) {
        if (!this._events[event]) this._events[event] = [];
        this._events[event].push(callback);
    }

    off(event, callback) {
        if (!this._events[event]) return;
        this._events[event] = this._events[event].filter(cb => cb !== callback);
    }

    emit(event, data) {
        if (!this._events[event]) return;
        this._events[event].forEach(cb => cb(data));
    }
}

// ==========================================
// Specialized Enemy Types
// ==========================================

/**
 * Jumper - Can jump to bypass defenses
 */
class JumperEnemy extends Enemy {
    constructor(x, y, difficulty) {
        super('jumper', x, y, difficulty);
        this.isJumping = false;
        this.jumpTarget = null;
    }

    canJump() {
        return !this.isJumping &&
               this.specialCooldown <= 0 &&
               this.special?.type === 'jumpAttack';
    }

    jump(targetX, targetY) {
        if (!this.canJump()) return false;

        // Emit warning before jump starts
        this.emit('specialActionWarning', {
            enemy: this,
            actionType: 'jump',
            warningDuration: 500, // 500ms warning
            targetPosition: { x: targetX, y: targetY },
            dangerRadius: this.special?.jumpDamageRadius || 40,
        });

        this.isJumping = true;
        this.jumpTarget = { x: targetX, y: targetY };
        this.specialCooldown = this.special.jumpCooldown;

        this.emit('jump', {
            enemy: this,
            from: { x: this.x, y: this.y },
            to: this.jumpTarget,
        });

        return true;
    }

    completeJump() {
        if (!this.isJumping || !this.jumpTarget) return;

        this.x = this.jumpTarget.x;
        this.y = this.jumpTarget.y;
        this.isJumping = false;
        this.jumpTarget = null;

        this.emit('jumpComplete', { enemy: this });
    }
}

/**
 * Hacker - Can hack turrets
 */
class HackerEnemy extends Enemy {
    constructor(x, y, difficulty) {
        super('hacker', x, y, difficulty);
        this.hackTarget = null;
        this.hackProgress = 0;
        this.isHacking = false;
    }

    startHacking(turret) {
        if (!turret || this.isHacking) return false;

        const distance = this.distanceTo(turret);
        const hackRange = (this.special?.hackRange || 2) * 40; // Convert tiles to pixels

        if (distance > hackRange) return false;

        // Emit warning when hacking starts
        this.emit('specialActionWarning', {
            enemy: this,
            actionType: 'hack',
            warningDuration: this.special?.hackTime || 5000,
            targetEntity: turret,
            targetPosition: { x: turret.x, y: turret.y },
        });

        this.isHacking = true;
        this.hackTarget = turret;
        this.hackProgress = 0;
        this.state = EnemyState.USING_ABILITY;

        this.emit('hackStart', {
            enemy: this,
            target: turret,
            hackTime: this.special?.hackTime || 5000,
        });

        return true;
    }

    updateHacking(deltaTime) {
        if (!this.isHacking || !this.hackTarget) return;

        this.hackProgress += deltaTime;

        if (this.hackProgress >= (this.special?.hackTime || 5000)) {
            this.completeHacking();
        }
    }

    completeHacking() {
        if (!this.hackTarget) return;

        this.emit('hackComplete', {
            enemy: this,
            target: this.hackTarget,
            effect: this.special?.hackEffect,
        });

        this.isHacking = false;
        this.hackTarget = null;
        this.hackProgress = 0;
        this.state = EnemyState.IDLE;
    }

    cancelHacking() {
        this.isHacking = false;
        this.hackTarget = null;
        this.hackProgress = 0;
        this.state = EnemyState.IDLE;

        this.emit('hackCanceled', { enemy: this });
    }
}

/**
 * Sniper - Long range, visible laser aiming
 */
class SniperEnemy extends Enemy {
    constructor(x, y, difficulty) {
        super('sniper', x, y, difficulty);
        this.isAiming = false;
        this.aimTarget = null;
        this.aimProgress = 0;
        this.laserEndpoint = null;
    }

    startAiming(target) {
        if (!target || this.isAiming) return false;

        const aimTime = this.special?.aimTime || 3000;

        // Emit warning when aiming starts
        this.emit('specialActionWarning', {
            enemy: this,
            actionType: 'sniper',
            warningDuration: aimTime,
            targetEntity: target,
            targetPosition: { x: target.x, y: target.y },
            laserVisible: true,
        });

        this.isAiming = true;
        this.aimTarget = target;
        this.aimProgress = 0;
        this.state = EnemyState.USING_ABILITY;

        // Can't move while aiming
        this.velocity.x = 0;
        this.velocity.y = 0;

        this.emit('aimStart', {
            enemy: this,
            target: target,
            aimTime: aimTime,
        });

        return true;
    }

    updateAiming(deltaTime) {
        if (!this.isAiming || !this.aimTarget) return;

        this.aimProgress += deltaTime;

        // Update laser endpoint (tracks target)
        this.laserEndpoint = { x: this.aimTarget.x, y: this.aimTarget.y };
        this.angle = Utils.angleBetween(this.x, this.y, this.aimTarget.x, this.aimTarget.y);

        if (this.aimProgress >= (this.special?.aimTime || 3000)) {
            this.fireShot();
        }
    }

    fireShot() {
        if (!this.aimTarget) return;

        this.emit('sniperShot', {
            enemy: this,
            target: this.aimTarget,
            damage: this.damage,
        });

        this.isAiming = false;
        this.aimTarget = null;
        this.aimProgress = 0;
        this.laserEndpoint = null;
        this.attackCooldown = this.attackSpeed;
        this.state = EnemyState.IDLE;
    }

    cancelAiming() {
        this.isAiming = false;
        this.aimTarget = null;
        this.aimProgress = 0;
        this.laserEndpoint = null;
        this.state = EnemyState.IDLE;
    }

    getRenderData() {
        const data = super.getRenderData();
        data.isAiming = this.isAiming;
        data.aimProgress = this.aimProgress / (this.special?.aimTime || 3000);
        data.laserEndpoint = this.laserEndpoint;
        return data;
    }
}

/**
 * Drone Carrier - Spawns drones
 */
class DroneCarrierEnemy extends Enemy {
    constructor(x, y, difficulty) {
        super('droneCarrier', x, y, difficulty);
        this.drones = [];
        this.lastSpawnTime = 0;
    }

    canSpawnDrones() {
        if (!this.special) return false;

        const maxDrones = this.special.maxDrones || 6;
        const aliveDrones = this.drones.filter(d => !d.markedForDeath).length;

        return aliveDrones < maxDrones && this.specialCooldown <= 0;
    }

    spawnDrones() {
        if (!this.canSpawnDrones()) return [];

        const count = this.special.dronesPerSpawn || 2;
        const newDrones = [];

        for (let i = 0; i < count; i++) {
            const angle = (Math.PI * 2 * i) / count;
            const spawnDist = 30;

            const drone = {
                id: Utils.generateId(),
                parentId: this.id,
                x: this.x + Math.cos(angle) * spawnDist,
                y: this.y + Math.sin(angle) * spawnDist,
                stats: { ...this.special.droneStats },
                health: this.special.droneStats.health,
                maxHealth: this.special.droneStats.health,
                markedForDeath: false,
            };

            this.drones.push(drone);
            newDrones.push(drone);
        }

        this.specialCooldown = this.special.spawnInterval || 10000;
        this.lastSpawnTime = Date.now();

        this.emit('dronesSpawned', {
            enemy: this,
            drones: newDrones,
        });

        return newDrones;
    }

    removeDrone(droneId) {
        this.drones = this.drones.filter(d => d.id !== droneId);
    }

    die(killer) {
        // Destroy all drones when carrier dies
        if (this.special?.dronesDisableOnDeath) {
            this.emit('dronesDestroyed', {
                enemy: this,
                drones: [...this.drones],
            });
            this.drones = [];
        }

        super.die(killer);
    }
}

/**
 * Shield Generator - Provides shields to nearby enemies
 */
class ShieldGeneratorEnemy extends Enemy {
    constructor(x, y, difficulty) {
        super('shieldGenerator', x, y, difficulty);
        this.shieldedEnemies = new Set();
    }

    getShieldRadius() {
        return (this.special?.shieldRadius || 2) * 40; // Convert tiles to pixels
    }

    updateShields(nearbyEnemies) {
        const radius = this.getShieldRadius();
        const newShielded = new Set();

        for (const enemy of nearbyEnemies) {
            if (enemy.id === this.id) continue;

            const distance = this.distanceTo(enemy);
            if (distance <= radius) {
                newShielded.add(enemy.id);

                if (!this.shieldedEnemies.has(enemy.id)) {
                    this.emit('shieldApplied', {
                        generator: this,
                        target: enemy,
                        effect: this.special?.shieldEffect,
                    });
                }
            }
        }

        // Remove shields from enemies that left range
        for (const enemyId of this.shieldedEnemies) {
            if (!newShielded.has(enemyId)) {
                this.emit('shieldRemoved', {
                    generator: this,
                    targetId: enemyId,
                });
            }
        }

        this.shieldedEnemies = newShielded;
    }

    isShielding(enemyId) {
        return this.shieldedEnemies.has(enemyId);
    }

    die(killer) {
        // Remove all shields when generator dies
        if (this.special?.shieldsDisableOnDeath) {
            for (const enemyId of this.shieldedEnemies) {
                this.emit('shieldRemoved', {
                    generator: this,
                    targetId: enemyId,
                });
            }
            this.shieldedEnemies.clear();
        }

        super.die(killer);
    }

    getRenderData() {
        const data = super.getRenderData();
        data.shieldRadius = this.getShieldRadius();
        data.shieldedCount = this.shieldedEnemies.size;
        data.shieldedEnemyIds = [...this.shieldedEnemies];
        data.isShieldGenerator = true;
        data.shieldEffect = this.special?.shieldEffect || 'rangedImmunity';
        return data;
    }
}

/**
 * Storm Creature - Self-destruct on contact
 */
class StormCreatureEnemy extends Enemy {
    constructor(x, y, difficulty) {
        super('stormCreature', x, y, difficulty);
        this.isExploding = false;
    }

    checkTrigger(targets) {
        if (this.isExploding) return false;

        const triggerRange = this.special?.triggerRange || 30;

        for (const target of targets) {
            const distance = this.distanceTo(target);
            if (distance <= triggerRange) {
                this.explode();
                return true;
            }
        }

        return false;
    }

    explode() {
        if (this.isExploding) return;

        this.isExploding = true;
        this.state = EnemyState.USING_ABILITY;

        const explosionRadius = (this.special?.explosionRadius || 2) * 40;

        // Emit warning before explosion
        this.emit('specialActionWarning', {
            enemy: this,
            actionType: 'explosion',
            warningDuration: 300, // Brief warning
            targetPosition: { x: this.x, y: this.y },
            dangerRadius: explosionRadius,
        });

        this.emit('selfDestruct', {
            enemy: this,
            position: { x: this.x, y: this.y },
            radius: explosionRadius,
            damage: this.special?.explosionDamage || this.damage,
        });

        // Die after explosion
        this.die(null);
    }
}

/**
 * Heavy Trooper - Has grenade attack
 */
class HeavyTrooperEnemy extends Enemy {
    constructor(x, y, difficulty) {
        super('heavyTrooper', x, y, difficulty);
    }

    canThrowGrenade() {
        return this.specialCooldown <= 0 && this.special?.type === 'grenadeThrow';
    }

    throwGrenade(targetX, targetY) {
        if (!this.canThrowGrenade()) return false;

        const range = (this.special?.grenadeRange || 3) * 40;
        const distance = Utils.distance(this.x, this.y, targetX, targetY);

        if (distance > range) return false;

        this.specialCooldown = this.special.grenadeCooldown;
        this.state = EnemyState.USING_ABILITY;

        this.emit('grenadeThrow', {
            enemy: this,
            target: { x: targetX, y: targetY },
            damage: this.special.grenadeDamage,
            radius: (this.special.grenadeRadius || 1.5) * 40,
        });

        return true;
    }
}

/**
 * Brute - Heavy melee with cleave and knockback
 */
class BruteEnemy extends Enemy {
    constructor(x, y, difficulty) {
        super('brute', x, y, difficulty);
    }

    attack(target) {
        if (!target || this.attackCooldown > 0) return false;

        this.state = EnemyState.ATTACKING;
        this.target = target;
        this.attackCooldown = this.attackSpeed;

        // Face target
        this.angle = Utils.angleBetween(this.x, this.y, target.x, target.y);

        // Emit cleave attack event
        this.emit('cleaveAttack', {
            enemy: this,
            target: target,
            damage: this.damage,
            cleaveAngle: Utils.degToRad(this.special?.cleaveAngle || 120),
            knockback: this.special?.knockbackForce || 3,
            oneHitKill: this.special?.oneHitKill || false,
        });

        return true;
    }
}

/**
 * Boss - Pirate Captain
 */
class PirateCaptainEnemy extends Enemy {
    constructor(x, y, difficulty) {
        super('pirateCaptain', x, y, difficulty);
        this.abilities = this.data.behavior.special?.abilities || [];
        this.abilityCooldowns = {};

        // Initialize cooldowns
        for (const ability of this.abilities) {
            this.abilityCooldowns[ability.id] = 0;
        }
    }

    updateAbilityCooldowns(deltaTime) {
        for (const abilityId in this.abilityCooldowns) {
            this.abilityCooldowns[abilityId] = Math.max(0,
                this.abilityCooldowns[abilityId] - deltaTime
            );
        }
    }

    canUseAbility(abilityId) {
        return this.abilityCooldowns[abilityId] <= 0;
    }

    useAbility(abilityId, context) {
        const ability = this.abilities.find(a => a.id === abilityId);
        if (!ability || !this.canUseAbility(abilityId)) return false;

        this.abilityCooldowns[abilityId] = ability.cooldown || 10000;

        this.emit('bossAbility', {
            enemy: this,
            ability: ability,
            context: context,
        });

        return true;
    }

    update(deltaTime, gameContext) {
        super.update(deltaTime, gameContext);
        this.updateAbilityCooldowns(deltaTime);
    }
}

/**
 * Boss - Storm Core (stationary, invulnerable)
 */
class StormCoreEnemy extends Enemy {
    constructor(x, y, difficulty) {
        super('stormCore', x, y, difficulty);
        this.pulseTimer = 0;
        this.spawnTimer = 0;
    }

    update(deltaTime, gameContext) {
        super.update(deltaTime, gameContext);

        // Energy pulse
        this.pulseTimer += deltaTime;
        const pulseInterval = this.data.behavior.special?.abilities?.[0]?.interval || 10000;

        if (this.pulseTimer >= pulseInterval) {
            this.pulseTimer = 0;
            this.emit('energyPulse', {
                enemy: this,
                damage: this.data.behavior.special?.abilities?.[0]?.damage || 10,
            });
        }

        // Spawn storm creatures
        this.spawnTimer += deltaTime;
        const spawnInterval = this.data.behavior.special?.abilities?.[1]?.interval || 15000;

        if (this.spawnTimer >= spawnInterval) {
            this.spawnTimer = 0;
            this.emit('spawnStormCreatures', {
                enemy: this,
                count: this.data.behavior.special?.abilities?.[1]?.count || 3,
            });
        }
    }

    // Override - Storm Core cannot move
    moveTowards() {
        return true; // Always "arrived"
    }

    // Override - Storm Core cannot be damaged
    takeDamage() {
        return 0;
    }
}

// ==========================================
// Enemy Factory
// ==========================================

const EnemyFactory = {
    /**
     * Create enemy instance by ID
     */
    create(enemyId, x, y, difficulty = 'normal') {
        switch (enemyId) {
            case 'jumper':
                return new JumperEnemy(x, y, difficulty);
            case 'hacker':
                return new HackerEnemy(x, y, difficulty);
            case 'sniper':
                return new SniperEnemy(x, y, difficulty);
            case 'droneCarrier':
                return new DroneCarrierEnemy(x, y, difficulty);
            case 'shieldGenerator':
                return new ShieldGeneratorEnemy(x, y, difficulty);
            case 'stormCreature':
                return new StormCreatureEnemy(x, y, difficulty);
            case 'heavyTrooper':
                return new HeavyTrooperEnemy(x, y, difficulty);
            case 'brute':
                return new BruteEnemy(x, y, difficulty);
            case 'pirateCaptain':
                return new PirateCaptainEnemy(x, y, difficulty);
            case 'stormCore':
                return new StormCoreEnemy(x, y, difficulty);
            default:
                return new Enemy(enemyId, x, y, difficulty);
        }
    },

    /**
     * Create multiple enemies
     */
    createBatch(enemyId, positions, difficulty = 'normal') {
        return positions.map(pos => this.create(enemyId, pos.x, pos.y, difficulty));
    },
};

// Make available globally
window.EnemyState = EnemyState;
window.Enemy = Enemy;
window.JumperEnemy = JumperEnemy;
window.HackerEnemy = HackerEnemy;
window.SniperEnemy = SniperEnemy;
window.DroneCarrierEnemy = DroneCarrierEnemy;
window.ShieldGeneratorEnemy = ShieldGeneratorEnemy;
window.StormCreatureEnemy = StormCreatureEnemy;
window.HeavyTrooperEnemy = HeavyTrooperEnemy;
window.BruteEnemy = BruteEnemy;
window.PirateCaptainEnemy = PirateCaptainEnemy;
window.StormCoreEnemy = StormCoreEnemy;
window.EnemyFactory = EnemyFactory;
