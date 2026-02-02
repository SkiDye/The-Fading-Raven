/**
 * THE FADING RAVEN - Upgrade Controller
 * Handles crew upgrades and equipment management
 */

const UpgradeController = {
    elements: {},
    selectedCrew: null,

    // Upgrade costs
    costs: {
        heal: 20,
        skillUpgrade: 50,
        rankUp: 100,
        equipment: 75,
    },

    // Available equipment
    equipment: [
        { id: 'shockWave', name: '충격파 수류탄', desc: '범위 내 적에게 피해를 주고 밀쳐냄', cost: 75 },
        { id: 'fragGrenade', name: '파편 수류탄', desc: '폭발하여 범위 피해', cost: 60 },
        { id: 'smokeBomb', name: '연막탄', desc: '적의 시야를 차단', cost: 50 },
        { id: 'medkit', name: '의료 키트', desc: '전투 중 체력 회복', cost: 80 },
        { id: 'shieldGen', name: '보호막 생성기', desc: '일시적 피해 면역', cost: 100 },
    ],

    init() {
        this.checkActiveRun();
        this.cacheElements();
        this.bindEvents();
        this.renderCrewGrid();
        this.updateCreditsDisplay();
        console.log('UpgradeController initialized');
    },

    checkActiveRun() {
        if (!GameState.hasActiveRun()) {
            Utils.navigateTo('index');
            return;
        }
    },

    cacheElements() {
        this.elements = {
            crewGrid: document.getElementById('crew-grid'),
            detailPanel: document.getElementById('detail-panel'),
            creditsDisplay: document.getElementById('current-credits'),
            btnContinue: document.getElementById('btn-done'),

            // Detail panel elements
            detailName: document.getElementById('detail-name'),
            detailClass: document.getElementById('detail-class'),
            detailRank: document.getElementById('detail-rank'),
            detailPortrait: document.getElementById('detail-portrait'),
            detailStats: document.querySelector('.detail-stats'),
            upgradeOptions: document.querySelector('.upgrade-options'),
            btnCloseDetail: document.getElementById('btn-close-detail'),
        };
    },

    bindEvents() {
        // Continue button
        this.elements.btnContinue?.addEventListener('click', () => {
            Utils.navigateTo('sector');
        });

        // Back button
        this.elements.btnBack?.addEventListener('click', () => {
            Utils.navigateTo('sector');
        });

        // Close detail panel
        this.elements.btnCloseDetail?.addEventListener('click', () => {
            this.closeDetailPanel();
        });

        // Keyboard
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                this.closeDetailPanel();
            }
        });
    },

    renderCrewGrid() {
        const grid = this.elements.crewGrid;
        if (!grid) return;

        grid.innerHTML = '';

        const crews = GameState.currentRun.crews;

        crews.forEach(crew => {
            if (!crew.isAlive) return;

            const classData = GameState.getClassData(crew.class);
            const card = document.createElement('div');
            card.className = `upgrade-card ${crew.class}`;
            card.dataset.crewId = crew.id;

            const healthPct = (crew.squadSize / crew.maxSquadSize) * 100;

            card.innerHTML = `
                <div class="card-header">
                    <div class="card-portrait ${crew.class}">${crew.name[0]}</div>
                    <div class="card-title">
                        <div class="card-name">${crew.name}</div>
                        <div class="card-class">${classData?.name || crew.class}</div>
                    </div>
                    <div class="card-rank ${crew.rank}">${this.getRankName(crew.rank)}</div>
                </div>
                <div class="card-body">
                    <div class="card-stats">
                        <div class="card-stat">
                            <span class="card-stat-value">${crew.squadSize}/${crew.maxSquadSize}</span>
                            <span class="card-stat-label">병력</span>
                        </div>
                        <div class="card-stat">
                            <span class="card-stat-value">${crew.skillLevel}</span>
                            <span class="card-stat-label">스킬 레벨</span>
                        </div>
                        <div class="card-stat">
                            <span class="card-stat-value">${crew.kills}</span>
                            <span class="card-stat-label">처치</span>
                        </div>
                    </div>
                    <div class="card-equipment ${crew.equipment ? 'has-item' : ''}">
                        ${crew.equipment ? this.getEquipmentName(crew.equipment) : '장비 없음'}
                    </div>
                </div>
                <div class="card-health-bar">
                    <div class="health-fill" style="width: ${healthPct}%"></div>
                </div>
            `;

            card.addEventListener('click', () => this.selectCrew(crew.id));
            grid.appendChild(card);
        });
    },

    selectCrew(crewId) {
        this.selectedCrew = GameState.getCrewById(crewId);
        if (!this.selectedCrew) return;

        // Update selection state
        document.querySelectorAll('.upgrade-card').forEach(card => {
            card.classList.toggle('selected', card.dataset.crewId === crewId);
        });

        this.showDetailPanel();
    },

    showDetailPanel() {
        if (!this.selectedCrew) return;

        const crew = this.selectedCrew;
        const classData = GameState.getClassData(crew.class);

        // Update header
        if (this.elements.detailName) {
            this.elements.detailName.textContent = crew.name;
        }
        if (this.elements.detailClass) {
            this.elements.detailClass.textContent = classData?.name || crew.class;
        }
        if (this.elements.detailRank) {
            this.elements.detailRank.textContent = this.getRankName(crew.rank);
            this.elements.detailRank.className = `crew-rank ${crew.rank}`;
        }
        if (this.elements.detailPortrait) {
            this.elements.detailPortrait.className = `crew-portrait large ${crew.class}`;
            this.elements.detailPortrait.innerHTML = `<span class="portrait-letter">${crew.name[0]}</span>`;
        }

        // Update stats
        this.renderDetailStats();

        // Update upgrade options
        this.renderUpgradeOptions();

        // Show panel
        this.elements.detailPanel?.classList.add('active');
    },

    closeDetailPanel() {
        this.elements.detailPanel?.classList.remove('active');
        this.selectedCrew = null;

        document.querySelectorAll('.upgrade-card').forEach(card => {
            card.classList.remove('selected');
        });
    },

    renderDetailStats() {
        const container = this.elements.detailStats;
        if (!container || !this.selectedCrew) return;

        const crew = this.selectedCrew;
        const classData = GameState.getClassData(crew.class);

        const stats = [
            { label: '병력', value: `${crew.squadSize}/${crew.maxSquadSize}` },
            { label: '스킬 레벨', value: `${crew.skillLevel}/3` },
            { label: '특성', value: this.getTraitName(crew.trait) },
            { label: '장비', value: crew.equipment ? this.getEquipmentName(crew.equipment) : '없음' },
            { label: '전투 참여', value: crew.battlesParticipated },
            { label: '총 처치', value: crew.kills },
        ];

        container.innerHTML = `
            <h3>상세 정보</h3>
            ${stats.map(stat => `
                <div class="stat-row">
                    <span>${stat.label}</span>
                    <span>${stat.value}</span>
                </div>
            `).join('')}
        `;
    },

    renderUpgradeOptions() {
        const container = this.elements.upgradeOptions;
        if (!container || !this.selectedCrew) return;

        const crew = this.selectedCrew;
        const credits = GameState.currentRun.credits;

        const options = [];

        // Heal option (if wounded)
        if (crew.squadSize < crew.maxSquadSize) {
            const healCost = this.costs.heal;
            const canAfford = credits >= healCost;
            options.push({
                id: 'heal',
                name: '병력 회복',
                desc: `+2 병력 (최대 ${crew.maxSquadSize})`,
                cost: healCost,
                disabled: !canAfford,
            });
        }

        // Skill upgrade (if not maxed)
        if (crew.skillLevel < 3) {
            const cost = this.costs.skillUpgrade * (crew.skillLevel + 1);
            const traitDiscount = crew.trait === 'skillful' ? 0.5 : 1;
            const finalCost = Math.floor(cost * traitDiscount);
            const canAfford = credits >= finalCost;
            options.push({
                id: 'skill',
                name: '스킬 강화',
                desc: `스킬 레벨 ${crew.skillLevel} → ${crew.skillLevel + 1}`,
                cost: finalCost,
                disabled: !canAfford,
            });
        }

        // Rank up (if not elite)
        if (crew.rank !== 'elite') {
            const nextRank = crew.rank === 'standard' ? 'veteran' : 'elite';
            const cost = this.costs.rankUp * (crew.rank === 'veteran' ? 2 : 1);
            const canAfford = credits >= cost;
            options.push({
                id: 'rank',
                name: '승급',
                desc: `${this.getRankName(crew.rank)} → ${this.getRankName(nextRank)}`,
                cost: cost,
                disabled: !canAfford,
            });
        }

        // Equipment (if no equipment)
        if (!crew.equipment) {
            options.push({
                id: 'equipment',
                name: '장비 구매',
                desc: '새 장비 장착',
                cost: this.costs.equipment,
                disabled: credits < this.costs.equipment,
                isEquipment: true,
            });
        }

        container.innerHTML = `
            <h3>업그레이드</h3>
            ${options.length === 0 ? '<p class="no-upgrades">사용 가능한 업그레이드가 없습니다.</p>' : ''}
            ${options.map(opt => `
                <div class="upgrade-option ${opt.disabled ? 'disabled' : ''}" data-upgrade="${opt.id}">
                    <div class="option-info">
                        <div class="option-name">${opt.name}</div>
                        <div class="option-desc">${opt.desc}</div>
                    </div>
                    <button class="btn-upgrade" ${opt.disabled ? 'disabled' : ''}>
                        <span class="cost">${opt.cost}</span>
                    </button>
                </div>
            `).join('')}
        `;

        // Bind upgrade buttons
        container.querySelectorAll('.upgrade-option:not(.disabled)').forEach(option => {
            const btn = option.querySelector('.btn-upgrade');
            btn?.addEventListener('click', () => this.performUpgrade(option.dataset.upgrade));
        });
    },

    performUpgrade(upgradeId) {
        if (!this.selectedCrew) return;

        const crew = this.selectedCrew;
        let cost = 0;

        switch (upgradeId) {
            case 'heal':
                cost = this.costs.heal;
                if (GameState.spendCredits(cost)) {
                    crew.squadSize = Math.min(crew.squadSize + 2, crew.maxSquadSize);
                    crew.health = crew.squadSize;
                }
                break;

            case 'skill':
                const skillCost = this.costs.skillUpgrade * (crew.skillLevel + 1);
                const traitDiscount = crew.trait === 'skillful' ? 0.5 : 1;
                cost = Math.floor(skillCost * traitDiscount);
                if (GameState.spendCredits(cost)) {
                    crew.skillLevel++;
                }
                break;

            case 'rank':
                cost = this.costs.rankUp * (crew.rank === 'veteran' ? 2 : 1);
                if (GameState.spendCredits(cost)) {
                    crew.rank = crew.rank === 'standard' ? 'veteran' : 'elite';
                    // Rank up bonus: +1 max squad size
                    crew.maxSquadSize++;
                }
                break;

            case 'equipment':
                this.showEquipmentSelection();
                return;
        }

        GameState.saveCurrentRun();
        this.updateCreditsDisplay();
        this.renderCrewGrid();
        this.showDetailPanel(); // Refresh detail panel
    },

    showEquipmentSelection() {
        const availableEquipment = this.equipment.filter(e =>
            GameState.progress.unlockedEquipment.includes(e.id)
        );

        const credits = GameState.currentRun.credits;

        const html = availableEquipment.map(eq => `
            <div class="equipment-option ${credits < eq.cost ? 'disabled' : ''}" data-equipment="${eq.id}">
                <div class="equipment-info">
                    <div class="equipment-name">${eq.name}</div>
                    <div class="equipment-desc">${eq.desc}</div>
                </div>
                <button class="btn-buy" ${credits < eq.cost ? 'disabled' : ''}>
                    <span class="cost">${eq.cost}</span>
                </button>
            </div>
        `).join('');

        // Show in upgrade options area
        this.elements.upgradeOptions.innerHTML = `
            <h3>장비 선택</h3>
            ${html}
            <button class="btn btn-secondary btn-back-to-upgrades">뒤로</button>
        `;

        // Bind equipment buttons
        this.elements.upgradeOptions.querySelectorAll('.equipment-option:not(.disabled)').forEach(option => {
            option.querySelector('.btn-buy')?.addEventListener('click', () => {
                this.buyEquipment(option.dataset.equipment);
            });
        });

        // Back button
        this.elements.upgradeOptions.querySelector('.btn-back-to-upgrades')?.addEventListener('click', () => {
            this.renderUpgradeOptions();
        });
    },

    buyEquipment(equipmentId) {
        const equipment = this.equipment.find(e => e.id === equipmentId);
        if (!equipment || !this.selectedCrew) return;

        if (GameState.spendCredits(equipment.cost)) {
            this.selectedCrew.equipment = equipmentId;
            GameState.saveCurrentRun();
            this.updateCreditsDisplay();
            this.renderCrewGrid();
            this.renderUpgradeOptions();
        }
    },

    updateCreditsDisplay() {
        if (this.elements.creditsDisplay) {
            this.elements.creditsDisplay.textContent = Utils.formatNumber(GameState.currentRun.credits);
        }
    },

    getRankName(rank) {
        const names = {
            standard: '일반',
            veteran: '베테랑',
            elite: '정예',
        };
        return names[rank] || rank;
    },

    getTraitName(trait) {
        const names = {
            energetic: '활력 넘침',
            swiftMovement: '빠른 이동',
            popular: '인기 많음',
            quickRecovery: '빠른 회복',
            sharpEdge: '날카로운 공격',
            heavyImpact: '강력한 충격',
            skillful: '숙련됨',
            collector: '수집가',
        };
        return names[trait] || trait;
    },

    getEquipmentName(equipmentId) {
        const equipment = this.equipment.find(e => e.id === equipmentId);
        return equipment ? equipment.name : equipmentId;
    }
};

// Initialize on DOM ready
document.addEventListener('DOMContentLoaded', () => {
    UpgradeController.init();
});
