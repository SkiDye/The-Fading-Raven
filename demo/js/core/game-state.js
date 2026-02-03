/**
 * THE FADING RAVEN - Game State Manager
 * Manages game state persistence across pages using localStorage
 * Extended to integrate with data modules
 */

const GameState = {
    STORAGE_KEY: 'theFadingRaven_gameState',
    SETTINGS_KEY: 'theFadingRaven_settings',
    PROGRESS_KEY: 'theFadingRaven_progress',
    TAB_KEY: 'theFadingRaven_activeTab',

    // Multi-tab tracking (L-007)
    tabId: null,
    isActiveTab: true,

    // Default settings
    defaultSettings: {
        difficulty: 'normal',
        gameSpeed: 1,
        soundVolume: 70,
        musicVolume: 50,
        showTutorial: true,
        screenShake: true,
        language: 'ko',
    },

    // Default progress (meta progression)
    defaultProgress: {
        highestDifficulty: 'normal',
        normalCleared: false,
        hardCleared: false,
        veryhardCleared: false,
        totalRuns: 0,
        totalVictories: 0,
        totalEnemiesKilled: 0,
        totalStationsDefended: 0,
        unlockedClasses: ['guardian', 'sentinel', 'ranger'],
        unlockedEquipment: ['shockWave', 'fragGrenade'],
        unlockedTraits: [], // All traits available by default, this tracks "seen"
        achievements: [],
    },

    // Current run state
    currentRun: null,

    /**
     * Initialize game state
     */
    init() {
        this.loadSettings();
        this.loadProgress();
        this.loadCurrentRun();
        this.initMultiTabDetection();
        console.log('GameState initialized');
    },

    // ==========================================
    // MULTI-TAB DETECTION (L-007)
    // ==========================================

    /**
     * Initialize multi-tab conflict detection
     */
    initMultiTabDetection() {
        // Generate unique tab ID
        this.tabId = Date.now().toString(36) + Math.random().toString(36).substr(2);

        // Register this tab
        this.registerTab();

        // Listen for storage changes from other tabs
        window.addEventListener('storage', (event) => {
            this.handleStorageChange(event);
        });

        // Register on visibility change (tab becomes active)
        document.addEventListener('visibilitychange', () => {
            if (document.visibilityState === 'visible') {
                this.registerTab();
            }
        });

        // Cleanup on page unload
        window.addEventListener('beforeunload', () => {
            this.unregisterTab();
        });
    },

    /**
     * Register this tab as active
     */
    registerTab() {
        try {
            const existingTab = localStorage.getItem(this.TAB_KEY);

            if (existingTab && existingTab !== this.tabId) {
                // Another tab is active
                this.handleTabConflict(existingTab);
            }

            localStorage.setItem(this.TAB_KEY, this.tabId);
            this.isActiveTab = true;
        } catch (e) {
            console.error('Failed to register tab:', e);
        }
    },

    /**
     * Unregister this tab
     */
    unregisterTab() {
        try {
            const currentTab = localStorage.getItem(this.TAB_KEY);
            if (currentTab === this.tabId) {
                localStorage.removeItem(this.TAB_KEY);
            }
        } catch (e) {
            console.error('Failed to unregister tab:', e);
        }
    },

    /**
     * Handle storage change events from other tabs
     */
    handleStorageChange(event) {
        // Check if our game state was modified by another tab
        if (event.key === this.STORAGE_KEY) {
            console.warn('[GameState] Game state modified by another tab');

            // Reload current run to sync
            this.loadCurrentRun();

            // Notify UI if available
            if (typeof Toast !== 'undefined') {
                Toast.info('다른 탭에서 게임 상태가 변경되었습니다');
            }

            // Emit event for listeners
            this.emitEvent('stateChanged', { source: 'otherTab' });
        }

        // Check if another tab took over
        if (event.key === this.TAB_KEY && event.newValue && event.newValue !== this.tabId) {
            this.isActiveTab = false;
            console.warn('[GameState] Another tab is now active');
        }
    },

    /**
     * Handle tab conflict (another tab was already active)
     */
    handleTabConflict(otherTabId) {
        console.warn('[GameState] Tab conflict detected. Other tab:', otherTabId);

        // Show warning to user
        if (typeof Toast !== 'undefined') {
            Toast.info('다른 탭에서 게임이 실행 중입니다. 데이터 충돌에 주의하세요.');
        }

        // Reload state to ensure we have latest
        this.loadCurrentRun();
        this.loadProgress();
    },

    /**
     * Check if this tab is currently the active game tab
     */
    isCurrentlyActiveTab() {
        try {
            return localStorage.getItem(this.TAB_KEY) === this.tabId;
        } catch (e) {
            return true; // Assume active if can't check
        }
    },

    /**
     * Emit custom event for state changes
     */
    emitEvent(eventName, detail = {}) {
        const event = new CustomEvent(`gamestate:${eventName}`, { detail });
        window.dispatchEvent(event);
    },

    // ==========================================
    // SETTINGS
    // ==========================================

    loadSettings() {
        try {
            const saved = localStorage.getItem(this.SETTINGS_KEY);
            this.settings = saved ? { ...this.defaultSettings, ...JSON.parse(saved) } : { ...this.defaultSettings };
        } catch (e) {
            console.error('Failed to load settings:', e);
            this.settings = { ...this.defaultSettings };
        }
    },

    saveSettings() {
        try {
            localStorage.setItem(this.SETTINGS_KEY, JSON.stringify(this.settings));
        } catch (e) {
            console.error('Failed to save settings:', e);
        }
    },

    getSetting(key) {
        return this.settings[key];
    },

    setSetting(key, value) {
        this.settings[key] = value;
        this.saveSettings();
    },

    // ==========================================
    // PROGRESS (Meta Progression)
    // ==========================================

    loadProgress() {
        try {
            const saved = localStorage.getItem(this.PROGRESS_KEY);
            this.progress = saved ? { ...this.defaultProgress, ...JSON.parse(saved) } : { ...this.defaultProgress };
        } catch (e) {
            console.error('Failed to load progress:', e);
            this.progress = { ...this.defaultProgress };
        }
    },

    saveProgress() {
        try {
            localStorage.setItem(this.PROGRESS_KEY, JSON.stringify(this.progress));
        } catch (e) {
            console.error('Failed to save progress:', e);
        }
    },

    resetProgress() {
        this.progress = { ...this.defaultProgress };
        this.saveProgress();
    },

    addAchievement(id) {
        if (!this.progress.achievements.includes(id)) {
            this.progress.achievements.push(id);
            this.saveProgress();
            return true;
        }
        return false;
    },

    unlockClass(classId) {
        if (!this.progress.unlockedClasses.includes(classId)) {
            this.progress.unlockedClasses.push(classId);
            this.saveProgress();
            return true;
        }
        return false;
    },

    unlockEquipment(equipmentId) {
        if (!this.progress.unlockedEquipment.includes(equipmentId)) {
            this.progress.unlockedEquipment.push(equipmentId);
            this.saveProgress();
            return true;
        }
        return false;
    },

    isClassUnlocked(classId) {
        return this.progress.unlockedClasses.includes(classId);
    },

    isEquipmentUnlocked(equipmentId) {
        return this.progress.unlockedEquipment.includes(equipmentId);
    },

    isDifficultyUnlocked(difficulty) {
        // Use BalanceData if available
        if (typeof BalanceData !== 'undefined') {
            return BalanceData.isDifficultyUnlocked(difficulty, this.progress);
        }

        // Fallback logic
        const difficultyOrder = ['normal', 'hard', 'veryhard', 'nightmare'];
        const highestIndex = difficultyOrder.indexOf(this.progress.highestDifficulty);
        const requestedIndex = difficultyOrder.indexOf(difficulty);
        return requestedIndex <= highestIndex + 1;
    },

    // ==========================================
    // CURRENT RUN
    // ==========================================

    loadCurrentRun() {
        try {
            const saved = localStorage.getItem(this.STORAGE_KEY);
            this.currentRun = saved ? JSON.parse(saved) : null;
        } catch (e) {
            console.error('Failed to load current run:', e);
            this.currentRun = null;
        }
    },

    saveCurrentRun() {
        if (!this.currentRun) return;
        try {
            localStorage.setItem(this.STORAGE_KEY, JSON.stringify(this.currentRun));
        } catch (e) {
            console.error('Failed to save current run:', e);
        }
    },

    clearCurrentRun() {
        this.currentRun = null;
        localStorage.removeItem(this.STORAGE_KEY);
    },

    hasActiveRun() {
        return this.currentRun !== null && !this.currentRun.isComplete;
    },

    /**
     * Start a new game run
     */
    startNewRun(seed, difficulty) {
        const seedNumber = typeof seed === 'string' ? SeedUtils.parseSeedString(seed) : seed;
        const seedString = typeof seed === 'string' ? seed : SeedUtils.generateSeedString();

        // Get starting credits from balance data
        const startingCredits = typeof BalanceData !== 'undefined'
            ? BalanceData.economy.startingCredits
            : 0;

        this.currentRun = {
            // Run identification
            id: Utils.generateId(),
            seed: seedNumber,
            seedString: seedString,
            difficulty: difficulty,
            startTime: Date.now(),

            // Campaign state
            turn: 1,
            credits: startingCredits,
            currentNodeId: null,
            visitedNodes: [],
            stormLine: 0,

            // Sector map (generated on sector page)
            sectorMap: null,

            // Crews
            crews: this.createStartingCrews(),

            // Inventory - equipment in storage (not equipped)
            inventory: [],

            // Raven abilities remaining
            ravenAbilities: this.getDefaultRavenAbilities(),

            // Turrets deployed this stage (reset per stage)
            activeTurrets: [],

            // Current battle state (if in battle)
            currentBattle: null,

            // Statistics
            stats: {
                stationsDefended: 0,
                stationsLost: 0,
                enemiesKilled: 0,
                crewsLost: 0,
                creditsEarned: 0,
                perfectDefenses: 0,
                bossesKilled: 0,
                turretsBuilt: 0,
                skillsUsed: 0,
            },

            // Completion status
            isComplete: false,
            isVictory: false,
        };

        this.saveCurrentRun();
        this.progress.totalRuns++;
        this.saveProgress();

        return this.currentRun;
    },

    /**
     * Get default Raven abilities
     */
    getDefaultRavenAbilities() {
        if (typeof BalanceData !== 'undefined') {
            return {
                scout: BalanceData.raven.scoutUses,
                flare: BalanceData.raven.flareUses,
                resupply: BalanceData.raven.resupplyUses,
                orbitalStrike: BalanceData.raven.orbitalStrikeUses,
            };
        }

        return {
            scout: -1, // unlimited
            flare: 2,
            resupply: 1,
            orbitalStrike: 1,
        };
    },

    /**
     * Create starting crews
     */
    createStartingCrews() {
        return [
            this.createCrew('Marcus', 'guardian'),
            this.createCrew('Elena', 'sentinel'),
            this.createCrew('Kai', 'ranger'),
        ];
    },

    /**
     * Create a new crew
     */
    createCrew(name, classType, trait = null) {
        const classData = this.getClassData(classType);

        return {
            id: Utils.generateId(),
            name: name,
            class: classType,
            rank: 'standard', // standard, veteran, elite
            trait: trait || this.getRandomTrait(),
            skillLevel: 0, // 0-3
            equipment: null,
            equipmentLevel: 0,

            // Current state
            squadSize: classData.baseSquadSize,
            maxSquadSize: classData.baseSquadSize,
            health: classData.baseSquadSize,
            isDeployed: false,
            isAlive: true,

            // Combat state (reset per battle)
            skillCooldown: 0,
            chargesUsed: {},

            // Stats
            kills: 0,
            battlesParticipated: 0,
            damageDealt: 0,
            damageTaken: 0,
        };
    },

    /**
     * Get class data - uses CrewData module if available
     */
    getClassData(classType) {
        // Use CrewData module if available
        if (typeof CrewData !== 'undefined') {
            const data = CrewData.getClass(classType);
            if (data) {
                return {
                    name: data.name,
                    nameEn: data.nameEn,
                    baseSquadSize: data.baseSquadSize,
                    skill: data.skill.id,
                    color: data.color,
                    stats: data.stats,
                };
            }
        }

        // Fallback data
        const classes = {
            guardian: {
                name: 'Guardian',
                baseSquadSize: 8,
                skill: 'shieldBash',
                color: '#4a9eff',
            },
            sentinel: {
                name: 'Sentinel',
                baseSquadSize: 8,
                skill: 'lanceCharge',
                color: '#f6ad55',
            },
            ranger: {
                name: 'Ranger',
                baseSquadSize: 8,
                skill: 'volleyFire',
                color: '#68d391',
            },
            engineer: {
                name: 'Engineer',
                baseSquadSize: 6,
                skill: 'deployTurret',
                color: '#fc8181',
            },
            bionic: {
                name: 'Bionic',
                baseSquadSize: 5,
                skill: 'blink',
                color: '#b794f4',
            },
        };
        return classes[classType] || classes.guardian;
    },

    /**
     * Get random trait - uses TraitData module if available
     */
    getRandomTrait(rng = null) {
        // Use TraitData module if available
        if (typeof TraitData !== 'undefined') {
            return TraitData.getRandomTraitWeighted(rng);
        }

        // Fallback
        const traits = [
            'energetic',
            'swiftMovement',
            'popular',
            'quickRecovery',
            'sharpEdge',
            'heavyImpact',
            'skillful',
            'collector',
        ];
        const index = rng ? rng.range(0, traits.length - 1) : Math.floor(Math.random() * traits.length);
        return traits[index];
    },

    /**
     * Get trait display name
     */
    getTraitName(traitId) {
        if (typeof TraitData !== 'undefined') {
            return TraitData.getName(traitId, this.settings.language);
        }

        const names = {
            energetic: '활력 넘침',
            swiftMovement: '빠른 이동',
            popular: '인기 많음',
            quickRecovery: '빠른 회복',
            sharpEdge: '날카로운 공격',
            heavyImpact: '강력한 충격',
            skillful: '숙련됨',
            collector: '수집가',
        };
        return names[traitId] || traitId;
    },

    /**
     * Get equipment data
     */
    getEquipmentData(equipmentId) {
        if (typeof EquipmentData !== 'undefined') {
            return EquipmentData.get(equipmentId);
        }
        return null;
    },

    /**
     * Get enemy data
     */
    getEnemyData(enemyId) {
        if (typeof EnemyData !== 'undefined') {
            return EnemyData.get(enemyId);
        }
        return null;
    },

    /**
     * Get facility data
     */
    getFacilityData(facilityId) {
        if (typeof FacilityData !== 'undefined') {
            return FacilityData.get(facilityId);
        }
        return null;
    },

    // ==========================================
    // CREW MANAGEMENT
    // ==========================================

    /**
     * Recruit new crew
     */
    recruitCrew(name, classType, trait = null) {
        if (!this.currentRun) return null;

        const crew = this.createCrew(name, classType, trait);
        this.currentRun.crews.push(crew);
        this.saveCurrentRun();
        return crew;
    },

    /**
     * Upgrade crew skill
     */
    upgradeCrewSkill(crewId) {
        const crew = this.getCrewById(crewId);
        if (!crew || crew.skillLevel >= 3) return false;

        const cost = this.getSkillUpgradeCost(crew);
        if (!this.spendCredits(cost)) return false;

        crew.skillLevel++;
        this.saveCurrentRun();
        return true;
    },

    /**
     * Get skill upgrade cost for crew
     */
    getSkillUpgradeCost(crew) {
        const targetLevel = crew.skillLevel + 1;
        const hasSkilledTrait = crew.trait === 'skillful';

        if (typeof BalanceData !== 'undefined') {
            return BalanceData.calculateSkillUpgradeCost(targetLevel, hasSkilledTrait);
        }

        const baseCosts = { 1: 7, 2: 10, 3: 14 };
        const cost = baseCosts[targetLevel] || 0;
        return hasSkilledTrait ? Math.floor(cost * 0.5) : cost;
    },

    /**
     * Rank up crew
     */
    rankUpCrew(crewId) {
        const crew = this.getCrewById(crewId);
        if (!crew || crew.rank === 'elite') return false;

        const nextRank = crew.rank === 'standard' ? 'veteran' : 'elite';
        const cost = this.getRankUpCost(nextRank);

        if (!this.spendCredits(cost)) return false;

        crew.rank = nextRank;

        // Apply rank bonuses
        if (typeof BalanceData !== 'undefined') {
            const bonus = BalanceData.economy.rankBonuses[nextRank];
            if (bonus) {
                crew.maxSquadSize += bonus.maxSquadSizeBonus || 0;
            }
        } else {
            crew.maxSquadSize++;
        }

        this.saveCurrentRun();
        return true;
    },

    /**
     * Get rank up cost
     */
    getRankUpCost(targetRank) {
        if (typeof BalanceData !== 'undefined') {
            return BalanceData.calculateRankUpCost(targetRank);
        }

        return targetRank === 'veteran' ? 100 : 200;
    },

    /**
     * Equip item to crew
     */
    equipItem(crewId, equipmentId) {
        const crew = this.getCrewById(crewId);
        if (!crew || crew.equipment) return false; // Can't change equipment

        crew.equipment = equipmentId;
        crew.equipmentLevel = 1;
        this.saveCurrentRun();
        return true;
    },

    /**
     * Heal crew
     */
    healCrew(crewId, amount = 2) {
        const crew = this.getCrewById(crewId);
        if (!crew || !crew.isAlive) return false;

        const healCost = typeof BalanceData !== 'undefined'
            ? BalanceData.economy.healCost
            : 20;

        if (!this.spendCredits(healCost)) return false;

        crew.squadSize = Math.min(crew.squadSize + amount, crew.maxSquadSize);
        crew.health = crew.squadSize;
        this.saveCurrentRun();
        return true;
    },

    /**
     * Apply trait effects to crew stats
     */
    getCrewEffectiveStats(crew) {
        const classData = this.getClassData(crew.class);
        let stats = { ...classData.stats };

        // Apply trait
        if (typeof TraitData !== 'undefined' && crew.trait) {
            stats = TraitData.applyTraitEffects(stats, crew.trait);
        }

        // Apply rank bonuses
        if (typeof BalanceData !== 'undefined' && crew.rank !== 'standard') {
            const bonus = BalanceData.economy.rankBonuses[crew.rank];
            if (bonus) {
                stats.damage = (stats.damage || 0) * (bonus.damageMultiplier || 1);
            }
        }

        // Apply equipment effects (passive)
        if (crew.equipment && typeof EquipmentData !== 'undefined') {
            const effect = EquipmentData.getEffect(crew.equipment, crew.equipmentLevel);
            if (effect) {
                if (effect.attackSpeedMultiplier) {
                    stats.attackSpeed = (stats.attackSpeed || 1000) / effect.attackSpeedMultiplier;
                }
                if (effect.moveSpeedMultiplier) {
                    stats.moveSpeed = (stats.moveSpeed || 80) * effect.moveSpeedMultiplier;
                }
            }
        }

        return stats;
    },

    // ==========================================
    // CREDITS & ECONOMY
    // ==========================================

    /**
     * Add credits
     */
    addCredits(amount) {
        if (!this.currentRun) return;
        this.currentRun.credits += amount;
        this.currentRun.stats.creditsEarned += amount;
        this.saveCurrentRun();
    },

    /**
     * Spend credits
     */
    spendCredits(amount) {
        if (!this.currentRun || this.currentRun.credits < amount) return false;
        this.currentRun.credits -= amount;
        this.saveCurrentRun();
        return true;
    },

    /**
     * Advance turn
     */
    advanceTurn() {
        if (!this.currentRun) return;
        this.currentRun.turn++;
        this.currentRun.stormLine++;

        // Reset stage-specific state
        this.currentRun.activeTurrets = [];

        this.saveCurrentRun();
    },

    // ==========================================
    // BATTLE & STATISTICS
    // ==========================================

    /**
     * Record station defended
     */
    recordStationDefended(credits, isPerfect = false) {
        if (!this.currentRun) return;
        this.currentRun.stats.stationsDefended++;
        if (isPerfect) {
            this.currentRun.stats.perfectDefenses++;
        }
        this.addCredits(credits);
        this.progress.totalStationsDefended++;
        this.saveProgress();
        this.saveCurrentRun();
    },

    /**
     * Record enemies killed
     */
    recordEnemiesKilled(count) {
        if (!this.currentRun) return;
        this.currentRun.stats.enemiesKilled += count;
        this.progress.totalEnemiesKilled += count;
        this.saveProgress();
        this.saveCurrentRun();
    },

    /**
     * Record boss killed
     */
    recordBossKilled() {
        if (!this.currentRun) return;
        this.currentRun.stats.bossesKilled++;
        this.saveCurrentRun();
    },

    /**
     * Record crew death
     */
    recordCrewDeath(crewId) {
        const crew = this.getCrewById(crewId);
        if (!crew) return;

        crew.isAlive = false;
        crew.squadSize = 0;
        this.currentRun.stats.crewsLost++;
        this.saveCurrentRun();
    },

    /**
     * End run (victory or defeat)
     */
    endRun(isVictory) {
        if (!this.currentRun) return;

        this.currentRun.isComplete = true;
        this.currentRun.isVictory = isVictory;
        this.currentRun.endTime = Date.now();

        if (isVictory) {
            this.progress.totalVictories++;

            // Mark difficulty as cleared
            const difficultyKey = this.currentRun.difficulty + 'Cleared';
            this.progress[difficultyKey] = true;

            // Check for difficulty unlock
            const difficultyOrder = ['normal', 'hard', 'veryhard', 'nightmare'];
            const currentIndex = difficultyOrder.indexOf(this.currentRun.difficulty);
            const highestIndex = difficultyOrder.indexOf(this.progress.highestDifficulty);
            if (currentIndex > highestIndex) {
                this.progress.highestDifficulty = this.currentRun.difficulty;
            }

            // Check for class unlocks
            if (this.currentRun.difficulty === 'normal' && !this.isClassUnlocked('engineer')) {
                this.unlockClass('engineer');
            }
            if (this.currentRun.difficulty === 'hard' && !this.isClassUnlocked('bionic')) {
                this.unlockClass('bionic');
            }
        }

        this.saveProgress();
        this.saveCurrentRun();
    },

    /**
     * Get run duration
     */
    getRunDuration() {
        if (!this.currentRun) return 0;
        const endTime = this.currentRun.endTime || Date.now();
        return Math.floor((endTime - this.currentRun.startTime) / 1000);
    },

    /**
     * Calculate final score
     */
    calculateScore() {
        if (!this.currentRun) return 0;

        // Use BalanceData if available
        if (typeof BalanceData !== 'undefined') {
            return BalanceData.calculateFinalScore(
                this.currentRun.stats,
                this.currentRun.difficulty
            );
        }

        // Fallback
        const stats = this.currentRun.stats;
        const difficultyMultiplier = {
            normal: 1,
            hard: 1.5,
            veryhard: 2,
            nightmare: 3,
        };

        let score = 0;
        score += stats.stationsDefended * 500;
        score += stats.perfectDefenses * 200;
        score += stats.enemiesKilled * 10;
        score += stats.creditsEarned * 5;
        score -= stats.crewsLost * 1000;

        score = Math.floor(score * (difficultyMultiplier[this.currentRun.difficulty] || 1));

        return Math.max(0, score);
    },

    /**
     * Get alive crews
     */
    getAliveCrews() {
        if (!this.currentRun) return [];
        return this.currentRun.crews.filter(c => c.isAlive);
    },

    /**
     * Get crew by ID
     */
    getCrewById(id) {
        if (!this.currentRun) return null;
        return this.currentRun.crews.find(c => c.id === id);
    },

    // ==========================================
    // VALIDATION
    // ==========================================

    /**
     * Validate current run data integrity
     */
    validateCurrentRun() {
        if (!this.currentRun) return true;

        const errors = [];

        // Validate crews
        for (const crew of this.currentRun.crews) {
            if (!this.getClassData(crew.class)) {
                errors.push(`Invalid class: ${crew.class}`);
            }
            if (crew.squadSize > crew.maxSquadSize) {
                errors.push(`Crew ${crew.name} has squadSize > maxSquadSize`);
            }
            if (crew.skillLevel < 0 || crew.skillLevel > 3) {
                errors.push(`Crew ${crew.name} has invalid skillLevel`);
            }
        }

        // Log errors if any
        if (errors.length > 0) {
            console.warn('GameState validation errors:', errors);
            return false;
        }

        return true;
    },
};

// Initialize on load
document.addEventListener('DOMContentLoaded', () => {
    GameState.init();
});

// Make available globally
window.GameState = GameState;
