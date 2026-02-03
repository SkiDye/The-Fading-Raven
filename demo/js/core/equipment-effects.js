/**
 * THE FADING RAVEN - Equipment Effects System
 * Handles passive effects, active equipment usage, and consumables
 */

const EquipmentEffects = {
    // Track active equipment states per crew
    activeStates: new Map(),

    // Track consumable charges per battle
    chargesUsed: new Map(),

    // ==========================================
    // INITIALIZATION
    // ==========================================

    /**
     * Initialize equipment for a crew
     */
    initCrew(crew, battle) {
        if (!crew.equipment) return;

        const equipmentId = crew.equipment.id || crew.equipment;
        const level = crew.equipment.level || 1;
        const equipment = EquipmentData.get(equipmentId);

        if (!equipment) return;

        const state = {
            equipmentId: equipmentId,
            level: level,
            type: equipment.type,
            cooldown: 0,
            maxCooldown: equipment.cooldown || 0,
            charges: this._getMaxCharges(equipmentId, level),
            maxCharges: this._getMaxCharges(equipmentId, level),
            active: false,
            activeTimer: 0,
        };

        this.activeStates.set(crew.id, state);

        // Apply passive effects immediately
        if (equipment.type === 'passive') {
            this.applyPassiveEffects(crew, state);
        }

        return state;
    },

    /**
     * Get max charges for equipment
     */
    _getMaxCharges(equipmentId, level) {
        const effect = EquipmentData.getEffect(equipmentId, level);
        return effect?.charges || 0;
    },

    /**
     * Reset for new battle
     */
    resetForBattle() {
        this.chargesUsed.clear();
        for (const [crewId, state] of this.activeStates) {
            state.cooldown = 0;
            state.charges = state.maxCharges;
            state.active = false;
            state.activeTimer = 0;
        }
    },

    // ==========================================
    // PASSIVE EFFECTS
    // ==========================================

    /**
     * Apply passive equipment effects to crew
     */
    applyPassiveEffects(crew, state) {
        const effect = EquipmentData.getEffect(state.equipmentId, state.level);
        if (!effect) return;

        switch (state.equipmentId) {
            case 'commandModule':
                // Increase squad size
                crew.maxSquadSize += effect.squadSizeBonus;
                crew.squadSize = Math.min(crew.squadSize + effect.squadSizeBonus, crew.maxSquadSize);
                break;

            case 'stimPack':
                // Increase attack and move speed
                crew.attackSpeed = Math.floor(crew.attackSpeed / effect.attackSpeedMultiplier);
                crew.moveSpeed *= effect.moveSpeedMultiplier;
                break;

            case 'salvageCore':
                // Handled at battle end
                break;
        }
    },

    /**
     * Get passive stat modifiers
     */
    getStatModifiers(crewId) {
        const state = this.activeStates.get(crewId);
        if (!state) return {};

        const effect = EquipmentData.getEffect(state.equipmentId, state.level);
        if (!effect) return {};

        const modifiers = {};

        switch (state.equipmentId) {
            case 'commandModule':
                modifiers.squadSizeBonus = effect.squadSizeBonus;
                modifiers.recoveryTimeMultiplier = effect.recoveryTimeMultiplier;
                break;

            case 'stimPack':
                modifiers.attackSpeedMultiplier = effect.attackSpeedMultiplier;
                modifiers.moveSpeedMultiplier = effect.moveSpeedMultiplier;
                if (effect.extraAction) modifiers.extraAction = true;
                break;

            case 'salvageCore':
                modifiers.bonusCredits = effect.bonusCredits;
                break;
        }

        return modifiers;
    },

    // ==========================================
    // ACTIVE EQUIPMENT
    // ==========================================

    /**
     * Check if equipment can be used
     */
    canUse(crewId) {
        const state = this.activeStates.get(crewId);
        if (!state) return false;

        const equipment = EquipmentData.get(state.equipmentId);
        if (!equipment) return false;

        // Passive equipment can't be "used"
        if (equipment.type === 'passive') return false;

        // Check cooldown
        if (equipment.type === 'active_cooldown' && state.cooldown > 0) {
            return false;
        }

        // Check charges
        if (equipment.type === 'active_charges' && state.charges <= 0) {
            return false;
        }

        return true;
    },

    /**
     * Use active equipment
     */
    use(crew, target, battle) {
        const state = this.activeStates.get(crew.id);
        if (!state || !this.canUse(crew.id)) {
            return { success: false, reason: 'not_ready' };
        }

        const effect = EquipmentData.getEffect(state.equipmentId, state.level);
        if (!effect) {
            return { success: false, reason: 'invalid_equipment' };
        }

        let result;

        switch (state.equipmentId) {
            case 'shockWave':
                result = this._useShockWave(crew, target, battle, effect);
                break;

            case 'fragGrenade':
                result = this._useFragGrenade(crew, target, battle, effect);
                break;

            case 'proximityMine':
                result = this._useProximityMine(crew, target, battle, effect);
                break;

            case 'rallyHorn':
                result = this._useRallyHorn(crew, target, battle, effect);
                break;

            case 'reviveKit':
                result = this._useReviveKit(crew, target, battle, effect);
                break;

            case 'shieldGenerator':
                result = this._useShieldGenerator(crew, target, battle, effect);
                break;

            case 'hackingDevice':
                result = this._useHackingDevice(crew, target, battle, effect);
                break;

            default:
                result = { success: false, reason: 'unknown_equipment' };
        }

        if (result.success) {
            // Apply cooldown or consume charge
            const equipment = EquipmentData.get(state.equipmentId);
            if (equipment.type === 'active_cooldown') {
                state.cooldown = state.maxCooldown;
            } else if (equipment.type === 'active_charges') {
                state.charges--;
            }
        }

        return result;
    },

    // ==========================================
    // EQUIPMENT IMPLEMENTATIONS
    // ==========================================

    /**
     * Shock Wave - AOE knockback and damage
     */
    _useShockWave(crew, target, battle, effect) {
        const direction = Math.atan2(target.y - crew.y, target.x - crew.x);

        // Jump forward
        const jumpDist = effect.jumpDistance * battle.tileSize;
        const landX = crew.x + Math.cos(direction) * jumpDist;
        const landY = crew.y + Math.sin(direction) * jumpDist;

        crew.x = landX;
        crew.y = landY;

        const radius = effect.radius * battle.tileSize;
        const hitEntities = [];

        // Damage and knockback enemies
        for (const enemy of battle.enemies) {
            const dist = Utils.distance(landX, landY, enemy.x, enemy.y);
            if (dist <= radius) {
                enemy.health -= effect.damage;
                battle.addDamageNumber(enemy.x, enemy.y, effect.damage);

                // Knockback
                const angle = Utils.angleBetween(landX, landY, enemy.x, enemy.y);
                const knockbackDist = effect.knockback * battle.tileSize;
                enemy.x += Math.cos(angle) * knockbackDist;
                enemy.y += Math.sin(angle) * knockbackDist;

                // Stun
                if (effect.stun) {
                    enemy.stunned = true;
                    enemy.stunTimer = effect.stun * 1000;
                }

                hitEntities.push(enemy);
            }
        }

        // Friendly fire (weak damage to allies)
        if (EquipmentData.hasFriendlyFire('shockWave')) {
            for (const ally of battle.crews) {
                if (ally.id === crew.id) continue;
                const dist = Utils.distance(landX, landY, ally.x, ally.y);
                if (dist <= radius) {
                    ally.squadSize = Math.max(1, ally.squadSize - 1);
                    battle.addDamageNumber(ally.x, ally.y, 1, true);
                }
            }
        }

        // Visual
        battle.addEffect({
            type: 'shockwave_large',
            x: landX,
            y: landY,
            radius: radius,
            duration: 500,
            timer: 0,
            color: '#f6ad55',
        });

        return { success: true, hitCount: hitEntities.length };
    },

    /**
     * Frag Grenade - Thrown explosive
     */
    _useFragGrenade(crew, target, battle, effect) {
        const throwRange = effect.throwRange * battle.tileSize;
        const dist = Utils.distance(crew.x, crew.y, target.x, target.y);

        // Clamp to max range
        let grenadeX = target.x;
        let grenadeY = target.y;
        if (dist > throwRange) {
            const angle = Utils.angleBetween(crew.x, crew.y, target.x, target.y);
            grenadeX = crew.x + Math.cos(angle) * throwRange;
            grenadeY = crew.y + Math.sin(angle) * throwRange;
        }

        // Create grenade projectile (delayed explosion)
        battle.addEffect({
            type: 'grenade_throw',
            startX: crew.x,
            startY: crew.y,
            endX: grenadeX,
            endY: grenadeY,
            duration: 500,
            timer: 0,
        });

        // Delayed explosion
        setTimeout(() => {
            const radius = effect.radius * battle.tileSize;
            const hitEnemies = [];

            for (const enemy of battle.enemies) {
                const d = Utils.distance(grenadeX, grenadeY, enemy.x, enemy.y);
                if (d <= radius) {
                    enemy.health -= effect.damage;
                    battle.addDamageNumber(enemy.x, enemy.y, effect.damage);
                    hitEnemies.push(enemy);
                }
            }

            // Friendly fire
            if (EquipmentData.hasFriendlyFire('fragGrenade')) {
                for (const ally of battle.crews) {
                    const d = Utils.distance(grenadeX, grenadeY, ally.x, ally.y);
                    if (d <= radius) {
                        const damage = Math.ceil(effect.damage / 4);
                        ally.squadSize = Math.max(1, ally.squadSize - Math.ceil(damage / 10));
                        battle.addDamageNumber(ally.x, ally.y, damage, true);
                    }
                }
            }

            battle.addEffect({
                type: 'explosion',
                x: grenadeX,
                y: grenadeY,
                radius: radius,
                duration: 400,
                timer: 0,
                color: '#f6ad55',
            });
        }, 500);

        return { success: true };
    },

    /**
     * Proximity Mine - Placed mine
     */
    _useProximityMine(crew, target, battle, effect) {
        const mine = {
            id: Utils.generateId(),
            x: target.x,
            y: target.y,
            damage: effect.damage,
            radius: effect.radius * battle.tileSize,
            triggerDelay: effect.triggerDelay,
            ownerId: crew.id,
            armed: true,
            triggered: false,
        };

        if (!battle.mines) battle.mines = [];
        battle.mines.push(mine);

        battle.addEffect({
            type: 'mine_placed',
            x: target.x,
            y: target.y,
            duration: 300,
            timer: 0,
        });

        return { success: true, mine: mine };
    },

    /**
     * Rally Horn - Instant heal
     */
    _useRallyHorn(crew, target, battle, effect) {
        let healAmount;

        if (effect.healPercent) {
            healAmount = crew.maxSquadSize;
        } else {
            healAmount = effect.healAmount;
        }

        const oldSize = crew.squadSize;
        crew.squadSize = Math.min(crew.maxSquadSize, crew.squadSize + healAmount);
        const actualHeal = crew.squadSize - oldSize;

        battle.addEffect({
            type: 'heal',
            x: crew.x,
            y: crew.y,
            amount: actualHeal,
            duration: 500,
            timer: 0,
            color: '#48bb78',
        });

        return { success: true, healed: actualHeal };
    },

    /**
     * Revive Kit - Revive dead crew
     */
    _useReviveKit(crew, target, battle, effect) {
        // Find dead crew to revive (from target selection)
        const deadCrew = battle.deadCrews?.find(c => c.id === target.crewId);
        if (!deadCrew) {
            return { success: false, reason: 'no_dead_crew' };
        }

        // Check if crew was retreating (can't revive)
        if (deadCrew.wasRetreating) {
            return { success: false, reason: 'was_retreating' };
        }

        // Revive with partial health
        deadCrew.isAlive = true;
        deadCrew.squadSize = Math.floor(deadCrew.maxSquadSize * effect.reviveHealth);

        // Add back to active crews
        battle.crews.push(deadCrew);
        battle.deadCrews = battle.deadCrews.filter(c => c.id !== deadCrew.id);

        battle.addEffect({
            type: 'revive',
            x: deadCrew.x,
            y: deadCrew.y,
            duration: 1000,
            timer: 0,
            color: '#68d391',
        });

        return { success: true, revived: deadCrew };
    },

    /**
     * Shield Generator - Temporary shield for team
     */
    _useShieldGenerator(crew, target, battle, effect) {
        // Apply shield to all friendly crews
        for (const ally of battle.crews) {
            ally.shielded = true;
            ally.shieldTimer = effect.duration;
            ally.shieldReduction = effect.damageReduction;
            ally.shieldReflect = effect.reflectProjectiles || false;
        }

        battle.addEffect({
            type: 'shield_activate',
            x: crew.x,
            y: crew.y,
            duration: effect.duration,
            timer: 0,
            color: '#63b3ed',
        });

        return { success: true };
    },

    /**
     * Hacking Device - Hack enemy turret/drone
     */
    _useHackingDevice(crew, target, battle, effect) {
        const hackRange = effect.hackRange * battle.tileSize;

        // Find hackable target
        let hackTarget = null;

        // Check turrets
        if (effect.targets.includes('turret') && battle.turrets) {
            for (const turret of battle.turrets) {
                if (turret.isHacked) continue;
                if (Utils.distance(crew.x, crew.y, turret.x, turret.y) <= hackRange) {
                    hackTarget = { type: 'turret', entity: turret };
                    break;
                }
            }
        }

        // Check drones
        if (!hackTarget && battle.drones) {
            for (const drone of battle.drones) {
                if (drone.isHacked) continue;
                const droneType = drone.size <= 15 ? 'smallDrone' : 'largeDrone';
                if (!effect.targets.includes(droneType)) continue;
                if (Utils.distance(crew.x, crew.y, drone.x, drone.y) <= hackRange) {
                    hackTarget = { type: 'drone', entity: drone };
                    break;
                }
            }
        }

        if (!hackTarget) {
            return { success: false, reason: 'no_target' };
        }

        // Start hacking (takes time)
        crew.state = 'hacking';
        crew.hackTarget = hackTarget.entity;
        crew.hackTimer = effect.hackTime;

        battle.addEffect({
            type: 'hacking',
            x: hackTarget.entity.x,
            y: hackTarget.entity.y,
            duration: effect.hackTime,
            timer: 0,
            color: '#68d391',
        });

        return { success: true, target: hackTarget };
    },

    // ==========================================
    // UPDATE LOOP
    // ==========================================

    /**
     * Update equipment states
     */
    update(dt, battle) {
        for (const [crewId, state] of this.activeStates) {
            // Update cooldowns
            if (state.cooldown > 0) {
                state.cooldown -= dt;
            }

            // Update active effects (like shield duration)
            if (state.active && state.activeTimer > 0) {
                state.activeTimer -= dt;
                if (state.activeTimer <= 0) {
                    state.active = false;
                    this._deactivateEffect(crewId, state, battle);
                }
            }
        }

        // Update mines
        this._updateMines(dt, battle);

        // Update crew shields
        this._updateShields(dt, battle);
    },

    /**
     * Update proximity mines
     */
    _updateMines(dt, battle) {
        if (!battle.mines) return;

        for (let i = battle.mines.length - 1; i >= 0; i--) {
            const mine = battle.mines[i];
            if (!mine.armed || mine.triggered) continue;

            // Check for enemies in trigger range
            for (const enemy of battle.enemies) {
                if (Utils.distance(mine.x, mine.y, enemy.x, enemy.y) < 30) {
                    mine.triggered = true;

                    // Delayed explosion
                    setTimeout(() => {
                        // Damage all enemies in radius
                        for (const e of battle.enemies) {
                            if (Utils.distance(mine.x, mine.y, e.x, e.y) <= mine.radius) {
                                e.health -= mine.damage;
                                battle.addDamageNumber(e.x, e.y, mine.damage);
                            }
                        }

                        battle.addEffect({
                            type: 'explosion',
                            x: mine.x,
                            y: mine.y,
                            radius: mine.radius,
                            duration: 400,
                            timer: 0,
                            color: '#fc8181',
                        });

                        // Remove mine
                        battle.mines = battle.mines.filter(m => m.id !== mine.id);
                    }, mine.triggerDelay);

                    break;
                }
            }
        }
    },

    /**
     * Update crew shields
     */
    _updateShields(dt, battle) {
        for (const crew of battle.crews) {
            if (crew.shielded && crew.shieldTimer > 0) {
                crew.shieldTimer -= dt;
                if (crew.shieldTimer <= 0) {
                    crew.shielded = false;
                    crew.shieldReduction = 0;
                    crew.shieldReflect = false;
                }
            }
        }
    },

    /**
     * Deactivate temporary effect
     */
    _deactivateEffect(crewId, state, battle) {
        switch (state.equipmentId) {
            case 'shieldGenerator':
                for (const crew of battle.crews) {
                    crew.shielded = false;
                    crew.shieldReduction = 0;
                    crew.shieldReflect = false;
                }
                break;
        }
    },

    // ==========================================
    // QUERY METHODS
    // ==========================================

    /**
     * Get equipment state for display
     */
    getState(crewId) {
        return this.activeStates.get(crewId) || null;
    },

    /**
     * Get cooldown percentage
     */
    getCooldownPercent(crewId) {
        const state = this.activeStates.get(crewId);
        if (!state || state.maxCooldown === 0) return 0;
        return Math.max(0, state.cooldown / state.maxCooldown);
    },

    /**
     * Get remaining charges
     */
    getCharges(crewId) {
        const state = this.activeStates.get(crewId);
        return state ? state.charges : 0;
    },

    /**
     * Calculate bonus credits from salvage cores
     */
    calculateBonusCredits(deployedCrews) {
        let bonus = 0;

        for (const crew of deployedCrews) {
            const state = this.activeStates.get(crew.id);
            if (state?.equipmentId === 'salvageCore') {
                const effect = EquipmentData.getEffect('salvageCore', state.level);
                bonus += effect.bonusCredits;
            }
        }

        return bonus;
    },

    /**
     * Check if equipment has friendly fire
     */
    checkFriendlyFire(equipmentId) {
        return EquipmentData.hasFriendlyFire(equipmentId);
    },

    /**
     * Reset all states
     */
    reset() {
        this.activeStates.clear();
        this.chargesUsed.clear();
    },
};

// Make available globally
window.EquipmentEffects = EquipmentEffects;
