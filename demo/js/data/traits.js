/**
 * THE FADING RAVEN - Traits Data
 * Defines all 15 traits with effects and synergies
 */

const TraitData = {
    traits: {
        // ==========================================
        // Combat Traits (6)
        // ==========================================

        sharpEdge: {
            id: 'sharpEdge',
            name: '날카로운 공격',
            nameEn: 'Sharp Edge',
            category: 'combat',
            desc: '데미지 +20%, 넉백 -30%',
            effect: {
                type: 'damageModifier',
                damageMultiplier: 1.2,
                knockbackMultiplier: 0.7,
            },
            recommendedClasses: ['sentinel', 'bionic'],
            icon: '🗡️',
        },

        heavyImpact: {
            id: 'heavyImpact',
            name: '강력한 충격',
            nameEn: 'Heavy Impact',
            category: 'combat',
            desc: '넉백 +50%, 스턴 지속시간 +50%',
            effect: {
                type: 'knockbackModifier',
                knockbackMultiplier: 1.5,
                stunDurationMultiplier: 1.5,
            },
            recommendedClasses: ['guardian', 'ranger'],
            icon: '💥',
        },

        titanFrame: {
            id: 'titanFrame',
            name: '타이탄 프레임',
            nameEn: 'Titan Frame',
            category: 'combat',
            desc: '팀장 체력 3배, 크기 증가',
            effect: {
                type: 'leaderBuff',
                leaderHealthMultiplier: 3,
                leaderSizeMultiplier: 1.5,
                leaderVisible: true, // makes leader visually distinct
            },
            recommendedClasses: ['guardian'],
            icon: '🛡️',
        },

        reinforcedArmor: {
            id: 'reinforcedArmor',
            name: '강화 장갑',
            nameEn: 'Reinforced Armor',
            category: 'combat',
            desc: '받는 데미지 -25%',
            effect: {
                type: 'defenseModifier',
                damageReduction: 0.25,
            },
            recommendedClasses: ['guardian', 'sentinel'],
            icon: '🔰',
        },

        steadyStance: {
            id: 'steadyStance',
            name: '안정된 자세',
            nameEn: 'Steady Stance',
            category: 'combat',
            desc: '넉백/스턴 저항',
            effect: {
                type: 'statusResist',
                knockbackResist: 0.8, // 80% knockback reduction
                stunResist: 0.8,
            },
            recommendedClasses: ['guardian', 'sentinel'],
            icon: '🦶',
        },

        fearless: {
            id: 'fearless',
            name: '두려움 없음',
            nameEn: 'Fearless',
            category: 'combat',
            desc: '절대 후퇴하지 않음 (위험)',
            effect: {
                type: 'behavior',
                cannotRetreat: true,
                moraleBonus: 1.5, // no morale penalty
            },
            recommendedClasses: [], // risky for all
            icon: '😤',
            warning: '철수 불가능!',
        },

        // ==========================================
        // Utility Traits (5)
        // ==========================================

        energetic: {
            id: 'energetic',
            name: '활력 넘침',
            nameEn: 'Energetic',
            category: 'utility',
            desc: '스킬 쿨다운 -33%',
            effect: {
                type: 'cooldownModifier',
                skillCooldownMultiplier: 0.67,
            },
            recommendedClasses: ['bionic', 'engineer'],
            icon: '⚡',
        },

        swiftMovement: {
            id: 'swiftMovement',
            name: '빠른 이동',
            nameEn: 'Swift Movement',
            category: 'utility',
            desc: '이동속도 +33%',
            effect: {
                type: 'movementModifier',
                moveSpeedMultiplier: 1.33,
            },
            recommendedClasses: ['bionic', 'ranger'],
            icon: '💨',
        },

        popular: {
            id: 'popular',
            name: '인기 많음',
            nameEn: 'Popular',
            category: 'utility',
            desc: '분대 크기 +1',
            effect: {
                type: 'squadModifier',
                squadSizeBonus: 1,
            },
            recommendedClasses: ['ranger'],
            icon: '👥',
        },

        quickRecovery: {
            id: 'quickRecovery',
            name: '빠른 회복',
            nameEn: 'Quick Recovery',
            category: 'utility',
            desc: '회복 시간 -33%',
            effect: {
                type: 'recoveryModifier',
                recoveryTimeMultiplier: 0.67,
            },
            recommendedClasses: ['guardian', 'sentinel'],
            icon: '💚',
        },

        techSavvy: {
            id: 'techSavvy',
            name: '기술 숙련',
            nameEn: 'Tech Savvy',
            category: 'utility',
            desc: '터렛 성능 +50%',
            effect: {
                type: 'turretModifier',
                turretDamageMultiplier: 1.5,
                turretHealthMultiplier: 1.5,
                turretRangeMultiplier: 1.2,
            },
            recommendedClasses: ['engineer'],
            icon: '🔧',
        },

        // ==========================================
        // Economy Traits (4)
        // ==========================================

        skillful: {
            id: 'skillful',
            name: '숙련됨',
            nameEn: 'Skillful',
            category: 'economy',
            desc: '스킬 업그레이드 비용 -50%',
            effect: {
                type: 'costModifier',
                skillUpgradeCostMultiplier: 0.5,
            },
            recommendedClasses: [], // good for any
            icon: '📚',
        },

        collector: {
            id: 'collector',
            name: '수집가',
            nameEn: 'Collector',
            category: 'economy',
            desc: '장비 업그레이드 비용 -50%',
            effect: {
                type: 'costModifier',
                equipmentUpgradeCostMultiplier: 0.5,
            },
            recommendedClasses: [],
            icon: '🎒',
        },

        heavyLoad: {
            id: 'heavyLoad',
            name: '무거운 짐',
            nameEn: 'Heavy Load',
            category: 'economy',
            desc: '소모품 사용 횟수 +1',
            effect: {
                type: 'chargeModifier',
                bonusCharges: 1,
            },
            recommendedClasses: ['engineer', 'ranger'],
            icon: '📦',
        },

        salvager: {
            id: 'salvager',
            name: '약탈자',
            nameEn: 'Salvager',
            category: 'economy',
            desc: '적 처치 시 소량 크레딧',
            effect: {
                type: 'creditModifier',
                creditPerKill: 0.1, // 0.1 credit per kill (rounds up at end)
            },
            recommendedClasses: ['ranger', 'bionic'],
            icon: '💰',
        },
    },

    // Traits that conflict with each other
    conflictRules: {
        fearless: ['steadyStance'], // fearless already has no retreat
        titanFrame: ['swiftMovement'], // big and slow
    },

    // ==========================================
    // API Methods
    // ==========================================

    /**
     * Get trait definition by ID
     */
    get(traitId) {
        return this.traits[traitId] || null;
    },

    /**
     * Get all traits
     */
    getAll() {
        return Object.values(this.traits);
    },

    /**
     * Get all trait IDs
     */
    getAllIds() {
        return Object.keys(this.traits);
    },

    /**
     * Get traits by category
     */
    getByCategory(category) {
        return Object.values(this.traits).filter(t => t.category === category);
    },

    /**
     * Get effect values for a trait
     */
    getEffect(traitId) {
        const trait = this.traits[traitId];
        return trait ? trait.effect : null;
    },

    /**
     * Get trait display name
     */
    getName(traitId, lang = 'ko') {
        const trait = this.traits[traitId];
        if (!trait) return traitId;

        return lang === 'en' ? trait.nameEn : trait.name;
    },

    /**
     * Get random trait using RNG
     */
    getRandomTrait(rng, excludeList = []) {
        const available = Object.keys(this.traits).filter(id => !excludeList.includes(id));

        if (available.length === 0) return null;

        const index = rng ? rng.range(0, available.length - 1) : Math.floor(Math.random() * available.length);
        return available[index];
    },

    /**
     * Get random trait weighted by category
     */
    getRandomTraitWeighted(rng, weights = { combat: 40, utility: 35, economy: 25 }, excludeList = []) {
        // Get available traits by category
        const available = {
            combat: this.getByCategory('combat').filter(t => !excludeList.includes(t.id)),
            utility: this.getByCategory('utility').filter(t => !excludeList.includes(t.id)),
            economy: this.getByCategory('economy').filter(t => !excludeList.includes(t.id)),
        };

        // Build weighted pool
        const pool = [];
        for (const [category, traits] of Object.entries(available)) {
            const weight = weights[category] || 25;
            traits.forEach(trait => {
                for (let i = 0; i < weight; i++) {
                    pool.push(trait.id);
                }
            });
        }

        if (pool.length === 0) return null;

        const index = rng ? rng.range(0, pool.length - 1) : Math.floor(Math.random() * pool.length);
        return pool[index];
    },

    /**
     * Check if two traits conflict
     */
    traitsConflict(traitId1, traitId2) {
        const conflicts1 = this.conflictRules[traitId1] || [];
        const conflicts2 = this.conflictRules[traitId2] || [];

        return conflicts1.includes(traitId2) || conflicts2.includes(traitId1);
    },

    /**
     * Get recommended traits for a class
     */
    getRecommendedForClass(classId) {
        return Object.values(this.traits).filter(t =>
            t.recommendedClasses.includes(classId)
        );
    },

    /**
     * Apply trait effects to stats
     */
    applyTraitEffects(baseStats, traitId) {
        const effect = this.getEffect(traitId);
        if (!effect) return baseStats;

        const stats = { ...baseStats };

        switch (effect.type) {
            case 'damageModifier':
                if (stats.damage) stats.damage *= effect.damageMultiplier || 1;
                break;

            case 'knockbackModifier':
                if (stats.knockback) stats.knockback *= effect.knockbackMultiplier || 1;
                break;

            case 'defenseModifier':
                stats.damageReduction = (stats.damageReduction || 0) + (effect.damageReduction || 0);
                break;

            case 'movementModifier':
                if (stats.moveSpeed) stats.moveSpeed *= effect.moveSpeedMultiplier || 1;
                break;

            case 'cooldownModifier':
                if (stats.skillCooldown) stats.skillCooldown *= effect.skillCooldownMultiplier || 1;
                break;

            case 'squadModifier':
                if (stats.squadSize) stats.squadSize += effect.squadSizeBonus || 0;
                break;

            case 'recoveryModifier':
                if (stats.recoveryTime) stats.recoveryTime *= effect.recoveryTimeMultiplier || 1;
                break;
        }

        return stats;
    },

    /**
     * Get trait icon
     */
    getIcon(traitId) {
        const trait = this.traits[traitId];
        return trait ? trait.icon : '?';
    },

    /**
     * Check if trait has warning
     */
    hasWarning(traitId) {
        const trait = this.traits[traitId];
        return trait && trait.warning;
    },

    /**
     * Get trait warning text
     */
    getWarning(traitId) {
        const trait = this.traits[traitId];
        return trait ? trait.warning : null;
    },
};

// Make available globally
window.TraitData = TraitData;
