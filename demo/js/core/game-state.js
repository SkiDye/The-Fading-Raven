/**
 * THE FADING RAVEN - Game State Manager
 * Manages game state persistence across pages using localStorage
 */

const GameState = {
    STORAGE_KEY: 'theFadingRaven_gameState',
    SETTINGS_KEY: 'theFadingRaven_settings',
    PROGRESS_KEY: 'theFadingRaven_progress',

    // Default settings
    defaultSettings: {
        difficulty: 'normal',
        gameSpeed: 1,
        soundVolume: 70,
        musicVolume: 50,
        showTutorial: true,
        screenShake: true,
    },

    // Default progress (meta progression)
    defaultProgress: {
        highestDifficulty: 'normal',
        totalRuns: 0,
        totalVictories: 0,
        totalEnemiesKilled: 0,
        totalStationsDefended: 0,
        unlockedClasses: ['guardian', 'sentinel', 'ranger'],
        unlockedEquipment: ['shockWave', 'fragGrenade'],
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
        console.log('GameState initialized');
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

    isClassUnlocked(classId) {
        return this.progress.unlockedClasses.includes(classId);
    },

    isDifficultyUnlocked(difficulty) {
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

        this.currentRun = {
            // Run identification
            id: Utils.generateId(),
            seed: seedNumber,
            seedString: seedString,
            difficulty: difficulty,
            startTime: Date.now(),

            // Campaign state
            turn: 1,
            credits: 0,
            currentNodeId: null,
            visitedNodes: [],
            stormLine: 0,

            // Sector map (generated on sector page)
            sectorMap: null,

            // Crews
            crews: this.createStartingCrews(),

            // Inventory
            equipment: [],

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

            // Current state
            squadSize: classData.baseSquadSize,
            maxSquadSize: classData.baseSquadSize,
            health: classData.baseSquadSize,
            isDeployed: false,
            isAlive: true,

            // Stats
            kills: 0,
            battlesParticipated: 0,
        };
    },

    /**
     * Get class data
     */
    getClassData(classType) {
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
        return classes[classType];
    },

    /**
     * Get random trait
     */
    getRandomTrait() {
        const traits = [
            'energetic',    // -33% skill cooldown
            'swiftMovement', // +33% move speed
            'popular',      // +1 squad size
            'quickRecovery', // -33% recovery time
            'sharpEdge',    // +20% damage
            'heavyImpact',  // +50% knockback
            'skillful',     // -50% skill upgrade cost
            'collector',    // -50% equipment cost
        ];
        return traits[Math.floor(Math.random() * traits.length)];
    },

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
        this.saveCurrentRun();
    },

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
     * End run (victory or defeat)
     */
    endRun(isVictory) {
        if (!this.currentRun) return;

        this.currentRun.isComplete = true;
        this.currentRun.isVictory = isVictory;
        this.currentRun.endTime = Date.now();

        if (isVictory) {
            this.progress.totalVictories++;
            // Check for difficulty unlock
            const difficultyOrder = ['normal', 'hard', 'veryhard', 'nightmare'];
            const currentIndex = difficultyOrder.indexOf(this.currentRun.difficulty);
            const highestIndex = difficultyOrder.indexOf(this.progress.highestDifficulty);
            if (currentIndex > highestIndex) {
                this.progress.highestDifficulty = this.currentRun.difficulty;
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
};

// Initialize on load
document.addEventListener('DOMContentLoaded', () => {
    GameState.init();
});

// Make available globally
window.GameState = GameState;
