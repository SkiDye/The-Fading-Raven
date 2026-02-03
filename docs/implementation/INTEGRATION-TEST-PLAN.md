# The Fading Raven - 통합 테스트 및 로직 검증 계획 v2.0

## 개요

모든 5개 세션 작업 완료 후 수행할 통합 테스트 및 로직 검증 절차입니다.
**업데이트: 2026-02-03** - 전체 시스템 반영

---

## 1. 파일 존재 확인 체크리스트

### Session 1: Data & Core
```
[x] demo/js/data/crews.js
[x] demo/js/data/equipment.js
[x] demo/js/data/traits.js
[x] demo/js/data/enemies.js
[x] demo/js/data/facilities.js
[x] demo/js/data/balance.js
[x] demo/js/core/game-state.js
```

### Session 2: Combat System
```
[x] demo/js/core/tile-grid.js
[x] demo/js/core/skills.js
[x] demo/js/core/equipment-effects.js
[x] demo/js/core/raven.js
[x] demo/js/entities/turret.js
[x] demo/js/pages/battle.js
```

### Session 3: Enemies & AI
```
[x] demo/js/entities/enemy.js
[x] demo/js/ai/behavior-tree.js
[x] demo/js/ai/enemy-mechanics.js
[x] demo/js/core/wave-generator.js
```

### Session 4: Campaign System
```
[x] demo/js/core/sector-generator.js
[x] demo/js/core/station-generator.js
[x] demo/js/core/meta-progress.js
[x] demo/js/pages/sector.js
```

### Session 5: UI & Polish
```
[x] demo/js/ui/ui-components.js
[x] demo/js/ui/effects.js
[x] demo/js/ui/hud.js
[x] demo/js/ui/battle-effects-integration.js
[x] demo/css/ui-components.css
[x] demo/css/effects.css
[x] demo/css/hud.css
```

### Test Files
```
[x] demo/js/test/integration-test.js
[x] demo/js/test/balance-validator.js
```

---

## 2. 콘솔 에러 체크

각 페이지에서 브라우저 개발자 도구(F12) 콘솔 확인:

| 페이지 | 에러 없음 | 경고 | 비고 |
|--------|----------|------|------|
| index.html | [ ] | [ ] | |
| pages/difficulty.html | [ ] | [ ] | |
| pages/sector.html | [ ] | [ ] | |
| pages/deploy.html | [ ] | [ ] | |
| pages/battle.html | [ ] | [ ] | |
| pages/result.html | [ ] | [ ] | |
| pages/upgrade.html | [ ] | [ ] | |
| pages/settings.html | [ ] | [ ] | |
| pages/victory.html | [ ] | [ ] | |
| pages/gameover.html | [ ] | [ ] | |

---

## 3. 자동화 테스트 실행

### 3.1 통합 테스트 실행
브라우저 콘솔에서:
```javascript
IntegrationTest.runAll()
```

**예상 결과:**
- 모든 데이터 모듈 로드 확인
- GameState 기본 기능 확인
- 크루 생성 기능 확인
- 경제 계산 확인
- 데이터 통합 확인

### 3.2 밸런스 검증 실행
```javascript
BalanceValidator.runAll()
```

**예상 결과:**
- 클래스 밸런스 분석
- 카운터 매트릭스 생성
- 난이도 스케일링 분석
- 스킬 비용-효과 분석
- 경제 시뮬레이션

### 3.3 개별 모듈 테스트
```javascript
// Session 2 시스템
IntegrationTest.testSession2()

// Session 3 시스템
IntegrationTest.testSession3()

// Session 4 시스템
IntegrationTest.testSession4()

// Session 5 시스템
IntegrationTest.testSession5()
```

---

## 4. Session 2 전투 시스템 테스트

### 4.1 TileGrid 테스트
```javascript
// battle.html에서 실행
console.log('=== TileGrid 테스트 ===');
console.log('TileGrid 로드:', typeof TileGrid !== 'undefined');

// 기본 기능 테스트
TileGrid.init({ width: 20, height: 15, tiles: [] });
console.log('getTile 작동:', TileGrid.getTile(5, 5) !== undefined);
console.log('isWalkable 작동:', typeof TileGrid.isWalkable(5, 5) === 'boolean');
console.log('findPath 작동:', typeof TileGrid.findPath === 'function');
console.log('hasLineOfSight 작동:', typeof TileGrid.hasLineOfSight === 'function');
```

### 4.2 SkillSystem 테스트
```javascript
console.log('=== SkillSystem 테스트 ===');
console.log('SkillSystem 로드:', typeof SkillSystem !== 'undefined');

// API 확인
console.log('initCrew 존재:', typeof SkillSystem.initCrew === 'function');
console.log('isSkillReady 존재:', typeof SkillSystem.isSkillReady === 'function');
console.log('useSkill 존재:', typeof SkillSystem.useSkill === 'function');
console.log('getCooldownPercent 존재:', typeof SkillSystem.getCooldownPercent === 'function');
console.log('getSkillInfo 존재:', typeof SkillSystem.getSkillInfo === 'function');
```

### 4.3 EquipmentEffects 테스트
```javascript
console.log('=== EquipmentEffects 테스트 ===');
console.log('EquipmentEffects 로드:', typeof EquipmentEffects !== 'undefined');

// API 확인
console.log('initCrew 존재:', typeof EquipmentEffects.initCrew === 'function');
console.log('canUse 존재:', typeof EquipmentEffects.canUse === 'function');
console.log('use 존재:', typeof EquipmentEffects.use === 'function');
console.log('getStatModifiers 존재:', typeof EquipmentEffects.getStatModifiers === 'function');
```

### 4.4 TurretSystem 테스트
```javascript
console.log('=== TurretSystem 테스트 ===');
console.log('TurretSystem 로드:', typeof TurretSystem !== 'undefined');

// API 확인
console.log('create 존재:', typeof TurretSystem.create === 'function');
console.log('remove 존재:', typeof TurretSystem.remove === 'function');
console.log('update 존재:', typeof TurretSystem.update === 'function');
console.log('canBeHacked 존재:', typeof TurretSystem.canBeHacked === 'function');
```

### 4.5 RavenSystem 테스트
```javascript
console.log('=== RavenSystem 테스트 ===');
console.log('RavenSystem 로드:', typeof RavenSystem !== 'undefined');

// API 확인
console.log('init 존재:', typeof RavenSystem.init === 'function');
console.log('canUse 존재:', typeof RavenSystem.canUse === 'function');
console.log('useAbility 존재:', typeof RavenSystem.useAbility === 'function');
console.log('getAllAbilities 존재:', typeof RavenSystem.getAllAbilities === 'function');

// 능력 확인
RavenSystem.init('normal');
const abilities = RavenSystem.getAllAbilities();
console.log('능력 수:', abilities.length);
abilities.forEach(a => console.log(`  - ${a.id}: ${a.name}`));
```

---

## 5. Session 3 적/AI 시스템 테스트

### 5.1 EnemyFactory 테스트
```javascript
console.log('=== EnemyFactory 테스트 ===');
console.log('EnemyFactory 로드:', typeof EnemyFactory !== 'undefined');

// 적 생성 테스트 (battle.html에서)
if (typeof EnemyFactory !== 'undefined') {
    const rusher = EnemyFactory.create('rusher', 100, 100, 'normal');
    console.log('러셔 생성:', rusher !== null);
    console.log('  - 체력:', rusher?.health);
    console.log('  - 속도:', rusher?.moveSpeed);

    const brute = EnemyFactory.create('brute', 100, 100, 'normal');
    console.log('브루트 생성:', brute !== null);
    console.log('  - 체력:', brute?.health);
}
```

### 5.2 AIManager 테스트
```javascript
console.log('=== AIManager 테스트 ===');
console.log('AIManager 로드:', typeof AIManager !== 'undefined');

// API 확인
console.log('updateEnemy 존재:', typeof AIManager.updateEnemy === 'function');
console.log('updateAll 존재:', typeof AIManager.updateAll === 'function');
console.log('clear 존재:', typeof AIManager.clear === 'function');
```

### 5.3 WaveGenerator 테스트
```javascript
console.log('=== WaveGenerator 테스트 ===');
console.log('WaveGenerator 로드:', typeof WaveGenerator !== 'undefined');

// 웨이브 생성 테스트
if (typeof WaveGenerator !== 'undefined') {
    const generator = new WaveGenerator();
    const waves = generator.generateWaves({
        depth: 5,
        difficulty: 'normal',
        spawnPoints: [{x: 0, y: 0}]
    });
    console.log('웨이브 생성:', waves.length > 0);
    console.log('  - 웨이브 수:', waves.length);
    if (waves[0]) {
        console.log('  - 첫 웨이브 적 수:', waves[0].enemies?.length);
    }
}
```

### 5.4 WaveManager 테스트
```javascript
console.log('=== WaveManager 테스트 ===');
console.log('WaveManager 로드:', typeof WaveManager !== 'undefined');

// API 확인
if (typeof WaveManager !== 'undefined') {
    console.log('initialize 존재:', typeof WaveManager.prototype.initialize === 'function');
    console.log('startNextWave 존재:', typeof WaveManager.prototype.startNextWave === 'function');
    console.log('update 존재:', typeof WaveManager.prototype.update === 'function');
    console.log('getProgress 존재:', typeof WaveManager.prototype.getProgress === 'function');
}
```

### 5.5 EnemyMechanicsManager 테스트
```javascript
console.log('=== EnemyMechanicsManager 테스트 ===');
console.log('EnemyMechanicsManager 로드:', typeof EnemyMechanicsManager !== 'undefined');

// API 확인
if (typeof EnemyMechanicsManager !== 'undefined') {
    console.log('update 존재:', typeof EnemyMechanicsManager.prototype.update === 'function');
    console.log('startHacking 존재:', typeof EnemyMechanicsManager.prototype.startHacking === 'function');
    console.log('getSniperLasers 존재:', typeof EnemyMechanicsManager.prototype.getSniperLasers === 'function');
    console.log('isEnemyShielded 존재:', typeof EnemyMechanicsManager.prototype.isEnemyShielded === 'function');
}
```

---

## 6. Session 4 캠페인 시스템 테스트

### 6.1 SectorGenerator 테스트
```javascript
console.log('=== SectorGenerator 테스트 ===');
console.log('SectorGenerator 로드:', typeof SectorGenerator !== 'undefined');

// 섹터 생성 테스트
if (typeof SectorGenerator !== 'undefined') {
    const rng = new RNG(12345);
    const sectorMap = SectorGenerator.generate(rng, 'normal');

    console.log('섹터맵 생성:', sectorMap !== null);
    console.log('  - 노드 수:', sectorMap?.nodes?.length);
    console.log('  - 레이어 수:', sectorMap?.layers);

    // 노드 타입 확인
    const nodeTypes = {};
    sectorMap?.nodes?.forEach(n => {
        nodeTypes[n.type] = (nodeTypes[n.type] || 0) + 1;
    });
    console.log('  - 노드 타입 분포:', nodeTypes);

    // 스톰 시스템 테스트
    console.log('advanceStormFront 작동:', typeof SectorGenerator.advanceStormFront === 'function');
    console.log('hasPathToGate 작동:', typeof SectorGenerator.hasPathToGate === 'function');
}
```

### 6.2 StationGenerator 테스트
```javascript
console.log('=== StationGenerator 테스트 ===');
console.log('StationGenerator 로드:', typeof StationGenerator !== 'undefined');

// 레이아웃 생성 테스트
if (typeof StationGenerator !== 'undefined') {
    const rng = new RNG(12345);
    const layout = StationGenerator.generate(rng, 5);

    console.log('레이아웃 생성:', layout !== null);
    console.log('  - 크기:', layout?.width, 'x', layout?.height);
    console.log('  - 시설 수:', layout?.facilities?.length);
    console.log('  - 스폰포인트 수:', layout?.spawnPoints?.length);

    // ASCII 출력 테스트
    console.log('ASCII 출력:');
    console.log(StationGenerator.toAscii(layout));
}
```

### 6.3 MetaProgress 테스트
```javascript
console.log('=== MetaProgress 테스트 ===');
console.log('MetaProgress 로드:', typeof MetaProgress !== 'undefined');

if (typeof MetaProgress !== 'undefined') {
    // 해금 상태 확인
    console.log('Guardian 해금:', MetaProgress.isClassUnlocked('guardian'));
    console.log('Bionic 해금:', MetaProgress.isClassUnlocked('bionic'));

    // 통계 확인
    const stats = MetaProgress.getStats();
    console.log('통계:', stats);

    // 해금된 클래스
    console.log('해금된 클래스:', MetaProgress.getUnlockedClasses());
    console.log('해금된 장비:', MetaProgress.getUnlockedEquipment());
}
```

---

## 7. Session 5 UI 시스템 테스트

### 7.1 UI Components 테스트
```javascript
console.log('=== UI Components 테스트 ===');

// Tooltip
console.log('Tooltip 로드:', typeof Tooltip !== 'undefined');
if (typeof Tooltip !== 'undefined') {
    Tooltip.showAt(100, 100, '테스트', '내용');
    setTimeout(() => Tooltip.hide(), 1000);
}

// Toast
console.log('Toast 로드:', typeof Toast !== 'undefined');
if (typeof Toast !== 'undefined') {
    Toast.info('테스트 메시지');
}

// ModalManager
console.log('ModalManager 로드:', typeof ModalManager !== 'undefined');

// ProgressBar
console.log('ProgressBar 로드:', typeof ProgressBar !== 'undefined');

// Loading
console.log('Loading 로드:', typeof Loading !== 'undefined');
```

### 7.2 Effects 시스템 테스트
```javascript
console.log('=== Effects 시스템 테스트 ===');

// ScreenEffects
console.log('ScreenEffects 로드:', typeof ScreenEffects !== 'undefined');
if (typeof ScreenEffects !== 'undefined') {
    // ScreenEffects.shake({ intensity: 5, duration: 200 });
    console.log('  - shake 존재:', typeof ScreenEffects.shake === 'function');
    console.log('  - flash 존재:', typeof ScreenEffects.flash === 'function');
    console.log('  - damage 존재:', typeof ScreenEffects.damage === 'function');
}

// TransitionEffects
console.log('TransitionEffects 로드:', typeof TransitionEffects !== 'undefined');

// ElementAnimations
console.log('ElementAnimations 로드:', typeof ElementAnimations !== 'undefined');

// ParticleSystem
console.log('ParticleSystem 로드:', typeof ParticleSystem !== 'undefined');
if (typeof ParticleSystem !== 'undefined') {
    console.log('  - emit 존재:', typeof ParticleSystem.emit === 'function');
    console.log('  - explosion 존재:', typeof ParticleSystem.explosion === 'function');
}

// FloatingText
console.log('FloatingText 로드:', typeof FloatingText !== 'undefined');
if (typeof FloatingText !== 'undefined') {
    console.log('  - show 존재:', typeof FloatingText.show === 'function');
    console.log('  - damage 존재:', typeof FloatingText.damage === 'function');
    console.log('  - heal 존재:', typeof FloatingText.heal === 'function');
}
```

### 7.3 HUD 테스트
```javascript
console.log('=== HUD 테스트 ===');
console.log('HUD 로드:', typeof HUD !== 'undefined');

if (typeof HUD !== 'undefined') {
    console.log('  - init 존재:', typeof HUD.init === 'function');
    console.log('  - updateWave 존재:', typeof HUD.updateWave === 'function');
    console.log('  - updateCrews 존재:', typeof HUD.updateCrews === 'function');
    console.log('  - announceWave 존재:', typeof HUD.announceWave === 'function');
}
```

### 7.4 BattleEffectsIntegration 테스트
```javascript
console.log('=== BattleEffectsIntegration 테스트 ===');
console.log('BattleEffectsIntegration 로드:', typeof BattleEffectsIntegration !== 'undefined');

if (typeof BattleEffectsIntegration !== 'undefined') {
    console.log('  - initialized:', BattleEffectsIntegration.initialized);
    console.log('  - init 존재:', typeof BattleEffectsIntegration.init === 'function');
    console.log('  - patchBattleController 존재:', typeof BattleEffectsIntegration.patchBattleController === 'function');
}
```

---

## 8. 수동 게임 플로우 테스트

### 8.1 새 게임 시작 → 섹터 맵
```
테스트 단계:
1. [ ] 메인 메뉴 NEW GAME 클릭
2. [ ] 시드 입력 (또는 랜덤)
3. [ ] 난이도 선택 화면 표시
4. [ ] 난이도 선택 후 섹터 맵 진입
5. [ ] 시작 크루 3명 표시 (Guardian, Sentinel, Ranger)
6. [ ] 섹터 맵 노드 렌더링 (start, battle, commander, equipment 등)
7. [ ] 스톰 프론트 표시 (붉은 영역)
8. [ ] 현재 위치 표시

검증:
- [ ] GameState.currentRun 존재
- [ ] crews 배열 길이 === 3
- [ ] 각 크루 isAlive === true
- [ ] sectorMap 노드 15-25개
```

### 8.2 전투 진입 → 배치 → 전투
```
테스트 단계:
1. [ ] 전투 노드 클릭
2. [ ] 배치 화면 진입 (StationGenerator 레이아웃)
3. [ ] 크루 선택 → 배치 영역(녹색)에 클릭으로 배치
4. [ ] 배치 취소 가능 확인
5. [ ] 최소 1명 배치 시 "전투 시작" 활성화
6. [ ] 전투 시작
7. [ ] 웨이브 알림 (HUD.announceWave)
8. [ ] 적 스폰 (에어락에서)
9. [ ] 크루 자동 전투
10. [ ] 스킬 사용 (Q키 또는 버튼)
11. [ ] 장비 사용 (E키 또는 버튼)
12. [ ] 시설 방어 시 크레딧 표시
13. [ ] 데미지 숫자 (FloatingText)
14. [ ] 적 처치 시 파티클 효과
15. [ ] 모든 웨이브 클리어
16. [ ] 결과 화면

검증:
- [ ] 적 스폰 위치 정확 (AIRLOCK 타일)
- [ ] 시설 방어 보상 정확
- [ ] 스킬 쿨다운 작동
- [ ] 웨이브 전환 정확
- [ ] 크루 사망 시 이펙트
```

### 8.3 업그레이드 시스템
```
테스트 단계:
1. [ ] 결과 화면에서 UPGRADE 클릭
2. [ ] 크루 카드 표시 (체력바, 특성, 장비)
3. [ ] 크루 선택 → 상세 패널
4. [ ] 힐 구매 (크레딧 차감, 체력 증가)
5. [ ] 스킬 업그레이드 (레벨 증가, 설명 변경)
6. [ ] 승급 (Standard → Veteran → Elite)
7. [ ] 장비 장착/해제
8. [ ] 상태 저장 확인 (새로고침 후 유지)

검증:
- [ ] 비용 계산 정확 (skillful 특성 50% 할인)
- [ ] 크레딧 부족 시 버튼 비활성화
- [ ] localStorage 저장 확인
```

### 8.4 특수 노드 테스트
```
Commander 노드:
- [ ] 새 크루 선택 옵션 표시
- [ ] 크루 영입 후 crews 배열 증가
- [ ] 영입 크루 특성 확인

Equipment 노드:
- [ ] 장비 선택 옵션 표시
- [ ] 장비 획득 후 인벤토리 추가

Rest 노드:
- [ ] 전체 크루 체력 회복
- [ ] 회복량 표시

Storm 노드:
- [ ] 강화된 적 출현 확인
- [ ] 추가 보상 확인
```

### 8.5 게임 종료 조건
```
승리 조건:
- [ ] Gate 노드 도달
- [ ] victory.html 진입
- [ ] 최종 점수 계산
- [ ] MetaProgress 업데이트 (해금)

패배 조건:
- [ ] 모든 크루 사망
- [ ] gameover.html 진입
- [ ] 통계 표시
```

---

## 9. 전투 상세 테스트

### 9.1 크루 스킬 테스트
| 클래스 | 스킬 | Lv1 | Lv2 | Lv3 |
|--------|------|-----|-----|-----|
| Guardian | Shield Bash | [ ] 3타일 돌진 | [ ] 5타일 | [ ] 무제한+스턴 |
| Sentinel | Lance Charge | [ ] 3타일 | [ ] 무제한 | [ ] 브루트 즉사 |
| Ranger | Volley Fire | [ ] 1타일 범위 | [ ] 탄환 증가 | [ ] 관통 |
| Engineer | Deploy Turret | [ ] 1개 | [ ] 2개 | [ ] 3개+슬로우 |
| Bionic | Blink | [ ] 2타일 | [ ] 4타일 | [ ] 6타일+스턴 |

### 9.2 적 AI 테스트
| 적 | 행동 패턴 | 테스트 결과 |
|----|-----------|-------------|
| Rusher | 가장 가까운 대상 공격 | [ ] |
| Gunner | 원거리 유지, 사격 | [ ] |
| Shield Trooper | 정면 실드 | [ ] |
| Jumper | 센티넬 우회 점프 | [ ] |
| Heavy Trooper | 느린 이동, 강한 공격 | [ ] |
| Hacker | 터렛 해킹 시도 | [ ] |
| Brute | 넉백 공격 | [ ] |
| Sniper | 조준 레이저 → 강한 사격 | [ ] |
| Drone Carrier | 드론 스폰 | [ ] |
| Shield Generator | 주변 적 보호막 | [ ] |

### 9.3 Raven 드론 테스트
| 능력 | 효과 | 테스트 결과 |
|------|------|-------------|
| Scout | 다음 웨이브 미리보기 | [ ] |
| Flare | 범위 시야 확보 (10초) | [ ] |
| Resupply | 범위 내 크루 회복 | [ ] |
| Orbital Strike | 범위 피해, 아군 포함 | [ ] |

---

## 10. 밸런스 검증

### 10.1 경제 시뮬레이션
```javascript
BalanceValidator.simulateEconomy('normal', 10)
BalanceValidator.simulateEconomy('hard', 10)
```

예상 결과:
- Normal: 약간 흑자 (여유로운 경제)
- Hard: 타이트한 경제 (신중한 지출 필요)

### 10.2 난이도 스케일링
```javascript
BalanceValidator.analyzeDifficultyScaling()
```

예상 배율:
| 난이도 | 적 체력 | 적 피해 | 적 수 | 크레딧 |
|--------|---------|---------|-------|--------|
| Normal | 1.0x | 1.0x | 1.0x | 1.0x |
| Hard | 1.3x | 1.2x | 1.3x | 0.9x |
| Very Hard | 1.6x | 1.4x | 1.6x | 0.8x |
| Nightmare | 2.0x | 1.6x | 2.0x | 0.7x |

### 10.3 클래스 밸런스
```javascript
BalanceValidator.analyzeClassBalance()
```

각 클래스 DPS, 생존력, 기동성 확인.

---

## 11. 성능 테스트

### 11.1 FPS 측정
전투 중 개발자 도구 Performance 탭:

| 상황 | 목표 FPS | 실제 FPS |
|------|---------|---------|
| 적 0명 | 60 | [ ] |
| 적 10명 | 60 | [ ] |
| 적 30명 | 45+ | [ ] |
| 적 50명 | 30+ | [ ] |

### 11.2 메모리 누수 확인
```javascript
// 10분 플레이 후
performance.memory.usedJSHeapSize / 1024 / 1024
```

---

## 12. 크로스 브라우저 테스트

| 브라우저 | 메뉴 | 전투 | 저장 | 이펙트 |
|---------|------|------|------|--------|
| Chrome | [ ] | [ ] | [ ] | [ ] |
| Firefox | [ ] | [ ] | [ ] | [ ] |
| Edge | [ ] | [ ] | [ ] | [ ] |
| Safari | [ ] | [ ] | [ ] | [ ] |

---

## 13. 버그 리포트 템플릿

```markdown
### 버그 제목
[간단한 설명]

### 재현 단계
1. ...
2. ...
3. ...

### 예상 동작
[어떻게 동작해야 하는지]

### 실제 동작
[실제로 어떻게 동작하는지]

### 환경
- 브라우저:
- 난이도:
- 시드:
- 턴:
- 노드 타입:

### 콘솔 에러 (있다면)
```

### 우선순위
[ ] Critical - 게임 진행 불가
[ ] High - 주요 기능 오작동
[ ] Medium - 부가 기능 문제
[ ] Low - 미미한 문제
```

---

## 14. 최종 체크리스트

### 필수 (Must Have)
- [ ] 새 게임 시작 가능
- [ ] 전투 진입/완료 가능
- [ ] 크루 생존/사망 처리
- [ ] 승리/패배 조건 작동
- [ ] 저장/불러오기 작동
- [ ] 콘솔 에러 없음

### 중요 (Should Have)
- [ ] 모든 5클래스 스킬 작동
- [ ] 모든 적 타입 스폰/AI 작동
- [ ] 업그레이드 시스템 작동
- [ ] Raven 드론 능력 작동
- [ ] 시설 방어 보상 작동
- [ ] 스톰 프론트 진행 작동
- [ ] 메타 진행(해금) 작동

### 권장 (Nice to Have)
- [ ] 시각 효과 정상 (파티클, 플로팅텍스트)
- [ ] 밸런스 적절
- [ ] 성능 최적화
- [ ] 모든 브라우저 지원
- [ ] 설정 저장/적용

---

## 부록: 테스트 시드

| 시드 | 특징 |
|------|------|
| 12345 | 기본 테스트 |
| 99999 | 스트레스 테스트 |
| 11111 | 쉬운 맵 배치 |
| 66666 | 어려운 맵 배치 |
