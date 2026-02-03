# The Fading Raven - Implementation Shared State

> **Last Updated:** 2026-02-03
> **Total JS Files:** 44
> **Total Lines Added (Today):** 42,259

## Progress Status

- [x] Session 1: Data & Core Systems (+ Extended: Utils, RNG, MultiTab)
- [x] Session 2: Combat System
- [x] Session 3: Enemies & AI (+ CrewAI)
- [x] Session 4: Campaign System (+ Extended: Combat Phases 1-3)
- [x] Session 5: UI & Polish (+ Extended: Bad North Combat)
- [x] Session 6: 2.5D Isometric Rendering System

---

## Session 1 Status
- Started: 2026-02-03
- Completed: 2026-02-03
- Assigned Files:
  - `demo/js/data/crews.js`
  - `demo/js/data/equipment.js`
  - `demo/js/data/traits.js`
  - `demo/js/data/enemies.js`
  - `demo/js/data/facilities.js`
  - `demo/js/data/balance.js`
  - `demo/js/core/game-state.js` (extended)

### Exposed Interfaces

```javascript
// CrewData - demo/js/data/crews.js
const CrewData = {
    getClass(classId),           // Returns class definition
    getSkill(classId, level),    // Returns skill at level
    getAllClasses(),             // Returns all class IDs
    getClassColor(classId),      // Returns class color
};

// EquipmentData - demo/js/data/equipment.js
const EquipmentData = {
    get(equipmentId),            // Returns equipment definition
    getAll(),                    // Returns all equipment
    getUpgradeCost(equipmentId, level),
    getEffect(equipmentId, level),
};

// TraitData - demo/js/data/traits.js
const TraitData = {
    get(traitId),                // Returns trait definition
    getAll(),                    // Returns all traits
    getEffect(traitId),          // Returns trait effect values
    getRandomTrait(rng),         // Returns random trait using RNG
};

// EnemyData - demo/js/data/enemies.js
const EnemyData = {
    get(enemyId),                // Returns enemy definition
    getByTier(tier),             // Returns enemies in tier
    getAll(),                    // Returns all enemies
    getBehaviorId(enemyId),      // Returns behavior pattern ID
};

// FacilityData - demo/js/data/facilities.js
const FacilityData = {
    get(facilityId),             // Returns facility definition
    getAll(),                    // Returns all facilities
    getCredits(facilityId),      // Returns credit value
    getEffect(facilityId),       // Returns facility effect
};

// BalanceData - demo/js/data/balance.js
const BalanceData = {
    getDifficultyMultiplier(difficulty, stat),
    getWaveConfig(depth, difficulty),
    getEconomyConfig(),
    getCombatConfig(),
    // Session 5 Extended - Bad North Combat ⭐
    calculateRecoveryTime(squadSize, hasQuickRecovery),
    calculateLandingKnockback(config),
    getBoatSizeCategory(enemyCount),
    checkShieldBlock(config),
    checkLanceState(distanceToEnemy),
    isInMeleeCombat(distanceToEnemy),
    getCombatState(config),
    getUnitGradeStats(grade),
    applyGradeModifier(baseStat, grade, statType),
    getWavePattern(depth, difficultyId),
    getSpawnTiming(timingType),
    checkVoidDeath(position, tileGrid, unitGrade),
    getHazardTileDamage(hazardType),
};
```

---

## Session 2 Status
- Started: 2026-02-03
- Completed: 2026-02-03
- Assigned Files:
  - `demo/js/core/tile-grid.js` (new)
  - `demo/js/core/skills.js` (new)
  - `demo/js/core/equipment-effects.js` (new)
  - `demo/js/core/raven.js` (new)
  - `demo/js/entities/turret.js` (new)
  - `demo/js/pages/battle.js` (refactored)
  - `docs/implementation/combat-system.md` (new)

### Exposed Interfaces

```javascript
// TileGrid - demo/js/core/tile-grid.js
const TileGrid = {
    init(layout),                    // Initialize from layout
    getTile(x, y),                   // Get tile at position
    isWalkable(x, y),                // Check walkability
    findPath(startX, startY, endX, endY, options), // A* pathfinding
    hasLineOfSight(x1, y1, x2, y2),  // Line of sight check
    pixelToTile(px, py, offsetX, offsetY),
    tileToPixel(tx, ty, offsetX, offsetY),
    getTilesInRange(centerX, centerY, range, options),
    hasCover(attackerX, attackerY, targetX, targetY),
};

// SkillSystem - demo/js/core/skills.js
const SkillSystem = {
    initCrew(crew),                  // Register crew skill
    isSkillReady(crewId),            // Check if skill ready
    useSkill(crew, target, battle),  // Execute skill
    getCooldownPercent(crewId),      // Get cooldown 0-1
    getSkillInfo(crewId),            // Get skill display info
    getTargetingInfo(crewId),        // Get targeting params
    update(dt),                      // Update cooldowns
    reset(),                         // Clear all state
};

// EquipmentEffects - demo/js/core/equipment-effects.js
const EquipmentEffects = {
    initCrew(crew, battle),          // Register crew equipment
    canUse(crewId),                  // Check if can use
    use(crew, target, battle),       // Use equipment
    getState(crewId),                // Get equipment state
    getCooldownPercent(crewId),      // Get cooldown 0-1
    getCharges(crewId),              // Get remaining charges
    getStatModifiers(crewId),        // Get passive bonuses
    calculateBonusCredits(crews),    // Salvage Core bonus
    update(dt, battle),              // Update cooldowns/effects
    resetForBattle(),                // Reset for new battle
    reset(),                         // Clear all state
};

// TurretSystem - demo/js/entities/turret.js
const TurretSystem = {
    create(options),                 // Create turret
    remove(turretId),                // Remove turret
    get(turretId),                   // Get turret by ID
    getByOwner(ownerId),             // Get turrets by owner
    canBeHacked(turretId),           // Check if hackable
    startHack(turretId, hackerId, hackTime),
    updateHack(turretId, dt),        // Returns {complete, progress}
    cancelHack(turretId),
    damage(turretId, amount, battle),
    update(dt, battle),              // Update all turrets
    render(ctx, battle),             // Render all turrets
    clear(),                         // Clear all turrets
};

// RavenSystem - demo/js/core/raven.js
const RavenSystem = {
    init(difficulty),                // Initialize with difficulty
    canUse(abilityId),               // Check if ability ready
    useAbility(abilityId, target, battle), // Execute ability
    getAbilityInfo(abilityId),       // Get ability info
    getAllAbilities(),               // Get all abilities
    getRemainingUses(abilityId),     // Get remaining uses
    getCooldown(abilityId),          // Get current cooldown
    isPositionRevealed(x, y),        // Check if in scout/flare
    getVisibilityBonus(x, y),        // Get accuracy bonus 0-0.2
    update(dt, battle),              // Update effects
    render(ctx, battle),             // Render drone & effects
    reset(difficulty),               // Reset for new battle
};
```

---

## Session 4 Status
- Started: 2026-02-03
- Completed: 2026-02-03
- Assigned Files:
  - `demo/js/core/sector-generator.js` (new)
  - `demo/js/core/station-generator.js` (new)
  - `demo/js/core/meta-progress.js` (new)
  - `demo/js/pages/sector.js` (improved)

### Exposed Interfaces

```javascript
// SectorGenerator - demo/js/core/sector-generator.js
const SectorGenerator = {
    generate(rng, difficulty),       // Returns sector map object
    visitNode(sectorMap, nodeId),    // Visit a node
    advanceStormFront(sectorMap),    // Advance storm
    updateAccessibility(sectorMap),  // Update node access
    hasPathToGate(sectorMap),        // Check path exists
    getNodesAtRisk(sectorMap),       // Get endangered nodes
    getStats(sectorMap),             // Get map statistics
    NODE_TYPES,                      // Node type constants
};

// StationGenerator - demo/js/core/station-generator.js
const StationGenerator = {
    generate(rng, difficultyScore),  // Returns station layout
    isWalkable(layout, x, y),        // Check walkability
    findPath(layout, x1, y1, x2, y2),// A* pathfinding
    getTile(layout, x, y),           // Get tile type
    getFacilityAt(layout, x, y),     // Get facility at pos
    toAscii(layout),                 // Debug output
    TILE,                            // Tile type constants
    FACILITY_TYPE,                   // Facility constants
};

// MetaProgress - demo/js/core/meta-progress.js
const MetaProgress = {
    isClassUnlocked(classId),
    isEquipmentUnlocked(equipmentId),
    isTraitUnlocked(traitId),
    isDifficultyUnlocked(difficulty),
    processRunCompletion(runData),   // Returns {newUnlocks, newAchievements}
    getUnlockedClasses(),
    getUnlockedEquipment(),
    getStats(),
    getCampaignTraitPool(rng, count),
};
```

---

## Session 1 Extended - Core Utilities

### Utils Module (`demo/js/core/utils.js`)

```javascript
const Utils = {
    // 기존 유틸리티
    clamp(value, min, max),
    lerp(a, b, t),
    distance(x1, y1, x2, y2),
    formatNumber(num),
    formatTime(seconds),
    generateId(),
    shuffle(array, rng),
    deepClone(obj),

    // L-006: 모듈 검증 API (NEW)
    validateRequiredModules(modules, options),  // { valid, missing }
    waitForModules(modules, timeout),           // Promise<boolean>
    getCoreDataModules(),      // ['CrewData', 'EquipmentData', ...]
    getCoreSystemModules(),    // ['GameState', 'Utils', 'SeedUtils']
};
```

### Seeded RNG (`demo/js/core/rng.js`)

```javascript
class SeededRNG {
    constructor(seed),
    random(),                  // 0-1 float
    range(min, max),           // inclusive integer
    rangeFloat(min, max),      // float range
    pick(array),               // random element
    shuffle(array),            // in-place shuffle
    chance(probability),       // boolean
    weighted(weights),         // weighted random index
    gaussian(mean, stddev),    // normal distribution
}

const SeedUtils = {
    generateSeed(),            // Random seed string
    parseSeed(seedString),     // Parse to number
    formatSeed(seedNumber),    // Format to display string
    validateSeed(seedString),  // Check validity
};
```

### GameState Extended (`demo/js/core/game-state.js`)

```javascript
const GameState = {
    // 기존 상태 관리...

    // L-007: 멀티탭 감지 (NEW)
    TAB_KEY: 'theFadingRaven_activeTab',
    tabId: null,
    isActiveTab: true,
    initMultiTabDetection(),
    registerTab(),
    handleStorageChange(event),
    emitEvent(eventName, detail),
};
```

---

## Session 3 Status
- Started: 2026-02-03
- Completed: 2026-02-03
- Issues Fixed: 2026-02-03 (9개 이슈 자체 수정 완료, SESSION-3-ISSUES.md 참조)
- Assigned Files:
  - `demo/js/entities/enemy.js` (new)
  - `demo/js/ai/behavior-tree.js` (new)
  - `demo/js/ai/enemy-mechanics.js` (new)
  - `demo/js/core/wave-generator.js` (new)

### Exposed Interfaces

```javascript
// EnemyFactory - demo/js/entities/enemy.js
const EnemyFactory = {
    create(enemyId, x, y, difficulty),  // Returns Enemy instance
    createBatch(enemyId, positions, difficulty),
};

// Enemy class methods
class Enemy {
    update(deltaTime, context),
    moveTowards(targetX, targetY, deltaTime),
    attack(target),
    takeDamage(amount, source, damageType),
    applyStun(duration),
    getRenderData(),
    on(event, callback),
}

// AIManager - demo/js/ai/behavior-tree.js (클래스)
// 사용 시 인스턴스 생성 필요: const aiManager = new AIManager();
class AIManager {
    constructor(),
    updateEnemy(enemy, context),
    updateAll(enemies, context),
    removeEnemy(enemyId),
    clear(),
}

// WaveGenerator - demo/js/core/wave-generator.js
class WaveGenerator {
    generateWaves(config),      // Returns waves array
    generateWave(config),
    generateBossWave(depth, isStorm, spawnPoints),
    getWavePreview(config),
}

// WaveManager - demo/js/core/wave-generator.js
class WaveManager {
    initialize(waves),
    startNextWave(difficulty),
    update(deltaTime, difficulty), // Returns spawned enemies
    isWaveCleared(activeEnemies),
    getProgress(),
    on(event, callback),
}

// EnemyMechanicsManager - demo/js/ai/enemy-mechanics.js
class EnemyMechanicsManager {
    update(deltaTime, context),
    startHacking(hacker, turret),
    cancelHacking(hackerId),
    startSniperAiming(sniper, target),
    getSniperLasers(),
    isEnemyShielded(enemyId),
    spawnDrones(carrier, context),
    getAllDrones(),
    queueExplosion(data),
}

// CrewAI - demo/js/ai/crew-ai.js (NEW)
const CrewAI = {
    classProfiles: {
        guardian: { preferredRange: 'melee', positioning: 'frontline', ... },
        sentinel: { preferredRange: 'melee', positioning: 'frontline', ... },
        ranger: { preferredRange: 'ranged', positioning: 'backline', optimalRange: 150, ... },
        engineer: { preferredRange: 'ranged', positioning: 'support', ... },
        bionic: { preferredRange: 'melee', positioning: 'flanker', ... },
    },

    enable(crewId),              // AI 활성화
    disable(crewId),             // AI 비활성화
    isEnabled(crewId),           // AI 활성화 여부
    enableAll(crews),            // 전체 AI 활성화
    disableAll(),                // 전체 AI 비활성화

    update(crew, context),       // 크루 AI 업데이트
    assessThreats(crew, enemies),// 위협 평가
    selectTarget(crew, threats), // 타겟 선택
    shouldUseSkill(crew, context),// 스킬 사용 여부
    getOptimalPosition(crew, context), // 최적 위치
    shouldRetreat(crew, threats),// 후퇴 여부
};
```

---

## Session 5 Status
- Started: 2026-02-03
- Completed: 2026-02-03
- Extended: 2026-02-03 (Bad North 전투 메카닉 추가)
- Assigned Files:
  - `demo/js/ui/ui-components.js` (new)
  - `demo/js/ui/effects.js` (new)
  - `demo/js/ui/hud.js` (new)
  - `demo/js/ui/battle-effects-integration.js` (new)
  - `demo/js/core/combat-mechanics.js` (new) ⭐
  - `demo/js/data/balance.js` (extended) ⭐
  - `demo/js/pages/battle.js` (grade scaling) ⭐
  - `demo/js/pages/result.js` (bug fixes) ⭐
  - `demo/css/ui-components.css` (new)
  - `demo/css/effects.css` (new)
  - `demo/css/hud.css` (new)
  - `demo/pages/settings.html` (improved)
  - `demo/pages/battle.html` (integrated)
  - `demo/js/pages/settings.js` (improved)
  - `demo/css/pages/panel.css` (extended)
  - `docs/implementation/ui-components.md` (new)
  - `docs/implementation/SESSION-5-ISSUES.md` (updated) ⭐

### Exposed Interfaces

```javascript
// Tooltip - demo/js/ui/ui-components.js
const Tooltip = {
    showAt(x, y, title, content),
    hide(),
};

// Toast - demo/js/ui/ui-components.js
const Toast = {
    show(message, type, duration),
    info(message), success(message), warning(message), error(message),
};

// ModalManager - demo/js/ui/ui-components.js
const ModalManager = {
    open(options),              // Returns modal ID
    close(id),
    closeAll(),
    confirm(message, onConfirm, onCancel),
    alert(message, onOk),
};

// ProgressBar - demo/js/ui/ui-components.js
const ProgressBar = {
    create(options),            // Returns HTMLElement
    update(container, value, max),
    setColor(container, color),
};

// Loading - demo/js/ui/ui-components.js
const Loading = {
    show(text),
    hide(),
    wrap(promise, text),        // Returns Promise
};

// ScreenEffects - demo/js/ui/effects.js
const ScreenEffects = {
    shake(options),
    flash(options),
    damage(intensity),          // 'light' | 'medium' | 'heavy'
    heal(), criticalHit(), explosion(),
};

// TransitionEffects - demo/js/ui/effects.js
const TransitionEffects = {
    fade(callback, options),
    slide(callback, direction, duration),
};

// ElementAnimations - demo/js/ui/effects.js
const ElementAnimations = {
    pulse(element, options),
    wiggle(element, options),
    bounce(element, options),
    fadeIn(element, duration),
    fadeOut(element, duration),
    slideIn(element, direction, duration),
    typeText(element, text, options),
    countUp(element, from, to, options),
};

// ParticleSystem - demo/js/ui/effects.js
const ParticleSystem = {
    emit(x, y, options),
    explosion(x, y, color),
    sparkle(x, y),
    credits(x, y),
    damage(x, y),
};

// FloatingText - demo/js/ui/effects.js
const FloatingText = {
    show(x, y, text, options),
    damage(x, y, amount),
    heal(x, y, amount),
    critical(x, y, amount),
    miss(x, y),
    credits(x, y, amount),
};

// HUD - demo/js/ui/hud.js
const HUD = {
    init(containerSelector),
    updateWave(current, total),
    updateEnemyCount(count),
    updateFacilities(facilities),
    updateCredits(amount, animate),
    updateCrews(crews),
    selectCrew(crewId),
    announceWave(waveNum, subtitle),
    alert(message, type, duration),
    show(), hide(),
    // Callbacks
    onCrewSelect, onSkillUse, onEquipmentUse, onPauseToggle, onSpeedChange,
};

// CombatMechanics - demo/js/core/combat-mechanics.js ⭐ NEW
const CombatMechanics = {
    // Coordinate utilities (isometric compatible)
    getUnitTilePosition(unit, tileGrid),
    getUnitHeight(unit, stationLayout),
    getKnockbackDirection(attacker, defender),
    knockbackPxToTiles(knockbackPx),

    // Landing knockback (Bad North)
    applyLandingKnockback(crew, spawnData),
    wouldFallIntoVoid(unit, knockbackPx, angle, tileGrid),
    isHeightBlocked(fromX, fromY, toX, toY, stationLayout),

    // Shield mechanics (Guardian)
    calculateShieldedDamage(defender, attacker, baseDamage, attackType),

    // Lance mechanics (Sentinel)
    updateLanceState(sentinel, enemies),
    checkLanceEscapeOptions(sentinel, enemies),

    // Recovery system
    calculateRecoveryTime(crew),
    canStartRecovery(crew, facility),
    handleRecoveryInterruption(crew, facility),

    // Void knockback combo
    processKnockbackWithVoidCheck(unit, knockbackPx, angle, tileGrid),
    findNearestEdgeTile(startTile, targetX, targetY, tileGrid),
    attemptLedgeRescue(unit, rescuer),

    // Unit grade scaling
    calculateGradeScaledDamage(attacker, defender, baseDamage),
    getGradeScaledMoveSpeed(unit, baseSpeed),
    getGradeScaledAttackSpeed(unit, baseAttackSpeed),
    checkMorale(crew),
    getMaxSquadSize(grade),

    // Utilities
    getDistanceBetween(unit1, unit2, useTiles),
    getTileDistance(unit1, unit2),
    getAngleBetween(unit1, unit2, useTiles),
    getFullCombatState(crew, enemies),
};
```

### Completed (Phase 2 - Combat Integration)
- [x] battle-effects-integration.js로 전투 이펙트 시스템 통합
- [x] FloatingText, ParticleSystem, ScreenEffects를 전투에 연결
- [x] 설정 화면 완성 (접근성 옵션 포함)

### Completed (Phase 3 - Bad North Combat Mechanics) ⭐ NEW
- [x] Landing Knockback System (상륙 넉백)
- [x] Shield Mechanics - Guardian 실드 (근접전 비활성)
- [x] Lance Raise - Sentinel 랜스 들어올림 (공격 불가)
- [x] Recovery Time Formula (2초 × 분대원 수)
- [x] Unit Grade Combat Scaling (standard/veteran/elite)
- [x] Void Knockback Combo (우주 추락 즉사 + 절벽 잡기)
- [x] Wave Progression Patterns (early/mid/late/boss)
- [x] Isometric System Compatibility (좌표계 연동)
- [x] battle.js Grade Scaling Integration (이동/공격속도)

### Bug Fixes (Session 5 Extended) ⭐ NEW
- [x] result.js: `sectorMap` iteration error (map is not iterable)
- [x] result.js: `currentNode.row` → `currentNode.depth`
- [x] result.js: `sectorMap.length` → `sectorMap.totalDepth`

### Future Enhancements
- Raven 능력 시각 효과 추가
- 사운드 시스템 통합
- Flee System (사기 붕괴 시 도주)
- Visual Threat Hints (위협 시각화)

---

## Integration Status (Session 4)

### Completed
- [x] **Deploy 페이지 통합** (`demo/js/pages/deploy.js`)
  - StationGenerator 연동 (procedural layout generation)
  - 레이아웃 형식 변환 (_convertLayout)
  - 배치 영역 생성 (_createDeploymentZones)

- [x] **Battle 시스템 통합** (`demo/js/pages/battle.js`)
  - WaveGenerator/WaveManager 연동
  - 새 타일 타입 렌더링 (ELEVATED, LOWERED, CORRIDOR, FACILITY)
  - 시설 렌더링 (credit values 표시)
  - 스폰 포인트 방향 표시

- [x] **Result 페이지 통합** (`demo/js/pages/result.js`)
  - MetaProgress 연동 (processRunCompletion)
  - 새로운 해금 표시 (newUnlocks, newAchievements)
  - 새 노드 타입 지원 (storm, commander)
  - 보너스 크레딧 표시 (Salvage Core, 시설 방어)

- [x] **Upgrade 페이지 개선** (`demo/js/pages/upgrade.js`)
  - EquipmentData 통합 (getAvailableEquipment)
  - TraitData 통합 (getTraitName, getTraitDescription)
  - MetaProgress 연동 (isEquipmentUnlocked)
  - 장비 희귀도 정렬

---

## Dependency Graph

```
Session 1 (Data)
    |
    v
Session 2 (Combat) <--> Session 3 (Enemies/AI)
    |                      |
    v                      v
Session 4 (Campaign) <-----+
    |
    v
Session 5 (UI/Polish)
```

---

## Shared Constants

### Class IDs
- `guardian`
- `sentinel`
- `ranger`
- `engineer`
- `bionic`

### Equipment IDs
- `commandModule`
- `shockWave`
- `fragGrenade`
- `proximityMine`
- `rallyHorn`
- `reviveKit`
- `stimPack`
- `salvageCore`
- `shieldGenerator`
- `hackingDevice`

### Trait IDs
- Combat: `sharpEdge`, `heavyImpact`, `titanFrame`, `reinforcedArmor`, `steadyStance`, `fearless`
- Utility: `energetic`, `swiftMovement`, `popular`, `quickRecovery`, `techSavvy`
- Economy: `skillful`, `collector`, `heavyLoad`, `salvager`

### Enemy IDs
- Tier 1: `rusher`, `gunner`, `shieldTrooper`
- Tier 2: `jumper`, `heavyTrooper`, `hacker`, `stormCreature`
- Tier 3: `brute`, `sniper`, `droneCarrier`, `shieldGenerator`
- Boss: `pirateCaptain`, `stormCore`

### Facility IDs
- `residential` (small/medium/large)
- `medical`
- `armory`
- `commTower`
- `powerPlant`

### Node Types (Sector Map)
- `start` - 시작점
- `battle` - 일반 전투
- `commander` - 팀장 영입
- `equipment` - 장비 획득
- `storm` - 폭풍 스테이지
- `boss` - 보스 전투
- `rest` - 휴식
- `gate` - 점프 게이트 (최종)

### Tile Types (Station Layout)
- `0` VOID - 우주 (즉사)
- `1` FLOOR - 바닥
- `2` WALL - 벽
- `3` FACILITY - 시설
- `4` AIRLOCK - 에어락 (스폰)
- `5` ELEVATED - 고지대
- `6` LOWERED - 저지대
- `7` CORRIDOR - 복도

---

## Conflict Prevention Rules

1. Each session only modifies its assigned files
2. Common file modifications must be recorded here
3. Interface changes require updating this document

---

## Notes

- All data modules expose a global object (window.XxxData)
- Data modules should not depend on each other
- GameState.js integrates all data modules
- **2026-02-03 작업 로그:** [UPDATE-LOG-2026-02-03.md](UPDATE-LOG-2026-02-03.md)

---

## Page Controllers (Web-specific)

페이지별 컨트롤러 - Godot에서는 Scene으로 대체

| 파일 | 역할 | Godot 대응 |
|------|------|-----------|
| `pages/menu.js` | 메인 메뉴 | `scenes/ui/MainMenu.tscn` |
| `pages/difficulty.js` | 난이도 선택 | `scenes/ui/DifficultySelect.tscn` |
| `pages/deploy.js` | 크루 배치 | `scenes/battle/Deploy.tscn` |
| `pages/battle.js` | 전투 메인 | `scenes/battle/Battle.tscn` |
| `pages/upgrade.js` | 업그레이드 상점 | `scenes/campaign/Upgrade.tscn` |
| `pages/sector.js` | 섹터 맵 | `scenes/campaign/SectorMap.tscn` |
| `pages/result.js` | 노드 결과 | `scenes/campaign/Result.tscn` |
| `pages/victory.js` | 승리 화면 | `scenes/ui/Victory.tscn` |
| `pages/gameover.js` | 패배 화면 | `scenes/ui/GameOver.tscn` |
| `pages/settings.js` | 설정 | `scenes/ui/Settings.tscn` |
| `pages/credits.js` | 크레딧 | `scenes/ui/Credits.tscn` |

---

## Godot Migration Notes

### 핵심 이관 대상 (Logic)

| 우선순위 | 모듈 | Godot 대응 |
|----------|------|-----------|
| **P0** | Data (`js/data/*`) | Resource (.tres) |
| **P0** | GameState | Autoload Singleton |
| **P0** | SeededRNG | Godot RandomNumberGenerator |
| **P1** | TileGrid | TileMap + Custom Script |
| **P1** | Combat Systems | Node-based Scripts |
| **P1** | Enemy/AI | CharacterBody2D + BehaviorTree |
| **P2** | Wave/Sector Gen | GDScript 클래스 |
| **P2** | CrewAI | GDScript AI |
| **P3** | UI Systems | Control Nodes + Theme |

### 웹 전용 (이관 불필요)

- `js/test/*` - 테스트 코드 (Godot GUT 사용)
- `js/ui/ui-components.js` - 웹 DOM 기반 (Godot Control로 대체)
- CSS 파일 전체 - Godot Theme으로 대체

### 핵심 인터페이스 유지

Godot에서도 동일한 메서드 시그니처 유지 권장:
- `CrewData.getClass(classId)` → `CrewData.get_class(class_id)`
- `EnemyData.getByTier(tier)` → `EnemyData.get_by_tier(tier)`
- `GameState.saveRun()` → `GameState.save_run()`

### 시드 시스템

```gdscript
# Godot 내장 RNG 활용
var rng = RandomNumberGenerator.new()
rng.seed = hash(seed_string)
```

---

## Session 4 Extended (2026-02-03)

### 전투 시스템 Phase 1-3 개선

**Phase 1 - 공격 피드백:**
- 공격 예비동작(windup) 애니메이션 (150ms)
- 크리티컬 히트 시각화 (황금색 파티클, 1.5배 데미지)
- 유닛 방향 표시 (삼각형 화살표)

**Phase 2 - 피격 반응:**
- 플래시 효과 (150ms) + 넉백 (8px, 100ms)
- 사망 애니메이션 (`death_burst`, `soul_rise`)
- 스킬/장비/레이븐 발동 이펙트

**Phase 3 - 폴리시:**
- 투사체 트레일 (8프레임 기록)
- 부드러운 체력바 전환 (15% 보간)
- 호흡 애니메이션 (±3% 스케일)
- 웨이브 시작 효과

### 이펙트 좌표 시스템 수정

**문제:** 아이소메트릭 모드에서 이펙트가 잘못된 위치에 표시

**해결 - 새 헬퍼 함수:**
```javascript
// battle.js에 추가
getEffectPos(entity)                    // 엔티티의 화면 좌표 반환
addEffectAtEntity(entity, effectProps)  // 엔티티 위치에 이펙트 추가
```

**수정된 함수:**
- `crewAttack()` - 화면 좌표로 windup/melee_hit
- `enemyAttack()` - 화면 좌표로 windup
- `applyHitReaction(target, source)` - 소스 엔티티 기반
- `triggerDeathAnimation()` - 화면 좌표 이펙트
- `addCriticalHitEffect(entity, color)` - 엔티티 기반 파라미터
- `updateProjectile()` - 화면 좌표 충돌 검사

**좌표 시스템:**
```
레거시 모드:     entity.x/y = 화면좌표, 변환 불필요
아이소메트릭:    entity.x/y = 타일좌표, getEffectPos() 필수
```

### 크루 분대원 시각화

**구현:**
- 메인 크루 원 주변에 분대원 배치 (반경 30px)
- 사람 형상: 머리(원 2.5px) + 몸통(타원 3x5px)
- 생존: 크루 색상 + 흰색 테두리
- 사망: 회색, 30% 투명도

**적용:**
- `renderCrew()` - 레거시 모드
- `renderCrewIsometric()` - 아이소메트릭 모드

### 2.5D 아이소메트릭 연동

Phase 1-3 기능을 아이소메트릭 렌더 함수에도 적용:
- `renderCrewIsometric`: 호흡, 전투상태, 부드러운HP, 분대원
- `renderEnemyIsometric`: 향상된 플래시, 부드러운HP

---

## Session 6 Status
- Started: 2026-02-03
- Completed: 2026-02-03
- Assigned Files:
  - `demo/js/rendering/isometric-renderer.js` (new)
  - `demo/js/rendering/height-system.js` (new)
  - `demo/js/rendering/tile-renderer.js` (new)
  - `demo/js/rendering/depth-sorter.js` (new)
  - `demo/js/pages/battle.js` (extended)
  - `demo/pages/battle.html` (extended)

### Features Implemented
- 2.5D 아이소메트릭 다이아몬드 타일 렌더링 (Bad North 스타일)
- 타일 높이 시스템 (VOID=0, FLOOR=1, ELEVATED=2, LOWERED=0)
- 고저차 시각화 (측면 벽 렌더링)
- 깊이 정렬 (back-to-front 렌더링)
- 카메라 컨트롤 (줌, 회전, 패닝)
- 터치 지원 (핀치 줌)

### Exposed Interfaces

```javascript
// IsometricRenderer - demo/js/rendering/isometric-renderer.js
const IsometricRenderer = {
    config: { tileWidth: 64, tileHeight: 32, heightOffset: 20, maxHeightLevels: 4 },
    camera: { zoom: 1.0, rotation: 0, panX: 0, panY: 0, targetZoom: 1.0, targetRotation: 0 },
    cameraLimits: { minZoom: 0.5, maxZoom: 2.0, zoomStep: 0.1, rotationSteps: 4 },

    init(canvas, gridWidth, gridHeight),   // 초기화
    tileToScreen(tileX, tileY, heightLevel), // 타일→화면 좌표
    screenToTile(screenX, screenY, heightLevel), // 화면→타일 좌표
    getDepth(tileX, tileY, heightLevel),   // 깊이 정렬값
    getDiamondVertices(screenX, screenY),  // 다이아몬드 꼭짓점
    isTileVisible(tileX, tileY, heightLevel), // 컬링 체크

    // 카메라 컨트롤
    setZoom(zoom, smooth),
    zoomIn(), zoomOut(),
    rotate(direction),                      // 'cw' | 'ccw'
    pan(dx, dy),
    resetCamera(),
    updateCamera(dt),                       // 부드러운 전환

    // 캐싱
    getTileCache(),
    markCacheDirty(),
    markCacheClean(),
    isCacheDirty(),
};

// HeightSystem - demo/js/rendering/height-system.js
const HeightSystem = {
    TILE_HEIGHT_MAP: { 0: 0, 1: 1, 2: 1, 3: 1, 4: 1, 5: 2, 6: 0, 7: 1, 8: 1, 9: 1, 10: 1 },

    getHeightLevel(tileType),              // 타일 타입→높이 레벨
    getLayoutTileHeight(stationLayout, x, y), // 레이아웃에서 높이 조회
    getSideRenderInfo(stationLayout, x, y),   // 측면 렌더 정보
    getEntityHeight(entity, stationLayout),   // 엔티티 높이 레벨
};

// TileRenderer - demo/js/rendering/tile-renderer.js
const TileRenderer = {
    TILE_COLORS: { 0: '#0a0a12', 1: '#1a1a2e', 2: '#2d2d44', ... },
    LEFT_SIDE_DARKNESS: 0.7,
    RIGHT_SIDE_DARKNESS: 0.85,

    drawTileTop(ctx, screenX, screenY, tileType, options),
    drawTileLeftSide(ctx, screenX, screenY, tileType, heightDiff),
    drawTileRightSide(ctx, screenX, screenY, tileType, heightDiff),
    drawTileComplete(ctx, screenX, screenY, tileType, sideInfo, options),
    renderAllTiles(ctx, stationLayout, options),
    renderToCache(stationLayout),
    drawFromCache(ctx),
    drawTileHighlight(ctx, screenX, screenY, color, alpha),
    drawTileOutline(ctx, screenX, screenY, color, lineWidth),
    renderFacilities(ctx, stationLayout),
    renderSpawnPoints(ctx, stationLayout),
};

// DepthSorter - demo/js/rendering/depth-sorter.js
const DepthSorter = {
    getEntityDepth(entity, stationLayout),  // 엔티티 깊이값 계산
    sortByDepth(entities, stationLayout),   // 깊이순 정렬
    createRenderList(crews, enemies, stationLayout), // 렌더 목록 생성
    getEntityScreenPosition(entity, stationLayout),  // 엔티티 화면 좌표
    getTileAtPosition(screenX, screenY, stationLayout), // 화면→타일
};
```

### Keyboard Shortcuts (Camera Controls)

| Key | Action |
|-----|--------|
| `Scroll` | 확대/축소 |
| `Z` | 카메라 반시계 회전 |
| `C` | 카메라 시계 회전 |
| `+` / `-` | 확대/축소 |
| `R` | 카메라 초기화 |
| `Middle Click + Drag` | 카메라 패닝 |

### Battle.js Extensions

```javascript
// 새 속성
useIsometric: true,
isometricInitialized: false,
isPanning: false,
isPinching: false,
lastPinchDistance: 0,

// 새 메서드
renderStationIsometric(),
renderEntitiesIsometric(),
renderCrewIsometric(crew),
renderEnemyIsometric(enemy),
getEntityScreenPos(entity),
moveCrewToScreen(crew, screenX, screenY),
moveCrewToTile(crew, tileX, tileY, screenX, screenY),
handleMouseWheel(e),
handleMouseDown(e),
handleMouseUp(e),
rotateCamera(direction),
resetCamera(),
updateEntityTilePosition(entity),
```

### Configuration

| Parameter | Value | Description |
|-----------|-------|-------------|
| `tileWidth` | 64px | 다이아몬드 가로 폭 |
| `tileHeight` | 32px | 다이아몬드 세로 높이 (2:1 비율) |
| `heightOffset` | 20px | 높이 레벨당 Y 오프셋 |
| `maxHeightLevels` | 4 | 0~3 레벨 |
| `minZoom` | 0.5 | 최소 줌 |
| `maxZoom` | 2.0 | 최대 줌 |
| `rotationSteps` | 4 | 90° 단위 회전 |
