/**
 * THE FADING RAVEN - HUD System
 * 전투 중 표시되는 정보 UI: 웨이브, 시설, 크레딧, 크루 상태 등
 */

// ============================================
// HUD MANAGER
// ============================================
const HUD = {
    container: null,
    elements: {},
    state: {
        wave: { current: 0, total: 0 },
        facilities: [],
        credits: 0,
        crews: [],
        selectedCrew: null,
        isPaused: false,
        gameSpeed: 1
    },

    init(containerSelector = '#battle-hud') {
        this.container = document.querySelector(containerSelector);
        if (!this.container) {
            console.warn('HUD container not found, creating one');
            this.container = document.createElement('div');
            this.container.id = 'battle-hud';
            this.container.className = 'hud-container';
            document.body.appendChild(this.container);
        }

        this.render();
        this.bindEvents();

        console.log('HUD initialized');
    },

    render() {
        this.container.innerHTML = `
            <!-- Top Bar -->
            <div class="hud-top-bar">
                <div class="hud-left">
                    <div class="hud-wave-info">
                        <span class="wave-label">WAVE</span>
                        <span class="wave-current" id="hud-wave-current">0</span>
                        <span class="wave-separator">/</span>
                        <span class="wave-total" id="hud-wave-total">0</span>
                    </div>
                    <div class="hud-enemy-count" id="hud-enemy-count">
                        <span class="enemy-icon">!</span>
                        <span class="enemy-value">0</span>
                    </div>
                </div>

                <div class="hud-center">
                    <div class="hud-facility-status" id="hud-facility-status">
                        <!-- 시설 상태 아이콘들 -->
                    </div>
                </div>

                <div class="hud-right">
                    <div class="hud-credits">
                        <span class="credits-icon">C</span>
                        <span class="credits-value" id="hud-credits">0</span>
                    </div>
                    <div class="hud-controls">
                        <button class="hud-btn" id="hud-btn-pause" title="일시정지 (Space)">
                            <span class="pause-icon">||</span>
                        </button>
                        <button class="hud-btn" id="hud-btn-speed" title="게임 속도">
                            <span class="speed-icon">x1</span>
                        </button>
                    </div>
                </div>
            </div>

            <!-- Bottom Bar - Crew Selection -->
            <div class="hud-bottom-bar">
                <div class="hud-crew-list" id="hud-crew-list">
                    <!-- 크루 선택 버튼들 -->
                </div>

                <!-- Selected Crew Panel -->
                <div class="hud-crew-panel" id="hud-crew-panel">
                    <div class="crew-panel-portrait" id="crew-panel-portrait"></div>
                    <div class="crew-panel-info">
                        <div class="crew-panel-name" id="crew-panel-name">-</div>
                        <div class="crew-panel-class" id="crew-panel-class">-</div>
                        <div class="crew-panel-health">
                            <div class="health-bar">
                                <div class="health-fill" id="crew-panel-health-fill"></div>
                            </div>
                            <span class="health-text" id="crew-panel-health-text">0/0</span>
                        </div>
                    </div>
                    <div class="crew-panel-actions">
                        <button class="skill-btn" id="crew-skill-btn" disabled>
                            <span class="skill-name" id="crew-skill-name">스킬</span>
                            <span class="skill-cooldown" id="crew-skill-cooldown">준비</span>
                        </button>
                        <button class="equipment-btn" id="crew-equipment-btn" disabled>
                            <span class="equipment-name" id="crew-equipment-name">장비</span>
                        </button>
                    </div>
                </div>
            </div>

            <!-- Wave Announcement Overlay -->
            <div class="hud-wave-announce" id="hud-wave-announce">
                <div class="wave-announce-text">WAVE <span id="wave-announce-num">1</span></div>
                <div class="wave-announce-sub" id="wave-announce-sub">적이 접근 중...</div>
            </div>

            <!-- Alert Messages -->
            <div class="hud-alerts" id="hud-alerts">
                <!-- 동적으로 추가되는 알림들 -->
            </div>
        `;

        this.cacheElements();
    },

    cacheElements() {
        this.elements = {
            waveCurrent: document.getElementById('hud-wave-current'),
            waveTotal: document.getElementById('hud-wave-total'),
            enemyCount: document.getElementById('hud-enemy-count'),
            facilityStatus: document.getElementById('hud-facility-status'),
            credits: document.getElementById('hud-credits'),
            btnPause: document.getElementById('hud-btn-pause'),
            btnSpeed: document.getElementById('hud-btn-speed'),
            crewList: document.getElementById('hud-crew-list'),
            crewPanel: document.getElementById('hud-crew-panel'),
            crewPortrait: document.getElementById('crew-panel-portrait'),
            crewName: document.getElementById('crew-panel-name'),
            crewClass: document.getElementById('crew-panel-class'),
            crewHealthFill: document.getElementById('crew-panel-health-fill'),
            crewHealthText: document.getElementById('crew-panel-health-text'),
            skillBtn: document.getElementById('crew-skill-btn'),
            skillName: document.getElementById('crew-skill-name'),
            skillCooldown: document.getElementById('crew-skill-cooldown'),
            equipmentBtn: document.getElementById('crew-equipment-btn'),
            equipmentName: document.getElementById('crew-equipment-name'),
            waveAnnounce: document.getElementById('hud-wave-announce'),
            waveAnnounceNum: document.getElementById('wave-announce-num'),
            waveAnnounceSub: document.getElementById('wave-announce-sub'),
            alerts: document.getElementById('hud-alerts')
        };
    },

    bindEvents() {
        // Pause button
        this.elements.btnPause?.addEventListener('click', () => this.togglePause());

        // Speed button
        this.elements.btnSpeed?.addEventListener('click', () => this.cycleSpeed());

        // Keyboard shortcuts
        document.addEventListener('keydown', (e) => {
            if (e.code === 'Space') {
                e.preventDefault();
                this.togglePause();
            }
            // 크루 선택 단축키 (1-5)
            if (e.key >= '1' && e.key <= '5') {
                const index = parseInt(e.key) - 1;
                this.selectCrewByIndex(index);
            }
        });

        // Skill button
        this.elements.skillBtn?.addEventListener('click', () => {
            if (this.state.selectedCrew) {
                this.onSkillUse?.(this.state.selectedCrew);
            }
        });

        // Equipment button
        this.elements.equipmentBtn?.addEventListener('click', () => {
            if (this.state.selectedCrew) {
                this.onEquipmentUse?.(this.state.selectedCrew);
            }
        });
    },

    // ============================================
    // STATE UPDATES
    // ============================================

    /**
     * 웨이브 정보 업데이트
     */
    updateWave(current, total) {
        this.state.wave = { current, total };
        if (this.elements.waveCurrent) this.elements.waveCurrent.textContent = current;
        if (this.elements.waveTotal) this.elements.waveTotal.textContent = total;
    },

    /**
     * 적 수 업데이트
     */
    updateEnemyCount(count) {
        const el = this.elements.enemyCount;
        if (el) {
            el.querySelector('.enemy-value').textContent = count;
            el.classList.toggle('warning', count > 10);
        }
    },

    /**
     * 시설 상태 업데이트
     * @param {Array} facilities - [{id, name, health, maxHealth, isDestroyed}]
     */
    updateFacilities(facilities) {
        this.state.facilities = facilities;
        const container = this.elements.facilityStatus;
        if (!container) return;

        container.innerHTML = facilities.map(f => {
            const healthPercent = f.maxHealth > 0 ? (f.health / f.maxHealth) * 100 : 0;
            const status = f.isDestroyed ? 'destroyed' : (healthPercent < 30 ? 'danger' : 'normal');

            return `
                <div class="facility-icon ${status}" data-facility-id="${f.id}"
                     data-tooltip="${f.name}"
                     data-tooltip-title="시설 상태">
                    <div class="facility-health" style="height: ${healthPercent}%"></div>
                </div>
            `;
        }).join('');
    },

    /**
     * 크레딧 업데이트
     */
    updateCredits(amount, animate = true) {
        const diff = amount - this.state.credits;
        this.state.credits = amount;

        if (this.elements.credits) {
            if (animate && diff !== 0) {
                ElementAnimations.countUp(
                    this.elements.credits,
                    amount - diff,
                    amount,
                    { duration: 500, format: (v) => Math.floor(v) }
                );

                // 증가/감소 효과
                this.elements.credits.classList.remove('increase', 'decrease');
                this.elements.credits.classList.add(diff > 0 ? 'increase' : 'decrease');
                setTimeout(() => {
                    this.elements.credits.classList.remove('increase', 'decrease');
                }, 500);
            } else {
                this.elements.credits.textContent = amount;
            }
        }
    },

    /**
     * 크루 목록 업데이트
     * @param {Array} crews - [{id, name, classId, health, maxHealth, isDeployed}]
     */
    updateCrews(crews) {
        this.state.crews = crews;
        const container = this.elements.crewList;
        if (!container) return;

        container.innerHTML = crews.map((crew, index) => {
            const healthPercent = crew.maxHealth > 0 ? (crew.health / crew.maxHealth) * 100 : 0;
            const isSelected = this.state.selectedCrew?.id === crew.id;
            const healthStatus = healthPercent < 30 ? 'critical' : (healthPercent < 60 ? 'wounded' : 'healthy');

            return `
                <button class="hud-crew-btn ${crew.classId} ${isSelected ? 'selected' : ''} ${healthStatus}"
                        data-crew-id="${crew.id}"
                        data-index="${index}">
                    <span class="crew-key">${index + 1}</span>
                    <span class="crew-initial">${crew.name.charAt(0)}</span>
                    <div class="crew-health-ring" style="--health: ${healthPercent}%"></div>
                </button>
            `;
        }).join('');

        // 클릭 이벤트 바인딩
        container.querySelectorAll('.hud-crew-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                const crewId = btn.dataset.crewId;
                this.selectCrew(crewId);
            });
        });
    },

    /**
     * 크루 선택
     */
    selectCrew(crewId) {
        const crew = this.state.crews.find(c => c.id === crewId);
        this.state.selectedCrew = crew;

        // UI 업데이트
        this.elements.crewList?.querySelectorAll('.hud-crew-btn').forEach(btn => {
            btn.classList.toggle('selected', btn.dataset.crewId === crewId);
        });

        this.updateCrewPanel(crew);

        // 콜백 호출
        this.onCrewSelect?.(crew);
    },

    selectCrewByIndex(index) {
        if (index >= 0 && index < this.state.crews.length) {
            this.selectCrew(this.state.crews[index].id);
        }
    },

    /**
     * 크루 패널 업데이트
     */
    updateCrewPanel(crew) {
        if (!crew) {
            this.elements.crewPanel?.classList.add('hidden');
            return;
        }

        this.elements.crewPanel?.classList.remove('hidden');

        const classColors = {
            guardian: '#4a9eff',
            sentinel: '#f6ad55',
            ranger: '#68d391',
            engineer: '#fc8181',
            bionic: '#b794f4'
        };

        // 포트레이트
        if (this.elements.crewPortrait) {
            this.elements.crewPortrait.style.backgroundColor = classColors[crew.classId] || '#4a9eff';
            this.elements.crewPortrait.textContent = crew.name.charAt(0);
        }

        // 이름, 클래스
        if (this.elements.crewName) this.elements.crewName.textContent = crew.name;
        if (this.elements.crewClass) this.elements.crewClass.textContent = crew.className || crew.classId;

        // 체력
        const healthPercent = crew.maxHealth > 0 ? (crew.health / crew.maxHealth) * 100 : 0;
        if (this.elements.crewHealthFill) {
            this.elements.crewHealthFill.style.width = `${healthPercent}%`;
            this.elements.crewHealthFill.className = 'health-fill';
            if (healthPercent < 30) this.elements.crewHealthFill.classList.add('critical');
            else if (healthPercent < 60) this.elements.crewHealthFill.classList.add('wounded');
        }
        if (this.elements.crewHealthText) {
            this.elements.crewHealthText.textContent = `${crew.health}/${crew.maxHealth}`;
        }

        // 스킬 버튼
        if (crew.skill) {
            this.elements.skillBtn.disabled = !crew.skill.isReady;
            this.elements.skillName.textContent = crew.skill.name;
            this.elements.skillCooldown.textContent = crew.skill.isReady
                ? '준비'
                : `${Math.ceil(crew.skill.cooldownRemaining / 1000)}s`;
        }

        // 장비 버튼
        if (crew.equipment) {
            this.elements.equipmentBtn.disabled = !crew.equipment.canUse;
            this.elements.equipmentName.textContent = crew.equipment.name;
        } else {
            this.elements.equipmentBtn.disabled = true;
            this.elements.equipmentName.textContent = '장비 없음';
        }
    },

    // ============================================
    // CONTROLS
    // ============================================

    togglePause() {
        this.state.isPaused = !this.state.isPaused;
        this.elements.btnPause?.classList.toggle('active', this.state.isPaused);
        this.elements.btnPause.querySelector('.pause-icon').textContent =
            this.state.isPaused ? '>' : '||';

        this.onPauseToggle?.(this.state.isPaused);
    },

    cycleSpeed() {
        const speeds = [1, 1.5, 2];
        const currentIndex = speeds.indexOf(this.state.gameSpeed);
        this.state.gameSpeed = speeds[(currentIndex + 1) % speeds.length];

        this.elements.btnSpeed.querySelector('.speed-icon').textContent = `x${this.state.gameSpeed}`;

        this.onSpeedChange?.(this.state.gameSpeed);
    },

    // ============================================
    // ANNOUNCEMENTS & ALERTS
    // ============================================

    /**
     * 웨이브 시작 알림
     */
    announceWave(waveNum, subtitle = '적이 접근 중...') {
        if (!this.elements.waveAnnounce) return;

        this.elements.waveAnnounceNum.textContent = waveNum;
        this.elements.waveAnnounceSub.textContent = subtitle;

        this.elements.waveAnnounce.classList.add('active');

        setTimeout(() => {
            this.elements.waveAnnounce.classList.remove('active');
        }, 2000);
    },

    /**
     * 알림 메시지 표시
     */
    alert(message, type = 'info', duration = 3000) {
        if (!this.elements.alerts) return;

        const alert = document.createElement('div');
        alert.className = `hud-alert hud-alert-${type}`;
        alert.innerHTML = `
            <span class="alert-icon">${this.getAlertIcon(type)}</span>
            <span class="alert-message">${message}</span>
        `;

        this.elements.alerts.appendChild(alert);

        requestAnimationFrame(() => {
            alert.classList.add('visible');
        });

        setTimeout(() => {
            alert.classList.remove('visible');
            setTimeout(() => alert.remove(), 300);
        }, duration);
    },

    getAlertIcon(type) {
        const icons = {
            info: 'i',
            success: '!',
            warning: '!',
            danger: '!',
            facility: 'F',
            crew: 'C'
        };
        return icons[type] || 'i';
    },

    // 프리셋 알림
    alertFacilityDamage(facilityName) {
        this.alert(`${facilityName} 피해!`, 'danger', 2000);
    },

    alertFacilityDestroyed(facilityName) {
        this.alert(`${facilityName} 파괴됨!`, 'danger', 3000);
        ScreenEffects.damage('heavy');
    },

    alertCrewDown(crewName) {
        this.alert(`${crewName} 쓰러짐!`, 'danger', 3000);
    },

    alertWaveComplete() {
        this.alert('웨이브 클리어!', 'success', 2000);
    },

    // ============================================
    // VISIBILITY
    // ============================================

    show() {
        this.container?.classList.remove('hidden');
    },

    hide() {
        this.container?.classList.add('hidden');
    },

    // ============================================
    // CALLBACKS (외부에서 설정)
    // ============================================
    onCrewSelect: null,
    onSkillUse: null,
    onEquipmentUse: null,
    onPauseToggle: null,
    onSpeedChange: null
};

// ============================================
// MINI MAP (선택적 컴포넌트)
// ============================================
const MiniMap = {
    canvas: null,
    ctx: null,
    size: { width: 150, height: 100 },

    init(containerSelector) {
        const container = document.querySelector(containerSelector);
        if (!container) return;

        this.canvas = document.createElement('canvas');
        this.canvas.className = 'mini-map-canvas';
        this.canvas.width = this.size.width;
        this.canvas.height = this.size.height;
        container.appendChild(this.canvas);

        this.ctx = this.canvas.getContext('2d');

        console.log('MiniMap initialized');
    },

    /**
     * 미니맵 렌더링
     * @param {Object} data - {tiles, crews, enemies, facilities}
     */
    render(data) {
        if (!this.ctx) return;

        const { tiles, crews, enemies, facilities } = data;

        // 배경 클리어
        this.ctx.fillStyle = '#0a0a12';
        this.ctx.fillRect(0, 0, this.size.width, this.size.height);

        // 타일 렌더링 (간략화)
        if (tiles) {
            // 구현 예정
        }

        // 시설 표시
        if (facilities) {
            this.ctx.fillStyle = '#48bb78';
            facilities.forEach(f => {
                this.ctx.fillRect(f.x, f.y, 4, 4);
            });
        }

        // 크루 표시
        if (crews) {
            this.ctx.fillStyle = '#4a9eff';
            crews.forEach(c => {
                this.ctx.beginPath();
                this.ctx.arc(c.x, c.y, 3, 0, Math.PI * 2);
                this.ctx.fill();
            });
        }

        // 적 표시
        if (enemies) {
            this.ctx.fillStyle = '#fc8181';
            enemies.forEach(e => {
                this.ctx.fillRect(e.x - 1, e.y - 1, 2, 2);
            });
        }
    }
};

// 전역 노출
window.HUD = HUD;
window.MiniMap = MiniMap;
