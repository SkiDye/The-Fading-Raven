/**
 * THE FADING RAVEN - Victory Controller
 * Handles victory screen display
 */

const VictoryController = {
    elements: {},

    init() {
        this.cacheElements();
        this.bindEvents();
        this.displayVictory();
        this.checkUnlocks();
        console.log('VictoryController initialized');
    },

    cacheElements() {
        this.elements = {
            scoreDisplay: document.querySelector('.final-score'),
            statsContainer: document.querySelector('.run-stats'),
            runInfo: document.querySelector('.run-info'),
            survivingCrew: document.querySelector('.surviving-crew'),
            unlocksContainer: document.getElementById('unlocks-section'),
            btnNewGame: document.getElementById('btn-new-run'),
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

    displayVictory() {
        if (!GameState.currentRun) {
            Utils.navigateTo('index');
            return;
        }

        // Score
        if (this.elements.scoreDisplay) {
            const score = GameState.calculateScore();
            this.elements.scoreDisplay.innerHTML = `
                <span class="score-label">최종 점수</span>
                <span class="score-value">${Utils.formatNumber(score)}</span>
            `;
        }

        // Stats
        this.displayStats();

        // Run info
        this.displayRunInfo();

        // Surviving crew
        this.displaySurvivingCrew();
    },

    displayStats() {
        const container = this.elements.statsContainer;
        if (!container || !GameState.currentRun) return;

        const stats = GameState.currentRun.stats;

        const statItems = [
            { label: '방어한 스테이션', value: stats.stationsDefended },
            { label: '완벽 방어', value: stats.perfectDefenses },
            { label: '처치한 적', value: stats.enemiesKilled },
            { label: '획득한 크레딧', value: Utils.formatNumber(stats.creditsEarned) },
        ];

        container.innerHTML = `
            <h2>전투 기록</h2>
            <div class="stats-grid">
                ${statItems.map(stat => `
                    <div class="stat-item">
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
                <span>총 턴</span>
                <span>${run.turn}</span>
            </div>
            <div class="info-row">
                <span>플레이 시간</span>
                <span>${minutes}분 ${seconds}초</span>
            </div>
        `;
    },

    displaySurvivingCrew() {
        const container = this.elements.survivingCrew;
        if (!container || !GameState.currentRun) return;

        const aliveCrews = GameState.getAliveCrews();

        if (aliveCrews.length === 0) {
            container.style.display = 'none';
            return;
        }

        container.innerHTML = `
            <h2>생존자</h2>
            <div class="crew-portraits">
                ${aliveCrews.map(crew => `
                    <div class="survivor-portrait">
                        <div class="survivor-icon ${crew.class}">${crew.name[0]}</div>
                        <span class="survivor-name">${crew.name}</span>
                    </div>
                `).join('')}
            </div>
        `;
    },

    checkUnlocks() {
        const container = this.elements.unlocksContainer;
        if (!container || !GameState.currentRun) return;

        const unlocks = [];
        const run = GameState.currentRun;

        // Check difficulty unlock
        const difficultyOrder = ['normal', 'hard', 'veryhard', 'nightmare'];
        const currentIndex = difficultyOrder.indexOf(run.difficulty);

        if (currentIndex < difficultyOrder.length - 1) {
            const nextDifficulty = difficultyOrder[currentIndex + 1];
            const difficultyNames = {
                hard: '어려움',
                veryhard: '매우 어려움',
                nightmare: '악몽',
            };

            // Check if this is a new unlock
            const previousHighest = GameState.progress.highestDifficulty;
            const previousIndex = difficultyOrder.indexOf(previousHighest);

            if (currentIndex >= previousIndex) {
                unlocks.push({
                    icon: '⚔️',
                    name: `${difficultyNames[nextDifficulty]} 난이도 해금`,
                    desc: '새로운 도전이 기다립니다!',
                });
            }
        }

        // Check for first victory achievement
        if (GameState.progress.totalVictories === 1) {
            unlocks.push({
                icon: '🏆',
                name: '첫 승리',
                desc: '우주 폭풍으로부터 살아남았습니다!',
            });
        }

        // Check for perfect run (no stations lost)
        if (run.stats.stationsLost === 0) {
            unlocks.push({
                icon: '⭐',
                name: '완벽한 지휘관',
                desc: '스테이션을 하나도 잃지 않았습니다!',
            });
        }

        // Check for survivor achievement (all crews alive)
        if (GameState.getAliveCrews().length === run.crews.length) {
            unlocks.push({
                icon: '💚',
                name: '전원 생존',
                desc: '모든 승무원이 살아남았습니다!',
            });
        }

        // Display unlocks
        if (unlocks.length > 0) {
            container.classList.add('active');
            container.innerHTML = `
                <h2>해금 및 업적</h2>
                <div class="unlock-list">
                    ${unlocks.map(unlock => `
                        <div class="unlock-item">
                            <span class="unlock-icon">${unlock.icon}</span>
                            <div class="unlock-info">
                                <span class="unlock-name">${unlock.name}</span>
                                <span class="unlock-desc">${unlock.desc}</span>
                            </div>
                        </div>
                    `).join('')}
                </div>
            `;
        } else {
            container.classList.remove('active');
        }
    }
};

// Initialize on DOM ready
document.addEventListener('DOMContentLoaded', () => {
    VictoryController.init();
});
