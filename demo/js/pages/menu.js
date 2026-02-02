/**
 * THE FADING RAVEN - Main Menu Controller
 * Handles main menu interactions and navigation
 */

const MenuController = {
    elements: {},

    init() {
        this.cacheElements();
        this.bindEvents();
        this.checkContinue();
        this.initStarfield();
        console.log('MenuController initialized');
    },

    cacheElements() {
        this.elements = {
            btnNewGame: document.getElementById('btn-new-game'),
            btnContinue: document.getElementById('btn-continue'),
            btnSettings: document.getElementById('btn-settings'),
            btnCredits: document.getElementById('btn-credits'),
            seedModal: document.getElementById('seed-modal'),
            seedInput: document.getElementById('seed-input'),
            btnRandomSeed: document.getElementById('btn-random-seed'),
            btnStartGame: document.getElementById('btn-start-game'),
            btnCancelSeed: document.getElementById('btn-cancel-seed'),
            starfield: document.querySelector('.starfield'),
        };
    },

    bindEvents() {
        // Main menu buttons
        this.elements.btnNewGame?.addEventListener('click', () => this.showSeedModal());
        this.elements.btnContinue?.addEventListener('click', () => this.continueGame());
        this.elements.btnSettings?.addEventListener('click', () => Utils.navigateTo('settings'));
        this.elements.btnCredits?.addEventListener('click', () => Utils.navigateTo('credits'));

        // Seed modal
        this.elements.btnRandomSeed?.addEventListener('click', () => this.generateRandomSeed());
        this.elements.btnStartGame?.addEventListener('click', () => this.startNewGame());
        this.elements.btnCancelSeed?.addEventListener('click', () => this.hideSeedModal());

        // Seed input formatting
        this.elements.seedInput?.addEventListener('input', (e) => this.formatSeedInput(e));

        // Close modal on backdrop click
        this.elements.seedModal?.addEventListener('click', (e) => {
            if (e.target === this.elements.seedModal) {
                this.hideSeedModal();
            }
        });

        // Keyboard shortcuts
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape' && this.elements.seedModal?.classList.contains('active')) {
                this.hideSeedModal();
            }
        });
    },

    checkContinue() {
        // Enable/disable continue button based on active run
        if (GameState.hasActiveRun()) {
            this.elements.btnContinue?.classList.remove('disabled');
            this.elements.btnContinue?.removeAttribute('disabled');
        } else {
            this.elements.btnContinue?.classList.add('disabled');
            this.elements.btnContinue?.setAttribute('disabled', 'true');
        }
    },

    showSeedModal() {
        this.generateRandomSeed();
        this.elements.seedModal?.classList.add('active');
        this.elements.seedInput?.focus();
    },

    hideSeedModal() {
        this.elements.seedModal?.classList.remove('active');
    },

    generateRandomSeed() {
        const seed = SeedUtils.generateSeedString();
        if (this.elements.seedInput) {
            this.elements.seedInput.value = seed;
        }
    },

    formatSeedInput(e) {
        const input = e.target;
        const formatted = SeedUtils.formatSeedString(input.value);
        input.value = formatted;
    },

    startNewGame() {
        const seedString = this.elements.seedInput?.value || SeedUtils.generateSeedString();

        // Validate seed
        if (!SeedUtils.isValidSeedString(seedString)) {
            this.showError('유효하지 않은 시드입니다. XXXX-XXXX-XXXX 형식으로 입력하세요.');
            return;
        }

        // Clear any existing run and navigate to difficulty selection
        GameState.clearCurrentRun();

        // Store seed temporarily for difficulty page
        sessionStorage.setItem('pendingSeed', seedString);

        this.hideSeedModal();
        Utils.navigateTo('difficulty');
    },

    continueGame() {
        if (!GameState.hasActiveRun()) {
            this.showError('진행 중인 게임이 없습니다.');
            return;
        }

        // Navigate to sector map
        Utils.navigateTo('sector');
    },

    showError(message) {
        // Simple alert for now - could be replaced with custom modal
        alert(message);
    },

    // Starfield animation
    initStarfield() {
        const starfield = this.elements.starfield;
        if (!starfield) return;

        // Create stars
        for (let i = 0; i < 100; i++) {
            const star = document.createElement('div');
            star.className = 'star';
            star.style.left = `${Math.random() * 100}%`;
            star.style.top = `${Math.random() * 100}%`;
            star.style.animationDelay = `${Math.random() * 3}s`;
            star.style.animationDuration = `${2 + Math.random() * 3}s`;

            // Random star size
            const size = Math.random() < 0.3 ? 2 : 1;
            star.style.width = `${size}px`;
            star.style.height = `${size}px`;

            starfield.appendChild(star);
        }

        // Create shooting stars occasionally
        this.createShootingStar();
    },

    createShootingStar() {
        const starfield = this.elements.starfield;
        if (!starfield) return;

        const shootingStar = document.createElement('div');
        shootingStar.className = 'shooting-star';
        shootingStar.style.left = `${Math.random() * 70}%`;
        shootingStar.style.top = `${Math.random() * 50}%`;

        starfield.appendChild(shootingStar);

        // Remove after animation
        setTimeout(() => {
            shootingStar.remove();
        }, 1000);

        // Schedule next shooting star
        setTimeout(() => this.createShootingStar(), 3000 + Math.random() * 5000);
    }
};

// Initialize on DOM ready
document.addEventListener('DOMContentLoaded', () => {
    MenuController.init();
});
