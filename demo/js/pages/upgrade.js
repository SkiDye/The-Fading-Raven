/**
 * THE FADING RAVEN - Upgrade Controller
 * Handles crew upgrades and equipment management
 */

const UpgradeController = {
    elements: {},
    selectedCrew: null,

    // Upgrade costs (can be overridden by BalanceData)
    costs: {
        heal: 20,
        skillUpgrade: 50,
        rankUp: 100,
        equipment: 75,
    },

    // Fallback equipment list (used if EquipmentData is not available)
    fallbackEquipment: [
        { id: 'shockWave', name: '충격파 수류탄', desc: '범위 내 적에게 피해를 주고 밀쳐냄', cost: 75 },
        { id: 'fragGrenade', name: '파편 수류탄', desc: '폭발하여 범위 피해', cost: 60 },
        { id: 'smokeBomb', name: '연막탄', desc: '적의 시야를 차단', cost: 50 },
        { id: 'medkit', name: '의료 키트', desc: '전투 중 체력 회복', cost: 80 },
        { id: 'shieldGen', name: '보호막 생성기', desc: '일시적 피해 면역', cost: 100 },
    ],

    // Get available equipment (from EquipmentData or fallback)
    getAvailableEquipment() {
        if (typeof EquipmentData !== 'undefined') {
            const all = EquipmentData.getAll();
            return Object.entries(all).map(([id, data]) => ({
                id,
                name: data.name,
                desc: data.description,
                cost: data.cost || 75,
                rarity: data.rarity || 'common',
            }));
        }
        return this.fallbackEquipment;
    },

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

            // Use CrewData if available
            const classData = typeof CrewData !== 'undefined'
                ? CrewData.getClass(crew.class)
                : GameState.getClassData(crew.class);
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
        const classData = typeof CrewData !== 'undefined'
            ? CrewData.getClass(crew.class)
            : GameState.getClassData(crew.class);

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

        // Use CrewData if available for class info
        let classData;
        if (typeof CrewData !== 'undefined') {
            classData = CrewData.getClass(crew.class);
        } else {
            classData = GameState.getClassData(crew.class);
        }

        const traitName = this.getTraitName(crew.trait);
        const traitDesc = this.getTraitDescription(crew.trait);

        const stats = [
            { label: '병력', value: `${crew.squadSize}/${crew.maxSquadSize}` },
            { label: '스킬 레벨', value: `${crew.skillLevel}/3` },
            { label: '특성', value: traitName, desc: traitDesc },
            { label: '장비', value: crew.equipment ? this.getEquipmentName(crew.equipment) : '없음' },
            { label: '전투 참여', value: crew.battlesParticipated },
            { label: '총 처치', value: crew.kills },
        ];

        container.innerHTML = `
            <h3>상세 정보</h3>
            ${stats.map(stat => `
                <div class="stat-row">
                    <span>${stat.label}</span>
                    <span title="${stat.desc || ''}">${stat.value}</span>
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

        // Equipment unequip (if has equipment) - M-004
        let equipmentSection = '';
        if (crew.equipment) {
            const equipName = this.getEquipmentName(crew.equipment);
            equipmentSection = `
                <div class="equipment-section">
                    <h4>장착 장비</h4>
                    <div class="equipped-item">
                        <span class="item-name">${equipName}</span>
                        <button class="btn-unequip" data-action="unequip">해제</button>
                    </div>
                </div>
            `;
        }

        container.innerHTML = `
            <h3>업그레이드</h3>
            ${options.length === 0 && !crew.equipment ? '<p class="no-upgrades">사용 가능한 업그레이드가 없습니다.</p>' : ''}
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
            ${equipmentSection}
        `;

        // Bind upgrade buttons
        container.querySelectorAll('.upgrade-option:not(.disabled)').forEach(option => {
            const btn = option.querySelector('.btn-upgrade');
            btn?.addEventListener('click', () => this.performUpgrade(option.dataset.upgrade));
        });

        // Bind unequip button - M-004
        const unequipBtn = container.querySelector('.btn-unequip');
        unequipBtn?.addEventListener('click', () => this.unequipItem());
    },

    // M-004: 장비 해제 (확인 절차 포함)
    async unequipItem() {
        if (!this.selectedCrew || !this.selectedCrew.equipment) return;

        const crew = this.selectedCrew;
        const equipName = this.getEquipmentName(crew.equipment);
        const confirmMessage = `${crew.name}의 "${equipName}"을(를) 해제합니다.\n` +
            `해제된 장비는 소멸됩니다. 계속하시겠습니까?`;

        // Use ModalManager if available
        if (typeof ModalManager !== 'undefined') {
            const confirmed = await new Promise(resolve => {
                ModalManager.confirm(
                    confirmMessage,
                    () => resolve(true),
                    () => resolve(false)
                );
            });
            if (!confirmed) return;
        }

        crew.equipment = null;
        GameState.saveCurrentRun();
        this.renderCrewGrid();
        this.showDetailPanel();

        // Show toast notification if available
        if (typeof Toast !== 'undefined') {
            Toast.info(`${equipName} 해제됨`);
        }
    },

    async performUpgrade(upgradeId) {
        if (!this.selectedCrew) return;

        const crew = this.selectedCrew;
        let cost = 0;
        let confirmMessage = '';
        let upgradeAction = null;

        switch (upgradeId) {
            case 'heal':
                cost = this.costs.heal;
                const healAmount = Math.min(2, crew.maxSquadSize - crew.squadSize);
                confirmMessage = `${crew.name}의 병력을 ${healAmount}만큼 회복합니다.\n비용: ${cost} 크레딧`;
                upgradeAction = () => {
                    crew.squadSize = Math.min(crew.squadSize + 2, crew.maxSquadSize);
                    crew.health = crew.squadSize;
                };
                break;

            case 'skill':
                const skillCost = this.costs.skillUpgrade * (crew.skillLevel + 1);
                const traitDiscount = crew.trait === 'skillful' ? 0.5 : 1;
                cost = Math.floor(skillCost * traitDiscount);
                const skillPreview = this.getSkillPreview(crew);
                confirmMessage = `${crew.name}의 스킬을 강화합니다.\n` +
                    `레벨 ${crew.skillLevel} → ${crew.skillLevel + 1}\n` +
                    (skillPreview ? `효과: ${skillPreview}\n` : '') +
                    `비용: ${cost} 크레딧`;
                upgradeAction = () => {
                    crew.skillLevel++;
                };
                break;

            case 'rank':
                cost = this.costs.rankUp * (crew.rank === 'veteran' ? 2 : 1);
                const nextRank = crew.rank === 'standard' ? 'veteran' : 'elite';
                confirmMessage = `${crew.name}을(를) 승급합니다.\n` +
                    `${this.getRankName(crew.rank)} → ${this.getRankName(nextRank)}\n` +
                    `보너스: 최대 병력 +1\n` +
                    `비용: ${cost} 크레딧`;
                upgradeAction = () => {
                    crew.rank = crew.rank === 'standard' ? 'veteran' : 'elite';
                    crew.maxSquadSize++;
                };
                break;

            case 'equipment':
                this.showEquipmentSelection();
                return;
        }

        // Use ModalManager if available, otherwise proceed directly
        if (typeof ModalManager !== 'undefined') {
            const confirmed = await new Promise(resolve => {
                ModalManager.confirm(
                    confirmMessage,
                    () => resolve(true),
                    () => resolve(false)
                );
            });
            if (!confirmed) return;
        }

        if (GameState.spendCredits(cost) && upgradeAction) {
            upgradeAction();
        }

        GameState.saveCurrentRun();
        this.updateCreditsDisplay();
        this.renderCrewGrid();
        this.showDetailPanel();
    },

    // M-005: 스킬 업그레이드 미리보기
    getSkillPreview(crew) {
        if (typeof CrewData === 'undefined') return null;

        const classData = CrewData.getClass(crew.class);
        if (!classData || !classData.skill || !classData.skill.levels) return null;

        const currentLevel = classData.skill.levels[crew.skillLevel];
        const nextLevel = classData.skill.levels[crew.skillLevel + 1];

        if (!nextLevel) return null;

        return nextLevel.description || nextLevel.effect || null;
    },

    showEquipmentSelection() {
        const allEquipment = this.getAvailableEquipment();

        // Filter by unlocked equipment (use MetaProgress if available, otherwise GameState)
        let availableEquipment;
        if (typeof MetaProgress !== 'undefined') {
            availableEquipment = allEquipment.filter(e => MetaProgress.isEquipmentUnlocked(e.id));
        } else {
            availableEquipment = allEquipment.filter(e =>
                GameState.progress.unlockedEquipment.includes(e.id)
            );
        }

        const credits = GameState.currentRun.credits;

        // Sort by rarity and cost
        const rarityOrder = { common: 0, uncommon: 1, rare: 2, epic: 3 };
        availableEquipment.sort((a, b) => {
            const rarityDiff = (rarityOrder[a.rarity] || 0) - (rarityOrder[b.rarity] || 0);
            return rarityDiff !== 0 ? rarityDiff : a.cost - b.cost;
        });

        let html;
        if (availableEquipment.length === 0) {
            html = '<p class="no-equipment">해금된 장비가 없습니다.</p>';
        } else {
            html = availableEquipment.map(eq => {
                const rarityClass = eq.rarity ? `rarity-${eq.rarity}` : '';
                return `
                    <div class="equipment-option ${credits < eq.cost ? 'disabled' : ''} ${rarityClass}" data-equipment="${eq.id}">
                        <div class="equipment-info">
                            <div class="equipment-name">${eq.name}</div>
                            <div class="equipment-desc">${eq.desc}</div>
                        </div>
                        <button class="btn-buy" ${credits < eq.cost ? 'disabled' : ''}>
                            <span class="cost">${eq.cost}</span>
                        </button>
                    </div>
                `;
            }).join('');
        }

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

    async buyEquipment(equipmentId) {
        const allEquipment = this.getAvailableEquipment();
        const equipment = allEquipment.find(e => e.id === equipmentId);
        if (!equipment || !this.selectedCrew) return;

        const crew = this.selectedCrew;
        const confirmMessage = `${crew.name}에게 "${equipment.name}"을(를) 장착합니다.\n` +
            `효과: ${equipment.desc}\n` +
            `비용: ${equipment.cost} 크레딧`;

        // Use ModalManager if available
        if (typeof ModalManager !== 'undefined') {
            const confirmed = await new Promise(resolve => {
                ModalManager.confirm(
                    confirmMessage,
                    () => resolve(true),
                    () => resolve(false)
                );
            });
            if (!confirmed) return;
        }

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
        // Use TraitData if available
        if (typeof TraitData !== 'undefined') {
            const traitData = TraitData.get(trait);
            if (traitData) return traitData.name;
        }

        // Fallback names
        const names = {
            energetic: '활력 넘침',
            swiftMovement: '빠른 이동',
            popular: '인기 많음',
            quickRecovery: '빠른 회복',
            sharpEdge: '날카로운 공격',
            heavyImpact: '강력한 충격',
            titanFrame: '티탄 프레임',
            reinforcedArmor: '강화 장갑',
            steadyStance: '안정된 자세',
            fearless: '무모함',
            techSavvy: '기술 전문가',
            skillful: '숙련됨',
            collector: '수집가',
            heavyLoad: '중장비',
            salvager: '회수 전문가',
        };
        return names[trait] || trait;
    },

    getEquipmentName(equipmentId) {
        // Use EquipmentData if available
        if (typeof EquipmentData !== 'undefined') {
            const equipData = EquipmentData.get(equipmentId);
            if (equipData) return equipData.name;
        }

        // Fallback to local list
        const allEquipment = this.getAvailableEquipment();
        const equipment = allEquipment.find(e => e.id === equipmentId);
        return equipment ? equipment.name : equipmentId;
    },

    getTraitDescription(trait) {
        // Use TraitData if available
        if (typeof TraitData !== 'undefined') {
            const traitData = TraitData.get(trait);
            if (traitData) return traitData.description;
        }
        return '';
    }
};

// Initialize on DOM ready
document.addEventListener('DOMContentLoaded', () => {
    UpgradeController.init();
});
