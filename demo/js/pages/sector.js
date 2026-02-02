/**
 * THE FADING RAVEN - Sector Map Controller
 * Handles sector map navigation and node selection
 */

const SectorController = {
    elements: {},
    selectedNode: null,
    rng: null,

    init() {
        this.checkActiveRun();
        this.cacheElements();
        this.bindEvents();
        this.initRNG();
        this.generateMapIfNeeded();
        this.renderMap();
        this.updateHUD();
        console.log('SectorController initialized');
    },

    checkActiveRun() {
        if (!GameState.hasActiveRun()) {
            Utils.navigateTo('index');
            return;
        }
    },

    cacheElements() {
        this.elements = {
            mapCanvas: document.getElementById('sector-map-canvas'),
            nodePopup: document.getElementById('node-popup'),
            popupTitle: document.getElementById('popup-title'),
            popupDesc: document.getElementById('popup-desc'),
            popupReward: document.getElementById('popup-reward'),
            popupDifficulty: document.getElementById('popup-difficulty'),
            btnEnterNode: document.getElementById('btn-enter-node'),
            btnCancelNode: document.getElementById('btn-cancel-node'),
            turnDisplay: document.getElementById('turn-display'),
            creditsDisplay: document.getElementById('credits-display'),
            crewRoster: document.getElementById('crew-roster'),
            stormWarning: document.getElementById('storm-warning'),
            stormTurns: document.getElementById('storm-turns'),
            btnMenu: document.getElementById('btn-menu'),
        };
    },

    bindEvents() {
        // Canvas click
        this.elements.mapCanvas?.addEventListener('click', (e) => this.handleMapClick(e));

        // Node popup
        this.elements.btnEnterNode?.addEventListener('click', () => this.enterSelectedNode());
        this.elements.btnCancelNode?.addEventListener('click', () => this.hideNodePopup());

        // Menu button
        this.elements.btnMenu?.addEventListener('click', () => this.showPauseMenu());

        // Close popup on backdrop click
        this.elements.nodePopup?.addEventListener('click', (e) => {
            if (e.target === this.elements.nodePopup) {
                this.hideNodePopup();
            }
        });

        // Keyboard
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                if (this.elements.nodePopup?.classList.contains('active')) {
                    this.hideNodePopup();
                } else {
                    this.showPauseMenu();
                }
            }
        });

        // Window resize
        window.addEventListener('resize', Utils.debounce(() => this.renderMap(), 200));
    },

    initRNG() {
        if (GameState.currentRun) {
            this.rng = new MultiStreamRNG(GameState.currentRun.seed);
        }
    },

    generateMapIfNeeded() {
        if (!GameState.currentRun) return;

        if (!GameState.currentRun.sectorMap) {
            GameState.currentRun.sectorMap = this.generateSectorMap();
            GameState.saveCurrentRun();
        }
    },

    generateSectorMap() {
        const mapRng = this.rng.get('sectorMap');
        const rows = 7;
        const nodesPerRow = [1, 2, 3, 3, 3, 2, 1];
        const nodeTypes = ['battle', 'elite', 'shop', 'event', 'rest'];

        const nodes = [];
        let nodeId = 0;

        // Generate nodes for each row
        for (let row = 0; row < rows; row++) {
            const rowNodes = [];
            const numNodes = nodesPerRow[row];

            for (let i = 0; i < numNodes; i++) {
                let type;
                if (row === 0) {
                    type = 'start';
                } else if (row === rows - 1) {
                    type = 'boss';
                } else {
                    // Weight node types
                    const weights = [50, 10, 15, 15, 10]; // battle, elite, shop, event, rest
                    type = mapRng.weightedPick(nodeTypes, weights);
                }

                const node = {
                    id: nodeId++,
                    row: row,
                    col: i,
                    type: type,
                    connections: [],
                    visited: row === 0, // Start node is visited
                    accessible: row === 0 || row === 1, // First two rows accessible
                    reward: this.generateNodeReward(type, row, mapRng),
                    difficulty: Math.min(row + 1, 5),
                    name: this.getNodeName(type, mapRng),
                };

                rowNodes.push(node);
            }

            nodes.push(rowNodes);
        }

        // Generate connections
        for (let row = 0; row < rows - 1; row++) {
            const currentRow = nodes[row];
            const nextRow = nodes[row + 1];

            currentRow.forEach((node, i) => {
                // Connect to nodes in next row
                const connections = [];
                const startIdx = Math.max(0, i - 1);
                const endIdx = Math.min(nextRow.length - 1, i + 1);

                for (let j = startIdx; j <= endIdx; j++) {
                    if (mapRng.chance(0.7) || connections.length === 0) {
                        connections.push(nextRow[j].id);
                    }
                }

                node.connections = connections;
            });
        }

        // Set current node to start
        if (!GameState.currentRun.currentNodeId) {
            GameState.currentRun.currentNodeId = 0;
            GameState.currentRun.visitedNodes = [0];
        }

        return nodes;
    },

    generateNodeReward(type, row, rng) {
        const baseReward = 50 + row * 25;
        switch (type) {
            case 'battle':
                return { credits: rng.range(baseReward, baseReward + 30) };
            case 'elite':
                return { credits: rng.range(baseReward * 1.5, baseReward * 2), equipment: true };
            case 'boss':
                return { credits: baseReward * 3, equipment: true };
            case 'shop':
                return { shop: true };
            case 'event':
                return { event: true };
            case 'rest':
                return { heal: true };
            default:
                return {};
        }
    },

    getNodeName(type, rng) {
        const names = {
            start: ['출발점'],
            battle: ['우주 정거장', '채굴 기지', '보급 정거장', '통신 중계소', '연구 시설'],
            elite: ['강화된 기지', '요새화된 정거장', '전략 거점'],
            shop: ['무역 허브', '상인 정거장', '암시장'],
            event: ['표류 우주선', '이상 신호', '미확인 객체', '긴급 구조 신호'],
            rest: ['안전 지대', '은신처', '수리 시설'],
            boss: ['적 본거지'],
        };
        return rng.pick(names[type] || ['알 수 없음']);
    },

    renderMap() {
        const canvas = this.elements.mapCanvas;
        if (!canvas || !GameState.currentRun?.sectorMap) return;

        const ctx = canvas.getContext('2d');
        const rect = canvas.getBoundingClientRect();
        canvas.width = rect.width;
        canvas.height = rect.height;

        const map = GameState.currentRun.sectorMap;
        const padding = 60;
        const rowHeight = (canvas.height - padding * 2) / (map.length - 1);

        // Clear canvas
        ctx.fillStyle = '#0a0a12';
        ctx.fillRect(0, 0, canvas.width, canvas.height);

        // Draw grid lines (subtle)
        ctx.strokeStyle = 'rgba(74, 158, 255, 0.05)';
        ctx.lineWidth = 1;
        for (let i = 0; i < 10; i++) {
            const y = (canvas.height / 10) * i;
            ctx.beginPath();
            ctx.moveTo(0, y);
            ctx.lineTo(canvas.width, y);
            ctx.stroke();
        }

        // Draw storm line
        const stormLine = GameState.currentRun.stormLine || 0;
        if (stormLine > 0) {
            const stormY = padding + rowHeight * (stormLine - 1);
            ctx.fillStyle = 'rgba(252, 129, 129, 0.1)';
            ctx.fillRect(0, 0, canvas.width, stormY);

            ctx.strokeStyle = 'rgba(252, 129, 129, 0.5)';
            ctx.lineWidth = 2;
            ctx.setLineDash([10, 5]);
            ctx.beginPath();
            ctx.moveTo(0, stormY);
            ctx.lineTo(canvas.width, stormY);
            ctx.stroke();
            ctx.setLineDash([]);
        }

        // Store node positions for click detection
        this.nodePositions = [];

        // Draw connections first
        map.forEach((row, rowIndex) => {
            row.forEach((node) => {
                const x = this.getNodeX(node.col, row.length, canvas.width, padding);
                const y = padding + rowIndex * rowHeight;

                node.connections.forEach(targetId => {
                    const targetNode = this.findNodeById(targetId, map);
                    if (targetNode) {
                        const targetRow = map[targetNode.row];
                        const tx = this.getNodeX(targetNode.col, targetRow.length, canvas.width, padding);
                        const ty = padding + targetNode.row * rowHeight;

                        ctx.strokeStyle = node.visited ? 'rgba(74, 158, 255, 0.5)' : 'rgba(74, 158, 255, 0.2)';
                        ctx.lineWidth = node.visited ? 2 : 1;
                        ctx.beginPath();
                        ctx.moveTo(x, y);
                        ctx.lineTo(tx, ty);
                        ctx.stroke();
                    }
                });
            });
        });

        // Draw nodes
        map.forEach((row, rowIndex) => {
            row.forEach((node) => {
                const x = this.getNodeX(node.col, row.length, canvas.width, padding);
                const y = padding + rowIndex * rowHeight;
                const radius = node.type === 'boss' ? 25 : 20;

                this.nodePositions.push({ node, x, y, radius });
                this.drawNode(ctx, node, x, y, radius);
            });
        });
    },

    getNodeX(col, totalInRow, canvasWidth, padding) {
        if (totalInRow === 1) {
            return canvasWidth / 2;
        }
        const availableWidth = canvasWidth - padding * 2;
        const spacing = availableWidth / (totalInRow - 1);
        return padding + col * spacing;
    },

    findNodeById(id, map) {
        for (const row of map) {
            for (const node of row) {
                if (node.id === id) return node;
            }
        }
        return null;
    },

    drawNode(ctx, node, x, y, radius) {
        const colors = {
            start: '#48bb78',
            battle: '#4a9eff',
            elite: '#f6ad55',
            shop: '#68d391',
            event: '#9f7aea',
            rest: '#fc8181',
            boss: '#e53e3e',
        };

        const color = colors[node.type] || '#4a9eff';
        const isAccessible = this.isNodeAccessible(node);
        const isCurrent = node.id === GameState.currentRun.currentNodeId;

        // Node glow for accessible nodes
        if (isAccessible && !node.visited) {
            ctx.shadowColor = color;
            ctx.shadowBlur = 15;
        }

        // Node circle
        ctx.beginPath();
        ctx.arc(x, y, radius, 0, Math.PI * 2);

        if (node.visited) {
            ctx.fillStyle = 'rgba(30, 30, 50, 0.8)';
            ctx.strokeStyle = 'rgba(74, 158, 255, 0.3)';
        } else if (isAccessible) {
            ctx.fillStyle = color;
            ctx.strokeStyle = '#fff';
        } else {
            ctx.fillStyle = 'rgba(30, 30, 50, 0.5)';
            ctx.strokeStyle = 'rgba(74, 158, 255, 0.2)';
        }

        ctx.lineWidth = isCurrent ? 3 : 2;
        ctx.fill();
        ctx.stroke();
        ctx.shadowBlur = 0;

        // Node icon
        const icons = {
            start: '🚀',
            battle: '⚔️',
            elite: '💀',
            shop: '🛒',
            event: '❓',
            rest: '💚',
            boss: '👹',
        };

        ctx.font = `${radius * 0.8}px Arial`;
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillStyle = node.visited ? 'rgba(255,255,255,0.3)' : '#fff';
        ctx.fillText(icons[node.type] || '●', x, y);

        // Current indicator
        if (isCurrent) {
            ctx.strokeStyle = '#fff';
            ctx.lineWidth = 2;
            ctx.setLineDash([4, 4]);
            ctx.beginPath();
            ctx.arc(x, y, radius + 8, 0, Math.PI * 2);
            ctx.stroke();
            ctx.setLineDash([]);
        }
    },

    isNodeAccessible(node) {
        if (node.visited) return false;

        const currentNode = this.findNodeById(GameState.currentRun.currentNodeId, GameState.currentRun.sectorMap);
        if (!currentNode) return node.row <= 1;

        return currentNode.connections.includes(node.id);
    },

    handleMapClick(e) {
        const canvas = this.elements.mapCanvas;
        const rect = canvas.getBoundingClientRect();
        const x = e.clientX - rect.left;
        const y = e.clientY - rect.top;

        // Find clicked node
        for (const { node, x: nx, y: ny, radius } of this.nodePositions) {
            const dist = Utils.distance(x, y, nx, ny);
            if (dist <= radius && this.isNodeAccessible(node)) {
                this.showNodePopup(node);
                return;
            }
        }
    },

    showNodePopup(node) {
        this.selectedNode = node;

        const typeNames = {
            battle: '전투',
            elite: '정예 전투',
            shop: '상점',
            event: '이벤트',
            rest: '휴식',
            boss: '보스 전투',
        };

        if (this.elements.popupTitle) {
            this.elements.popupTitle.textContent = node.name;
        }

        if (this.elements.popupDesc) {
            this.elements.popupDesc.textContent = typeNames[node.type] || '알 수 없음';
        }

        if (this.elements.popupReward) {
            const rewards = [];
            if (node.reward.credits) rewards.push(`💰 ${node.reward.credits} 크레딧`);
            if (node.reward.equipment) rewards.push('📦 장비 획득 가능');
            if (node.reward.heal) rewards.push('💚 승무원 회복');
            if (node.reward.shop) rewards.push('🛒 상점 이용');
            if (node.reward.event) rewards.push('❓ 이벤트 발생');
            this.elements.popupReward.textContent = rewards.join(' | ') || '보상 없음';
        }

        if (this.elements.popupDifficulty) {
            this.elements.popupDifficulty.textContent = '⭐'.repeat(node.difficulty);
        }

        this.elements.nodePopup?.classList.add('active');
    },

    hideNodePopup() {
        this.selectedNode = null;
        this.elements.nodePopup?.classList.remove('active');
    },

    enterSelectedNode() {
        if (!this.selectedNode) return;

        const node = this.selectedNode;

        // Update game state
        GameState.currentRun.currentNodeId = node.id;
        GameState.currentRun.visitedNodes.push(node.id);

        // Mark node as visited in map
        const mapNode = this.findNodeById(node.id, GameState.currentRun.sectorMap);
        if (mapNode) {
            mapNode.visited = true;
        }

        GameState.saveCurrentRun();

        // Navigate based on node type
        switch (node.type) {
            case 'battle':
            case 'elite':
            case 'boss':
                // Store battle info
                sessionStorage.setItem('currentBattle', JSON.stringify({
                    nodeId: node.id,
                    type: node.type,
                    difficulty: node.difficulty,
                    reward: node.reward,
                }));
                Utils.navigateTo('deploy');
                break;
            case 'shop':
                Utils.navigateTo('upgrade');
                break;
            case 'rest':
                this.handleRestNode(node);
                break;
            case 'event':
                this.handleEventNode(node);
                break;
        }

        this.hideNodePopup();
    },

    handleRestNode(node) {
        // Heal all crews by 2
        GameState.currentRun.crews.forEach(crew => {
            if (crew.isAlive) {
                crew.squadSize = Math.min(crew.squadSize + 2, crew.maxSquadSize);
                crew.health = crew.squadSize;
            }
        });
        GameState.advanceTurn();
        alert('승무원들이 휴식을 취했습니다. (+2 체력)');
        this.renderMap();
        this.updateHUD();
    },

    handleEventNode(node) {
        // Simple random event
        const events = [
            { text: '표류하는 화물선에서 크레딧을 발견했습니다!', credits: 50 },
            { text: '부상당한 용병을 구출했습니다. 감사의 표시로 크레딧을 받았습니다.', credits: 30 },
            { text: '우주 폭풍으로 인해 약간의 피해를 입었습니다.', damage: 1 },
            { text: '버려진 보급품을 발견했습니다!', credits: 40 },
        ];

        const event = this.rng.get('items').pick(events);

        if (event.credits) {
            GameState.addCredits(event.credits);
        }
        if (event.damage) {
            GameState.currentRun.crews.forEach(crew => {
                if (crew.isAlive && crew.squadSize > 1) {
                    crew.squadSize -= event.damage;
                    crew.health = crew.squadSize;
                }
            });
        }

        GameState.advanceTurn();
        alert(event.text);
        this.renderMap();
        this.updateHUD();
    },

    updateHUD() {
        if (!GameState.currentRun) return;

        // Turn display
        if (this.elements.turnDisplay) {
            this.elements.turnDisplay.textContent = `턴 ${GameState.currentRun.turn}`;
        }

        // Credits
        if (this.elements.creditsDisplay) {
            this.elements.creditsDisplay.textContent = Utils.formatNumber(GameState.currentRun.credits);
        }

        // Storm warning
        const stormTurns = Math.max(0, 10 - GameState.currentRun.turn);
        if (this.elements.stormTurns) {
            this.elements.stormTurns.textContent = stormTurns;
        }
        if (this.elements.stormWarning) {
            this.elements.stormWarning.style.display = stormTurns <= 5 ? 'block' : 'none';
        }

        // Crew roster
        this.renderCrewRoster();
    },

    renderCrewRoster() {
        const roster = this.elements.crewRoster;
        if (!roster || !GameState.currentRun) return;

        roster.innerHTML = '';

        GameState.currentRun.crews.forEach(crew => {
            if (!crew.isAlive) return;

            const card = document.createElement('div');
            card.className = `crew-mini-card ${crew.class}`;
            card.innerHTML = `
                <div class="crew-portrait ${crew.class}">${crew.name[0]}</div>
                <div class="crew-info">
                    <span class="crew-name">${crew.name}</span>
                    <div class="crew-health">
                        <span class="health-bar" style="width: ${(crew.squadSize / crew.maxSquadSize) * 100}%"></span>
                        <span class="health-text">${crew.squadSize}/${crew.maxSquadSize}</span>
                    </div>
                </div>
            `;
            roster.appendChild(card);
        });
    },

    showPauseMenu() {
        if (confirm('메인 메뉴로 돌아가시겠습니까? 진행 상황은 저장됩니다.')) {
            Utils.navigateTo('index');
        }
    }
};

// Initialize on DOM ready
document.addEventListener('DOMContentLoaded', () => {
    SectorController.init();
});
