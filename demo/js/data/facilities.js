/**
 * THE FADING RAVEN - Facilities Data
 * Defines all 5 facility module types with effects and credit values
 */

const FacilityData = {
    facilities: {
        // ==========================================
        // Residential Module (with size variants)
        // ==========================================

        residentialSmall: {
            id: 'residentialSmall',
            name: '소형 거주 모듈',
            nameEn: 'Small Residential Module',
            desc: '소규모 거주 시설',
            category: 'residential',
            size: 'small',

            credits: 2, // 1 → 2 (H-001 경제 밸런스 조정)
            tiles: 1, // 1x1

            effect: null, // no special effect

            visual: {
                color: '#4a5568',
                icon: '🏠',
            },

            spawnWeight: 30,
            destructionTime: 5000, // 5 seconds to destroy
        },

        residentialMedium: {
            id: 'residentialMedium',
            name: '중형 거주 모듈',
            nameEn: 'Medium Residential Module',
            desc: '중규모 거주 시설',
            category: 'residential',
            size: 'medium',

            credits: 3, // 2 → 3 (H-001 경제 밸런스 조정)
            tiles: 2, // 1x2 or 2x1

            effect: null,

            visual: {
                color: '#4a5568',
                icon: '🏢',
            },

            spawnWeight: 25,
            destructionTime: 6000,
        },

        residentialLarge: {
            id: 'residentialLarge',
            name: '대형 거주 모듈',
            nameEn: 'Large Residential Module',
            desc: '대규모 거주 시설',
            category: 'residential',
            size: 'large',

            credits: 5, // 3 → 5 (H-001 경제 밸런스 조정)
            tiles: 4, // 2x2

            effect: null,

            visual: {
                color: '#4a5568',
                icon: '🏛️',
            },

            spawnWeight: 15,
            destructionTime: 8000,
        },

        // ==========================================
        // Special Facilities
        // ==========================================

        medical: {
            id: 'medical',
            name: '의료 모듈',
            nameEn: 'Medical Module',
            desc: '회복 시간 -50%',
            category: 'support',
            size: 'medium',

            credits: 2,
            tiles: 2,

            effect: {
                type: 'recoveryBonus',
                scope: 'stage',
                value: {
                    recoveryTimeMultiplier: 0.5,
                },
                description: '해당 스테이지에서 회복 시간 50% 감소',
            },

            visual: {
                color: '#fc8181',
                icon: '🏥',
            },

            spawnWeight: 15,
            destructionTime: 6000,
        },

        armory: {
            id: 'armory',
            name: '무기고',
            nameEn: 'Armory',
            desc: '해당 스테이지 데미지 +20%',
            category: 'combat',
            size: 'medium',

            credits: 2,
            tiles: 2,

            effect: {
                type: 'damageBonus',
                scope: 'stage',
                value: {
                    damageMultiplier: 1.2,
                },
                description: '해당 스테이지에서 모든 아군 데미지 20% 증가',
            },

            visual: {
                color: '#f6ad55',
                icon: '🔫',
            },

            spawnWeight: 15,
            destructionTime: 6000,
        },

        commTower: {
            id: 'commTower',
            name: '통신탑',
            nameEn: 'Communication Tower',
            desc: 'Raven 드론 능력 +1회',
            category: 'support',
            size: 'small',

            credits: 1,
            tiles: 1,

            effect: {
                type: 'ravenBonus',
                scope: 'stage',
                value: {
                    flareBonus: 1,
                    resupplyBonus: 1,
                    orbitalStrikeBonus: 0, // need 2+ towers
                },
                stackable: true, // multiple towers stack
                description: 'Raven 드론 능력 사용 횟수 +1',
            },

            // Special: 2+ towers give orbital strike bonus
            stackBonus: {
                threshold: 2,
                bonus: {
                    orbitalStrikeBonus: 1,
                },
            },

            visual: {
                color: '#4a9eff',
                icon: '📡',
            },

            spawnWeight: 15,
            destructionTime: 5000,
        },

        powerPlant: {
            id: 'powerPlant',
            name: '발전소',
            nameEn: 'Power Plant',
            desc: '터렛 성능 +50%',
            category: 'support',
            size: 'large',

            credits: 3,
            tiles: 4,

            effect: {
                type: 'turretBonus',
                scope: 'stage',
                value: {
                    turretDamageMultiplier: 1.5,
                    turretHealthMultiplier: 1.5,
                    turretRangeMultiplier: 1.25,
                },
                description: '해당 스테이지에서 모든 터렛 성능 50% 증가',
            },

            visual: {
                color: '#68d391',
                icon: '⚡',
            },

            spawnWeight: 10,
            destructionTime: 8000,
        },
    },

    // Destruction mechanics
    destruction: {
        explosiveSetupTime: 5000, // time to plant explosive
        warningTime: 2000, // warning before explosion
        explosionRadius: 1, // tiles affected by explosion
    },

    // Repair mechanics (for Engineer)
    repair: {
        repairTime: 20000, // 20 seconds
        healthRestored: 0.5, // 50% health
        creditsRestored: 0.5, // 50% of original credits
    },

    // ==========================================
    // API Methods
    // ==========================================

    /**
     * Get facility definition by ID
     */
    get(facilityId) {
        return this.facilities[facilityId] || null;
    },

    /**
     * Get all facilities
     */
    getAll() {
        return Object.values(this.facilities);
    },

    /**
     * Get all facility IDs
     */
    getAllIds() {
        return Object.keys(this.facilities);
    },

    /**
     * Get credit value
     */
    getCredits(facilityId) {
        const facility = this.facilities[facilityId];
        return facility ? facility.credits : 0;
    },

    /**
     * Get facility effect
     */
    getEffect(facilityId) {
        const facility = this.facilities[facilityId];
        return facility ? facility.effect : null;
    },

    /**
     * Get facility display name
     */
    getName(facilityId, lang = 'ko') {
        const facility = this.facilities[facilityId];
        if (!facility) return facilityId;

        return lang === 'en' ? facility.nameEn : facility.name;
    },

    /**
     * Get facilities by category
     */
    getByCategory(category) {
        return Object.values(this.facilities).filter(f => f.category === category);
    },

    /**
     * Get facilities by size
     */
    getBySize(size) {
        return Object.values(this.facilities).filter(f => f.size === size);
    },

    /**
     * Get residential facilities
     */
    getResidential() {
        return this.getByCategory('residential');
    },

    /**
     * Get special facilities (non-residential)
     */
    getSpecial() {
        return Object.values(this.facilities).filter(f => f.category !== 'residential');
    },

    /**
     * Get random facility based on spawn weights
     */
    getRandomFacility(rng, excludeIds = []) {
        const available = Object.values(this.facilities).filter(f =>
            !excludeIds.includes(f.id)
        );

        if (available.length === 0) return null;

        // Build weighted pool
        const pool = [];
        for (const facility of available) {
            for (let i = 0; i < facility.spawnWeight; i++) {
                pool.push(facility.id);
            }
        }

        const index = rng ? rng.range(0, pool.length - 1) : Math.floor(Math.random() * pool.length);
        return this.facilities[pool[index]];
    },

    /**
     * Get total credits from facility list
     */
    calculateTotalCredits(facilityIds) {
        return facilityIds.reduce((total, id) => total + this.getCredits(id), 0);
    },

    /**
     * Get combined effects from defended facilities
     */
    getCombinedEffects(defendedFacilityIds) {
        const effects = {
            recoveryTimeMultiplier: 1,
            damageMultiplier: 1,
            turretDamageMultiplier: 1,
            turretHealthMultiplier: 1,
            turretRangeMultiplier: 1,
            flareBonus: 0,
            resupplyBonus: 0,
            orbitalStrikeBonus: 0,
        };

        // Track comm towers for stack bonus
        let commTowerCount = 0;

        for (const facilityId of defendedFacilityIds) {
            const facility = this.facilities[facilityId];
            if (!facility || !facility.effect) continue;

            const value = facility.effect.value;

            switch (facility.effect.type) {
                case 'recoveryBonus':
                    effects.recoveryTimeMultiplier *= value.recoveryTimeMultiplier || 1;
                    break;

                case 'damageBonus':
                    effects.damageMultiplier *= value.damageMultiplier || 1;
                    break;

                case 'turretBonus':
                    effects.turretDamageMultiplier *= value.turretDamageMultiplier || 1;
                    effects.turretHealthMultiplier *= value.turretHealthMultiplier || 1;
                    effects.turretRangeMultiplier *= value.turretRangeMultiplier || 1;
                    break;

                case 'ravenBonus':
                    effects.flareBonus += value.flareBonus || 0;
                    effects.resupplyBonus += value.resupplyBonus || 0;
                    commTowerCount++;
                    break;
            }
        }

        // Apply comm tower stack bonus
        if (commTowerCount >= 2) {
            const commTower = this.facilities.commTower;
            if (commTower.stackBonus) {
                effects.orbitalStrikeBonus += commTower.stackBonus.bonus.orbitalStrikeBonus || 0;
            }
        }

        return effects;
    },

    /**
     * Get destruction time for facility
     */
    getDestructionTime(facilityId) {
        const facility = this.facilities[facilityId];
        return facility ? facility.destructionTime : this.destruction.explosiveSetupTime;
    },

    /**
     * Get repair result
     */
    getRepairResult(facilityId) {
        const facility = this.facilities[facilityId];
        if (!facility) return null;

        return {
            time: this.repair.repairTime,
            healthRestored: this.repair.healthRestored,
            creditsRestored: Math.floor(facility.credits * this.repair.creditsRestored),
        };
    },

    /**
     * Get visual properties
     */
    getVisual(facilityId) {
        const facility = this.facilities[facilityId];
        return facility ? facility.visual : { color: '#666666', icon: '?' };
    },

    /**
     * Get tile count for facility
     */
    getTileCount(facilityId) {
        const facility = this.facilities[facilityId];
        return facility ? facility.tiles : 1;
    },
};

// Make available globally
window.FacilityData = FacilityData;
