/**
 * THE FADING RAVEN - Settings Controller
 * Handles game settings management with tabs and accessibility options
 */

const SettingsController = {
    elements: {},
    currentTab: 'gameplay',

    init() {
        this.cacheElements();
        this.bindEvents();
        this.loadCurrentSettings();
        this.updateStorageInfo();
        console.log('SettingsController initialized');
    },

    cacheElements() {
        this.elements = {
            // Tabs
            tabBtns: document.querySelectorAll('.tab-btn'),
            tabContents: document.querySelectorAll('.settings-tab-content'),

            // Navigation
            btnBack: document.getElementById('btn-back'),
            btnSave: document.getElementById('btn-save'),

            // Gameplay
            difficultySelect: document.getElementById('setting-difficulty'),
            gameSpeedSlider: document.getElementById('setting-speed'),
            gameSpeedValue: document.getElementById('speed-value'),
            tutorialToggle: document.getElementById('setting-tutorial'),
            autoPauseToggle: document.getElementById('setting-auto-pause'),
            tooltipsToggle: document.getElementById('setting-tooltips'),
            confirmToggle: document.getElementById('setting-confirm'),

            // Audio
            masterSlider: document.getElementById('setting-master'),
            masterValue: document.getElementById('master-value'),
            musicSlider: document.getElementById('setting-music'),
            musicValue: document.getElementById('music-value'),
            sfxSlider: document.getElementById('setting-sfx'),
            sfxValue: document.getElementById('sfx-value'),
            uiSoundsToggle: document.getElementById('setting-ui-sounds'),
            muteBgToggle: document.getElementById('setting-mute-bg'),

            // Accessibility
            screenShakeToggle: document.getElementById('setting-screenshake'),
            flashToggle: document.getElementById('setting-flash'),
            colorblindSelect: document.getElementById('setting-colorblind'),
            textSizeSlider: document.getElementById('setting-text-size'),
            textSizeValue: document.getElementById('text-size-value'),
            contrastToggle: document.getElementById('setting-contrast'),
            reducedMotionToggle: document.getElementById('setting-reduced-motion'),
            dyslexiaToggle: document.getElementById('setting-dyslexia'),

            // Data
            btnClearRun: document.getElementById('btn-clear-run'),
            btnResetSettings: document.getElementById('btn-reset-settings'),
            btnResetProgress: document.getElementById('btn-reset-progress'),
            btnExport: document.getElementById('btn-export'),
            btnImport: document.getElementById('btn-import'),
            importFile: document.getElementById('import-file'),
            storageUsed: document.getElementById('storage-used'),
            lastSaved: document.getElementById('last-saved'),
        };
    },

    bindEvents() {
        // Tab switching
        this.elements.tabBtns.forEach(btn => {
            btn.addEventListener('click', () => this.switchTab(btn.dataset.tab));
        });

        // Navigation
        this.elements.btnBack?.addEventListener('click', () => this.goBack());
        this.elements.btnSave?.addEventListener('click', () => this.saveSettings());

        // Gameplay settings
        this.bindSlider('gameSpeedSlider', 'gameSpeedValue', 'gameSpeed', (v) => `${v}x`);
        this.bindSelect('difficultySelect', 'difficulty');
        this.bindToggle('tutorialToggle', 'showTutorial');
        this.bindToggle('autoPauseToggle', 'autoPause');
        this.bindToggle('tooltipsToggle', 'showTooltips');
        this.bindToggle('confirmToggle', 'confirmActions');

        // Audio settings
        this.bindSlider('masterSlider', 'masterValue', 'masterVolume', (v) => `${v}%`);
        this.bindSlider('musicSlider', 'musicValue', 'musicVolume', (v) => `${v}%`);
        this.bindSlider('sfxSlider', 'sfxValue', 'sfxVolume', (v) => `${v}%`);
        this.bindToggle('uiSoundsToggle', 'uiSounds');
        this.bindToggle('muteBgToggle', 'muteWhenBackground');

        // Accessibility settings
        this.bindToggle('screenShakeToggle', 'screenShake');
        this.bindToggle('flashToggle', 'screenFlash');
        this.bindSelect('colorblindSelect', 'colorblindMode');
        this.bindSlider('textSizeSlider', 'textSizeValue', 'textSize', (v) => `${v}%`, () => this.applyTextSize());
        this.bindToggle('contrastToggle', 'highContrast', () => this.applyContrast());
        this.bindToggle('reducedMotionToggle', 'reducedMotion', () => this.applyReducedMotion());
        this.bindToggle('dyslexiaToggle', 'dyslexiaFont', () => this.applyDyslexiaFont());

        // Data management
        this.elements.btnClearRun?.addEventListener('click', () => this.clearCurrentRun());
        this.elements.btnResetSettings?.addEventListener('click', () => this.resetSettings());
        this.elements.btnResetProgress?.addEventListener('click', () => this.resetProgress());
        this.elements.btnExport?.addEventListener('click', () => this.exportSave());
        this.elements.btnImport?.addEventListener('click', () => this.elements.importFile?.click());
        this.elements.importFile?.addEventListener('change', (e) => this.importSave(e));

        // Keyboard
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                this.goBack();
            }
        });
    },

    // ============================================
    // BINDING HELPERS
    // ============================================

    bindSlider(sliderId, valueId, settingKey, formatter, callback) {
        const slider = this.elements[sliderId];
        const valueEl = this.elements[valueId];

        if (!slider) return;

        slider.addEventListener('input', (e) => {
            const value = parseFloat(e.target.value);
            if (valueEl) valueEl.textContent = formatter(value);
            this.setSetting(settingKey, value);
            if (callback) callback(value);
        });
    },

    bindSelect(selectId, settingKey, callback) {
        const select = this.elements[selectId];
        if (!select) return;

        select.addEventListener('change', (e) => {
            this.setSetting(settingKey, e.target.value);
            if (callback) callback(e.target.value);
        });
    },

    bindToggle(toggleId, settingKey, callback) {
        const toggle = this.elements[toggleId];
        if (!toggle) return;

        toggle.addEventListener('change', (e) => {
            this.setSetting(settingKey, e.target.checked);
            if (callback) callback(e.target.checked);
        });
    },

    setSetting(key, value) {
        if (typeof GameState !== 'undefined' && GameState.setSetting) {
            GameState.setSetting(key, value);
        } else {
            // Fallback to localStorage
            const settings = JSON.parse(localStorage.getItem('tfr_settings') || '{}');
            settings[key] = value;
            localStorage.setItem('tfr_settings', JSON.stringify(settings));
        }
    },

    getSetting(key, defaultValue) {
        if (typeof GameState !== 'undefined' && GameState.settings) {
            return GameState.settings[key] ?? defaultValue;
        }
        // Fallback
        const settings = JSON.parse(localStorage.getItem('tfr_settings') || '{}');
        return settings[key] ?? defaultValue;
    },

    // ============================================
    // TAB MANAGEMENT
    // ============================================

    switchTab(tabName) {
        this.currentTab = tabName;

        // Update tab buttons
        this.elements.tabBtns.forEach(btn => {
            btn.classList.toggle('active', btn.dataset.tab === tabName);
        });

        // Update tab contents
        this.elements.tabContents.forEach(content => {
            content.classList.toggle('active', content.id === `tab-${tabName}`);
        });
    },

    // ============================================
    // LOAD/SAVE SETTINGS
    // ============================================

    loadCurrentSettings() {
        // Gameplay
        this.loadSelect('difficultySelect', 'difficulty', 'normal');
        this.loadSlider('gameSpeedSlider', 'gameSpeedValue', 'gameSpeed', 1, (v) => `${v}x`);
        this.loadToggle('tutorialToggle', 'showTutorial', true);
        this.loadToggle('autoPauseToggle', 'autoPause', true);
        this.loadToggle('tooltipsToggle', 'showTooltips', true);
        this.loadToggle('confirmToggle', 'confirmActions', true);

        // Audio
        this.loadSlider('masterSlider', 'masterValue', 'masterVolume', 100, (v) => `${v}%`);
        this.loadSlider('musicSlider', 'musicValue', 'musicVolume', 50, (v) => `${v}%`);
        this.loadSlider('sfxSlider', 'sfxValue', 'sfxVolume', 70, (v) => `${v}%`);
        this.loadToggle('uiSoundsToggle', 'uiSounds', true);
        this.loadToggle('muteBgToggle', 'muteWhenBackground', false);

        // Accessibility
        this.loadToggle('screenShakeToggle', 'screenShake', true);
        this.loadToggle('flashToggle', 'screenFlash', true);
        this.loadSelect('colorblindSelect', 'colorblindMode', 'none');
        this.loadSlider('textSizeSlider', 'textSizeValue', 'textSize', 100, (v) => `${v}%`);
        this.loadToggle('contrastToggle', 'highContrast', false);
        this.loadToggle('reducedMotionToggle', 'reducedMotion', false);
        this.loadToggle('dyslexiaToggle', 'dyslexiaFont', false);

        // Apply visual settings
        this.applyTextSize();
        this.applyContrast();
        this.applyReducedMotion();
        this.applyDyslexiaFont();
        this.applyColorblindMode();
    },

    loadSlider(sliderId, valueId, settingKey, defaultValue, formatter) {
        const slider = this.elements[sliderId];
        const valueEl = this.elements[valueId];
        if (!slider) return;

        const value = this.getSetting(settingKey, defaultValue);
        slider.value = value;
        if (valueEl) valueEl.textContent = formatter(value);
    },

    loadSelect(selectId, settingKey, defaultValue) {
        const select = this.elements[selectId];
        if (!select) return;

        select.value = this.getSetting(settingKey, defaultValue);
    },

    loadToggle(toggleId, settingKey, defaultValue) {
        const toggle = this.elements[toggleId];
        if (!toggle) return;

        toggle.checked = this.getSetting(settingKey, defaultValue);
    },

    saveSettings() {
        if (typeof GameState !== 'undefined' && GameState.saveSettings) {
            GameState.saveSettings();
        }

        // Show feedback
        if (typeof Toast !== 'undefined') {
            Toast.success('Settings saved!');
        } else {
            alert('설정이 저장되었습니다.');
        }
    },

    // ============================================
    // ACCESSIBILITY APPLICATIONS
    // ============================================

    applyTextSize() {
        const size = this.getSetting('textSize', 100);
        document.documentElement.style.fontSize = `${size}%`;
    },

    applyContrast() {
        const enabled = this.getSetting('highContrast', false);
        document.body.classList.toggle('high-contrast', enabled);
    },

    applyReducedMotion() {
        const enabled = this.getSetting('reducedMotion', false);
        document.body.classList.toggle('reduced-motion', enabled);
    },

    applyDyslexiaFont() {
        const enabled = this.getSetting('dyslexiaFont', false);
        document.body.classList.toggle('dyslexia-font', enabled);
    },

    applyColorblindMode() {
        const mode = this.getSetting('colorblindMode', 'none');
        document.body.classList.remove('colorblind-protanopia', 'colorblind-deuteranopia', 'colorblind-tritanopia');
        if (mode !== 'none') {
            document.body.classList.add(`colorblind-${mode}`);
        }
    },

    // ============================================
    // DATA MANAGEMENT
    // ============================================

    clearCurrentRun() {
        const confirmMsg = '진행 중인 게임을 삭제하시겠습니까?';

        if (typeof ModalManager !== 'undefined') {
            ModalManager.confirm(confirmMsg, () => {
                if (typeof GameState !== 'undefined') {
                    GameState.clearCurrentRun();
                }
                Toast.info('진행 중인 게임이 삭제되었습니다.');
            });
        } else if (confirm(confirmMsg)) {
            if (typeof GameState !== 'undefined') {
                GameState.clearCurrentRun();
            }
            alert('진행 중인 게임이 삭제되었습니다.');
        }
    },

    resetSettings() {
        const confirmMsg = '모든 설정을 기본값으로 복원하시겠습니까?';

        if (typeof ModalManager !== 'undefined') {
            ModalManager.confirm(confirmMsg, () => {
                localStorage.removeItem('tfr_settings');
                if (typeof GameState !== 'undefined' && GameState.resetSettings) {
                    GameState.resetSettings();
                }
                this.loadCurrentSettings();
                Toast.success('설정이 초기화되었습니다.');
            });
        } else if (confirm(confirmMsg)) {
            localStorage.removeItem('tfr_settings');
            this.loadCurrentSettings();
            alert('설정이 초기화되었습니다.');
        }
    },

    resetProgress() {
        const confirmMsg = '정말로 모든 데이터를 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다!';

        if (typeof ModalManager !== 'undefined') {
            ModalManager.confirm(confirmMsg, () => {
                this.performReset();
            });
        } else if (confirm(confirmMsg)) {
            this.performReset();
        }
    },

    performReset() {
        // Clear all game data
        const keysToRemove = [];
        for (let i = 0; i < localStorage.length; i++) {
            const key = localStorage.key(i);
            if (key && key.startsWith('tfr_')) {
                keysToRemove.push(key);
            }
        }
        keysToRemove.forEach(key => localStorage.removeItem(key));

        if (typeof GameState !== 'undefined') {
            GameState.resetProgress?.();
            GameState.clearCurrentRun?.();
        }

        if (typeof Toast !== 'undefined') {
            Toast.success('모든 데이터가 삭제되었습니다.');
        } else {
            alert('모든 데이터가 삭제되었습니다.');
        }

        this.updateStorageInfo();
    },

    exportSave() {
        const data = {};

        // Collect all game data
        for (let i = 0; i < localStorage.length; i++) {
            const key = localStorage.key(i);
            if (key && key.startsWith('tfr_')) {
                data[key] = localStorage.getItem(key);
            }
        }

        // Create and download file
        const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `the-fading-raven-save-${new Date().toISOString().split('T')[0]}.json`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);

        if (typeof Toast !== 'undefined') {
            Toast.success('저장 데이터를 내보냈습니다.');
        }
    },

    importSave(event) {
        const file = event.target.files?.[0];
        if (!file) return;

        const reader = new FileReader();
        reader.onload = (e) => {
            try {
                const data = JSON.parse(e.target.result);

                // Validate data
                if (typeof data !== 'object') {
                    throw new Error('Invalid save file format');
                }

                // Import data
                Object.entries(data).forEach(([key, value]) => {
                    if (key.startsWith('tfr_')) {
                        localStorage.setItem(key, value);
                    }
                });

                if (typeof Toast !== 'undefined') {
                    Toast.success('저장 데이터를 불러왔습니다. 새로고침합니다...');
                } else {
                    alert('저장 데이터를 불러왔습니다.');
                }

                // Reload to apply
                setTimeout(() => location.reload(), 1000);

            } catch (error) {
                console.error('Import error:', error);
                if (typeof Toast !== 'undefined') {
                    Toast.error('저장 파일을 읽을 수 없습니다.');
                } else {
                    alert('저장 파일을 읽을 수 없습니다.');
                }
            }
        };
        reader.readAsText(file);

        // Reset input
        event.target.value = '';
    },

    updateStorageInfo() {
        // Calculate storage usage
        let totalSize = 0;
        for (let i = 0; i < localStorage.length; i++) {
            const key = localStorage.key(i);
            if (key && key.startsWith('tfr_')) {
                totalSize += (localStorage.getItem(key) || '').length * 2; // UTF-16
            }
        }

        const sizeKB = (totalSize / 1024).toFixed(2);
        if (this.elements.storageUsed) {
            this.elements.storageUsed.textContent = `${sizeKB} KB`;
        }

        // Last saved time
        const lastSaved = localStorage.getItem('tfr_last_saved');
        if (this.elements.lastSaved) {
            this.elements.lastSaved.textContent = lastSaved
                ? new Date(parseInt(lastSaved)).toLocaleString()
                : 'Never';
        }
    },

    // ============================================
    // NAVIGATION
    // ============================================

    goBack() {
        if (typeof Utils !== 'undefined' && Utils.navigateTo) {
            Utils.navigateTo('index');
        } else {
            window.location.href = '../index.html';
        }
    }
};

// Initialize on DOM ready
document.addEventListener('DOMContentLoaded', () => {
    SettingsController.init();
});
