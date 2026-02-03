/**
 * THE FADING RAVEN - Credits Controller
 * Handles credits page display
 */

const CreditsController = {
    elements: {},

    init() {
        this.cacheElements();
        this.bindEvents();
        console.log('CreditsController initialized');
    },

    cacheElements() {
        this.elements = {
            btnBack: document.getElementById('btn-back'),
            creditsContent: document.querySelector('.credits-content'),
        };
    },

    bindEvents() {
        // Back button
        this.elements.btnBack?.addEventListener('click', () => this.goBack());

        // Keyboard
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                this.goBack();
            }
        });
    },

    goBack() {
        Utils.navigateTo('index');
    }
};

// Initialize on DOM ready
document.addEventListener('DOMContentLoaded', () => {
    CreditsController.init();
});
