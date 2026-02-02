/**
 * THE FADING RAVEN - Battle Result Controller
 * Handles post-battle result display
 */

const ResultController = {
    elements: {},
    result: null,

    init() {
        this.loadResult();
        this.cacheElements();
        this.bindEvents();
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
            btnContinue: document.getElementById('btn-continue'),
            btnRetry: document.getElementById('btn-retry'),
        };
    },

    bindEvents() {
        this.elements.btnContinue?.addEventListener('click', () => this.continue());
        this.elements.btnRetry?.addEventListener('click', () => this.retry());

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
            };
            this.elements.resultSubtitle.textContent = typeNames[this.result.battleType] || '전투';
        }

        // Stats
        this.displayStats();

        // Rewards
        this.displayRewards();

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

        const stats = [
            { label: '웨이브 완료', value: `${this.result.wavesCompleted}/${this.result.totalWaves}` },
            { label: '적 처치', value: this.result.enemiesKilled },
            { label: '스테이션 상태', value: `${Math.floor(this.result.stationHealth)}%` },
        ];

        container.innerHTML = stats.map(stat => `
            <div class="stat-item">
                <span class="stat-value">${stat.value}</span>
                <span class="stat-label">${stat.label}</span>
            </div>
        `).join('');
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
            rewards.push(`<div class="reward-item"><span class="reward-icon">📦</span><span class="reward-text">장비 획득!</span></div>`);
        }

        // Perfect defense bonus
        if (this.result.stationHealth >= 100) {
            const bonus = Math.floor(this.result.reward.credits * 0.5);
            rewards.push(`<div class="reward-item bonus"><span class="reward-icon">⭐</span><span class="reward-text">완벽 방어 보너스: +${bonus} 크레딧</span></div>`);
        }

        container.innerHTML = rewards.join('');
    },

    displayCrewStatus() {
        const container = this.elements.crewStatus;
        if (!container) return;

        const crews = GameState.currentRun.crews;

        container.innerHTML = crews.map(crew => {
            const classData = GameState.getClassData(crew.class);
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
            // Check if this was the final boss
            const currentNode = this.findCurrentNode();
            if (currentNode && currentNode.row === GameState.currentRun.sectorMap.length - 1) {
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

        for (const row of map) {
            for (const node of row) {
                if (node.id === GameState.currentRun.currentNodeId) {
                    return node;
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
