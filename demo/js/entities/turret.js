/**
 * THE FADING RAVEN - Turret System
 * Handles auto-targeting turrets with hacking capability
 */

const TurretSystem = {
    // All active turrets
    turrets: [],

    // Turret visual constants
    TURRET_SIZE: 20,
    TURRET_COLOR_FRIENDLY: '#68d391',
    TURRET_COLOR_HACKED: '#fc8181',
    TURRET_COLOR_NEUTRAL: '#a0aec0',

    /**
     * Create a new turret
     */
    create(options) {
        const turret = {
            id: options.id || Utils.generateId(),
            ownerId: options.ownerId || null,
            x: options.x,
            y: options.y,

            // Stats
            health: options.health || 50,
            maxHealth: options.maxHealth || options.health || 50,
            damage: options.damage || 8,
            range: options.range || 150,
            attackSpeed: options.attackSpeed || 1000,

            // State
            attackTimer: 0,
            targetId: null,
            rotation: 0,
            isHacked: false,
            hackProgress: 0,
            beingHacked: false,
            hackedBy: null,

            // Modifiers
            slow: options.slow || false,
            slowAmount: options.slowAmount || 0.5,
            slowDuration: options.slowDuration || 1000,

            // Visual
            color: options.color || this.TURRET_COLOR_FRIENDLY,
            size: options.size || this.TURRET_SIZE,
        };

        this.turrets.push(turret);
        return turret;
    },

    /**
     * Remove a turret
     */
    remove(turretId) {
        this.turrets = this.turrets.filter(t => t.id !== turretId);
    },

    /**
     * Get turret by ID
     */
    get(turretId) {
        return this.turrets.find(t => t.id === turretId);
    },

    /**
     * Get turrets by owner
     */
    getByOwner(ownerId) {
        return this.turrets.filter(t => t.ownerId === ownerId);
    },

    /**
     * Update all turrets
     */
    update(dt, battle) {
        for (const turret of this.turrets) {
            this._updateTurret(turret, dt, battle);
        }

        // Remove destroyed turrets
        this.turrets = this.turrets.filter(t => t.health > 0);
    },

    /**
     * Update single turret
     */
    _updateTurret(turret, dt, battle) {
        // Skip if being hacked
        if (turret.beingHacked) {
            return;
        }

        // Reduce attack timer
        turret.attackTimer -= dt;

        // Find and attack targets
        const targets = turret.isHacked ? battle.crews : battle.enemies;
        const target = this._findBestTarget(turret, targets);

        if (target) {
            turret.targetId = target.id;

            // Rotate towards target
            const targetAngle = Utils.angleBetween(turret.x, turret.y, target.x, target.y);
            turret.rotation = this._smoothRotation(turret.rotation, targetAngle, dt);

            // Attack if ready and facing target
            const angleDiff = Math.abs(turret.rotation - targetAngle);
            if (turret.attackTimer <= 0 && angleDiff < 0.2) {
                this._attack(turret, target, battle);
                turret.attackTimer = turret.attackSpeed;
            }
        } else {
            turret.targetId = null;
        }
    },

    /**
     * Find best target for turret
     */
    _findBestTarget(turret, targets) {
        if (!targets || targets.length === 0) return null;

        let bestTarget = null;
        let bestScore = -Infinity;

        for (const target of targets) {
            // Skip dead targets
            if (turret.isHacked) {
                if (target.squadSize <= 0) continue;
            } else {
                if (target.health <= 0) continue;
            }

            const dist = Utils.distance(turret.x, turret.y, target.x, target.y);

            // Check range
            if (dist > turret.range) continue;

            // Score based on distance (closer = higher priority)
            let score = turret.range - dist;

            // Prioritize current target for consistency
            if (target.id === turret.targetId) {
                score += 50;
            }

            // Prioritize low health targets
            const healthPercent = turret.isHacked
                ? target.squadSize / target.maxSquadSize
                : target.health / target.maxHealth;
            score += (1 - healthPercent) * 30;

            if (score > bestScore) {
                bestScore = score;
                bestTarget = target;
            }
        }

        return bestTarget;
    },

    /**
     * Smooth rotation towards target
     */
    _smoothRotation(current, target, dt) {
        const rotSpeed = 5; // radians per second
        let diff = target - current;

        // Normalize to -PI to PI
        while (diff > Math.PI) diff -= Math.PI * 2;
        while (diff < -Math.PI) diff += Math.PI * 2;

        const maxRotation = rotSpeed * (dt / 1000);
        if (Math.abs(diff) < maxRotation) {
            return target;
        }

        return current + Math.sign(diff) * maxRotation;
    },

    /**
     * Execute turret attack
     */
    _attack(turret, target, battle) {
        // Create projectile
        battle.projectiles.push({
            x: turret.x,
            y: turret.y,
            angle: turret.rotation,
            speed: 400,
            damage: turret.damage,
            target: target,
            color: turret.isHacked ? this.TURRET_COLOR_HACKED : turret.color,
            isTurretShot: true,
            applySlows: turret.slow,
            slowAmount: turret.slowAmount,
            slowDuration: turret.slowDuration,
        });

        // Muzzle flash effect
        battle.addEffect({
            type: 'muzzle_flash',
            x: turret.x + Math.cos(turret.rotation) * turret.size,
            y: turret.y + Math.sin(turret.rotation) * turret.size,
            duration: 100,
            timer: 0,
            color: turret.isHacked ? this.TURRET_COLOR_HACKED : turret.color,
        });
    },

    // ==========================================
    // HACKING SYSTEM
    // ==========================================

    /**
     * Start hacking a turret
     */
    startHack(turretId, hackerId, hackTime) {
        const turret = this.get(turretId);
        if (!turret || turret.isHacked) return false;

        turret.beingHacked = true;
        turret.hackedBy = hackerId;
        turret.hackProgress = 0;
        turret.hackTime = hackTime;

        return true;
    },

    /**
     * Update hack progress
     */
    updateHack(turretId, dt) {
        const turret = this.get(turretId);
        if (!turret || !turret.beingHacked) return null;

        turret.hackProgress += dt;

        if (turret.hackProgress >= turret.hackTime) {
            // Hack complete
            turret.beingHacked = false;
            turret.isHacked = true;
            turret.color = this.TURRET_COLOR_HACKED;
            return { complete: true, turret: turret };
        }

        return { complete: false, progress: turret.hackProgress / turret.hackTime };
    },

    /**
     * Cancel hack in progress
     */
    cancelHack(turretId) {
        const turret = this.get(turretId);
        if (!turret) return;

        turret.beingHacked = false;
        turret.hackedBy = null;
        turret.hackProgress = 0;
    },

    /**
     * Check if turret can be hacked
     */
    canBeHacked(turretId) {
        const turret = this.get(turretId);
        return turret && !turret.isHacked && !turret.beingHacked;
    },

    /**
     * Get hackable turrets in range
     */
    getHackableInRange(x, y, range) {
        return this.turrets.filter(t => {
            if (t.isHacked || t.beingHacked) return false;
            return Utils.distance(x, y, t.x, t.y) <= range;
        });
    },

    // ==========================================
    // DAMAGE & DESTRUCTION
    // ==========================================

    /**
     * Damage a turret
     */
    damage(turretId, amount, battle) {
        const turret = this.get(turretId);
        if (!turret) return;

        turret.health -= amount;

        battle?.addDamageNumber(turret.x, turret.y, amount);

        if (turret.health <= 0) {
            this._onDestroyed(turret, battle);
        }
    },

    /**
     * Handle turret destruction
     */
    _onDestroyed(turret, battle) {
        battle?.addEffect({
            type: 'explosion',
            x: turret.x,
            y: turret.y,
            radius: 30,
            duration: 400,
            timer: 0,
            color: turret.color,
        });

        // Remove from list
        this.remove(turret.id);
    },

    // ==========================================
    // RENDERING
    // ==========================================

    /**
     * Render all turrets
     */
    render(ctx, battle) {
        for (const turret of this.turrets) {
            this._renderTurret(ctx, turret, battle);
        }
    },

    /**
     * Render single turret
     */
    _renderTurret(ctx, turret, battle) {
        const x = turret.x;
        const y = turret.y;
        const size = turret.size;

        // Base
        ctx.fillStyle = '#2d2d44';
        ctx.beginPath();
        ctx.arc(x, y, size, 0, Math.PI * 2);
        ctx.fill();

        // Turret body
        ctx.fillStyle = turret.color;
        ctx.beginPath();
        ctx.arc(x, y, size * 0.7, 0, Math.PI * 2);
        ctx.fill();

        // Gun barrel
        ctx.strokeStyle = turret.color;
        ctx.lineWidth = 4;
        ctx.beginPath();
        ctx.moveTo(x, y);
        ctx.lineTo(
            x + Math.cos(turret.rotation) * size * 1.2,
            y + Math.sin(turret.rotation) * size * 1.2
        );
        ctx.stroke();

        // Health bar
        if (turret.health < turret.maxHealth) {
            const healthPct = turret.health / turret.maxHealth;
            const barWidth = size * 2;
            const barHeight = 4;
            const barX = x - barWidth / 2;
            const barY = y - size - 10;

            ctx.fillStyle = '#333';
            ctx.fillRect(barX, barY, barWidth, barHeight);
            ctx.fillStyle = healthPct > 0.5 ? '#48bb78' : healthPct > 0.25 ? '#f6ad55' : '#fc8181';
            ctx.fillRect(barX, barY, barWidth * healthPct, barHeight);
        }

        // Hack progress indicator
        if (turret.beingHacked) {
            const progress = turret.hackProgress / turret.hackTime;
            ctx.strokeStyle = '#68d391';
            ctx.lineWidth = 3;
            ctx.beginPath();
            ctx.arc(x, y, size + 5, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * progress);
            ctx.stroke();
        }

        // Hacked indicator
        if (turret.isHacked) {
            ctx.fillStyle = '#fc8181';
            ctx.font = 'bold 12px sans-serif';
            ctx.textAlign = 'center';
            ctx.fillText('HACKED', x, y - size - 15);
        }

        // Range indicator (when selected or debugging)
        if (turret.showRange) {
            ctx.strokeStyle = 'rgba(104, 211, 145, 0.3)';
            ctx.lineWidth = 1;
            ctx.setLineDash([5, 5]);
            ctx.beginPath();
            ctx.arc(x, y, turret.range, 0, Math.PI * 2);
            ctx.stroke();
            ctx.setLineDash([]);
        }
    },

    // ==========================================
    // UTILITY
    // ==========================================

    /**
     * Get all turrets
     */
    getAll() {
        return this.turrets;
    },

    /**
     * Get friendly turrets
     */
    getFriendly() {
        return this.turrets.filter(t => !t.isHacked);
    },

    /**
     * Get hacked (hostile) turrets
     */
    getHostile() {
        return this.turrets.filter(t => t.isHacked);
    },

    /**
     * Clear all turrets
     */
    clear() {
        this.turrets = [];
    },

    /**
     * Import turrets from battle data
     */
    import(turretData) {
        if (!turretData) return;

        for (const data of turretData) {
            this.create(data);
        }
    },

    /**
     * Export turrets for saving
     */
    export() {
        return this.turrets.map(t => ({
            id: t.id,
            ownerId: t.ownerId,
            x: t.x,
            y: t.y,
            health: t.health,
            maxHealth: t.maxHealth,
            damage: t.damage,
            range: t.range,
            attackSpeed: t.attackSpeed,
            isHacked: t.isHacked,
            slow: t.slow,
            slowAmount: t.slowAmount,
            slowDuration: t.slowDuration,
        }));
    },
};

// Make available globally
window.TurretSystem = TurretSystem;
