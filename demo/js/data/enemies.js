/**
 * THE FADING RAVEN - Enemy Data
 * Defines all 15 enemy types across tiers with stats and behaviors
 */

const EnemyData = {
    enemies: {
        // ==========================================
        // Tier 1 - Basic Enemies
        // ==========================================

        rusher: {
            id: 'rusher',
            name: '러셔',
            nameEn: 'Rusher',
            tier: 1,

            stats: {
                health: 1,
                damage: 5,
                speed: 70,
                attackSpeed: 1200,
                attackRange: 40,
            },

            visual: {
                color: '#fc8181',
                size: 12,
                icon: '🗡️',
            },

            behavior: {
                id: 'melee_basic',
                priority: 'nearest_crew',
                attacksStation: true,
                special: null,
            },

            cost: 1,
            minDepth: 0,
            counters: ['guardian', 'sentinel', 'ranger'],
            threats: [],
            description: '기본 근접 적',
        },

        gunner: {
            id: 'gunner',
            name: '건너',
            nameEn: 'Gunner',
            tier: 1,

            stats: {
                health: 1,
                damage: 8,
                speed: 50,
                attackSpeed: 1500,
                attackRange: 150,
            },

            visual: {
                color: '#f6ad55',
                size: 12,
                icon: '🔫',
            },

            behavior: {
                id: 'ranged_basic',
                priority: 'nearest_crew',
                attacksStation: true,
                keepDistance: true,
                preferredRange: 120,
                special: null,
            },

            cost: 2,
            minDepth: 0,
            counters: ['guardian'],
            threats: ['sentinel', 'ranger'],
            description: '원거리 적, 실드에 약함',
        },

        shieldTrooper: {
            id: 'shieldTrooper',
            name: '실드 트루퍼',
            nameEn: 'Shield Trooper',
            tier: 1,

            stats: {
                health: 2,
                damage: 6,
                speed: 55,
                attackSpeed: 1300,
                attackRange: 45,
                frontShield: 0.9, // blocks 90% frontal ranged damage
            },

            visual: {
                color: '#4a9eff',
                size: 14,
                icon: '🛡️',
            },

            behavior: {
                id: 'melee_shielded',
                priority: 'nearest_crew',
                attacksStation: true,
                faceTarget: true, // always face target for shield
                special: {
                    type: 'frontalShield',
                    blockAngle: 90, // degrees
                },
            },

            cost: 3,
            minDepth: 0,
            counters: ['sentinel', 'bionic'],
            threats: ['ranger'],
            description: '정면 원거리 공격 방어',
        },

        // ==========================================
        // Tier 2 - Medium Enemies
        // ==========================================

        jumper: {
            id: 'jumper',
            name: '점퍼',
            nameEn: 'Jumper',
            tier: 2,

            stats: {
                health: 2,
                damage: 10,
                speed: 85,
                attackSpeed: 900,
                attackRange: 45,
            },

            visual: {
                color: '#9f7aea',
                size: 13,
                icon: '🦘',
            },

            behavior: {
                id: 'melee_jumper',
                priority: 'crew_bypassing_defense',
                attacksStation: false, // prioritizes crew
                special: {
                    type: 'jumpAttack',
                    jumpRange: 4, // tiles
                    jumpCooldown: 3000,
                    bypassesSentinel: true,
                },
            },

            cost: 4,
            minDepth: 3,
            counters: ['ranger', 'bionic'],
            threats: ['sentinel', 'engineer'],
            description: '점프팩으로 방어선 우회',
        },

        heavyTrooper: {
            id: 'heavyTrooper',
            name: '헤비 트루퍼',
            nameEn: 'Heavy Trooper',
            tier: 2,

            stats: {
                health: 3,
                damage: 12,
                speed: 45,
                attackSpeed: 1600,
                attackRange: 50,
                frontShield: 0.8,
            },

            visual: {
                color: '#718096',
                size: 18,
                icon: '💣',
            },

            behavior: {
                id: 'melee_heavy',
                priority: 'nearest_crew',
                attacksStation: true,
                special: {
                    type: 'grenadeThrow',
                    grenadeRange: 3, // tiles
                    grenadeDamage: 15,
                    grenadeRadius: 1.5,
                    grenadeCooldown: 8000,
                },
            },

            cost: 5,
            minDepth: 4,
            counters: [],
            threats: ['sentinel'], // grenade breaks formation
            description: '만능형, 수류탄 투척',
        },

        hacker: {
            id: 'hacker',
            name: '해커',
            nameEn: 'Hacker',
            tier: 2,

            stats: {
                health: 1,
                damage: 0, // no direct combat
                speed: 60,
                attackSpeed: 0,
                attackRange: 0,
            },

            visual: {
                color: '#68d391',
                size: 11,
                icon: '💻',
            },

            behavior: {
                id: 'support_hacker',
                priority: 'nearest_turret',
                attacksStation: false,
                fleesWhenTargeted: true,
                special: {
                    type: 'hackTurret',
                    hackRange: 2, // tiles
                    hackTime: 5000, // 5 seconds
                    hackEffect: 'turnHostile',
                },
            },

            cost: 3,
            minDepth: 4,
            counters: ['bionic', 'ranger'],
            threats: ['engineer'],
            description: '터렛/시스템 해킹',
        },

        stormCreature: {
            id: 'stormCreature',
            name: '폭풍 생명체',
            nameEn: 'Storm Creature',
            tier: 2,

            stats: {
                health: 2,
                damage: 20, // self-destruct damage
                speed: 75,
                attackSpeed: 0,
                attackRange: 30, // trigger range
            },

            visual: {
                color: '#e53e3e',
                size: 14,
                icon: '⚡',
            },

            behavior: {
                id: 'kamikaze',
                priority: 'nearest_crew',
                attacksStation: true,
                special: {
                    type: 'selfDestruct',
                    triggerRange: 30,
                    explosionRadius: 2, // tiles
                    explosionDamage: 20,
                },
            },

            cost: 3,
            minDepth: 0, // storm stage only
            counters: ['ranger'],
            threats: ['guardian', 'sentinel'],
            description: '폭풍 스테이지 전용, 자폭',
            stormOnly: true,
        },

        // ==========================================
        // Tier 3 - Advanced Enemies
        // ==========================================

        brute: {
            id: 'brute',
            name: '브루트',
            nameEn: 'Brute',
            tier: 3,

            stats: {
                health: 6, // 5-8 hits to kill
                damage: 25,
                speed: 35,
                attackSpeed: 2000,
                attackRange: 60,
                knockback: 3, // tiles
            },

            visual: {
                color: '#9f7aea',
                size: 28,
                icon: '👹',
            },

            behavior: {
                id: 'melee_brute',
                priority: 'nearest_crew',
                attacksStation: true,
                special: {
                    type: 'heavySwing',
                    knockbackForce: 3,
                    cleaveAngle: 120, // hits multiple targets
                    oneHitKill: true, // against normal units
                },
            },

            cost: 8,
            minDepth: 5,
            counters: ['sentinel'],
            threats: ['guardian', 'ranger', 'bionic', 'engineer'],
            description: '고체력, 강력한 넉백',
            groupSize: { min: 2, max: 4 },
        },

        sniper: {
            id: 'sniper',
            name: '스나이퍼',
            nameEn: 'Sniper',
            tier: 3,

            stats: {
                health: 1,
                damage: 30, // one-hit kill
                speed: 30,
                attackSpeed: 4000, // slow but deadly
                attackRange: 500, // entire map
            },

            visual: {
                color: '#ed64a6',
                size: 12,
                icon: '🎯',
            },

            behavior: {
                id: 'ranged_sniper',
                priority: 'highest_threat',
                attacksStation: false,
                staysBack: true,
                special: {
                    type: 'sniperShot',
                    aimTime: 3000, // 3 second warning
                    laserVisible: true,
                    cannotMoveWhileAiming: true,
                },
            },

            cost: 6,
            minDepth: 6,
            counters: ['bionic'],
            threats: ['ranger', 'guardian', 'sentinel'],
            description: '맵 전체 공격, 고데미지',
        },

        droneCarrier: {
            id: 'droneCarrier',
            name: '드론 캐리어',
            nameEn: 'Drone Carrier',
            tier: 3,

            stats: {
                health: 3,
                damage: 5,
                speed: 40,
                attackSpeed: 2000,
                attackRange: 100,
            },

            visual: {
                color: '#4fd1c5',
                size: 22,
                icon: '🤖',
            },

            behavior: {
                id: 'support_carrier',
                priority: 'safe_position',
                attacksStation: false,
                staysBack: true,
                special: {
                    type: 'spawnDrones',
                    spawnInterval: 10000, // every 10 seconds
                    dronesPerSpawn: 2,
                    maxDrones: 6,
                    droneStats: {
                        health: 1,
                        damage: 4,
                        speed: 90,
                        attackRange: 80,
                    },
                    dronesDisableOnDeath: true,
                },
            },

            cost: 7,
            minDepth: 7,
            counters: ['bionic', 'ranger'],
            threats: ['engineer'],
            description: '드론 지속 소환',
        },

        shieldGenerator: {
            id: 'shieldGenerator',
            name: '실드 제너레이터',
            nameEn: 'Shield Generator',
            tier: 3,

            stats: {
                health: 2,
                damage: 0, // no direct attack
                speed: 50,
                attackSpeed: 0,
                attackRange: 0,
            },

            visual: {
                color: '#63b3ed',
                size: 16,
                icon: '🔋',
            },

            behavior: {
                id: 'support_shield',
                priority: 'center_of_allies',
                attacksStation: false,
                staysWithAllies: true,
                special: {
                    type: 'aoeShield',
                    shieldRadius: 2, // tiles
                    shieldEffect: 'rangedImmunity',
                    shieldsDisableOnDeath: true,
                },
            },

            cost: 5,
            minDepth: 6,
            counters: ['bionic', 'guardian'],
            threats: ['ranger'],
            description: '주변 적에게 실드 부여',
        },

        // ==========================================
        // Boss Enemies
        // ==========================================

        pirateCaptain: {
            id: 'pirateCaptain',
            name: '해적 대장',
            nameEn: 'Pirate Captain',
            tier: 'boss',

            stats: {
                health: 15,
                damage: 20,
                speed: 45,
                attackSpeed: 1800,
                attackRange: 60,
            },

            visual: {
                color: '#e53e3e',
                size: 35,
                icon: '☠️',
            },

            behavior: {
                id: 'boss_captain',
                priority: 'nearest_crew',
                attacksStation: true,
                phases: [
                    {
                        healthThreshold: 1.0,
                        pattern: 'aggressive',
                    },
                    {
                        healthThreshold: 0.5,
                        pattern: 'summon_reinforcements',
                    },
                    {
                        healthThreshold: 0.25,
                        pattern: 'enraged',
                    },
                ],
                special: {
                    type: 'bossAbilities',
                    abilities: [
                        {
                            id: 'allyBuff',
                            effect: 'damageBoost',
                            value: 1.5,
                            radius: 3,
                        },
                        {
                            id: 'charge',
                            damage: 25,
                            knockback: 2,
                            cooldown: 8000,
                        },
                        {
                            id: 'summonRushers',
                            count: 5,
                            cooldown: 15000,
                        },
                    ],
                },
            },

            cost: 20,
            minDepth: 5,
            counters: [],
            threats: [],
            description: '보스, 다양한 패턴',
            isBoss: true,
            reward: {
                credits: 5,
                equipment: true,
            },
        },

        stormCore: {
            id: 'stormCore',
            name: '폭풍 핵',
            nameEn: 'Storm Core',
            tier: 'boss',

            stats: {
                health: -1, // invulnerable
                damage: 10, // periodic damage
                speed: 0, // stationary
                attackSpeed: 5000,
                attackRange: 999, // entire map
            },

            visual: {
                color: '#ed64a6',
                size: 50,
                icon: '🌀',
            },

            behavior: {
                id: 'boss_storm',
                priority: 'none',
                attacksStation: true,
                stationary: true,
                special: {
                    type: 'stormAbilities',
                    abilities: [
                        {
                            id: 'energyPulse',
                            damage: 10,
                            interval: 10000,
                            affectsAll: true,
                        },
                        {
                            id: 'spawnStormCreatures',
                            count: 3,
                            interval: 15000,
                        },
                        {
                            id: 'facilityDamage',
                            damagePerSecond: 1,
                        },
                    ],
                    retreatCondition: 'allWavesCleared',
                },
            },

            cost: 0, // not spawned normally
            minDepth: 0,
            counters: [],
            threats: [],
            description: '파괴 불가, 환경 위험',
            isBoss: true,
            invulnerable: true,
            stormOnly: true,
        },
    },

    // ==========================================
    // API Methods
    // ==========================================

    /**
     * Get enemy definition by ID
     */
    get(enemyId) {
        return this.enemies[enemyId] || null;
    },

    /**
     * Get enemies by tier
     */
    getByTier(tier) {
        return Object.values(this.enemies).filter(e => e.tier === tier);
    },

    /**
     * Get all enemies
     */
    getAll() {
        return Object.values(this.enemies);
    },

    /**
     * Get all enemy IDs
     */
    getAllIds() {
        return Object.keys(this.enemies);
    },

    /**
     * Get behavior pattern ID
     */
    getBehaviorId(enemyId) {
        const enemy = this.enemies[enemyId];
        return enemy ? enemy.behavior.id : null;
    },

    /**
     * Get enemies available at specific depth
     */
    getAvailableAtDepth(depth, isStormStage = false) {
        return Object.values(this.enemies).filter(e => {
            if (e.minDepth > depth) return false;
            if (e.stormOnly && !isStormStage) return false;
            if (e.isBoss) return false; // bosses handled separately
            return true;
        });
    },

    /**
     * Get enemy wave cost
     */
    getCost(enemyId) {
        const enemy = this.enemies[enemyId];
        return enemy ? enemy.cost : 0;
    },

    /**
     * Get enemy counters (classes that are strong against it)
     */
    getCounters(enemyId) {
        const enemy = this.enemies[enemyId];
        return enemy ? enemy.counters : [];
    },

    /**
     * Get enemy threats (classes that are weak against it)
     */
    getThreats(enemyId) {
        const enemy = this.enemies[enemyId];
        return enemy ? enemy.threats : [];
    },

    /**
     * Check if enemy is a boss
     */
    isBoss(enemyId) {
        const enemy = this.enemies[enemyId];
        return enemy ? enemy.isBoss === true : false;
    },

    /**
     * Get enemy display name
     */
    getName(enemyId, lang = 'ko') {
        const enemy = this.enemies[enemyId];
        if (!enemy) return enemyId;

        return lang === 'en' ? enemy.nameEn : enemy.name;
    },

    /**
     * Get enemy visual properties
     */
    getVisual(enemyId) {
        const enemy = this.enemies[enemyId];
        return enemy ? enemy.visual : { color: '#ffffff', size: 15, icon: '?' };
    },

    /**
     * Get enemies for wave generation
     */
    getForWaveGeneration(depth, budget, isStormStage = false) {
        const available = this.getAvailableAtDepth(depth, isStormStage);
        return available.filter(e => e.cost <= budget);
    },

    /**
     * Get bosses
     */
    getBosses() {
        return Object.values(this.enemies).filter(e => e.isBoss);
    },

    /**
     * Check if enemy has special mechanic
     */
    hasSpecialMechanic(enemyId, mechanicType) {
        const enemy = this.enemies[enemyId];
        if (!enemy || !enemy.behavior.special) return false;

        return enemy.behavior.special.type === mechanicType;
    },

    /**
     * Get special mechanic data
     */
    getSpecialMechanic(enemyId) {
        const enemy = this.enemies[enemyId];
        return enemy?.behavior?.special || null;
    },
};

// Make available globally
window.EnemyData = EnemyData;
