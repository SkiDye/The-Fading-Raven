# The Fading Raven - Implementation Shared State

## Progress Status

- [x] Session 1: Data & Core Systems
- [x] Session 2: Combat System
- [x] Session 3: Enemies & AI
- [x] Session 4: Campaign System
- [x] Session 5: UI & Polish (Complete)

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

## Session 3 Status
- Started: 2026-02-03
- Completed: 2026-02-03
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

// AIManager - demo/js/ai/behavior-tree.js
const AIManager = {
    updateEnemy(enemy, context),
    updateAll(enemies, context),
    removeEnemy(enemyId),
    clear(),
};

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
```

---

## Session 5 Status
- Started: 2026-02-03
- Completed: 2026-02-03
- Assigned Files:
  - `demo/js/ui/ui-components.js` (new)
  - `demo/js/ui/effects.js` (new)
  - `demo/js/ui/hud.js` (new)
  - `demo/js/ui/battle-effects-integration.js` (new)
  - `demo/css/ui-components.css` (new)
  - `demo/css/effects.css` (new)
  - `demo/css/hud.css` (new)
  - `demo/pages/settings.html` (improved)
  - `demo/pages/battle.html` (integrated)
  - `demo/js/pages/settings.js` (improved)
  - `demo/css/pages/panel.css` (extended)
  - `docs/implementation/ui-components.md` (new)

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
```

### Completed (Phase 2 - Combat Integration)
- [x] battle-effects-integration.js로 전투 이펙트 시스템 통합
- [x] FloatingText, ParticleSystem, ScreenEffects를 전투에 연결
- [x] 설정 화면 완성 (접근성 옵션 포함)

### Future Enhancements
- 업그레이드 UI 개선 (장비/스킬 상세 뷰)
- Raven 능력 시각 효과 추가
- 사운드 시스템 통합

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
