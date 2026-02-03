/**
 * THE FADING RAVEN - Sector Map Controller
 * Handles sector map navigation and node selection
 * Integrates with SectorGenerator for DAG-based map generation
 */

const SectorController = {
    elements: {},
    selectedNode: null,
    rng: null,
    nodePositions: [],

    // L-012: Zoom/Pan state
    zoom: 1.0,
    panX: 0,
    panY: 0,
    isDragging: false,
    dragStartX: 0,
    dragStartY: 0,
    lastPanX: 0,
    lastPanY: 0,
    MIN_ZOOM: 0.5,
    MAX_ZOOM: 2.0,
    ZOOM_STEP: 0.1,

    // Node type display configuration
    NODE_CONFIG: {
        start: { color: '#48bb78', icon: '🚀', name: '출발점' },
        battle: { color: '#4a9eff', icon: '⚔️', name: '전투' },
        commander: { color: '#f6e05e', icon: '🚩', name: '팀장 영입' },
        equipment: { color: '#9f7aea', icon: '❓', name: '장비 획득' },
        storm: { color: '#ed8936', icon: '⚡', name: '폭풍 스테이지' },
        boss: { color: '#e53e3e', icon: '💀', name: '보스 전투' },
        rest: { color: '#fc8181', icon: '💚', name: '휴식' },
        gate: { color: '#38b2ac', icon: '🚪', name: '점프 게이트' },
    },

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
            mapContainer: document.getElementById('map-container'),
            nodePopup: document.getElementById('node-popup'),
            popupTitle: document.getElementById('popup-title'),
            popupDesc: document.getElementById('popup-desc'),
            popupReward: document.getElementById('popup-reward'),
            popupDifficulty: document.getElementById('popup-difficulty'),
            popupWarning: document.getElementById('popup-warning'),
            // L-011: Storm info elements
            popupStormInfo: document.getElementById('popup-storm-info'),
            stormRisksList: document.getElementById('storm-risks-list'),
            stormRewardsList: document.getElementById('storm-rewards-list'),
            btnEnterNode: document.getElementById('btn-enter-node'),
            btnCancelNode: document.getElementById('btn-cancel-node'),
            turnDisplay: document.getElementById('turn-display'),
            creditsDisplay: document.getElementById('credits-display'),
            crewRoster: document.getElementById('crew-roster'),
            stormWarning: document.getElementById('storm-warning'),
            stormTurns: document.getElementById('storm-turns'),
            btnMenu: document.getElementById('btn-menu'),
            depthDisplay: document.getElementById('depth-display'),
            // L-012: Zoom/Pan elements
            btnZoomIn: document.getElementById('btn-zoom-in'),
            btnZoomOut: document.getElementById('btn-zoom-out'),
            btnZoomReset: document.getElementById('btn-zoom-reset'),
            zoomLevel: document.getElementById('zoom-level'),
            panHint: document.getElementById('pan-hint'),
        };
    },

    bindEvents() {
        // Canvas click
        this.elements.mapCanvas?.addEventListener('click', (e) => {
            if (!this.isDragging) this.handleMapClick(e);
        });

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

        // L-012: Zoom controls
        this.elements.btnZoomIn?.addEventListener('click', () => this.zoomIn());
        this.elements.btnZoomOut?.addEventListener('click', () => this.zoomOut());
        this.elements.btnZoomReset?.addEventListener('click', () => this.resetZoom());

        // L-012: Mouse wheel zoom
        this.elements.mapCanvas?.addEventListener('wheel', (e) => {
            e.preventDefault();
            if (e.deltaY < 0) {
                this.zoomIn();
            } else {
                this.zoomOut();
            }
        }, { passive: false });

        // L-012: Pan with mouse drag
        this.elements.mapCanvas?.addEventListener('mousedown', (e) => this.startPan(e));
        this.elements.mapCanvas?.addEventListener('mousemove', (e) => this.doPan(e));
        this.elements.mapCanvas?.addEventListener('mouseup', () => this.endPan());
        this.elements.mapCanvas?.addEventListener('mouseleave', () => this.endPan());

        // L-012: Touch pan support
        this.elements.mapCanvas?.addEventListener('touchstart', (e) => this.startPan(e.touches[0]));
        this.elements.mapCanvas?.addEventListener('touchmove', (e) => {
            e.preventDefault();
            this.doPan(e.touches[0]);
        }, { passive: false });
        this.elements.mapCanvas?.addEventListener('touchend', () => this.endPan());

        // Keyboard
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                if (this.elements.nodePopup?.classList.contains('active')) {
                    this.hideNodePopup();
                } else {
                    this.showPauseMenu();
                }
            }
            // L-012: Keyboard zoom
            if (e.key === '+' || e.key === '=') this.zoomIn();
            if (e.key === '-') this.zoomOut();
            if (e.key === '0') this.resetZoom();
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
            // Use new SectorGenerator
            const mapRng = this.rng.get('sectorMap');
            const difficulty = GameState.currentRun.difficulty || 'normal';

            GameState.currentRun.sectorMap = SectorGenerator.generate(mapRng, difficulty);
            GameState.saveCurrentRun();
        }
    },

    // ==========================================
    // RENDERING
    // ==========================================

    renderMap() {
        const canvas = this.elements.mapCanvas;
        const sectorMap = GameState.currentRun?.sectorMap;
        if (!canvas || !sectorMap) return;

        const ctx = canvas.getContext('2d');
        const rect = canvas.getBoundingClientRect();
        canvas.width = rect.width;
        canvas.height = rect.height;

        const padding = 40;
        const totalDepth = sectorMap.totalDepth;
        // Limit vertical spacing for more compact map
        const maxDepthHeight = 60;
        const calculatedDepthHeight = (canvas.height - padding * 2) / totalDepth;
        const depthHeight = Math.min(maxDepthHeight, calculatedDepthHeight);

        // Clear canvas
        ctx.fillStyle = '#0a0a12';
        ctx.fillRect(0, 0, canvas.width, canvas.height);

        // L-012: Apply zoom and pan transformations
        ctx.save();
        ctx.translate(canvas.width / 2 + this.panX, canvas.height / 2 + this.panY);
        ctx.scale(this.zoom, this.zoom);
        ctx.translate(-canvas.width / 2, -canvas.height / 2);

        // Draw grid lines (subtle)
        this._drawGridLines(ctx, canvas);

        // Draw storm front
        this._drawStormFront(ctx, canvas, sectorMap, padding, depthHeight);

        // Reset node positions
        this.nodePositions = [];

        // Group nodes by depth for rendering
        const nodesByDepth = this._groupNodesByDepth(sectorMap.nodes);

        // Draw connections first
        this._drawConnections(ctx, sectorMap.nodes, nodesByDepth, canvas, padding, depthHeight);

        // Draw nodes
        this._drawNodes(ctx, sectorMap.nodes, nodesByDepth, canvas, padding, depthHeight);

        // L-012: Restore canvas state
        ctx.restore();

        // Update cursor style based on zoom level
        if (this.zoom > 1 && !this.isDragging) {
            canvas.style.cursor = 'grab';
        } else if (!this.isDragging) {
            canvas.style.cursor = 'pointer';
        }
    },

    _drawGridLines(ctx, canvas) {
        ctx.strokeStyle = 'rgba(74, 158, 255, 0.05)';
        ctx.lineWidth = 1;
        for (let i = 0; i < 20; i++) {
            const y = (canvas.height / 20) * i;
            ctx.beginPath();
            ctx.moveTo(0, y);
            ctx.lineTo(canvas.width, y);
            ctx.stroke();
        }
    },

    _drawStormFront(ctx, canvas, sectorMap, padding, depthHeight) {
        const stormPosition = sectorMap.stormFrontPosition || 0;
        if (stormPosition > 0) {
            const stormY = padding + depthHeight * stormPosition;

            // Consumed area
            ctx.fillStyle = 'rgba(252, 129, 129, 0.15)';
            ctx.fillRect(0, 0, canvas.width, stormY);

            // Storm line
            ctx.strokeStyle = 'rgba(252, 129, 129, 0.7)';
            ctx.lineWidth = 3;
            ctx.setLineDash([10, 5]);
            ctx.beginPath();
            ctx.moveTo(0, stormY);
            ctx.lineTo(canvas.width, stormY);
            ctx.stroke();
            ctx.setLineDash([]);

            // Warning zone (next depth to be consumed)
            const warningY = stormY + depthHeight;
            ctx.fillStyle = 'rgba(252, 129, 129, 0.05)';
            ctx.fillRect(0, stormY, canvas.width, depthHeight);
        }
    },

    _groupNodesByDepth(nodes) {
        const grouped = {};
        nodes.forEach(node => {
            if (!grouped[node.depth]) {
                grouped[node.depth] = [];
            }
            grouped[node.depth].push(node);
        });
        return grouped;
    },

    _drawConnections(ctx, nodes, nodesByDepth, canvas, padding, depthHeight) {
        nodes.forEach(node => {
            const pos = this._getNodePosition(node, nodesByDepth, canvas, padding, depthHeight);

            node.connections.forEach(targetId => {
                const targetNode = nodes.find(n => n.id === targetId);
                if (!targetNode) return;

                const targetPos = this._getNodePosition(targetNode, nodesByDepth, canvas, padding, depthHeight);

                // Connection style based on visited state
                if (node.visited) {
                    ctx.strokeStyle = 'rgba(74, 158, 255, 0.6)';
                    ctx.lineWidth = 2;
                } else if (node.accessible) {
                    ctx.strokeStyle = 'rgba(74, 158, 255, 0.4)';
                    ctx.lineWidth = 1.5;
                } else {
                    ctx.strokeStyle = 'rgba(74, 158, 255, 0.15)';
                    ctx.lineWidth = 1;
                }

                ctx.beginPath();
                ctx.moveTo(pos.x, pos.y);
                ctx.lineTo(targetPos.x, targetPos.y);
                ctx.stroke();
            });
        });
    },

    _drawNodes(ctx, nodes, nodesByDepth, canvas, padding, depthHeight) {
        nodes.forEach(node => {
            const pos = this._getNodePosition(node, nodesByDepth, canvas, padding, depthHeight);
            const config = this.NODE_CONFIG[node.type] || this.NODE_CONFIG.battle;
            const radius = node.type === 'boss' || node.type === 'gate' ? 22 : 18;

            // Store position for click detection
            this.nodePositions.push({ node, x: pos.x, y: pos.y, radius });

            // Draw node
            this._drawNode(ctx, node, pos.x, pos.y, radius, config);
        });
    },

    _getNodePosition(node, nodesByDepth, canvas, padding, depthHeight) {
        const depthNodes = nodesByDepth[node.depth] || [node];
        const nodeIndex = depthNodes.indexOf(node);
        const nodesInDepth = depthNodes.length;

        const y = padding + node.depth * depthHeight;
        let x;

        const centerX = canvas.width / 2;

        if (nodesInDepth === 1) {
            x = centerX;
        } else {
            // Limit max spread to prevent spider-web effect
            const maxSpread = Math.min(canvas.width - padding * 2, 400);
            const nodeSpacing = Math.min(80, maxSpread / (nodesInDepth - 1));
            const totalWidth = nodeSpacing * (nodesInDepth - 1);
            const startX = centerX - totalWidth / 2;
            x = startX + nodeIndex * nodeSpacing;
        }

        return { x, y };
    },

    _drawNode(ctx, node, x, y, radius, config) {
        const isAccessible = node.accessible && !node.visited && !node.consumed;
        const isCurrent = node.id === GameState.currentRun?.sectorMap?.currentNodeId;
        const isConsumed = node.consumed;

        // Glow effect for accessible nodes
        if (isAccessible) {
            ctx.shadowColor = config.color;
            ctx.shadowBlur = 20;
        }

        // Node circle
        ctx.beginPath();
        ctx.arc(x, y, radius, 0, Math.PI * 2);

        if (isConsumed) {
            ctx.fillStyle = 'rgba(50, 50, 50, 0.5)';
            ctx.strokeStyle = 'rgba(252, 129, 129, 0.3)';
        } else if (node.visited) {
            ctx.fillStyle = 'rgba(30, 30, 50, 0.8)';
            ctx.strokeStyle = 'rgba(74, 158, 255, 0.4)';
        } else if (isAccessible) {
            ctx.fillStyle = config.color;
            ctx.strokeStyle = '#fff';
        } else {
            ctx.fillStyle = 'rgba(30, 30, 50, 0.6)';
            ctx.strokeStyle = 'rgba(74, 158, 255, 0.2)';
        }

        ctx.lineWidth = isCurrent ? 3 : 2;
        ctx.fill();
        ctx.stroke();
        ctx.shadowBlur = 0;

        // Node icon
        ctx.font = `${radius * 0.9}px Arial`;
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillStyle = isConsumed ? 'rgba(255,255,255,0.2)' :
                        node.visited ? 'rgba(255,255,255,0.4)' : '#fff';
        ctx.fillText(config.icon, x, y);

        // Current position indicator
        if (isCurrent) {
            ctx.strokeStyle = '#fff';
            ctx.lineWidth = 2;
            ctx.setLineDash([5, 3]);
            ctx.beginPath();
            ctx.arc(x, y, radius + 8, 0, Math.PI * 2);
            ctx.stroke();
            ctx.setLineDash([]);
        }

        // Difficulty indicator (small dots below node)
        if (!node.visited && !isConsumed && node.difficultyScore > 0) {
            const dots = Math.min(5, Math.ceil(node.difficultyScore));
            const dotSpacing = 6;
            const startX = x - ((dots - 1) * dotSpacing) / 2;

            for (let i = 0; i < dots; i++) {
                ctx.beginPath();
                ctx.arc(startX + i * dotSpacing, y + radius + 8, 2, 0, Math.PI * 2);
                ctx.fillStyle = isAccessible ? 'rgba(255,255,255,0.7)' : 'rgba(255,255,255,0.3)';
                ctx.fill();
            }
        }
    },

    // ==========================================
    // INTERACTION
    // ==========================================

    handleMapClick(e) {
        const canvas = this.elements.mapCanvas;
        const rect = canvas.getBoundingClientRect();
        const screenX = e.clientX - rect.left;
        const screenY = e.clientY - rect.top;

        // L-012: Convert screen coordinates to map coordinates
        const { x, y } = this.screenToMap(screenX, screenY);

        // Find clicked node
        for (const { node, x: nx, y: ny, radius } of this.nodePositions) {
            const dist = Math.sqrt((x - nx) ** 2 + (y - ny) ** 2);
            // Adjust hit area for zoom
            const hitRadius = (radius + 5) / this.zoom;
            if (dist <= hitRadius && node.accessible && !node.visited && !node.consumed) {
                this.showNodePopup(node);
                return;
            }
        }
    },

    showNodePopup(node) {
        this.selectedNode = node;
        const config = this.NODE_CONFIG[node.type] || this.NODE_CONFIG.battle;

        if (this.elements.popupTitle) {
            this.elements.popupTitle.textContent = node.name || config.name;
        }

        if (this.elements.popupDesc) {
            this.elements.popupDesc.textContent = config.name;
            this.elements.popupDesc.style.color = config.color;
        }

        if (this.elements.popupReward) {
            const rewards = this._formatReward(node);
            this.elements.popupReward.textContent = rewards;
        }

        if (this.elements.popupDifficulty) {
            if (node.difficultyScore > 0) {
                const stars = Math.min(5, Math.ceil(node.difficultyScore));
                this.elements.popupDifficulty.textContent = '⭐'.repeat(stars);
                this.elements.popupDifficulty.style.display = 'block';
            } else {
                this.elements.popupDifficulty.style.display = 'none';
            }
        }

        // L-011: Show detailed storm info
        if (this.elements.popupStormInfo) {
            if (node.type === 'storm') {
                this.elements.popupStormInfo.style.display = 'block';
                this._displayStormDetails(node);
            } else {
                this.elements.popupStormInfo.style.display = 'none';
            }
        }

        // Show warning for non-storm dangerous nodes
        if (this.elements.popupWarning) {
            if (node.type === 'boss') {
                this.elements.popupWarning.textContent = '⚠️ 강력한 보스가 기다리고 있습니다';
                this.elements.popupWarning.style.display = 'block';
            } else if (node.difficultyScore >= 4) {
                this.elements.popupWarning.textContent = '⚠️ 매우 어려운 전투입니다';
                this.elements.popupWarning.style.display = 'block';
            } else {
                this.elements.popupWarning.style.display = 'none';
            }
        }

        this.elements.nodePopup?.classList.add('active');
    },

    // L-011: Display detailed storm stage information
    _displayStormDetails(node) {
        const difficulty = GameState.currentRun?.difficulty || 'normal';
        const difficultyMultiplier = { easy: 0.8, normal: 1.0, hard: 1.3, veryhard: 1.6, nightmare: 2.0 };
        const mult = difficultyMultiplier[difficulty] || 1.0;

        // Calculate storm risks based on node depth and difficulty
        const envDamage = Math.floor(5 + node.depth * 2 * mult);
        const enemyHpBonus = Math.floor(20 + node.depth * 5);
        const enemyDamageBonus = Math.floor(10 + node.depth * 3);

        // Risks
        if (this.elements.stormRisksList) {
            this.elements.stormRisksList.innerHTML = `
                <li><span class="risk-icon">💨</span> 환경 피해: 매 10초마다 ${envDamage} 피해</li>
                <li><span class="risk-icon">💪</span> 적 체력 +${enemyHpBonus}%</li>
                <li><span class="risk-icon">⚔️</span> 적 공격력 +${enemyDamageBonus}%</li>
                <li><span class="risk-icon">👁️</span> 시야 제한 (폭풍 효과)</li>
            `;
        }

        // Rewards
        const bonusCredits = Math.floor((node.reward?.credits || 100) * 0.5);
        const rareDropChance = Math.min(50, 15 + node.depth * 3);

        if (this.elements.stormRewardsList) {
            this.elements.stormRewardsList.innerHTML = `
                <li><span class="reward-icon">💰</span> 추가 크레딧: +${bonusCredits}</li>
                <li><span class="reward-icon">🎁</span> 희귀 장비 확률: ${rareDropChance}%</li>
                <li><span class="reward-icon">⭐</span> 경험치 보너스: +50%</li>
            `;
        }
    },

    _formatReward(node) {
        if (!node.reward) return '보상 없음';

        const rewards = [];

        switch (node.reward.type) {
            case 'credits':
                rewards.push(`💰 ${node.reward.credits} 크레딧`);
                break;
            case 'commander':
                rewards.push('🚩 새 팀장 영입 가능');
                if (node.reward.credits) rewards.push(`💰 ${node.reward.credits} 크레딧`);
                break;
            case 'equipment':
                rewards.push('📦 장비 획득 가능');
                if (node.reward.credits) rewards.push(`💰 ${node.reward.credits} 크레딧`);
                break;
            case 'storm':
                rewards.push(`💰 ${node.reward.credits} 크레딧 (보너스)`);
                if (node.reward.bonusChance) rewards.push('🎁 희귀 보상 확률 증가');
                break;
            case 'boss':
                rewards.push(`💰 ${node.reward.credits} 크레딧`);
                rewards.push('📦 장비 확정');
                break;
            case 'rest':
                rewards.push('💚 승무원 회복');
                break;
            case 'gate':
                rewards.push('🏆 최종 목표');
                break;
        }

        return rewards.join(' | ') || '보상 없음';
    },

    hideNodePopup() {
        this.selectedNode = null;
        this.elements.nodePopup?.classList.remove('active');
    },

    enterSelectedNode() {
        if (!this.selectedNode) return;

        const node = this.selectedNode;
        const sectorMap = GameState.currentRun.sectorMap;

        // Update using SectorGenerator
        SectorGenerator.visitNode(sectorMap, node.id);
        GameState.saveCurrentRun();

        // Navigate based on node type
        this._handleNodeEntry(node);
        this.hideNodePopup();
    },

    _handleNodeEntry(node) {
        switch (node.type) {
            case 'battle':
            case 'storm':
            case 'boss':
                this._enterBattleNode(node);
                break;
            case 'commander':
                this._enterCommanderNode(node);
                break;
            case 'equipment':
                this._enterEquipmentNode(node);
                break;
            case 'rest':
                this._handleRestNode(node);
                break;
            case 'gate':
                this._handleGateNode(node);
                break;
        }
    },

    _enterBattleNode(node) {
        sessionStorage.setItem('currentBattle', JSON.stringify({
            nodeId: node.id,
            type: node.type,
            difficultyScore: node.difficultyScore,
            reward: node.reward,
            isStorm: node.type === 'storm',
            isBoss: node.type === 'boss',
        }));
        Utils.navigateTo('deploy');
    },

    _enterCommanderNode(node) {
        // Store commander recruitment info
        sessionStorage.setItem('currentBattle', JSON.stringify({
            nodeId: node.id,
            type: 'commander',
            difficultyScore: node.difficultyScore,
            reward: node.reward,
            isRecruitment: true,
        }));
        Utils.navigateTo('deploy');
    },

    _enterEquipmentNode(node) {
        sessionStorage.setItem('currentBattle', JSON.stringify({
            nodeId: node.id,
            type: 'equipment',
            difficultyScore: node.difficultyScore,
            reward: node.reward,
            hasEquipment: true,
        }));
        Utils.navigateTo('deploy');
    },

    _handleRestNode(node) {
        // Heal all crews
        GameState.currentRun.crews.forEach(crew => {
            if (crew.isAlive) {
                crew.squadSize = Math.min(crew.squadSize + 2, crew.maxSquadSize);
                crew.health = crew.squadSize;
            }
        });

        this._advanceTurnAndRender();
        alert('승무원들이 휴식을 취했습니다. (+2 체력)');
    },

    _handleGateNode(node) {
        // Final battle - victory condition
        sessionStorage.setItem('currentBattle', JSON.stringify({
            nodeId: node.id,
            type: 'gate',
            difficultyScore: node.difficultyScore,
            reward: node.reward,
            isFinalBattle: true,
        }));
        Utils.navigateTo('deploy');
    },

    _advanceTurnAndRender() {
        GameState.advanceTurn();

        // Advance storm front
        const sectorMap = GameState.currentRun.sectorMap;
        SectorGenerator.advanceStormFront(sectorMap);
        SectorGenerator.updateAccessibility(sectorMap);

        // Check if path to gate still exists
        if (!SectorGenerator.hasPathToGate(sectorMap)) {
            alert('경고: 게이트로 가는 경로가 막혔습니다!');
        }

        GameState.saveCurrentRun();
        this.renderMap();
        this.updateHUD();
    },

    // ==========================================
    // HUD
    // ==========================================

    updateHUD() {
        if (!GameState.currentRun) return;

        const sectorMap = GameState.currentRun.sectorMap;

        // Turn display
        if (this.elements.turnDisplay) {
            this.elements.turnDisplay.textContent = `턴 ${GameState.currentRun.turn}`;
        }

        // Depth display
        if (this.elements.depthDisplay && sectorMap) {
            const currentNode = sectorMap.nodes.find(n => n.id === sectorMap.currentNodeId);
            const currentDepth = currentNode ? currentNode.depth : 0;
            this.elements.depthDisplay.textContent = `깊이 ${currentDepth}/${sectorMap.totalDepth}`;
        }

        // Credits
        if (this.elements.creditsDisplay) {
            this.elements.creditsDisplay.textContent = Utils.formatNumber(GameState.currentRun.credits);
        }

        // Storm warning
        if (sectorMap) {
            const nodesAtRisk = SectorGenerator.getNodesAtRisk(sectorMap);
            const hasPathToGate = SectorGenerator.hasPathToGate(sectorMap);

            if (this.elements.stormWarning) {
                if (nodesAtRisk.length > 0) {
                    this.elements.stormWarning.style.display = 'block';
                    this.elements.stormWarning.classList.toggle('critical', !hasPathToGate);
                } else {
                    this.elements.stormWarning.style.display = 'none';
                }
            }

            if (this.elements.stormTurns) {
                this.elements.stormTurns.textContent = nodesAtRisk.length;
            }
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

            const healthPercent = (crew.squadSize / crew.maxSquadSize) * 100;
            const healthClass = healthPercent <= 25 ? 'critical' :
                               healthPercent <= 50 ? 'warning' : '';

            card.innerHTML = `
                <div class="crew-portrait ${crew.class}">${crew.name[0]}</div>
                <div class="crew-info">
                    <span class="crew-name">${crew.name}</span>
                    <div class="crew-health ${healthClass}">
                        <span class="health-bar" style="width: ${healthPercent}%"></span>
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
    },

    // ==========================================
    // UTILITY
    // ==========================================

    getMapStats() {
        const sectorMap = GameState.currentRun?.sectorMap;
        if (!sectorMap) return null;

        return SectorGenerator.getStats(sectorMap);
    },

    // ==========================================
    // L-012: ZOOM/PAN CONTROLS
    // ==========================================

    zoomIn() {
        this.zoom = Math.min(this.MAX_ZOOM, this.zoom + this.ZOOM_STEP);
        this.updateZoomDisplay();
        this.renderMap();
    },

    zoomOut() {
        this.zoom = Math.max(this.MIN_ZOOM, this.zoom - this.ZOOM_STEP);
        this.updateZoomDisplay();
        this.renderMap();
    },

    resetZoom() {
        this.zoom = 1.0;
        this.panX = 0;
        this.panY = 0;
        this.updateZoomDisplay();
        this.renderMap();
        this.hidePanHint();
    },

    updateZoomDisplay() {
        if (this.elements.zoomLevel) {
            this.elements.zoomLevel.textContent = `${Math.round(this.zoom * 100)}%`;
        }
    },

    startPan(e) {
        this.isDragging = true;
        this.dragStartX = e.clientX;
        this.dragStartY = e.clientY;
        this.lastPanX = this.panX;
        this.lastPanY = this.panY;

        if (this.elements.mapCanvas) {
            this.elements.mapCanvas.style.cursor = 'grabbing';
        }
    },

    doPan(e) {
        if (!this.isDragging) return;

        const dx = e.clientX - this.dragStartX;
        const dy = e.clientY - this.dragStartY;

        this.panX = this.lastPanX + dx;
        this.panY = this.lastPanY + dy;

        // Clamp pan to reasonable bounds
        const canvas = this.elements.mapCanvas;
        if (canvas) {
            const maxPanX = canvas.width * (this.zoom - 1) / 2;
            const maxPanY = canvas.height * (this.zoom - 1) / 2;
            this.panX = Math.max(-maxPanX, Math.min(maxPanX, this.panX));
            this.panY = Math.max(-maxPanY, Math.min(maxPanY, this.panY));
        }

        this.renderMap();
    },

    endPan() {
        if (this.isDragging) {
            this.isDragging = false;
            if (this.elements.mapCanvas) {
                this.elements.mapCanvas.style.cursor = 'grab';
            }
        }
    },

    showPanHint() {
        if (this.elements.panHint && this.zoom > 1) {
            this.elements.panHint.style.opacity = '1';
            setTimeout(() => this.hidePanHint(), 2000);
        }
    },

    hidePanHint() {
        if (this.elements.panHint) {
            this.elements.panHint.style.opacity = '0';
        }
    },

    // Transform screen coordinates to map coordinates (for click detection)
    screenToMap(screenX, screenY) {
        const canvas = this.elements.mapCanvas;
        if (!canvas) return { x: screenX, y: screenY };

        const centerX = canvas.width / 2;
        const centerY = canvas.height / 2;

        return {
            x: (screenX - centerX - this.panX) / this.zoom + centerX,
            y: (screenY - centerY - this.panY) / this.zoom + centerY
        };
    },
};

// Initialize on DOM ready
document.addEventListener('DOMContentLoaded', () => {
    SectorController.init();
});
