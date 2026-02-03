/**
 * THE FADING RAVEN - Crew Class Data
 * Defines all 5 crew classes with stats, skills, and properties
 */

const CrewData = {
    classes: {
        guardian: {
            id: 'guardian',
            name: '가디언',
            nameEn: 'Guardian',
            baseSquadSize: 8,
            weapon: '에너지 실드 + 블래스터',
            role: '올라운더, 대원거리',
            color: '#4a9eff',

            stats: {
                damage: 10,
                attackSpeed: 1000,
                moveSpeed: 80,
                attackRange: 60,
                defense: 0.9, // 90% ranged damage reduction with shield
            },

            skill: {
                id: 'shieldBash',
                name: '실드 배쉬',
                nameEn: 'Shield Bash',
                type: 'direction',
                baseCooldown: 10000,
                description: '지정 방향으로 돌진하여 적에게 피해를 주고 밀쳐냅니다.',
                levels: [
                    {
                        level: 1,
                        effect: {
                            distance: 3, // tiles
                            knockback: 1,
                            damage: 1.0,
                            stun: 0,
                        },
                        cost: 7,
                        description: '3타일 돌진, 넉백',
                    },
                    {
                        level: 2,
                        effect: {
                            distance: 5,
                            knockback: 1.5,
                            damage: 1.2,
                            stun: 0,
                        },
                        cost: 10,
                        description: '5타일 돌진, 넉백 강화',
                    },
                    {
                        level: 3,
                        effect: {
                            distance: -1, // unlimited
                            knockback: 2,
                            damage: 1.5,
                            stun: 2, // seconds
                        },
                        cost: 14,
                        description: '무제한 거리, 착지 스턴',
                    },
                ],
            },

            strengths: ['원거리 적 대응 (실드)', '기동성', '유연성'],
            weaknesses: ['짧은 리치', '대형 적 취약', '교전 중 실드 무효'],
        },

        sentinel: {
            id: 'sentinel',
            name: '센티넬',
            nameEn: 'Sentinel',
            baseSquadSize: 8,
            weapon: '에너지 랜스',
            role: '병목 방어, 대브루트',
            color: '#f6ad55',

            stats: {
                damage: 15,
                attackSpeed: 1200,
                moveSpeed: 70,
                attackRange: 80, // long reach
                defense: 0,
            },

            skill: {
                id: 'lanceCharge',
                name: '랜스 차지',
                nameEn: 'Lance Charge',
                type: 'direction',
                baseCooldown: 12000,
                description: '지정 방향으로 돌격하여 경로상 모든 적에게 고데미지를 줍니다.',
                levels: [
                    {
                        level: 1,
                        effect: {
                            distance: 3,
                            damage: 2.0,
                            bruteKill: false,
                            piercing: true,
                        },
                        cost: 7,
                        description: '3타일, 브루트 제외 즉사',
                    },
                    {
                        level: 2,
                        effect: {
                            distance: -1, // unlimited
                            damage: 2.5,
                            bruteKill: false,
                            piercing: true,
                        },
                        cost: 10,
                        description: '무제한 거리',
                    },
                    {
                        level: 3,
                        effect: {
                            distance: -1,
                            damage: 3.0,
                            bruteKill: true,
                            piercing: true,
                        },
                        cost: 14,
                        description: '브루트 포함 즉사',
                    },
                ],
            },

            strengths: ['긴 리치', '병목 최강', '브루트 카운터'],
            weaknesses: ['정지 공격', '근접 무력화', '원거리 취약', '측면 취약'],

            // Special mechanic: lance raise when enemies get too close
            specialMechanics: {
                lanceRaise: {
                    triggerRange: 30, // pixels
                    effect: 'disabled', // can't attack when enemies too close
                },
            },
        },

        ranger: {
            id: 'ranger',
            name: '레인저',
            nameEn: 'Ranger',
            baseSquadSize: 8,
            weapon: '레이저 라이플',
            role: '원거리 딜러, 침투 저지',
            color: '#68d391',

            stats: {
                damage: 8,
                attackSpeed: 800,
                moveSpeed: 75,
                attackRange: 200,
                defense: 0,
            },

            skill: {
                id: 'volleyFire',
                name: '볼리 파이어',
                nameEn: 'Volley Fire',
                type: 'position',
                baseCooldown: 8000,
                description: '지정 위치에 분대 전체가 일제 사격합니다.',
                levels: [
                    {
                        level: 1,
                        effect: {
                            aoeRadius: 1, // tile
                            shotsPerUnit: 1,
                            shieldPenetration: 0.3,
                            piercing: false,
                        },
                        cost: 7,
                        description: '1타일 타겟',
                    },
                    {
                        level: 2,
                        effect: {
                            aoeRadius: 1.5,
                            shotsPerUnit: 2,
                            shieldPenetration: 0.5,
                            piercing: false,
                        },
                        cost: 10,
                        description: '탄환 수 증가',
                    },
                    {
                        level: 3,
                        effect: {
                            aoeRadius: 2,
                            shotsPerUnit: 3,
                            shieldPenetration: 0.7,
                            piercing: true,
                        },
                        cost: 14,
                        description: '최대 탄환, 관통 효과',
                    },
                ],
            },

            strengths: ['원거리 공격', '침투 저지', '고지대 보너스'],
            weaknesses: ['실드 무효화', '이동 타겟 명중률 낮음', '근접 취약', '초기 정확도 낮음'],

            // Accuracy improves with rank
            accuracyByRank: {
                standard: 0.5,
                veteran: 0.75,
                elite: 0.95,
            },
        },

        engineer: {
            id: 'engineer',
            name: '엔지니어',
            nameEn: 'Engineer',
            baseSquadSize: 6, // smaller squad
            weapon: '권총 + 터렛',
            role: '지원, 설치, 시설 수리',
            color: '#fc8181',

            stats: {
                damage: 5,
                attackSpeed: 1500,
                moveSpeed: 65,
                attackRange: 80,
                defense: 0,
            },

            skill: {
                id: 'deployTurret',
                name: '터렛 배치',
                nameEn: 'Deploy Turret',
                type: 'position',
                baseCooldown: 15000,
                description: '지정 위치에 자동 공격 터렛을 설치합니다.',
                levels: [
                    {
                        level: 1,
                        effect: {
                            maxTurrets: 1,
                            turretDamage: 1.0,
                            turretHealth: 1.0,
                            turretRange: 150,
                            slow: false,
                        },
                        cost: 7,
                        description: '1개 터렛',
                    },
                    {
                        level: 2,
                        effect: {
                            maxTurrets: 2,
                            turretDamage: 1.5,
                            turretHealth: 1.5,
                            turretRange: 175,
                            slow: false,
                        },
                        cost: 10,
                        description: '2개 터렛, DPS +50%',
                    },
                    {
                        level: 3,
                        effect: {
                            maxTurrets: 3,
                            turretDamage: 2.0,
                            turretHealth: 2.0,
                            turretRange: 200,
                            slow: true, // slows enemies
                        },
                        cost: 14,
                        description: '3개 터렛, DPS +100%, 슬로우',
                    },
                ],
            },

            strengths: ['터렛 화력', '시설 수리', '병목 강화'],
            weaknesses: ['약한 전투력', '호위 필요', '터렛 제한', '해커 취약'],

            // Special: Repair ability
            repairAbility: {
                repairTime: 20000, // 20 seconds
                repairHealthPercent: 50,
                repairCreditPercent: 50,
            },
        },

        bionic: {
            id: 'bionic',
            name: '바이오닉',
            nameEn: 'Bionic',
            baseSquadSize: 5, // smallest squad
            weapon: '에너지 블레이드',
            role: '고기동, 암살',
            color: '#b794f4',

            stats: {
                damage: 12,
                attackSpeed: 600, // fast attacks
                moveSpeed: 120, // +50% base speed
                attackRange: 50,
                defense: 0,
            },

            skill: {
                id: 'blink',
                name: '블링크',
                nameEn: 'Blink',
                type: 'position',
                baseCooldown: 15000,
                description: '지정 위치로 순간이동합니다. 벽을 통과할 수 있습니다.',
                levels: [
                    {
                        level: 1,
                        effect: {
                            distance: 2, // tiles
                            cooldownReduction: 0,
                            stunOnLanding: false,
                            invulnerabilityTime: 200, // ms
                        },
                        cost: 7,
                        description: '2타일 순간이동',
                    },
                    {
                        level: 2,
                        effect: {
                            distance: 4,
                            cooldownReduction: 0.2,
                            stunOnLanding: false,
                            invulnerabilityTime: 300,
                        },
                        cost: 10,
                        description: '4타일, 쿨다운 -20%',
                    },
                    {
                        level: 3,
                        effect: {
                            distance: 6,
                            cooldownReduction: 0.33,
                            stunOnLanding: true, // stuns nearby enemies
                            stunRadius: 1, // tile
                            stunDuration: 1.5, // seconds
                            invulnerabilityTime: 500,
                        },
                        cost: 14,
                        description: '6타일, 착지 스턴',
                    },
                ],
            },

            strengths: ['고기동', '암살 보너스', '우선순위 처치'],
            weaknesses: ['적은 인원', '낮은 체력', '정면전 약함'],

            // Special: Assassination bonus
            assassinationBonus: {
                damageMultiplier: 2.0,
                condition: 'targetNotEngaged', // target must not be fighting another unit
            },
        },
    },

    // ==========================================
    // API Methods
    // ==========================================

    /**
     * Get class definition by ID
     */
    getClass(classId) {
        return this.classes[classId] || null;
    },

    /**
     * Get skill definition at specific level
     */
    getSkill(classId, level = 1) {
        const classData = this.classes[classId];
        if (!classData) return null;

        const skill = classData.skill;
        const levelData = skill.levels[Math.min(level, skill.levels.length) - 1];

        return {
            ...skill,
            currentLevel: level,
            ...levelData,
        };
    },

    /**
     * Get all class IDs
     */
    getAllClasses() {
        return Object.keys(this.classes);
    },

    /**
     * Get class color
     */
    getClassColor(classId) {
        const classData = this.classes[classId];
        return classData ? classData.color : '#ffffff';
    },

    /**
     * Get skill upgrade cost for next level
     */
    getSkillUpgradeCost(classId, currentLevel) {
        const classData = this.classes[classId];
        if (!classData || currentLevel >= 3) return null;

        return classData.skill.levels[currentLevel].cost;
    },

    /**
     * Get base stats for a class
     */
    getBaseStats(classId) {
        const classData = this.classes[classId];
        if (!classData) return null;

        return { ...classData.stats };
    },

    /**
     * Get class display name
     */
    getClassName(classId, lang = 'ko') {
        const classData = this.classes[classId];
        if (!classData) return classId;

        return lang === 'en' ? classData.nameEn : classData.name;
    },

    /**
     * Get recommended classes for countering specific enemies
     */
    getCounterClasses(enemyType) {
        // This will be filled in by EnemyData integration
        const counters = {
            rusher: ['guardian', 'sentinel', 'ranger'],
            gunner: ['guardian'],
            shieldTrooper: ['sentinel', 'bionic'],
            jumper: ['ranger', 'bionic'],
            heavyTrooper: ['guardian', 'sentinel'],
            hacker: ['bionic', 'ranger'],
            stormCreature: ['ranger'],
            brute: ['sentinel'],
            sniper: ['bionic'],
            droneCarrier: ['bionic', 'ranger'],
            shieldGenerator: ['bionic', 'guardian'],
        };

        return counters[enemyType] || [];
    },
};

// Make available globally
window.CrewData = CrewData;
