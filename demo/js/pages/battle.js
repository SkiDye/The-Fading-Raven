/**
 * THE FADING RAVEN - Battle Controller
 * Handles real-time tactical combat
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

    // Layout
    tileSize: 40,
    offsetX: 0,
    offsetY: 0,

    // Entities
    crews: [],
    enemies: [],
    projectiles: [],
    effects: [],

    // Battle state
    waveNumber: 0,
    totalWaves: 3,
    waveTimer: 0,
    waveDelay: 5000, // 5 seconds between waves
    enemiesRemaining: 0,
    stationHealth: 100,

    // Selection
    selectedCrew: null,
    targetPosition: null,

    // RNG
    rng: null,

    init() {
        this.checkDeploymentData();
        this.cacheElements();
        this.initCanvas();
        this.initRNG();
        this.setupBattle();
        this.bindEvents();
        this.startBattle();
        console.log('BattleController initialized');
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

        // Calculate tile size to fit station
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

    setupBattle() {
        // Setup crews from deployment
        this.crews = [];
        this.deploymentData.deployedCrews.forEach(deploy => {
            const crewData = GameState.getCrewById(deploy.crewId);
            if (crewData) {
                this.crews.push(this.createCrewEntity(crewData, deploy.x, deploy.y));
            }
        });

        // Initialize enemies array
        this.enemies = [];
        this.projectiles = [];
        this.effects = [];

        // Set total waves based on difficulty
        this.totalWaves = 2 + this.battleInfo.difficulty;
        if (this.battleInfo.type === 'boss') {
            this.totalWaves = 1;
        }

        // Create crew buttons
        this.createCrewButtons();
    },

    createCrewEntity(crewData, tileX, tileY) {
        const classData = GameState.getClassData(crewData.class);
        return {
            id: crewData.id,
            name: crewData.name,
            class: crewData.class,
            color: classData?.color || '#4a9eff',

            // Position (in pixels)
            x: (tileX + 0.5) * this.tileSize + this.offsetX,
            y: (tileY + 0.5) * this.tileSize + this.offsetY,
            targetX: null,
            targetY: null,

            // Stats
            squadSize: crewData.squadSize,
            maxSquadSize: crewData.maxSquadSize,
            damage: 10 + crewData.skillLevel * 2,
            attackRange: crewData.class === 'ranger' ? 200 : 60,
            attackSpeed: 1000, // ms between attacks
            moveSpeed: 80, // pixels per second

            // State
            state: 'idle', // idle, moving, attacking, using_skill
            attackTimer: 0,
            targetEnemy: null,
            skillCooldown: 0,
            skillMaxCooldown: 10000, // 10 seconds
        };
    },

    createEnemyEntity(type, spawnX, spawnY) {
        const enemyTypes = {
            grunt: { health: 20, damage: 5, speed: 50, color: '#fc8181', size: 15 },
            raider: { health: 30, damage: 8, speed: 70, color: '#f6ad55', size: 18 },
            brute: { health: 60, damage: 15, speed: 30, color: '#9f7aea', size: 25 },
            boss: { health: 200, damage: 25, speed: 25, color: '#e53e3e', size: 35 },
        };

        const data = enemyTypes[type] || enemyTypes.grunt;
        const difficultyMult = 1 + (this.battleInfo.difficulty - 1) * 0.25;

        return {
            id: Utils.generateId(),
            type: type,
            x: spawnX,
            y: spawnY,
            targetX: null,
            targetY: null,

            health: Math.floor(data.health * difficultyMult),
            maxHealth: Math.floor(data.health * difficultyMult),
            damage: Math.floor(data.damage * difficultyMult),
            speed: data.speed,
            color: data.color,
            size: data.size,

            state: 'moving',
            attackTimer: 0,
            attackSpeed: 1500,
            targetCrew: null,
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
            `;
            container.appendChild(btn);
        });
    },

    bindEvents() {
        // Canvas click for movement/selection
        this.canvas?.addEventListener('click', (e) => this.handleCanvasClick(e));
        this.canvas?.addEventListener('contextmenu', (e) => {
            e.preventDefault();
            this.handleCanvasRightClick(e);
        });

        // Crew selection
        this.elements.crewButtons?.addEventListener('click', (e) => {
            const btn = e.target.closest('.crew-btn');
            if (btn) {
                this.selectCrew(btn.dataset.crewId);
            }
        });

        // Keyboard controls
        document.addEventListener('keydown', (e) => this.handleKeyDown(e));

        // Pause button
        this.elements.btnPause?.addEventListener('click', () => this.togglePause());
        this.elements.btnResume?.addEventListener('click', () => this.togglePause());
        this.elements.btnRetreatBattle?.addEventListener('click', () => this.retreatFromBattle());

        // Window resize
        window.addEventListener('resize', Utils.debounce(() => {
            this.resizeCanvas();
        }, 200));
    },

    handleCanvasClick(e) {
        const rect = this.canvas.getBoundingClientRect();
        const x = e.clientX - rect.left;
        const y = e.clientY - rect.top;

        if (this.selectedCrew) {
            // Move selected crew
            this.selectedCrew.targetX = x;
            this.selectedCrew.targetY = y;
            this.selectedCrew.state = 'moving';
            this.selectedCrew.targetEnemy = null;

            // Show move indicator
            this.addEffect({
                type: 'move_indicator',
                x: x,
                y: y,
                duration: 500,
                timer: 0,
            });
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
        const rect = this.canvas.getBoundingClientRect();
        const x = e.clientX - rect.left;
        const y = e.clientY - rect.top;

        if (this.selectedCrew) {
            // Check if clicking on enemy
            for (const enemy of this.enemies) {
                if (Utils.distance(x, y, enemy.x, enemy.y) < enemy.size + 10) {
                    this.selectedCrew.targetEnemy = enemy;
                    this.selectedCrew.state = 'attacking';
                    return;
                }
            }
        }
    },

    handleKeyDown(e) {
        // Number keys for crew selection
        if (e.key >= '1' && e.key <= '9') {
            const index = parseInt(e.key) - 1;
            if (index < this.crews.length) {
                this.selectCrew(this.crews[index].id);
            }
        }

        // Escape to deselect
        if (e.key === 'Escape') {
            if (this.paused) {
                this.togglePause();
            } else {
                this.selectedCrew = null;
                this.updateCrewButtonSelection();
            }
        }

        // Space to pause
        if (e.key === ' ') {
            e.preventDefault();
            this.togglePause();
        }

        // Q for skill
        if (e.key === 'q' || e.key === 'Q') {
            if (this.selectedCrew && this.selectedCrew.skillCooldown <= 0) {
                this.useCrewSkill(this.selectedCrew);
            }
        }
    },

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

    startBattle() {
        this.running = true;
        this.waveNumber = 0;
        this.lastTime = performance.now();
        this.spawnNextWave();
        this.gameLoop();
    },

    gameLoop(currentTime = performance.now()) {
        if (!this.running || this.paused) return;

        this.deltaTime = currentTime - this.lastTime;
        this.lastTime = currentTime;

        this.update(this.deltaTime);
        this.render();

        requestAnimationFrame((t) => this.gameLoop(t));
    },

    update(dt) {
        // Update wave timer
        if (this.enemies.length === 0 && this.waveNumber < this.totalWaves) {
            this.waveTimer += dt;
            if (this.waveTimer >= this.waveDelay) {
                this.spawnNextWave();
            }
        }

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

        // Check battle end conditions
        this.checkBattleEnd();

        // Update HUD
        this.updateHUD();
    },

    updateCrew(crew, dt) {
        // Reduce cooldowns
        if (crew.skillCooldown > 0) {
            crew.skillCooldown -= dt;
        }
        crew.attackTimer -= dt;

        switch (crew.state) {
            case 'moving':
                if (crew.targetX !== null && crew.targetY !== null) {
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
                }
                break;

            case 'attacking':
                if (crew.targetEnemy) {
                    if (crew.targetEnemy.health <= 0) {
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
                } else {
                    crew.state = 'idle';
                }
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

    updateEnemy(enemy, dt) {
        enemy.attackTimer -= dt;

        // Find nearest crew or move towards station center
        const nearestCrew = this.findNearestCrew(enemy);

        if (nearestCrew) {
            const dist = Utils.distance(enemy.x, enemy.y, nearestCrew.x, nearestCrew.y);

            if (dist <= 50) {
                // Attack crew
                if (enemy.attackTimer <= 0) {
                    this.enemyAttack(enemy, nearestCrew);
                    enemy.attackTimer = enemy.attackSpeed;
                }
            } else {
                // Move towards crew
                const angle = Utils.angleBetween(enemy.x, enemy.y, nearestCrew.x, nearestCrew.y);
                const moveAmount = enemy.speed * (dt / 1000);
                enemy.x += Math.cos(angle) * moveAmount;
                enemy.y += Math.sin(angle) * moveAmount;
            }
        } else {
            // Move towards station center (damage station)
            const centerX = this.canvas.width / 2;
            const centerY = this.canvas.height / 2;
            const dist = Utils.distance(enemy.x, enemy.y, centerX, centerY);

            if (dist > 50) {
                const angle = Utils.angleBetween(enemy.x, enemy.y, centerX, centerY);
                const moveAmount = enemy.speed * (dt / 1000);
                enemy.x += Math.cos(angle) * moveAmount;
                enemy.y += Math.sin(angle) * moveAmount;
            } else {
                // Damage station
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
        if (proj.target && proj.target.health > 0) {
            if (Utils.distance(proj.x, proj.y, proj.target.x, proj.target.y) < proj.target.size + 5) {
                proj.target.health -= proj.damage;
                this.addDamageNumber(proj.target.x, proj.target.y, proj.damage);
                return false;
            }
        }

        // Remove if out of bounds
        if (proj.x < 0 || proj.x > this.canvas.width || proj.y < 0 || proj.y > this.canvas.height) {
            return false;
        }

        return true;
    },

    crewAttack(crew, enemy) {
        if (crew.class === 'ranger') {
            // Ranged attack - create projectile
            this.projectiles.push({
                x: crew.x,
                y: crew.y,
                angle: Utils.angleBetween(crew.x, crew.y, enemy.x, enemy.y),
                speed: 400,
                damage: crew.damage,
                target: enemy,
                color: crew.color,
            });
        } else {
            // Melee attack
            enemy.health -= crew.damage;
            this.addDamageNumber(enemy.x, enemy.y, crew.damage);

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
        crew.squadSize--;
        this.addDamageNumber(crew.x, crew.y, enemy.damage, true);

        if (crew.squadSize <= 0) {
            // Crew eliminated
            this.crews = this.crews.filter(c => c.id !== crew.id);
            this.addEffect({
                type: 'death',
                x: crew.x,
                y: crew.y,
                duration: 500,
                timer: 0,
            });
        }

        // Update crew button health
        this.updateCrewButtons();
    },

    useCrewSkill(crew) {
        crew.skillCooldown = crew.skillMaxCooldown;

        const skillRadius = 100;

        switch (crew.class) {
            case 'guardian':
                // Shield Bash - knockback and stun nearby enemies
                this.enemies.forEach(enemy => {
                    if (Utils.distance(crew.x, crew.y, enemy.x, enemy.y) < skillRadius) {
                        const angle = Utils.angleBetween(crew.x, crew.y, enemy.x, enemy.y);
                        enemy.x += Math.cos(angle) * 50;
                        enemy.y += Math.sin(angle) * 50;
                        enemy.health -= crew.damage;
                    }
                });
                this.addEffect({ type: 'shockwave', x: crew.x, y: crew.y, duration: 300, timer: 0, color: crew.color });
                break;

            case 'sentinel':
                // Lance Charge - dash forward and damage
                const nearestEnemy = this.findNearestEnemy(crew);
                if (nearestEnemy) {
                    crew.x = nearestEnemy.x;
                    crew.y = nearestEnemy.y;
                    nearestEnemy.health -= crew.damage * 2;
                    this.addDamageNumber(nearestEnemy.x, nearestEnemy.y, crew.damage * 2);
                }
                break;

            case 'ranger':
                // Volley Fire - hit all enemies in range
                this.enemies.forEach(enemy => {
                    if (Utils.distance(crew.x, crew.y, enemy.x, enemy.y) < crew.attackRange * 1.5) {
                        enemy.health -= crew.damage;
                        this.addDamageNumber(enemy.x, enemy.y, crew.damage);
                    }
                });
                this.addEffect({ type: 'volley', x: crew.x, y: crew.y, duration: 300, timer: 0, color: crew.color });
                break;
        }
    },

    findNearestEnemy(crew) {
        let nearest = null;
        let nearestDist = Infinity;

        this.enemies.forEach(enemy => {
            const dist = Utils.distance(crew.x, crew.y, enemy.x, enemy.y);
            if (dist < nearestDist) {
                nearestDist = dist;
                nearest = enemy;
            }
        });

        return nearest;
    },

    findNearestCrew(enemy) {
        let nearest = null;
        let nearestDist = Infinity;

        this.crews.forEach(crew => {
            const dist = Utils.distance(enemy.x, enemy.y, crew.x, crew.y);
            if (dist < nearestDist) {
                nearestDist = dist;
                nearest = crew;
            }
        });

        return nearest;
    },

    spawnNextWave() {
        this.waveNumber++;
        this.waveTimer = 0;

        // Show wave announcement
        this.showWaveAnnouncement();

        // Spawn enemies
        const enemyCount = 3 + this.waveNumber * 2 + this.battleInfo.difficulty;
        const combatRng = this.rng.get('combat');

        this.stationLayout.spawnPoints.forEach(spawn => {
            const spawnX = this.offsetX + spawn.x * this.tileSize + this.tileSize / 2;
            const spawnY = this.offsetY + spawn.y * this.tileSize + this.tileSize / 2;

            const countAtSpawn = Math.ceil(enemyCount / this.stationLayout.spawnPoints.length);

            for (let i = 0; i < countAtSpawn; i++) {
                let type = 'grunt';
                const roll = combatRng.random();

                if (this.battleInfo.type === 'boss' && i === 0) {
                    type = 'boss';
                } else if (roll > 0.9 && this.waveNumber >= 2) {
                    type = 'brute';
                } else if (roll > 0.7) {
                    type = 'raider';
                }

                // Stagger spawns
                setTimeout(() => {
                    const offsetX = combatRng.range(-20, 20);
                    const offsetY = combatRng.range(-20, 20);
                    this.enemies.push(this.createEnemyEntity(type, spawnX + offsetX, spawnY + offsetY));
                }, i * 300);
            }
        });
    },

    showWaveAnnouncement() {
        if (this.elements.waveAnnouncement && this.elements.waveText) {
            this.elements.waveText.textContent = this.battleInfo.type === 'boss'
                ? '보스 등장!'
                : `웨이브 ${this.waveNumber}/${this.totalWaves}`;
            this.elements.waveAnnouncement.classList.add('active');

            setTimeout(() => {
                this.elements.waveAnnouncement.classList.remove('active');
            }, 2000);
        }
    },

    addDamageNumber(x, y, damage, isCrewDamage = false) {
        this.effects.push({
            type: 'damage_number',
            x: x + (Math.random() - 0.5) * 20,
            y: y - 10,
            damage: Math.floor(damage),
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
            }
        });

        // Remove buttons for dead crews
        document.querySelectorAll('.crew-btn').forEach(btn => {
            if (!this.crews.find(c => c.id === btn.dataset.crewId)) {
                btn.classList.add('dead');
            }
        });
    },

    checkBattleEnd() {
        // Victory: All waves cleared and no enemies remaining
        if (this.waveNumber >= this.totalWaves && this.enemies.length === 0) {
            this.endBattle(true);
            return;
        }

        // Defeat: Station destroyed or all crews dead
        if (this.stationHealth <= 0 || this.crews.length === 0) {
            this.endBattle(false);
            return;
        }
    },

    endBattle(victory) {
        this.running = false;

        // Update crew states in GameState
        const aliveCrewIds = this.crews.map(c => c.id);
        GameState.currentRun.crews.forEach(crew => {
            const battleCrew = this.crews.find(c => c.id === crew.id);
            if (battleCrew) {
                crew.squadSize = battleCrew.squadSize;
                crew.health = battleCrew.squadSize;
                crew.battlesParticipated++;
            } else if (this.deploymentData.deployedCrews.find(d => d.crewId === crew.id)) {
                // Crew was deployed but died
                crew.isAlive = false;
                crew.squadSize = 0;
                GameState.currentRun.stats.crewsLost++;
            }
        });

        // Record battle results
        const enemiesKilled = this.waveNumber * 5; // Approximate
        GameState.recordEnemiesKilled(enemiesKilled);

        if (victory) {
            GameState.recordStationDefended(this.battleInfo.reward.credits || 50, this.stationHealth >= 100);
        } else {
            GameState.currentRun.stats.stationsLost++;
        }

        // Store result for result page
        sessionStorage.setItem('battleResult', JSON.stringify({
            victory,
            stationHealth: this.stationHealth,
            enemiesKilled,
            wavesCompleted: this.waveNumber,
            totalWaves: this.totalWaves,
            reward: victory ? this.battleInfo.reward : null,
            battleType: this.battleInfo.type,
        }));

        // Cleanup
        sessionStorage.removeItem('deploymentData');
        sessionStorage.removeItem('currentBattle');

        GameState.advanceTurn();

        // Navigate to result
        Utils.navigateTo('result');
    },

    retreatFromBattle() {
        if (confirm('전투에서 후퇴하시겠습니까? 보상을 받지 못합니다.')) {
            this.endBattle(false);
        }
    },

    render() {
        const ctx = this.ctx;
        if (!ctx) return;

        // Clear
        ctx.fillStyle = '#0a0a12';
        ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);

        // Draw station
        this.renderStation();

        // Draw effects (below entities)
        this.effects.filter(e => e.type === 'shockwave' || e.type === 'volley').forEach(e => this.renderEffect(e));

        // Draw enemies
        this.enemies.forEach(e => this.renderEnemy(e));

        // Draw crews
        this.crews.forEach(c => this.renderCrew(c));

        // Draw projectiles
        this.projectiles.forEach(p => this.renderProjectile(p));

        // Draw effects (above entities)
        this.effects.filter(e => e.type !== 'shockwave' && e.type !== 'volley').forEach(e => this.renderEffect(e));

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
    },

    renderStation() {
        const ctx = this.ctx;

        // Draw tiles
        for (let y = 0; y < this.stationLayout.height; y++) {
            for (let x = 0; x < this.stationLayout.width; x++) {
                const tile = this.stationLayout.tiles[y][x];
                const px = this.offsetX + x * this.tileSize;
                const py = this.offsetY + y * this.tileSize;

                switch (tile.type) {
                    case 'floor':
                        ctx.fillStyle = '#1a1a2e';
                        break;
                    case 'wall':
                        ctx.fillStyle = '#2d2d44';
                        break;
                    case 'cover':
                        ctx.fillStyle = '#252538';
                        break;
                }

                ctx.fillRect(px + 1, py + 1, this.tileSize - 2, this.tileSize - 2);
            }
        }

        // Draw spawn warning
        this.stationLayout.spawnPoints.forEach(spawn => {
            const px = this.offsetX + spawn.x * this.tileSize + this.tileSize / 2;
            const py = this.offsetY + spawn.y * this.tileSize + this.tileSize / 2;

            ctx.fillStyle = 'rgba(252, 129, 129, 0.2)';
            ctx.beginPath();
            ctx.arc(px, py, this.tileSize / 2, 0, Math.PI * 2);
            ctx.fill();
        });
    },

    renderCrew(crew) {
        const ctx = this.ctx;

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
        if (crew.skillCooldown > 0) {
            const cdPct = crew.skillCooldown / crew.skillMaxCooldown;
            ctx.strokeStyle = 'rgba(255, 255, 255, 0.3)';
            ctx.lineWidth = 3;
            ctx.beginPath();
            ctx.arc(crew.x, crew.y, 23, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * (1 - cdPct));
            ctx.stroke();
        }
    },

    renderEnemy(enemy) {
        const ctx = this.ctx;

        // Enemy circle
        ctx.fillStyle = enemy.color;
        ctx.beginPath();
        ctx.arc(enemy.x, enemy.y, enemy.size, 0, Math.PI * 2);
        ctx.fill();

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
        if (enemy.type === 'boss') {
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
                ctx.strokeStyle = effect.color || '#4a9eff';
                ctx.lineWidth = 3;
                ctx.globalAlpha = 1 - progress;
                ctx.beginPath();
                ctx.arc(effect.x, effect.y, progress * 100, 0, Math.PI * 2);
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
        }
    }
};

// Initialize on DOM ready
document.addEventListener('DOMContentLoaded', () => {
    BattleController.init();
});
