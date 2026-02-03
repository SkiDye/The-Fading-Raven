/**
 * THE FADING RAVEN - Balance Validator
 * 게임 밸런스 검증 및 시뮬레이션 도구
 * 브라우저 콘솔에서 실행: BalanceValidator.runAll()
 */

const BalanceValidator = {
    // ==========================================
    // Economy Simulation
    // ==========================================

    /**
     * 캠페인 경제 시뮬레이션
     */
    simulateEconomy(difficulty = 'normal', stages = 10) {
        console.log(`\n%c=== 경제 시뮬레이션: ${difficulty}, ${stages} 스테이지 ===`, 'font-weight: bold');

        const diff = BalanceData.difficulty[difficulty];
        let totalCredits = 0;
        let totalSpent = 0;
        const stageResults = [];

        for (let stage = 1; stage <= stages; stage++) {
            // 예상 수입 (시설 2-3개 방어, 실제 크레딧 값 사용)
            const facilitiesDefended = 2 + Math.floor(Math.random());
            // 평균 시설 크레딧: (소형2 + 중형3 + 대형5) / 3 ≈ 3.3
            const avgFacilityCredit = 3;
            const facilityCredits = facilitiesDefended * avgFacilityCredit;
            const perfectBonus = Math.random() > 0.5 ? BalanceData.economy.perfectDefenseBonus : 0;
            const stageIncome = Math.floor((facilityCredits + perfectBonus) * diff.creditMultiplier);

            totalCredits += stageIncome;

            // 예상 지출
            let stageSpending = 0;
            if (stage % 2 === 0) { // 2스테이지마다 힐
                stageSpending += BalanceData.economy.healCost;
            }
            if (stage === 3) { // 3스테이지에 스킬 업그레이드
                stageSpending += BalanceData.economy.skillUpgradeCosts[1];
            }
            if (stage === 6) { // 6스테이지에 스킬 업그레이드
                stageSpending += BalanceData.economy.skillUpgradeCosts[2];
            }

            totalSpent += stageSpending;

            stageResults.push({
                stage,
                income: stageIncome,
                spending: stageSpending,
                balance: totalCredits - totalSpent
            });
        }

        console.table(stageResults);
        console.log(`\n총 수입: ${totalCredits}`);
        console.log(`총 지출: ${totalSpent}`);
        console.log(`최종 잔액: ${totalCredits - totalSpent}`);

        const economyHealth = totalCredits - totalSpent;
        if (economyHealth < 0) {
            console.log('%c⚠️ 경고: 적자 경제', 'color: #fc8181');
        } else if (economyHealth < 20) {
            console.log('%c✓ 타이트한 경제 (의도된 설계)', 'color: #f6ad55');
        } else {
            console.log('%c✓ 여유로운 경제', 'color: #68d391');
        }

        return { totalCredits, totalSpent, balance: economyHealth };
    },

    // ==========================================
    // Wave Difficulty Analysis
    // ==========================================

    /**
     * 웨이브 난이도 분석
     */
    analyzeWaveDifficulty(depth = 5, difficulty = 'normal') {
        console.log(`\n%c=== 웨이브 난이도 분석: 깊이 ${depth}, ${difficulty} ===`, 'font-weight: bold');

        const waveConfig = BalanceData.getWaveConfig(depth, difficulty);
        const availableEnemies = EnemyData.getAvailableAtDepth(depth);

        console.log('웨이브 설정:');
        console.log(`  예산: ${waveConfig.budget}`);
        console.log(`  웨이브 수: ${waveConfig.waveCount}`);
        console.log(`  사용 가능한 적: ${availableEnemies.length}종`);

        // 예산으로 생성 가능한 적 조합 예시
        console.log('\n예산으로 생성 가능한 조합:');

        const combinations = [];

        // 러셔만
        combinations.push({
            name: '러셔 웨이브',
            composition: `러셔 x${waveConfig.budget}`,
            totalCost: waveConfig.budget,
            difficulty: '쉬움'
        });

        // 혼합
        if (waveConfig.tier2Available) {
            const jumperCount = Math.floor(waveConfig.budget / 4);
            const remaining = waveConfig.budget - (jumperCount * 4);
            combinations.push({
                name: '점퍼 혼합',
                composition: `점퍼 x${jumperCount}, 러셔 x${remaining}`,
                totalCost: waveConfig.budget,
                difficulty: '보통'
            });
        }

        // 브루트 포함
        if (waveConfig.tier3Available) {
            const bruteCount = Math.floor(waveConfig.budget / 8);
            const remaining = waveConfig.budget - (bruteCount * 8);
            combinations.push({
                name: '브루트 웨이브',
                composition: `브루트 x${bruteCount}, 러셔 x${remaining}`,
                totalCost: waveConfig.budget,
                difficulty: '어려움'
            });
        }

        console.table(combinations);

        return { waveConfig, availableEnemies, combinations };
    },

    // ==========================================
    // Class Balance Analysis
    // ==========================================

    /**
     * 클래스 밸런스 분석
     */
    analyzeClassBalance() {
        console.log(`\n%c=== 클래스 밸런스 분석 ===`, 'font-weight: bold');

        const classes = CrewData.getAllClasses().map(classId => {
            const data = CrewData.getClass(classId);
            const stats = data.stats;

            // DPS 계산 (데미지 / 공격 속도)
            const dps = (stats.damage * 1000) / stats.attackSpeed;

            // 생존력 점수 (분대 크기 * 방어력 보정)
            const survival = data.baseSquadSize * (1 + (stats.defense || 0));

            // 기동성 점수
            const mobility = stats.moveSpeed + (stats.attackRange / 10);

            return {
                class: classId,
                name: data.name,
                squadSize: data.baseSquadSize,
                damage: stats.damage,
                attackSpeed: stats.attackSpeed,
                dps: dps.toFixed(1),
                range: stats.attackRange,
                moveSpeed: stats.moveSpeed,
                survival: survival.toFixed(1),
                mobility: mobility.toFixed(1)
            };
        });

        console.table(classes);

        // 역할별 분류
        console.log('\n역할 분석:');
        classes.forEach(c => {
            let role = '';
            if (c.class === 'guardian') role = '올라운더, 대원거리';
            if (c.class === 'sentinel') role = '병목 방어, 대브루트';
            if (c.class === 'ranger') role = '원거리 딜러';
            if (c.class === 'engineer') role = '지원, 터렛';
            if (c.class === 'bionic') role = '암살, 기동';
            console.log(`  ${c.name}: ${role} (DPS: ${c.dps}, 생존: ${c.survival})`);
        });

        return classes;
    },

    // ==========================================
    // Enemy Counter Matrix
    // ==========================================

    /**
     * 적 카운터 매트릭스
     */
    generateCounterMatrix() {
        console.log(`\n%c=== 적 카운터 매트릭스 ===`, 'font-weight: bold');

        const enemies = EnemyData.getAll().filter(e => !e.isBoss);
        const classes = CrewData.getAllClasses();

        const matrix = {};

        enemies.forEach(enemy => {
            matrix[enemy.id] = {};
            classes.forEach(classId => {
                let effectiveness = '△'; // 보통

                if (enemy.counters?.includes(classId)) {
                    effectiveness = '◎'; // 강력 카운터
                } else if (enemy.threats?.includes(classId)) {
                    effectiveness = '✗'; // 비효과적
                }

                matrix[enemy.id][classId] = effectiveness;
            });
        });

        // 테이블 출력
        console.log('\n카운터 매트릭스 (◎ 강력 | △ 보통 | ✗ 비효과):');
        console.log('         guardian sentinel ranger  engineer bionic');
        console.log('─'.repeat(60));

        Object.keys(matrix).forEach(enemyId => {
            const row = matrix[enemyId];
            const line = `${enemyId.padEnd(12)} ${row.guardian.padEnd(8)} ${row.sentinel.padEnd(8)} ${row.ranger.padEnd(8)} ${row.engineer.padEnd(8)} ${row.bionic}`;
            console.log(line);
        });

        return matrix;
    },

    // ==========================================
    // Difficulty Scaling Analysis
    // ==========================================

    /**
     * 난이도 스케일링 분석
     */
    analyzeDifficultyScaling() {
        console.log(`\n%c=== 난이도 스케일링 분석 ===`, 'font-weight: bold');

        const difficulties = ['normal', 'hard', 'veryhard', 'nightmare'];

        const analysis = difficulties.map(diffId => {
            const diff = BalanceData.difficulty[diffId];
            const waveConfig = BalanceData.getWaveConfig(5, diffId);

            return {
                difficulty: diffId,
                enemyHealth: `${diff.enemyHealthMultiplier}x`,
                enemyDamage: `${diff.enemyDamageMultiplier}x`,
                enemyCount: `${diff.enemyCountMultiplier}x`,
                waveBonus: `+${diff.waveCountBonus}`,
                waveBudget: waveConfig.budget,
                credits: `${diff.creditMultiplier}x`,
                score: `${diff.scoreMultiplier}x`
            };
        });

        console.table(analysis);

        // 상대적 난이도 증가율
        console.log('\n상대적 난이도 증가 (Normal 기준):');
        const normalBudget = BalanceData.getWaveConfig(5, 'normal').budget;
        difficulties.forEach(diffId => {
            const budget = BalanceData.getWaveConfig(5, diffId).budget;
            const increase = ((budget / normalBudget - 1) * 100).toFixed(0);
            console.log(`  ${diffId}: +${increase}% 적 예산`);
        });

        return analysis;
    },

    // ==========================================
    // Skill Cost-Benefit Analysis
    // ==========================================

    /**
     * 스킬 비용 대비 효과 분석
     */
    analyzeSkillValue() {
        console.log(`\n%c=== 스킬 비용-효과 분석 ===`, 'font-weight: bold');

        const classes = CrewData.getAllClasses();

        const analysis = [];

        classes.forEach(classId => {
            const classData = CrewData.getClass(classId);
            const skill = classData.skill;

            skill.levels.forEach((level, idx) => {
                analysis.push({
                    class: classData.name,
                    skill: skill.name,
                    level: idx + 1,
                    cost: level.cost,
                    effect: level.description,
                    valueRating: this.rateSkillValue(classId, idx + 1)
                });
            });
        });

        console.table(analysis);

        return analysis;
    },

    /**
     * 스킬 가치 평가 (주관적)
     */
    rateSkillValue(classId, level) {
        const ratings = {
            guardian: { 1: '★★★', 2: '★★★', 3: '★★★★' },
            sentinel: { 1: '★★★★', 2: '★★★★★', 3: '★★★★★' },
            ranger: { 1: '★★', 2: '★★★', 3: '★★★★★' },
            engineer: { 1: '★★★', 2: '★★★★', 3: '★★★★' },
            bionic: { 1: '★★★', 2: '★★★★', 3: '★★★★★' }
        };

        return ratings[classId]?.[level] || '★★★';
    },

    // ==========================================
    // Full Analysis
    // ==========================================

    /**
     * 전체 밸런스 분석 실행
     */
    runAll() {
        console.log('%c╔════════════════════════════════════════════╗', 'color: #4a9eff');
        console.log('%c║   THE FADING RAVEN - 밸런스 검증 리포트    ║', 'color: #4a9eff; font-weight: bold');
        console.log('%c╚════════════════════════════════════════════╝', 'color: #4a9eff');

        this.analyzeClassBalance();
        this.generateCounterMatrix();
        this.analyzeDifficultyScaling();
        this.analyzeSkillValue();
        this.analyzeWaveDifficulty(5, 'normal');
        this.simulateEconomy('normal', 10);

        console.log('\n%c=== 분석 완료 ===', 'font-weight: bold');
        console.log('개별 분석: BalanceValidator.analyzeClassBalance()');
        console.log('경제 시뮬: BalanceValidator.simulateEconomy("hard", 15)');
        console.log('웨이브 분석: BalanceValidator.analyzeWaveDifficulty(10, "hard")');
    },

    // ==========================================
    // Combat Simulation
    // ==========================================

    /**
     * 간단한 전투 시뮬레이션
     */
    simulateCombat(crewClass, enemyId, crewCount = 8) {
        console.log(`\n%c=== 전투 시뮬레이션: ${crewClass} vs ${enemyId} ===`, 'font-weight: bold');

        const classData = CrewData.getClass(crewClass);
        const enemyData = EnemyData.get(enemyId);

        if (!classData || !enemyData) {
            console.log('잘못된 클래스 또는 적 ID');
            return;
        }

        // 크루 스탯
        const crewDamage = classData.stats.damage;
        const crewAttackSpeed = classData.stats.attackSpeed;
        const crewDps = (crewDamage * 1000) / crewAttackSpeed * crewCount;

        // 적 스탯
        const enemyHealth = enemyData.stats.health;
        const enemyDamage = enemyData.stats.damage;
        const enemyAttackSpeed = enemyData.stats.attackSpeed;

        // 킬 시간 계산
        const timeToKill = (enemyHealth / crewDps) * 1000;

        // 적이 주는 피해 계산 (근접까지 도달 시간 + 공격 시간)
        const approachTime = 2000; // 2초 가정
        const attacksBeforeDeath = Math.floor((timeToKill - approachTime) / enemyAttackSpeed);
        const damageDealt = Math.max(0, attacksBeforeDeath * enemyDamage);

        console.log(`${crewClass} (${crewCount}명):`);
        console.log(`  개인 데미지: ${crewDamage}`);
        console.log(`  팀 DPS: ${crewDps.toFixed(1)}`);

        console.log(`\n${enemyId}:`);
        console.log(`  체력: ${enemyHealth}`);
        console.log(`  데미지: ${enemyDamage}`);

        console.log(`\n결과:`);
        console.log(`  킬 시간: ${(timeToKill / 1000).toFixed(2)}초`);
        console.log(`  받은 피해: ${damageDealt} (약 ${Math.ceil(damageDealt / 10)}명 손실)`);

        const result = damageDealt < crewCount * 10 ? '승리' : '패배';
        console.log(`  예상 결과: ${result}`);

        return { timeToKill, damageDealt, result };
    },
};

// 글로벌로 노출
window.BalanceValidator = BalanceValidator;

console.log('%c밸런스 검증기 로드됨. 실행: BalanceValidator.runAll()', 'color: #f6ad55');
