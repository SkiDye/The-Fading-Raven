/**
 * THE FADING RAVEN - Deployment Controller
 * Handles pre-battle crew deployment
 * Integrated with StationGenerator for procedural layouts
 */

const DeployController = {
    elements: {},
    stationLayout: null,
    deployedCrews: new Map(),
    selectedCrew: null,
    rng: null,

    // Rendering state
    tileSize: 40,
    offsetX: 0,
    offsetY: 0,

    init() {
        this.checkBattleData();
        this.cacheElements();
        this.initRNG();
        this.generateStation();
        this.bindEvents();
        this.renderStation();
        this.renderCrewPanel();
        this.updateBattleInfo();
        console.log('DeployController initialized with StationGenerator');
    },

    checkBattleData() {
        const battleData = sessionStorage.getItem('currentBattle');
        if (!battleData || !GameState.hasActiveRun()) {
            Utils.navigateTo('sector');
            return;
        }
        this.battleInfo = JSON.parse(battleData);
    },

    cacheElements() {
        this.elements = {
            stationCanvas: document.getElementById('station-canvas'),
            crewPanel: document.getElementById('crew-panel'),
            crewList: document.getElementById('crew-list'),
            btnStartBattle: document.getElementById('btn-start-battle'),
            btnRetreat: document.getElementById('btn-retreat'),
            battleType: document.getElementById('battle-type'),
            battleDifficulty: document.getElementById('battle-difficulty'),
            battleReward: document.getElementById('battle-reward'),
            stationInfo: document.getElementById('station-info'),
        };
    },

    initRNG() {
        if (GameState.currentRun) {
            const seed = GameState.currentRun.seed + GameState.currentRun.turn * 1000;
            this.rng = new MultiStreamRNG(seed);
        }
    },

    generateStation() {
        if (!StationGenerator) {
            console.warn('StationGenerator not available, using fallback');
            this._generateFallbackStation();
            return;
        }

        const stationRng = this.rng.get('stationLayout');
        const difficultyScore = this.battleInfo?.difficultyScore ||
                               (1.0 + (this.battleInfo?.difficulty || 1) * 0.5);

        // Generate station using StationGenerator
        const layout = StationGenerator.generate(stationRng, difficultyScore);

        // Convert to battle-compatible format
        this.stationLayout = this._convertLayout(layout);

        // Log stats
        console.log('Station generated:', {
            size: `${layout.width}x${layout.height}`,
            facilities: layout.facilities.length,
            spawnPoints: layout.spawnPoints.length,
            totalCredits: layout.totalCredits,
        });
    },

    _convertLayout(generatedLayout) {
        const { width, height, grid, facilities, spawnPoints } = generatedLayout;

        // Convert grid to tiles format
        const tiles = [];
        for (let y = 0; y < height; y++) {
            const row = [];
            for (let x = 0; x < width; x++) {
                const tileType = grid[y][x];
                row.push({
                    type: this._getTileTypeName(tileType),
                    walkable: StationGenerator.isWalkable(generatedLayout, x, y),
                    elevated: tileType === StationGenerator.TILE.ELEVATED,
                    lowered: tileType === StationGenerator.TILE.LOWERED,
                    tileCode: tileType,
                });
            }
            tiles.push(row);
        }

        // Create deployment zones near airlocks (player spawn areas)
        // Place zones on the opposite side from enemy spawn points
        const zones = this._createDeploymentZones(generatedLayout);

        return {
            width,
            height,
            tiles,
            zones,
            spawnPoints: spawnPoints.map(sp => ({
                x: sp.x,
                y: sp.y,
                direction: sp.direction,
            })),
            facilities: facilities.map(f => ({
                id: f.id,
                type: f.type,
                x: f.x,
                y: f.y,
                credits: f.credits,
                health: 100,
                destroyed: false,
            })),
            totalCredits: generatedLayout.totalCredits,
            grid: grid, // Keep original grid for TileGrid
        };
    },

    _getTileTypeName(tileCode) {
        const names = {
            [StationGenerator.TILE.VOID]: 'void',
            [StationGenerator.TILE.FLOOR]: 'floor',
            [StationGenerator.TILE.WALL]: 'wall',
            [StationGenerator.TILE.FACILITY]: 'facility',
            [StationGenerator.TILE.AIRLOCK]: 'airlock',
            [StationGenerator.TILE.ELEVATED]: 'elevated',
            [StationGenerator.TILE.LOWERED]: 'lowered',
            [StationGenerator.TILE.CORRIDOR]: 'corridor',
        };
        return names[tileCode] || 'floor';
    },

    _createDeploymentZones(layout) {
        const zones = [];
        const { width, height, spawnPoints } = layout;
        const maxCrews = Math.min(3, GameState.getAliveCrews().length);

        if (maxCrews === 0) return zones;

        // Find average spawn point position to determine enemy side
        // Default to right side if no spawn points
        let playerSide = 'left';
        if (spawnPoints && spawnPoints.length > 0) {
            const avgSpawnX = spawnPoints.reduce((sum, sp) => sum + sp.x, 0) / spawnPoints.length;
            playerSide = avgSpawnX > width / 2 ? 'left' : 'right';
        }

        // Find walkable tiles on player side
        const candidateTiles = [];
        for (let y = 1; y < height - 1; y++) {
            for (let x = 1; x < width - 1; x++) {
                const isPlayerSide = playerSide === 'left' ? x < width / 3 : x > width * 2 / 3;
                if (isPlayerSide && StationGenerator.isWalkable(layout, x, y)) {
                    // Check if not too close to spawn points
                    const nearSpawn = spawnPoints && spawnPoints.some(sp =>
                        Math.abs(sp.x - x) + Math.abs(sp.y - y) < 3
                    );
                    if (!nearSpawn) {
                        candidateTiles.push({ x, y });
                    }
                }
            }
        }

        // If no candidates on player side, try the entire map
        if (candidateTiles.length === 0) {
            for (let y = 1; y < height - 1; y++) {
                for (let x = 1; x < width - 1; x++) {
                    if (StationGenerator.isWalkable(layout, x, y)) {
                        candidateTiles.push({ x, y });
                    }
                }
            }
        }

        // Select spread out positions for deployment zones
        const spacing = Math.max(1, Math.floor(candidateTiles.length / (maxCrews + 1)));
        for (let i = 0; i < maxCrews; i++) {
            const idx = Math.min(spacing * (i + 1), candidateTiles.length - 1);
            if (idx >= 0 && idx < candidateTiles.length) {
                const tile = candidateTiles[idx];
                zones.push({
                    id: `zone-${i}`,
                    x: tile.x,
                    y: tile.y,
                    width: 1,
                    height: 1,
                    crewId: null,
                });
            }
        }

        // Fallback if not enough zones
        if (zones.length < maxCrews && candidateTiles.length > 0) {
            for (let i = zones.length; i < maxCrews && i < candidateTiles.length; i++) {
                const tile = candidateTiles[i];
                zones.push({
                    id: `zone-${i}`,
                    x: tile.x,
                    y: tile.y,
                    width: 1,
                    height: 1,
                    crewId: null,
                });
            }
        }

        // Ultimate fallback - create zones at fixed positions
        if (zones.length === 0 && maxCrews > 0) {
            for (let i = 0; i < maxCrews; i++) {
                zones.push({
                    id: `zone-${i}`,
                    x: 2,
                    y: Math.floor((height / (maxCrews + 1)) * (i + 1)),
                    width: 1,
                    height: 1,
                    crewId: null,
                });
            }
        }

        return zones;
    },

    _generateFallbackStation() {
        // Fallback for when StationGenerator is not available
        const stationRng = this.rng?.get('stationLayout') || { range: (a, b) => a, random: () => 0.5 };
        const difficulty = this.battleInfo?.difficulty || 1;

        const width = 8 + difficulty;
        const height = 6 + Math.floor(difficulty / 2);

        this.stationLayout = {
            width,
            height,
            tiles: [],
            zones: [],
            spawnPoints: [],
            facilities: [],
            totalCredits: 5,
        };

        for (let y = 0; y < height; y++) {
            const row = [];
            for (let x = 0; x < width; x++) {
                row.push({ type: 'floor', walkable: true });
            }
            this.stationLayout.tiles.push(row);
        }

        const numZones = Math.min(3, GameState.getAliveCrews().length);
        for (let i = 0; i < numZones; i++) {
            const zoneY = Math.floor((height / (numZones + 1)) * (i + 1));
            this.stationLayout.zones.push({
                id: `zone-${i}`,
                x: 1,
                y: zoneY,
                width: 1,
                height: 1,
                crewId: null,
            });
        }

        const numSpawns = 2 + difficulty;
        for (let i = 0; i < numSpawns; i++) {
            this.stationLayout.spawnPoints.push({
                x: width - 2,
                y: Math.floor(height * (i + 1) / (numSpawns + 1)),
            });
        }
    },

    bindEvents() {
        this.elements.stationCanvas?.addEventListener('click', (e) => this.handleCanvasClick(e));

        this.elements.crewList?.addEventListener('click', (e) => {
            const card = e.target.closest('.crew-deploy-card');
            if (card) {
                this.selectCrew(card.dataset.crewId);
            }
        });

        this.elements.btnStartBattle?.addEventListener('click', () => this.startBattle());
        this.elements.btnRetreat?.addEventListener('click', () => this.retreat());

        window.addEventListener('resize', Utils.debounce(() => this.renderStation(), 200));
    },

    renderStation() {
        const canvas = this.elements.stationCanvas;
        if (!canvas || !this.stationLayout) return;

        const ctx = canvas.getContext('2d');
        const rect = canvas.getBoundingClientRect();
        canvas.width = rect.width;
        canvas.height = rect.height;

        this.tileSize = Math.min(
            (canvas.width - 60) / this.stationLayout.width,
            (canvas.height - 60) / this.stationLayout.height
        );

        this.offsetX = (canvas.width - this.stationLayout.width * this.tileSize) / 2;
        this.offsetY = (canvas.height - this.stationLayout.height * this.tileSize) / 2;

        // Clear canvas
        ctx.fillStyle = '#0a0a12';
        ctx.fillRect(0, 0, canvas.width, canvas.height);

        // Draw tiles
        this._renderTiles(ctx);

        // Draw facilities
        this._renderFacilities(ctx);

        // Draw deployment zones
        this._renderDeploymentZones(ctx);

        // Draw spawn points
        this._renderSpawnPoints(ctx);
    },

    _renderTiles(ctx) {
        const colors = {
            void: '#000000',
            floor: '#1a1a2e',
            wall: '#2d2d44',
            corridor: '#1e1e32',
            facility: '#252540',
            airlock: '#2a2a3e',
            elevated: '#1f1f38',
            lowered: '#151528',
            cover: '#252538',
        };

        for (let y = 0; y < this.stationLayout.height; y++) {
            for (let x = 0; x < this.stationLayout.width; x++) {
                const tile = this.stationLayout.tiles[y][x];
                const px = this.offsetX + x * this.tileSize;
                const py = this.offsetY + y * this.tileSize;

                // Fill
                ctx.fillStyle = colors[tile.type] || colors.floor;
                ctx.fillRect(px + 1, py + 1, this.tileSize - 2, this.tileSize - 2);

                // Grid lines
                ctx.strokeStyle = 'rgba(74, 158, 255, 0.08)';
                ctx.strokeRect(px, py, this.tileSize, this.tileSize);

                // Elevation indicator
                if (tile.elevated) {
                    ctx.strokeStyle = 'rgba(99, 179, 237, 0.3)';
                    ctx.lineWidth = 2;
                    ctx.strokeRect(px + 3, py + 3, this.tileSize - 6, this.tileSize - 6);
                } else if (tile.lowered) {
                    ctx.fillStyle = 'rgba(0, 0, 0, 0.2)';
                    ctx.fillRect(px + 1, py + 1, this.tileSize - 2, this.tileSize - 2);
                }
            }
        }
    },

    _renderFacilities(ctx) {
        if (!this.stationLayout.facilities) return;

        this.stationLayout.facilities.forEach(facility => {
            const px = this.offsetX + facility.x * this.tileSize;
            const py = this.offsetY + facility.y * this.tileSize;

            // Facility background
            ctx.fillStyle = 'rgba(246, 173, 85, 0.2)';
            ctx.fillRect(px + 2, py + 2, this.tileSize - 4, this.tileSize - 4);

            // Border
            ctx.strokeStyle = '#f6ad55';
            ctx.lineWidth = 2;
            ctx.strokeRect(px + 2, py + 2, this.tileSize - 4, this.tileSize - 4);

            // Credit value
            ctx.fillStyle = '#fff';
            ctx.font = `${this.tileSize * 0.35}px sans-serif`;
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            ctx.fillText(`💰${facility.credits}`, px + this.tileSize / 2, py + this.tileSize / 2);
        });
    },

    _renderDeploymentZones(ctx) {
        this.stationLayout.zones.forEach((zone, index) => {
            const px = this.offsetX + zone.x * this.tileSize;
            const py = this.offsetY + zone.y * this.tileSize;
            const width = zone.width * this.tileSize;
            const height = zone.height * this.tileSize;

            // Zone fill
            if (zone.crewId) {
                ctx.fillStyle = 'rgba(72, 187, 120, 0.4)';
            } else if (this.selectedCrew) {
                ctx.fillStyle = 'rgba(74, 158, 255, 0.3)';
            } else {
                ctx.fillStyle = 'rgba(74, 158, 255, 0.15)';
            }
            ctx.fillRect(px, py, width, height);

            // Border
            ctx.strokeStyle = zone.crewId ? '#48bb78' : '#4a9eff';
            ctx.lineWidth = 2;
            ctx.strokeRect(px, py, width, height);

            // Label
            ctx.fillStyle = '#fff';
            ctx.font = `${this.tileSize * 0.3}px sans-serif`;
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';

            if (zone.crewId) {
                const crew = GameState.getCrewById(zone.crewId);
                if (crew) {
                    const classData = CrewData?.getClass(crew.class);
                    ctx.fillStyle = classData?.color || '#4a9eff';
                    ctx.font = `bold ${this.tileSize * 0.4}px sans-serif`;
                    ctx.fillText(crew.name[0], px + width / 2, py + height / 2);
                }
            } else {
                ctx.fillStyle = 'rgba(255, 255, 255, 0.5)';
                ctx.fillText(`${index + 1}`, px + width / 2, py + height / 2);
            }
        });
    },

    _renderSpawnPoints(ctx) {
        this.stationLayout.spawnPoints.forEach(spawn => {
            const px = this.offsetX + spawn.x * this.tileSize + this.tileSize / 2;
            const py = this.offsetY + spawn.y * this.tileSize + this.tileSize / 2;

            // Warning circle
            ctx.fillStyle = 'rgba(252, 129, 129, 0.25)';
            ctx.beginPath();
            ctx.arc(px, py, this.tileSize * 0.4, 0, Math.PI * 2);
            ctx.fill();

            ctx.strokeStyle = '#fc8181';
            ctx.lineWidth = 2;
            ctx.stroke();

            // Arrow showing direction
            ctx.fillStyle = '#fc8181';
            ctx.font = `${this.tileSize * 0.4}px sans-serif`;
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';

            const arrows = { north: '↓', south: '↑', east: '←', west: '→' };
            ctx.fillText(arrows[spawn.direction] || '⚠', px, py);
        });
    },

    renderCrewPanel() {
        const list = this.elements.crewList;
        if (!list) return;

        list.innerHTML = '';

        const aliveCrews = GameState.getAliveCrews();
        aliveCrews.forEach(crew => {
            const isDeployed = this.isCrewDeployed(crew.id);
            const card = document.createElement('div');
            card.className = `crew-deploy-card ${crew.class} ${isDeployed ? 'deployed' : ''} ${this.selectedCrew === crew.id ? 'selected' : ''}`;
            card.dataset.crewId = crew.id;

            const classData = CrewData?.getClass(crew.class) || GameState.getClassData(crew.class);
            const traitData = TraitData?.get(crew.trait);

            card.innerHTML = `
                <div class="crew-portrait ${crew.class}" style="background-color: ${classData?.color || '#4a9eff'}">
                    ${crew.name[0]}
                </div>
                <div class="crew-details">
                    <div class="crew-name">${crew.name}</div>
                    <div class="crew-class">${classData?.name || classData?.nameEn || crew.class}</div>
                    ${traitData ? `<div class="crew-trait">${traitData.icon} ${traitData.name}</div>` : ''}
                    <div class="crew-health-bar">
                        <div class="health-fill" style="width: ${(crew.squadSize / crew.maxSquadSize) * 100}%"></div>
                        <span class="health-text">${crew.squadSize}/${crew.maxSquadSize}</span>
                    </div>
                </div>
                <div class="deploy-status">${isDeployed ? '✓' : '...'}</div>
            `;

            list.appendChild(card);
        });
    },

    isCrewDeployed(crewId) {
        return this.stationLayout.zones.some(zone => zone.crewId === crewId);
    },

    selectCrew(crewId) {
        if (this.selectedCrew === crewId) {
            this.selectedCrew = null;
        } else {
            // Remove from current zone if deployed
            this.stationLayout.zones.forEach(zone => {
                if (zone.crewId === crewId) {
                    zone.crewId = null;
                }
            });
            this.selectedCrew = crewId;
        }

        this.renderStation();
        this.renderCrewPanel();
        this.updateStartButton();
    },

    handleCanvasClick(e) {
        if (!this.selectedCrew) return;

        const rect = this.elements.stationCanvas.getBoundingClientRect();
        const x = e.clientX - rect.left;
        const y = e.clientY - rect.top;

        for (const zone of this.stationLayout.zones) {
            const zoneX = this.offsetX + zone.x * this.tileSize;
            const zoneY = this.offsetY + zone.y * this.tileSize;
            const zoneW = zone.width * this.tileSize;
            const zoneH = zone.height * this.tileSize;

            if (x >= zoneX && x <= zoneX + zoneW && y >= zoneY && y <= zoneY + zoneH) {
                zone.crewId = this.selectedCrew;
                this.selectedCrew = null;

                this.renderStation();
                this.renderCrewPanel();
                this.updateStartButton();
                return;
            }
        }
    },

    updateStartButton() {
        const deployedCount = this.stationLayout.zones.filter(z => z.crewId).length;
        const btn = this.elements.btnStartBattle;

        if (btn) {
            btn.disabled = deployedCount === 0;
            btn.textContent = deployedCount > 0
                ? `전투 시작 (${deployedCount}명)`
                : '승무원을 배치하세요';
        }
    },

    updateBattleInfo() {
        if (!this.battleInfo) return;

        const typeNames = {
            battle: '일반 전투',
            commander: '팀장 영입',
            equipment: '장비 획득',
            storm: '⚡ 폭풍 스테이지',
            boss: '💀 보스 전투',
            gate: '🚪 최종 전투',
        };

        if (this.elements.battleType) {
            this.elements.battleType.textContent = typeNames[this.battleInfo.type] || '전투';

            if (this.battleInfo.type === 'storm') {
                this.elements.battleType.classList.add('storm');
            }
            if (this.battleInfo.type === 'boss' || this.battleInfo.type === 'gate') {
                this.elements.battleType.classList.add('boss');
            }
        }

        if (this.elements.battleDifficulty) {
            const stars = Math.min(5, Math.ceil(this.battleInfo.difficultyScore || this.battleInfo.difficulty || 1));
            this.elements.battleDifficulty.textContent = '⭐'.repeat(stars);
        }

        if (this.elements.battleReward && this.battleInfo.reward) {
            const rewards = [];
            if (this.battleInfo.reward.credits) {
                rewards.push(`💰 ${this.battleInfo.reward.credits}`);
            }
            if (this.battleInfo.isRecruitment) {
                rewards.push('🚩 팀장 영입');
            }
            if (this.battleInfo.hasEquipment) {
                rewards.push('📦 장비');
            }
            this.elements.battleReward.textContent = rewards.join(' ') || '';
        }

        if (this.elements.stationInfo && this.stationLayout) {
            this.elements.stationInfo.textContent =
                `시설: ${this.stationLayout.facilities?.length || 0}개 (💰${this.stationLayout.totalCredits || 0})`;
        }
    },

    startBattle() {
        const deployedCrews = this.stationLayout.zones
            .filter(z => z.crewId)
            .map(z => ({
                crewId: z.crewId,
                zoneId: z.id,
                x: z.x,
                y: z.y,
            }));

        if (deployedCrews.length === 0) {
            if (Toast) {
                Toast.warning('최소 1명의 승무원을 배치해야 합니다.');
            } else {
                alert('최소 1명의 승무원을 배치해야 합니다.');
            }
            return;
        }

        // Store deployment data
        sessionStorage.setItem('deploymentData', JSON.stringify({
            stationLayout: this.stationLayout,
            deployedCrews: deployedCrews,
            battleInfo: this.battleInfo,
        }));

        Utils.navigateTo('battle');
    },

    retreat() {
        const confirmRetreat = () => {
            sessionStorage.removeItem('currentBattle');
            GameState.advanceTurn();
            Utils.navigateTo('sector');
        };

        if (ModalManager) {
            ModalManager.confirm(
                '후퇴하시겠습니까? 이 노드는 다시 방문할 수 없습니다.',
                confirmRetreat,
                null
            );
        } else if (confirm('후퇴하시겠습니까? 이 노드는 다시 방문할 수 없습니다.')) {
            confirmRetreat();
        }
    }
};

// Initialize on DOM ready
document.addEventListener('DOMContentLoaded', () => {
    DeployController.init();
});
