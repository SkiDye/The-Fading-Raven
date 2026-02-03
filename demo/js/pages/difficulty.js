/**
 * THE FADING RAVEN - Difficulty Selection Controller
 * Handles difficulty selection before starting a new game
 */

const DifficultyController = {
    elements: {},
    selectedDifficulty: 'normal',

    difficulties: {
        normal: {
            name: '보통',
            description: '균형 잡힌 도전',
            modifiers: ['기본 적 체력', '기본 보상', '표준 웨이브 간격'],
            multiplier: 1.0,
        },
        hard: {
            name: '어려움',
            description: '숙련된 지휘관을 위한',
            modifiers: ['+25% 적 체력', '+20% 보상', '빠른 웨이브'],
            multiplier: 1.5,
            requiresUnlock: true,
            unlockCondition: '보통 난이도 클리어',
        },
        veryhard: {
            name: '매우 어려움',
            description: '진정한 전술가만이',
            modifiers: ['+50% 적 체력', '+40% 보상', '매우 빠른 웨이브', '정예 적 증가'],
            multiplier: 2.0,
            requiresUnlock: true,
            unlockCondition: '어려움 난이도 클리어',
        },
        nightmare: {
            name: '악몽',
            description: '생존이 승리다',
            modifiers: ['+100% 적 체력', '+80% 보상', '극한 웨이브', '보스 강화'],
            multiplier: 3.0,
            requiresUnlock: true,
            unlockCondition: '매우 어려움 난이도 클리어',
        },
    },

    init() {
        this.cacheElements();
        this.bindEvents();
        this.renderDifficulties();
        this.checkSeed();
        console.log('DifficultyController initialized');
    },

    cacheElements() {
        this.elements = {
            btnBack: document.getElementById('btn-back'),
            difficultyGrid: document.getElementById('difficulty-grid'),
            btnStart: document.getElementById('btn-start'),
            seedDisplay: document.getElementById('seed-display'),
        };
    },

    bindEvents() {
        // Back button
        this.elements.btnBack?.addEventListener('click', () => this.goBack());

        // Start button
        this.elements.btnStart?.addEventListener('click', () => this.startGame());

        // Keyboard
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                this.goBack();
            } else if (e.key === 'Enter') {
                this.startGame();
            }
        });
    },

    checkSeed() {
        const pendingSeed = sessionStorage.getItem('pendingSeed');
        if (!pendingSeed) {
            // No seed, go back to menu
            Utils.navigateTo('index');
            return;
        }

        if (this.elements.seedDisplay) {
            this.elements.seedDisplay.textContent = pendingSeed;
        }
    },

    renderDifficulties() {
        const grid = this.elements.difficultyGrid;
        if (!grid) return;

        grid.innerHTML = '';

        Object.entries(this.difficulties).forEach(([key, diff]) => {
            const card = document.createElement('div');
            card.className = 'difficulty-card';
            card.dataset.difficulty = key;

            const isUnlocked = !diff.requiresUnlock || GameState.isDifficultyUnlocked(key);

            if (!isUnlocked) {
                card.classList.add('locked');
            }

            if (key === this.selectedDifficulty && isUnlocked) {
                card.classList.add('selected');
            }

            const unlockText = diff.unlockCondition || '이전 난이도 클리어 필요';
            card.innerHTML = `
                <div class="difficulty-header">
                    <h3 class="difficulty-name">${diff.name}</h3>
                    <span class="difficulty-multiplier">x${diff.multiplier}</span>
                </div>
                <p class="difficulty-desc">${diff.description}</p>
                <ul class="difficulty-modifiers">
                    ${diff.modifiers.map(mod => `<li>${mod}</li>`).join('')}
                </ul>
                ${!isUnlocked ? `<div class="locked-overlay"><span>🔒 ${unlockText}</span></div>` : ''}
            `;

            if (isUnlocked) {
                card.addEventListener('click', () => this.selectDifficulty(key));
            }

            grid.appendChild(card);
        });
    },

    selectDifficulty(difficulty) {
        this.selectedDifficulty = difficulty;

        // Update UI
        document.querySelectorAll('.difficulty-card').forEach(card => {
            card.classList.toggle('selected', card.dataset.difficulty === difficulty);
        });
    },

    startGame() {
        const pendingSeed = sessionStorage.getItem('pendingSeed');
        if (!pendingSeed) {
            Utils.navigateTo('index');
            return;
        }

        // Check if difficulty is unlocked
        const diff = this.difficulties[this.selectedDifficulty];
        if (diff.requiresUnlock && !GameState.isDifficultyUnlocked(this.selectedDifficulty)) {
            alert('이 난이도는 아직 잠겨 있습니다.');
            return;
        }

        // Start new run
        GameState.startNewRun(pendingSeed, this.selectedDifficulty);

        // Clear pending seed
        sessionStorage.removeItem('pendingSeed');

        // Navigate to sector map
        Utils.navigateTo('sector');
    },

    goBack() {
        sessionStorage.removeItem('pendingSeed');
        Utils.navigateTo('index');
    }
};

// Initialize on DOM ready
document.addEventListener('DOMContentLoaded', () => {
    DifficultyController.init();
});
