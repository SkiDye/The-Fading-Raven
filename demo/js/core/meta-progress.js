/**
 * THE FADING RAVEN - Meta Progression System
 * Handles permanent unlocks across runs
 */

const MetaProgress = {
    STORAGE_KEY: 'theFadingRaven_metaProgress',

    // Default progress state
    defaultState: {
        // Classes - guardian, sentinel, ranger are default unlocked
        unlockedClasses: ['guardian', 'sentinel', 'ranger'],

        // Equipment - shockWave, fragGrenade are default unlocked
        unlockedEquipment: ['shockWave', 'fragGrenade'],

        // Traits - all combat traits default unlocked
        unlockedTraits: ['sharpEdge', 'heavyImpact', 'titanFrame', 'reinforcedArmor', 'steadyStance', 'fearless'],

        // Starting options unlocked
        unlockedStartingTraits: [],
        unlockedStartingEquipment: [],

        // Difficulty levels
        highestDifficultyCleared: null, // null means none cleared
        unlockedDifficulties: ['normal'],

        // Achievements
        achievements: [],

        // Statistics
        stats: {
            totalRuns: 0,
            totalVictories: 0,
            totalDefeats: 0,
            totalCreditsEarned: 0,
            totalEnemiesKilled: 0,
            totalStationsDefended: 0,
            totalPerfectDefenses: 0,
            totalCrewsLost: 0,
            totalBossesKilled: 0,
            fastestVictoryTime: null, // in seconds
            highestScore: 0,
            longestWinStreak: 0,
            currentWinStreak: 0,
        },

        // Last run info for continuation
        lastRunSeed: null,
        lastRunDifficulty: null,
    },

    // Unlock conditions from GDD 12.2
    unlockConditions: {
        classes: {
            engineer: {
                type: 'firstClear',
                description: '첫 클리어',
            },
            bionic: {
                type: 'difficultyClear',
                difficulty: 'hard',
                description: 'Hard 난이도 클리어',
            },
        },
        equipment: {
            proximityMine: {
                type: 'kills',
                killCount: 100,
                description: '적 100명 처치',
            },
            rallyHorn: {
                type: 'stationsDefended',
                count: 20,
                description: '정거장 20개 방어',
            },
            reviveKit: {
                type: 'crewsLost',
                count: 10,
                description: '크루 10명 상실',
            },
            stimPack: {
                type: 'perfectDefenses',
                count: 5,
                description: '완벽 방어 5회',
            },
            salvageCore: {
                type: 'creditsEarned',
                credits: 500,
                description: '총 500 크레딧 획득',
            },
            shieldGenerator: {
                type: 'bossKill',
                count: 1,
                description: '보스 1회 처치',
            },
            hackingDevice: {
                type: 'engineerVictory',
                description: '엔지니어로 클리어',
            },
            commandModule: {
                type: 'rangerVictory',
                description: '레인저로 클리어',
            },
        },
        traits: {
            energetic: {
                type: 'skillUses',
                count: 50,
                description: '스킬 50회 사용',
            },
            swiftMovement: {
                type: 'stormEscapes',
                count: 3,
                description: '폭풍 회피 3회',
            },
            popular: {
                type: 'commandersRecruited',
                count: 10,
                description: '팀장 10명 영입',
            },
            quickRecovery: {
                type: 'heals',
                count: 20,
                description: '휴식 20회',
            },
            techSavvy: {
                type: 'turretKills',
                count: 30,
                description: '터렛으로 30명 처치',
            },
            skillful: {
                type: 'skillMaxed',
                count: 3,
                description: '스킬 3개 최대 레벨',
            },
            collector: {
                type: 'equipmentMaxed',
                count: 3,
                description: '장비 3개 최대 레벨',
            },
            heavyLoad: {
                type: 'consumablesUsed',
                count: 30,
                description: '소모품 30회 사용',
            },
            salvager: {
                type: 'hardClear',
                description: 'Hard 난이도 클리어',
            },
        },
        difficulties: {
            hard: {
                type: 'difficultyClear',
                difficulty: 'normal',
                description: 'Normal 클리어',
            },
            veryhard: {
                type: 'difficultyClear',
                difficulty: 'hard',
                description: 'Hard 클리어',
            },
            nightmare: {
                type: 'difficultyClear',
                difficulty: 'veryhard',
                description: 'Very Hard 클리어',
            },
        },
    },

    // Achievements from GDD 12.3
    achievementDefinitions: {
        firstEscape: {
            id: 'firstEscape',
            name: '첫 탈출',
            description: '캠페인을 처음으로 클리어',
            icon: '🏆',
            reward: { unlockClass: 'engineer' },
        },
        perfectionist: {
            id: 'perfectionist',
            name: '완벽주의자',
            description: '모든 시설 방어로 클리어',
            icon: '⭐',
            reward: { unlockEquipment: 'shieldGenerator' },
        },
        assassin: {
            id: 'assassin',
            name: '암살자',
            description: '바이오닉으로 보스 10회 처치',
            icon: '🗡️',
            reward: { unlockTrait: 'special_assassin' },
        },
        turretMaster: {
            id: 'turretMaster',
            name: '터렛 마스터',
            description: '터렛으로 100명 처치',
            icon: '🔫',
            reward: { cosmetic: 'turretSkin' },
        },
        speedRunner: {
            id: 'speedRunner',
            name: '스피드 러너',
            description: '30분 이내에 클리어',
            icon: '⏱️',
            reward: { startingBonus: 'extraCredits' },
        },
        survivor: {
            id: 'survivor',
            name: '생존자',
            description: '크루 손실 없이 클리어',
            icon: '💪',
            reward: { unlockTrait: 'special_survivor' },
        },
        stormChaser: {
            id: 'stormChaser',
            name: '폭풍 추적자',
            description: '폭풍 스테이지 10회 클리어',
            icon: '⚡',
            reward: { startingBonus: 'stormResist' },
        },
        economist: {
            id: 'economist',
            name: '경제학자',
            description: '한 런에서 200 크레딧 획득',
            icon: '💰',
            reward: { unlockEquipment: 'salvageCore' },
        },
        nightmare: {
            id: 'nightmare',
            name: '악몽의 지배자',
            description: 'Nightmare 난이도 클리어',
            icon: '👹',
            reward: { cosmetic: 'nightmareTitle' },
        },
        allClasses: {
            id: 'allClasses',
            name: '만능 지휘관',
            description: '모든 클래스로 클리어',
            icon: '🎖️',
            reward: { startingBonus: 'classChoice' },
        },
    },

    // Current state
    state: null,

    /**
     * Initialize meta progress
     */
    init() {
        this.load();
        console.log('MetaProgress initialized');
    },

    /**
     * Load progress from storage
     */
    load() {
        try {
            const saved = localStorage.getItem(this.STORAGE_KEY);
            if (saved) {
                const parsed = JSON.parse(saved);
                // Merge with defaults to handle new fields
                this.state = this._mergeWithDefaults(parsed);
            } else {
                this.state = { ...this.defaultState };
            }
        } catch (e) {
            console.error('Failed to load meta progress:', e);
            this.state = { ...this.defaultState };
        }
    },

    /**
     * Save progress to storage
     */
    save() {
        try {
            localStorage.setItem(this.STORAGE_KEY, JSON.stringify(this.state));
        } catch (e) {
            console.error('Failed to save meta progress:', e);
        }
    },

    /**
     * Merge saved state with defaults
     */
    _mergeWithDefaults(saved) {
        const merged = { ...this.defaultState };

        // Merge arrays by combining unique values
        if (saved.unlockedClasses) {
            merged.unlockedClasses = [...new Set([...merged.unlockedClasses, ...saved.unlockedClasses])];
        }
        if (saved.unlockedEquipment) {
            merged.unlockedEquipment = [...new Set([...merged.unlockedEquipment, ...saved.unlockedEquipment])];
        }
        if (saved.unlockedTraits) {
            merged.unlockedTraits = [...new Set([...merged.unlockedTraits, ...saved.unlockedTraits])];
        }
        if (saved.unlockedDifficulties) {
            merged.unlockedDifficulties = [...new Set([...merged.unlockedDifficulties, ...saved.unlockedDifficulties])];
        }
        if (saved.achievements) {
            merged.achievements = [...new Set([...merged.achievements, ...saved.achievements])];
        }

        // Merge simple values
        if (saved.highestDifficultyCleared) {
            merged.highestDifficultyCleared = saved.highestDifficultyCleared;
        }

        // Merge stats
        if (saved.stats) {
            merged.stats = { ...merged.stats, ...saved.stats };
        }

        // Other values
        merged.unlockedStartingTraits = saved.unlockedStartingTraits || [];
        merged.unlockedStartingEquipment = saved.unlockedStartingEquipment || [];
        merged.lastRunSeed = saved.lastRunSeed;
        merged.lastRunDifficulty = saved.lastRunDifficulty;

        return merged;
    },

    /**
     * Reset all progress
     */
    reset() {
        this.state = { ...this.defaultState };
        this.save();
    },

    // ==========================================
    // UNLOCK CHECKS
    // ==========================================

    /**
     * Check if a class is unlocked
     */
    isClassUnlocked(classId) {
        return this.state.unlockedClasses.includes(classId);
    },

    /**
     * Check if equipment is unlocked
     */
    isEquipmentUnlocked(equipmentId) {
        return this.state.unlockedEquipment.includes(equipmentId);
    },

    /**
     * Check if trait is unlocked
     */
    isTraitUnlocked(traitId) {
        return this.state.unlockedTraits.includes(traitId);
    },

    /**
     * Check if difficulty is unlocked
     */
    isDifficultyUnlocked(difficulty) {
        return this.state.unlockedDifficulties.includes(difficulty);
    },

    /**
     * Check if achievement is earned
     */
    hasAchievement(achievementId) {
        return this.state.achievements.includes(achievementId);
    },

    // ==========================================
    // UNLOCK METHODS
    // ==========================================

    /**
     * Unlock a class
     */
    unlockClass(classId) {
        if (!this.state.unlockedClasses.includes(classId)) {
            this.state.unlockedClasses.push(classId);
            this.save();
            return true;
        }
        return false;
    },

    /**
     * Unlock equipment
     */
    unlockEquipment(equipmentId) {
        if (!this.state.unlockedEquipment.includes(equipmentId)) {
            this.state.unlockedEquipment.push(equipmentId);
            this.save();
            return true;
        }
        return false;
    },

    /**
     * Unlock trait
     */
    unlockTrait(traitId) {
        if (!this.state.unlockedTraits.includes(traitId)) {
            this.state.unlockedTraits.push(traitId);
            this.save();
            return true;
        }
        return false;
    },

    /**
     * Unlock difficulty
     */
    unlockDifficulty(difficulty) {
        if (!this.state.unlockedDifficulties.includes(difficulty)) {
            this.state.unlockedDifficulties.push(difficulty);
            this.save();
            return true;
        }
        return false;
    },

    /**
     * Award achievement
     */
    awardAchievement(achievementId) {
        if (!this.state.achievements.includes(achievementId)) {
            this.state.achievements.push(achievementId);

            // Process reward
            const achievement = this.achievementDefinitions[achievementId];
            if (achievement && achievement.reward) {
                this._processReward(achievement.reward);
            }

            this.save();
            return achievement;
        }
        return null;
    },

    /**
     * Process achievement reward
     */
    _processReward(reward) {
        if (reward.unlockClass) {
            this.unlockClass(reward.unlockClass);
        }
        if (reward.unlockEquipment) {
            this.unlockEquipment(reward.unlockEquipment);
        }
        if (reward.unlockTrait) {
            this.unlockTrait(reward.unlockTrait);
        }
    },

    // ==========================================
    // RUN COMPLETION
    // ==========================================

    /**
     * Process run completion (victory or defeat)
     * @param {Object} runData - Data from the completed run
     */
    processRunCompletion(runData) {
        const newUnlocks = [];
        const newAchievements = [];

        // Update stats
        this.state.stats.totalRuns++;

        if (runData.isVictory) {
            this.state.stats.totalVictories++;
            this.state.stats.currentWinStreak++;

            if (this.state.stats.currentWinStreak > this.state.stats.longestWinStreak) {
                this.state.stats.longestWinStreak = this.state.stats.currentWinStreak;
            }

            // Update highest difficulty cleared
            const difficultyOrder = ['normal', 'hard', 'veryhard', 'nightmare'];
            const currentIdx = difficultyOrder.indexOf(runData.difficulty);
            const highestIdx = this.state.highestDifficultyCleared
                ? difficultyOrder.indexOf(this.state.highestDifficultyCleared)
                : -1;

            if (currentIdx > highestIdx) {
                this.state.highestDifficultyCleared = runData.difficulty;

                // Unlock next difficulty
                if (currentIdx < difficultyOrder.length - 1) {
                    const nextDifficulty = difficultyOrder[currentIdx + 1];
                    if (this.unlockDifficulty(nextDifficulty)) {
                        newUnlocks.push({ type: 'difficulty', id: nextDifficulty });
                    }
                }
            }

            // Check for first clear unlock (engineer)
            if (this.state.stats.totalVictories === 1) {
                if (this.unlockClass('engineer')) {
                    newUnlocks.push({ type: 'class', id: 'engineer' });
                }
                const achievement = this.awardAchievement('firstEscape');
                if (achievement) newAchievements.push(achievement);
            }

            // Check for hard clear unlock (bionic)
            if (runData.difficulty === 'hard' || difficultyOrder.indexOf(runData.difficulty) > difficultyOrder.indexOf('hard')) {
                if (this.unlockClass('bionic')) {
                    newUnlocks.push({ type: 'class', id: 'bionic' });
                }
            }

            // Check for speed run
            if (runData.duration && runData.duration < 30 * 60) { // 30 minutes
                const achievement = this.awardAchievement('speedRunner');
                if (achievement) newAchievements.push(achievement);

                if (!this.state.stats.fastestVictoryTime || runData.duration < this.state.stats.fastestVictoryTime) {
                    this.state.stats.fastestVictoryTime = runData.duration;
                }
            }

            // Check for no crew loss
            if (runData.stats && runData.stats.crewsLost === 0) {
                const achievement = this.awardAchievement('survivor');
                if (achievement) newAchievements.push(achievement);
            }

            // Check for perfectionist (all facilities defended)
            if (runData.stats && runData.stats.stationsLost === 0) {
                const achievement = this.awardAchievement('perfectionist');
                if (achievement) newAchievements.push(achievement);
            }

            // Check for nightmare clear
            if (runData.difficulty === 'nightmare') {
                const achievement = this.awardAchievement('nightmare');
                if (achievement) newAchievements.push(achievement);
            }

        } else {
            this.state.stats.totalDefeats++;
            this.state.stats.currentWinStreak = 0;
        }

        // Update cumulative stats
        if (runData.stats) {
            this.state.stats.totalCreditsEarned += runData.stats.creditsEarned || 0;
            this.state.stats.totalEnemiesKilled += runData.stats.enemiesKilled || 0;
            this.state.stats.totalStationsDefended += runData.stats.stationsDefended || 0;
            this.state.stats.totalPerfectDefenses += runData.stats.perfectDefenses || 0;
            this.state.stats.totalCrewsLost += runData.stats.crewsLost || 0;

            // Check score
            if (runData.score && runData.score > this.state.stats.highestScore) {
                this.state.stats.highestScore = runData.score;
            }
        }

        // Check condition-based unlocks
        this._checkConditionUnlocks(newUnlocks);

        // Check economist achievement
        if (runData.stats && runData.stats.creditsEarned >= 200) {
            const achievement = this.awardAchievement('economist');
            if (achievement) newAchievements.push(achievement);
        }

        this.save();

        return {
            newUnlocks,
            newAchievements,
        };
    },

    /**
     * Check condition-based unlocks
     */
    _checkConditionUnlocks(newUnlocks) {
        // Check equipment unlocks
        for (const [equipId, condition] of Object.entries(this.unlockConditions.equipment)) {
            if (this.isEquipmentUnlocked(equipId)) continue;

            let unlocked = false;

            switch (condition.type) {
                case 'kills':
                    unlocked = this.state.stats.totalEnemiesKilled >= condition.killCount;
                    break;
                case 'stationsDefended':
                    unlocked = this.state.stats.totalStationsDefended >= condition.count;
                    break;
                case 'crewsLost':
                    unlocked = this.state.stats.totalCrewsLost >= condition.count;
                    break;
                case 'perfectDefenses':
                    unlocked = this.state.stats.totalPerfectDefenses >= condition.count;
                    break;
                case 'creditsEarned':
                    unlocked = this.state.stats.totalCreditsEarned >= condition.credits;
                    break;
            }

            if (unlocked) {
                this.unlockEquipment(equipId);
                newUnlocks.push({ type: 'equipment', id: equipId });
            }
        }
    },

    // ==========================================
    // GETTERS
    // ==========================================

    /**
     * Get all unlocked classes
     */
    getUnlockedClasses() {
        return [...this.state.unlockedClasses];
    },

    /**
     * Get all unlocked equipment
     */
    getUnlockedEquipment() {
        return [...this.state.unlockedEquipment];
    },

    /**
     * Get all unlocked traits
     */
    getUnlockedTraits() {
        return [...this.state.unlockedTraits];
    },

    /**
     * Get all unlocked difficulties
     */
    getUnlockedDifficulties() {
        return [...this.state.unlockedDifficulties];
    },

    /**
     * Get all achievements
     */
    getAchievements() {
        return this.state.achievements.map(id => ({
            ...this.achievementDefinitions[id],
            earned: true,
        }));
    },

    /**
     * Get all available achievements with status
     */
    getAllAchievements() {
        return Object.values(this.achievementDefinitions).map(def => ({
            ...def,
            earned: this.state.achievements.includes(def.id),
        }));
    },

    /**
     * Get stats
     */
    getStats() {
        return { ...this.state.stats };
    },

    /**
     * Get unlock progress for a specific item
     */
    getUnlockProgress(type, id) {
        const conditions = this.unlockConditions[type];
        if (!conditions || !conditions[id]) return null;

        const condition = conditions[id];
        let current = 0;
        let target = 0;

        switch (condition.type) {
            case 'kills':
                current = this.state.stats.totalEnemiesKilled;
                target = condition.killCount;
                break;
            case 'stationsDefended':
                current = this.state.stats.totalStationsDefended;
                target = condition.count;
                break;
            case 'crewsLost':
                current = this.state.stats.totalCrewsLost;
                target = condition.count;
                break;
            case 'perfectDefenses':
                current = this.state.stats.totalPerfectDefenses;
                target = condition.count;
                break;
            case 'creditsEarned':
                current = this.state.stats.totalCreditsEarned;
                target = condition.credits;
                break;
            case 'firstClear':
                current = this.state.stats.totalVictories;
                target = 1;
                break;
            case 'difficultyClear':
                const cleared = this.state.unlockedDifficulties.includes(condition.difficulty);
                current = cleared ? 1 : 0;
                target = 1;
                break;
            default:
                return null;
        }

        return {
            current,
            target,
            percentage: Math.min(100, Math.floor((current / target) * 100)),
            description: condition.description,
        };
    },

    /**
     * Get available trait pool for a campaign
     * Returns subset of unlocked traits based on GDD rules
     */
    getCampaignTraitPool(rng, count = 10) {
        const unlocked = this.getUnlockedTraits();
        if (unlocked.length <= count) {
            return [...unlocked];
        }

        // Randomly select subset
        const shuffled = rng.shuffle([...unlocked]);
        return shuffled.slice(0, count);
    },

    /**
     * Record last run for seed replay
     */
    recordLastRun(seed, difficulty) {
        this.state.lastRunSeed = seed;
        this.state.lastRunDifficulty = difficulty;
        this.save();
    },

    /**
     * Get last run info
     */
    getLastRun() {
        if (!this.state.lastRunSeed) return null;

        return {
            seed: this.state.lastRunSeed,
            difficulty: this.state.lastRunDifficulty,
        };
    },
};

// Initialize on load
document.addEventListener('DOMContentLoaded', () => {
    MetaProgress.init();
});

// Make available globally
window.MetaProgress = MetaProgress;
