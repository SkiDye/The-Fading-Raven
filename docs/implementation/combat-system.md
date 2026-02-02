# Combat System - API Documentation

## Overview

The Fading Raven 전투 시스템은 타일 기반 실시간 전술 전투를 구현합니다.

### 핵심 모듈

| 모듈 | 파일 | 역할 |
|------|------|------|
| TileGrid | `js/core/tile-grid.js` | 타일 그리드, 경로 탐색, 시야선 |
| SkillSystem | `js/core/skills.js` | 크루 스킬 실행 및 쿨다운 |
| EquipmentEffects | `js/core/equipment-effects.js` | 장비 패시브/액티브 효과 |
| TurretSystem | `js/entities/turret.js` | 자동 타겟팅 터렛 |
| RavenSystem | `js/core/raven.js` | Raven 드론 지원 능력 |
| BattleController | `js/pages/battle.js` | 전투 컨트롤러 (통합) |

---

## TileGrid

타일 기반 그리드 시스템으로 경로 탐색(A*)과 시야선 계산을 제공합니다.

### 타일 타입

```javascript
TileGrid.TILE_FLOOR   // 바닥 - 이동 가능
TileGrid.TILE_WALL    // 벽 - 이동/시야 차단
TileGrid.TILE_COVER   // 엄폐물 - 이동 가능, 피해 감소
TileGrid.TILE_SPAWN   // 스폰 지점
TileGrid.TILE_DEPLOY  // 배치 지점
```

### 주요 API

```javascript
// 초기화
TileGrid.init(layout)                    // 레이아웃 데이터로 초기화
TileGrid.createEmpty(width, height)      // 빈 그리드 생성

// 타일 조회/설정
TileGrid.getTile(x, y)                   // 타일 객체 반환
TileGrid.setTile(x, y, type)             // 타일 타입 변경
TileGrid.isWalkable(x, y)                // 이동 가능 여부
TileGrid.isValid(x, y)                   // 유효 좌표 여부

// 좌표 변환
TileGrid.pixelToTile(px, py, offsetX, offsetY)
TileGrid.tileToPixel(tx, ty, offsetX, offsetY)

// 경로 탐색 (A*)
TileGrid.findPath(startX, startY, endX, endY, options)
// options: { allowDiagonal, avoidOccupied, maxIterations }

// 시야선
TileGrid.hasLineOfSight(x1, y1, x2, y2)
TileGrid.hasLineOfSightPixel(px1, py1, px2, py2, offsetX, offsetY)
TileGrid.getVisibleTiles(centerX, centerY, maxRange)

// 범위 조회
TileGrid.getTilesInRange(centerX, centerY, range, options)
TileGrid.getTilesAlongLine(x1, y1, x2, y2)
TileGrid.getTilesInCone(originX, originY, direction, range, angleWidth)

// 엄폐 확인
TileGrid.hasCover(attackerX, attackerY, targetX, targetY)
// 반환: { hasCover: boolean, reduction: number }
```

---

## SkillSystem

크루별 고유 스킬의 실행과 쿨다운을 관리합니다.

### 스킬 목록

| 클래스 | 스킬 ID | 스킬명 | 타입 |
|--------|---------|--------|------|
| Guardian | `shieldBash` | 실드 배쉬 | direction |
| Sentinel | `lanceCharge` | 랜스 차지 | direction |
| Ranger | `volleyFire` | 볼리 파이어 | position |
| Engineer | `deployTurret` | 터렛 배치 | position |
| Bionic | `blink` | 블링크 | position |

### 주요 API

```javascript
// 초기화
SkillSystem.initCrew(crew)               // 크루 스킬 등록
SkillSystem.reset()                      // 모든 상태 초기화

// 스킬 사용
SkillSystem.isSkillReady(crewId)         // 사용 가능 여부
SkillSystem.useSkill(crew, target, battle)
// 반환: { success: boolean, reason?: string, ... }

// 쿨다운 조회
SkillSystem.getCooldownPercent(crewId)   // 0-1 쿨다운 비율
SkillSystem.getRemainingCooldown(crewId) // 남은 초

// 정보 조회
SkillSystem.getSkillInfo(crewId)
// 반환: { id, name, type, ready, cooldownPercent, level, effects }

SkillSystem.getTargetingInfo(crewId)
// 반환: { type, range, radius }

// 업데이트
SkillSystem.update(dt)                   // 쿨다운 감소
```

### 스킬 레벨별 효과

각 스킬은 1-3 레벨까지 업그레이드 가능합니다.

```javascript
// 예: Shield Bash 효과
skill.getEffects(1) // { distance: 3, knockback: 1, damage: 1.0, stun: 0 }
skill.getEffects(2) // { distance: 5, knockback: 1.5, damage: 1.2, stun: 0 }
skill.getEffects(3) // { distance: -1, knockback: 2, damage: 1.5, stun: 2 }
// distance: -1 = 무제한
```

---

## EquipmentEffects

장비의 패시브/액티브 효과를 관리합니다.

### 장비 타입

- `passive`: 상시 적용 (Command Module, Stim Pack, Salvage Core)
- `active_cooldown`: 쿨다운 기반 (Shock Wave, Shield Generator)
- `active_charges`: 충전 기반 (Frag Grenade, Proximity Mine, Rally Horn, Revive Kit, Hacking Device)

### 주요 API

```javascript
// 초기화
EquipmentEffects.initCrew(crew, battle)  // 크루 장비 등록
EquipmentEffects.resetForBattle()        // 전투 시작 시 초기화
EquipmentEffects.reset()                 // 전체 초기화

// 장비 사용
EquipmentEffects.canUse(crewId)          // 사용 가능 여부
EquipmentEffects.use(crew, target, battle)
// 반환: { success: boolean, reason?: string, ... }

// 상태 조회
EquipmentEffects.getState(crewId)
EquipmentEffects.getCooldownPercent(crewId)
EquipmentEffects.getCharges(crewId)

// 패시브 효과 조회
EquipmentEffects.getStatModifiers(crewId)
// 반환: { squadSizeBonus?, attackSpeedMultiplier?, bonusCredits?, ... }

// 보너스 크레딧 계산 (Salvage Core)
EquipmentEffects.calculateBonusCredits(deployedCrews)

// 업데이트
EquipmentEffects.update(dt, battle)      // 쿨다운, 지뢰, 실드 업데이트
```

---

## TurretSystem

자동 타겟팅 터렛을 관리합니다. 해커에 의해 해킹될 수 있습니다.

### 주요 API

```javascript
// 생성/삭제
TurretSystem.create(options)
// options: { id?, ownerId, x, y, health, damage, range, attackSpeed, slow, slowAmount, slowDuration }
TurretSystem.remove(turretId)
TurretSystem.clear()

// 조회
TurretSystem.get(turretId)
TurretSystem.getByOwner(ownerId)
TurretSystem.getAll()
TurretSystem.getFriendly()               // 해킹되지 않은 터렛
TurretSystem.getHostile()                // 해킹된 터렛

// 해킹
TurretSystem.canBeHacked(turretId)
TurretSystem.startHack(turretId, hackerId, hackTime)
TurretSystem.updateHack(turretId, dt)    // 반환: { complete, progress? }
TurretSystem.cancelHack(turretId)
TurretSystem.getHackableInRange(x, y, range)

// 피해
TurretSystem.damage(turretId, amount, battle)

// 업데이트/렌더링
TurretSystem.update(dt, battle)
TurretSystem.render(ctx, battle)

// 저장/로드
TurretSystem.export()
TurretSystem.import(turretData)
```

### 터렛 상태

```javascript
turret = {
    id, ownerId, x, y,
    health, maxHealth, damage, range, attackSpeed,
    attackTimer, targetId, rotation,
    isHacked,           // 해킹 여부
    beingHacked,        // 해킹 진행 중
    hackProgress,       // 해킹 진행도
    slow,               // 슬로우 적용 여부
    slowAmount,         // 슬로우 비율 (0.5 = 50%)
    slowDuration,       // 슬로우 지속시간 (ms)
}
```

---

## RavenSystem

Raven 모함의 지원 드론 능력을 관리합니다.

### 능력 목록

| ID | 이름 | 효과 | 최대 사용 |
|----|------|------|----------|
| `scout` | 정찰 | 영역 시야 확보, 적 마킹 | 3 |
| `flare` | 조명탄 | 넓은 영역 조명, 은신 해제 | 2 |
| `resupply` | 보급 | 체력 회복, 장비 충전 보충 | 2 |
| `orbitalStrike` | 궤도 폭격 | 대규모 피해, 엄폐물 파괴 | 1 |

### 주요 API

```javascript
// 초기화
RavenSystem.init(difficulty)             // 난이도별 사용 횟수 조정
RavenSystem.reset(difficulty)

// 능력 사용
RavenSystem.canUse(abilityId)
RavenSystem.useAbility(abilityId, target, battle)
// 반환: { success: boolean, reason?: string, ... }

// 정보 조회
RavenSystem.getAbilityInfo(abilityId)
// 반환: { id, name, icon, usesRemaining, cooldown, cooldownPercent, ready, ... }
RavenSystem.getAllAbilities()

// 남은 횟수/쿨다운
RavenSystem.getRemainingUses(abilityId)
RavenSystem.getCooldown(abilityId)

// 가시성 확인
RavenSystem.isPositionRevealed(x, y)     // Scout/Flare 영역 내 여부
RavenSystem.getVisibilityBonus(x, y)     // 명중률 보너스 (0-0.2)

// 업데이트/렌더링
RavenSystem.update(dt, battle)
RavenSystem.render(ctx, battle)
```

---

## BattleController

전투 시스템을 통합 관리하는 메인 컨트롤러입니다.

### 시간 제어

```javascript
// 슬로우 모션
BattleController.activateSlowMotion(duration)   // ms
BattleController.deactivateSlowMotion()
BattleController.SLOW_MOTION_SCALE              // 0.3 (30% 속도)

// 화면 흔들림
BattleController.screenShake(amount, duration)
```

### 타겟팅 모드

```javascript
// 스킬/장비/Raven 능력 타겟팅 시작
BattleController.startSkillTargeting(crew)
BattleController.startEquipmentTargeting(crew)
BattleController.startRavenTargeting(abilityId)

// 타겟팅 취소
BattleController.cancelTargeting()

// 타겟팅 실행
BattleController.executeTargetedAction(x, y)
```

### 크루 이동

```javascript
// A* 경로 탐색을 사용한 이동
BattleController.moveCrewTo(crew, x, y)
```

### 주요 콜백

```javascript
// 효과 추가
BattleController.addEffect(effect)
// effect: { type, x, y, duration, timer, ... }

// 데미지 숫자 표시
BattleController.addDamageNumber(x, y, damage, isCrewDamage)
```

---

## 상태 효과 (Status Effects)

### 크루 상태

```javascript
crew.invulnerable       // 무적 (Blink 사용 후)
crew.invulnerableTimer
crew.shielded           // 보호막 (Shield Generator)
crew.shieldTimer
crew.shieldReduction    // 피해 감소율
crew.shieldReflect      // 투사체 반사
crew.stunned            // 기절
crew.stunTimer
```

### 적 상태

```javascript
enemy.stunned           // 기절
enemy.stunTimer
enemy.slowed            // 감속
enemy.slowTimer
enemy.slowAmount        // 이동 속도 배율
enemy.marked            // 마킹 (Scout)
enemy.markTimer
enemy.illuminated       // 조명 (Flare)
enemy.illuminatedTimer
```

---

## 통합 예시

```javascript
// 전투 시작 시 초기화
SkillSystem.reset();
EquipmentEffects.reset();
TurretSystem.clear();
RavenSystem.init('normal');

// 크루 등록
crews.forEach(crew => {
    SkillSystem.initCrew(crew);
    EquipmentEffects.initCrew(crew, battle);
});

// 매 프레임 업데이트
function update(dt) {
    SkillSystem.update(dt);
    EquipmentEffects.update(dt, battle);
    TurretSystem.update(dt, battle);
    RavenSystem.update(dt, battle);
}

// 스킬 사용
if (SkillSystem.isSkillReady(crew.id)) {
    const result = SkillSystem.useSkill(crew, target, battle);
    if (result.success) {
        console.log('스킬 사용 성공');
    }
}

// 경로 탐색
const path = TileGrid.findPath(startX, startY, endX, endY);
if (path.length > 0) {
    crew.path = path.slice(1);
    crew.state = 'moving';
}
```

---

## Session 2 완료 파일

- `demo/js/core/tile-grid.js` - 타일 그리드 시스템
- `demo/js/core/skills.js` - 스킬 시스템
- `demo/js/core/equipment-effects.js` - 장비 효과 시스템
- `demo/js/core/raven.js` - Raven 드론 시스템
- `demo/js/entities/turret.js` - 터렛 시스템
- `demo/js/pages/battle.js` - 전투 컨트롤러 (리팩토링)
- `docs/implementation/combat-system.md` - 본 문서
