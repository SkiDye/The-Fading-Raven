/**
 * THE FADING RAVEN - Battle Result Controller
 * Handles post-battle result display
 */

const ResultController = {
    elements: {},
    result: null,
    unlockResults: null, // Stores MetaProgress unlock results

    init() {
        this.loadResult();
        this.cacheElements();
        this.bindEvents();
        this.processMetaProgress();
        this.displayResult();
        console.log('ResultController initialized');
    },

    loadResult() {
        const resultData = sessionStorage.getItem('battleResult');
        if (!resultData || !GameState.hasActiveRun()) {
            Utils.navigateTo('sector');
            return;
        }
        this.result = JSON.parse(resultData);
    },

    cacheElements() {
        this.elements = {
            resultTitle: document.getElementById('result-title'),
            resultSubtitle: document.getElementById('result-subtitle'),
            statsContainer: document.getElementById('stats-container'),
            rewardsContainer: document.getElementById('rewards-container'),
            crewStatus: document.getElementById('crew-status'),
            unlocksContainer: document.getElementById('unlocks-container'),
            btnContinue: document.getElementById('btn-continue'),
            btnRetry: document.getElementById('btn-retry'),
            // M-012: Recruitment panel
            recruitmentContainer: document.getElementById('recruitment-container'),
            newCrewInfo: document.getElementById('new-crew-info'),
            crewComparison: document.getElementById('crew-comparison'),
            btnAcceptRecruit: document.getElementById('btn-accept-recruit'),
            btnSkipRecruit: document.getElementById('btn-skip-recruit'),
            // M-013: Equipment panel
            equipmentContainer: document.getElementById('equipment-container'),
            acquiredEquipment: document.getElementById('acquired-equipment'),
            equipOptions: document.getElementById('equip-options'),
            btnSkipEquip: document.getElementById('btn-skip-equip'),
            btnGoUpgrade: document.getElementById('btn-go-upgrade'),
        };
    },

    processMetaProgress() {
        // Only process on run completion (victory/defeat when run ends)
        if (!this.result || !GameState.currentRun) return;

        // Check if MetaProgress is available
        if (typeof MetaProgress === 'undefined') return;

        // Check if run is actually ending (not just a battle result)
        const aliveCrews = GameState.getAliveCrews();
        const isGameOver = aliveCrews.length === 0;
        const isFinalBossVictory = this.result.victory && this.result.battleType === 'boss' && this.isFinalBoss();

        // Only process on actual run end
        if (!isGameOver && !isFinalBossVictory) {
            return;
        }

        // Prepare run data for MetaProgress
        const runData = {
            victory: isFinalBossVictory,
            difficulty: GameState.currentRun.difficulty || 'normal',
            stats: {
                ...GameState.currentRun.stats,
                enemiesKilled: this.result.enemiesKilled,
                stationsDefended: GameState.currentRun.stats.stationsDefended || 0,
                perfectDefenses: GameState.currentRun.stats.perfectDefenses || 0,
            },
            crews: GameState.currentRun.crews,
            isBossVictory: isFinalBossVictory,
            isStormVictory: this.result.victory && this.result.battleType === 'storm',
        };

        // Process run completion for unlocks
        this.unlockResults = MetaProgress.processRunCompletion(runData);

        console.log('MetaProgress processed:', this.unlockResults);
    },

    isFinalBoss() {
        const currentNode = this.findCurrentNode();
        if (!currentNode) return false;
        const sectorMap = GameState.currentRun?.sectorMap;
        if (!sectorMap) return false;
        // Node has 'depth' property, sectorMap has 'totalDepth'
        return currentNode.depth === sectorMap.totalDepth;
    },

    bindEvents() {
        this.elements.btnContinue?.addEventListener('click', () => this.continue());
        this.elements.btnRetry?.addEventListener('click', () => this.retry());

        // M-012: Recruitment events
        this.elements.btnAcceptRecruit?.addEventListener('click', () => this.acceptRecruitment());
        this.elements.btnSkipRecruit?.addEventListener('click', () => this.skipRecruitment());

        // M-013: Equipment events
        this.elements.btnSkipEquip?.addEventListener('click', () => this.skipEquipment());
        this.elements.btnGoUpgrade?.addEventListener('click', () => this.goToUpgrade());

        document.addEventListener('keydown', (e) => {
            if (e.key === 'Enter' || e.key === ' ') {
                this.continue();
            }
        });
    },

    displayResult() {
        if (!this.result) return;

        // Title
        if (this.elements.resultTitle) {
            this.elements.resultTitle.textContent = this.result.victory ? '승리!' : '패배';
            this.elements.resultTitle.className = this.result.victory ? 'victory' : 'defeat';
        }

        // Subtitle
        if (this.elements.resultSubtitle) {
            const typeNames = {
                battle: '방어 전투',
                elite: '정예 전투',
                boss: '보스 전투',
                storm: '폭풍 스테이지',
                commander: '팀장 영입전',
            };
            this.elements.resultSubtitle.textContent = typeNames[this.result.battleType] || '전투';
        }

        // Stats
        this.displayStats();

        // Rewards
        this.displayRewards();

        // Unlocks (from MetaProgress)
        this.displayUnlocks();

        // M-012: Commander recruitment
        this.displayRecruitment();

        // M-013: Equipment acquisition
        this.displayEquipmentAcquisition();

        // Crew status
        this.displayCrewStatus();

        // Show/hide buttons based on result
        if (this.elements.btnRetry) {
            this.elements.btnRetry.style.display = this.result.victory ? 'none' : 'inline-block';
        }

        // Check for game over
        const aliveCrews = GameState.getAliveCrews();
        if (aliveCrews.length === 0) {
            // Game over - no crews left
            setTimeout(() => {
                GameState.endRun(false);
                Utils.navigateTo('gameover');
            }, 2000);
        }
    },

    displayStats() {
        const container = this.elements.statsContainer;
        if (!container) return;

        // Basic battle stats
        const stats = [
            { label: '웨이브 완료', value: `${this.result.wavesCompleted}/${this.result.totalWaves}` },
            { label: '적 처치', value: this.result.enemiesKilled },
            { label: '스테이션 상태', value: `${Math.floor(this.result.stationHealth)}%` },
        ];

        // Extended stats (L-005)
        if (this.result.battleDuration) {
            const mins = Math.floor(this.result.battleDuration / 60);
            const secs = Math.floor(this.result.battleDuration % 60);
            stats.push({ label: '전투 시간', value: `${mins}:${secs.toString().padStart(2, '0')}` });
        }

        if (this.result.skillsUsed !== undefined) {
            stats.push({ label: '스킬 사용', value: this.result.skillsUsed });
        }

        if (this.result.damageDealt !== undefined) {
            stats.push({ label: '가한 피해', value: Utils.formatNumber(this.result.damageDealt) });
        }

        if (this.result.damageTaken !== undefined) {
            stats.push({ label: '받은 피해', value: Utils.formatNumber(this.result.damageTaken) });
        }

        // Enemy type breakdown (if available)
        let enemyBreakdown = '';
        if (this.result.enemyTypeKills && Object.keys(this.result.enemyTypeKills).length > 0) {
            const breakdown = Object.entries(this.result.enemyTypeKills)
                .filter(([_, count]) => count > 0)
                .map(([type, count]) => {
                    const name = this.getEnemyTypeName(type);
                    return `<span class="enemy-type">${name}: ${count}</span>`;
                }).join('');
            if (breakdown) {
                enemyBreakdown = `
                    <div class="stat-breakdown">
                        <span class="stat-label">적 처치 상세</span>
                        <div class="breakdown-list">${breakdown}</div>
                    </div>
                `;
            }
        }

        container.innerHTML = stats.map(stat => `
            <div class="stat-item">
                <span class="stat-value">${stat.value}</span>
                <span class="stat-label">${stat.label}</span>
            </div>
        `).join('') + enemyBreakdown;
    },

    getEnemyTypeName(enemyId) {
        if (typeof EnemyData !== 'undefined') {
            const data = EnemyData.get(enemyId);
            return data?.name || enemyId;
        }
        const names = {
            rusher: '돌격병', gunner: '총잡이', shieldTrooper: '방패병',
            jumper: '점프병', heavyTrooper: '중장병', hacker: '해커',
            stormCreature: '폭풍생물', brute: '브루트', sniper: '저격수',
            droneCarrier: '드론모함', shieldGenerator: '보호막 생성기',
            pirateCaptain: '해적 선장', stormCore: '폭풍 핵',
        };
        return names[enemyId] || enemyId;
    },

    displayRewards() {
        const container = this.elements.rewardsContainer;
        if (!container) return;

        if (!this.result.victory || !this.result.reward) {
            container.innerHTML = '<p class="no-reward">보상 없음</p>';
            return;
        }

        const rewards = [];

        if (this.result.reward.credits) {
            rewards.push(`<div class="reward-item"><span class="reward-icon">💰</span><span class="reward-text">${this.result.reward.credits} 크레딧</span></div>`);
        }

        if (this.result.reward.equipment) {
            const equipName = typeof EquipmentData !== 'undefined'
                ? EquipmentData.get(this.result.reward.equipment)?.name || '장비'
                : '장비';
            rewards.push(`<div class="reward-item"><span class="reward-icon">📦</span><span class="reward-text">${equipName} 획득!</span></div>`);
        }

        // Salvage Core bonus (from battle result)
        if (this.result.bonusCredits && this.result.bonusCredits > 0) {
            rewards.push(`<div class="reward-item bonus"><span class="reward-icon">🔩</span><span class="reward-text">회수 코어 보너스: +${this.result.bonusCredits} 크레딧</span></div>`);
        }

        // Perfect defense bonus
        if (this.result.stationHealth >= 100) {
            const bonus = Math.floor(this.result.reward.credits * 0.5);
            rewards.push(`<div class="reward-item bonus"><span class="reward-icon">⭐</span><span class="reward-text">완벽 방어 보너스: +${bonus} 크레딧</span></div>`);
        }

        // Facility credits (if applicable)
        if (this.result.facilityCredits && this.result.facilityCredits > 0) {
            rewards.push(`<div class="reward-item"><span class="reward-icon">🏛️</span><span class="reward-text">시설 방어: +${this.result.facilityCredits} 크레딧</span></div>`);
        }

        container.innerHTML = rewards.join('');
    },

    displayUnlocks() {
        const container = this.elements.unlocksContainer;
        if (!container) return;

        // No unlock results
        if (!this.unlockResults) {
            container.style.display = 'none';
            return;
        }

        const { newUnlocks, newAchievements } = this.unlockResults;

        // Check if there's anything to display
        if ((!newUnlocks || newUnlocks.length === 0) &&
            (!newAchievements || newAchievements.length === 0)) {
            container.style.display = 'none';
            return;
        }

        container.style.display = 'block';
        const items = [];

        // Display new unlocks
        if (newUnlocks && newUnlocks.length > 0) {
            newUnlocks.forEach(unlock => {
                const icons = {
                    class: '👤',
                    equipment: '🔧',
                    trait: '✨',
                    difficulty: '💀',
                };
                const typeNames = {
                    class: '클래스',
                    equipment: '장비',
                    trait: '특성',
                    difficulty: '난이도',
                };
                items.push(`
                    <div class="unlock-item new-unlock">
                        <span class="unlock-icon">${icons[unlock.type] || '🔓'}</span>
                        <span class="unlock-text">
                            <strong>${typeNames[unlock.type] || unlock.type} 해금!</strong>
                            <span class="unlock-name">${this.getUnlockName(unlock)}</span>
                        </span>
                    </div>
                `);
            });
        }

        // Display new achievements
        if (newAchievements && newAchievements.length > 0) {
            newAchievements.forEach(achievement => {
                items.push(`
                    <div class="unlock-item achievement">
                        <span class="unlock-icon">🏆</span>
                        <span class="unlock-text">
                            <strong>도전과제 달성!</strong>
                            <span class="unlock-name">${achievement.name || achievement.id}</span>
                        </span>
                    </div>
                `);
            });
        }

        container.innerHTML = `
            <h3>새로운 해금</h3>
            ${items.join('')}
        `;
    },

    // M-012: Display recruitment panel with crew comparison
    displayRecruitment() {
        const container = this.elements.recruitmentContainer;
        if (!container) return;

        // Only show for commander battles with victory
        if (!this.result.victory || this.result.battleType !== 'commander') {
            container.style.display = 'none';
            return;
        }

        // Check if there's a new crew to recruit
        const newCrew = this.result.reward?.newCrew;
        if (!newCrew) {
            container.style.display = 'none';
            return;
        }

        container.style.display = 'block';

        // Display new crew info
        const newCrewEl = this.elements.newCrewInfo;
        if (newCrewEl) {
            const classData = typeof CrewData !== 'undefined'
                ? CrewData.getClass(newCrew.class)
                : null;

            newCrewEl.innerHTML = `
                <div class="crew-card new-recruit">
                    <div class="crew-portrait ${newCrew.class}">${newCrew.name[0]}</div>
                    <div class="crew-details">
                        <h3>${newCrew.name}</h3>
                        <span class="crew-class">${classData?.name || newCrew.class}</span>
                        <div class="crew-stats">
                            <div class="stat"><span class="label">HP</span><span class="value">${newCrew.stats?.hp || classData?.stats?.hp || '?'}</span></div>
                            <div class="stat"><span class="label">공격력</span><span class="value">${newCrew.stats?.attack || classData?.stats?.attack || '?'}</span></div>
                            <div class="stat"><span class="label">방어력</span><span class="value">${newCrew.stats?.defense || classData?.stats?.defense || '?'}</span></div>
                            <div class="stat"><span class="label">분대원</span><span class="value">${newCrew.squadSize || classData?.squadSize || '?'}</span></div>
                        </div>
                        ${classData?.description ? `<p class="crew-desc">${classData.description}</p>` : ''}
                    </div>
                </div>
            `;
        }

        // Display comparison with existing crews
        const comparisonEl = this.elements.crewComparison;
        if (comparisonEl) {
            const existingCrews = GameState.currentRun?.crews || [];

            if (existingCrews.length === 0) {
                comparisonEl.innerHTML = '<p class="no-comparison">현재 크루가 없습니다.</p>';
            } else {
                const newClassData = typeof CrewData !== 'undefined'
                    ? CrewData.getClass(newCrew.class)
                    : null;
                const newStats = newCrew.stats || newClassData?.stats || {};

                comparisonEl.innerHTML = `
                    <h4>기존 크루와 비교</h4>
                    <div class="comparison-list">
                        ${existingCrews.map(crew => {
                            const classData = typeof CrewData !== 'undefined'
                                ? CrewData.getClass(crew.class)
                                : null;
                            const crewStats = crew.stats || classData?.stats || {};

                            const hpDiff = (newStats.hp || 0) - (crewStats.hp || 0);
                            const atkDiff = (newStats.attack || 0) - (crewStats.attack || 0);
                            const defDiff = (newStats.defense || 0) - (crewStats.defense || 0);

                            return `
                                <div class="comparison-row ${crew.isAlive ? '' : 'dead'}">
                                    <div class="crew-mini">
                                        <span class="crew-portrait-mini ${crew.class}">${crew.name[0]}</span>
                                        <span class="crew-name">${crew.name}</span>
                                        <span class="crew-class">${classData?.name || crew.class}</span>
                                    </div>
                                    <div class="stat-comparison">
                                        <span class="stat-diff ${hpDiff > 0 ? 'positive' : hpDiff < 0 ? 'negative' : ''}">
                                            HP: ${hpDiff > 0 ? '+' : ''}${hpDiff}
                                        </span>
                                        <span class="stat-diff ${atkDiff > 0 ? 'positive' : atkDiff < 0 ? 'negative' : ''}">
                                            공격: ${atkDiff > 0 ? '+' : ''}${atkDiff}
                                        </span>
                                        <span class="stat-diff ${defDiff > 0 ? 'positive' : defDiff < 0 ? 'negative' : ''}">
                                            방어: ${defDiff > 0 ? '+' : ''}${defDiff}
                                        </span>
                                    </div>
                                </div>
                            `;
                        }).join('')}
                    </div>
                    <p class="crew-count">현재 크루: ${existingCrews.length}/4</p>
                `;
            }
        }

        // Store new crew for acceptance
        this.pendingRecruitment = newCrew;
    },

    acceptRecruitment() {
        if (!this.pendingRecruitment) return;

        const crews = GameState.currentRun?.crews || [];
        if (crews.length >= 4) {
            alert('크루가 가득 찼습니다! (최대 4명)');
            return;
        }

        // Add new crew to GameState
        GameState.addCrew(this.pendingRecruitment);

        // Hide recruitment panel
        if (this.elements.recruitmentContainer) {
            this.elements.recruitmentContainer.style.display = 'none';
        }

        // Update crew status display
        this.displayCrewStatus();
        this.pendingRecruitment = null;

        console.log('New crew recruited:', this.pendingRecruitment?.name);
    },

    skipRecruitment() {
        // Hide recruitment panel without adding crew
        if (this.elements.recruitmentContainer) {
            this.elements.recruitmentContainer.style.display = 'none';
        }
        this.pendingRecruitment = null;
    },

    // M-013: Display equipment acquisition panel
    displayEquipmentAcquisition() {
        const container = this.elements.equipmentContainer;
        if (!container) return;

        // Only show for equipment-type rewards with victory
        if (!this.result.victory || !this.result.reward?.equipment) {
            container.style.display = 'none';
            return;
        }

        container.style.display = 'block';

        const equipmentId = this.result.reward.equipment;
        const equipData = typeof EquipmentData !== 'undefined'
            ? EquipmentData.get(equipmentId)
            : null;

        // Display acquired equipment info
        const acquiredEl = this.elements.acquiredEquipment;
        if (acquiredEl) {
            acquiredEl.innerHTML = `
                <div class="equipment-card">
                    <div class="equipment-icon">${equipData?.icon || '📦'}</div>
                    <div class="equipment-details">
                        <h3>${equipData?.name || equipmentId}</h3>
                        <span class="equipment-type">${this.getEquipmentTypeName(equipData?.type)}</span>
                        ${equipData?.description ? `<p class="equipment-desc">${equipData.description}</p>` : ''}
                        ${this.renderEquipmentStats(equipData)}
                    </div>
                </div>
            `;
        }

        // Display equip options (available crews)
        const optionsEl = this.elements.equipOptions;
        if (optionsEl) {
            const aliveCrews = GameState.getAliveCrews();

            if (aliveCrews.length === 0) {
                optionsEl.innerHTML = '<p class="no-crews">장착 가능한 크루가 없습니다.</p>';
            } else {
                optionsEl.innerHTML = `
                    <h4>즉시 장착하기</h4>
                    <div class="equip-crew-list">
                        ${aliveCrews.map(crew => {
                            const classData = typeof CrewData !== 'undefined'
                                ? CrewData.getClass(crew.class)
                                : null;
                            const currentEquip = crew.equipment?.[equipData?.type];
                            const currentEquipData = currentEquip && typeof EquipmentData !== 'undefined'
                                ? EquipmentData.get(currentEquip)
                                : null;

                            return `
                                <div class="equip-option" data-crew-id="${crew.id}">
                                    <div class="crew-info">
                                        <span class="crew-portrait-mini ${crew.class}">${crew.name[0]}</span>
                                        <span class="crew-name">${crew.name}</span>
                                    </div>
                                    <div class="current-equip">
                                        ${currentEquipData
                                            ? `<span class="has-equip">${currentEquipData.icon || '📦'} ${currentEquipData.name}</span>`
                                            : '<span class="no-equip">비어있음</span>'
                                        }
                                    </div>
                                    <button class="btn btn-small btn-equip" onclick="ResultController.equipToCrew('${crew.id}', '${equipmentId}')">
                                        ${currentEquipData ? '교체' : '장착'}
                                    </button>
                                </div>
                            `;
                        }).join('')}
                    </div>
                `;
            }
        }
    },

    getEquipmentTypeName(type) {
        const typeNames = {
            weapon: '무기',
            armor: '방어구',
            accessory: '액세서리',
            utility: '유틸리티',
        };
        return typeNames[type] || type || '장비';
    },

    renderEquipmentStats(equipData) {
        if (!equipData?.stats) return '';

        const statLabels = {
            hp: 'HP',
            attack: '공격력',
            defense: '방어력',
            speed: '속도',
            range: '사거리',
            cooldown: '쿨다운',
        };

        const stats = Object.entries(equipData.stats)
            .filter(([_, value]) => value !== 0)
            .map(([key, value]) => {
                const label = statLabels[key] || key;
                const prefix = value > 0 ? '+' : '';
                return `<span class="equip-stat ${value > 0 ? 'positive' : 'negative'}">${label}: ${prefix}${value}</span>`;
            })
            .join('');

        return stats ? `<div class="equipment-stats">${stats}</div>` : '';
    },

    equipToCrew(crewId, equipmentId) {
        const crew = GameState.currentRun?.crews.find(c => c.id === crewId);
        if (!crew) return;

        const equipData = typeof EquipmentData !== 'undefined'
            ? EquipmentData.get(equipmentId)
            : null;

        if (!equipData) return;

        // Initialize equipment object if needed
        if (!crew.equipment) {
            crew.equipment = {};
        }

        // Equip the item
        crew.equipment[equipData.type] = equipmentId;

        // Save state
        GameState.saveRun();

        // Update display
        this.displayEquipmentAcquisition();
        this.displayCrewStatus();

        console.log(`Equipped ${equipmentId} to ${crew.name}`);
    },

    skipEquipment() {
        // Hide equipment panel
        if (this.elements.equipmentContainer) {
            this.elements.equipmentContainer.style.display = 'none';
        }
    },

    goToUpgrade() {
        sessionStorage.removeItem('battleResult');
        Utils.navigateTo('upgrade');
    },

    getUnlockName(unlock) {
        // Try to get display name from data modules
        if (unlock.type === 'class' && typeof CrewData !== 'undefined') {
            const classData = CrewData.getClass(unlock.id);
            return classData?.name || unlock.id;
        }
        if (unlock.type === 'equipment' && typeof EquipmentData !== 'undefined') {
            const equipData = EquipmentData.get(unlock.id);
            return equipData?.name || unlock.id;
        }
        if (unlock.type === 'trait' && typeof TraitData !== 'undefined') {
            const traitData = TraitData.get(unlock.id);
            return traitData?.name || unlock.id;
        }
        if (unlock.type === 'difficulty') {
            const diffNames = {
                hard: '어려움',
                veryhard: '매우 어려움',
                nightmare: '악몽',
            };
            return diffNames[unlock.id] || unlock.id;
        }
        return unlock.id;
    },

    displayCrewStatus() {
        const container = this.elements.crewStatus;
        if (!container) return;

        const crews = GameState.currentRun.crews;

        container.innerHTML = crews.map(crew => {
            const classData = typeof CrewData !== 'undefined'
                ? CrewData.getClass(crew.class)
                : GameState.getClassData(crew.class);
            const statusClass = crew.isAlive ? (crew.squadSize < crew.maxSquadSize ? 'wounded' : 'healthy') : 'dead';

            return `
                <div class="crew-result-card ${statusClass}">
                    <div class="crew-portrait ${crew.class}">${crew.name[0]}</div>
                    <div class="crew-info">
                        <span class="crew-name">${crew.name}</span>
                        <span class="crew-class">${classData?.name || crew.class}</span>
                    </div>
                    <div class="crew-status-indicator">
                        ${crew.isAlive
                            ? `<span class="health">${crew.squadSize}/${crew.maxSquadSize}</span>`
                            : '<span class="dead-text">전사</span>'
                        }
                    </div>
                </div>
            `;
        }).join('');
    },

    continue() {
        // Clear result data
        sessionStorage.removeItem('battleResult');

        // Check for boss victory
        if (this.result.victory && this.result.battleType === 'boss') {
            // Check if this was the final boss (gate node)
            const currentNode = this.findCurrentNode();
            const sectorMap = GameState.currentRun?.sectorMap;
            // Node has 'depth' property, sectorMap has 'totalDepth'
            if (currentNode && sectorMap && currentNode.depth === sectorMap.totalDepth) {
                GameState.endRun(true);
                Utils.navigateTo('victory');
                return;
            }
        }

        // Continue to sector map
        Utils.navigateTo('sector');
    },

    retry() {
        // Restart from sector - lose progress on this node
        sessionStorage.removeItem('battleResult');
        Utils.navigateTo('sector');
    },

    findCurrentNode() {
        const map = GameState.currentRun?.sectorMap;
        if (!map) return null;

        // sectorMap.nodes is a flat array of all nodes
        if (map.nodes) {
            return map.nodes.find(node => node.id === GameState.currentRun.currentNodeId) || null;
        }

        // Fallback: iterate through layers (2D array)
        if (map.layers) {
            for (const layer of map.layers) {
                for (const node of layer) {
                    if (node.id === GameState.currentRun.currentNodeId) {
                        return node;
                    }
                }
            }
        }

        return null;
    }
};

// Initialize on DOM ready
document.addEventListener('DOMContentLoaded', () => {
    ResultController.init();
});
