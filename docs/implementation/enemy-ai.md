# The Fading Raven - Enemy & AI System Documentation

## Overview

Session 3 구현 문서. 15종 적 유형, AI 행동 트리, 웨이브 생성 시스템, 특수 메카닉을 다룹니다.

---

## File Structure

```
demo/js/
├── entities/
│   └── enemy.js          # 적 엔티티 클래스
├── ai/
│   ├── behavior-tree.js  # AI 행동 트리 시스템
│   └── enemy-mechanics.js # 특수 메카닉 관리
└── core/
    └── wave-generator.js # 웨이브 생성 시스템
```

---

## Exposed Interfaces

### EnemyFactory

```javascript
const EnemyFactory = {
    create(enemyId, x, y, difficulty),  // 적 인스턴스 생성
    createBatch(enemyId, positions, difficulty),  // 다중 적 생성
};
```

### Enemy Class

```javascript
class Enemy {
    // Properties
    id              // 고유 ID
    enemyId         // 적 유형 ID
    x, y            // 위치
    health          // 현재 체력
    maxHealth       // 최대 체력
    damage          // 공격력
    speed           // 이동 속도
    state           // 현재 상태 (EnemyState)
    target          // 현재 타겟

    // Methods
    update(deltaTime, context)
    moveTowards(targetX, targetY, deltaTime)
    isInAttackRange(target)
    attack(target)
    useSpecialAbility(context)
    takeDamage(amount, source, damageType)
    applyStun(duration)
    applySlow(multiplier, duration)
    getRenderData()

    // Events
    on(event, callback)
    emit(event, data)
}
```

### AIManager

```javascript
const AIManager = {
    updateEnemy(enemy, context),   // 단일 적 AI 업데이트
    updateAll(enemies, context),   // 모든 적 AI 업데이트
    removeEnemy(enemyId),          // 적 AI 제거
    clear(),                       // 전체 초기화
};
```

### WaveGenerator

```javascript
class WaveGenerator {
    generateWaves(config)          // 스테이지용 웨이브 생성
    generateWave(config)           // 단일 웨이브 생성
    generateBossWave(depth, isStorm, spawnPoints)
    getWavePreview(config)         // 웨이브 미리보기
}
```

### WaveManager

```javascript
class WaveManager {
    initialize(waves)              // 웨이브 초기화
    startNextWave(difficulty)      // 다음 웨이브 시작
    update(deltaTime, difficulty)  // 스폰 업데이트
    isWaveCleared(activeEnemies)   // 웨이브 클리어 확인
    getProgress()                  // 진행 상황

    // Events: waveStart, enemySpawned, waveSpawnComplete, allWavesComplete
}
```

### EnemyMechanicsManager

```javascript
class EnemyMechanicsManager {
    update(deltaTime, context)     // 메카닉 업데이트

    // Hacking
    startHacking(hacker, turret)
    cancelHacking(hackerId)
    isHacking(hackerId)

    // Sniper
    startSniperAiming(sniper, target)
    getSniperLasers()

    // Shields
    isEnemyShielded(enemyId)
    getShieldEffect(enemyId)

    // Drones
    spawnDrones(carrier, context)
    getAllDrones()
    damageDrone(droneId, damage)

    // Explosions
    queueExplosion(data)
}
```

---

## Enemy Types

### Tier 1 (기본)

| ID | 이름 | 행동 | 특수 |
|---|---|---|---|
| `rusher` | 러셔 | melee_basic | - |
| `gunner` | 건너 | ranged_basic | keepDistance |
| `shieldTrooper` | 실드 트루퍼 | melee_shielded | frontalShield |

### Tier 2 (중급)

| ID | 이름 | 행동 | 특수 |
|---|---|---|---|
| `jumper` | 점퍼 | melee_jumper | jumpAttack |
| `heavyTrooper` | 헤비 트루퍼 | melee_heavy | grenadeThrow |
| `hacker` | 해커 | support_hacker | hackTurret |
| `stormCreature` | 폭풍 생명체 | kamikaze | selfDestruct |

### Tier 3 (고급)

| ID | 이름 | 행동 | 특수 |
|---|---|---|---|
| `brute` | 브루트 | melee_brute | heavySwing (cleave) |
| `sniper` | 스나이퍼 | ranged_sniper | sniperShot (laser) |
| `droneCarrier` | 드론 캐리어 | support_carrier | spawnDrones |
| `shieldGenerator` | 실드 제너레이터 | support_shield | aoeShield |

### Boss

| ID | 이름 | 행동 | 특수 |
|---|---|---|---|
| `pirateCaptain` | 해적 대장 | boss_captain | 다중 능력 (버프, 돌진, 소환) |
| `stormCore` | 폭풍 핵 | boss_storm | 무적, 주기적 펄스, 폭풍 생명체 소환 |

---

## Behavior Tree System

### Node Types

#### Composite Nodes
- `SequenceNode` - 순차 실행 (모두 성공해야 성공)
- `SelectorNode` - 선택 실행 (하나 성공하면 성공)
- `ParallelNode` - 병렬 실행
- `RandomSelectorNode` - 랜덤 선택

#### Decorator Nodes
- `InverterNode` - 결과 반전
- `RepeaterNode` - 반복 실행
- `CooldownNode` - 쿨다운 적용

#### Leaf Nodes
- `ConditionNode` - 조건 검사
- `ActionNode` - 행동 실행

### Behavior Patterns

```javascript
// 사용 예시
const tree = BehaviorPatterns.melee_basic();
tree.tick(enemy, context);
```

**Available Patterns:**
- `melee_basic` - 기본 근접
- `melee_shielded` - 실드 근접
- `ranged_basic` - 기본 원거리
- `melee_jumper` - 점퍼 전용
- `melee_heavy` - 헤비 트루퍼 전용
- `melee_brute` - 브루트 전용
- `support_hacker` - 해커 전용
- `ranged_sniper` - 스나이퍼 전용
- `support_carrier` - 드론 캐리어 전용
- `support_shield` - 실드 제너레이터 전용
- `kamikaze` - 폭풍 생명체 전용
- `boss_captain` - 해적 대장 전용
- `boss_storm` - 폭풍 핵 전용

---

## Wave Generation

### Configuration

```javascript
const config = {
    depth: 5,                    // 현재 깊이
    difficulty: 'normal',        // 난이도
    isStormStage: false,         // 폭풍 스테이지 여부
    spawnPoints: [{x, y}, ...],  // 스폰 포인트
    isBossStage: false,          // 보스 스테이지 여부
};

const generator = new WaveGenerator(rng);
const waves = generator.generateWaves(config);
```

### Wave Templates

- **basic_rush** - 러셔 위주 돌격
- **basic_ranged** - 원거리 위주
- **basic_mixed** - 혼합 구성
- **assault** - 점퍼 포함 공격
- **heavy_push** - 헤비 유닛 전진
- **hacker_support** - 해커 지원
- **elite_assault** - 엘리트 공격
- **sniper_cover** - 스나이퍼 엄호
- **drone_swarm** - 드론 스웜
- **storm_basic/mixed** - 폭풍 전용

### Spawn Patterns

- `swarm` - 한 포인트에서 몰려 나옴
- `spread` - 모든 포인트에 분산
- `mixed` - 랜덤 분산
- `assault` - 전선/후방 분리
- `push` - 라인 진형
- `support` - 지원 유닛 후방
- `cover` - 실드 앞, 원거리 뒤
- `boss` - 보스 단독

---

## Special Mechanics Detail

### 1. Hacker - Turret Hacking

```javascript
// Flow
1. Hacker finds nearest turret
2. Moves into hack range (2 tiles)
3. Starts 5-second hack process
4. If interrupted (hacker damaged/moved), hack cancels
5. On completion, turret turns hostile or disables
```

**Events:**
- `hackingStarted` - 해킹 시작
- `hackingProgress` - 진행률 업데이트
- `hackingComplete` - 해킹 완료
- `hackingCanceled` - 해킹 취소

### 2. Sniper - Laser Aiming

```javascript
// Flow
1. Sniper finds highest threat target
2. Stops moving, starts 3-second aim
3. Red laser visible, tracks target
4. If interrupted, aim cancels
5. Fires one-shot-kill damage
```

**Visual:**
- 조준 시 빨간 레이저 표시
- 프로그레스에 따라 레이저 강도 증가

### 3. Drone Carrier - Drone Spawning

```javascript
// Flow
1. Carrier stays back from front line
2. Every 10 seconds, spawns 2 drones
3. Max 6 drones active per carrier
4. Drones auto-attack nearest crew
5. If carrier dies, all drones destroyed
```

**Drone Stats:**
- Health: 1
- Damage: 4
- Speed: 90
- Range: 80

### 4. Shield Generator - AoE Shield

```javascript
// Flow
1. Generator moves to center of allies
2. Provides ranged immunity in 2-tile radius
3. Shield effect shown visually
4. If generator dies, shields removed
```

**Effect:** `rangedImmunity` - 원거리 공격 완전 차단

### 5. Storm Creature - Self Destruct

```javascript
// Flow
1. Rushes towards nearest target
2. When within 30px of target, triggers
3. Explodes with 2-tile radius
4. Deals 20 damage to all in radius
```

### 6. Brute - Cleave Attack

```javascript
// Properties
- cleaveAngle: 120 degrees
- knockbackForce: 3 tiles
- oneHitKill: true (vs normal units)
```

### 7. Heavy Trooper - Grenade

```javascript
// Properties
- grenadeRange: 3 tiles
- grenadeDamage: 15
- grenadeRadius: 1.5 tiles
- cooldown: 8 seconds
```

---

## Integration with Other Sessions

### Session 2 (Combat System) Integration

```javascript
// Combat system should call:
enemy.takeDamage(amount, source, damageType);
enemy.applyStun(duration);
enemy.applySlow(multiplier, duration);

// And listen to:
enemy.on('attack', handleEnemyAttack);
enemy.on('death', handleEnemyDeath);
enemy.on('specialAbility', handleSpecialAbility);
```

### Session 4 (Campaign) Integration

```javascript
// Campaign should use:
const generator = new WaveGenerator(rng);
const waves = generator.generateWaves({
    depth: currentDepth,
    difficulty: selectedDifficulty,
    isStormStage: isStorm,
    spawnPoints: stationSpawnPoints,
    isBossStage: depth % 5 === 0,
});

const waveManager = new WaveManager();
waveManager.initialize(waves);
```

### Session 5 (UI) Integration

**Enemy Render Data:**
```javascript
const renderData = enemy.getRenderData();
// Returns: { x, y, angle, color, size, icon, health, maxHealth, state, ... }
```

**Sniper Lasers:**
```javascript
const lasers = mechanicsManager.getSniperLasers();
// Returns: [{ from, to, progress }, ...]
```

**Shield Visuals:**
```javascript
const shields = mechanicsManager.getShieldVisuals();
// Returns: [{ generatorId, shieldedCount, shieldedIds }, ...]
```

---

## Usage Example

```javascript
// Initialize
const aiManager = new AIManager();
const waveGenerator = new WaveGenerator(gameState.rng.get('enemyWaves'));
const waveManager = new WaveManager();
const mechanicsManager = new EnemyMechanicsManager();

// Generate and start waves
const waves = waveGenerator.generateWaves({
    depth: 5,
    difficulty: 'normal',
    spawnPoints: [{ x: 100, y: 200 }, { x: 300, y: 200 }],
});

waveManager.initialize(waves);
waveManager.startNextWave('normal');

// Game loop
function update(deltaTime) {
    const context = {
        deltaTime,
        crews: activeCrew,
        enemies: activeEnemies,
        turrets: activeTurrets,
        station: currentStation,
    };

    // Spawn enemies
    const spawned = waveManager.update(deltaTime, 'normal');
    activeEnemies.push(...spawned);

    // Update enemy AI
    aiManager.updateAll(activeEnemies, context);

    // Update special mechanics
    mechanicsManager.update(deltaTime, context);

    // Update each enemy
    for (const enemy of activeEnemies) {
        enemy.update(deltaTime, context);
    }

    // Check wave clear
    if (waveManager.isWaveCleared(activeEnemies)) {
        if (!waveManager.isAllWavesComplete()) {
            waveManager.startNextWave('normal');
        } else {
            // Stage complete
        }
    }
}
```

---

## Constants Reference

### EnemyState
```javascript
SPAWNING, IDLE, MOVING, ATTACKING, USING_ABILITY, STUNNED, DYING, DEAD
```

### NodeState (Behavior Tree)
```javascript
SUCCESS, FAILURE, RUNNING
```

---

## Performance Notes

1. **Behavior Trees** - 캐시됨, 적당 하나의 트리 인스턴스
2. **Shield Updates** - 매 프레임이 아닌 변경 시에만
3. **Drone Updates** - 캐리어별 드론 그룹화로 효율적 관리
4. **Targeting** - O(n) 검색, 큰 적 수에서 최적화 필요시 공간 분할 고려

---

## Version

- Session 3 Implementation
- Date: 2026-02-03
- Status: Complete
