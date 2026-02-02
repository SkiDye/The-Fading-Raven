/**
 * THE FADING RAVEN - Settings Controller
 * Handles game settings management
 */

const SettingsController = {
    elements: {},

    init() {
        this.cacheElements();
        this.bindEvents();
        this.loadCurrentSettings();
        console.log('SettingsController initialized');
    },

    cacheElements() {
        this.elements = {
            btnBack: document.getElementById('btn-back'),
            difficultySelect: document.getElementById('setting-difficulty'),
            gameSpeedSlider: document.getElementById('setting-speed'),
            gameSpeedValue: document.getElementById('speed-value'),
            soundSlider: document.getElementById('setting-volume'),
            soundValue: document.getElementById('volume-value'),
            musicSlider: document.getElementById('setting-music'),
            musicValue: document.getElementById('music-value'),
            tutorialToggle: document.getElementById('setting-tutorial'),
            screenShakeToggle: document.getElementById('setting-screenshake'),
            btnResetProgress: document.getElementById('btn-reset-progress'),
        };
    },

    bindEvents() {
        // Back button
        this.elements.btnBack?.addEventListener('click', () => this.goBack());

        // Difficulty
        this.elements.difficultySelect?.addEventListener('change', (e) => {
            GameState.setSetting('difficulty', e.target.value);
        });

        // Game speed
        this.elements.gameSpeedSlider?.addEventListener('input', (e) => {
            const value = parseFloat(e.target.value);
            this.updateSliderDisplay('gameSpeed', value);
            GameState.setSetting('gameSpeed', value);
        });

        // Sound volume
        this.elements.soundSlider?.addEventListener('input', (e) => {
            const value = parseInt(e.target.value);
            this.updateSliderDisplay('sound', value);
            GameState.setSetting('soundVolume', value);
        });

        // Music volume
        this.elements.musicSlider?.addEventListener('input', (e) => {
            const value = parseInt(e.target.value);
            this.updateSliderDisplay('music', value);
            GameState.setSetting('musicVolume', value);
        });

        // Tutorial toggle
        this.elements.tutorialToggle?.addEventListener('change', (e) => {
            GameState.setSetting('showTutorial', e.target.checked);
        });

        // Screen shake toggle
        this.elements.screenShakeToggle?.addEventListener('change', (e) => {
            GameState.setSetting('screenShake', e.target.checked);
        });

        // Reset buttons
        this.elements.btnResetProgress?.addEventListener('click', () => this.resetProgress());
        this.elements.btnResetSettings?.addEventListener('click', () => this.resetSettings());

        // Keyboard
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                this.goBack();
            }
        });
    },

    loadCurrentSettings() {
        const settings = GameState.settings;

        // Difficulty
        if (this.elements.difficultySelect) {
            this.elements.difficultySelect.value = settings.difficulty;
        }

        // Game speed
        if (this.elements.gameSpeedSlider) {
            this.elements.gameSpeedSlider.value = settings.gameSpeed;
            this.updateSliderDisplay('gameSpeed', settings.gameSpeed);
        }

        // Sound volume
        if (this.elements.soundSlider) {
            this.elements.soundSlider.value = settings.soundVolume;
            this.updateSliderDisplay('sound', settings.soundVolume);
        }

        // Music volume
        if (this.elements.musicSlider) {
            this.elements.musicSlider.value = settings.musicVolume;
            this.updateSliderDisplay('music', settings.musicVolume);
        }

        // Toggles
        if (this.elements.tutorialToggle) {
            this.elements.tutorialToggle.checked = settings.showTutorial;
        }
        if (this.elements.screenShakeToggle) {
            this.elements.screenShakeToggle.checked = settings.screenShake;
        }
    },

    updateSliderDisplay(type, value) {
        switch (type) {
            case 'gameSpeed':
                if (this.elements.gameSpeedValue) {
                    this.elements.gameSpeedValue.textContent = `${value}x`;
                }
                break;
            case 'sound':
                if (this.elements.soundValue) {
                    this.elements.soundValue.textContent = `${value}%`;
                }
                break;
            case 'music':
                if (this.elements.musicValue) {
                    this.elements.musicValue.textContent = `${value}%`;
                }
                break;
        }
    },

    resetProgress() {
        if (confirm('모든 진행 상황을 초기화하시겠습니까? 이 작업은 되돌릴 수 없습니다.')) {
            GameState.resetProgress();
            GameState.clearCurrentRun();
            alert('진행 상황이 초기화되었습니다.');
        }
    },

    resetSettings() {
        if (confirm('모든 설정을 기본값으로 초기화하시겠습니까?')) {
            GameState.settings = { ...GameState.defaultSettings };
            GameState.saveSettings();
            this.loadCurrentSettings();
            alert('설정이 초기화되었습니다.');
        }
    },

    goBack() {
        Utils.navigateTo('index');
    }
};

// Initialize on DOM ready
document.addEventListener('DOMContentLoaded', () => {
    SettingsController.init();
});
