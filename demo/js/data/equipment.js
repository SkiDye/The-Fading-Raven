/**
 * THE FADING RAVEN - Equipment Data
 * Defines all 10 equipment items with upgrade levels and effects
 */

const EquipmentData = {
    items: {
        commandModule: {
            id: 'commandModule',
            name: '커맨드 모듈',
            nameEn: 'Command Module',
            desc: '분대 크기를 증가시킵니다.',
            type: 'passive',
            baseCost: 60,
            recommendedClasses: ['ranger'],

            levels: [
                {
                    level: 1,
                    effect: {
                        squadSizeBonus: 3, // 8 -> 11
                        recoveryTimeMultiplier: 1.375, // 16s -> 22s
                    },
                    upgradeCost: 0, // base purchase
                    description: '분대 크기 +3, 회복 시간 +37.5%',
                },
                {
                    level: 2,
                    effect: {
                        squadSizeBonus: 6, // 8 -> 14
                        recoveryTimeMultiplier: 1.75, // 16s -> 28s
                    },
                    upgradeCost: 16,
                    description: '분대 크기 +6, 회복 시간 +75%',
                },
            ],
        },

        shockWave: {
            id: 'shockWave',
            name: '충격파',
            nameEn: 'Shock Wave',
            desc: '전방으로 점프 후 AOE 데미지와 넉백을 줍니다.',
            type: 'active_cooldown',
            cooldown: 40000, // 40 seconds
            baseCost: 75,
            recommendedClasses: ['sentinel', 'guardian'],
            friendlyFire: true, // weak damage to allies

            levels: [
                {
                    level: 1,
                    effect: {
                        damage: 20,
                        knockback: 2, // tiles
                        radius: 2, // tiles
                        jumpDistance: 1,
                    },
                    upgradeCost: 0,
                    description: '기본 충격파',
                },
                {
                    level: 2,
                    effect: {
                        damage: 30,
                        knockback: 3,
                        radius: 2.5,
                        jumpDistance: 2,
                        stun: 0.5, // seconds
                    },
                    upgradeCost: 12,
                    description: '데미지/넉백 강화, 스턴 추가',
                },
            ],
        },

        fragGrenade: {
            id: 'fragGrenade',
            name: '파편 수류탄',
            nameEn: 'Frag Grenade',
            desc: '투척형 폭발물로 범위 피해를 줍니다.',
            type: 'active_charges',
            baseCost: 60,
            recommendedClasses: ['ranger', 'guardian'],
            friendlyFire: true,

            levels: [
                {
                    level: 1,
                    effect: {
                        charges: 1,
                        damage: 40,
                        radius: 1.5, // tiles
                        throwRange: 2, // tiles
                    },
                    upgradeCost: 0,
                    description: '1개/스테이지',
                },
                {
                    level: 2,
                    effect: {
                        charges: 2,
                        damage: 45,
                        radius: 1.5,
                        throwRange: 2.5,
                    },
                    upgradeCost: 8,
                    description: '2개/스테이지',
                },
                {
                    level: 3,
                    effect: {
                        charges: 3,
                        damage: 50,
                        radius: 2,
                        throwRange: 3,
                    },
                    upgradeCost: 14,
                    description: '3개 + AOE 증가',
                },
            ],
        },

        proximityMine: {
            id: 'proximityMine',
            name: '근접 지뢰',
            nameEn: 'Proximity Mine',
            desc: '설치형 지뢰로 적 접근 시 폭발합니다.',
            type: 'active_charges',
            baseCost: 55,
            recommendedClasses: ['engineer'],
            friendlyFire: false,

            levels: [
                {
                    level: 1,
                    effect: {
                        charges: 1,
                        damage: 50,
                        radius: 1.5,
                        triggerDelay: 300, // ms
                    },
                    upgradeCost: 0,
                    description: '1개/스테이지',
                },
                {
                    level: 2,
                    effect: {
                        charges: 2,
                        damage: 55,
                        radius: 1.5,
                        triggerDelay: 200,
                    },
                    upgradeCost: 8,
                    description: '2개/스테이지',
                },
                {
                    level: 3,
                    effect: {
                        charges: 3,
                        damage: 65,
                        radius: 2,
                        triggerDelay: 100,
                    },
                    upgradeCost: 14,
                    description: '3개 + 데미지 증가',
                },
            ],

            // Special: Can malfunction from landing ship impact
            malfunction: {
                impactChance: 0.3,
            },
        },

        rallyHorn: {
            id: 'rallyHorn',
            name: '랠리 혼',
            nameEn: 'Rally Horn',
            desc: '즉시 병력을 보충합니다.',
            type: 'active_charges',
            baseCost: 70,
            recommendedClasses: ['guardian'],
            friendlyFire: false,

            levels: [
                {
                    level: 1,
                    effect: {
                        charges: 1,
                        healAmount: 3, // squad members
                        healPercent: null,
                    },
                    upgradeCost: 0,
                    description: '1회/스테이지, +3 병력',
                },
                {
                    level: 2,
                    effect: {
                        charges: 2,
                        healAmount: 4,
                        healPercent: null,
                    },
                    upgradeCost: 10,
                    description: '2회/스테이지, +4 병력',
                },
                {
                    level: 3,
                    effect: {
                        charges: 3,
                        healAmount: null,
                        healPercent: 100, // full heal
                    },
                    upgradeCost: 16,
                    description: '3회/스테이지, 완전 회복',
                },
            ],
        },

        reviveKit: {
            id: 'reviveKit',
            name: '리바이브 키트',
            nameEn: 'Revive Kit',
            desc: '전멸한 팀을 1회 부활시킵니다.',
            type: 'active_charges',
            baseCost: 100,
            recommendedClasses: ['guardian', 'sentinel'],
            friendlyFire: false,

            levels: [
                {
                    level: 1,
                    effect: {
                        charges: 1, // per campaign, not stage
                        reviveHealth: 0.5, // 50% health
                        scope: 'campaign',
                    },
                    upgradeCost: 0,
                    description: '캠페인당 1회, 50% 체력 부활',
                },
            ],

            // Special: Cannot revive if crew was retreating
            restrictions: ['cannotReviveRetreating'],
        },

        stimPack: {
            id: 'stimPack',
            name: '스팀 팩',
            nameEn: 'Stim Pack',
            desc: '턴당 추가 행동/공격을 제공합니다.',
            type: 'passive',
            baseCost: 65,
            recommendedClasses: ['bionic'],
            friendlyFire: false,

            levels: [
                {
                    level: 1,
                    effect: {
                        attackSpeedMultiplier: 1.25, // 25% faster attacks
                        moveSpeedMultiplier: 1.1,
                    },
                    upgradeCost: 0,
                    description: '공격 속도 +25%, 이동 속도 +10%',
                },
                {
                    level: 2,
                    effect: {
                        attackSpeedMultiplier: 1.5,
                        moveSpeedMultiplier: 1.2,
                        extraAction: true, // additional action per turn
                    },
                    upgradeCost: 14,
                    description: '공격 속도 +50%, 이동 속도 +20%, 추가 행동',
                },
            ],
        },

        salvageCore: {
            id: 'salvageCore',
            name: '샐비지 코어',
            nameEn: 'Salvage Core',
            desc: '스테이지 클리어 시 추가 크레딧을 획득합니다.',
            type: 'passive',
            baseCost: 40,
            recommendedClasses: [], // any class
            friendlyFire: false,

            levels: [
                {
                    level: 1,
                    effect: {
                        bonusCredits: 1,
                    },
                    upgradeCost: 0,
                    description: '+1 크레딧/스테이지',
                },
                {
                    level: 2,
                    effect: {
                        bonusCredits: 2,
                    },
                    upgradeCost: 5,
                    description: '+2 크레딧/스테이지',
                },
                {
                    level: 3,
                    effect: {
                        bonusCredits: 3,
                    },
                    upgradeCost: 9,
                    description: '+3 크레딧/스테이지',
                },
            ],

            // Special: Must deploy crew to get bonus
            requirement: 'mustBeDeployed',
        },

        shieldGenerator: {
            id: 'shieldGenerator',
            name: '보호막 생성기',
            nameEn: 'Shield Generator',
            desc: '팀 전체에 일시적 에너지 실드를 부여합니다.',
            type: 'active_cooldown',
            cooldown: 60000, // 60 seconds
            baseCost: 85,
            recommendedClasses: ['sentinel', 'ranger'],
            friendlyFire: false,

            levels: [
                {
                    level: 1,
                    effect: {
                        duration: 5000, // 5 seconds
                        damageReduction: 0.75, // 75% damage reduction
                        projectileBlock: true,
                    },
                    upgradeCost: 0,
                    description: '5초간 75% 피해 감소',
                },
                {
                    level: 2,
                    effect: {
                        duration: 7000,
                        damageReduction: 0.9,
                        projectileBlock: true,
                        reflectProjectiles: true, // reflects some projectiles
                    },
                    upgradeCost: 14,
                    description: '7초간 90% 피해 감소, 투사체 반사',
                },
            ],
        },

        hackingDevice: {
            id: 'hackingDevice',
            name: '해킹 장치',
            nameEn: 'Hacking Device',
            desc: '적 터렛이나 드론을 해킹하여 아군으로 만듭니다.',
            type: 'active_charges',
            baseCost: 70,
            recommendedClasses: ['engineer'],
            friendlyFire: false,

            levels: [
                {
                    level: 1,
                    effect: {
                        charges: 1,
                        hackRange: 3, // tiles
                        hackTime: 3000, // 3 seconds
                        targets: ['turret'],
                    },
                    upgradeCost: 0,
                    description: '1회, 터렛만',
                },
                {
                    level: 2,
                    effect: {
                        charges: 2,
                        hackRange: 4,
                        hackTime: 2500,
                        targets: ['turret', 'smallDrone'],
                    },
                    upgradeCost: 10,
                    description: '2회, 터렛/소형 드론',
                },
                {
                    level: 3,
                    effect: {
                        charges: 3,
                        hackRange: 5,
                        hackTime: 2000,
                        targets: ['turret', 'smallDrone', 'largeDrone'],
                    },
                    upgradeCost: 16,
                    description: '3회, 터렛/모든 드론',
                },
            ],
        },
    },

    // ==========================================
    // API Methods
    // ==========================================

    /**
     * Get equipment definition by ID
     */
    get(equipmentId) {
        return this.items[equipmentId] || null;
    },

    /**
     * Get all equipment
     */
    getAll() {
        return Object.values(this.items);
    },

    /**
     * Get all equipment IDs
     */
    getAllIds() {
        return Object.keys(this.items);
    },

    /**
     * Get upgrade cost for specific level
     */
    getUpgradeCost(equipmentId, level) {
        const item = this.items[equipmentId];
        if (!item) return null;

        const levelData = item.levels[level - 1];
        return levelData ? levelData.upgradeCost : null;
    },

    /**
     * Get effect at specific level
     */
    getEffect(equipmentId, level) {
        const item = this.items[equipmentId];
        if (!item) return null;

        const levelIndex = Math.min(level, item.levels.length) - 1;
        return item.levels[levelIndex]?.effect || null;
    },

    /**
     * Get equipment display name
     */
    getName(equipmentId, lang = 'ko') {
        const item = this.items[equipmentId];
        if (!item) return equipmentId;

        return lang === 'en' ? item.nameEn : item.name;
    },

    /**
     * Get equipment by type
     */
    getByType(type) {
        return Object.values(this.items).filter(item => item.type === type);
    },

    /**
     * Get recommended equipment for a class
     */
    getRecommendedForClass(classId) {
        return Object.values(this.items).filter(item =>
            item.recommendedClasses.length === 0 ||
            item.recommendedClasses.includes(classId)
        );
    },

    /**
     * Check if equipment has friendly fire
     */
    hasFriendlyFire(equipmentId) {
        const item = this.items[equipmentId];
        return item ? item.friendlyFire : false;
    },

    /**
     * Get max level for equipment
     */
    getMaxLevel(equipmentId) {
        const item = this.items[equipmentId];
        return item ? item.levels.length : 0;
    },

    /**
     * Calculate total cost to max level
     */
    getTotalCost(equipmentId) {
        const item = this.items[equipmentId];
        if (!item) return 0;

        let total = item.baseCost;
        for (const level of item.levels) {
            total += level.upgradeCost;
        }
        return total;
    },
};

// Make available globally
window.EquipmentData = EquipmentData;
