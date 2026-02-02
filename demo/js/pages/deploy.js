/**
 * THE FADING RAVEN - Deployment Controller
 * Handles pre-battle crew deployment
 */

const DeployController = {
    elements: {},
    stationLayout: null,
    deployedCrews: new Map(), // zoneId -> crewId
    selectedCrew: null,
    rng: null,

    init() {
        this.checkBattleData();
        this.cacheElements();
        this.initRNG();
        this.generateStation();
        this.bindEvents();
        this.renderStation();
        this.renderCrewPanel();
        this.updateBattleInfo();
        console.log('DeployController initialized');
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
            deploymentZones: document.getElementById('deployment-zones'),
        };
    },

    initRNG() {
        if (GameState.currentRun) {
            this.rng = new MultiStreamRNG(GameState.currentRun.seed);
        }
    },

    generateStation() {
        const stationRng = this.rng.get('stationLayout');
        const difficulty = this.battleInfo?.difficulty || 1;

        // Generate simple station layout
        const width = 8 + difficulty;
        const height = 6 + Math.floor(difficulty / 2);

        this.stationLayout = {
            width,
            height,
            tiles: [],
            zones: [],
            spawnPoints: [],
        };

        // Create tile grid
        for (let y = 0; y < height; y++) {
            const row = [];
            for (let x = 0; x < width; x++) {
                row.push({
                    type: 'floor',
                    walkable: true,
                });
            }
            this.stationLayout.tiles.push(row);
        }

        // Add some walls
        for (let i = 0; i < Math.floor(width * height * 0.1); i++) {
            const x = stationRng.range(1, width - 2);
            const y = stationRng.range(1, height - 2);
            this.stationLayout.tiles[y][x] = { type: 'wall', walkable: false };
        }

        // Create deployment zones (left side)
        const numZones = Math.min(3, GameState.getAliveCrews().length);
        for (let i = 0; i < numZones; i++) {
            const zoneY = Math.floor((height / (numZones + 1)) * (i + 1));
            this.stationLayout.zones.push({
                id: `zone-${i}`,
                x: 1,
                y: zoneY,
                width: 2,
                height: 1,
                crewId: null,
            });
        }

        // Create enemy spawn points (right side)
        const numSpawns = 2 + difficulty;
        for (let i = 0; i < numSpawns; i++) {
            const spawnY = stationRng.range(1, height - 2);
            this.stationLayout.spawnPoints.push({
                x: width - 2,
                y: spawnY,
            });
        }

        // Add some obstacles/cover
        for (let i = 0; i < Math.floor(width * height * 0.05); i++) {
            const x = stationRng.range(3, width - 4);
            const y = stationRng.range(0, height - 1);
            if (this.stationLayout.tiles[y][x].type === 'floor') {
                this.stationLayout.tiles[y][x] = { type: 'cover', walkable: true };
            }
        }
    },

    bindEvents() {
        // Canvas click for deployment
        this.elements.stationCanvas?.addEventListener('click', (e) => this.handleCanvasClick(e));

        // Crew selection
        this.elements.crewList?.addEventListener('click', (e) => {
            const card = e.target.closest('.crew-deploy-card');
            if (card) {
                this.selectCrew(card.dataset.crewId);
            }
        });

        // Start battle
        this.elements.btnStartBattle?.addEventListener('click', () => this.startBattle());

        // Retreat
        this.elements.btnRetreat?.addEventListener('click', () => this.retreat());

        // Window resize
        window.addEventListener('resize', Utils.debounce(() => this.renderStation(), 200));
    },

    renderStation() {
        const canvas = this.elements.stationCanvas;
        if (!canvas || !this.stationLayout) return;

        const ctx = canvas.getContext('2d');
        const rect = canvas.getBoundingClientRect();
        canvas.width = rect.width;
        canvas.height = rect.height;

        const tileSize = Math.min(
            (canvas.width - 40) / this.stationLayout.width,
            (canvas.height - 40) / this.stationLayout.height
        );

        const offsetX = (canvas.width - this.stationLayout.width * tileSize) / 2;
        const offsetY = (canvas.height - this.stationLayout.height * tileSize) / 2;

        // Store for click detection
        this.tileSize = tileSize;
        this.offsetX = offsetX;
        this.offsetY = offsetY;

        // Clear canvas
        ctx.fillStyle = '#0a0a12';
        ctx.fillRect(0, 0, canvas.width, canvas.height);

        // Draw tiles
        for (let y = 0; y < this.stationLayout.height; y++) {
            for (let x = 0; x < this.stationLayout.width; x++) {
                const tile = this.stationLayout.tiles[y][x];
                const px = offsetX + x * tileSize;
                const py = offsetY + y * tileSize;

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

                ctx.fillRect(px + 1, py + 1, tileSize - 2, tileSize - 2);

                // Grid lines
                ctx.strokeStyle = 'rgba(74, 158, 255, 0.1)';
                ctx.strokeRect(px, py, tileSize, tileSize);
            }
        }

        // Draw deployment zones
        this.stationLayout.zones.forEach((zone, index) => {
            const px = offsetX + zone.x * tileSize;
            const py = offsetY + zone.y * tileSize;
            const width = zone.width * tileSize;
            const height = zone.height * tileSize;

            ctx.fillStyle = zone.crewId ? 'rgba(72, 187, 120, 0.3)' : 'rgba(74, 158, 255, 0.2)';
            ctx.fillRect(px, py, width, height);

            ctx.strokeStyle = zone.crewId ? '#48bb78' : '#4a9eff';
            ctx.lineWidth = 2;
            ctx.strokeRect(px, py, width, height);

            // Zone label
            ctx.fillStyle = '#fff';
            ctx.font = '12px sans-serif';
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';

            if (zone.crewId) {
                const crew = GameState.getCrewById(zone.crewId);
                if (crew) {
                    ctx.fillText(crew.name, px + width / 2, py + height / 2);
                }
            } else {
                ctx.fillStyle = 'rgba(255, 255, 255, 0.5)';
                ctx.fillText(`배치 ${index + 1}`, px + width / 2, py + height / 2);
            }
        });

        // Draw spawn points
        this.stationLayout.spawnPoints.forEach(spawn => {
            const px = offsetX + spawn.x * tileSize + tileSize / 2;
            const py = offsetY + spawn.y * tileSize + tileSize / 2;

            ctx.fillStyle = 'rgba(252, 129, 129, 0.3)';
            ctx.beginPath();
            ctx.arc(px, py, tileSize / 3, 0, Math.PI * 2);
            ctx.fill();

            ctx.strokeStyle = '#fc8181';
            ctx.lineWidth = 2;
            ctx.stroke();

            ctx.fillStyle = '#fc8181';
            ctx.font = '16px sans-serif';
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            ctx.fillText('⚠', px, py);
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

            const classData = GameState.getClassData(crew.class);

            card.innerHTML = `
                <div class="crew-portrait ${crew.class}">${crew.name[0]}</div>
                <div class="crew-details">
                    <div class="crew-name">${crew.name}</div>
                    <div class="crew-class">${classData?.name || crew.class}</div>
                    <div class="crew-health-bar">
                        <div class="health-fill" style="width: ${(crew.squadSize / crew.maxSquadSize) * 100}%"></div>
                        <span class="health-text">${crew.squadSize}/${crew.maxSquadSize}</span>
                    </div>
                </div>
                <div class="deploy-status">${isDeployed ? '배치됨' : '대기 중'}</div>
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

        // Check if clicked on a deployment zone
        for (const zone of this.stationLayout.zones) {
            const zoneX = this.offsetX + zone.x * this.tileSize;
            const zoneY = this.offsetY + zone.y * this.tileSize;
            const zoneW = zone.width * this.tileSize;
            const zoneH = zone.height * this.tileSize;

            if (x >= zoneX && x <= zoneX + zoneW && y >= zoneY && y <= zoneY + zoneH) {
                // Deploy crew to this zone
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
            btn.textContent = deployedCount > 0 ? `전투 시작 (${deployedCount}명 배치됨)` : '승무원을 배치하세요';
        }
    },

    updateBattleInfo() {
        if (!this.battleInfo) return;

        const typeNames = {
            battle: '일반 전투',
            elite: '정예 전투',
            boss: '보스 전투',
        };

        if (this.elements.battleType) {
            this.elements.battleType.textContent = typeNames[this.battleInfo.type] || '전투';
        }

        if (this.elements.battleDifficulty) {
            this.elements.battleDifficulty.textContent = '⭐'.repeat(this.battleInfo.difficulty);
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
            alert('최소 1명의 승무원을 배치해야 합니다.');
            return;
        }

        // Store deployment data
        sessionStorage.setItem('deploymentData', JSON.stringify({
            stationLayout: this.stationLayout,
            deployedCrews: deployedCrews,
            battleInfo: this.battleInfo,
        }));

        // Navigate to battle
        Utils.navigateTo('battle');
    },

    retreat() {
        if (confirm('후퇴하시겠습니까? 이 노드는 다시 방문할 수 없습니다.')) {
            sessionStorage.removeItem('currentBattle');
            GameState.advanceTurn();
            Utils.navigateTo('sector');
        }
    }
};

// Initialize on DOM ready
document.addEventListener('DOMContentLoaded', () => {
    DeployController.init();
});
