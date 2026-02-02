/**
 * THE FADING RAVEN - Raven Drone System
 * The mothership's support drone with 4 abilities
 */

const RavenSystem = {
    // Ability definitions
    abilities: {
        scout: {
            id: 'scout',
            name: '정찰',
            nameEn: 'Scout',
            description: '지정 영역의 시야를 밝히고 적 위치를 표시합니다.',
            icon: '👁️',
            maxUses: 3,
            cooldown: 15000, // 15 seconds
            duration: 10000, // 10 seconds
            radius: 5, // tiles
        },
        flare: {
            id: 'flare',
            name: '조명탄',
            nameEn: 'Flare',
            description: '넓은 영역을 밝혀 적의 은신을 해제합니다.',
            icon: '🔥',
            maxUses: 2,
            cooldown: 20000,
            duration: 15000,
            radius: 8,
            removesStealth: true,
        },
        resupply: {
            id: 'resupply',
            name: '보급',
            nameEn: 'Resupply',
            description: '아군의 체력을 회복하고 장비 충전을 보충합니다.',
            icon: '📦',
            maxUses: 2,
            cooldown: 30000,
            healAmount: 3, // squad members
            chargeRefill: 1, // equipment charges
            radius: 3,
        },
        orbitalStrike: {
            id: 'orbitalStrike',
            name: '궤도 폭격',
            nameEn: 'Orbital Strike',
            description: '강력한 궤도 폭격으로 지정 영역을 초토화합니다.',
            icon: '💥',
            maxUses: 1,
            cooldown: 60000,
            chargeTime: 3000, // 3 second warning
            damage: 100,
            radius: 3,
            destroysCover: true,
        },
    },

    // Current state
    state: {
        uses: {}, // remaining uses per ability
        cooldowns: {}, // current cooldowns
        activeEffects: [], // currently active ability effects
        position: { x: 0, y: 0 }, // Raven drone position
        visible: false,
    },

    /**
     * Initialize Raven for a battle
     */
    init(difficulty = 'normal') {
        // Reset uses based on difficulty
        const useMult = {
            normal: 1,
            hard: 1,
            veryhard: 0.5,
            nightmare: 0.5,
        };

        const mult = useMult[difficulty] || 1;

        this.state.uses = {};
        this.state.cooldowns = {};
        this.state.activeEffects = [];

        for (const [id, ability] of Object.entries(this.abilities)) {
            this.state.uses[id] = Math.ceil(ability.maxUses * mult);
            this.state.cooldowns[id] = 0;
        }

        return this;
    },

    /**
     * Check if ability can be used
     */
    canUse(abilityId) {
        const ability = this.abilities[abilityId];
        if (!ability) return false;

        // Check uses
        if (this.state.uses[abilityId] <= 0) return false;

        // Check cooldown
        if (this.state.cooldowns[abilityId] > 0) return false;

        return true;
    },

    /**
     * Get ability info for UI
     */
    getAbilityInfo(abilityId) {
        const ability = this.abilities[abilityId];
        if (!ability) return null;

        return {
            ...ability,
            usesRemaining: this.state.uses[abilityId],
            cooldown: this.state.cooldowns[abilityId],
            cooldownPercent: this.state.cooldowns[abilityId] / ability.cooldown,
            ready: this.canUse(abilityId),
        };
    },

    /**
     * Get all abilities info
     */
    getAllAbilities() {
        return Object.keys(this.abilities).map(id => this.getAbilityInfo(id));
    },

    /**
     * Use an ability
     */
    useAbility(abilityId, target, battle) {
        if (!this.canUse(abilityId)) {
            return { success: false, reason: 'not_ready' };
        }

        let result;

        switch (abilityId) {
            case 'scout':
                result = this._useScout(target, battle);
                break;
            case 'flare':
                result = this._useFlare(target, battle);
                break;
            case 'resupply':
                result = this._useResupply(target, battle);
                break;
            case 'orbitalStrike':
                result = this._useOrbitalStrike(target, battle);
                break;
            default:
                result = { success: false, reason: 'invalid_ability' };
        }

        if (result.success) {
            this.state.uses[abilityId]--;
            this.state.cooldowns[abilityId] = this.abilities[abilityId].cooldown;
        }

        return result;
    },

    // ==========================================
    // ABILITY IMPLEMENTATIONS
    // ==========================================

    /**
     * Scout - Reveal area and mark enemies
     */
    _useScout(target, battle) {
        const ability = this.abilities.scout;
        const radius = ability.radius * battle.tileSize;

        // Create vision effect
        const effect = {
            id: Utils.generateId(),
            type: 'scout',
            x: target.x,
            y: target.y,
            radius: radius,
            duration: ability.duration,
            timer: 0,
        };

        this.state.activeEffects.push(effect);

        // Mark enemies in area
        for (const enemy of battle.enemies) {
            if (Utils.distance(target.x, target.y, enemy.x, enemy.y) <= radius) {
                enemy.marked = true;
                enemy.markTimer = ability.duration;
            }
        }

        // Visual effect
        battle.addEffect({
            type: 'scan_pulse',
            x: target.x,
            y: target.y,
            radius: radius,
            duration: 500,
            timer: 0,
            color: '#4a9eff',
        });

        // Move Raven to position
        this._moveRavenTo(target.x, target.y - 100, battle);

        return { success: true };
    },

    /**
     * Flare - Light up area and remove stealth
     */
    _useFlare(target, battle) {
        const ability = this.abilities.flare;
        const radius = ability.radius * battle.tileSize;

        // Create illumination effect
        const effect = {
            id: Utils.generateId(),
            type: 'flare',
            x: target.x,
            y: target.y,
            radius: radius,
            duration: ability.duration,
            timer: 0,
        };

        this.state.activeEffects.push(effect);

        // Remove stealth from enemies
        for (const enemy of battle.enemies) {
            if (Utils.distance(target.x, target.y, enemy.x, enemy.y) <= radius) {
                if (enemy.stealthed) {
                    enemy.stealthed = false;
                    enemy.stealthBroken = true;
                }
                enemy.illuminated = true;
                enemy.illuminatedTimer = ability.duration;
            }
        }

        // Flare visual
        battle.addEffect({
            type: 'flare_drop',
            x: target.x,
            y: target.y,
            radius: radius,
            duration: ability.duration,
            timer: 0,
            color: '#f6ad55',
        });

        return { success: true };
    },

    /**
     * Resupply - Heal and refill charges
     */
    _useResupply(target, battle) {
        const ability = this.abilities.resupply;
        const radius = ability.radius * battle.tileSize;

        const affectedCrews = [];

        // Find crews in radius
        for (const crew of battle.crews) {
            if (Utils.distance(target.x, target.y, crew.x, crew.y) <= radius) {
                // Heal
                const oldSize = crew.squadSize;
                crew.squadSize = Math.min(crew.maxSquadSize, crew.squadSize + ability.healAmount);
                const healed = crew.squadSize - oldSize;

                // Refill equipment charges
                if (EquipmentEffects) {
                    const state = EquipmentEffects.getState(crew.id);
                    if (state && state.charges < state.maxCharges) {
                        state.charges = Math.min(state.maxCharges, state.charges + ability.chargeRefill);
                    }
                }

                affectedCrews.push({ crew, healed });

                battle.addEffect({
                    type: 'heal',
                    x: crew.x,
                    y: crew.y,
                    amount: healed,
                    duration: 500,
                    timer: 0,
                    color: '#48bb78',
                });
            }
        }

        // Supply drop visual
        battle.addEffect({
            type: 'supply_drop',
            x: target.x,
            y: target.y,
            radius: radius,
            duration: 1000,
            timer: 0,
            color: '#48bb78',
        });

        // Move Raven
        this._moveRavenTo(target.x, target.y - 80, battle);

        return { success: true, affectedCrews };
    },

    /**
     * Orbital Strike - Massive damage after delay
     */
    _useOrbitalStrike(target, battle) {
        const ability = this.abilities.orbitalStrike;
        const radius = ability.radius * battle.tileSize;

        // Show warning indicator
        battle.addEffect({
            type: 'orbital_warning',
            x: target.x,
            y: target.y,
            radius: radius,
            duration: ability.chargeTime,
            timer: 0,
            color: '#fc8181',
        });

        // Delayed strike
        setTimeout(() => {
            // Damage all enemies in radius
            for (const enemy of battle.enemies) {
                if (Utils.distance(target.x, target.y, enemy.x, enemy.y) <= radius) {
                    enemy.health -= ability.damage;
                    battle.addDamageNumber(enemy.x, enemy.y, ability.damage);
                }
            }

            // Damage turrets (both friendly and hostile)
            if (battle.turrets) {
                for (const turret of battle.turrets) {
                    if (Utils.distance(target.x, target.y, turret.x, turret.y) <= radius) {
                        TurretSystem.damage(turret.id, ability.damage, battle);
                    }
                }
            }

            // Destroy cover tiles
            if (ability.destroysCover && battle.tileGrid) {
                const centerTile = battle.tileGrid.pixelToTile(target.x, target.y, battle.offsetX, battle.offsetY);
                const tiles = battle.tileGrid.getTilesInRange(centerTile.x, centerTile.y, ability.radius, { includeCenter: true });

                for (const tile of tiles) {
                    if (tile.type === 'cover') {
                        battle.tileGrid.setTile(tile.x, tile.y, 'floor');
                    }
                }
            }

            // Massive explosion effect
            battle.addEffect({
                type: 'orbital_explosion',
                x: target.x,
                y: target.y,
                radius: radius,
                duration: 1000,
                timer: 0,
                color: '#fc8181',
            });

            // Screen shake
            if (battle.screenShake) {
                battle.screenShake(20, 500);
            }
        }, ability.chargeTime);

        return { success: true };
    },

    // ==========================================
    // RAVEN DRONE MOVEMENT
    // ==========================================

    /**
     * Move Raven drone to position
     */
    _moveRavenTo(x, y, battle) {
        this.state.visible = true;
        this.state.targetPosition = { x, y };

        // Animate in if not visible
        if (!this.state.position.x) {
            this.state.position = {
                x: battle.canvas.width / 2,
                y: -50,
            };
        }
    },

    /**
     * Update Raven position
     */
    _updatePosition(dt) {
        if (!this.state.visible || !this.state.targetPosition) return;

        const speed = 200; // pixels per second
        const target = this.state.targetPosition;
        const pos = this.state.position;

        const dist = Utils.distance(pos.x, pos.y, target.x, target.y);

        if (dist > 5) {
            const angle = Utils.angleBetween(pos.x, pos.y, target.x, target.y);
            const moveAmount = speed * (dt / 1000);
            pos.x += Math.cos(angle) * moveAmount;
            pos.y += Math.sin(angle) * moveAmount;
        }
    },

    // ==========================================
    // UPDATE LOOP
    // ==========================================

    /**
     * Update Raven system
     */
    update(dt, battle) {
        // Update cooldowns
        for (const id of Object.keys(this.state.cooldowns)) {
            if (this.state.cooldowns[id] > 0) {
                this.state.cooldowns[id] -= dt;
            }
        }

        // Update active effects
        for (let i = this.state.activeEffects.length - 1; i >= 0; i--) {
            const effect = this.state.activeEffects[i];
            effect.timer += dt;

            if (effect.timer >= effect.duration) {
                this._onEffectEnd(effect, battle);
                this.state.activeEffects.splice(i, 1);
            }
        }

        // Update enemy marks
        for (const enemy of battle.enemies) {
            if (enemy.marked && enemy.markTimer > 0) {
                enemy.markTimer -= dt;
                if (enemy.markTimer <= 0) {
                    enemy.marked = false;
                }
            }
            if (enemy.illuminated && enemy.illuminatedTimer > 0) {
                enemy.illuminatedTimer -= dt;
                if (enemy.illuminatedTimer <= 0) {
                    enemy.illuminated = false;
                }
            }
        }

        // Update Raven position
        this._updatePosition(dt);
    },

    /**
     * Handle effect ending
     */
    _onEffectEnd(effect, battle) {
        switch (effect.type) {
            case 'scout':
                // Vision effect ends
                break;
            case 'flare':
                // Illumination ends
                break;
        }
    },

    // ==========================================
    // RENDERING
    // ==========================================

    /**
     * Render Raven drone and effects
     */
    render(ctx, battle) {
        // Render active area effects
        for (const effect of this.state.activeEffects) {
            this._renderEffect(ctx, effect);
        }

        // Render Raven drone
        if (this.state.visible) {
            this._renderRaven(ctx);
        }
    },

    /**
     * Render active effect
     */
    _renderEffect(ctx, effect) {
        const progress = effect.timer / effect.duration;

        ctx.save();

        switch (effect.type) {
            case 'scout':
                // Circular vision area
                ctx.strokeStyle = 'rgba(74, 158, 255, 0.5)';
                ctx.lineWidth = 2;
                ctx.setLineDash([5, 5]);
                ctx.beginPath();
                ctx.arc(effect.x, effect.y, effect.radius, 0, Math.PI * 2);
                ctx.stroke();
                ctx.setLineDash([]);

                // Pulsing inner circle
                ctx.fillStyle = `rgba(74, 158, 255, ${0.1 * (1 - progress)})`;
                ctx.beginPath();
                ctx.arc(effect.x, effect.y, effect.radius * (0.5 + Math.sin(effect.timer / 200) * 0.2), 0, Math.PI * 2);
                ctx.fill();
                break;

            case 'flare':
                // Bright illuminated area
                const gradient = ctx.createRadialGradient(
                    effect.x, effect.y, 0,
                    effect.x, effect.y, effect.radius
                );
                gradient.addColorStop(0, `rgba(246, 173, 85, ${0.3 * (1 - progress * 0.5)})`);
                gradient.addColorStop(1, 'rgba(246, 173, 85, 0)');
                ctx.fillStyle = gradient;
                ctx.beginPath();
                ctx.arc(effect.x, effect.y, effect.radius, 0, Math.PI * 2);
                ctx.fill();
                break;
        }

        ctx.restore();
    },

    /**
     * Render Raven drone
     */
    _renderRaven(ctx) {
        const pos = this.state.position;
        if (!pos.x && !pos.y) return;

        ctx.save();
        ctx.translate(pos.x, pos.y);

        // Drone body
        ctx.fillStyle = '#2d3748';
        ctx.beginPath();
        ctx.moveTo(0, -15);
        ctx.lineTo(20, 10);
        ctx.lineTo(0, 5);
        ctx.lineTo(-20, 10);
        ctx.closePath();
        ctx.fill();

        // Cockpit
        ctx.fillStyle = '#4a9eff';
        ctx.beginPath();
        ctx.ellipse(0, -5, 8, 5, 0, 0, Math.PI * 2);
        ctx.fill();

        // Engines
        ctx.fillStyle = '#63b3ed';
        ctx.beginPath();
        ctx.arc(-15, 8, 4, 0, Math.PI * 2);
        ctx.arc(15, 8, 4, 0, Math.PI * 2);
        ctx.fill();

        // Engine glow
        ctx.fillStyle = 'rgba(99, 179, 237, 0.5)';
        ctx.beginPath();
        ctx.arc(-15, 12, 6, 0, Math.PI * 2);
        ctx.arc(15, 12, 6, 0, Math.PI * 2);
        ctx.fill();

        ctx.restore();
    },

    // ==========================================
    // UTILITY
    // ==========================================

    /**
     * Check if position is within any active scout/flare area
     */
    isPositionRevealed(x, y) {
        for (const effect of this.state.activeEffects) {
            if (effect.type === 'scout' || effect.type === 'flare') {
                if (Utils.distance(x, y, effect.x, effect.y) <= effect.radius) {
                    return true;
                }
            }
        }
        return false;
    },

    /**
     * Get visibility bonus at position (for accuracy)
     */
    getVisibilityBonus(x, y) {
        for (const effect of this.state.activeEffects) {
            if (effect.type === 'flare') {
                if (Utils.distance(x, y, effect.x, effect.y) <= effect.radius) {
                    return 0.2; // 20% accuracy bonus
                }
            }
            if (effect.type === 'scout') {
                if (Utils.distance(x, y, effect.x, effect.y) <= effect.radius) {
                    return 0.1; // 10% accuracy bonus
                }
            }
        }
        return 0;
    },

    /**
     * Reset for new battle
     */
    reset(difficulty) {
        this.init(difficulty);
    },

    /**
     * Get remaining uses for ability
     */
    getRemainingUses(abilityId) {
        return this.state.uses[abilityId] || 0;
    },

    /**
     * Get current cooldown for ability
     */
    getCooldown(abilityId) {
        return this.state.cooldowns[abilityId] || 0;
    },
};

// Make available globally
window.RavenSystem = RavenSystem;
