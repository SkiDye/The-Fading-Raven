/**
 * THE FADING RAVEN - Battle Controller
 * Refactored with tile-based combat, skill system, and slow motion
 */

const BattleController = {
    elements: {},
    canvas: null,
    ctx: null,

    // Game state
    running: false,
    paused: false,
    lastTime: 0,
    deltaTime: 0,

    // Time control
    timeScale: 1,
    slowMotionActive: false,
    slowMotionDuration: 0,
    SLOW_MOTION_SCALE: 0.3,

    // Layout
    tileSize: 40,
    offsetX: 0,
    offsetY: 0,

    // Entities
    crews: [],
    enemies: [],
    projectiles: [],
    effects: [],
    turrets: [],
    mines: [],
    deadCrews: [],

    // Tile grid reference
    tileGrid: null,

    // Battle state
    waveNumber: 0,
    totalWaves: 3,
    waveTimer: 0,
    waveDelay: 5000,
    enemiesRemaining: 0,
    stationHealth: 100,

    // Selection & Targeting
    selectedCrew: null,
    targetingMode: null, // null, 'skill', 'equipment', 'raven'
    targetingAbility: null,
    targetPosition: null,

    // RNG
    rng: null,

    // Wave management
    waveGenerator: null,
    waveManager: null,

    // Screen shake
    shakeAmount: 0,
    shakeDuration: 0,
    shakeOffset: { x: 0, y: 0 },

    init() {
        this.checkDeploymentData();
        this.cacheElements();
        this.initCanvas();
        this.initRNG();
        this.initTileGrid();
        this.initSystems();
        this.setupBattle();
        this.bindEvents();
        this.startBattle();
        console.log('BattleController initialized with new systems');
    },

    checkDeploymentData() {
        const deploymentData = sessionStorage.getItem('deploymentData');
        if (!deploymentData || !GameState.hasActiveRun()) {
            Utils.navigateTo('sector');
            return;
        }
        this.deploymentData = JSON.parse(deploymentData);
        this.battleInfo = this.deploymentData.battleInfo;
        this.stationLayout = this.deploymentData.stationLayout;
    },

    cacheElements() {
        this.elements = {
            battleCanvas: document.getElementById('battle-canvas'),
            hudWave: document.getElementById('hud-wave'),
            hudEnemies: document.getElementById('hud-enemies'),
            hudStation: document.getElementById('hud-station'),
            stationHealthBar: document.getElementById('station-health-bar'),
            crewButtons: document.getElementById('crew-buttons'),
            ravenAbilities: document.getElementById('raven-abilities'),
            waveAnnouncement: document.getElementById('wave-announcement'),
            waveText: document.getElementById('wave-text'),
            btnPause: document.getElementById('btn-pause'),
            pauseMenu: document.getElementById('pause-menu'),
            btnResume: document.getElementById('btn-resume'),
            btnRetreatBattle: document.getElementById('btn-retreat-battle'),
            targetingOverlay: document.getElementById('targeting-overlay'),
            slowMotionIndicator: document.getElementById('slow-motion-indicator'),
        };
    },

    initCanvas() {
        this.canvas = this.elements.battleCanvas;
        if (!this.canvas) return;

        this.ctx = this.canvas.getContext('2d');
        this.resizeCanvas();
    },

    resizeCanvas() {
        if (!this.canvas) return;

        const rect = this.canvas.getBoundingClientRect();
        this.canvas.width = rect.width;
        this.canvas.height = rect.height;

        if (this.stationLayout) {
            this.tileSize = Math.min(
                (this.canvas.width - 100) / this.stationLayout.width,
                (this.canvas.height - 100) / this.stationLayout.height
            );
            this.offsetX = (this.canvas.width - this.stationLayout.width * this.tileSize) / 2;
            this.offsetY = (this.canvas.height - this.stationLayout.height * this.tileSize) / 2;
        }
    },

    initRNG() {
        if (GameState.currentRun) {
            this.rng = new MultiStreamRNG(GameState.currentRun.seed + GameState.currentRun.turn);
        }
    },

    initTileGrid() {
        if (this.stationLayout && TileGrid) {
            this.tileGrid = Object.create(TileGrid);
            this.tileGrid.init(this.stationLayout);
            this.tileGrid.tileSize = this.tileSize;
        }
    },

    initSystems() {
        // Initialize skill system
        if (SkillSystem) {
            SkillSystem.reset();
        }

        // Initialize equipment effects
        if (EquipmentEffects) {
            EquipmentEffects.reset();
            EquipmentEffects.resetForBattle();
        }

        // Initialize turret system
        if (TurretSystem) {
            TurretSystem.clear();
        }

        // Initialize Raven system
        if (RavenSystem) {
            RavenSystem.init(GameState.currentRun?.difficulty || 'normal');
        }

        // Initialize wave generation system
        this.initWaveSystem();
    },

    initWaveSystem() {
        const combatRng = this.rng.get('combat');
        const difficulty = GameState.currentRun?.difficulty || 'normal';

        // Get spawn point positions in pixels
        const spawnPoints = this.stationLayout.spawnPoints.map(sp => ({
            x: this.offsetX + sp.x * this.tileSize + this.tileSize / 2,
            y: this.offsetY + sp.y * this.tileSize + this.tileSize / 2,
            direction: sp.direction,
        }));

        // Create wave generator
        if (typeof WaveGenerator !== 'undefined') {
            this.waveGenerator = new WaveGenerator(combatRng);

            const waveConfig = {
                depth: this.battleInfo.difficultyScore || this.battleInfo.difficulty || 1,
                difficulty: difficulty,
                isStorm: this.battleInfo.isStorm || this.battleInfo.type === 'storm',
                isBoss: this.battleInfo.isBoss || this.battleInfo.type === 'boss',
                spawnPoints: spawnPoints,
                tileSize: this.tileSize,
            };

            const waves = this.waveGenerator.generateWaves(waveConfig);
            this.totalWaves = waves.length;

            // Create wave manager
            this.waveManager = new WaveManager();
            this.waveManager.initialize(waves);

            // Set up event handlers
            this.waveManager.on('waveStart', (data) => {
                this.waveNumber = data.waveIndex + 1;
                this.showWaveAnnouncement(data.wave?.isBoss);
            });

            this.waveManager.on('enemySpawned', (data) => {
                if (data.enemy) {
                    this.enemies.push(data.enemy);
                }
            });

            console.log('Wave system initialized:', {
                totalWaves: this.totalWaves,
                isStorm: waveConfig.isStorm,
                isBoss: waveConfig.isBoss,
            });
        } else {
            // Fallback to basic wave system
            console.warn('WaveGenerator not available, using fallback');
            this.useFallbackWaves = true;
            this.totalWaves = 2 + (this.battleInfo.difficulty || 1);
            if (this.battleInfo.type === 'boss') {
                this.totalWaves = 1;
            }

            // Show warning to user
            if (typeof Toast !== 'undefined') {
                Toast.warning('웨이브 시스템 제한 모드로 실행 중');
            }
        }
    },

    setupBattle() {
        this.crews = [];
        this.deploymentData.deployedCrews.forEach(deploy => {
            const crewData = GameState.getCrewById(deploy.crewId);
            if (crewData) {
                const crew = this.createCrewEntity(crewData, deploy.x, deploy.y);
                this.crews.push(crew);

                // Initialize crew in systems
                if (SkillSystem) {
                    SkillSystem.initCrew(crew);
                }
                if (EquipmentEffects && crewData.equipment) {
                    EquipmentEffects.initCrew(crew, this);
                }
            }
        });

        this.enemies = [];
        this.projectiles = [];
        this.effects = [];
        this.turrets = [];
        this.mines = [];
        this.deadCrews = [];

        this.totalWaves = 2 + this.battleInfo.difficulty;
        if (this.battleInfo.type === 'boss') {
            this.totalWaves = 1;
        }

        this.createCrewButtons();
        this.createRavenButtons();
    },

    createCrewEntity(crewData, tileX, tileY) {
        const classData = CrewData ? CrewData.getClass(crewData.class) : GameState.getClassData(crewData.class);
        const baseStats = CrewData ? CrewData.getBaseStats(crewData.class) : {};

        return {
            id: crewData.id,
            name: crewData.name,
            class: crewData.class,
            color: classData?.color || '#4a9eff',
            trait: crewData.trait,
            equipment: crewData.equipment,

            // Position (in pixels)
            x: (tileX + 0.5) * this.tileSize + this.offsetX,
            y: (tileY + 0.5) * this.tileSize + this.offsetY,
            tileX: tileX,
            tileY: tileY,
            targetX: null,
            targetY: null,
            path: [],

            // Stats
            squadSize: crewData.squadSize,
            maxSquadSize: crewData.maxSquadSize,
            damage: baseStats.damage || (10 + crewData.skillLevel * 2),
            attackRange: baseStats.attackRange || (crewData.class === 'ranger' ? 200 : 60),
            attackSpeed: baseStats.attackSpeed || 1000,
            moveSpeed: baseStats.moveSpeed || 80,
            skillLevel: crewData.skillLevel || 1,

            // State
            state: 'idle',
            attackTimer: 0,
            targetEnemy: null,

            // Status effects
            invulnerable: false,
            invulnerableTimer: 0,
            shielded: false,
            shieldTimer: 0,
            shieldReduction: 0,
            shieldReflect: false,
            stunned: false,
            stunTimer: 0,
        };
    },

    createEnemyEntity(type, spawnX, spawnY) {
        const enemyData = EnemyData ? EnemyData.get(type) : null;

        const baseStats = enemyData?.stats || {
            health: 20,
            damage: 5,
            speed: 50,
            attackSpeed: 1500,
            attackRange: 40,
        };

        const visual = enemyData?.visual || {
            color: '#fc8181',
            size: 15,
        };

        const difficultyMult = 1 + (this.battleInfo.difficulty - 1) * 0.25;

        return {
            id: Utils.generateId(),
            type: type,
            x: spawnX,
            y: spawnY,
            targetX: null,
            targetY: null,
            path: [],

            health: Math.floor(baseStats.health * 10 * difficultyMult),
            maxHealth: Math.floor(baseStats.health * 10 * difficultyMult),
            damage: Math.floor(baseStats.damage * difficultyMult),
            speed: baseStats.speed,
            attackSpeed: baseStats.attackSpeed,
            attackRange: baseStats.attackRange,
            color: visual.color,
            size: visual.size,

            state: 'moving',
            attackTimer: 0,
            targetCrew: null,

            // Status effects
            stunned: false,
            stunTimer: 0,
            slowed: false,
            slowTimer: 0,
            slowAmount: 1,
            marked: false,
            markTimer: 0,
            illuminated: false,
            illuminatedTimer: 0,

            // Behavior data
            behavior: enemyData?.behavior || { id: 'melee_basic' },
            stats: baseStats,
        };
    },

    createCrewButtons() {
        const container = this.elements.crewButtons;
        if (!container) return;

        container.innerHTML = '';

        this.crews.forEach((crew, index) => {
            const btn = document.createElement('button');
            btn.className = `crew-btn ${crew.class}`;
            btn.dataset.crewId = crew.id;
            btn.innerHTML = `
                <span class="crew-key">${index + 1}</span>
                <span class="crew-name">${crew.name}</span>
                <div class="crew-health-mini">
                    <div class="fill" style="width: ${(crew.squadSize / crew.maxSquadSize) * 100}%"></div>
                </div>
                <div class="crew-skill-cd"></div>
            `;
            container.appendChild(btn);
        });
    },

    createRavenButtons() {
        const container = this.elements.ravenAbilities;
        if (!container || !RavenSystem) return;

        container.innerHTML = '';

        const abilities = RavenSystem.getAllAbilities();
        abilities.forEach(ability => {
            const btn = document.createElement('button');
            btn.className = 'raven-btn';
            btn.dataset.abilityId = ability.id;
            btn.innerHTML = `
                <span class="raven-icon">${ability.icon}</span>
                <span class="raven-name">${ability.name}</span>
                <span class="raven-uses">${ability.usesRemaining}</span>
            `;
            btn.disabled = !ability.ready;
            container.appendChild(btn);
        });
    },

    bindEvents() {
        // Mouse events
        this.canvas?.addEventListener('click', (e) => this.handleCanvasClick(e));
        this.canvas?.addEventListener('contextmenu', (e) => {
            e.preventDefault();
            this.handleCanvasRightClick(e);
        });
        this.canvas?.addEventListener('mousemove', (e) => this.handleCanvasMouseMove(e));

        // Touch events for mobile support
        this.canvas?.addEventListener('touchstart', (e) => this.handleTouchStart(e), { passive: false });
        this.canvas?.addEventListener('touchmove', (e) => this.handleTouchMove(e), { passive: false });
        this.canvas?.addEventListener('touchend', (e) => this.handleTouchEnd(e), { passive: false });

        this.elements.crewButtons?.addEventListener('click', (e) => {
            const btn = e.target.closest('.crew-btn');
            if (btn) {
                this.selectCrew(btn.dataset.crewId);
            }
        });

        this.elements.ravenAbilities?.addEventListener('click', (e) => {
            const btn = e.target.closest('.raven-btn');
            if (btn) {
                this.startRavenTargeting(btn.dataset.abilityId);
            }
        });

        document.addEventListener('keydown', (e) => this.handleKeyDown(e));

        this.elements.btnPause?.addEventListener('click', () => this.togglePause());
        this.elements.btnResume?.addEventListener('click', () => this.togglePause());
        this.elements.btnRetreatBattle?.addEventListener('click', () => this.retreatFromBattle());

        // Deselect button
        document.getElementById('btn-deselect')?.addEventListener('click', () => {
            this.selectedCrew = null;
            this.updateCrewButtonSelection();
        });

        window.addEventListener('resize', Utils.debounce(() => {
            this.resizeCanvas();
        }, 200));
    },

    // ==========================================
    // TOUCH SUPPORT
    // ==========================================

    touchStartTime: 0,
    touchStartPos: null,
    isDragging: false,

    handleTouchStart(e) {
        e.preventDefault();
        const touch = e.touches[0];
        this.touchStartTime = Date.now();
        this.touchStartPos = { x: touch.clientX, y: touch.clientY };
        this.isDragging = false;
    },

    handleTouchMove(e) {
        e.preventDefault();
        if (!this.touchStartPos) return;

        const touch = e.touches[0];
        const dx = touch.clientX - this.touchStartPos.x;
        const dy = touch.clientY - this.touchStartPos.y;

        // Start dragging if moved more than 10px
        if (Math.abs(dx) > 10 || Math.abs(dy) > 10) {
            this.isDragging = true;
        }

        // Update targeting position during drag
        if (this.targetingMode) {
            const rect = this.canvas.getBoundingClientRect();
            this.targetPosition = {
                x: touch.clientX - rect.left - this.shakeOffset.x,
                y: touch.clientY - rect.top - this.shakeOffset.y,
            };
        }
    },

    handleTouchEnd(e) {
        e.preventDefault();
        if (!this.touchStartPos) return;

        const touch = e.changedTouches[0];
        const touchDuration = Date.now() - this.touchStartTime;

        // Create a fake event for position handling
        const fakeEvent = {
            clientX: touch.clientX,
            clientY: touch.clientY,
        };

        if (this.isDragging) {
            // Handle drag end
            if (this.targetingMode) {
                const { x, y } = this.getAdjustedClickPosition(fakeEvent);
                this.executeTargetedAction(x, y);
            }
        } else {
            // Handle tap
            if (touchDuration < 300) {
                // Short tap = click
                this.handleCanvasClick(fakeEvent);
            } else {
                // Long press = right click (cancel/attack)
                this.handleCanvasRightClick(fakeEvent);
            }
        }

        this.touchStartPos = null;
        this.isDragging = false;
    },

    /**
     * Get click position adjusted for screen shake offset
     */
    getAdjustedClickPosition(e) {
        const rect = this.canvas.getBoundingClientRect();
        return {
            x: e.clientX - rect.left - this.shakeOffset.x,
            y: e.clientY - rect.top - this.shakeOffset.y,
        };
    },

    handleCanvasClick(e) {
        const { x, y } = this.getAdjustedClickPosition(e);

        // Handle targeting mode
        if (this.targetingMode) {
            this.executeTargetedAction(x, y);
            return;
        }

        if (this.selectedCrew) {
            // Move selected crew using pathfinding
            this.moveCrewTo(this.selectedCrew, x, y);
        } else {
            // Try to select a crew
            for (const crew of this.crews) {
                if (Utils.distance(x, y, crew.x, crew.y) < 25) {
                    this.selectCrew(crew.id);
                    return;
                }
            }
        }
    },

    handleCanvasRightClick(e) {
        const { x, y } = this.getAdjustedClickPosition(e);

        // Cancel targeting mode
        if (this.targetingMode) {
            this.cancelTargeting();
            return;
        }

        if (this.selectedCrew) {
            // Check if clicking on enemy - target for attack
            for (const enemy of this.enemies) {
                if (Utils.distance(x, y, enemy.x, enemy.y) < enemy.size + 10) {
                    this.selectedCrew.targetEnemy = enemy;
                    this.selectedCrew.state = 'attacking';
                    return;
                }
            }
        }
    },

    handleCanvasMouseMove(e) {
        if (!this.targetingMode) return;

        this.targetPosition = this.getAdjustedClickPosition(e);
    },

    handleKeyDown(e) {
        // Number keys for crew selection
        if (e.key >= '1' && e.key <= '9') {
            const index = parseInt(e.key) - 1;
            if (index < this.crews.length) {
                this.selectCrew(this.crews[index].id);
            }
        }

        // Escape to deselect or cancel targeting
        if (e.key === 'Escape') {
            if (this.targetingMode) {
                this.cancelTargeting();
            } else if (this.paused) {
                this.togglePause();
            } else {
                this.selectedCrew = null;
                this.updateCrewButtonSelection();
            }
        }

        // Space to pause/slow-mo toggle
        if (e.key === ' ') {
            e.preventDefault();
            this.togglePause();
        }

        // Q for skill
        if (e.key === 'q' || e.key === 'Q') {
            if (this.selectedCrew) {
                this.startSkillTargeting(this.selectedCrew);
            }
        }

        // E for equipment
        if (e.key === 'e' || e.key === 'E') {
            if (this.selectedCrew) {
                this.startEquipmentTargeting(this.selectedCrew);
            }
        }

        // Tab to activate slow motion
        if (e.key === 'Tab') {
            e.preventDefault();
            this.activateSlowMotion(2000);
        }
    },

    // ==========================================
    // CREW MOVEMENT WITH PATHFINDING
    // ==========================================

    moveCrewTo(crew, x, y) {
        if (!this.tileGrid) {
            // Fallback to direct movement
            crew.targetX = x;
            crew.targetY = y;
            crew.state = 'moving';
            return;
        }

        const startTile = this.tileGrid.pixelToTile(crew.x, crew.y, this.offsetX, this.offsetY);
        const endTile = this.tileGrid.pixelToTile(x, y, this.offsetX, this.offsetY);

        // Check if target tile is walkable
        if (!this.tileGrid.isWalkable(endTile.x, endTile.y)) {
            this.showMovementFeedback(x, y, 'blocked');
            return;
        }

        const path = this.tileGrid.findPath(startTile.x, startTile.y, endTile.x, endTile.y);

        if (path.length > 0) {
            crew.path = path.slice(1); // Remove start position
            crew.state = 'moving';
            crew.targetEnemy = null;

            // Store path for visual display
            crew.displayPath = path.map(tile =>
                this.tileGrid.tileToPixel(tile.x, tile.y, this.offsetX, this.offsetY)
            );

            // Move indicator effect
            this.addEffect({
                type: 'move_indicator',
                x: x,
                y: y,
                duration: 500,
                timer: 0,
            });
        } else {
            // Path not found - show feedback
            this.showMovementFeedback(x, y, 'no_path');
        }
    },

    /**
     * Show movement feedback (blocked, no path, out of range)
     */
    showMovementFeedback(x, y, reason) {
        const messages = {
            blocked: '이동 불가',
            no_path: '경로 없음',
            out_of_range: '사거리 초과',
        };

        this.addEffect({
            type: 'move_blocked',
            x: x,
            y: y,
            message: messages[reason] || '이동 불가',
            duration: 800,
            timer: 0,
        });

        // Optional: Show toast
        if (typeof Toast !== 'undefined') {
            Toast.warning(messages[reason] || '이동할 수 없습니다');
        }
    },

    // ==========================================
    // TARGETING SYSTEM
    // ==========================================

    startSkillTargeting(crew) {
        // Block during pause
        if (this.paused) return;

        if (!SkillSystem || !SkillSystem.isSkillReady(crew.id)) {
            return;
        }

        this.targetingMode = 'skill';
        this.targetingAbility = SkillSystem.getTargetingInfo(crew.id);
        this.activateSlowMotion(5000);
        this.canvas?.classList.add('targeting');
    },

    startEquipmentTargeting(crew) {
        // Block during pause
        if (this.paused) return;

        if (!EquipmentEffects || !EquipmentEffects.canUse(crew.id)) {
            return;
        }

        this.targetingMode = 'equipment';
        this.targetingAbility = EquipmentEffects.getState(crew.id);
        this.activateSlowMotion(5000);
        this.canvas?.classList.add('targeting');
    },

    startRavenTargeting(abilityId) {
        // Block during pause
        if (this.paused) return;

        if (!RavenSystem || !RavenSystem.canUse(abilityId)) {
            return;
        }

        this.targetingMode = 'raven';
        this.targetingAbility = RavenSystem.getAbilityInfo(abilityId);
        this.activateSlowMotion(5000);
        this.canvas?.classList.add('targeting');
    },

    cancelTargeting() {
        this.targetingMode = null;
        this.targetingAbility = null;
        this.targetPosition = null;
        this.deactivateSlowMotion();
        this.canvas?.classList.remove('targeting');
    },

    executeTargetedAction(x, y) {
        const target = { x, y };

        switch (this.targetingMode) {
            case 'skill':
                if (this.selectedCrew) {
                    SkillSystem.useSkill(this.selectedCrew, target, this);
                }
                break;

            case 'equipment':
                if (this.selectedCrew) {
                    EquipmentEffects.use(this.selectedCrew, target, this);
                }
                break;

            case 'raven':
                if (this.targetingAbility) {
                    RavenSystem.useAbility(this.targetingAbility.id, target, this);
                    this.updateRavenButtons();
                }
                break;
        }

        this.cancelTargeting();
    },

    // ==========================================
    // SLOW MOTION SYSTEM
    // ==========================================

    activateSlowMotion(duration) {
        this.slowMotionActive = true;
        this.slowMotionDuration = duration;
        this.timeScale = this.SLOW_MOTION_SCALE;
        this.elements.slowMotionIndicator?.classList.add('active');
    },

    deactivateSlowMotion() {
        this.slowMotionActive = false;
        this.slowMotionDuration = 0;
        this.timeScale = 1;
        this.elements.slowMotionIndicator?.classList.remove('active');
    },

    updateSlowMotion(dt) {
        if (this.slowMotionActive && this.slowMotionDuration > 0) {
            this.slowMotionDuration -= dt / this.timeScale; // Real time
            if (this.slowMotionDuration <= 0 && !this.targetingMode) {
                this.deactivateSlowMotion();
            }
        }
    },

    // ==========================================
    // SCREEN SHAKE
    // ==========================================

    screenShake(amount, duration) {
        this.shakeAmount = amount;
        this.shakeDuration = duration;
    },

    updateScreenShake(dt) {
        if (this.shakeDuration > 0) {
            this.shakeDuration -= dt;
            this.shakeOffset = {
                x: (Math.random() - 0.5) * this.shakeAmount,
                y: (Math.random() - 0.5) * this.shakeAmount,
            };
        } else {
            this.shakeOffset = { x: 0, y: 0 };
        }
    },

    // ==========================================
    // SELECTION
    // ==========================================

    selectCrew(crewId) {
        this.selectedCrew = this.crews.find(c => c.id === crewId) || null;
        this.updateCrewButtonSelection();
    },

    updateCrewButtonSelection() {
        document.querySelectorAll('.crew-btn').forEach(btn => {
            btn.classList.toggle('selected', btn.dataset.crewId === this.selectedCrew?.id);
        });
    },

    togglePause() {
        this.paused = !this.paused;
        this.elements.pauseMenu?.classList.toggle('active', this.paused);

        if (!this.paused) {
            this.lastTime = performance.now();
            this.gameLoop();
        }
    },

    // ==========================================
    // GAME LOOP
    // ==========================================

    startBattle() {
        this.running = true;
        this.waveNumber = 0;
        this.lastTime = performance.now();
        this.spawnNextWave();
        this.gameLoop();
    },

    gameLoop(currentTime = performance.now()) {
        if (!this.running || this.paused) return;

        const realDt = currentTime - this.lastTime;
        this.lastTime = currentTime;

        // Apply time scale
        this.deltaTime = realDt * this.timeScale;

        this.update(this.deltaTime);
        this.render();

        requestAnimationFrame((t) => this.gameLoop(t));
    },

    update(dt) {
        // Update slow motion
        this.updateSlowMotion(dt);

        // Update screen shake
        this.updateScreenShake(dt);

        // Update wave spawning
        if (this.waveManager) {
            // Use WaveManager for spawning
            const difficulty = GameState.currentRun?.difficulty || 'normal';
            this.waveManager.update(dt, difficulty);

            // Check if wave is cleared and start next
            if (this.waveManager.isWaveCleared(this.enemies) && !this.waveManager.isAllWavesComplete()) {
                this.waveTimer += dt;
                if (this.waveTimer >= this.waveDelay) {
                    this.spawnNextWave();
                }
            }

            // Update progress
            const progress = this.waveManager.getProgress();
            this.waveNumber = progress.currentWave;
        } else {
            // Fallback wave logic
            if (this.enemies.length === 0 && this.waveNumber < this.totalWaves) {
                this.waveTimer += dt;
                if (this.waveTimer >= this.waveDelay) {
                    this.spawnNextWave();
                }
            }
        }

        // Update systems
        if (SkillSystem) SkillSystem.update(dt);
        if (EquipmentEffects) EquipmentEffects.update(dt, this);
        if (TurretSystem) TurretSystem.update(dt, this);
        if (RavenSystem) RavenSystem.update(dt, this);

        // Update crews
        this.crews.forEach(crew => this.updateCrew(crew, dt));

        // Update enemies
        this.enemies.forEach(enemy => this.updateEnemy(enemy, dt));

        // Update projectiles
        this.projectiles = this.projectiles.filter(p => this.updateProjectile(p, dt));

        // Update effects
        this.effects = this.effects.filter(e => {
            e.timer += dt;
            return e.timer < e.duration;
        });

        // Remove dead enemies
        this.enemies = this.enemies.filter(e => e.health > 0);

        // Check battle end
        this.checkBattleEnd();

        // Update HUD
        this.updateHUD();
        this.updateCrewButtons();
    },

    updateCrew(crew, dt) {
        // Update status effects
        if (crew.invulnerable && crew.invulnerableTimer > 0) {
            crew.invulnerableTimer -= dt;
            if (crew.invulnerableTimer <= 0) crew.invulnerable = false;
        }
        if (crew.stunned && crew.stunTimer > 0) {
            crew.stunTimer -= dt;
            if (crew.stunTimer <= 0) crew.stunned = false;
            return; // Can't act while stunned
        }

        // Reduce attack timer
        crew.attackTimer -= dt;

        switch (crew.state) {
            case 'moving':
                this.updateCrewMovement(crew, dt);
                break;

            case 'attacking':
                this.updateCrewAttacking(crew, dt);
                break;

            case 'idle':
                // Auto-target nearby enemies
                const nearestEnemy = this.findNearestEnemy(crew);
                if (nearestEnemy && Utils.distance(crew.x, crew.y, nearestEnemy.x, nearestEnemy.y) <= crew.attackRange * 1.5) {
                    crew.targetEnemy = nearestEnemy;
                    crew.state = 'attacking';
                }
                break;
        }
    },

    updateCrewMovement(crew, dt) {
        if (crew.path && crew.path.length > 0) {
            // Pathfinding movement
            const nextTile = crew.path[0];
            const targetPixel = this.tileGrid.tileToPixel(nextTile.x, nextTile.y, this.offsetX, this.offsetY);

            const dist = Utils.distance(crew.x, crew.y, targetPixel.x, targetPixel.y);
            if (dist > 3) {
                const angle = Utils.angleBetween(crew.x, crew.y, targetPixel.x, targetPixel.y);
                let moveSpeed = crew.moveSpeed;

                // Apply trait bonus
                if (crew.trait === 'swiftMovement') moveSpeed *= 1.33;

                const moveAmount = moveSpeed * (dt / 1000);
                crew.x += Math.cos(angle) * moveAmount;
                crew.y += Math.sin(angle) * moveAmount;
            } else {
                crew.path.shift();
                if (crew.path.length === 0) {
                    crew.state = 'idle';
                }
            }
        } else if (crew.targetX !== null && crew.targetY !== null) {
            // Direct movement fallback
            const dist = Utils.distance(crew.x, crew.y, crew.targetX, crew.targetY);
            if (dist > 5) {
                const angle = Utils.angleBetween(crew.x, crew.y, crew.targetX, crew.targetY);
                const moveAmount = crew.moveSpeed * (dt / 1000);
                crew.x += Math.cos(angle) * moveAmount;
                crew.y += Math.sin(angle) * moveAmount;
            } else {
                crew.state = 'idle';
                crew.targetX = null;
                crew.targetY = null;
            }
        } else {
            crew.state = 'idle';
        }
    },

    updateCrewAttacking(crew, dt) {
        if (!crew.targetEnemy || crew.targetEnemy.health <= 0) {
            crew.targetEnemy = null;
            crew.state = 'idle';
            return;
        }

        const dist = Utils.distance(crew.x, crew.y, crew.targetEnemy.x, crew.targetEnemy.y);

        if (dist <= crew.attackRange) {
            // In range - attack
            if (crew.attackTimer <= 0) {
                this.crewAttack(crew, crew.targetEnemy);
                crew.attackTimer = crew.attackSpeed;
            }
        } else {
            // Move towards enemy
            const angle = Utils.angleBetween(crew.x, crew.y, crew.targetEnemy.x, crew.targetEnemy.y);
            const moveAmount = crew.moveSpeed * (dt / 1000);
            crew.x += Math.cos(angle) * moveAmount;
            crew.y += Math.sin(angle) * moveAmount;
        }
    },

    updateEnemy(enemy, dt) {
        // Update status effects
        if (enemy.stunned && enemy.stunTimer > 0) {
            enemy.stunTimer -= dt;
            if (enemy.stunTimer <= 0) enemy.stunned = false;
            return;
        }
        if (enemy.slowed && enemy.slowTimer > 0) {
            enemy.slowTimer -= dt;
            if (enemy.slowTimer <= 0) {
                enemy.slowed = false;
                enemy.slowAmount = 1;
            }
        }

        enemy.attackTimer -= dt;

        const nearestCrew = this.findNearestCrew(enemy);
        const effectiveSpeed = enemy.speed * (enemy.slowed ? enemy.slowAmount : 1);

        if (nearestCrew) {
            const dist = Utils.distance(enemy.x, enemy.y, nearestCrew.x, nearestCrew.y);

            if (dist <= enemy.attackRange) {
                if (enemy.attackTimer <= 0) {
                    this.enemyAttack(enemy, nearestCrew);
                    enemy.attackTimer = enemy.attackSpeed;
                }
            } else {
                const angle = Utils.angleBetween(enemy.x, enemy.y, nearestCrew.x, nearestCrew.y);
                const moveAmount = effectiveSpeed * (dt / 1000);
                enemy.x += Math.cos(angle) * moveAmount;
                enemy.y += Math.sin(angle) * moveAmount;
            }
        } else {
            // Move to station center
            const centerX = this.canvas.width / 2;
            const centerY = this.canvas.height / 2;
            const dist = Utils.distance(enemy.x, enemy.y, centerX, centerY);

            if (dist > 50) {
                const angle = Utils.angleBetween(enemy.x, enemy.y, centerX, centerY);
                const moveAmount = effectiveSpeed * (dt / 1000);
                enemy.x += Math.cos(angle) * moveAmount;
                enemy.y += Math.sin(angle) * moveAmount;
            } else {
                if (enemy.attackTimer <= 0) {
                    this.stationHealth -= enemy.damage / 5;
                    enemy.attackTimer = enemy.attackSpeed;
                }
            }
        }
    },

    updateProjectile(proj, dt) {
        const moveAmount = proj.speed * (dt / 1000);
        proj.x += Math.cos(proj.angle) * moveAmount;
        proj.y += Math.sin(proj.angle) * moveAmount;

        // Check collision with target
        if (proj.target) {
            const targetHealth = proj.target.health !== undefined ? proj.target.health : proj.target.squadSize;
            if (targetHealth > 0) {
                const targetSize = proj.target.size || 20;
                if (Utils.distance(proj.x, proj.y, proj.target.x, proj.target.y) < targetSize + 5) {
                    // Apply damage
                    if (proj.target.health !== undefined) {
                        // Enemy target
                        let damage = proj.damage;

                        // Check shield
                        if (proj.target.shielded) {
                            damage *= (1 - (proj.target.shieldReduction || 0));
                        }

                        proj.target.health -= damage;
                        this.addDamageNumber(proj.target.x, proj.target.y, Math.floor(damage));

                        // Apply slow from turret
                        if (proj.applySlows && proj.slowAmount) {
                            proj.target.slowed = true;
                            proj.target.slowTimer = proj.slowDuration;
                            proj.target.slowAmount = proj.slowAmount;
                        }
                    } else {
                        // Crew target (from hacked turret)
                        proj.target.squadSize--;
                        this.addDamageNumber(proj.target.x, proj.target.y, 1, true);
                    }

                    if (!proj.piercing) return false;
                }
            }
        }

        // Out of bounds
        if (proj.x < 0 || proj.x > this.canvas.width || proj.y < 0 || proj.y > this.canvas.height) {
            return false;
        }

        return true;
    },

    crewAttack(crew, enemy) {
        // Check for assassination bonus (bionic)
        let damage = crew.damage;
        if (crew.class === 'bionic') {
            const classData = CrewData?.getClass('bionic');
            if (classData?.assassinationBonus && !enemy.targetCrew) {
                damage *= classData.assassinationBonus.damageMultiplier;
            }
        }

        // Apply trait bonuses
        if (crew.trait === 'sharpEdge') damage *= 1.2;

        if (crew.class === 'ranger') {
            // Ranged attack
            this.projectiles.push({
                x: crew.x,
                y: crew.y,
                angle: Utils.angleBetween(crew.x, crew.y, enemy.x, enemy.y),
                speed: 400,
                damage: damage,
                target: enemy,
                color: crew.color,
            });
        } else {
            // Melee attack
            enemy.health -= damage;
            this.addDamageNumber(enemy.x, enemy.y, Math.floor(damage));

            this.addEffect({
                type: 'melee_hit',
                x: enemy.x,
                y: enemy.y,
                duration: 200,
                timer: 0,
                color: crew.color,
            });
        }
    },

    enemyAttack(enemy, crew) {
        if (crew.invulnerable) return;

        let damage = 1; // Squad members lost
        if (crew.shielded) {
            damage = Math.max(0, Math.round(damage * (1 - crew.shieldReduction)));
        }

        crew.squadSize -= damage;
        this.addDamageNumber(crew.x, crew.y, enemy.damage, true);

        if (crew.squadSize <= 0) {
            this.deadCrews.push(crew);
            this.crews = this.crews.filter(c => c.id !== crew.id);
            this.addEffect({
                type: 'death',
                x: crew.x,
                y: crew.y,
                duration: 500,
                timer: 0,
            });
        }
    },

    findNearestEnemy(crew) {
        let nearest = null;
        let nearestDist = Infinity;

        for (const enemy of this.enemies) {
            const dist = Utils.distance(crew.x, crew.y, enemy.x, enemy.y);
            if (dist < nearestDist) {
                nearestDist = dist;
                nearest = enemy;
            }
        }

        return nearest;
    },

    findNearestCrew(enemy) {
        let nearest = null;
        let nearestDist = Infinity;

        for (const crew of this.crews) {
            const dist = Utils.distance(enemy.x, enemy.y, crew.x, crew.y);
            if (dist < nearestDist) {
                nearestDist = dist;
                nearest = crew;
            }
        }

        return nearest;
    },

    spawnNextWave() {
        this.waveTimer = 0;

        // Use WaveManager if available
        if (this.waveManager) {
            const difficulty = GameState.currentRun?.difficulty || 'normal';
            const started = this.waveManager.startNextWave(difficulty);

            if (!started) {
                // All waves complete
                return;
            }
            return;
        }

        // Fallback spawning
        this.waveNumber++;
        this.showWaveAnnouncement();

        const enemyCount = 3 + this.waveNumber * 2 + (this.battleInfo.difficulty || 1);
        const combatRng = this.rng.get('combat');

        this.stationLayout.spawnPoints.forEach(spawn => {
            const spawnX = this.offsetX + spawn.x * this.tileSize + this.tileSize / 2;
            const spawnY = this.offsetY + spawn.y * this.tileSize + this.tileSize / 2;

            const countAtSpawn = Math.ceil(enemyCount / this.stationLayout.spawnPoints.length);

            for (let i = 0; i < countAtSpawn; i++) {
                let type = 'rusher';
                const roll = combatRng.random();

                if (this.battleInfo.type === 'boss' && i === 0) {
                    type = 'pirateCaptain';
                } else if (roll > 0.9 && this.waveNumber >= 2) {
                    type = 'brute';
                } else if (roll > 0.7) {
                    type = 'gunner';
                } else if (roll > 0.5) {
                    type = 'shieldTrooper';
                }

                setTimeout(() => {
                    const offsetX = combatRng.range(-20, 20);
                    const offsetY = combatRng.range(-20, 20);
                    this.enemies.push(this.createEnemyEntity(type, spawnX + offsetX, spawnY + offsetY));
                }, i * 300);
            }
        });
    },

    showWaveAnnouncement(isBossWave = false) {
        if (this.elements.waveAnnouncement && this.elements.waveText) {
            let text;
            if (isBossWave || this.battleInfo.type === 'boss') {
                text = '💀 보스 등장!';
                this.elements.waveAnnouncement.classList.add('boss');
            } else if (this.battleInfo.type === 'storm' || this.battleInfo.isStorm) {
                text = `⚡ 웨이브 ${this.waveNumber}/${this.totalWaves}`;
                this.elements.waveAnnouncement.classList.add('storm');
            } else {
                text = `웨이브 ${this.waveNumber}/${this.totalWaves}`;
            }

            this.elements.waveText.textContent = text;
            this.elements.waveAnnouncement.classList.add('active');

            // Screen shake for boss
            if (isBossWave || this.battleInfo.type === 'boss') {
                this.screenShake(10, 500);
            }

            setTimeout(() => {
                this.elements.waveAnnouncement.classList.remove('active', 'boss', 'storm');
            }, 2500);
        }
    },

    addDamageNumber(x, y, damage, isCrewDamage = false) {
        this.effects.push({
            type: 'damage_number',
            x: x + (Math.random() - 0.5) * 20,
            y: y - 10,
            damage: typeof damage === 'number' ? Math.floor(damage) : damage,
            duration: 1000,
            timer: 0,
            isCrewDamage,
        });
    },

    addEffect(effect) {
        this.effects.push(effect);
    },

    updateHUD() {
        if (this.elements.hudWave) {
            this.elements.hudWave.textContent = `${this.waveNumber}/${this.totalWaves}`;
        }
        if (this.elements.hudEnemies) {
            this.elements.hudEnemies.textContent = this.enemies.length;
        }
        if (this.elements.hudStation) {
            this.elements.hudStation.textContent = `${Math.floor(this.stationHealth)}%`;
        }
        if (this.elements.stationHealthBar) {
            this.elements.stationHealthBar.style.width = `${this.stationHealth}%`;
            this.elements.stationHealthBar.style.background =
                this.stationHealth > 50 ? '#48bb78' :
                this.stationHealth > 25 ? '#f6ad55' : '#fc8181';
        }
    },

    updateCrewButtons() {
        this.crews.forEach(crew => {
            const btn = document.querySelector(`.crew-btn[data-crew-id="${crew.id}"]`);
            if (btn) {
                const healthFill = btn.querySelector('.fill');
                if (healthFill) {
                    healthFill.style.width = `${(crew.squadSize / crew.maxSquadSize) * 100}%`;
                }

                // Update skill cooldown indicator
                const skillCd = btn.querySelector('.crew-skill-cd');
                if (skillCd && SkillSystem) {
                    const cdPercent = SkillSystem.getCooldownPercent(crew.id);
                    skillCd.style.width = `${cdPercent * 100}%`;
                }
            }
        });

        document.querySelectorAll('.crew-btn').forEach(btn => {
            if (!this.crews.find(c => c.id === btn.dataset.crewId)) {
                btn.classList.add('dead');
            }
        });
    },

    updateRavenButtons() {
        if (!RavenSystem) return;

        document.querySelectorAll('.raven-btn').forEach(btn => {
            const abilityId = btn.dataset.abilityId;
            const ability = RavenSystem.getAbilityInfo(abilityId);
            if (ability) {
                btn.disabled = !ability.ready;
                const usesSpan = btn.querySelector('.raven-uses');
                if (usesSpan) usesSpan.textContent = ability.usesRemaining;
            }
        });
    },

    checkBattleEnd() {
        // Victory condition
        const allWavesComplete = this.waveManager
            ? this.waveManager.isAllWavesComplete() && this.enemies.length === 0
            : this.waveNumber >= this.totalWaves && this.enemies.length === 0;

        if (allWavesComplete) {
            this.endBattle(true);
            return;
        }

        // Defeat conditions
        if (this.stationHealth <= 0) {
            this.endBattle(false);
            return;
        }

        if (this.crews.length === 0) {
            this.endBattle(false);
            return;
        }

        // Check facilities if using new station layout
        if (this.stationLayout.facilities) {
            const allFacilitiesDestroyed = this.stationLayout.facilities.every(f => f.destroyed);
            if (allFacilitiesDestroyed) {
                this.stationHealth = 0;
                this.endBattle(false);
                return;
            }
        }
    },

    endBattle(victory) {
        this.running = false;

        // Calculate bonus credits from salvage cores
        let bonusCredits = 0;
        if (EquipmentEffects) {
            bonusCredits = EquipmentEffects.calculateBonusCredits(this.crews);
        }

        // Update crew states
        const aliveCrewIds = this.crews.map(c => c.id);
        GameState.currentRun.crews.forEach(crew => {
            const battleCrew = this.crews.find(c => c.id === crew.id);
            if (battleCrew) {
                crew.squadSize = battleCrew.squadSize;
                crew.health = battleCrew.squadSize;
                crew.battlesParticipated++;
            } else if (this.deploymentData.deployedCrews.find(d => d.crewId === crew.id)) {
                crew.isAlive = false;
                crew.squadSize = 0;
                GameState.currentRun.stats.crewsLost++;
            }
        });

        const enemiesKilled = this.waveNumber * 5;
        GameState.recordEnemiesKilled(enemiesKilled);

        if (victory) {
            const baseCredits = this.battleInfo.reward.credits || 50;
            GameState.recordStationDefended(baseCredits + bonusCredits, this.stationHealth >= 100);
        } else {
            GameState.currentRun.stats.stationsLost++;
        }

        sessionStorage.setItem('battleResult', JSON.stringify({
            victory,
            stationHealth: this.stationHealth,
            enemiesKilled,
            wavesCompleted: this.waveNumber,
            totalWaves: this.totalWaves,
            reward: victory ? this.battleInfo.reward : null,
            battleType: this.battleInfo.type,
            bonusCredits,
        }));

        sessionStorage.removeItem('deploymentData');
        sessionStorage.removeItem('currentBattle');

        GameState.advanceTurn();
        Utils.navigateTo('result');
    },

    retreatFromBattle() {
        if (confirm('전투에서 후퇴하시겠습니까? 보상을 받지 못합니다.')) {
            this.endBattle(false);
        }
    },

    // ==========================================
    // RENDERING
    // ==========================================

    render() {
        const ctx = this.ctx;
        if (!ctx) return;

        ctx.save();

        // Apply screen shake
        ctx.translate(this.shakeOffset.x, this.shakeOffset.y);

        // Clear
        ctx.fillStyle = '#0a0a12';
        ctx.fillRect(-10, -10, this.canvas.width + 20, this.canvas.height + 20);

        // Draw station
        this.renderStation();

        // Render Raven effects
        if (RavenSystem) RavenSystem.render(ctx, this);

        // Draw effects (below entities)
        this.effects.filter(e => e.type === 'shockwave' || e.type === 'volley' || e.type === 'target_area').forEach(e => this.renderEffect(e));

        // Draw mines
        this.renderMines();

        // Draw movement paths
        this.renderMovementPaths();

        // Draw turrets
        if (TurretSystem) TurretSystem.render(ctx, this);

        // Draw enemies
        this.enemies.forEach(e => this.renderEnemy(e));

        // Draw crews
        this.crews.forEach(c => this.renderCrew(c));

        // Draw projectiles
        this.projectiles.forEach(p => this.renderProjectile(p));

        // Draw effects (above entities)
        this.effects.filter(e => e.type !== 'shockwave' && e.type !== 'volley' && e.type !== 'target_area').forEach(e => this.renderEffect(e));

        // Draw selection indicator
        if (this.selectedCrew) {
            ctx.strokeStyle = '#fff';
            ctx.lineWidth = 2;
            ctx.setLineDash([4, 4]);
            ctx.beginPath();
            ctx.arc(this.selectedCrew.x, this.selectedCrew.y, 30, 0, Math.PI * 2);
            ctx.stroke();
            ctx.setLineDash([]);
        }

        // Draw targeting indicator
        if (this.targetingMode && this.targetPosition) {
            this.renderTargetingIndicator();
        }

        ctx.restore();
    },

    renderStation() {
        const ctx = this.ctx;

        // Tile type colors (supports both old format and new StationGenerator format)
        const tileColors = {
            // Old format
            'floor': '#1a1a2e',
            'wall': '#2d2d44',
            'cover': '#252538',
            // New StationGenerator format (numeric types)
            0: '#0a0a12',     // VOID - space
            1: '#1a1a2e',     // FLOOR
            2: '#2d2d44',     // WALL
            3: '#1e3a5f',     // FACILITY
            4: '#3d1a1a',     // AIRLOCK (spawn)
            5: '#252538',     // ELEVATED (high ground)
            6: '#12121a',     // LOWERED
            7: '#1a1a2e',     // CORRIDOR
        };

        for (let y = 0; y < this.stationLayout.height; y++) {
            for (let x = 0; x < this.stationLayout.width; x++) {
                const tile = this.stationLayout.tiles[y][x];
                const px = this.offsetX + x * this.tileSize;
                const py = this.offsetY + y * this.tileSize;

                // Support both object format ({type: 'floor'}) and numeric format
                const tileType = typeof tile === 'object' ? tile.type : tile;
                ctx.fillStyle = tileColors[tileType] || '#1a1a2e';
                ctx.fillRect(px + 1, py + 1, this.tileSize - 2, this.tileSize - 2);

                // Add visual indicators for special tiles
                if (tileType === 5 || tileType === 'elevated') {
                    // High ground indicator
                    ctx.fillStyle = 'rgba(255, 255, 255, 0.1)';
                    ctx.fillRect(px + 1, py + 1, this.tileSize - 2, this.tileSize - 2);
                } else if (tileType === 6 || tileType === 'lowered') {
                    // Low ground shadow
                    ctx.fillStyle = 'rgba(0, 0, 0, 0.2)';
                    ctx.fillRect(px + 1, py + 1, this.tileSize - 2, this.tileSize - 2);
                }
            }
        }

        // Render facilities with credit values
        if (this.stationLayout.facilities) {
            this.stationLayout.facilities.forEach(facility => {
                if (facility.destroyed) return;

                const px = this.offsetX + facility.x * this.tileSize;
                const py = this.offsetY + facility.y * this.tileSize;
                const width = (facility.width || 1) * this.tileSize;
                const height = (facility.height || 1) * this.tileSize;

                // Facility background
                ctx.fillStyle = '#1e4d3d';
                ctx.fillRect(px + 2, py + 2, width - 4, height - 4);

                // Facility border
                ctx.strokeStyle = '#48bb78';
                ctx.lineWidth = 2;
                ctx.strokeRect(px + 2, py + 2, width - 4, height - 4);

                // Credit value
                if (facility.credits) {
                    ctx.fillStyle = '#f6e05e';
                    ctx.font = 'bold 10px sans-serif';
                    ctx.textAlign = 'center';
                    ctx.textBaseline = 'middle';
                    ctx.fillText(`$${facility.credits}`, px + width / 2, py + height / 2);
                }

                // Facility icon (if available)
                if (facility.type) {
                    const icons = {
                        residential: '🏠',
                        medical: '🏥',
                        armory: '🔫',
                        commTower: '📡',
                        powerPlant: '⚡',
                    };
                    const icon = icons[facility.type];
                    if (icon) {
                        ctx.font = '12px sans-serif';
                        ctx.fillText(icon, px + width / 2, py + height / 2 - 8);
                    }
                }
            });
        }

        // Render spawn points
        this.stationLayout.spawnPoints.forEach(spawn => {
            const px = this.offsetX + spawn.x * this.tileSize + this.tileSize / 2;
            const py = this.offsetY + spawn.y * this.tileSize + this.tileSize / 2;

            ctx.fillStyle = 'rgba(252, 129, 129, 0.2)';
            ctx.beginPath();
            ctx.arc(px, py, this.tileSize / 2, 0, Math.PI * 2);
            ctx.fill();

            // Direction indicator
            if (spawn.direction) {
                const dirs = { north: -Math.PI/2, south: Math.PI/2, east: 0, west: Math.PI };
                const angle = dirs[spawn.direction] || 0;
                ctx.strokeStyle = 'rgba(252, 129, 129, 0.5)';
                ctx.lineWidth = 2;
                ctx.beginPath();
                ctx.moveTo(px, py);
                ctx.lineTo(px + Math.cos(angle) * this.tileSize * 0.8, py + Math.sin(angle) * this.tileSize * 0.8);
                ctx.stroke();
            }
        });
    },

    renderCrew(crew) {
        const ctx = this.ctx;

        // Invulnerability effect
        if (crew.invulnerable) {
            ctx.fillStyle = 'rgba(183, 148, 244, 0.3)';
            ctx.beginPath();
            ctx.arc(crew.x, crew.y, 28, 0, Math.PI * 2);
            ctx.fill();
        }

        // Shield effect
        if (crew.shielded) {
            ctx.strokeStyle = 'rgba(99, 179, 237, 0.7)';
            ctx.lineWidth = 3;
            ctx.beginPath();
            ctx.arc(crew.x, crew.y, 26, 0, Math.PI * 2);
            ctx.stroke();
        }

        // Crew circle
        ctx.fillStyle = crew.color;
        ctx.beginPath();
        ctx.arc(crew.x, crew.y, 20, 0, Math.PI * 2);
        ctx.fill();

        // Border
        ctx.strokeStyle = '#fff';
        ctx.lineWidth = 2;
        ctx.stroke();

        // Name initial
        ctx.fillStyle = '#fff';
        ctx.font = 'bold 14px sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText(crew.name[0], crew.x, crew.y);

        // Health bar
        const healthPct = crew.squadSize / crew.maxSquadSize;
        const barWidth = 30;
        const barHeight = 4;
        const barX = crew.x - barWidth / 2;
        const barY = crew.y - 30;

        ctx.fillStyle = '#333';
        ctx.fillRect(barX, barY, barWidth, barHeight);
        ctx.fillStyle = healthPct > 0.5 ? '#48bb78' : healthPct > 0.25 ? '#f6ad55' : '#fc8181';
        ctx.fillRect(barX, barY, barWidth * healthPct, barHeight);

        // Squad count
        ctx.fillStyle = '#fff';
        ctx.font = '10px sans-serif';
        ctx.fillText(crew.squadSize, crew.x, barY - 8);

        // Skill cooldown indicator
        if (SkillSystem) {
            const cdPct = SkillSystem.getCooldownPercent(crew.id);
            if (cdPct > 0) {
                ctx.strokeStyle = 'rgba(255, 255, 255, 0.3)';
                ctx.lineWidth = 3;
                ctx.beginPath();
                ctx.arc(crew.x, crew.y, 23, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * (1 - cdPct));
                ctx.stroke();
            }
        }

        // Stun indicator
        if (crew.stunned) {
            ctx.fillStyle = '#fff';
            ctx.font = '12px sans-serif';
            ctx.fillText('💫', crew.x, crew.y - 35);
        }
    },

    renderEnemy(enemy) {
        const ctx = this.ctx;

        // Enemy circle
        ctx.fillStyle = enemy.color;
        ctx.beginPath();
        ctx.arc(enemy.x, enemy.y, enemy.size, 0, Math.PI * 2);
        ctx.fill();

        // Marked indicator
        if (enemy.marked) {
            ctx.strokeStyle = '#4a9eff';
            ctx.lineWidth = 2;
            ctx.setLineDash([3, 3]);
            ctx.beginPath();
            ctx.arc(enemy.x, enemy.y, enemy.size + 5, 0, Math.PI * 2);
            ctx.stroke();
            ctx.setLineDash([]);
        }

        // Illuminated indicator
        if (enemy.illuminated) {
            ctx.fillStyle = 'rgba(246, 173, 85, 0.2)';
            ctx.beginPath();
            ctx.arc(enemy.x, enemy.y, enemy.size + 8, 0, Math.PI * 2);
            ctx.fill();
        }

        // Stun indicator
        if (enemy.stunned) {
            ctx.fillStyle = '#fff';
            ctx.font = '12px sans-serif';
            ctx.textAlign = 'center';
            ctx.fillText('💫', enemy.x, enemy.y - enemy.size - 5);
        }

        // Slow indicator
        if (enemy.slowed) {
            ctx.fillStyle = '#63b3ed';
            ctx.font = '10px sans-serif';
            ctx.textAlign = 'center';
            ctx.fillText('❄️', enemy.x, enemy.y);
        }

        // Health bar
        const healthPct = enemy.health / enemy.maxHealth;
        const barWidth = enemy.size * 2;
        const barHeight = 3;
        const barX = enemy.x - barWidth / 2;
        const barY = enemy.y - enemy.size - 8;

        ctx.fillStyle = '#333';
        ctx.fillRect(barX, barY, barWidth, barHeight);
        ctx.fillStyle = '#fc8181';
        ctx.fillRect(barX, barY, barWidth * healthPct, barHeight);

        // Boss indicator
        if (enemy.type === 'pirateCaptain' || enemy.type === 'stormCore') {
            ctx.fillStyle = '#fff';
            ctx.font = 'bold 16px sans-serif';
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            ctx.fillText('👹', enemy.x, enemy.y);
        }
    },

    renderProjectile(proj) {
        const ctx = this.ctx;

        ctx.fillStyle = proj.color || '#4a9eff';
        ctx.beginPath();
        ctx.arc(proj.x, proj.y, 4, 0, Math.PI * 2);
        ctx.fill();

        // Trail
        ctx.strokeStyle = proj.color || '#4a9eff';
        ctx.lineWidth = 2;
        ctx.globalAlpha = 0.5;
        ctx.beginPath();
        ctx.moveTo(proj.x, proj.y);
        ctx.lineTo(
            proj.x - Math.cos(proj.angle) * 15,
            proj.y - Math.sin(proj.angle) * 15
        );
        ctx.stroke();
        ctx.globalAlpha = 1;
    },

    renderMines() {
        const ctx = this.ctx;
        if (!this.mines) return;

        for (const mine of this.mines) {
            ctx.fillStyle = mine.triggered ? '#fc8181' : '#68d391';
            ctx.beginPath();
            ctx.arc(mine.x, mine.y, 8, 0, Math.PI * 2);
            ctx.fill();

            ctx.strokeStyle = '#fff';
            ctx.lineWidth = 1;
            ctx.stroke();

            // Warning indicator when triggered
            if (mine.triggered) {
                ctx.strokeStyle = 'rgba(252, 129, 129, 0.5)';
                ctx.lineWidth = 2;
                ctx.beginPath();
                ctx.arc(mine.x, mine.y, mine.radius, 0, Math.PI * 2);
                ctx.stroke();
            }
        }
    },

    /**
     * Render movement paths for crews
     */
    renderMovementPaths() {
        const ctx = this.ctx;

        for (const crew of this.crews) {
            if (!crew.displayPath || crew.displayPath.length < 2) continue;
            if (crew.state !== 'moving') {
                crew.displayPath = null;
                continue;
            }

            // Draw path line
            ctx.strokeStyle = crew.color || '#4a9eff';
            ctx.lineWidth = 2;
            ctx.globalAlpha = 0.4;
            ctx.setLineDash([5, 5]);

            ctx.beginPath();
            ctx.moveTo(crew.x, crew.y);

            for (const point of crew.displayPath) {
                ctx.lineTo(point.x, point.y);
            }
            ctx.stroke();

            // Draw waypoint dots
            ctx.fillStyle = crew.color || '#4a9eff';
            for (let i = 0; i < crew.displayPath.length; i++) {
                const point = crew.displayPath[i];
                const size = i === crew.displayPath.length - 1 ? 5 : 3;
                ctx.beginPath();
                ctx.arc(point.x, point.y, size, 0, Math.PI * 2);
                ctx.fill();
            }

            ctx.setLineDash([]);
            ctx.globalAlpha = 1;
        }
    },

    renderTargetingIndicator() {
        const ctx = this.ctx;
        const pos = this.targetPosition;

        if (!pos) return;

        ctx.strokeStyle = 'rgba(255, 255, 255, 0.8)';
        ctx.lineWidth = 2;
        ctx.setLineDash([5, 5]);

        // Draw range indicator based on ability type
        if (this.targetingAbility) {
            const radius = (this.targetingAbility.radius || 2) * this.tileSize;

            ctx.beginPath();
            ctx.arc(pos.x, pos.y, radius, 0, Math.PI * 2);
            ctx.stroke();

            // Fill with semi-transparent color
            ctx.fillStyle = 'rgba(74, 158, 255, 0.2)';
            ctx.beginPath();
            ctx.arc(pos.x, pos.y, radius, 0, Math.PI * 2);
            ctx.fill();
        }

        // Crosshair
        ctx.setLineDash([]);
        ctx.beginPath();
        ctx.moveTo(pos.x - 15, pos.y);
        ctx.lineTo(pos.x + 15, pos.y);
        ctx.moveTo(pos.x, pos.y - 15);
        ctx.lineTo(pos.x, pos.y + 15);
        ctx.stroke();
    },

    renderEffect(effect) {
        const ctx = this.ctx;
        const progress = effect.timer / effect.duration;

        switch (effect.type) {
            case 'damage_number':
                ctx.fillStyle = effect.isCrewDamage ? '#fc8181' : '#fff';
                ctx.font = 'bold 14px sans-serif';
                ctx.textAlign = 'center';
                ctx.globalAlpha = 1 - progress;
                ctx.fillText(`-${effect.damage}`, effect.x, effect.y - progress * 30);
                ctx.globalAlpha = 1;
                break;

            case 'melee_hit':
                ctx.strokeStyle = effect.color || '#fff';
                ctx.lineWidth = 2;
                ctx.globalAlpha = 1 - progress;
                ctx.beginPath();
                ctx.arc(effect.x, effect.y, 10 + progress * 20, 0, Math.PI * 2);
                ctx.stroke();
                ctx.globalAlpha = 1;
                break;

            case 'shockwave':
            case 'shockwave_large':
                ctx.strokeStyle = effect.color || '#4a9eff';
                ctx.lineWidth = 3;
                ctx.globalAlpha = 1 - progress;
                const radius = effect.radius || (progress * 100);
                ctx.beginPath();
                ctx.arc(effect.x, effect.y, typeof radius === 'number' ? radius * progress : progress * 100, 0, Math.PI * 2);
                ctx.stroke();
                ctx.globalAlpha = 1;
                break;

            case 'volley':
                ctx.strokeStyle = effect.color || '#68d391';
                ctx.lineWidth = 2;
                ctx.globalAlpha = 1 - progress;
                for (let i = 0; i < 8; i++) {
                    const angle = (Math.PI * 2 / 8) * i;
                    ctx.beginPath();
                    ctx.moveTo(effect.x, effect.y);
                    ctx.lineTo(
                        effect.x + Math.cos(angle) * (50 + progress * 100),
                        effect.y + Math.sin(angle) * (50 + progress * 100)
                    );
                    ctx.stroke();
                }
                ctx.globalAlpha = 1;
                break;

            case 'move_indicator':
                ctx.strokeStyle = '#4a9eff';
                ctx.lineWidth = 2;
                ctx.globalAlpha = 1 - progress;
                ctx.beginPath();
                ctx.arc(effect.x, effect.y, 5 + progress * 10, 0, Math.PI * 2);
                ctx.stroke();
                ctx.globalAlpha = 1;
                break;

            case 'move_blocked':
                // Red X indicator
                ctx.strokeStyle = '#fc8181';
                ctx.lineWidth = 3;
                ctx.globalAlpha = 1 - progress;
                const xSize = 12;
                ctx.beginPath();
                ctx.moveTo(effect.x - xSize, effect.y - xSize);
                ctx.lineTo(effect.x + xSize, effect.y + xSize);
                ctx.moveTo(effect.x + xSize, effect.y - xSize);
                ctx.lineTo(effect.x - xSize, effect.y + xSize);
                ctx.stroke();
                // Message text
                if (effect.message) {
                    ctx.fillStyle = '#fc8181';
                    ctx.font = 'bold 11px sans-serif';
                    ctx.textAlign = 'center';
                    ctx.fillText(effect.message, effect.x, effect.y - 20 - progress * 10);
                }
                ctx.globalAlpha = 1;
                break;

            case 'death':
                ctx.fillStyle = '#fc8181';
                ctx.globalAlpha = 1 - progress;
                for (let i = 0; i < 6; i++) {
                    const angle = (Math.PI * 2 / 6) * i + progress * Math.PI;
                    const dist = progress * 50;
                    ctx.beginPath();
                    ctx.arc(
                        effect.x + Math.cos(angle) * dist,
                        effect.y + Math.sin(angle) * dist,
                        5, 0, Math.PI * 2
                    );
                    ctx.fill();
                }
                ctx.globalAlpha = 1;
                break;

            case 'explosion':
                ctx.fillStyle = effect.color || '#f6ad55';
                ctx.globalAlpha = (1 - progress) * 0.7;
                ctx.beginPath();
                ctx.arc(effect.x, effect.y, effect.radius * (0.5 + progress * 0.5), 0, Math.PI * 2);
                ctx.fill();
                ctx.globalAlpha = 1;
                break;

            case 'heal':
                ctx.fillStyle = effect.color || '#48bb78';
                ctx.font = 'bold 14px sans-serif';
                ctx.textAlign = 'center';
                ctx.globalAlpha = 1 - progress;
                ctx.fillText(`+${effect.amount}`, effect.x, effect.y - progress * 30);
                ctx.globalAlpha = 1;
                break;

            case 'target_area':
                ctx.strokeStyle = effect.color || '#4a9eff';
                ctx.lineWidth = 2;
                ctx.setLineDash([5, 5]);
                ctx.globalAlpha = 1 - progress;
                ctx.beginPath();
                ctx.arc(effect.x, effect.y, effect.radius, 0, Math.PI * 2);
                ctx.stroke();
                ctx.setLineDash([]);
                ctx.globalAlpha = 1;
                break;

            case 'orbital_warning':
                ctx.strokeStyle = '#fc8181';
                ctx.lineWidth = 3;
                ctx.setLineDash([10, 5]);
                ctx.beginPath();
                ctx.arc(effect.x, effect.y, effect.radius, 0, Math.PI * 2);
                ctx.stroke();
                ctx.setLineDash([]);

                // Pulsing fill
                ctx.fillStyle = `rgba(252, 129, 129, ${0.3 * Math.sin(effect.timer / 100)})`;
                ctx.beginPath();
                ctx.arc(effect.x, effect.y, effect.radius, 0, Math.PI * 2);
                ctx.fill();
                break;

            case 'orbital_explosion':
                const explosionRadius = effect.radius * (1 + progress * 0.3);
                ctx.fillStyle = `rgba(252, 129, 129, ${(1 - progress) * 0.8})`;
                ctx.beginPath();
                ctx.arc(effect.x, effect.y, explosionRadius, 0, Math.PI * 2);
                ctx.fill();

                ctx.strokeStyle = '#fff';
                ctx.lineWidth = 4;
                ctx.globalAlpha = 1 - progress;
                ctx.beginPath();
                ctx.arc(effect.x, effect.y, explosionRadius * 1.2, 0, Math.PI * 2);
                ctx.stroke();
                ctx.globalAlpha = 1;
                break;

            case 'blink_start':
            case 'blink_end':
                ctx.fillStyle = effect.color || '#b794f4';
                ctx.globalAlpha = 1 - progress;
                for (let i = 0; i < 8; i++) {
                    const angle = (Math.PI * 2 / 8) * i;
                    const dist = effect.type === 'blink_start' ? progress * 30 : (1 - progress) * 30;
                    ctx.beginPath();
                    ctx.arc(
                        effect.x + Math.cos(angle) * dist,
                        effect.y + Math.sin(angle) * dist,
                        3, 0, Math.PI * 2
                    );
                    ctx.fill();
                }
                ctx.globalAlpha = 1;
                break;

            case 'deploy':
                ctx.strokeStyle = effect.color || '#68d391';
                ctx.lineWidth = 2;
                ctx.globalAlpha = 1 - progress;
                ctx.beginPath();
                ctx.arc(effect.x, effect.y, 20 * (1 - progress), 0, Math.PI * 2);
                ctx.stroke();
                ctx.beginPath();
                ctx.arc(effect.x, effect.y, 10 + 20 * progress, 0, Math.PI * 2);
                ctx.stroke();
                ctx.globalAlpha = 1;
                break;

            case 'dash_trail':
            case 'lance_trail':
                ctx.strokeStyle = effect.color || '#4a9eff';
                ctx.lineWidth = effect.type === 'lance_trail' ? 6 : 4;
                ctx.globalAlpha = 1 - progress;
                ctx.beginPath();
                ctx.moveTo(effect.startX, effect.startY);
                ctx.lineTo(effect.endX, effect.endY);
                ctx.stroke();
                ctx.globalAlpha = 1;
                break;

            case 'scan_pulse':
                ctx.strokeStyle = effect.color || '#4a9eff';
                ctx.lineWidth = 2;
                ctx.globalAlpha = 1 - progress;
                ctx.beginPath();
                ctx.arc(effect.x, effect.y, effect.radius * progress, 0, Math.PI * 2);
                ctx.stroke();
                ctx.globalAlpha = 1;
                break;

            case 'flare_drop':
                const flareGradient = ctx.createRadialGradient(
                    effect.x, effect.y, 0,
                    effect.x, effect.y, effect.radius
                );
                flareGradient.addColorStop(0, `rgba(246, 173, 85, ${0.4 * (1 - progress * 0.5)})`);
                flareGradient.addColorStop(1, 'rgba(246, 173, 85, 0)');
                ctx.fillStyle = flareGradient;
                ctx.beginPath();
                ctx.arc(effect.x, effect.y, effect.radius, 0, Math.PI * 2);
                ctx.fill();
                break;

            case 'supply_drop':
                ctx.strokeStyle = effect.color || '#48bb78';
                ctx.lineWidth = 2;
                ctx.setLineDash([5, 5]);
                ctx.globalAlpha = 1 - progress;
                ctx.beginPath();
                ctx.arc(effect.x, effect.y, effect.radius, 0, Math.PI * 2);
                ctx.stroke();
                ctx.setLineDash([]);
                // Falling crate icon
                ctx.fillStyle = '#48bb78';
                ctx.font = '20px sans-serif';
                ctx.textAlign = 'center';
                ctx.fillText('📦', effect.x, effect.y - (1 - progress) * 50);
                ctx.globalAlpha = 1;
                break;

            case 'mine_placed':
                ctx.strokeStyle = '#68d391';
                ctx.lineWidth = 2;
                ctx.globalAlpha = 1 - progress;
                ctx.beginPath();
                ctx.arc(effect.x, effect.y, 15 * (1 - progress), 0, Math.PI * 2);
                ctx.stroke();
                ctx.globalAlpha = 1;
                break;

            case 'grenade_throw':
                const throwProgress = Math.min(1, progress * 2);
                const arcHeight = 50;
                const grenadeX = effect.startX + (effect.endX - effect.startX) * throwProgress;
                const grenadeY = effect.startY + (effect.endY - effect.startY) * throwProgress
                    - Math.sin(throwProgress * Math.PI) * arcHeight;
                ctx.fillStyle = '#4a5568';
                ctx.beginPath();
                ctx.arc(grenadeX, grenadeY, 6, 0, Math.PI * 2);
                ctx.fill();
                ctx.strokeStyle = '#fff';
                ctx.lineWidth = 1;
                ctx.stroke();
                break;

            case 'muzzle_flash':
                ctx.fillStyle = effect.color || '#f6e05e';
                ctx.globalAlpha = 1 - progress;
                ctx.beginPath();
                ctx.arc(effect.x, effect.y, 8 * (1 - progress), 0, Math.PI * 2);
                ctx.fill();
                ctx.globalAlpha = 1;
                break;

            case 'stun_indicator':
                ctx.fillStyle = '#fff';
                ctx.font = '14px sans-serif';
                ctx.textAlign = 'center';
                ctx.globalAlpha = 0.5 + Math.sin(effect.timer / 100) * 0.5;
                ctx.fillText('💫', effect.x, effect.y - 25);
                ctx.globalAlpha = 1;
                break;

            case 'revive':
                ctx.strokeStyle = effect.color || '#68d391';
                ctx.lineWidth = 3;
                ctx.globalAlpha = 1 - progress;
                // Rising rings
                for (let i = 0; i < 3; i++) {
                    const ringProgress = (progress + i * 0.2) % 1;
                    ctx.beginPath();
                    ctx.arc(effect.x, effect.y - ringProgress * 40, 15 * (1 - ringProgress), 0, Math.PI * 2);
                    ctx.stroke();
                }
                ctx.globalAlpha = 1;
                break;

            case 'shield_activate':
                ctx.strokeStyle = effect.color || '#63b3ed';
                ctx.lineWidth = 3;
                ctx.globalAlpha = 1 - progress;
                // Expanding shield bubble
                ctx.beginPath();
                ctx.arc(effect.x, effect.y, 30 + progress * 70, 0, Math.PI * 2);
                ctx.stroke();
                ctx.fillStyle = `rgba(99, 179, 237, ${0.2 * (1 - progress)})`;
                ctx.beginPath();
                ctx.arc(effect.x, effect.y, 30 + progress * 70, 0, Math.PI * 2);
                ctx.fill();
                ctx.globalAlpha = 1;
                break;

            case 'hacking':
                ctx.strokeStyle = effect.color || '#68d391';
                ctx.lineWidth = 2;
                // Rotating data streams
                for (let i = 0; i < 4; i++) {
                    const angle = (Math.PI * 2 / 4) * i + effect.timer / 200;
                    ctx.globalAlpha = 0.5 + Math.sin(effect.timer / 100 + i) * 0.3;
                    ctx.beginPath();
                    ctx.moveTo(effect.x + Math.cos(angle) * 15, effect.y + Math.sin(angle) * 15);
                    ctx.lineTo(effect.x + Math.cos(angle) * 30, effect.y + Math.sin(angle) * 30);
                    ctx.stroke();
                }
                ctx.globalAlpha = 1;
                break;
        }
    },
};

// Initialize on DOM ready
document.addEventListener('DOMContentLoaded', () => {
    BattleController.init();
});
