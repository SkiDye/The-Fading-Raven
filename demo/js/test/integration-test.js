/**
 * THE FADING RAVEN - Integration Test Suite v2.0
 * 브라우저 콘솔에서 실행: IntegrationTest.runAll()
 *
 * 전체 세션 시스템 테스트 포함:
 * - Session 1: Data modules
 * - Session 2: Combat system
 * - Session 3: Enemy/AI system
 * - Session 4: Campaign system
 * - Session 5: UI system
 */

const IntegrationTest = {
    results: [],
    verbose: true,
    currentCategory: '',

    // ==========================================
    // Main Test Runner
    // ==========================================

    async runAll() {
        console.log('%c╔════════════════════════════════════════════╗', 'color: #4a9eff');
        console.log('%c║   THE FADING RAVEN - 통합 테스트 v2.0      ║', 'color: #4a9eff; font-weight: bold');
        console.log('%c╚════════════════════════════════════════════╝', 'color: #4a9eff');

        this.results = [];
        const startTime = performance.now();

        // Session 1: Data Modules
        this.category('Session 1: Data Modules');
        this.testDataModulesExist();
        this.testCrewData();
        this.testEquipmentData();
        this.testTraitData();
        this.testEnemyData();
        this.testFacilityData();
        this.testBalanceData();

        // Session 1: GameState
        this.category('Session 1: GameState');
        this.testGameStateBasic();
        this.testCrewCreation();
        this.testEconomyFunctions();
        this.testUtilsModuleValidation();
        this.testMultiTabDetection();

        // Session 2: Combat System
        this.category('Session 2: Combat System');
        this.testSession2();

        // Session 3: Enemy/AI System
        this.category('Session 3: Enemy/AI System');
        this.testSession3();

        // Session 4: Campaign System
        this.category('Session 4: Campaign System');
        this.testSession4();

        // Session 5: UI System
        this.category('Session 5: UI System');
        this.testSession5();

        // Integration Tests
        this.category('Integration Tests');
        this.testFullGameFlow();
        this.testDataIntegration();

        const endTime = performance.now();
        this.printResults();
        console.log(`\n⏱️ 테스트 완료: ${(endTime - startTime).toFixed(2)}ms`);

        return this.results.every(r => r.passed);
    },

    category(name) {
        this.currentCategory = name;
        this.log(`\n%c📦 ${name}`, 'font-weight: bold; color: #f6ad55');
    },

    // ==========================================
    // Session 1: Data Module Tests
    // ==========================================

    testDataModulesExist() {
        this.test('CrewData 로드됨', () => typeof CrewData !== 'undefined');
        this.test('EquipmentData 로드됨', () => typeof EquipmentData !== 'undefined');
        this.test('TraitData 로드됨', () => typeof TraitData !== 'undefined');
        this.test('EnemyData 로드됨', () => typeof EnemyData !== 'undefined');
        this.test('FacilityData 로드됨', () => typeof FacilityData !== 'undefined');
        this.test('BalanceData 로드됨', () => typeof BalanceData !== 'undefined');
        this.test('GameState 로드됨', () => typeof GameState !== 'undefined');
    },

    testCrewData() {
        if (typeof CrewData === 'undefined') return;

        const classes = CrewData.getAllClasses();
        this.test('5개 클래스 존재', () => classes.length === 5);

        const expectedClasses = ['guardian', 'sentinel', 'ranger', 'engineer', 'bionic'];
        expectedClasses.forEach(classId => {
            const data = CrewData.getClass(classId);
            this.test(`${classId} 클래스 정의됨`, () => data !== null);
            this.test(`${classId} 분대크기 > 0`, () => data?.baseSquadSize > 0);
            this.test(`${classId} 스킬 존재`, () => data?.skill !== undefined);
            this.test(`${classId} 스킬 3레벨`, () => data?.skill?.levels?.length === 3);
        });
    },

    testEquipmentData() {
        if (typeof EquipmentData === 'undefined') return;

        const items = EquipmentData.getAll();
        this.test('10개 장비 존재', () => items.length === 10);

        const expectedIds = [
            'commandModule', 'shockWave', 'fragGrenade', 'proximityMine',
            'rallyHorn', 'reviveKit', 'stimPack', 'salvageCore',
            'shieldGenerator', 'hackingDevice'
        ];

        expectedIds.forEach(id => {
            const item = EquipmentData.get(id);
            this.test(`${id} 장비 존재`, () => item !== null);
        });

        this.test('패시브 장비 존재', () => EquipmentData.getByType('passive').length > 0);
        this.test('액티브 쿨다운 장비 존재', () => EquipmentData.getByType('active_cooldown').length > 0);
        this.test('액티브 횟수 장비 존재', () => EquipmentData.getByType('active_charges').length > 0);
    },

    testTraitData() {
        if (typeof TraitData === 'undefined') return;

        const traits = TraitData.getAll();
        this.test('15개 특성 존재', () => traits.length === 15);

        this.test('전투 특성 6개', () => TraitData.getByCategory('combat').length === 6);
        this.test('유틸리티 특성 5개', () => TraitData.getByCategory('utility').length === 5);
        this.test('경제 특성 4개', () => TraitData.getByCategory('economy').length === 4);

        const energetic = TraitData.get('energetic');
        this.test('energetic 쿨다운 감소', () => energetic?.effect?.skillCooldownMultiplier < 1);

        const popular = TraitData.get('popular');
        this.test('popular 분대크기 +1', () => popular?.effect?.squadSizeBonus === 1);
    },

    testEnemyData() {
        if (typeof EnemyData === 'undefined') return;

        const enemies = EnemyData.getAll();
        this.test('13+ 적 유형 존재', () => enemies.length >= 13);

        this.test('Tier 1 적 3종', () => EnemyData.getByTier(1).length >= 3);
        this.test('Tier 2 적 4종', () => EnemyData.getByTier(2).length >= 4);
        this.test('Tier 3 적 4종', () => EnemyData.getByTier(3).length >= 4);
        this.test('보스 2종', () => EnemyData.getBosses().length >= 2);

        const rusher = EnemyData.get('rusher');
        this.test('rusher 체력 > 0', () => rusher?.stats?.health > 0);
        this.test('rusher 비용 = 1', () => rusher?.cost === 1);
    },

    testFacilityData() {
        if (typeof FacilityData === 'undefined') return;

        const facilities = FacilityData.getAll();
        this.test('7+ 시설 존재', () => facilities.length >= 7);

        this.test('소형 거주모듈 크레딧 = 2', () => FacilityData.getCredits('residentialSmall') === 2);
        this.test('중형 거주모듈 크레딧 = 3', () => FacilityData.getCredits('residentialMedium') === 3);
        this.test('대형 거주모듈 크레딧 = 5', () => FacilityData.getCredits('residentialLarge') === 5);
    },

    testBalanceData() {
        if (typeof BalanceData === 'undefined') return;

        const difficulties = ['normal', 'hard', 'veryhard', 'nightmare'];
        difficulties.forEach(diff => {
            const config = BalanceData.difficulty[diff];
            this.test(`${diff} 난이도 정의`, () => config !== undefined);
        });

        this.test('hard > normal 적 수', () => {
            return BalanceData.difficulty.hard.enemyCountMultiplier >
                   BalanceData.difficulty.normal.enemyCountMultiplier;
        });

        this.test('힐 비용 정의', () => BalanceData.economy.healCost > 0);

        const waveConfig = BalanceData.getWaveConfig(5, 'normal');
        this.test('웨이브 예산 > 0', () => waveConfig.budget > 0);
    },

    // ==========================================
    // GameState Tests
    // ==========================================

    testGameStateBasic() {
        if (typeof GameState === 'undefined') return;

        const backup = GameState.currentRun;

        const run = GameState.startNewRun(12345, 'normal');
        this.test('런 생성됨', () => run !== null);
        this.test('시드 저장됨', () => run.seed === 12345);
        this.test('난이도 저장됨', () => run.difficulty === 'normal');
        this.test('크루 3명', () => run.crews.length === 3);

        GameState.addCredits(100);
        this.test('크레딧 추가', () => GameState.currentRun.credits === 100);

        const spent = GameState.spendCredits(30);
        this.test('크레딧 사용 성공', () => spent === true);
        this.test('크레딧 차감됨', () => GameState.currentRun.credits === 70);

        GameState.clearCurrentRun();
        GameState.currentRun = backup;
        if (backup) GameState.saveCurrentRun();
    },

    testCrewCreation() {
        if (typeof GameState === 'undefined') return;

        const crew = GameState.createCrew('TestCommander', 'guardian');

        this.test('크루 ID 존재', () => crew.id !== undefined);
        this.test('크루 이름', () => crew.name === 'TestCommander');
        this.test('크루 클래스', () => crew.class === 'guardian');
        this.test('분대 크기 8', () => crew.squadSize === 8);
        this.test('특성 존재', () => crew.trait !== null);

        const engineer = GameState.createCrew('Engineer', 'engineer');
        this.test('엔지니어 분대크기 6', () => engineer.squadSize === 6);

        const bionic = GameState.createCrew('Bionic', 'bionic');
        this.test('바이오닉 분대크기 5', () => bionic.squadSize === 5);
    },

    testEconomyFunctions() {
        if (typeof GameState === 'undefined') return;

        const normalCrew = { skillLevel: 0, trait: null };
        const skilledCrew = { skillLevel: 0, trait: 'skillful' };

        const cost1 = GameState.getSkillUpgradeCost(normalCrew);
        const cost1Skilled = GameState.getSkillUpgradeCost(skilledCrew);

        this.test('스킬 Lv1 비용', () => cost1 === 7);
        this.test('숙련 특성 할인', () => cost1Skilled < cost1);
    },

    // ==========================================
    // Session 1: Utils Module Validation (L-006)
    // ==========================================

    testUtilsModuleValidation() {
        if (typeof Utils === 'undefined') return;

        // Test validateRequiredModules
        this.test('Utils.validateRequiredModules 존재', () => typeof Utils.validateRequiredModules === 'function');

        const validResult = Utils.validateRequiredModules(['Utils', 'GameState'], { silent: true });
        this.test('모듈 검증 성공', () => validResult.valid === true);
        this.test('누락 모듈 없음', () => validResult.missing.length === 0);

        const invalidResult = Utils.validateRequiredModules(['NonExistentModule'], { silent: true });
        this.test('없는 모듈 검증 실패', () => invalidResult.valid === false);
        this.test('누락 모듈 포함', () => invalidResult.missing.includes('NonExistentModule'));

        // Test getCoreDataModules
        this.test('Utils.getCoreDataModules 존재', () => typeof Utils.getCoreDataModules === 'function');
        const dataModules = Utils.getCoreDataModules();
        this.test('핵심 데이터 모듈 6개', () => dataModules.length === 6);
        this.test('CrewData 포함', () => dataModules.includes('CrewData'));
        this.test('BalanceData 포함', () => dataModules.includes('BalanceData'));

        // Test getCoreSystemModules
        this.test('Utils.getCoreSystemModules 존재', () => typeof Utils.getCoreSystemModules === 'function');
        const systemModules = Utils.getCoreSystemModules();
        this.test('핵심 시스템 모듈 3개', () => systemModules.length === 3);
        this.test('GameState 포함', () => systemModules.includes('GameState'));

        // Test waitForModules
        this.test('Utils.waitForModules 존재', () => typeof Utils.waitForModules === 'function');
    },

    // ==========================================
    // Session 1: Multi-Tab Detection (L-007)
    // ==========================================

    testMultiTabDetection() {
        if (typeof GameState === 'undefined') return;

        // Test tab ID exists
        this.test('GameState.tabId 존재', () => GameState.tabId !== null && GameState.tabId !== undefined);
        this.test('GameState.isActiveTab 존재', () => typeof GameState.isActiveTab === 'boolean');

        // Test multi-tab functions exist
        this.test('initMultiTabDetection 존재', () => typeof GameState.initMultiTabDetection === 'function');
        this.test('registerTab 존재', () => typeof GameState.registerTab === 'function');
        this.test('unregisterTab 존재', () => typeof GameState.unregisterTab === 'function');
        this.test('handleStorageChange 존재', () => typeof GameState.handleStorageChange === 'function');
        this.test('isCurrentlyActiveTab 존재', () => typeof GameState.isCurrentlyActiveTab === 'function');
        this.test('emitEvent 존재', () => typeof GameState.emitEvent === 'function');

        // Test isCurrentlyActiveTab
        const isActive = GameState.isCurrentlyActiveTab();
        this.test('현재 탭 활성 상태 확인 가능', () => typeof isActive === 'boolean');
    },

    // ==========================================
    // Session 2: Combat System Tests
    // ==========================================

    testSession2() {
        // TileGrid
        this.test('TileGrid 로드됨', () => typeof TileGrid !== 'undefined');
        if (typeof TileGrid !== 'undefined') {
            this.test('TileGrid.init 존재', () => typeof TileGrid.init === 'function');
            this.test('TileGrid.getTile 존재', () => typeof TileGrid.getTile === 'function');
            this.test('TileGrid.isWalkable 존재', () => typeof TileGrid.isWalkable === 'function');
            this.test('TileGrid.findPath 존재', () => typeof TileGrid.findPath === 'function');
            this.test('TileGrid.hasLineOfSight 존재', () => typeof TileGrid.hasLineOfSight === 'function');
        }

        // SkillSystem
        this.test('SkillSystem 로드됨', () => typeof SkillSystem !== 'undefined');
        if (typeof SkillSystem !== 'undefined') {
            this.test('SkillSystem.initCrew 존재', () => typeof SkillSystem.initCrew === 'function');
            this.test('SkillSystem.isSkillReady 존재', () => typeof SkillSystem.isSkillReady === 'function');
            this.test('SkillSystem.useSkill 존재', () => typeof SkillSystem.useSkill === 'function');
            this.test('SkillSystem.getCooldownPercent 존재', () => typeof SkillSystem.getCooldownPercent === 'function');
        }

        // EquipmentEffects
        this.test('EquipmentEffects 로드됨', () => typeof EquipmentEffects !== 'undefined');
        if (typeof EquipmentEffects !== 'undefined') {
            this.test('EquipmentEffects.initCrew 존재', () => typeof EquipmentEffects.initCrew === 'function');
            this.test('EquipmentEffects.canUse 존재', () => typeof EquipmentEffects.canUse === 'function');
            this.test('EquipmentEffects.use 존재', () => typeof EquipmentEffects.use === 'function');
        }

        // TurretSystem
        this.test('TurretSystem 로드됨', () => typeof TurretSystem !== 'undefined');
        if (typeof TurretSystem !== 'undefined') {
            this.test('TurretSystem.create 존재', () => typeof TurretSystem.create === 'function');
            this.test('TurretSystem.update 존재', () => typeof TurretSystem.update === 'function');
            this.test('TurretSystem.canBeHacked 존재', () => typeof TurretSystem.canBeHacked === 'function');
        }

        // RavenSystem
        this.test('RavenSystem 로드됨', () => typeof RavenSystem !== 'undefined');
        if (typeof RavenSystem !== 'undefined') {
            this.test('RavenSystem.init 존재', () => typeof RavenSystem.init === 'function');
            this.test('RavenSystem.canUse 존재', () => typeof RavenSystem.canUse === 'function');
            this.test('RavenSystem.useAbility 존재', () => typeof RavenSystem.useAbility === 'function');
            this.test('RavenSystem.getAllAbilities 존재', () => typeof RavenSystem.getAllAbilities === 'function');

            // 능력 테스트
            RavenSystem.init('normal');
            const abilities = RavenSystem.getAllAbilities();
            this.test('Raven 능력 4개', () => abilities.length === 4);
        }
    },

    // ==========================================
    // Session 3: Enemy/AI System Tests
    // ==========================================

    testSession3() {
        // EnemyFactory
        this.test('EnemyFactory 로드됨', () => typeof EnemyFactory !== 'undefined');
        if (typeof EnemyFactory !== 'undefined') {
            this.test('EnemyFactory.create 존재', () => typeof EnemyFactory.create === 'function');
            this.test('EnemyFactory.createBatch 존재', () => typeof EnemyFactory.createBatch === 'function');
        }

        // AIManager (Class - check prototype methods)
        this.test('AIManager 로드됨', () => typeof AIManager !== 'undefined');
        if (typeof AIManager !== 'undefined') {
            this.test('AIManager.updateEnemy 존재', () => typeof AIManager.prototype.updateEnemy === 'function');
            this.test('AIManager.updateAll 존재', () => typeof AIManager.prototype.updateAll === 'function');
            this.test('AIManager.clear 존재', () => typeof AIManager.prototype.clear === 'function');
        }

        // WaveGenerator
        this.test('WaveGenerator 로드됨', () => typeof WaveGenerator !== 'undefined');
        if (typeof WaveGenerator !== 'undefined') {
            this.test('WaveGenerator 클래스', () => {
                const gen = new WaveGenerator();
                return typeof gen.generateWaves === 'function';
            });
        }

        // WaveManager
        this.test('WaveManager 로드됨', () => typeof WaveManager !== 'undefined');
        if (typeof WaveManager !== 'undefined') {
            this.test('WaveManager 클래스', () => {
                const mgr = new WaveManager();
                return typeof mgr.initialize === 'function';
            });
        }

        // EnemyMechanicsManager
        this.test('EnemyMechanicsManager 로드됨', () => typeof EnemyMechanicsManager !== 'undefined');
        if (typeof EnemyMechanicsManager !== 'undefined') {
            this.test('EnemyMechanicsManager 클래스', () => {
                const mgr = new EnemyMechanicsManager();
                return typeof mgr.update === 'function';
            });
        }
    },

    // ==========================================
    // Session 4: Campaign System Tests
    // ==========================================

    testSession4() {
        // SectorGenerator
        this.test('SectorGenerator 로드됨', () => typeof SectorGenerator !== 'undefined');
        if (typeof SectorGenerator !== 'undefined') {
            this.test('SectorGenerator.generate 존재', () => typeof SectorGenerator.generate === 'function');
            this.test('SectorGenerator.visitNode 존재', () => typeof SectorGenerator.visitNode === 'function');
            this.test('SectorGenerator.advanceStormFront 존재', () => typeof SectorGenerator.advanceStormFront === 'function');
            this.test('SectorGenerator.NODE_TYPES 존재', () => SectorGenerator.NODE_TYPES !== undefined);

            // 섹터 생성 테스트
            if (typeof RNG !== 'undefined') {
                const rng = new RNG(12345);
                const sectorMap = SectorGenerator.generate(rng, 'normal');
                this.test('섹터맵 생성됨', () => sectorMap !== null);
                this.test('섹터맵 노드 존재', () => sectorMap?.nodes?.length > 10);
                this.test('start 노드 존재', () => sectorMap?.nodes?.some(n => n.type === 'start'));
                this.test('gate 노드 존재', () => sectorMap?.nodes?.some(n => n.type === 'gate'));
            }
        }

        // StationGenerator
        this.test('StationGenerator 로드됨', () => typeof StationGenerator !== 'undefined');
        if (typeof StationGenerator !== 'undefined') {
            this.test('StationGenerator.generate 존재', () => typeof StationGenerator.generate === 'function');
            this.test('StationGenerator.isWalkable 존재', () => typeof StationGenerator.isWalkable === 'function');
            this.test('StationGenerator.TILE 존재', () => StationGenerator.TILE !== undefined);

            // 레이아웃 생성 테스트
            if (typeof RNG !== 'undefined') {
                const rng = new RNG(12345);
                const layout = StationGenerator.generate(rng, 5);
                this.test('레이아웃 생성됨', () => layout !== null);
                this.test('레이아웃 크기 존재', () => layout?.width > 0 && layout?.height > 0);
                this.test('시설 존재', () => layout?.facilities?.length > 0);
                this.test('스폰포인트 존재', () => layout?.spawnPoints?.length > 0);
            }
        }

        // MetaProgress
        this.test('MetaProgress 로드됨', () => typeof MetaProgress !== 'undefined');
        if (typeof MetaProgress !== 'undefined') {
            this.test('MetaProgress.isClassUnlocked 존재', () => typeof MetaProgress.isClassUnlocked === 'function');
            this.test('MetaProgress.isEquipmentUnlocked 존재', () => typeof MetaProgress.isEquipmentUnlocked === 'function');
            this.test('MetaProgress.getStats 존재', () => typeof MetaProgress.getStats === 'function');
            this.test('MetaProgress.processRunCompletion 존재', () => typeof MetaProgress.processRunCompletion === 'function');

            // 기본 해금 확인
            this.test('Guardian 기본 해금', () => MetaProgress.isClassUnlocked('guardian'));
            this.test('Sentinel 기본 해금', () => MetaProgress.isClassUnlocked('sentinel'));
            this.test('Ranger 기본 해금', () => MetaProgress.isClassUnlocked('ranger'));
        }
    },

    // ==========================================
    // Session 5: UI System Tests
    // ==========================================

    testSession5() {
        // Tooltip
        this.test('Tooltip 로드됨', () => typeof Tooltip !== 'undefined');
        if (typeof Tooltip !== 'undefined') {
            this.test('Tooltip.showAt 존재', () => typeof Tooltip.showAt === 'function');
            this.test('Tooltip.hide 존재', () => typeof Tooltip.hide === 'function');
        }

        // Toast
        this.test('Toast 로드됨', () => typeof Toast !== 'undefined');
        if (typeof Toast !== 'undefined') {
            this.test('Toast.show 존재', () => typeof Toast.show === 'function');
            this.test('Toast.info 존재', () => typeof Toast.info === 'function');
            this.test('Toast.error 존재', () => typeof Toast.error === 'function');
        }

        // ModalManager
        this.test('ModalManager 로드됨', () => typeof ModalManager !== 'undefined');
        if (typeof ModalManager !== 'undefined') {
            this.test('ModalManager.open 존재', () => typeof ModalManager.open === 'function');
            this.test('ModalManager.close 존재', () => typeof ModalManager.close === 'function');
            this.test('ModalManager.confirm 존재', () => typeof ModalManager.confirm === 'function');
        }

        // ProgressBar
        this.test('ProgressBar 로드됨', () => typeof ProgressBar !== 'undefined');
        if (typeof ProgressBar !== 'undefined') {
            this.test('ProgressBar.create 존재', () => typeof ProgressBar.create === 'function');
            this.test('ProgressBar.update 존재', () => typeof ProgressBar.update === 'function');
        }

        // ScreenEffects
        this.test('ScreenEffects 로드됨', () => typeof ScreenEffects !== 'undefined');
        if (typeof ScreenEffects !== 'undefined') {
            this.test('ScreenEffects.shake 존재', () => typeof ScreenEffects.shake === 'function');
            this.test('ScreenEffects.flash 존재', () => typeof ScreenEffects.flash === 'function');
            this.test('ScreenEffects.damage 존재', () => typeof ScreenEffects.damage === 'function');
        }

        // ParticleSystem
        this.test('ParticleSystem 로드됨', () => typeof ParticleSystem !== 'undefined');
        if (typeof ParticleSystem !== 'undefined') {
            this.test('ParticleSystem.emit 존재', () => typeof ParticleSystem.emit === 'function');
            this.test('ParticleSystem.explosion 존재', () => typeof ParticleSystem.explosion === 'function');
        }

        // FloatingText
        this.test('FloatingText 로드됨', () => typeof FloatingText !== 'undefined');
        if (typeof FloatingText !== 'undefined') {
            this.test('FloatingText.show 존재', () => typeof FloatingText.show === 'function');
            this.test('FloatingText.damage 존재', () => typeof FloatingText.damage === 'function');
            this.test('FloatingText.heal 존재', () => typeof FloatingText.heal === 'function');
        }

        // HUD
        this.test('HUD 로드됨', () => typeof HUD !== 'undefined');
        if (typeof HUD !== 'undefined') {
            this.test('HUD.init 존재', () => typeof HUD.init === 'function');
            this.test('HUD.updateWave 존재', () => typeof HUD.updateWave === 'function');
            this.test('HUD.updateCrews 존재', () => typeof HUD.updateCrews === 'function');
        }

        // BattleEffectsIntegration
        this.test('BattleEffectsIntegration 로드됨', () => typeof BattleEffectsIntegration !== 'undefined');
        if (typeof BattleEffectsIntegration !== 'undefined') {
            this.test('BattleEffectsIntegration.init 존재', () => typeof BattleEffectsIntegration.init === 'function');
        }
    },

    // ==========================================
    // Integration Tests
    // ==========================================

    testFullGameFlow() {
        if (typeof GameState === 'undefined') return;

        const backup = GameState.currentRun;

        // 전체 게임 플로우 시뮬레이션
        const run = GameState.startNewRun(99999, 'normal');
        this.test('플로우: 게임 시작', () => run !== null);

        const aliveCrews = GameState.getAliveCrews();
        this.test('플로우: 생존 크루 3명', () => aliveCrews.length === 3);

        GameState.recordStationDefended(50, true);
        this.test('플로우: 스테이션 방어 기록', () => run.stats.stationsDefended === 1);
        this.test('플로우: 크레딧 획득', () => run.credits === 50);

        GameState.recordEnemiesKilled(20);
        this.test('플로우: 적 처치 기록', () => run.stats.enemiesKilled === 20);

        const firstCrew = run.crews[0];
        GameState.recordCrewDeath(firstCrew.id);
        this.test('플로우: 크루 사망 처리', () => !firstCrew.isAlive);

        const score = GameState.calculateScore();
        this.test('플로우: 점수 계산', () => score > 0);

        GameState.endRun(true);
        this.test('플로우: 게임 완료', () => run.isComplete === true);

        GameState.clearCurrentRun();
        GameState.currentRun = backup;
        if (backup) GameState.saveCurrentRun();
    },

    testDataIntegration() {
        // CrewData + TraitData 통합
        if (typeof CrewData !== 'undefined' && typeof TraitData !== 'undefined') {
            const recommendedTraits = TraitData.getRecommendedForClass('guardian');
            this.test('가디언 추천 특성 존재', () => recommendedTraits.length > 0);
        }

        // EnemyData + BalanceData 통합
        if (typeof EnemyData !== 'undefined' && typeof BalanceData !== 'undefined') {
            const waveConfig = BalanceData.getWaveConfig(5, 'normal');
            const availableEnemies = EnemyData.getAvailableAtDepth(5);
            this.test('예산으로 적 생성 가능', () => {
                const cheapestEnemy = availableEnemies.reduce((min, e) =>
                    e.cost < min.cost ? e : min, availableEnemies[0]);
                return waveConfig.budget >= cheapestEnemy.cost;
            });
        }

        // CrewData + EnemyData 카운터 관계
        if (typeof CrewData !== 'undefined' && typeof EnemyData !== 'undefined') {
            const brute = EnemyData.get('brute');
            this.test('브루트 카운터 = 센티넬', () => brute?.counters?.includes('sentinel'));

            const sniper = EnemyData.get('sniper');
            this.test('스나이퍼 카운터 = 바이오닉', () => sniper?.counters?.includes('bionic'));
        }
    },

    // ==========================================
    // Utility Functions
    // ==========================================

    test(name, fn) {
        try {
            const result = fn();
            this.results.push({
                name,
                passed: result,
                error: null,
                category: this.currentCategory
            });
            if (this.verbose && !result) {
                console.log(`  %c✗ ${name}`, 'color: #fc8181');
            }
        } catch (e) {
            this.results.push({
                name,
                passed: false,
                error: e.message,
                category: this.currentCategory
            });
            if (this.verbose) {
                console.log(`  %c✗ ${name}: ${e.message}`, 'color: #fc8181');
            }
        }
    },

    log(message, style = '') {
        if (this.verbose) {
            console.log(message, style);
        }
    },

    printResults() {
        console.log('\n%c═══════════════════════════════════════════', 'color: #4a9eff');
        console.log('%c              테스트 결과 요약              ', 'color: #4a9eff; font-weight: bold');
        console.log('%c═══════════════════════════════════════════', 'color: #4a9eff');

        let passed = 0, failed = 0;
        const failures = [];
        const categoryResults = {};

        this.results.forEach(r => {
            if (!categoryResults[r.category]) {
                categoryResults[r.category] = { passed: 0, failed: 0 };
            }
            if (r.passed) {
                passed++;
                categoryResults[r.category].passed++;
            } else {
                failed++;
                categoryResults[r.category].failed++;
                failures.push(r);
            }
        });

        // 카테고리별 결과
        console.log('\n%c카테고리별 결과:', 'font-weight: bold');
        Object.entries(categoryResults).forEach(([cat, res]) => {
            const status = res.failed === 0 ? '✓' : '✗';
            const color = res.failed === 0 ? 'color: #68d391' : 'color: #fc8181';
            console.log(`  %c${status} ${cat}: ${res.passed}/${res.passed + res.failed}`, color);
        });

        // 전체 결과
        console.log(`\n%c전체: ${passed}/${passed + failed} (${((passed / (passed + failed)) * 100).toFixed(1)}%)`,
            'font-weight: bold');

        if (failures.length > 0) {
            console.log('\n%c실패한 테스트:', 'color: #fc8181; font-weight: bold');
            failures.forEach(f => {
                console.log(`  ✗ [${f.category}] ${f.name}${f.error ? ': ' + f.error : ''}`);
            });
        }

        if (failed === 0) {
            console.log('%c\n✓ 모든 테스트 통과!', 'color: #68d391; font-size: 14px; font-weight: bold');
        }
    },

    // ==========================================
    // Quick Tests
    // ==========================================

    testDataModules() {
        this.results = [];
        this.currentCategory = 'Data Modules';
        this.testDataModulesExist();
        this.testCrewData();
        this.testEquipmentData();
        this.testTraitData();
        this.testEnemyData();
        this.testFacilityData();
        this.testBalanceData();
        this.printResults();
    },

    testGameState() {
        this.results = [];
        this.currentCategory = 'GameState';
        this.testGameStateBasic();
        this.testCrewCreation();
        this.testEconomyFunctions();
        this.printResults();
    },
};

// 글로벌로 노출
window.IntegrationTest = IntegrationTest;

console.log('%c통합 테스트 v2.0 로드됨', 'color: #4a9eff; font-weight: bold');
console.log('%c실행: IntegrationTest.runAll()', 'color: #68d391');
console.log('%c개별: IntegrationTest.testSession2() / testSession3() / testSession4() / testSession5()', 'color: #a0aec0');
