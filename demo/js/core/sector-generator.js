/**
 * THE FADING RAVEN - Sector Map Generator
 * DAG-based procedural sector map generation
 */

const SectorGenerator = {
    // Difficulty presets from GDD 13.2.2
    DIFFICULTY_CONFIG: {
        normal: {
            depthRange: [12, 15],
            nodesPerDepth: [2, 3],
            branchChance: 0.6,
            mergeChance: 0.4,
            difficultyBase: 1.0,
            difficultyScale: 0.15,
        },
        hard: {
            depthRange: [15, 18],
            nodesPerDepth: [2, 4],
            branchChance: 0.7,
            mergeChance: 0.5,
            difficultyBase: 1.5,
            difficultyScale: 0.20,
        },
        veryhard: {
            depthRange: [18, 22],
            nodesPerDepth: [3, 4],
            branchChance: 0.8,
            mergeChance: 0.6,
            difficultyBase: 2.0,
            difficultyScale: 0.25,
        },
        nightmare: {
            depthRange: [22, 25],
            nodesPerDepth: [3, 5],
            branchChance: 0.9,
            mergeChance: 0.7,
            difficultyBase: 2.5,
            difficultyScale: 0.30,
        },
    },

    // Node types
    NODE_TYPES: {
        START: 'start',
        BATTLE: 'battle',
        COMMANDER: 'commander',  // 🚩 Leader recruitment
        EQUIPMENT: 'equipment',  // ❓ Equipment acquisition
        STORM: 'storm',          // ⚡ Storm stage (high risk/reward)
        BOSS: 'boss',            // 💀 Pirate captain
        REST: 'rest',            // Rest node
        GATE: 'gate',            // 🚪 Final objective
    },

    // Event placement rules from GDD 13.2.4
    EVENT_RULES: {
        commander: {
            firstAppear: [2, 3],
            interval: [3, 4],
            minGap: 3,
            maxPerMap: 3,
        },
        equipment: {
            firstAppear: [1, 2],
            interval: [2, 3],
            minGap: 2,
            maxPerMap: 7,
        },
        storm: {
            firstAppear: [4, 5],
            chance: 0.20,
            minGap: 2,
            maxPerMap: 4,
        },
        boss: {
            firstAppear: [5, 6],
            interval: 5,
            minGap: 4,
            maxPerMap: 4,
        },
        rest: {
            fixedDepths: [6, 12, 18],
            chance: 0.5,
        },
    },

    /**
     * Generate a complete sector map
     * @param {SeededRNG} rng - The RNG stream to use
     * @param {string} difficulty - Difficulty level
     * @returns {Object} Sector map data
     */
    generate(rng, difficulty = 'normal') {
        const config = this.DIFFICULTY_CONFIG[difficulty] || this.DIFFICULTY_CONFIG.normal;

        // Determine total depth
        const totalDepth = rng.range(config.depthRange[0], config.depthRange[1]);

        // Generate node structure
        const layers = this._generateLayers(rng, config, totalDepth);

        // Generate connections (DAG)
        this._generateConnections(rng, layers, config);

        // Assign node types
        this._assignNodeTypes(rng, layers, config, difficulty);

        // Calculate difficulty scores
        this._calculateDifficultyScores(layers, config);

        // Generate node metadata
        this._generateNodeMetadata(rng, layers);

        // Flatten to node array with layer info
        const nodes = this._flattenLayers(layers);

        return {
            nodes,
            layers,
            totalDepth,
            difficulty,
            stormFrontPosition: 0,
            currentNodeId: 0, // Start node
            visitedNodeIds: [0],
        };
    },

    /**
     * Generate layer structure with nodes
     */
    _generateLayers(rng, config, totalDepth) {
        const layers = [];
        let nodeId = 0;

        for (let depth = 0; depth <= totalDepth; depth++) {
            const layer = [];
            let nodeCount;

            if (depth === 0) {
                // Start layer - single node
                nodeCount = 1;
            } else if (depth === totalDepth) {
                // Gate layer - single node
                nodeCount = 1;
            } else {
                // Random node count within range
                nodeCount = rng.range(config.nodesPerDepth[0], config.nodesPerDepth[1]);
            }

            for (let i = 0; i < nodeCount; i++) {
                layer.push({
                    id: nodeId++,
                    depth,
                    index: i,
                    type: this.NODE_TYPES.BATTLE, // Default, will be overwritten
                    connections: [], // Forward connections (to next layer)
                    backConnections: [], // Backward connections (from previous layer)
                    visited: depth === 0,
                    accessible: depth <= 1,
                    difficultyScore: 0,
                    reward: null,
                    name: '',
                    metadata: {},
                });
            }

            layers.push(layer);
        }

        return layers;
    },

    /**
     * Generate DAG connections between layers
     */
    _generateConnections(rng, layers, config) {
        for (let depth = 0; depth < layers.length - 1; depth++) {
            const currentLayer = layers[depth];
            const nextLayer = layers[depth + 1];

            // Ensure every node in current layer connects to at least one in next
            currentLayer.forEach(node => {
                // Calculate which nodes in next layer this node can connect to
                const relativePos = node.index / Math.max(1, currentLayer.length - 1);
                const targetCenter = Math.floor(relativePos * (nextLayer.length - 1));

                // Potential targets: center and adjacent
                const potentialTargets = [];
                for (let i = Math.max(0, targetCenter - 1); i <= Math.min(nextLayer.length - 1, targetCenter + 1); i++) {
                    potentialTargets.push(i);
                }

                // Must connect to at least one
                const mustConnect = potentialTargets[Math.floor(potentialTargets.length / 2)];
                node.connections.push(nextLayer[mustConnect].id);
                nextLayer[mustConnect].backConnections.push(node.id);

                // Maybe connect to others based on branch chance
                potentialTargets.forEach(targetIdx => {
                    if (targetIdx !== mustConnect && rng.chance(config.branchChance)) {
                        node.connections.push(nextLayer[targetIdx].id);
                        nextLayer[targetIdx].backConnections.push(node.id);
                    }
                });
            });

            // Ensure every node in next layer has at least one back connection
            nextLayer.forEach(node => {
                if (node.backConnections.length === 0) {
                    // Connect to closest node in previous layer
                    const relativePos = node.index / Math.max(1, nextLayer.length - 1);
                    const sourceIdx = Math.floor(relativePos * (currentLayer.length - 1));
                    const sourceNode = currentLayer[Math.min(sourceIdx, currentLayer.length - 1)];

                    if (!sourceNode.connections.includes(node.id)) {
                        sourceNode.connections.push(node.id);
                        node.backConnections.push(sourceNode.id);
                    }
                }
            });

            // Remove duplicate connections
            currentLayer.forEach(node => {
                node.connections = [...new Set(node.connections)];
            });
            nextLayer.forEach(node => {
                node.backConnections = [...new Set(node.backConnections)];
            });
        }
    },

    /**
     * Assign node types based on rules
     */
    _assignNodeTypes(rng, layers, config, difficulty) {
        const totalDepth = layers.length - 1;
        const rules = this.EVENT_RULES;

        // Track placed events
        const eventPlacements = {
            commander: [],
            equipment: [],
            storm: [],
            boss: [],
            rest: [],
        };

        // First, set fixed types
        layers[0][0].type = this.NODE_TYPES.START;
        layers[totalDepth][0].type = this.NODE_TYPES.GATE;

        // Plan mandatory events
        // Commanders: first at depth 2-3, then every 3-4 depths
        let nextCommanderDepth = rng.range(rules.commander.firstAppear[0], rules.commander.firstAppear[1]);
        while (nextCommanderDepth < totalDepth && eventPlacements.commander.length < rules.commander.maxPerMap) {
            eventPlacements.commander.push(nextCommanderDepth);
            nextCommanderDepth += rng.range(rules.commander.interval[0], rules.commander.interval[1]);
        }

        // Bosses: first at depth 5-6, then every 5 depths
        let nextBossDepth = rng.range(rules.boss.firstAppear[0], rules.boss.firstAppear[1]);
        while (nextBossDepth < totalDepth && eventPlacements.boss.length < rules.boss.maxPerMap) {
            eventPlacements.boss.push(nextBossDepth);
            nextBossDepth += rules.boss.interval;
        }

        // Equipment: first at depth 1-2, then every 2-3 depths
        let nextEquipDepth = rng.range(rules.equipment.firstAppear[0], rules.equipment.firstAppear[1]);
        while (nextEquipDepth < totalDepth && eventPlacements.equipment.length < rules.equipment.maxPerMap) {
            eventPlacements.equipment.push(nextEquipDepth);
            nextEquipDepth += rng.range(rules.equipment.interval[0], rules.equipment.interval[1]);
        }

        // Rest nodes at fixed depths if they exist
        rules.rest.fixedDepths.forEach(depth => {
            if (depth < totalDepth && rng.chance(rules.rest.chance)) {
                eventPlacements.rest.push(depth);
            }
        });

        // Storm nodes: random placement from depth 4+
        for (let depth = rules.storm.firstAppear[0]; depth < totalDepth; depth++) {
            if (eventPlacements.storm.length >= rules.storm.maxPerMap) break;

            // Check min gap
            const lastStorm = eventPlacements.storm[eventPlacements.storm.length - 1];
            if (lastStorm && depth - lastStorm < rules.storm.minGap) continue;

            if (rng.chance(rules.storm.chance)) {
                eventPlacements.storm.push(depth);
            }
        }

        // Now assign types to nodes
        // Priority: boss > commander > equipment > storm > rest > battle
        for (let depth = 1; depth < totalDepth; depth++) {
            const layer = layers[depth];
            const usedIndices = new Set();

            // Helper to assign type to random node in layer
            const assignToLayer = (type, placements) => {
                if (!placements.includes(depth)) return;

                // Find available node
                const availableIndices = layer
                    .map((_, i) => i)
                    .filter(i => !usedIndices.has(i));

                if (availableIndices.length > 0) {
                    const idx = rng.pick(availableIndices);
                    layer[idx].type = type;
                    usedIndices.add(idx);
                }
            };

            // Assign in priority order
            assignToLayer(this.NODE_TYPES.BOSS, eventPlacements.boss);
            assignToLayer(this.NODE_TYPES.COMMANDER, eventPlacements.commander);
            assignToLayer(this.NODE_TYPES.EQUIPMENT, eventPlacements.equipment);
            assignToLayer(this.NODE_TYPES.STORM, eventPlacements.storm);
            assignToLayer(this.NODE_TYPES.REST, eventPlacements.rest);

            // Remaining nodes stay as BATTLE
        }
    },

    /**
     * Calculate difficulty scores for each node
     */
    _calculateDifficultyScores(layers, config) {
        layers.forEach((layer, depth) => {
            layer.forEach(node => {
                // Base difficulty from depth
                let score = config.difficultyBase + (depth * config.difficultyScale);

                // Modifiers by node type
                switch (node.type) {
                    case this.NODE_TYPES.STORM:
                        score *= 1.3; // Storm stages are harder
                        break;
                    case this.NODE_TYPES.BOSS:
                        score *= 1.5; // Boss fights are much harder
                        break;
                    case this.NODE_TYPES.REST:
                    case this.NODE_TYPES.START:
                    case this.NODE_TYPES.GATE:
                        score = 0; // No combat difficulty
                        break;
                }

                node.difficultyScore = Math.round(score * 100) / 100;
            });
        });
    },

    /**
     * Generate metadata for nodes (names, rewards, etc.)
     */
    _generateNodeMetadata(rng, layers) {
        const namePool = {
            battle: ['우주 정거장', '채굴 기지', '보급 정거장', '통신 중계소', '연구 시설', '폐허 정거장', '수송 허브'],
            commander: ['구조 신호', '생존자 기지', '저항군 거점', '피난 정거장'],
            equipment: ['물자 창고', '무기고', '기술 연구소', '약탈된 화물선'],
            storm: ['폭풍 지대', '이온 폭풍 구역', '불안정 영역', '방사선 지대'],
            boss: ['해적 요새', '적 본거지', '함대 기함', '지휘 센터'],
            rest: ['안전 지대', '은신처', '수리 시설', '휴식 구역'],
            gate: ['점프 게이트'],
            start: ['Raven 함'],
        };

        layers.forEach(layer => {
            layer.forEach(node => {
                // Name
                const pool = namePool[node.type] || namePool.battle;
                node.name = rng.pick(pool);

                // Reward based on type and difficulty
                node.reward = this._generateReward(rng, node);
            });
        });
    },

    /**
     * Generate reward for a node
     */
    _generateReward(rng, node) {
        const baseCredits = Math.floor(30 + node.depth * 15);

        switch (node.type) {
            case this.NODE_TYPES.BATTLE:
                return {
                    type: 'credits',
                    credits: rng.range(baseCredits, baseCredits + 20),
                };
            case this.NODE_TYPES.COMMANDER:
                return {
                    type: 'commander',
                    credits: rng.range(baseCredits * 0.5, baseCredits),
                    commander: true,
                };
            case this.NODE_TYPES.EQUIPMENT:
                return {
                    type: 'equipment',
                    credits: rng.range(baseCredits * 0.7, baseCredits),
                    equipment: true,
                };
            case this.NODE_TYPES.STORM:
                return {
                    type: 'storm',
                    credits: rng.range(baseCredits * 1.5, baseCredits * 2),
                    bonusChance: true,
                };
            case this.NODE_TYPES.BOSS:
                return {
                    type: 'boss',
                    credits: baseCredits * 3,
                    equipment: true,
                    guaranteed: true,
                };
            case this.NODE_TYPES.REST:
                return {
                    type: 'rest',
                    heal: true,
                };
            case this.NODE_TYPES.GATE:
                return {
                    type: 'gate',
                    victory: true,
                };
            default:
                return { type: 'none' };
        }
    },

    /**
     * Flatten layers to single node array
     */
    _flattenLayers(layers) {
        const nodes = [];
        layers.forEach(layer => {
            layer.forEach(node => {
                nodes.push(node);
            });
        });
        return nodes;
    },

    /**
     * Advance storm front by one turn
     * @param {Object} sectorMap - The sector map object
     * @returns {Array} Array of node IDs that were consumed by storm
     */
    advanceStormFront(sectorMap) {
        sectorMap.stormFrontPosition++;

        const consumedNodes = [];
        sectorMap.nodes.forEach(node => {
            if (node.depth < sectorMap.stormFrontPosition && !node.visited) {
                node.accessible = false;
                node.consumed = true;
                consumedNodes.push(node.id);
            }
        });

        return consumedNodes;
    },

    /**
     * Update accessible nodes based on current position
     * @param {Object} sectorMap - The sector map object
     */
    updateAccessibility(sectorMap) {
        const currentNode = sectorMap.nodes.find(n => n.id === sectorMap.currentNodeId);
        if (!currentNode) return;

        sectorMap.nodes.forEach(node => {
            // Reset accessibility
            node.accessible = false;

            // Node is accessible if:
            // 1. Connected from current node
            // 2. Not visited
            // 3. Not consumed by storm
            if (currentNode.connections.includes(node.id) &&
                !node.visited &&
                !node.consumed &&
                node.depth >= sectorMap.stormFrontPosition) {
                node.accessible = true;
            }
        });
    },

    /**
     * Visit a node
     * @param {Object} sectorMap - The sector map object
     * @param {number} nodeId - The node ID to visit
     * @returns {Object|null} The visited node or null if not accessible
     */
    visitNode(sectorMap, nodeId) {
        const node = sectorMap.nodes.find(n => n.id === nodeId);
        if (!node || !node.accessible) return null;

        node.visited = true;
        node.accessible = false;
        sectorMap.currentNodeId = nodeId;
        sectorMap.visitedNodeIds.push(nodeId);

        this.updateAccessibility(sectorMap);

        return node;
    },

    /**
     * Get nodes at risk from next storm advance
     * @param {Object} sectorMap - The sector map object
     * @returns {Array} Array of nodes at risk
     */
    getNodesAtRisk(sectorMap) {
        const nextStormPosition = sectorMap.stormFrontPosition + 1;
        return sectorMap.nodes.filter(node =>
            node.depth === nextStormPosition - 1 &&
            !node.visited
        );
    },

    /**
     * Check if any accessible path to gate exists
     * @param {Object} sectorMap - The sector map object
     * @returns {boolean} True if path exists
     */
    hasPathToGate(sectorMap) {
        const gateNode = sectorMap.nodes.find(n => n.type === this.NODE_TYPES.GATE);
        if (!gateNode) return false;

        const visited = new Set();
        const queue = [sectorMap.currentNodeId];

        while (queue.length > 0) {
            const currentId = queue.shift();
            if (currentId === gateNode.id) return true;
            if (visited.has(currentId)) continue;

            visited.add(currentId);
            const current = sectorMap.nodes.find(n => n.id === currentId);
            if (!current) continue;

            current.connections.forEach(connId => {
                const connNode = sectorMap.nodes.find(n => n.id === connId);
                if (connNode && !connNode.consumed && connNode.depth >= sectorMap.stormFrontPosition) {
                    queue.push(connId);
                }
            });
        }

        return false;
    },

    /**
     * Get statistics about the sector map
     * @param {Object} sectorMap - The sector map object
     * @returns {Object} Statistics
     */
    getStats(sectorMap) {
        const typeCount = {};
        Object.values(this.NODE_TYPES).forEach(type => {
            typeCount[type] = 0;
        });

        sectorMap.nodes.forEach(node => {
            typeCount[node.type] = (typeCount[node.type] || 0) + 1;
        });

        return {
            totalNodes: sectorMap.nodes.length,
            totalDepth: sectorMap.totalDepth,
            nodesByType: typeCount,
            visitedCount: sectorMap.visitedNodeIds.length,
            stormPosition: sectorMap.stormFrontPosition,
            accessibleCount: sectorMap.nodes.filter(n => n.accessible).length,
        };
    },
};

// Make available globally
window.SectorGenerator = SectorGenerator;
