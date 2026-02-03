/**
 * THE FADING RAVEN - Balance Constants
 * Central location for all game balance values and difficulty scaling
 */

const BalanceData = {
    // ==========================================
    // Difficulty Settings
    // ==========================================

    difficulty: {
        normal: {
            id: 'normal',
            name: '보통',
            nameEn: 'Normal',
            enemyHealthMultiplier: 1.0,
            enemyDamageMultiplier: 1.0,
            enemyCountMultiplier: 1.0,
            waveCountBonus: 0,
            creditMultiplier: 1.0,
            scoreMultiplier: 1.0,
            unlockRequirement: null,
        },

        hard: {
            id: 'hard',
            name: '어려움',
            nameEn: 'Hard',
            enemyHealthMultiplier: 1.25,
            enemyDamageMultiplier: 1.25,
            enemyCountMultiplier: 1.5,
            waveCountBonus: 1,
            creditMultiplier: 1.25,
            scoreMultiplier: 1.5,
            unlockRequirement: 'normalCleared',
        },

        veryhard: {
            id: 'veryhard',
            name: '매우 어려움',
            nameEn: 'Very Hard',
            enemyHealthMultiplier: 1.5,
            enemyDamageMultiplier: 1.5,
            enemyCountMultiplier: 2.0,
            waveCountBonus: 2,
            bossEnhanced: true,
            creditMultiplier: 1.5,
            scoreMultiplier: 2.0,
            unlockRequirement: 'hardCleared',
        },

        nightmare: {
            id: 'nightmare',
            name: '악몽',
            nameEn: 'Nightmare',
            enemyHealthMultiplier: 2.0,
            enemyDamageMultiplier: 1.75,
            enemyCountMultiplier: 2.5,
            waveCountBonus: 3,
            bossEnhanced: true,
            permadeathUnlimited: true, // no revive limits
            creditMultiplier: 2.0,
            scoreMultiplier: 3.0,
            unlockRequirement: 'veryhardCleared',
        },
    },

    // ==========================================
    // Economy
    // ==========================================

    economy: {
        // Healing costs
        healCost: 12, // 20 → 15 → 12 (H-001 경제 밸런스 조정)
        healAmount: 2, // squad members restored

        // Skill upgrade costs by level
        skillUpgradeCosts: {
            1: 7,
            2: 10,
            3: 14,
        },

        // Rank up costs
        rankUpCosts: {
            standard: 0, // starting rank
            veteran: 100,
            elite: 200,
        },

        // Rank bonus
        rankBonuses: {
            veteran: {
                maxSquadSizeBonus: 1,
                damageMultiplier: 1.1,
                accuracyBonus: 0.15,
            },
            elite: {
                maxSquadSizeBonus: 2,
                damageMultiplier: 1.2,
                accuracyBonus: 0.25,
            },
        },

        // Equipment base cost multiplier
        equipmentBaseCostMultiplier: 1.0,

        // Credits from different sources
        perfectDefenseBonus: 5, // 2 → 5 (H-001 경제 밸런스 조정)
        bossKillBonus: 5,
        salvagerCreditPerKill: 0.1,

        // Starting credits
        startingCredits: 0,
    },

    // ==========================================
    // Combat
    // ==========================================

    combat: {
        // Slow motion when selecting crew
        slowMotionFactor: 0.25, // 25% speed

        // Base skill cooldowns (modified by class)
        skillCooldownBase: 10000, // 10 seconds

        // Critical hits (not used in base game but available)
        criticalChance: 0,
        criticalMultiplier: 1.5,

        // Knockback
        knockbackBase: 50, // pixels
        knockbackDecay: 0.9, // per frame

        // Stun duration base
        stunDurationBase: 1000, // 1 second

        // Recovery/Replenish time at facilities (Bad North formula: 2s × squadSize)
        recoveryTimePerMember: 2000, // 2 seconds per squad member
        recoveryTimeBase: 5000, // fallback

        // Squad formation
        formationSpread: 15, // pixels between squad members

        // Auto-targeting range multiplier
        autoTargetRangeMultiplier: 1.5,

        // Friendly fire damage reduction
        friendlyFireDamageMultiplier: 0.3,

        // Fall damage (into void/space)
        fallDamage: 999, // instant kill

        // ==========================================
        // Landing Knockback System (Bad North)
        // ==========================================
        landingKnockback: {
            // Knockback strength = baseKnockback × boatSizeMultiplier × enemyCountFactor / unitGradeResistance
            baseKnockback: 80, // base knockback in pixels

            // Boat size multipliers
            boatSizeMultiplier: {
                small: 0.5,   // 1-3 enemies
                medium: 1.0,  // 4-6 enemies
                large: 1.5,   // 7-10 enemies
                xlarge: 2.0,  // 11+ enemies
            },

            // Enemy count factor (more enemies = stronger knockback)
            enemyCountFactor: 0.1, // per enemy

            // Unit grade resistance (higher = less knockback)
            gradeResistance: {
                standard: 1.0,
                veteran: 1.5,
                elite: 2.0,
            },

            // Knockback thresholds
            weakThreshold: 30,   // < 30px = slight push, no stun
            strongThreshold: 60, // >= 60px = big push + stun
            stunDuration: 1500,  // stun duration for strong knockback

            // Steady Stance trait gives 80% resistance
            steadyStanceResistance: 0.8,
        },

        // ==========================================
        // Shield Mechanics (Bad North)
        // ==========================================
        shield: {
            // Shield blocks ranged attacks when not in melee
            rangedDamageReduction: 0.9, // 90% damage reduction

            // Shield is DISABLED during melee combat
            disabledDuringMelee: true,

            // Shield facing (only blocks from front)
            facingAngle: 90, // degrees (45° each side)
        },

        // ==========================================
        // Lance/Pike Mechanics (Bad North - "Lance Raise")
        // ==========================================
        lance: {
            // Sentinel raises lance when enemies get too close
            grapplingRange: 30, // pixels - range at which lance is raised

            // When lance is raised, Sentinel cannot attack
            raisedState: {
                canAttack: false,
                canMove: true,
                // Ways to exit raised state:
                // 1. Use Shock Wave equipment to push enemies back
                // 2. Move away from enemies
                // 3. Allied unit engages the close enemy
            },

            // Damage bonus at optimal range (enemies at lance tip)
            optimalRangeBonus: 1.5,
            optimalRange: { min: 40, max: 80 }, // pixels
        },

        // ==========================================
        // Melee Combat States
        // ==========================================
        melee: {
            // Range to enter melee combat
            engageRange: 25, // pixels

            // Units in melee cannot:
            // - Block ranged attacks with shield
            // - Use lance effectively (Sentinel)

            // Disengage conditions
            disengageDistance: 50, // must move this far to disengage
        },
    },

    // ==========================================
    // Wave Generation
    // ==========================================

    wave: {
        // Base budget for wave generation
        baseBudget: 10,
        budgetPerDepth: 3,
        budgetPerWave: 2, // within same stage

        // Enemy count limits
        minEnemies: 3,
        maxEnemies: 30,

        // Spawn timing
        spawnStaggerMs: 300, // delay between enemy spawns
        waveDelayMs: 5000, // delay between waves

        // Tier restrictions by depth
        tierUnlockDepth: {
            1: 0, // tier 1 always available
            2: 3, // tier 2 from depth 3
            3: 5, // tier 3 from depth 5
        },

        // Special enemy spawn chances
        specialSpawnChance: {
            brute: 0.15,
            sniper: 0.1,
            droneCarrier: 0.1,
            shieldGenerator: 0.15,
        },

        // Boss spawn interval
        bossDepthInterval: 5, // boss every 5 depths
    },

    // ==========================================
    // Progression
    // ==========================================

    progression: {
        // Sector map generation
        sectorDepth: {
            normal: { min: 12, max: 15 },
            hard: { min: 15, max: 18 },
            veryhard: { min: 18, max: 22 },
            nightmare: { min: 22, max: 25 },
        },

        nodesPerDepth: {
            normal: { min: 2, max: 3 },
            hard: { min: 2, max: 4 },
            veryhard: { min: 3, max: 4 },
            nightmare: { min: 3, max: 5 },
        },

        // Storm front
        stormAdvanceRate: 1, // advances 1 depth per turn
        stormStartDepth: 0, // starts at beginning

        // Event node distribution
        eventDistribution: {
            battle: 50,
            elite: 10,
            shop: 15,
            event: 15,
            rest: 10,
        },

        // Crew recruitment
        crewRecruitmentDepth: {
            first: 2, // first recruitment at depth 2-3
            interval: 3, // then every 3-4 depths
        },

        // Equipment nodes
        equipmentNodeInterval: 2, // every 2-3 depths

        // Storm stage chance
        stormStageChance: 0.2, // 20% from depth 4+
        stormStageMinDepth: 4,
    },

    // ==========================================
    // Raven Drone
    // ==========================================

    raven: {
        // Base ability uses per stage
        scoutUses: -1, // unlimited, once per wave
        flareUses: 2,
        resupplyUses: 1,
        orbitalStrikeUses: 1,

        // Ability effects
        flareDuration: 10000, // 10 seconds
        resupplyHealPercent: 1.0, // full heal

        orbitalStrike: {
            damage: 50,
            radius: 1.5, // tiles
            delay: 2000, // warning time
            friendlyFire: true,
        },
    },

    // ==========================================
    // Station Layout
    // ==========================================

    station: {
        // Map sizes by difficulty score
        mapSizes: {
            small: { width: 5, height: 5, tiles: 25, facilities: { min: 2, max: 3 } },
            medium: { width: 7, height: 7, tiles: 49, facilities: { min: 3, max: 4 } },
            large: { width: 9, height: 9, tiles: 81, facilities: { min: 4, max: 5 } },
            xlarge: { width: 11, height: 11, tiles: 121, facilities: { min: 5, max: 6 } },
        },

        // Difficulty score thresholds for map size
        mapSizeThresholds: {
            small: 0,
            medium: 2,
            large: 3,
            xlarge: 4.5,
        },

        // Spawn point configuration
        minSpawnPoints: 2,
        maxSpawnPoints: 4,

        // Pathfinding
        pathfindingIterations: 1000, // A* max iterations
    },

    // ==========================================
    // Scoring
    // ==========================================

    scoring: {
        stationDefended: 500,
        perfectDefense: 200,
        enemyKilled: 10,
        creditsEarned: 5,
        crewLost: -1000,
    },

    // ==========================================
    // Unit Grade Combat Stats (Bad North Style)
    // ==========================================

    unitGrades: {
        standard: {
            attackPower: 1.0,
            defense: 1.0,
            moveSpeed: 1.0,
            attackSpeed: 1.0,
            maxSquadSize: 8,
            knockbackResistance: 1.0,
            morale: 1.0,
            cost: 0,
        },
        veteran: {
            attackPower: 1.15,
            defense: 1.2,
            moveSpeed: 1.05,
            attackSpeed: 1.1,
            maxSquadSize: 9,
            knockbackResistance: 1.5,
            morale: 1.3,
            cost: 100,
        },
        elite: {
            attackPower: 1.35,
            defense: 1.4,
            moveSpeed: 1.1,
            attackSpeed: 1.2,
            maxSquadSize: 10,
            knockbackResistance: 2.0,
            morale: 1.6,
            cost: 200,
        },
    },

    // ==========================================
    // Wave Progression Patterns (Bad North Style)
    // ==========================================

    wavePatterns: {
        // Wave progression types based on Bad North
        progression: {
            // Early waves: simple enemies, low count
            early: {
                enemyTypes: ['grunt', 'raider'],
                countRange: { min: 3, max: 6 },
                spawnDelay: 2000, // ms between spawns
                directionVariance: 1, // how many directions
            },
            // Mid waves: mix of enemies, flanking starts
            mid: {
                enemyTypes: ['grunt', 'raider', 'brute', 'gunner'],
                countRange: { min: 5, max: 10 },
                spawnDelay: 1500,
                directionVariance: 2,
            },
            // Late waves: elite enemies, multi-direction attacks
            late: {
                enemyTypes: ['brute', 'sniper', 'shielded', 'commander'],
                countRange: { min: 8, max: 15 },
                spawnDelay: 1000,
                directionVariance: 3,
            },
            // Boss waves: mini-boss with support units
            boss: {
                enemyTypes: ['boss'],
                supportTypes: ['grunt', 'raider', 'shielded'],
                countRange: { min: 1, max: 1 },
                supportCount: { min: 4, max: 8 },
                spawnDelay: 500,
                directionVariance: 4,
            },
        },

        // Spawn timing patterns
        timing: {
            simultaneous: { delay: 0, name: '동시 상륙' },
            staggered: { delay: 500, name: '순차 상륙' },
            waves: { delay: 3000, name: '파상 공격' },
            rush: { delay: 200, name: '급습' },
        },

        // Difficulty scaling for wave patterns
        difficultyScaling: {
            normal: {
                patternAdvanceDepth: 5, // depth to advance pattern
                maxSimultaneousSpawns: 2,
            },
            hard: {
                patternAdvanceDepth: 4,
                maxSimultaneousSpawns: 3,
            },
            veryhard: {
                patternAdvanceDepth: 3,
                maxSimultaneousSpawns: 4,
            },
            nightmare: {
                patternAdvanceDepth: 2,
                maxSimultaneousSpawns: 5,
            },
        },
    },

    // ==========================================
    // Environmental Hazards (Void/Water Death)
    // ==========================================

    environmental: {
        // Void (space) - instant death
        void: {
            damage: 9999,
            instantKill: true,
            knockbackVulnerable: true, // can be knocked into
        },

        // Hazard tiles
        hazardTiles: {
            // Space/void around station
            space: { type: 'void', damage: 9999, instant: true },
            // Damaged hull (may collapse)
            damagedHull: { type: 'hazard', collapseChance: 0.3 },
            // Fire
            fire: { type: 'dot', damagePerSec: 5, duration: 3000 },
        },

        // Knockback into void combo
        voidKnockback: {
            enabled: true,
            // Distance past edge needed to fall
            edgeThreshold: 10, // pixels past tile edge
            // Grab ledge chance (elite units only)
            ledgeGrabChance: {
                standard: 0,
                veteran: 0.15,
                elite: 0.3,
            },
            // Rescue time window if grabbed ledge
            rescueWindow: 3000, // ms
        },
    },

    // ==========================================
    // API Methods
    // ==========================================

    /**
     * Get difficulty multiplier for a stat
     */
    getDifficultyMultiplier(difficultyId, stat) {
        const diff = this.difficulty[difficultyId];
        if (!diff) return 1;

        const multiplierKey = stat + 'Multiplier';
        return diff[multiplierKey] || 1;
    },

    /**
     * Get wave configuration for depth and difficulty
     */
    getWaveConfig(depth, difficultyId) {
        const diff = this.difficulty[difficultyId] || this.difficulty.normal;

        const baseBudget = this.wave.baseBudget + (depth * this.wave.budgetPerDepth);
        const budget = Math.floor(baseBudget * diff.enemyCountMultiplier);

        return {
            budget,
            waveCount: 2 + Math.floor(depth / 3) + diff.waveCountBonus,
            minEnemies: this.wave.minEnemies,
            maxEnemies: this.wave.maxEnemies,
            tier1Available: depth >= this.wave.tierUnlockDepth[1],
            tier2Available: depth >= this.wave.tierUnlockDepth[2],
            tier3Available: depth >= this.wave.tierUnlockDepth[3],
        };
    },

    /**
     * Get economy configuration
     */
    getEconomyConfig() {
        return { ...this.economy };
    },

    /**
     * Get combat configuration
     */
    getCombatConfig() {
        return { ...this.combat };
    },

    /**
     * Calculate skill upgrade cost with trait discount
     */
    calculateSkillUpgradeCost(targetLevel, hasSkilledTrait = false) {
        const baseCost = this.economy.skillUpgradeCosts[targetLevel] || 0;
        return hasSkilledTrait ? Math.floor(baseCost * 0.5) : baseCost;
    },

    /**
     * Calculate rank up cost
     */
    calculateRankUpCost(targetRank) {
        return this.economy.rankUpCosts[targetRank] || 0;
    },

    /**
     * Get map size for difficulty score
     */
    getMapSizeForScore(score) {
        if (score >= this.station.mapSizeThresholds.xlarge) return 'xlarge';
        if (score >= this.station.mapSizeThresholds.large) return 'large';
        if (score >= this.station.mapSizeThresholds.medium) return 'medium';
        return 'small';
    },

    /**
     * Calculate difficulty score for depth
     */
    calculateDifficultyScore(depth, difficultyId) {
        const baseMultipliers = {
            normal: 1.0,
            hard: 1.5,
            veryhard: 2.0,
            nightmare: 2.5,
        };

        const scalingPerDepth = {
            normal: 0.15,
            hard: 0.20,
            veryhard: 0.25,
            nightmare: 0.30,
        };

        const base = baseMultipliers[difficultyId] || 1.0;
        const scaling = scalingPerDepth[difficultyId] || 0.15;

        return base + (depth * scaling);
    },

    /**
     * Get sector generation parameters for difficulty
     */
    getSectorParams(difficultyId) {
        const depth = this.progression.sectorDepth[difficultyId] || this.progression.sectorDepth.normal;
        const nodes = this.progression.nodesPerDepth[difficultyId] || this.progression.nodesPerDepth.normal;

        return {
            minDepth: depth.min,
            maxDepth: depth.max,
            minNodesPerDepth: nodes.min,
            maxNodesPerDepth: nodes.max,
            eventDistribution: this.progression.eventDistribution,
            stormAdvanceRate: this.progression.stormAdvanceRate,
        };
    },

    /**
     * Calculate final score
     */
    calculateFinalScore(stats, difficultyId) {
        const diff = this.difficulty[difficultyId] || this.difficulty.normal;

        let score = 0;
        score += (stats.stationsDefended || 0) * this.scoring.stationDefended;
        score += (stats.perfectDefenses || 0) * this.scoring.perfectDefense;
        score += (stats.enemiesKilled || 0) * this.scoring.enemyKilled;
        score += (stats.creditsEarned || 0) * this.scoring.creditsEarned;
        score += (stats.crewsLost || 0) * this.scoring.crewLost;

        return Math.max(0, Math.floor(score * diff.scoreMultiplier));
    },

    /**
     * Check if difficulty is unlocked
     */
    isDifficultyUnlocked(difficultyId, progress) {
        const diff = this.difficulty[difficultyId];
        if (!diff || !diff.unlockRequirement) return true;

        // Check progress for unlock requirement
        switch (diff.unlockRequirement) {
            case 'normalCleared':
                return progress.normalCleared === true;
            case 'hardCleared':
                return progress.hardCleared === true;
            case 'veryhardCleared':
                return progress.veryhardCleared === true;
            default:
                return false;
        }
    },

    /**
     * Get all difficulty IDs in order
     */
    getDifficultyOrder() {
        return ['normal', 'hard', 'veryhard', 'nightmare'];
    },

    // ==========================================
    // Combat Mechanics API (Bad North)
    // ==========================================

    /**
     * Calculate recovery/replenish time based on squad size
     * Bad North formula: 2 seconds × squad size
     * @param {number} squadSize - Current squad size
     * @param {boolean} hasQuickRecovery - Has Quick Recovery trait (-33%)
     * @returns {number} Recovery time in milliseconds
     */
    calculateRecoveryTime(squadSize, hasQuickRecovery = false) {
        const baseTime = squadSize * this.combat.recoveryTimePerMember;
        return hasQuickRecovery ? Math.floor(baseTime * 0.67) : baseTime;
    },

    /**
     * Calculate landing knockback when enemies spawn/land
     * @param {Object} config - { boatSize, enemyCount, unitGrade, hasSteadyStance }
     * @returns {Object} { knockbackPx, isStrong, stunDuration }
     */
    calculateLandingKnockback(config) {
        const { boatSize = 'medium', enemyCount = 5, unitGrade = 'standard', hasSteadyStance = false } = config;
        const lk = this.combat.landingKnockback;

        // Get multipliers
        const sizeMultiplier = lk.boatSizeMultiplier[boatSize] || 1.0;
        const countFactor = 1 + (enemyCount * lk.enemyCountFactor);
        const gradeResistance = lk.gradeResistance[unitGrade] || 1.0;

        // Calculate base knockback
        let knockbackPx = (lk.baseKnockback * sizeMultiplier * countFactor) / gradeResistance;

        // Apply Steady Stance trait
        if (hasSteadyStance) {
            knockbackPx *= (1 - lk.steadyStanceResistance);
        }

        // Determine knockback strength
        const isWeak = knockbackPx < lk.weakThreshold;
        const isStrong = knockbackPx >= lk.strongThreshold;

        return {
            knockbackPx: Math.floor(knockbackPx),
            isWeak,
            isStrong,
            stunDuration: isStrong ? lk.stunDuration : 0,
        };
    },

    /**
     * Get boat size category based on enemy count
     * @param {number} enemyCount - Number of enemies in boat
     * @returns {string} 'small' | 'medium' | 'large' | 'xlarge'
     */
    getBoatSizeCategory(enemyCount) {
        if (enemyCount <= 3) return 'small';
        if (enemyCount <= 6) return 'medium';
        if (enemyCount <= 10) return 'large';
        return 'xlarge';
    },

    /**
     * Check if shield blocks damage (based on melee state and facing)
     * @param {Object} config - { isInMelee, facingAngle, attackAngle }
     * @returns {Object} { blocked, damageReduction }
     */
    checkShieldBlock(config) {
        const { isInMelee = false, facingAngle = 0, attackAngle = 0 } = config;
        const shield = this.combat.shield;

        // Shield disabled during melee
        if (shield.disabledDuringMelee && isInMelee) {
            return { blocked: false, damageReduction: 0 };
        }

        // Check facing angle
        const angleDiff = Math.abs(facingAngle - attackAngle);
        const normalizedDiff = angleDiff > 180 ? 360 - angleDiff : angleDiff;

        if (normalizedDiff <= shield.facingAngle / 2) {
            return { blocked: true, damageReduction: shield.rangedDamageReduction };
        }

        return { blocked: false, damageReduction: 0 };
    },

    /**
     * Check if Sentinel lance is raised (too close to enemies)
     * @param {number} distanceToEnemy - Distance to nearest enemy in pixels
     * @returns {Object} { lanceRaised, canAttack, damageMultiplier }
     */
    checkLanceState(distanceToEnemy) {
        const lance = this.combat.lance;

        // Lance raised when enemy in grappling range
        if (distanceToEnemy <= lance.grapplingRange) {
            return {
                lanceRaised: true,
                canAttack: lance.raisedState.canAttack,
                damageMultiplier: 0,
            };
        }

        // Optimal range bonus
        if (distanceToEnemy >= lance.optimalRange.min && distanceToEnemy <= lance.optimalRange.max) {
            return {
                lanceRaised: false,
                canAttack: true,
                damageMultiplier: lance.optimalRangeBonus,
            };
        }

        // Normal attack
        return {
            lanceRaised: false,
            canAttack: true,
            damageMultiplier: 1.0,
        };
    },

    /**
     * Check if unit is in melee combat
     * @param {number} distanceToEnemy - Distance to nearest enemy
     * @returns {boolean}
     */
    isInMeleeCombat(distanceToEnemy) {
        return distanceToEnemy <= this.combat.melee.engageRange;
    },

    /**
     * Get combat state summary for a unit
     * @param {Object} config - { classId, distanceToEnemy, unitGrade, traits }
     * @returns {Object} Combat state with all modifiers
     */
    getCombatState(config) {
        const { classId, distanceToEnemy = 100, unitGrade = 'standard', traits = [] } = config;
        const isInMelee = this.isInMeleeCombat(distanceToEnemy);

        const state = {
            isInMelee,
            canAttack: true,
            damageMultiplier: 1.0,
            shieldActive: false,
            lanceRaised: false,
        };

        // Class-specific mechanics
        switch (classId) {
            case 'guardian':
                // Shield active when not in melee
                state.shieldActive = !isInMelee;
                break;

            case 'sentinel':
                // Lance mechanics
                const lanceState = this.checkLanceState(distanceToEnemy);
                state.lanceRaised = lanceState.lanceRaised;
                state.canAttack = lanceState.canAttack;
                state.damageMultiplier = lanceState.damageMultiplier;
                break;

            case 'ranger':
                // Ranged unit - melee penalty
                if (isInMelee) {
                    state.damageMultiplier = 0.3; // severe melee penalty
                }
                break;

            case 'engineer':
                // Weak in combat
                state.damageMultiplier = 0.5;
                break;

            case 'bionic':
                // Assassination bonus when target not in combat
                // (handled separately in damage calculation)
                break;
        }

        return state;
    },

    // ==========================================
    // Unit Grade API
    // ==========================================

    /**
     * Get unit grade stats
     * @param {string} grade - 'standard' | 'veteran' | 'elite'
     * @returns {Object} Grade stats
     */
    getUnitGradeStats(grade) {
        return this.unitGrades[grade] || this.unitGrades.standard;
    },

    /**
     * Calculate stat with grade modifier
     * @param {number} baseStat - Base stat value
     * @param {string} grade - Unit grade
     * @param {string} statType - Stat type key (attackPower, defense, etc.)
     * @returns {number} Modified stat
     */
    applyGradeModifier(baseStat, grade, statType) {
        const gradeStats = this.getUnitGradeStats(grade);
        const modifier = gradeStats[statType] || 1.0;
        return baseStat * modifier;
    },

    // ==========================================
    // Wave Pattern API
    // ==========================================

    /**
     * Get wave pattern for depth
     * @param {number} depth - Current depth
     * @param {string} difficultyId - Difficulty level
     * @returns {Object} Wave pattern configuration
     */
    getWavePattern(depth, difficultyId = 'normal') {
        const scaling = this.wavePatterns.difficultyScaling[difficultyId] ||
                        this.wavePatterns.difficultyScaling.normal;
        const advanceDepth = scaling.patternAdvanceDepth;

        // Determine pattern stage based on depth
        let patternStage;
        if (depth < advanceDepth) {
            patternStage = 'early';
        } else if (depth < advanceDepth * 2) {
            patternStage = 'mid';
        } else if (depth % 5 === 0) {
            patternStage = 'boss';
        } else {
            patternStage = 'late';
        }

        const pattern = this.wavePatterns.progression[patternStage];

        return {
            ...pattern,
            stage: patternStage,
            maxSimultaneousSpawns: scaling.maxSimultaneousSpawns,
        };
    },

    /**
     * Get spawn timing pattern
     * @param {string} timingType - 'simultaneous' | 'staggered' | 'waves' | 'rush'
     * @returns {Object} Timing configuration
     */
    getSpawnTiming(timingType) {
        return this.wavePatterns.timing[timingType] || this.wavePatterns.timing.staggered;
    },

    // ==========================================
    // Environmental Hazard API
    // ==========================================

    /**
     * Check if position would result in void death
     * @param {Object} position - { x, y } in pixels
     * @param {Object} tileGrid - Reference to TileGrid
     * @returns {Object} { wouldFall, canGrabLedge, rescueWindow }
     */
    checkVoidDeath(position, tileGrid, unitGrade = 'standard') {
        const env = this.environmental;

        // This is a placeholder - actual tile checking is in CombatMechanics
        const result = {
            wouldFall: false,
            canGrabLedge: false,
            rescueWindow: 0,
        };

        if (!env.voidKnockback.enabled) {
            return result;
        }

        // Ledge grab chance based on grade
        const grabChance = env.voidKnockback.ledgeGrabChance[unitGrade] || 0;
        if (grabChance > 0 && Math.random() < grabChance) {
            result.canGrabLedge = true;
            result.rescueWindow = env.voidKnockback.rescueWindow;
        }

        return result;
    },

    /**
     * Get hazard tile damage
     * @param {string} hazardType - Hazard type key
     * @returns {Object} Hazard configuration
     */
    getHazardTileDamage(hazardType) {
        return this.environmental.hazardTiles[hazardType] || null;
    },
};

// Make available globally
window.BalanceData = BalanceData;
