/**
 * THE FADING RAVEN - Game Over Controller
 * Handles game over screen display
 */

const GameOverController = {
    elements: {},

    init() {
        this.cacheElements();
        this.bindEvents();
        this.displayGameOver();
        console.log('GameOverController initialized');
    },

    cacheElements() {
        this.elements = {
            message: document.getElementById('gameover-message'),
            statsContainer: document.querySelector('.run-stats'),
            runInfo: document.querySelector('.run-info'),
            btnNewGame: document.getElementById('btn-retry'),
            btnMainMenu: document.getElementById('btn-menu'),
        };
    },

    bindEvents() {
        this.elements.btnNewGame?.addEventListener('click', () => {
            GameState.clearCurrentRun();
            Utils.navigateTo('index');
        });

        this.elements.btnMainMenu?.addEventListener('click', () => {
            Utils.navigateTo('index');
        });
    },

    displayGameOver() {
        if (!GameState.currentRun) {
            Utils.navigateTo('index');
            return;
        }

        const run = GameState.currentRun;

        // Message based on how player lost
        if (this.elements.message) {
            const aliveCrews = GameState.getAliveCrews();
            if (aliveCrews.length === 0) {
                this.elements.message.textContent = '모든 승무원이 전사했습니다...';
            } else {
                this.elements.message.textContent = '우주 폭풍에 휩쓸렸습니다...';
            }
        }

        // Stats
        this.displayStats();

        // Run info
        this.displayRunInfo();
    },

    displayStats() {
        const container = this.elements.statsContainer;
        if (!container || !GameState.currentRun) return;

        const stats = GameState.currentRun.stats;
        const score = GameState.calculateScore();

        const statItems = [
            { label: '최종 점수', value: Utils.formatNumber(score), highlight: true },
            { label: '방어한 스테이션', value: stats.stationsDefended },
            { label: '잃은 스테이션', value: stats.stationsLost },
            { label: '처치한 적', value: stats.enemiesKilled },
            { label: '잃은 승무원', value: stats.crewsLost },
            { label: '획득한 크레딧', value: Utils.formatNumber(stats.creditsEarned) },
        ];

        container.innerHTML = `
            <h2>전투 기록</h2>
            <div class="stats-grid">
                ${statItems.map(stat => `
                    <div class="stat-item ${stat.highlight ? 'highlight' : ''}">
                        <span class="stat-value">${stat.value}</span>
                        <span class="stat-label">${stat.label}</span>
                    </div>
                `).join('')}
            </div>
        `;
    },

    displayRunInfo() {
        const container = this.elements.runInfo;
        if (!container || !GameState.currentRun) return;

        const run = GameState.currentRun;
        const duration = GameState.getRunDuration();
        const minutes = Math.floor(duration / 60);
        const seconds = duration % 60;

        const difficultyNames = {
            normal: '보통',
            hard: '어려움',
            veryhard: '매우 어려움',
            nightmare: '악몽',
        };

        container.innerHTML = `
            <div class="info-row">
                <span>시드</span>
                <span class="seed">${run.seedString}</span>
            </div>
            <div class="info-row">
                <span>난이도</span>
                <span>${difficultyNames[run.difficulty] || run.difficulty}</span>
            </div>
            <div class="info-row">
                <span>진행 턴</span>
                <span>${run.turn}</span>
            </div>
            <div class="info-row">
                <span>플레이 시간</span>
                <span>${minutes}분 ${seconds}초</span>
            </div>
        `;
    }
};

// Initialize on DOM ready
document.addEventListener('DOMContentLoaded', () => {
    GameOverController.init();
});
