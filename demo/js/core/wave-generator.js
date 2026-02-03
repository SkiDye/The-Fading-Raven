/**
 * THE FADING RAVEN - Wave Generator System
 * Budget-based enemy wave generation with difficulty scaling
 */

/**
 * Wave composition templates
 */
const WaveTemplates = {
    // Basic waves (early game)
    basic_rush: {
        composition: { rusher: 0.6, gunner: 0.4 },
        pattern: 'swarm',
        minDepth: 0,
    },
    basic_ranged: {
        composition: { gunner: 0.7, rusher: 0.3 },
        pattern: 'spread',
        minDepth: 0,
    },
    basic_mixed: {
        composition: { rusher: 0.4, gunner: 0.3, shieldTrooper: 0.3 },
        pattern: 'mixed',
        minDepth: 0,
    },

    // Medium waves (mid game)
    assault: {
        composition: { jumper: 0.4, rusher: 0.3, gunner: 0.3 },
        pattern: 'assault',
        minDepth: 3,
    },
    heavy_push: {
        composition: { heavyTrooper: 0.3, shieldTrooper: 0.4, gunner: 0.3 },
        pattern: 'push',
        minDepth: 4,
    },
    hacker_support: {
        composition: { hacker: 0.2, gunner: 0.4, shieldTrooper: 0.4 },
        pattern: 'support',
        minDepth: 4,
    },

    // Advanced waves (late game)
    elite_assault: {
        composition: { brute: 0.2, jumper: 0.3, heavyTrooper: 0.3, rusher: 0.2 },
        pattern: 'assault',
        minDepth: 5,
    },
    sniper_cover: {
        composition: { sniper: 0.2, shieldTrooper: 0.4, gunner: 0.4 },
        pattern: 'cover',
        minDepth: 6,
    },
    drone_swarm: {
        composition: { droneCarrier: 0.2, shieldGenerator: 0.2, gunner: 0.6 },
        pattern: 'support',
        minDepth: 7,
    },
    elite_mixed: {
        composition: { brute: 0.15, sniper: 0.15, droneCarrier: 0.1, shieldGenerator: 0.1, heavyTrooper: 0.25, jumper: 0.25 },
        pattern: 'mixed',
        minDepth: 7,
    },

    // Storm waves (storm stages only)
    storm_basic: {
        composition: { stormCreature: 0.6, rusher: 0.4 },
        pattern: 'swarm',
        minDepth: 0,
        stormOnly: true,
    },
    storm_mixed: {
        composition: { stormCreature: 0.4, gunner: 0.3, jumper: 0.3 },
        pattern: 'assault',
        minDepth: 4,
        stormOnly: true,
    },

    // Boss waves
    boss_captain: {
        composition: { pirateCaptain: 1.0 },
        pattern: 'boss',
        isBoss: true,
    },
    boss_storm: {
        composition: { stormCore: 1.0 },
        pattern: 'boss',
        isBoss: true,
        stormOnly: true,
    },
};

/**
 * Default spawn point fallback
 */
const DEFAULT_SPAWN_POINT = { x: 0, y: 0 };

/**
 * Get safe spawn points (with fallback)
 */
function getSafeSpawnPoints(spawnPoints) {
    if (!spawnPoints || spawnPoints.length === 0) {
        return [DEFAULT_SPAWN_POINT];
    }
    return spawnPoints;
}

/**
 * Spawn patterns
 */
const SpawnPatterns = {
    /**
     * Swarm - All enemies spawn from one point
     */
    swarm: (count, spawnPoints, rng) => {
        const safePoints = getSafeSpawnPoints(spawnPoints);
        const point = rng.pick(safePoints);
        const positions = [];

        for (let i = 0; i < count; i++) {
            positions.push({
                x: point.x + rng.rangeFloat(-30, 30),
                y: point.y + rng.rangeFloat(-30, 30),
                delay: i * 200,
            });
        }

        return positions;
    },

    /**
     * Spread - Enemies spread across all spawn points
     */
    spread: (count, spawnPoints, rng) => {
        const safePoints = getSafeSpawnPoints(spawnPoints);
        const positions = [];
        const perPoint = Math.ceil(count / safePoints.length);

        for (let i = 0; i < count; i++) {
            const pointIndex = Math.floor(i / perPoint) % safePoints.length;
            const point = safePoints[pointIndex];

            positions.push({
                x: point.x + rng.rangeFloat(-20, 20),
                y: point.y + rng.rangeFloat(-20, 20),
                delay: (i % perPoint) * 300,
            });
        }

        return positions;
    },

    /**
     * Mixed - Random spawn points
     */
    mixed: (count, spawnPoints, rng) => {
        const safePoints = getSafeSpawnPoints(spawnPoints);
        const positions = [];

        for (let i = 0; i < count; i++) {
            const point = rng.pick(safePoints);

            positions.push({
                x: point.x + rng.rangeFloat(-25, 25),
                y: point.y + rng.rangeFloat(-25, 25),
                delay: i * 250 + rng.range(0, 100),
            });
        }

        return positions;
    },

    /**
     * Assault - Front line first, then ranged
     */
    assault: (count, spawnPoints, rng) => {
        const safePoints = getSafeSpawnPoints(spawnPoints);
        const positions = [];
        const frontCount = Math.floor(count * 0.6);

        // Front line (closer together)
        const frontPoint = rng.pick(safePoints);
        for (let i = 0; i < frontCount; i++) {
            positions.push({
                x: frontPoint.x + rng.rangeFloat(-40, 40),
                y: frontPoint.y + rng.rangeFloat(-20, 20),
                delay: i * 150,
                isFront: true,
            });
        }

        // Back line (spread)
        for (let i = frontCount; i < count; i++) {
            const point = rng.pick(safePoints);
            positions.push({
                x: point.x + rng.rangeFloat(-30, 30),
                y: point.y + rng.rangeFloat(-30, 30),
                delay: 500 + (i - frontCount) * 300,
                isFront: false,
            });
        }

        return positions;
    },

    /**
     * Push - Line formation advancing
     */
    push: (count, spawnPoints, rng) => {
        const safePoints = getSafeSpawnPoints(spawnPoints);
        const positions = [];
        const point = rng.pick(safePoints);

        // Line formation
        const spacing = 35;
        const startX = point.x - ((count - 1) * spacing) / 2;

        for (let i = 0; i < count; i++) {
            positions.push({
                x: startX + i * spacing,
                y: point.y + rng.rangeFloat(-10, 10),
                delay: i * 100,
            });
        }

        return positions;
    },

    /**
     * Support - Support units in back
     */
    support: (count, spawnPoints, rng) => {
        const safePoints = getSafeSpawnPoints(spawnPoints);
        const positions = [];
        const point = rng.pick(safePoints);

        for (let i = 0; i < count; i++) {
            const isSupport = i < Math.floor(count * 0.3);

            positions.push({
                x: point.x + rng.rangeFloat(-40, 40),
                y: point.y + (isSupport ? 50 : 0) + rng.rangeFloat(-15, 15),
                delay: isSupport ? 0 : 300 + i * 150,
                isSupport,
            });
        }

        return positions;
    },

    /**
     * Cover - Ranged behind shields
     */
    cover: (count, spawnPoints, rng) => {
        const safePoints = getSafeSpawnPoints(spawnPoints);
        const positions = [];
        const point = rng.pick(safePoints);

        const frontCount = Math.floor(count * 0.4);

        // Shields in front
        for (let i = 0; i < frontCount; i++) {
            positions.push({
                x: point.x + (i - frontCount / 2) * 40,
                y: point.y,
                delay: i * 100,
                isCover: true,
            });
        }

        // Ranged in back
        for (let i = frontCount; i < count; i++) {
            positions.push({
                x: point.x + ((i - frontCount) - (count - frontCount) / 2) * 50,
                y: point.y + 60,
                delay: 400 + (i - frontCount) * 150,
                isCover: false,
            });
        }

        return positions;
    },

    /**
     * Boss - Single boss spawn
     */
    boss: (count, spawnPoints, rng) => {
        const safePoints = getSafeSpawnPoints(spawnPoints);
        const point = rng.pick(safePoints);

        return [{
            x: point.x,
            y: point.y,
            delay: 0,
            isBoss: true,
        }];
    },
};

/**
 * Wave Generator
 */
class WaveGenerator {
    constructor(rng = null) {
        this.rng = rng || new SeededRNG(Date.now());
    }

    /**
     * Generate waves for a stage
     */
    generateWaves(config) {
        const {
            depth,
            difficulty = 'normal',
            isStormStage = false,
            spawnPoints = [],
            isBossStage = false,
        } = config;

        const waveConfig = BalanceData.getWaveConfig(depth, difficulty);
        const waves = [];

        if (isBossStage) {
            // Boss wave
            waves.push(this.generateBossWave(depth, isStormStage, spawnPoints));
        } else {
            // Normal waves
            for (let i = 0; i < waveConfig.waveCount; i++) {
                const waveBudget = waveConfig.budget + (i * BalanceData.wave.budgetPerWave);

                waves.push(this.generateWave({
                    waveIndex: i,
                    budget: waveBudget,
                    depth,
                    difficulty,
                    isStormStage,
                    spawnPoints,
                    tier1Available: waveConfig.tier1Available,
                    tier2Available: waveConfig.tier2Available,
                    tier3Available: waveConfig.tier3Available,
                }));
            }
        }

        return waves;
    }

    /**
     * Generate a single wave
     */
    generateWave(config) {
        const {
            waveIndex,
            budget,
            depth,
            difficulty,
            isStormStage,
            spawnPoints,
            tier1Available,
            tier2Available,
            tier3Available,
        } = config;

        // Select wave template
        const template = this.selectTemplate(depth, isStormStage);

        // Get available enemies for this wave
        const availableEnemies = EnemyData.getForWaveGeneration(depth, budget, isStormStage);

        // Generate enemy list based on budget
        const enemies = this.allocateBudget(
            budget,
            template.composition,
            availableEnemies,
            { tier1Available, tier2Available, tier3Available }
        );

        // Generate spawn positions
        const pattern = SpawnPatterns[template.pattern] || SpawnPatterns.mixed;
        const positions = pattern(enemies.length, spawnPoints, this.rng);

        // Combine enemies with positions
        const spawnList = enemies.map((enemyId, index) => ({
            enemyId,
            ...positions[index],
        }));

        // Sort by delay
        spawnList.sort((a, b) => a.delay - b.delay);

        return {
            index: waveIndex,
            enemies: spawnList,
            totalEnemies: enemies.length,
            pattern: template.pattern,
            budget: budget,
        };
    }

    /**
     * Generate boss wave
     */
    generateBossWave(depth, isStormStage, spawnPoints) {
        const bossId = isStormStage ? 'stormCore' : 'pirateCaptain';
        const template = isStormStage ? WaveTemplates.boss_storm : WaveTemplates.boss_captain;

        const positions = SpawnPatterns.boss(1, spawnPoints, this.rng);

        // Add escort enemies for pirate captain
        const enemies = [{ enemyId: bossId, ...positions[0] }];

        if (!isStormStage) {
            // Add escort
            const escortCount = Math.min(5, Math.floor(depth / 2));
            const escortPositions = SpawnPatterns.spread(escortCount, spawnPoints, this.rng);

            for (let i = 0; i < escortCount; i++) {
                enemies.push({
                    enemyId: this.rng.pick(['rusher', 'gunner', 'shieldTrooper']),
                    ...escortPositions[i],
                    delay: escortPositions[i].delay + 1000, // Spawn after boss
                });
            }
        }

        return {
            index: 0,
            enemies,
            totalEnemies: enemies.length,
            pattern: 'boss',
            isBoss: true,
            bossId,
        };
    }

    /**
     * Select appropriate wave template
     */
    selectTemplate(depth, isStormStage) {
        const availableTemplates = Object.entries(WaveTemplates)
            .filter(([name, template]) => {
                if (template.isBoss) return false;
                if (template.stormOnly && !isStormStage) return false;
                if (isStormStage && !template.stormOnly) return false;
                if ((template.minDepth || 0) > depth) return false;
                return true;
            })
            .map(([name, template]) => ({ name, ...template }));

        if (availableTemplates.length === 0) {
            return WaveTemplates.basic_mixed;
        }

        // Weight towards more advanced templates at higher depths
        const weights = availableTemplates.map(t => {
            const minDepth = t.minDepth || 0;
            return 1 + (depth - minDepth) * 0.5;
        });

        return this.rng.weightedPick(availableTemplates, weights);
    }

    /**
     * Allocate budget to enemies
     */
    allocateBudget(budget, composition, availableEnemies, tierConfig) {
        const enemies = [];
        let remainingBudget = budget;

        // Get available enemy IDs from composition
        const compositionEnemies = Object.keys(composition)
            .filter(enemyId => {
                const enemy = EnemyData.get(enemyId);
                if (!enemy) return false;

                // Check tier availability
                const tier = enemy.tier;
                if (tier === 1 && !tierConfig.tier1Available) return false;
                if (tier === 2 && !tierConfig.tier2Available) return false;
                if (tier === 3 && !tierConfig.tier3Available) return false;

                return true;
            });

        if (compositionEnemies.length === 0) {
            // Fallback to basic enemies
            compositionEnemies.push('rusher', 'gunner');
        }

        // Calculate target counts based on composition percentages
        const targetCounts = {};
        let totalWeight = 0;

        for (const enemyId of compositionEnemies) {
            totalWeight += composition[enemyId] || 0;
        }

        for (const enemyId of compositionEnemies) {
            const weight = composition[enemyId] || 0;
            targetCounts[enemyId] = Math.max(1, Math.floor((weight / totalWeight) * (budget / 2)));
        }

        // Fill enemies based on target counts
        let iterations = 0;
        const maxIterations = 100;

        while (remainingBudget > 0 && iterations < maxIterations) {
            iterations++;

            // Pick enemy type weighted by remaining need
            const candidates = compositionEnemies.filter(enemyId => {
                const cost = EnemyData.getCost(enemyId);
                return cost <= remainingBudget;
            });

            if (candidates.length === 0) break;

            const weights = candidates.map(enemyId => {
                const currentCount = enemies.filter(e => e === enemyId).length;
                const target = targetCounts[enemyId] || 1;
                return Math.max(0.1, target - currentCount);
            });

            const enemyId = this.rng.weightedPick(candidates, weights);
            const cost = EnemyData.getCost(enemyId);

            enemies.push(enemyId);
            remainingBudget -= cost;
        }

        // Enforce min/max enemy count
        const minEnemies = BalanceData.wave.minEnemies;
        const maxEnemies = BalanceData.wave.maxEnemies;

        while (enemies.length < minEnemies) {
            enemies.push(this.rng.pick(['rusher', 'gunner']));
        }

        if (enemies.length > maxEnemies) {
            enemies.length = maxEnemies;
        }

        return this.rng.shuffle(enemies);
    }

    /**
     * Generate reinforcement wave
     */
    generateReinforcements(count, depth, spawnPoints) {
        const enemies = [];

        for (let i = 0; i < count; i++) {
            enemies.push(this.rng.pick(['rusher', 'gunner']));
        }

        const positions = SpawnPatterns.swarm(count, spawnPoints, this.rng);

        return enemies.map((enemyId, index) => ({
            enemyId,
            ...positions[index],
        }));
    }

    /**
     * Calculate wave difficulty score
     */
    calculateWaveDifficulty(wave) {
        let score = 0;

        for (const spawn of wave.enemies) {
            const enemy = EnemyData.get(spawn.enemyId);
            if (enemy) {
                score += enemy.cost * (enemy.isBoss ? 5 : 1);
            }
        }

        return score;
    }

    /**
     * Get preview of waves for display
     */
    getWavePreview(config) {
        const waves = this.generateWaves(config);

        return waves.map(wave => ({
            index: wave.index,
            totalEnemies: wave.totalEnemies,
            pattern: wave.pattern,
            isBoss: wave.isBoss,
            enemyTypes: [...new Set(wave.enemies.map(e => e.enemyId))],
            difficulty: this.calculateWaveDifficulty(wave),
        }));
    }
}

/**
 * Wave Manager - Handles wave execution during battle
 */
class WaveManager {
    constructor() {
        this.waves = [];
        this.currentWaveIndex = -1;
        this.currentWave = null;
        this.spawnQueue = [];
        this.spawnedEnemies = [];
        this.isSpawning = false;
        this.waveStartTime = 0;

        this.events = Utils.createEventEmitter();
    }

    /**
     * Initialize with generated waves
     */
    initialize(waves) {
        this.waves = waves;
        this.currentWaveIndex = -1;
        this.currentWave = null;
        this.spawnQueue = [];
        this.spawnedEnemies = [];
        this.isSpawning = false;
    }

    /**
     * Start next wave
     */
    startNextWave(difficulty = 'normal') {
        this.currentWaveIndex++;

        if (this.currentWaveIndex >= this.waves.length) {
            this.events.emit('allWavesComplete');
            return false;
        }

        this.currentWave = this.waves[this.currentWaveIndex];
        this.spawnQueue = [...this.currentWave.enemies];
        this.spawnedEnemies = [];
        this.isSpawning = true;
        this.waveStartTime = Date.now();

        this.events.emit('waveStart', {
            waveIndex: this.currentWaveIndex,
            totalWaves: this.waves.length,
            wave: this.currentWave,
        });

        return true;
    }

    /**
     * Update wave spawning
     */
    update(deltaTime, difficulty = 'normal') {
        if (!this.isSpawning || this.spawnQueue.length === 0) {
            return [];
        }

        const elapsed = Date.now() - this.waveStartTime;
        const spawned = [];

        // Spawn enemies whose delay has passed
        while (this.spawnQueue.length > 0 && this.spawnQueue[0].delay <= elapsed) {
            const spawnData = this.spawnQueue.shift();

            const enemy = EnemyFactory.create(
                spawnData.enemyId,
                spawnData.x,
                spawnData.y,
                difficulty
            );

            this.spawnedEnemies.push(enemy);
            spawned.push(enemy);

            this.events.emit('enemySpawned', { enemy, waveIndex: this.currentWaveIndex });
        }

        // Check if spawning complete
        if (this.spawnQueue.length === 0) {
            this.isSpawning = false;
            this.events.emit('waveSpawnComplete', {
                waveIndex: this.currentWaveIndex,
                totalSpawned: this.spawnedEnemies.length,
            });
        }

        return spawned;
    }

    /**
     * Check if current wave is cleared
     */
    isWaveCleared(activeEnemies) {
        if (this.isSpawning) return false;

        return activeEnemies.filter(e =>
            e.state !== EnemyState.DEAD &&
            e.state !== EnemyState.DYING
        ).length === 0;
    }

    /**
     * Get wave progress
     */
    getProgress() {
        return {
            currentWave: this.currentWaveIndex + 1,
            totalWaves: this.waves.length,
            enemiesSpawned: this.spawnedEnemies.length,
            enemiesRemaining: this.spawnQueue.length,
            isSpawning: this.isSpawning,
            isBossWave: this.currentWave?.isBoss || false,
        };
    }

    /**
     * Check if all waves are complete
     */
    isAllWavesComplete() {
        return this.currentWaveIndex >= this.waves.length - 1 && !this.isSpawning;
    }

    /**
     * Get current wave info
     */
    getCurrentWaveInfo() {
        if (!this.currentWave) return null;

        return {
            index: this.currentWaveIndex,
            pattern: this.currentWave.pattern,
            totalEnemies: this.currentWave.totalEnemies,
            isBoss: this.currentWave.isBoss,
        };
    }

    /**
     * Get preview of next wave for UI display
     */
    getNextWavePreview() {
        const nextIndex = this.currentWaveIndex + 1;

        if (nextIndex >= this.waves.length) {
            return null;
        }

        const nextWave = this.waves[nextIndex];
        const enemyCounts = {};
        const specialEnemies = [];

        // Count enemy types
        for (const spawn of nextWave.enemies) {
            enemyCounts[spawn.enemyId] = (enemyCounts[spawn.enemyId] || 0) + 1;

            // Track special/dangerous enemies
            const enemyData = EnemyData.get(spawn.enemyId);
            if (enemyData && (enemyData.tier >= 2 || enemyData.isBoss)) {
                if (!specialEnemies.find(e => e.id === spawn.enemyId)) {
                    specialEnemies.push({
                        id: spawn.enemyId,
                        name: enemyData.name,
                        tier: enemyData.tier,
                        isBoss: enemyData.isBoss,
                        icon: enemyData.visual?.icon,
                        color: enemyData.visual?.color,
                        threat: enemyData.behavior?.special?.type || null,
                    });
                }
            }
        }

        // Build enemy summary
        const enemySummary = Object.entries(enemyCounts).map(([enemyId, count]) => {
            const data = EnemyData.get(enemyId);
            return {
                enemyId,
                count,
                name: data?.name || enemyId,
                tier: data?.tier || 1,
                icon: data?.visual?.icon,
                color: data?.visual?.color,
            };
        }).sort((a, b) => b.tier - a.tier || b.count - a.count);

        return {
            waveNumber: nextIndex + 1,
            totalWaves: this.waves.length,
            totalEnemies: nextWave.totalEnemies,
            pattern: nextWave.pattern,
            isBoss: nextWave.isBoss || false,
            bossId: nextWave.bossId || null,
            enemySummary,
            specialEnemies,
            warnings: this.getWaveWarnings(nextWave, specialEnemies),
        };
    }

    /**
     * Generate warnings for wave preview
     */
    getWaveWarnings(wave, specialEnemies) {
        const warnings = [];

        for (const enemy of specialEnemies) {
            switch (enemy.threat) {
                case 'hack':
                    warnings.push({ type: 'hacker', message: '해커 출현 - 터렛 보호 필요', icon: '⚡' });
                    break;
                case 'sniper':
                    warnings.push({ type: 'sniper', message: '스나이퍼 출현 - 엄폐 권장', icon: '🎯' });
                    break;
                case 'spawnDrones':
                    warnings.push({ type: 'carrier', message: '드론 캐리어 출현 - 우선 처치', icon: '🤖' });
                    break;
                case 'shieldGenerator':
                    warnings.push({ type: 'shield', message: '쉴드 제너레이터 출현', icon: '🛡️' });
                    break;
                case 'jumpAttack':
                    warnings.push({ type: 'jumper', message: '점퍼 출현 - 후방 주의', icon: '🦘' });
                    break;
            }

            if (enemy.isBoss) {
                warnings.push({ type: 'boss', message: '보스 출현!', icon: '💀', priority: 'high' });
            }
        }

        return warnings;
    }

    /**
     * Subscribe to events
     */
    on(event, callback) {
        this.events.on(event, callback);
    }

    /**
     * Unsubscribe from events
     */
    off(event, callback) {
        this.events.off(event, callback);
    }

    /**
     * Reset manager
     */
    reset() {
        this.waves = [];
        this.currentWaveIndex = -1;
        this.currentWave = null;
        this.spawnQueue = [];
        this.spawnedEnemies = [];
        this.isSpawning = false;
    }
}

// Make available globally
window.WaveTemplates = WaveTemplates;
window.SpawnPatterns = SpawnPatterns;
window.WaveGenerator = WaveGenerator;
window.WaveManager = WaveManager;
