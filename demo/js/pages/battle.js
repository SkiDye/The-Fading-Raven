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
    tacticalModeActive: false, // Auto slow-mo when crew selected
    SLOW_MOTION_SCALE: 0.3,

    // Layout
    tileSize: 40,
    offsetX: 0,
    offsetY: 0,

    // Isometric rendering mode
    useIsometric: true,
    isometricInitialized: false,

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
            // Keyboard help (L-002)
            keyboardHelpModal: document.getElementById('keyboard-help-modal'),
            btnHelp: document.getElementById('btn-help'),
            btnCloseHelp: document.getElementById('btn-close-help'),
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
            // Legacy grid calculations (still needed for some systems)
            this.tileSize = Math.min(
                (this.canvas.width - 100) / this.stationLayout.width,
                (this.canvas.height - 100) / this.stationLayout.height
            );
            this.offsetX = (this.canvas.width - this.stationLayout.width * this.tileSize) / 2;
            this.offsetY = (this.canvas.height - this.stationLayout.height * this.tileSize) / 2;

            // Initialize/update isometric renderer
            if (this.useIsometric && typeof IsometricRenderer !== 'undefined') {
                IsometricRenderer.init(this.canvas, this.stationLayout.width, this.stationLayout.height);
                this.isometricInitialized = true;
            }
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

        // Initialize Crew AI (enabled by default)
        if (typeof CrewAI !== 'undefined') {
            CrewAI.reset();
            CrewAI.enableAll(this.crews);
        }

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

        // Calculate tile position from pixel coordinates
        const tileX = Math.floor((spawnX - this.offsetX) / this.tileSize);
        const tileY = Math.floor((spawnY - this.offsetY) / this.tileSize);

        return {
            id: Utils.generateId(),
            type: type,
            x: spawnX,
            y: spawnY,
            tileX: tileX,
            tileY: tileY,
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

        // Camera controls - Mouse wheel for zoom
        this.canvas?.addEventListener('wheel', (e) => this.handleMouseWheel(e), { passive: false });

        // Camera controls - Middle mouse for pan
        this.canvas?.addEventListener('mousedown', (e) => this.handleMouseDown(e));
        this.canvas?.addEventListener('mouseup', (e) => this.handleMouseUp(e));
        this.canvas?.addEventListener('mouseleave', (e) => this.handleMouseUp(e));

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

        // Keyboard help (L-002)
        this.elements.btnHelp?.addEventListener('click', () => this.showKeyboardHelp());
        this.elements.btnCloseHelp?.addEventListener('click', () => this.hideKeyboardHelp());
        this.elements.keyboardHelpModal?.addEventListener('click', (e) => {
            if (e.target === this.elements.keyboardHelpModal) {
                this.hideKeyboardHelp();
            }
        });

        // Deselect button
        document.getElementById('btn-deselect')?.addEventListener('click', () => {
            this.deselectCrew();
        });

        window.addEventListener('resize', Utils.debounce(() => {
            this.resizeCanvas();
            // Invalidate isometric tile cache on resize
            if (this.useIsometric && typeof IsometricRenderer !== 'undefined') {
                IsometricRenderer.invalidateCache();
            }
        }, 200));
    },

    // ==========================================
    // CAMERA CONTROLS
    // ==========================================

    isPanning: false,
    panStartPos: null,
    lastPanPos: null,

    /**
     * Handle mouse wheel for zoom
     */
    handleMouseWheel(e) {
        if (!this.useIsometric || !this.isometricInitialized) return;

        e.preventDefault();

        // Zoom in/out based on wheel direction
        if (e.deltaY < 0) {
            IsometricRenderer.zoomIn();
        } else {
            IsometricRenderer.zoomOut();
        }
    },

    /**
     * Handle mouse down for pan start
     */
    handleMouseDown(e) {
        // Middle mouse button (button 1) for panning
        if (e.button === 1) {
            e.preventDefault();
            this.isPanning = true;
            this.panStartPos = { x: e.clientX, y: e.clientY };
            this.lastPanPos = { x: e.clientX, y: e.clientY };
            this.canvas.style.cursor = 'grabbing';
        }
    },

    /**
     * Handle mouse up for pan end
     */
    handleMouseUp(e) {
        if (this.isPanning) {
            this.isPanning = false;
            this.panStartPos = null;
            this.lastPanPos = null;
            this.canvas.style.cursor = '';
        }
    },

    /**
     * Rotate camera (called from keyboard)
     */
    rotateCamera(direction) {
        if (!this.useIsometric || !this.isometricInitialized) return;

        if (direction > 0) {
            IsometricRenderer.rotateClockwise();
        } else {
            IsometricRenderer.rotateCounterClockwise();
        }
    },

    /**
     * Reset camera to default
     */
    resetCamera() {
        if (!this.useIsometric || !this.isometricInitialized) return;

        IsometricRenderer.resetCamera();
        IsometricRenderer.calculateOrigin();
        IsometricRenderer.invalidateCache();
    },

    // ==========================================
    // TOUCH SUPPORT
    // ==========================================

    touchStartTime: 0,
    touchStartPos: null,
    isDragging: false,
    // Pinch zoom support
    isPinching: false,
    lastPinchDistance: 0,

    handleTouchStart(e) {
        e.preventDefault();

        // Two-finger touch = pinch zoom start
        if (e.touches.length === 2 && this.useIsometric && this.isometricInitialized) {
            const dx = e.touches[0].clientX - e.touches[1].clientX;
            const dy = e.touches[0].clientY - e.touches[1].clientY;
            this.lastPinchDistance = Math.sqrt(dx * dx + dy * dy);
            this.isPinching = true;
            return;
        }

        const touch = e.touches[0];
        this.touchStartTime = Date.now();
        this.touchStartPos = { x: touch.clientX, y: touch.clientY };
        this.isDragging = false;
    },

    handleTouchMove(e) {
        e.preventDefault();

        // Pinch zoom
        if (e.touches.length === 2 && this.isPinching && this.useIsometric && this.isometricInitialized) {
            const dx = e.touches[0].clientX - e.touches[1].clientX;
            const dy = e.touches[0].clientY - e.touches[1].clientY;
            const distance = Math.sqrt(dx * dx + dy * dy);

            if (this.lastPinchDistance > 0) {
                const scale = distance / this.lastPinchDistance;
                const currentZoom = IsometricRenderer.getZoom();
                IsometricRenderer.setZoom(currentZoom * scale, false);
            }

            this.lastPinchDistance = distance;
            return;
        }

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

        // End pinch zoom
        if (this.isPinching) {
            this.isPinching = false;
            this.lastPinchDistance = 0;
            if (e.touches.length === 0) {
                return;
            }
        }

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
            this.moveCrewToScreen(this.selectedCrew, x, y);
        } else {
            // Try to select a crew (isometric or legacy)
            if (this.useIsometric && this.isometricInitialized) {
                const selectedCrew = DepthSorter.getEntityAtPosition(
                    x, y, this.crews,
                    this.stationLayout, this.offsetX, this.offsetY, this.tileSize, 25
                );
                if (selectedCrew) {
                    this.selectCrew(selectedCrew.id);
                    return;
                }
            } else {
                for (const crew of this.crews) {
                    if (Utils.distance(x, y, crew.x, crew.y) < 25) {
                        this.selectCrew(crew.id);
                        return;
                    }
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
            // Check if clicking on enemy - target for attack (isometric or legacy)
            if (this.useIsometric && this.isometricInitialized) {
                const selectedEnemy = DepthSorter.getEntityAtPosition(
                    x, y, this.enemies,
                    this.stationLayout, this.offsetX, this.offsetY, this.tileSize,
                    30 // Larger hit radius for enemies
                );
                if (selectedEnemy) {
                    this.selectedCrew.targetEnemy = selectedEnemy;
                    this.selectedCrew.state = 'attacking';
                    return;
                }
            } else {
                for (const enemy of this.enemies) {
                    if (Utils.distance(x, y, enemy.x, enemy.y) < enemy.size + 10) {
                        this.selectedCrew.targetEnemy = enemy;
                        this.selectedCrew.state = 'attacking';
                        return;
                    }
                }
            }
        }
    },

    handleCanvasMouseMove(e) {
        // Handle camera panning
        if (this.isPanning && this.lastPanPos) {
            const dx = e.clientX - this.lastPanPos.x;
            const dy = e.clientY - this.lastPanPos.y;
            IsometricRenderer.pan(dx, dy);
            this.lastPanPos = { x: e.clientX, y: e.clientY };
            return;
        }

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
                this.deselectCrew();
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

        // ? for keyboard help (L-002)
        if (e.key === '?' || e.key === '/') {
            this.showKeyboardHelp();
        }

        // Camera controls (when isometric mode is active)
        if (this.useIsometric && this.isometricInitialized) {
            // Z - Rotate counter-clockwise
            if (e.key === 'z' || e.key === 'Z') {
                e.preventDefault();
                this.rotateCamera(-1);
            }

            // C - Rotate clockwise
            if (e.key === 'c' || e.key === 'C') {
                e.preventDefault();
                this.rotateCamera(1);
            }

            // R - Reset camera (only when no crew selected)
            if ((e.key === 'r' || e.key === 'R') && !this.selectedCrew) {
                e.preventDefault();
                this.resetCamera();
            }

            // + / = - Zoom in
            if (e.key === '+' || e.key === '=') {
                e.preventDefault();
                IsometricRenderer.zoomIn();
            }

            // - - Zoom out
            if (e.key === '-' || e.key === '_') {
                e.preventDefault();
                IsometricRenderer.zoomOut();
            }
        }
    },

    // Keyboard help methods (L-002)
    showKeyboardHelp() {
        this.elements.keyboardHelpModal?.classList.add('active');
        // Pause game while help is shown
        if (!this.paused) {
            this.togglePause();
        }
    },

    hideKeyboardHelp() {
        this.elements.keyboardHelpModal?.classList.remove('active');
    },

    // ==========================================
    // CREW MOVEMENT WITH PATHFINDING
    // ==========================================

    /**
     * Move crew to a screen position (handles isometric conversion)
     */
    moveCrewToScreen(crew, screenX, screenY) {
        if (this.useIsometric && this.isometricInitialized) {
            // Convert screen position to tile coordinates
            const tileInfo = DepthSorter.getTileAtPosition(screenX, screenY, this.stationLayout);
            if (tileInfo) {
                this.moveCrewToTile(crew, tileInfo.x, tileInfo.y, screenX, screenY);
            } else {
                this.showMovementFeedbackIsometric(screenX, screenY, 'blocked');
            }
        } else {
            // Legacy pixel-based movement
            this.moveCrewTo(crew, screenX, screenY);
        }
    },

    /**
     * Move crew to a specific tile (isometric mode)
     */
    moveCrewToTile(crew, tileX, tileY, screenX, screenY) {
        if (!this.tileGrid) {
            return;
        }

        // Get crew's current tile position
        const startTileX = Math.floor((crew.x - this.offsetX) / this.tileSize);
        const startTileY = Math.floor((crew.y - this.offsetY) / this.tileSize);

        // Check if target tile is walkable
        if (!this.tileGrid.isWalkable(tileX, tileY)) {
            this.showMovementFeedbackIsometric(screenX, screenY, 'blocked');
            return;
        }

        // Find path using A*
        const path = this.tileGrid.findPath(startTileX, startTileY, tileX, tileY);

        if (path.length > 0) {
            crew.path = path.slice(1); // Remove start position
            crew.state = 'moving';
            crew.targetEnemy = null;

            // Store path for visual display (in isometric coordinates)
            crew.displayPath = path.map(tile => {
                const heightLevel = HeightSystem.getLayoutTileHeight(this.stationLayout, tile.x, tile.y);
                return IsometricRenderer.tileToScreen(tile.x, tile.y, heightLevel);
            });

            // Move indicator effect at target
            const targetHeight = HeightSystem.getLayoutTileHeight(this.stationLayout, tileX, tileY);
            const targetScreen = IsometricRenderer.tileToScreen(tileX, tileY, targetHeight);
            this.addEffect({
                type: 'move_indicator',
                x: targetScreen.x,
                y: targetScreen.y,
                duration: 500,
                timer: 0,
            });
        } else {
            this.showMovementFeedbackIsometric(screenX, screenY, 'no_path');
        }
    },

    /**
     * Show movement feedback in isometric mode
     */
    showMovementFeedbackIsometric(screenX, screenY, reason) {
        const messages = {
            blocked: '이동 불가',
            no_path: '경로 없음',
            out_of_range: '사거리 초과',
        };

        this.addEffect({
            type: 'move_blocked',
            x: screenX,
            y: screenY,
            message: messages[reason] || '이동 불가',
            duration: 800,
            timer: 0,
        });

        if (typeof Toast !== 'undefined') {
            Toast.warning(messages[reason] || '이동할 수 없습니다');
        }
    },

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
                    // Phase 2: Skill activation effect (using screen coordinates)
                    this.addEffectAtEntity(this.selectedCrew, {
                        type: 'skill_activate',
                        duration: 400,
                        timer: 0,
                        color: this.selectedCrew.color,
                    });
                    SkillSystem.useSkill(this.selectedCrew, target, this);
                }
                break;

            case 'equipment':
                if (this.selectedCrew) {
                    // Phase 2: Equipment activation effect (using screen coordinates)
                    this.addEffectAtEntity(this.selectedCrew, {
                        type: 'skill_activate',
                        duration: 300,
                        timer: 0,
                        color: '#f6e05e', // Gold for equipment
                    });
                    EquipmentEffects.use(this.selectedCrew, target, this);
                }
                break;

            case 'raven':
                if (this.targetingAbility) {
                    // Phase 2: Raven ability activation effect
                    // Note: x,y here are already screen coordinates from click position
                    this.addEffect({
                        type: 'skill_activate',
                        x: x,
                        y: y,
                        duration: 500,
                        timer: 0,
                        color: '#fc8181', // Red for Raven
                    });
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
        const previousSelection = this.selectedCrew;
        this.selectedCrew = this.crews.find(c => c.id === crewId) || null;
        this.updateCrewButtonSelection();

        // Tactical Mode: Auto slow-motion on crew selection (Bad North style)
        if (this.selectedCrew && !previousSelection) {
            this.enterTacticalMode();
        }
    },

    deselectCrew() {
        if (this.selectedCrew) {
            this.selectedCrew = null;
            this.updateCrewButtonSelection();
            this.exitTacticalMode();
        }
    },

    enterTacticalMode() {
        if (!this.tacticalModeActive) {
            this.tacticalModeActive = true;
            this.timeScale = this.SLOW_MOTION_SCALE;
            this.elements.slowMotionIndicator?.classList.add('active');
        }
    },

    exitTacticalMode() {
        if (this.tacticalModeActive && !this.targetingMode) {
            this.tacticalModeActive = false;
            this.timeScale = 1;
            this.elements.slowMotionIndicator?.classList.remove('active');
        }
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

        // Update camera animation (isometric mode)
        if (this.useIsometric && this.isometricInitialized && IsometricRenderer.isAnimating) {
            IsometricRenderer.updateCamera(dt);
        }

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

        // Remove dead enemies (support both Enemy class and simple objects)
        this.enemies = this.enemies.filter(e => {
            // Enemy class instance
            if (e.state !== undefined) {
                return e.state !== EnemyState.DEAD && e.state !== EnemyState.DYING;
            }
            // Simple object fallback
            return e.health > 0;
        });

        // Check battle end
        this.checkBattleEnd();

        // Update HUD
        this.updateHUD();
        this.updateCrewButtons();
    },

    updateCrew(crew, dt) {
        // Phase 2: Update flash effect
        if (crew.flashTime > 0) {
            crew.flashTime -= dt;
        }

        // Phase 2: Apply knockback
        if (crew.knockbackTime > 0) {
            const knockbackProgress = crew.knockbackTime / 100;
            crew.x += crew.knockbackX * knockbackProgress * (dt / 16);
            crew.y += crew.knockbackY * knockbackProgress * (dt / 16);
            crew.knockbackTime -= dt;
        }

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

        // Run Crew AI if enabled
        if (typeof CrewAI !== 'undefined' && CrewAI.isEnabled(crew.id)) {
            CrewAI.update(crew, this, dt);
        }

        switch (crew.state) {
            case 'moving':
                this.updateCrewMovement(crew, dt);
                break;

            case 'attacking':
                this.updateCrewAttacking(crew, dt);
                break;

            case 'idle':
                // Auto-target nearby enemies (fallback if AI disabled)
                if (!CrewAI || !CrewAI.isEnabled(crew.id)) {
                    const nearestEnemy = this.findNearestEnemy(crew);
                    if (nearestEnemy && Utils.distance(crew.x, crew.y, nearestEnemy.x, nearestEnemy.y) <= crew.attackRange * 1.5) {
                        crew.targetEnemy = nearestEnemy;
                        crew.state = 'attacking';
                    }
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
                crew.facingAngle = angle; // Update facing direction

                // Get final move speed with grade scaling and trait bonus
                const moveSpeed = this.getCrewMoveSpeed(crew);
                const moveAmount = moveSpeed * (dt / 1000);
                crew.x += Math.cos(angle) * moveAmount;
                crew.y += Math.sin(angle) * moveAmount;

                // Update tile coordinates for isometric rendering
                this.updateEntityTilePosition(crew);
            } else {
                // Arrived at next tile
                crew.tileX = nextTile.x;
                crew.tileY = nextTile.y;
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
                crew.facingAngle = angle; // Update facing direction

                // Get final move speed with grade scaling and trait bonus
                const moveSpeed = this.getCrewMoveSpeed(crew);
                const moveAmount = moveSpeed * (dt / 1000);
                crew.x += Math.cos(angle) * moveAmount;
                crew.y += Math.sin(angle) * moveAmount;

                // Update tile coordinates for isometric rendering
                this.updateEntityTilePosition(crew);
            } else {
                crew.state = 'idle';
                crew.targetX = null;
                crew.targetY = null;
            }
        } else {
            crew.state = 'idle';
        }
    },

    /**
     * Update entity's tile position from pixel coordinates
     */
    updateEntityTilePosition(entity) {
        if (!this.tileGrid) return;

        const newTileX = Math.floor((entity.x - this.offsetX) / this.tileSize);
        const newTileY = Math.floor((entity.y - this.offsetY) / this.tileSize);

        if (entity.tileX !== newTileX || entity.tileY !== newTileY) {
            entity.tileX = newTileX;
            entity.tileY = newTileY;
        }
    },

    /**
     * Get crew's final movement speed with all modifiers applied
     * - Unit grade scaling (standard/veteran/elite)
     * - Trait bonus (swiftMovement +33%)
     * @param {Object} crew - The crew entity
     * @returns {number} Final movement speed in pixels/second
     */
    getCrewMoveSpeed(crew) {
        let moveSpeed = crew.moveSpeed || 80;

        // Apply unit grade scaling (CombatMechanics integration)
        if (typeof CombatMechanics !== 'undefined' && CombatMechanics.getGradeScaledMoveSpeed) {
            moveSpeed = CombatMechanics.getGradeScaledMoveSpeed(crew, moveSpeed);
        }

        // Apply trait bonus
        if (crew.trait === 'swiftMovement') {
            moveSpeed *= 1.33;
        }

        return moveSpeed;
    },

    /**
     * Get crew's final attack speed (cooldown) with all modifiers applied
     * - Unit grade scaling (standard/veteran/elite)
     * Higher grade = lower cooldown = faster attacks
     * @param {Object} crew - The crew entity
     * @returns {number} Attack cooldown in milliseconds
     */
    getCrewAttackSpeed(crew) {
        const baseAttackSpeed = crew.attackSpeed || 1000;

        // Apply unit grade scaling (CombatMechanics integration)
        if (typeof CombatMechanics !== 'undefined' && CombatMechanics.getGradeScaledAttackSpeed) {
            return CombatMechanics.getGradeScaledAttackSpeed(crew, baseAttackSpeed);
        }

        return baseAttackSpeed;
    },

    updateCrewAttacking(crew, dt) {
        if (!crew.targetEnemy || crew.targetEnemy.health <= 0) {
            crew.targetEnemy = null;
            crew.state = 'idle';
            return;
        }

        const dist = Utils.distance(crew.x, crew.y, crew.targetEnemy.x, crew.targetEnemy.y);
        // Always face the target enemy
        crew.facingAngle = Utils.angleBetween(crew.x, crew.y, crew.targetEnemy.x, crew.targetEnemy.y);

        if (dist <= crew.attackRange) {
            // In range - attack
            if (crew.attackTimer <= 0) {
                this.crewAttack(crew, crew.targetEnemy);
                // Apply grade-scaled attack speed
                crew.attackTimer = this.getCrewAttackSpeed(crew);
            }
        } else {
            // Move towards enemy
            const angle = crew.facingAngle;

            // Get final move speed with grade scaling and trait bonus
            const moveSpeed = this.getCrewMoveSpeed(crew);
            const moveAmount = moveSpeed * (dt / 1000);
            crew.x += Math.cos(angle) * moveAmount;
            crew.y += Math.sin(angle) * moveAmount;
        }
    },

    updateEnemy(enemy, dt) {
        // Phase 2: Update flash effect
        if (enemy.flashTime > 0) {
            enemy.flashTime -= dt;
        }

        // Phase 2: Apply knockback
        if (enemy.knockbackTime > 0) {
            const knockbackProgress = enemy.knockbackTime / 100;
            enemy.x += enemy.knockbackX * knockbackProgress * (dt / 16);
            enemy.y += enemy.knockbackY * knockbackProgress * (dt / 16);
            enemy.knockbackTime -= dt;
        }

        // Check if this is an Enemy class instance (Session 3)
        if (typeof enemy.update === 'function') {
            // Use Enemy class update with game context
            const context = {
                crews: this.crews,
                enemies: this.enemies,
                turrets: this.turrets,
                station: { x: this.canvas.width / 2, y: this.canvas.height / 2, health: this.stationHealth },
                tileGrid: this.tileGrid,
                rng: this.rng,
            };

            // Set target for AI
            const nearestCrew = this.findNearestCrew(enemy);
            enemy.target = nearestCrew;

            // Update facing angle for direction indicator
            if (nearestCrew) {
                enemy.facingAngle = Utils.angleBetween(enemy.x, enemy.y, nearestCrew.x, nearestCrew.y);
            }

            // Update enemy (handles state, cooldowns, status effects)
            enemy.update(dt, context);

            // Update tile position for isometric rendering
            this.updateEntityTilePosition(enemy);

            // Handle attack event from Enemy class
            if (enemy.state === EnemyState.ATTACKING && enemy.attackCooldown <= 0) {
                if (nearestCrew && enemy.isInAttackRange(nearestCrew)) {
                    this.enemyAttack(enemy, nearestCrew);
                }
            }

            // Station damage if no crew targets
            if (!nearestCrew && enemy.canAttackStation && enemy.canAttackStation()) {
                const centerX = this.canvas.width / 2;
                const centerY = this.canvas.height / 2;
                const dist = Utils.distance(enemy.x, enemy.y, centerX, centerY);

                if (dist <= 50 && enemy.attackCooldown <= 0) {
                    this.stationHealth -= enemy.damage / 5;
                    enemy.attackCooldown = enemy.attackSpeed;
                }
            }

            return;
        }

        // Fallback for simple enemy objects (legacy support)
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
            // Update facing angle towards target
            enemy.facingAngle = Utils.angleBetween(enemy.x, enemy.y, nearestCrew.x, nearestCrew.y);

            if (dist <= enemy.attackRange) {
                if (enemy.attackTimer <= 0) {
                    this.enemyAttack(enemy, nearestCrew);
                    enemy.attackTimer = enemy.attackSpeed;
                }
            } else {
                const angle = enemy.facingAngle;
                const moveAmount = effectiveSpeed * (dt / 1000);
                enemy.x += Math.cos(angle) * moveAmount;
                enemy.y += Math.sin(angle) * moveAmount;
                // Update tile position for isometric rendering
                this.updateEntityTilePosition(enemy);
            }
        } else {
            // Move to station center
            const centerX = this.canvas.width / 2;
            const centerY = this.canvas.height / 2;
            const dist = Utils.distance(enemy.x, enemy.y, centerX, centerY);

            if (dist > 50) {
                const angle = Utils.angleBetween(enemy.x, enemy.y, centerX, centerY);
                enemy.facingAngle = angle; // Update facing direction
                const moveAmount = effectiveSpeed * (dt / 1000);
                enemy.x += Math.cos(angle) * moveAmount;
                enemy.y += Math.sin(angle) * moveAmount;
                // Update tile position for isometric rendering
                this.updateEntityTilePosition(enemy);
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
                // Get target screen position for collision check (projectile uses screen coords)
                const targetScreenPos = this.getEffectPos(proj.target);
                if (Utils.distance(proj.x, proj.y, targetScreenPos.x, targetScreenPos.y) < targetSize + 5) {
                    // Apply damage
                    if (proj.target.health !== undefined) {
                        // Enemy target
                        let damage = proj.damage;
                        let actualDamage = damage;

                        // Use Enemy class takeDamage if available
                        if (typeof proj.target.takeDamage === 'function') {
                            actualDamage = proj.target.takeDamage(damage, proj.source, 'ranged');
                        } else {
                            // Fallback for simple objects
                            if (proj.target.shielded) {
                                damage *= (1 - (proj.target.shieldReduction || 0));
                            }
                            proj.target.health -= damage;
                            actualDamage = damage;
                        }
                        this.addDamageNumber(targetScreenPos.x, targetScreenPos.y, Math.floor(actualDamage), false, proj.isCritical);

                        // Phase 2: Hit reaction for ranged attacks
                        // Create a pseudo-source entity at projectile position for knockback direction
                        this.applyHitReaction(proj.target, { x: proj.target.x - 1, y: proj.target.y });

                        // Critical hit effect for ranged attacks
                        if (proj.isCritical) {
                            this.addCriticalHitEffect(proj.target, proj.color);
                            // Extra knockback on crit
                            if (proj.target.knockbackX) {
                                proj.target.knockbackX *= 1.5;
                                proj.target.knockbackY *= 1.5;
                            }
                        }

                        // Check for enemy death from projectile
                        if (proj.target.health <= 0) {
                            this.triggerDeathAnimation(proj.target, 'enemy');
                        }

                        // Apply slow from turret (for Enemy class, use applySlow method)
                        if (proj.applySlows && proj.slowAmount) {
                            if (typeof proj.target.applySlow === 'function') {
                                proj.target.applySlow(proj.slowAmount, proj.slowDuration);
                            } else {
                                proj.target.slowed = true;
                                proj.target.slowTimer = proj.slowDuration;
                                proj.target.slowAmount = proj.slowAmount;
                            }
                        }
                    } else {
                        // Crew target (from hacked turret)
                        proj.target.squadSize--;
                        this.addDamageNumber(targetScreenPos.x, targetScreenPos.y, 1, true);

                        // Phase 2: Hit reaction for crew from ranged
                        this.applyHitReaction(proj.target, { x: proj.target.x - 1, y: proj.target.y });
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

        // Calculate critical hit (15% base chance, +5% for precision trait)
        const critChance = crew.trait === 'precision' ? 0.20 : 0.15;
        const combatRng = this.rng?.get('combat');
        const isCritical = combatRng ? combatRng.random() < critChance : Math.random() < critChance;
        if (isCritical) {
            damage *= 1.5; // 50% bonus damage on crit
        }

        // Set facing direction for animation
        crew.facingAngle = Utils.angleBetween(crew.x, crew.y, enemy.x, enemy.y);

        // Get screen positions for effects
        const crewScreenPos = this.getEffectPos(crew);
        const enemyScreenPos = this.getEffectPos(enemy);

        // Add windup effect (using screen coordinates)
        this.addEffect({
            type: 'attack_windup',
            x: crewScreenPos.x,
            y: crewScreenPos.y,
            targetX: enemyScreenPos.x,
            targetY: enemyScreenPos.y,
            duration: 150,
            timer: 0,
            color: crew.color,
            isRanged: crew.class === 'ranger',
        });

        if (crew.class === 'ranger') {
            // Ranged attack (delayed by windup)
            setTimeout(() => {
                if (enemy.health <= 0) return;
                // Get fresh screen positions (entity may have moved)
                const freshCrewPos = this.getEffectPos(crew);
                const freshEnemyPos = this.getEffectPos(enemy);
                this.projectiles.push({
                    x: freshCrewPos.x,
                    y: freshCrewPos.y,
                    angle: Math.atan2(freshEnemyPos.y - freshCrewPos.y, freshEnemyPos.x - freshCrewPos.x),
                    speed: 400,
                    damage: damage,
                    target: enemy,
                    color: crew.color,
                    isCritical: isCritical,
                });
            }, 150);
        } else {
            // Melee attack (delayed by windup)
            setTimeout(() => {
                if (enemy.health <= 0) return;

                let actualDamage;
                if (typeof enemy.takeDamage === 'function') {
                    actualDamage = enemy.takeDamage(damage, crew, 'melee');
                } else {
                    enemy.health -= damage;
                    actualDamage = damage;
                }
                // Get fresh screen positions
                const freshEnemyPos = this.getEffectPos(enemy);
                this.addDamageNumber(freshEnemyPos.x, freshEnemyPos.y, Math.floor(actualDamage), false, isCritical);

                // Phase 2: Hit reaction for enemy
                this.applyHitReaction(enemy, crew);

                // Critical hit particles
                if (isCritical) {
                    this.addCriticalHitEffect(enemy, crew.color);
                    // Extra knockback on crit
                    enemy.knockbackX *= 1.5;
                    enemy.knockbackY *= 1.5;
                }

                // Check for enemy death
                if (enemy.health <= 0) {
                    this.triggerDeathAnimation(enemy, 'enemy');
                }

                this.addEffectAtEntity(enemy, {
                    type: 'melee_hit',
                    duration: 200,
                    timer: 0,
                    color: crew.color,
                });
            }, 150);
        }
    },

    /**
     * Add critical hit visual effect (particles)
     * @param {Object} entity - Entity at which to display the effect
     * @param {string} color - Effect color
     */
    addCriticalHitEffect(entity, color) {
        const pos = this.getEffectPos(entity);
        // Add burst particles
        for (let i = 0; i < 8; i++) {
            const angle = (Math.PI * 2 / 8) * i;
            this.addEffect({
                type: 'crit_particle',
                x: pos.x,
                y: pos.y,
                angle: angle,
                duration: 400,
                timer: 0,
                color: color || '#ffd700',
            });
        }
        // Add impact flash
        this.addEffect({
            type: 'crit_flash',
            x: pos.x,
            y: pos.y,
            duration: 200,
            timer: 0,
        });
    },

    enemyAttack(enemy, crew) {
        if (crew.invulnerable) return;

        // Set enemy facing direction
        enemy.facingAngle = Utils.angleBetween(enemy.x, enemy.y, crew.x, crew.y);

        // Get screen positions for effects
        const enemyScreenPos = this.getEffectPos(enemy);
        const crewScreenPos = this.getEffectPos(crew);

        // Add windup effect for enemy (using screen coordinates)
        this.addEffect({
            type: 'attack_windup',
            x: enemyScreenPos.x,
            y: enemyScreenPos.y,
            targetX: crewScreenPos.x,
            targetY: crewScreenPos.y,
            duration: 150,
            timer: 0,
            color: enemy.visual?.color || enemy.color || '#ff6b6b',
            isEnemy: true,
        });

        // Delayed attack after windup
        setTimeout(() => {
            if (crew.squadSize <= 0) return;

            let damage = 1; // Squad members lost
            if (crew.shielded) {
                damage = Math.max(0, Math.round(damage * (1 - crew.shieldReduction)));
            }

            crew.squadSize -= damage;
            // Get fresh screen position
            const freshCrewPos = this.getEffectPos(crew);
            this.addDamageNumber(freshCrewPos.x, freshCrewPos.y, enemy.damage, true);

            // Phase 2: Hit reaction for crew
            this.applyHitReaction(crew, enemy);

            if (crew.squadSize <= 0) {
                // Phase 2: Enhanced death animation
                this.triggerDeathAnimation(crew, 'crew');
                this.deadCrews.push(crew);
                this.crews = this.crews.filter(c => c.id !== crew.id);
            }
        }, 150);
    },

    /**
     * Phase 2: Apply hit reaction (flash + knockback)
     * @param {Object} target - Entity receiving the hit
     * @param {Object} source - Entity that caused the hit (for knockback direction)
     */
    applyHitReaction(target, source) {
        // Flash effect
        target.flashTime = 150;

        // Knockback calculation (using tile coordinates for direction)
        const knockbackDist = 8;
        const angle = Utils.angleBetween(source.x, source.y, target.x, target.y);
        target.knockbackX = Math.cos(angle) * knockbackDist;
        target.knockbackY = Math.sin(angle) * knockbackDist;
        target.knockbackTime = 100;

        // Hit effect (using screen coordinates)
        this.addEffectAtEntity(target, {
            type: 'hit_impact',
            duration: 200,
            timer: 0,
            color: '#fff',
        });
    },

    /**
     * Phase 2: Trigger enhanced death animation
     */
    triggerDeathAnimation(entity, entityType) {
        // Get screen position for effects
        const pos = this.getEffectPos(entity);
        const color = entity.color || (entityType === 'crew' ? '#4a9eff' : '#ff6b6b');

        // Main death burst
        this.addEffect({
            type: 'death_burst',
            x: pos.x,
            y: pos.y,
            duration: 600,
            timer: 0,
            color: color,
            particleCount: entityType === 'crew' ? 12 : 8,
        });

        // Soul/essence rising effect for crews
        if (entityType === 'crew') {
            this.addEffect({
                type: 'soul_rise',
                x: pos.x,
                y: pos.y,
                duration: 1000,
                timer: 0,
                color: color,
            });
        }

        // Screen shake on death
        this.screenShake(entityType === 'crew' ? 5 : 3, 150);

        // Legacy death effect for compatibility
        this.addEffect({
            type: 'death',
            x: pos.x,
            y: pos.y,
            duration: 500,
            timer: 0,
        });
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

            // Phase 3: Wave transition visual effects
            const centerX = this.canvas.width / 2;
            const centerY = this.canvas.height / 2;

            // Add wave start effect
            this.addEffect({
                type: 'wave_start',
                x: centerX,
                y: centerY,
                duration: 1000,
                timer: 0,
                waveNumber: this.waveNumber,
                isBoss: isBossWave || this.battleInfo.type === 'boss',
            });

            // Screen shake for boss (enhanced)
            if (isBossWave || this.battleInfo.type === 'boss') {
                this.screenShake(10, 500);
                // Add boss entrance effect
                this.addEffect({
                    type: 'boss_entrance',
                    x: centerX,
                    y: centerY,
                    duration: 1500,
                    timer: 0,
                });
            } else {
                // Normal wave screen pulse
                this.screenShake(3, 200);
            }

            setTimeout(() => {
                this.elements.waveAnnouncement.classList.remove('active', 'boss', 'storm');
            }, 2500);
        }
    },

    addDamageNumber(x, y, damage, isCrewDamage = false, isCritical = false) {
        this.effects.push({
            type: 'damage_number',
            x: x + (Math.random() - 0.5) * 20,
            y: y - 10,
            damage: typeof damage === 'number' ? Math.floor(damage) : damage,
            duration: isCritical ? 1200 : 1000, // Longer duration for crits
            timer: 0,
            isCrewDamage,
            isCritical,
        });
    },

    addEffect(effect) {
        this.effects.push(effect);
    },

    /**
     * Get screen position for effect rendering
     * Converts entity tile coordinates to screen coordinates in isometric mode
     */
    getEffectPos(entity) {
        if (!entity) return { x: 0, y: 0 };
        return this.getEntityScreenPos(entity);
    },

    /**
     * Add effect at entity position (auto-converts to screen coords)
     */
    addEffectAtEntity(entity, effectProps) {
        const pos = this.getEffectPos(entity);
        this.addEffect({
            ...effectProps,
            x: pos.x,
            y: pos.y,
        });
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

        // Draw station (isometric or legacy)
        if (this.useIsometric && this.isometricInitialized) {
            this.renderStationIsometric();
        } else {
            this.renderStation();
        }

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

        // Draw entities with depth sorting (isometric mode)
        if (this.useIsometric && this.isometricInitialized) {
            this.renderEntitiesIsometric();
        } else {
            // Legacy rendering
            this.enemies.forEach(e => this.renderEnemy(e));
            this.crews.forEach(c => this.renderCrew(c));
        }

        // Draw projectiles
        this.projectiles.forEach(p => this.renderProjectile(p));

        // Draw effects (above entities)
        this.effects.filter(e => e.type !== 'shockwave' && e.type !== 'volley' && e.type !== 'target_area').forEach(e => this.renderEffect(e));

        // Draw selection indicator
        if (this.selectedCrew) {
            const pos = this.getEntityScreenPos(this.selectedCrew);
            ctx.strokeStyle = '#fff';
            ctx.lineWidth = 2;
            ctx.setLineDash([4, 4]);
            ctx.beginPath();
            ctx.arc(pos.x, pos.y, 30, 0, Math.PI * 2);
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

    // ==========================================
    // ISOMETRIC RENDERING
    // ==========================================

    /**
     * Render station using isometric tiles
     */
    renderStationIsometric() {
        const ctx = this.ctx;

        // Render tiles using cached canvas if available
        if (IsometricRenderer.isCacheDirty()) {
            TileRenderer.renderToCache(this.stationLayout);
        }
        TileRenderer.drawFromCache(ctx);

        // Render facilities
        TileRenderer.renderFacilities(ctx, this.stationLayout);

        // Render spawn points
        TileRenderer.renderSpawnPoints(ctx, this.stationLayout);
    },

    /**
     * Render all entities with depth sorting for isometric view
     */
    renderEntitiesIsometric() {
        // Create render list with depth sorting
        const renderList = DepthSorter.createRenderList(
            {
                enemies: this.enemies,
                crews: this.crews,
            },
            this.stationLayout,
            this.offsetX,
            this.offsetY,
            this.tileSize
        );

        // Render in depth order
        for (const item of renderList) {
            if (item.type === 'enemies') {
                this.renderEnemyIsometric(item.entity);
            } else if (item.type === 'crews') {
                this.renderCrewIsometric(item.entity);
            }
        }
    },

    /**
     * Get screen position for an entity (isometric or legacy)
     */
    getEntityScreenPos(entity) {
        if (this.useIsometric && this.isometricInitialized) {
            return DepthSorter.getEntityScreenPosition(
                entity,
                this.stationLayout,
                this.offsetX,
                this.offsetY,
                this.tileSize
            );
        }
        return { x: entity.x, y: entity.y };
    },

    /**
     * Render a crew member in isometric view
     */
    renderCrewIsometric(crew) {
        const ctx = this.ctx;
        const pos = this.getEntityScreenPos(crew);
        const x = pos.x;
        const y = pos.y;

        // Phase 3: Smooth health bar transition (shared with non-isometric)
        if (crew.displayHealth === undefined) crew.displayHealth = crew.squadSize;
        crew.displayHealth += (crew.squadSize - crew.displayHealth) * 0.15;

        // Phase 3: Idle breathing animation
        if (!crew.idlePhase) crew.idlePhase = Math.random() * Math.PI * 2;
        const idleTime = performance.now() / 1000;
        const breathScale = crew.state === 'idle' ? 1 + Math.sin(idleTime * 2 + crew.idlePhase) * 0.03 : 1;

        // Phase 3: Combat state indicator
        if (crew.state === 'attacking') {
            const pulsePhase = (idleTime * 4) % 1;
            ctx.strokeStyle = `rgba(255, 100, 100, ${0.5 - pulsePhase * 0.5})`;
            ctx.lineWidth = 2;
            ctx.beginPath();
            ctx.arc(x, y, 20 * breathScale + 5 + pulsePhase * 10, 0, Math.PI * 2);
            ctx.stroke();
        }

        // Invulnerability effect
        if (crew.invulnerable) {
            ctx.fillStyle = 'rgba(183, 148, 244, 0.3)';
            ctx.beginPath();
            ctx.arc(x, y, 28 * breathScale, 0, Math.PI * 2);
            ctx.fill();
        }

        // Shield effect
        if (crew.shielded) {
            ctx.strokeStyle = 'rgba(99, 179, 237, 0.7)';
            ctx.lineWidth = 3;
            ctx.beginPath();
            ctx.arc(x, y, 26 * breathScale, 0, Math.PI * 2);
            ctx.stroke();
        }

        // Phase 2: Flash effect when hit
        const isFlashing = crew.flashTime > 0;
        const flashIntensity = isFlashing ? (crew.flashTime / 150) : 0;

        // Crew circle with breathing
        if (isFlashing) {
            const r = parseInt(crew.color.slice(1, 3), 16);
            const g = parseInt(crew.color.slice(3, 5), 16);
            const b = parseInt(crew.color.slice(5, 7), 16);
            const flashR = Math.min(255, r + (255 - r) * flashIntensity);
            const flashG = Math.min(255, g + (255 - g) * flashIntensity);
            const flashB = Math.min(255, b + (255 - b) * flashIntensity);
            ctx.fillStyle = `rgb(${Math.floor(flashR)}, ${Math.floor(flashG)}, ${Math.floor(flashB)})`;
        } else {
            ctx.fillStyle = crew.color;
        }
        ctx.beginPath();
        ctx.arc(x, y, 20 * breathScale, 0, Math.PI * 2);
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
        ctx.fillText(crew.name[0], x, y);

        // Squad member visualization - humanoid figures around the main circle
        const squadRadius = 30 * breathScale;
        const maxMembers = crew.maxSquadSize;
        const aliveMembers = crew.squadSize;

        for (let i = 0; i < maxMembers; i++) {
            // Distribute members evenly around the circle (starting from top)
            const angle = -Math.PI / 2 + (Math.PI * 2 / maxMembers) * i;
            const memberX = x + Math.cos(angle) * squadRadius;
            const memberY = y + Math.sin(angle) * squadRadius;

            ctx.save();
            ctx.translate(memberX, memberY);

            if (i < aliveMembers) {
                // Alive member - humanoid shape (head + body ellipse)
                ctx.fillStyle = crew.color;
                ctx.beginPath();
                ctx.ellipse(0, 2, 3, 5, 0, 0, Math.PI * 2);
                ctx.fill();
                ctx.strokeStyle = '#fff';
                ctx.lineWidth = 0.5;
                ctx.stroke();

                ctx.fillStyle = crew.color;
                ctx.beginPath();
                ctx.arc(0, -4, 2.5, 0, Math.PI * 2);
                ctx.fill();
                ctx.stroke();
            } else {
                // Dead member - ghostly/dim humanoid
                ctx.globalAlpha = 0.3;
                ctx.fillStyle = '#666';
                ctx.beginPath();
                ctx.ellipse(0, 2, 3, 5, 0, 0, Math.PI * 2);
                ctx.fill();
                ctx.strokeStyle = '#999';
                ctx.lineWidth = 0.5;
                ctx.stroke();

                ctx.beginPath();
                ctx.arc(0, -4, 2.5, 0, Math.PI * 2);
                ctx.fill();
                ctx.stroke();
                ctx.globalAlpha = 1;
            }

            ctx.restore();
        }

        // Phase 3: Smooth health bar with damage indicator
        const healthPct = crew.squadSize / crew.maxSquadSize;
        const displayHealthPct = crew.displayHealth / crew.maxSquadSize;
        const barWidth = 30;
        const barHeight = 4;
        const barX = x - barWidth / 2;
        const barY = y - 38; // Moved up to accommodate squad figures

        ctx.fillStyle = '#333';
        ctx.fillRect(barX, barY, barWidth, barHeight);
        // Damage indicator
        if (displayHealthPct > healthPct) {
            ctx.fillStyle = '#fc8181';
            ctx.fillRect(barX, barY, barWidth * displayHealthPct, barHeight);
        }
        ctx.fillStyle = healthPct > 0.5 ? '#48bb78' : healthPct > 0.25 ? '#f6ad55' : '#fc8181';
        ctx.fillRect(barX, barY, barWidth * healthPct, barHeight);

        // Squad count
        ctx.fillStyle = '#fff';
        ctx.font = '10px sans-serif';
        ctx.fillText(`${crew.squadSize}/${crew.maxSquadSize}`, x, barY - 6);

        // Skill cooldown indicator
        if (SkillSystem) {
            const cdPct = SkillSystem.getCooldownPercent(crew.id);
            if (cdPct > 0) {
                ctx.strokeStyle = 'rgba(255, 255, 255, 0.3)';
                ctx.lineWidth = 3;
                ctx.beginPath();
                ctx.arc(x, y, 23, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * (1 - cdPct));
                ctx.stroke();
            }
        }

        // Stun indicator
        if (crew.stunned) {
            ctx.fillStyle = '#fff';
            ctx.font = '12px sans-serif';
            ctx.fillText('💫', x, y - 35);
        }

        // Direction indicator
        let facingAngle = crew.facingAngle;
        if (!facingAngle && crew.targetEnemy) {
            const targetPos = this.getEntityScreenPos(crew.targetEnemy);
            facingAngle = Math.atan2(targetPos.y - y, targetPos.x - x);
        }

        if (facingAngle !== undefined) {
            const arrowDist = 28;
            const arrowX = x + Math.cos(facingAngle) * arrowDist;
            const arrowY = y + Math.sin(facingAngle) * arrowDist;

            ctx.fillStyle = crew.color;
            ctx.beginPath();
            ctx.moveTo(arrowX + Math.cos(facingAngle) * 6, arrowY + Math.sin(facingAngle) * 6);
            ctx.lineTo(arrowX + Math.cos(facingAngle + 2.5) * 5, arrowY + Math.sin(facingAngle + 2.5) * 5);
            ctx.lineTo(arrowX + Math.cos(facingAngle - 2.5) * 5, arrowY + Math.sin(facingAngle - 2.5) * 5);
            ctx.closePath();
            ctx.fill();
        }
    },

    /**
     * Render an enemy in isometric view
     */
    renderEnemyIsometric(enemy) {
        const ctx = this.ctx;
        const pos = this.getEntityScreenPos(enemy);
        const x = pos.x;
        const y = pos.y;

        // Phase 3: Smooth health bar transition
        if (enemy.displayHealth === undefined) enemy.displayHealth = enemy.health;
        enemy.displayHealth += (enemy.health - enemy.displayHealth) * 0.15;

        // Get render data
        const color = enemy.visual?.color || enemy.color || '#ff6b6b';
        const size = enemy.visual?.size || enemy.size || 15;
        const isStunned = enemy.isStunned || enemy.stunned;
        const isSlowed = enemy.slowMultiplier < 1 || enemy.slowed;
        const hasShield = enemy.hasShield;

        // Phase 2: Enhanced flash effect
        const isFlashing = enemy.flashTime > 0;
        const flashIntensity = isFlashing ? (enemy.flashTime / 150) : 0;

        // Enemy circle with flash effect
        if (isFlashing) {
            let r = 255, g = 107, b = 107;
            if (color.startsWith('#') && color.length === 7) {
                r = parseInt(color.slice(1, 3), 16);
                g = parseInt(color.slice(3, 5), 16);
                b = parseInt(color.slice(5, 7), 16);
            }
            const flashR = Math.min(255, r + (255 - r) * flashIntensity);
            const flashG = Math.min(255, g + (255 - g) * flashIntensity);
            const flashB = Math.min(255, b + (255 - b) * flashIntensity);
            ctx.fillStyle = `rgb(${Math.floor(flashR)}, ${Math.floor(flashG)}, ${Math.floor(flashB)})`;
        } else {
            ctx.fillStyle = color;
        }
        ctx.beginPath();
        ctx.arc(x, y, size, 0, Math.PI * 2);
        ctx.fill();

        // Boss indicator
        if (enemy.isBoss) {
            ctx.strokeStyle = '#ffd700';
            ctx.lineWidth = 3;
            ctx.beginPath();
            ctx.arc(x, y, size + 3, 0, Math.PI * 2);
            ctx.stroke();
        }

        // Shield indicator
        if (hasShield) {
            ctx.strokeStyle = 'rgba(100, 200, 255, 0.8)';
            ctx.lineWidth = 2;
            ctx.beginPath();
            ctx.arc(x, y, size + 4, 0, Math.PI * 2);
            ctx.stroke();
        }

        // Marked indicator
        if (enemy.marked) {
            ctx.strokeStyle = '#4a9eff';
            ctx.lineWidth = 2;
            ctx.setLineDash([3, 3]);
            ctx.beginPath();
            ctx.arc(x, y, size + 5, 0, Math.PI * 2);
            ctx.stroke();
            ctx.setLineDash([]);
        }

        // Illuminated indicator
        if (enemy.illuminated) {
            ctx.fillStyle = 'rgba(246, 173, 85, 0.2)';
            ctx.beginPath();
            ctx.arc(x, y, size + 8, 0, Math.PI * 2);
            ctx.fill();
        }

        // Stun indicator
        if (isStunned) {
            ctx.fillStyle = '#fff';
            ctx.font = '12px sans-serif';
            ctx.textAlign = 'center';
            ctx.fillText('💫', x, y - size - 5);
        }

        // Slow indicator
        if (isSlowed) {
            ctx.fillStyle = '#63b3ed';
            ctx.font = '10px sans-serif';
            ctx.textAlign = 'center';
            ctx.fillText('❄️', x, y);
        }

        // Phase 3: Smooth health bar with damage indicator
        const healthPct = enemy.health / enemy.maxHealth;
        const displayHealthPct = enemy.displayHealth / enemy.maxHealth;
        const barWidth = size * 2;
        const barHeight = 3;
        const barX = x - barWidth / 2;
        const barY = y - size - 8;

        ctx.fillStyle = '#333';
        ctx.fillRect(barX, barY, barWidth, barHeight);
        // Damage indicator
        if (displayHealthPct > healthPct) {
            ctx.fillStyle = '#fff';
            ctx.fillRect(barX, barY, barWidth * displayHealthPct, barHeight);
        }
        ctx.fillStyle = enemy.isBoss ? '#ffd700' : '#fc8181';
        ctx.fillRect(barX, barY, barWidth * healthPct, barHeight);

        // Boss emoji
        if (enemy.type === 'pirateCaptain' || enemy.type === 'stormCore') {
            ctx.fillStyle = '#fff';
            ctx.font = 'bold 16px sans-serif';
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            ctx.fillText('👹', x, y);
        }

        // Direction indicator
        let facingAngle = enemy.facingAngle;
        if (!facingAngle && enemy.target) {
            const targetPos = this.getEntityScreenPos(enemy.target);
            facingAngle = Math.atan2(targetPos.y - y, targetPos.x - x);
        }

        if (facingAngle !== undefined) {
            const arrowDist = size + 8;
            const arrowX = x + Math.cos(facingAngle) * arrowDist;
            const arrowY = y + Math.sin(facingAngle) * arrowDist;

            ctx.fillStyle = color;
            ctx.globalAlpha = 0.8;
            ctx.beginPath();
            ctx.moveTo(arrowX + Math.cos(facingAngle) * 4, arrowY + Math.sin(facingAngle) * 4);
            ctx.lineTo(arrowX + Math.cos(facingAngle + 2.5) * 4, arrowY + Math.sin(facingAngle + 2.5) * 4);
            ctx.lineTo(arrowX + Math.cos(facingAngle - 2.5) * 4, arrowY + Math.sin(facingAngle - 2.5) * 4);
            ctx.closePath();
            ctx.fill();
            ctx.globalAlpha = 1;
        }
    },

    renderCrew(crew) {
        const ctx = this.ctx;

        // Phase 3: Smooth health bar transition
        if (crew.displayHealth === undefined) crew.displayHealth = crew.squadSize;
        crew.displayHealth += (crew.squadSize - crew.displayHealth) * 0.15;

        // Phase 3: Idle breathing animation
        if (!crew.idlePhase) crew.idlePhase = Math.random() * Math.PI * 2;
        const idleTime = performance.now() / 1000;
        const breathScale = crew.state === 'idle' ? 1 + Math.sin(idleTime * 2 + crew.idlePhase) * 0.03 : 1;

        // Phase 3: Combat state indicator
        if (crew.state === 'attacking') {
            const pulsePhase = (idleTime * 4) % 1;
            ctx.strokeStyle = `rgba(255, 100, 100, ${0.5 - pulsePhase * 0.5})`;
            ctx.lineWidth = 2;
            ctx.beginPath();
            ctx.arc(crew.x, crew.y, 20 * breathScale + 5 + pulsePhase * 10, 0, Math.PI * 2);
            ctx.stroke();
        }

        // Invulnerability effect
        if (crew.invulnerable) {
            ctx.fillStyle = 'rgba(183, 148, 244, 0.3)';
            ctx.beginPath();
            ctx.arc(crew.x, crew.y, 28 * breathScale, 0, Math.PI * 2);
            ctx.fill();
        }

        // Shield effect
        if (crew.shielded) {
            ctx.strokeStyle = 'rgba(99, 179, 237, 0.7)';
            ctx.lineWidth = 3;
            ctx.beginPath();
            ctx.arc(crew.x, crew.y, 26 * breathScale, 0, Math.PI * 2);
            ctx.stroke();
        }

        // Phase 2: Flash effect when hit
        const isFlashing = crew.flashTime > 0;
        const flashIntensity = isFlashing ? (crew.flashTime / 150) : 0;

        // Crew circle with breathing
        if (isFlashing) {
            const r = parseInt(crew.color.slice(1, 3), 16);
            const g = parseInt(crew.color.slice(3, 5), 16);
            const b = parseInt(crew.color.slice(5, 7), 16);
            const flashR = Math.min(255, r + (255 - r) * flashIntensity);
            const flashG = Math.min(255, g + (255 - g) * flashIntensity);
            const flashB = Math.min(255, b + (255 - b) * flashIntensity);
            ctx.fillStyle = `rgb(${Math.floor(flashR)}, ${Math.floor(flashG)}, ${Math.floor(flashB)})`;
        } else {
            ctx.fillStyle = crew.color;
        }
        ctx.beginPath();
        ctx.arc(crew.x, crew.y, 20 * breathScale, 0, Math.PI * 2);
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

        // Squad member visualization - humanoid figures around the main circle
        const squadRadius = 30 * breathScale;
        const maxMembers = crew.maxSquadSize;
        const aliveMembers = crew.squadSize;

        for (let i = 0; i < maxMembers; i++) {
            // Distribute members evenly around the circle (starting from top)
            const angle = -Math.PI / 2 + (Math.PI * 2 / maxMembers) * i;
            const memberX = crew.x + Math.cos(angle) * squadRadius;
            const memberY = crew.y + Math.sin(angle) * squadRadius;

            ctx.save();
            ctx.translate(memberX, memberY);

            if (i < aliveMembers) {
                // Alive member - humanoid shape (head + body ellipse)
                // Body (ellipse - taller than wide)
                ctx.fillStyle = crew.color;
                ctx.beginPath();
                ctx.ellipse(0, 2, 3, 5, 0, 0, Math.PI * 2);
                ctx.fill();
                ctx.strokeStyle = '#fff';
                ctx.lineWidth = 0.5;
                ctx.stroke();

                // Head (small circle)
                ctx.fillStyle = crew.color;
                ctx.beginPath();
                ctx.arc(0, -4, 2.5, 0, Math.PI * 2);
                ctx.fill();
                ctx.stroke();
            } else {
                // Dead member - ghostly/dim humanoid
                ctx.globalAlpha = 0.3;
                // Body
                ctx.fillStyle = '#666';
                ctx.beginPath();
                ctx.ellipse(0, 2, 3, 5, 0, 0, Math.PI * 2);
                ctx.fill();
                ctx.strokeStyle = '#999';
                ctx.lineWidth = 0.5;
                ctx.stroke();

                // Head
                ctx.beginPath();
                ctx.arc(0, -4, 2.5, 0, Math.PI * 2);
                ctx.fill();
                ctx.stroke();
                ctx.globalAlpha = 1;
            }

            ctx.restore();
        }

        // Phase 3: Smooth health bar with damage indicator
        const healthPct = crew.squadSize / crew.maxSquadSize;
        const displayHealthPct = crew.displayHealth / crew.maxSquadSize;
        const barWidth = 30;
        const barHeight = 4;
        const barX = crew.x - barWidth / 2;
        const barY = crew.y - 38; // Moved up to accommodate squad dots

        ctx.fillStyle = '#333';
        ctx.fillRect(barX, barY, barWidth, barHeight);
        // Damage indicator (red bar showing lost health)
        if (displayHealthPct > healthPct) {
            ctx.fillStyle = '#fc8181';
            ctx.fillRect(barX, barY, barWidth * displayHealthPct, barHeight);
        }
        ctx.fillStyle = healthPct > 0.5 ? '#48bb78' : healthPct > 0.25 ? '#f6ad55' : '#fc8181';
        ctx.fillRect(barX, barY, barWidth * healthPct, barHeight);

        // Squad count (above health bar)
        ctx.fillStyle = '#fff';
        ctx.font = '10px sans-serif';
        ctx.fillText(`${crew.squadSize}/${crew.maxSquadSize}`, crew.x, barY - 6);

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

        // Phase 1: Direction indicator (triangle pointing towards target/movement)
        let facingAngle = crew.facingAngle;
        if (!facingAngle && crew.targetEnemy) {
            facingAngle = Utils.angleBetween(crew.x, crew.y, crew.targetEnemy.x, crew.targetEnemy.y);
        } else if (!facingAngle && crew.path && crew.path.length > 0) {
            const nextTile = crew.path[0];
            const targetPixel = this.tileGrid?.tileToPixel(nextTile.x, nextTile.y, this.offsetX, this.offsetY);
            if (targetPixel) {
                facingAngle = Utils.angleBetween(crew.x, crew.y, targetPixel.x, targetPixel.y);
            }
        }

        if (facingAngle !== undefined) {
            const arrowDist = 28;
            const arrowX = crew.x + Math.cos(facingAngle) * arrowDist;
            const arrowY = crew.y + Math.sin(facingAngle) * arrowDist;

            ctx.fillStyle = crew.color;
            ctx.beginPath();
            // Triangle pointing in facing direction
            ctx.moveTo(arrowX + Math.cos(facingAngle) * 6, arrowY + Math.sin(facingAngle) * 6);
            ctx.lineTo(arrowX + Math.cos(facingAngle + 2.5) * 5, arrowY + Math.sin(facingAngle + 2.5) * 5);
            ctx.lineTo(arrowX + Math.cos(facingAngle - 2.5) * 5, arrowY + Math.sin(facingAngle - 2.5) * 5);
            ctx.closePath();
            ctx.fill();
        }
    },

    renderEnemy(enemy) {
        const ctx = this.ctx;

        // Phase 3: Smooth health bar transition
        if (enemy.displayHealth === undefined) enemy.displayHealth = enemy.health;
        enemy.displayHealth += (enemy.health - enemy.displayHealth) * 0.15;

        // Get render data (support both Enemy class and simple objects)
        const color = enemy.visual?.color || enemy.color || '#ff6b6b';
        const size = enemy.visual?.size || enemy.size || 15;
        const isStunned = enemy.isStunned || enemy.stunned;
        const isSlowed = enemy.slowMultiplier < 1 || enemy.slowed;
        const hasShield = enemy.hasShield;

        // Phase 2: Flash effect when hit
        const isFlashing = enemy.flashTime > 0;
        const flashIntensity = isFlashing ? (enemy.flashTime / 150) : 0;

        // Enemy circle with flash effect
        if (isFlashing) {
            // Parse hex color and flash to white
            let r = 255, g = 107, b = 107; // default red
            if (color.startsWith('#') && color.length === 7) {
                r = parseInt(color.slice(1, 3), 16);
                g = parseInt(color.slice(3, 5), 16);
                b = parseInt(color.slice(5, 7), 16);
            }
            const flashR = Math.min(255, r + (255 - r) * flashIntensity);
            const flashG = Math.min(255, g + (255 - g) * flashIntensity);
            const flashB = Math.min(255, b + (255 - b) * flashIntensity);
            ctx.fillStyle = `rgb(${Math.floor(flashR)}, ${Math.floor(flashG)}, ${Math.floor(flashB)})`;
        } else {
            ctx.fillStyle = color;
        }
        ctx.beginPath();
        ctx.arc(enemy.x, enemy.y, size, 0, Math.PI * 2);
        ctx.fill();

        // Boss indicator
        if (enemy.isBoss) {
            ctx.strokeStyle = '#ffd700';
            ctx.lineWidth = 3;
            ctx.beginPath();
            ctx.arc(enemy.x, enemy.y, size + 3, 0, Math.PI * 2);
            ctx.stroke();
        }

        // Shield indicator (from Shield Generator)
        if (hasShield) {
            ctx.strokeStyle = 'rgba(100, 200, 255, 0.8)';
            ctx.lineWidth = 2;
            ctx.beginPath();
            ctx.arc(enemy.x, enemy.y, size + 4, 0, Math.PI * 2);
            ctx.stroke();
        }

        // Marked indicator
        if (enemy.marked) {
            ctx.strokeStyle = '#4a9eff';
            ctx.lineWidth = 2;
            ctx.setLineDash([3, 3]);
            ctx.beginPath();
            ctx.arc(enemy.x, enemy.y, size + 5, 0, Math.PI * 2);
            ctx.stroke();
            ctx.setLineDash([]);
        }

        // Illuminated indicator
        if (enemy.illuminated) {
            ctx.fillStyle = 'rgba(246, 173, 85, 0.2)';
            ctx.beginPath();
            ctx.arc(enemy.x, enemy.y, size + 8, 0, Math.PI * 2);
            ctx.fill();
        }

        // Stun indicator
        if (isStunned) {
            ctx.fillStyle = '#fff';
            ctx.font = '12px sans-serif';
            ctx.textAlign = 'center';
            ctx.fillText('💫', enemy.x, enemy.y - size - 5);
        }

        // Slow indicator
        if (isSlowed) {
            ctx.fillStyle = '#63b3ed';
            ctx.font = '10px sans-serif';
            ctx.textAlign = 'center';
            ctx.fillText('❄️', enemy.x, enemy.y);
        }

        // Phase 3: Smooth health bar with damage indicator
        const healthPct = enemy.health / enemy.maxHealth;
        const displayHealthPct = enemy.displayHealth / enemy.maxHealth;
        const barWidth = size * 2;
        const barHeight = 3;
        const barX = enemy.x - barWidth / 2;
        const barY = enemy.y - size - 8;

        ctx.fillStyle = '#333';
        ctx.fillRect(barX, barY, barWidth, barHeight);
        // Damage indicator (shows health being lost)
        if (displayHealthPct > healthPct) {
            ctx.fillStyle = '#fff';
            ctx.fillRect(barX, barY, barWidth * displayHealthPct, barHeight);
        }
        ctx.fillStyle = enemy.isBoss ? '#ffd700' : '#fc8181';
        ctx.fillRect(barX, barY, barWidth * healthPct, barHeight);

        // Boss indicator
        if (enemy.type === 'pirateCaptain' || enemy.type === 'stormCore') {
            ctx.fillStyle = '#fff';
            ctx.font = 'bold 16px sans-serif';
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            ctx.fillText('👹', enemy.x, enemy.y);
        }

        // Phase 1: Direction indicator (triangle pointing towards target)
        let facingAngle = enemy.facingAngle;
        if (!facingAngle && enemy.target) {
            facingAngle = Utils.angleBetween(enemy.x, enemy.y, enemy.target.x, enemy.target.y);
        }

        if (facingAngle !== undefined) {
            const arrowDist = size + 8;
            const arrowX = enemy.x + Math.cos(facingAngle) * arrowDist;
            const arrowY = enemy.y + Math.sin(facingAngle) * arrowDist;

            ctx.fillStyle = color;
            ctx.globalAlpha = 0.8;
            ctx.beginPath();
            // Small triangle pointing in facing direction
            ctx.moveTo(arrowX + Math.cos(facingAngle) * 4, arrowY + Math.sin(facingAngle) * 4);
            ctx.lineTo(arrowX + Math.cos(facingAngle + 2.5) * 4, arrowY + Math.sin(facingAngle + 2.5) * 4);
            ctx.lineTo(arrowX + Math.cos(facingAngle - 2.5) * 4, arrowY + Math.sin(facingAngle - 2.5) * 4);
            ctx.closePath();
            ctx.fill();
            ctx.globalAlpha = 1;
        }
    },

    renderProjectile(proj) {
        const ctx = this.ctx;
        const color = proj.color || '#4a9eff';

        // Phase 3: Enhanced projectile with glow and longer trail

        // Store trail positions if not exists
        if (!proj.trailPositions) {
            proj.trailPositions = [];
        }

        // Add current position to trail
        proj.trailPositions.push({ x: proj.x, y: proj.y });

        // Keep only last 8 positions
        if (proj.trailPositions.length > 8) {
            proj.trailPositions.shift();
        }

        // Draw trail with fading effect
        if (proj.trailPositions.length > 1) {
            for (let i = 0; i < proj.trailPositions.length - 1; i++) {
                const alpha = (i / proj.trailPositions.length) * 0.6;
                const width = 1 + (i / proj.trailPositions.length) * 2;

                ctx.strokeStyle = color;
                ctx.lineWidth = width;
                ctx.globalAlpha = alpha;
                ctx.beginPath();
                ctx.moveTo(proj.trailPositions[i].x, proj.trailPositions[i].y);
                ctx.lineTo(proj.trailPositions[i + 1].x, proj.trailPositions[i + 1].y);
                ctx.stroke();
            }
        }

        // Glow effect
        ctx.globalAlpha = 0.3;
        ctx.fillStyle = color;
        ctx.beginPath();
        ctx.arc(proj.x, proj.y, 8, 0, Math.PI * 2);
        ctx.fill();

        // Core projectile
        ctx.globalAlpha = 1;
        ctx.fillStyle = proj.isCritical ? '#ffd700' : color;
        ctx.beginPath();
        ctx.arc(proj.x, proj.y, proj.isCritical ? 5 : 4, 0, Math.PI * 2);
        ctx.fill();

        // White center for critical
        if (proj.isCritical) {
            ctx.fillStyle = '#fff';
            ctx.beginPath();
            ctx.arc(proj.x, proj.y, 2, 0, Math.PI * 2);
            ctx.fill();
        }
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

            // Get crew screen position (isometric or legacy)
            const crewPos = this.getEntityScreenPos(crew);

            // Draw path line
            ctx.strokeStyle = crew.color || '#4a9eff';
            ctx.lineWidth = 2;
            ctx.globalAlpha = 0.4;
            ctx.setLineDash([5, 5]);

            ctx.beginPath();
            ctx.moveTo(crewPos.x, crewPos.y);

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
                if (effect.isCritical) {
                    // Critical hit - golden text with "!" and larger font
                    ctx.fillStyle = '#ffd700';
                    ctx.font = 'bold 18px sans-serif';
                    ctx.textAlign = 'center';
                    ctx.globalAlpha = 1 - progress;
                    // Shake effect for critical
                    const shakeX = (Math.random() - 0.5) * 4 * (1 - progress);
                    ctx.fillText(`-${effect.damage}!`, effect.x + shakeX, effect.y - progress * 40);
                    // Add glow effect
                    ctx.shadowColor = '#ffd700';
                    ctx.shadowBlur = 10;
                    ctx.fillText(`-${effect.damage}!`, effect.x + shakeX, effect.y - progress * 40);
                    ctx.shadowBlur = 0;
                } else {
                    ctx.fillStyle = effect.isCrewDamage ? '#fc8181' : '#fff';
                    ctx.font = 'bold 14px sans-serif';
                    ctx.textAlign = 'center';
                    ctx.globalAlpha = 1 - progress;
                    ctx.fillText(`-${effect.damage}`, effect.x, effect.y - progress * 30);
                }
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

            // Phase 1: Attack Windup Animation
            case 'attack_windup':
                const windupAngle = Utils.angleBetween(effect.x, effect.y, effect.targetX, effect.targetY);
                ctx.strokeStyle = effect.color || '#fff';
                ctx.lineWidth = 2;
                ctx.globalAlpha = 1 - progress;

                if (effect.isRanged) {
                    // Ranged windup - aiming line
                    const lineLen = 25 + progress * 15;
                    ctx.setLineDash([3, 3]);
                    ctx.beginPath();
                    ctx.moveTo(effect.x, effect.y);
                    ctx.lineTo(
                        effect.x + Math.cos(windupAngle) * lineLen,
                        effect.y + Math.sin(windupAngle) * lineLen
                    );
                    ctx.stroke();
                    ctx.setLineDash([]);
                    // Targeting circle
                    ctx.beginPath();
                    ctx.arc(
                        effect.x + Math.cos(windupAngle) * lineLen,
                        effect.y + Math.sin(windupAngle) * lineLen,
                        4, 0, Math.PI * 2
                    );
                    ctx.stroke();
                } else {
                    // Melee windup - pull back then strike arc
                    const pullback = Math.sin(progress * Math.PI) * 8;
                    // Draw arc showing attack direction
                    ctx.beginPath();
                    ctx.arc(effect.x - Math.cos(windupAngle) * pullback,
                            effect.y - Math.sin(windupAngle) * pullback,
                            25, windupAngle - 0.5, windupAngle + 0.5);
                    ctx.stroke();
                }
                ctx.globalAlpha = 1;
                break;

            // Phase 1: Critical Hit Particles
            case 'crit_particle':
                ctx.fillStyle = '#ffd700';
                ctx.globalAlpha = 1 - progress;
                const particleDist = 10 + progress * 35;
                const particleSize = 4 * (1 - progress);
                ctx.beginPath();
                ctx.arc(
                    effect.x + Math.cos(effect.angle) * particleDist,
                    effect.y + Math.sin(effect.angle) * particleDist,
                    particleSize, 0, Math.PI * 2
                );
                ctx.fill();
                ctx.globalAlpha = 1;
                break;

            // Phase 1: Critical Hit Flash
            case 'crit_flash':
                ctx.fillStyle = '#ffd700';
                ctx.globalAlpha = (1 - progress) * 0.5;
                ctx.beginPath();
                ctx.arc(effect.x, effect.y, 25 * (1 - progress * 0.5), 0, Math.PI * 2);
                ctx.fill();
                ctx.globalAlpha = 1;
                break;

            // Phase 2: Hit Impact Effect
            case 'hit_impact':
                ctx.strokeStyle = effect.color || '#fff';
                ctx.lineWidth = 2;
                ctx.globalAlpha = 1 - progress;
                // Impact ring
                ctx.beginPath();
                ctx.arc(effect.x, effect.y, 8 + progress * 15, 0, Math.PI * 2);
                ctx.stroke();
                // Impact cross
                const impactSize = 6 * (1 - progress);
                ctx.beginPath();
                ctx.moveTo(effect.x - impactSize, effect.y);
                ctx.lineTo(effect.x + impactSize, effect.y);
                ctx.moveTo(effect.x, effect.y - impactSize);
                ctx.lineTo(effect.x, effect.y + impactSize);
                ctx.stroke();
                ctx.globalAlpha = 1;
                break;

            // Phase 2: Enhanced Death Burst
            case 'death_burst':
                const particleCount = effect.particleCount || 8;
                ctx.fillStyle = effect.color || '#fc8181';
                ctx.globalAlpha = 1 - progress;

                // Central flash
                ctx.beginPath();
                ctx.arc(effect.x, effect.y, 15 * (1 - progress), 0, Math.PI * 2);
                ctx.fill();

                // Burst particles
                for (let i = 0; i < particleCount; i++) {
                    const burstAngle = (Math.PI * 2 / particleCount) * i + progress * 0.5;
                    const burstDist = progress * 60;
                    const burstSize = 5 * (1 - progress * 0.7);

                    ctx.beginPath();
                    ctx.arc(
                        effect.x + Math.cos(burstAngle) * burstDist,
                        effect.y + Math.sin(burstAngle) * burstDist,
                        burstSize, 0, Math.PI * 2
                    );
                    ctx.fill();
                }

                // Shockwave ring
                ctx.strokeStyle = effect.color || '#fc8181';
                ctx.lineWidth = 3 * (1 - progress);
                ctx.beginPath();
                ctx.arc(effect.x, effect.y, progress * 40, 0, Math.PI * 2);
                ctx.stroke();
                ctx.globalAlpha = 1;
                break;

            // Phase 2: Soul Rise Effect (for crew death)
            case 'soul_rise':
                ctx.globalAlpha = (1 - progress) * 0.8;

                // Rising soul orb
                const soulY = effect.y - progress * 50;
                const soulSize = 8 * (1 - progress * 0.5);

                // Glow
                const soulGradient = ctx.createRadialGradient(
                    effect.x, soulY, 0,
                    effect.x, soulY, soulSize * 2
                );
                soulGradient.addColorStop(0, effect.color || '#4a9eff');
                soulGradient.addColorStop(1, 'rgba(74, 158, 255, 0)');
                ctx.fillStyle = soulGradient;
                ctx.beginPath();
                ctx.arc(effect.x, soulY, soulSize * 2, 0, Math.PI * 2);
                ctx.fill();

                // Core
                ctx.fillStyle = '#fff';
                ctx.beginPath();
                ctx.arc(effect.x, soulY, soulSize * 0.5, 0, Math.PI * 2);
                ctx.fill();

                // Trail particles
                for (let i = 0; i < 3; i++) {
                    const trailY = soulY + (i + 1) * 10;
                    const trailSize = soulSize * (0.6 - i * 0.15);
                    const trailAlpha = (1 - progress) * (0.6 - i * 0.2);
                    ctx.globalAlpha = trailAlpha;
                    ctx.fillStyle = effect.color || '#4a9eff';
                    ctx.beginPath();
                    ctx.arc(effect.x, trailY, trailSize, 0, Math.PI * 2);
                    ctx.fill();
                }
                ctx.globalAlpha = 1;
                break;

            // Phase 2: Skill Activation Effect
            case 'skill_activate':
                ctx.globalAlpha = 1 - progress;

                // Rotating runes/symbols
                for (let i = 0; i < 6; i++) {
                    const runeAngle = (Math.PI * 2 / 6) * i + progress * Math.PI * 2;
                    const runeDist = 25 + progress * 15;
                    const runeX = effect.x + Math.cos(runeAngle) * runeDist;
                    const runeY = effect.y + Math.sin(runeAngle) * runeDist;

                    ctx.fillStyle = effect.color || '#b794f4';
                    ctx.beginPath();
                    ctx.arc(runeX, runeY, 3, 0, Math.PI * 2);
                    ctx.fill();
                }

                // Central burst
                ctx.strokeStyle = effect.color || '#b794f4';
                ctx.lineWidth = 2;
                ctx.beginPath();
                ctx.arc(effect.x, effect.y, 20 + progress * 30, 0, Math.PI * 2);
                ctx.stroke();

                // Inner glow
                const skillGradient = ctx.createRadialGradient(
                    effect.x, effect.y, 0,
                    effect.x, effect.y, 30
                );
                skillGradient.addColorStop(0, `rgba(183, 148, 244, ${0.3 * (1 - progress)})`);
                skillGradient.addColorStop(1, 'rgba(183, 148, 244, 0)');
                ctx.fillStyle = skillGradient;
                ctx.beginPath();
                ctx.arc(effect.x, effect.y, 30, 0, Math.PI * 2);
                ctx.fill();
                ctx.globalAlpha = 1;
                break;

            // Phase 2: Status Effect Applied
            case 'status_apply':
                ctx.globalAlpha = 1 - progress;
                ctx.fillStyle = effect.color || '#68d391';
                ctx.font = 'bold 12px sans-serif';
                ctx.textAlign = 'center';

                // Status icon rising
                const statusY = effect.y - 20 - progress * 20;
                ctx.fillText(effect.icon || '✦', effect.x, statusY);

                // Swirl particles
                for (let i = 0; i < 4; i++) {
                    const swirlAngle = (Math.PI * 2 / 4) * i + progress * Math.PI * 3;
                    const swirlDist = 15 * (1 - progress);
                    ctx.beginPath();
                    ctx.arc(
                        effect.x + Math.cos(swirlAngle) * swirlDist,
                        effect.y + Math.sin(swirlAngle) * swirlDist,
                        2, 0, Math.PI * 2
                    );
                    ctx.fill();
                }
                ctx.globalAlpha = 1;
                break;

            // Phase 3: Wave Start Effect
            case 'wave_start':
                ctx.globalAlpha = 1 - progress;

                // Expanding ring
                ctx.strokeStyle = effect.isBoss ? '#ffd700' : '#4a9eff';
                ctx.lineWidth = 3 * (1 - progress);
                ctx.beginPath();
                ctx.arc(effect.x, effect.y, 50 + progress * 200, 0, Math.PI * 2);
                ctx.stroke();

                // Inner glow
                const waveGradient = ctx.createRadialGradient(
                    effect.x, effect.y, 0,
                    effect.x, effect.y, 100 * (1 - progress)
                );
                const waveColor = effect.isBoss ? '255, 215, 0' : '74, 158, 255';
                waveGradient.addColorStop(0, `rgba(${waveColor}, ${0.3 * (1 - progress)})`);
                waveGradient.addColorStop(1, `rgba(${waveColor}, 0)`);
                ctx.fillStyle = waveGradient;
                ctx.beginPath();
                ctx.arc(effect.x, effect.y, 100 * (1 - progress), 0, Math.PI * 2);
                ctx.fill();

                // Wave number indicator
                if (progress < 0.5) {
                    ctx.fillStyle = effect.isBoss ? '#ffd700' : '#fff';
                    ctx.font = 'bold 24px sans-serif';
                    ctx.textAlign = 'center';
                    ctx.textBaseline = 'middle';
                    ctx.globalAlpha = 1 - progress * 2;
                    ctx.fillText(`${effect.waveNumber}`, effect.x, effect.y);
                }
                ctx.globalAlpha = 1;
                break;

            // Phase 3: Boss Entrance Effect
            case 'boss_entrance':
                ctx.globalAlpha = 1 - progress;

                // Multiple expanding rings
                for (let i = 0; i < 3; i++) {
                    const ringProgress = Math.max(0, progress - i * 0.15);
                    if (ringProgress <= 0) continue;

                    ctx.strokeStyle = '#ffd700';
                    ctx.lineWidth = 4 * (1 - ringProgress);
                    ctx.beginPath();
                    ctx.arc(effect.x, effect.y, ringProgress * 300, 0, Math.PI * 2);
                    ctx.stroke();
                }

                // Danger lines
                ctx.strokeStyle = '#fc8181';
                ctx.lineWidth = 2;
                for (let i = 0; i < 8; i++) {
                    const lineAngle = (Math.PI * 2 / 8) * i + progress * Math.PI;
                    const lineStart = 50 + progress * 100;
                    const lineEnd = 100 + progress * 200;
                    ctx.beginPath();
                    ctx.moveTo(
                        effect.x + Math.cos(lineAngle) * lineStart,
                        effect.y + Math.sin(lineAngle) * lineStart
                    );
                    ctx.lineTo(
                        effect.x + Math.cos(lineAngle) * lineEnd,
                        effect.y + Math.sin(lineAngle) * lineEnd
                    );
                    ctx.stroke();
                }

                // Central skull indicator
                if (progress < 0.7) {
                    ctx.fillStyle = '#ffd700';
                    ctx.font = '40px sans-serif';
                    ctx.textAlign = 'center';
                    ctx.textBaseline = 'middle';
                    ctx.globalAlpha = (1 - progress) * 1.5;
                    ctx.fillText('💀', effect.x, effect.y);
                }
                ctx.globalAlpha = 1;
                break;

            // Phase 3: Projectile Impact
            case 'projectile_impact':
                ctx.globalAlpha = 1 - progress;
                ctx.fillStyle = effect.color || '#4a9eff';

                // Splash particles
                for (let i = 0; i < 6; i++) {
                    const splashAngle = (Math.PI * 2 / 6) * i + progress;
                    const splashDist = progress * 20;
                    const splashSize = 3 * (1 - progress);
                    ctx.beginPath();
                    ctx.arc(
                        effect.x + Math.cos(splashAngle) * splashDist,
                        effect.y + Math.sin(splashAngle) * splashDist,
                        splashSize, 0, Math.PI * 2
                    );
                    ctx.fill();
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
