# The Fading Raven - Enemy & AI System Documentation

## Overview

Session 3 구현 문서. 15종 적 유형, AI 행동 트리, 웨이브 생성 시스템, 특수 메카닉을 다룹니다.

**Status**: ✅ Complete (Godot 4.x)
**Updated**: 2026-02-04

---

## File Structure

```
godot/src/
├── data/
│   └── EnemyData.gd          # 적 데이터 Resource 클래스
├── entities/
│   ├── Entity.gd             # 베이스 엔티티 클래스
│   └── enemy/
│       ├── EnemyUnit.gd      # 적 유닛 클래스
│       └── EnemyUnit.tscn    # 적 유닛 씬
└── systems/
    ├── ai/
    │   ├── BTNode.gd         # 행동 트리 기본 노드
    │   ├── BTComposite.gd    # 복합 노드 (Selector, Sequence, Parallel)
    │   ├── BTDecorator.gd    # 데코레이터 노드
    │   ├── BTLeaf.gd         # 리프 노드 (Condition, Action, Wait)
    │   ├── BehaviorTree.gd   # BT 빌더 헬퍼 + TreeRunner
    │   ├── EnemyBehaviors.gd # 적 유형별 행동 패턴
    │   └── AIManager.gd      # 적 AI 중앙 관리자
    └── wave/
        ├── WaveGenerator.gd  # 웨이브 구성 생성기
        ├── WaveManager.gd    # 웨이브 상태 관리자
        └── SpawnController.gd # 적 스폰 컨트롤러
```

---

## Exposed Interfaces

### EnemyData (Resource)

```gdscript
class_name EnemyData
extends Resource

# 기본 속성
@export var id: String
@export var display_name: String
@export var tier: Constants.EnemyTier
@export var hp: int
@export var base_damage: int
@export var attack_range: float
@export var move_speed: float
@export var armor: int
@export var wave_cost: int
@export var behavior_id: String

# 특수 메카닉 플래그
@export var is_sniper: bool
@export var can_hack: bool
@export var spawns_drones: bool
@export var self_destructs: bool
@export var provides_shield: bool
@export var throws_grenade: bool
@export var is_boss: bool

# Methods
func get_scaled_stats(difficulty: int, wave_number: int) -> Dictionary
```

### EnemyUnit (Node)

```gdscript
class_name EnemyUnit
extends Entity

# Signals
signal target_changed(new_target: Node)
signal special_ability_used(ability_id: String)
signal landing_completed()
signal hazard_zone_created(position: Vector2, radius: float, duration: float)
signal storm_pulse_fired(damage: int)

# Properties
var enemy_data: EnemyData
var current_target: Node
var entry_point: Vector2i
var has_landed: bool
var special_state: Dictionary

# Methods
func initialize(data: EnemyData, spawn_point: Vector2i, difficulty: int, wave_num: int)
func set_target(target: Node)
func is_boss() -> bool
func is_shielded() -> bool

# Jumper
func can_jump() -> bool
func perform_jump(target_pos: Vector2i)

# Grenade
func can_throw_grenade() -> bool
func throw_grenade(target_pos: Vector2)

# Captain
func captain_charge_attack(direction: Vector2) -> bool
func captain_summon_reinforcements()

# Storm Core
func get_active_hazard_zones() -> Array[Dictionary]
func is_storm_core() -> bool
```

### AIManager (Node/Autoload)

```gdscript
class_name AIManager
extends Node

# 10개의 행동 트리 내장
var behavior_trees: Dictionary

# Methods
func initialize(tile_grid: Node, battle_controller: Node)
func activate()
func deactivate()

# 자동 처리 (_process에서)
# - 모든 적 AI 업데이트
# - 행동 트리 틱 실행
```

### WaveGenerator (RefCounted)

```gdscript
class_name WaveGenerator
extends RefCounted

class WaveData:
    var wave_index: int
    var enemies: Array  # [{enemy_id, count, entry_point}]
    var spawn_delays: Array[float]
    var theme: String
    var budget: int
    var is_boss_wave: bool

# Methods
func generate_waves(station_depth: int, diff: Constants.Difficulty, entry_points: Array[Vector2i]) -> Array[WaveData]
func generate_boss_wave(station_depth: int, diff: Constants.Difficulty, entry_points: Array[Vector2i], boss_id: String) -> WaveData
func get_wave_preview(wave_data: WaveData) -> Array
```

### WaveManager (Node)

```gdscript
class_name WaveManager
extends Node

# Signals
signal wave_started(wave_num: int)
signal wave_ended(wave_num: int)
signal all_waves_cleared()
signal enemy_spawned(enemy: Node)
signal wave_preview_ready(wave_num: int, preview: Array)

# Methods
func initialize(tile_grid: Node, battle_controller: Node, difficulty: Constants.Difficulty)
func setup_waves(station_depth: int, entry_points: Array[Vector2i], seed_value: int)
func setup_boss_wave(station_depth: int, entry_points: Array[Vector2i], boss_id: String, seed_value: int)
func start_next_wave()
func force_end_wave()
func end_battle()
func get_total_waves() -> int
func get_current_wave() -> int
func get_remaining_enemies() -> int
func get_next_wave_preview() -> Array
```

### SpawnController (Node)

```gdscript
class_name SpawnController
extends Node

# Signals
signal enemy_spawned(enemy: Node)
signal group_spawned(enemy_id: String, count: int, entry_point: Vector2i)
signal spawning_complete()

# Methods
func initialize(tile_grid: Node, battle_controller: Node)
func start_spawning(wave_data: WaveGenerator.WaveData)
func stop_spawning()
func is_spawning_complete() -> bool
func get_spawn_progress() -> float
```

---

## Enemy Types

### Tier 1 (기본)

| ID | 이름 | 행동 | 특수 | Wave Cost |
|---|---|---|---|---|
| `rusher` | 러셔 | melee_basic | - | 1 |
| `gunner` | 건너 | ranged_basic | keepDistance | 2 |
| `shield_trooper` | 실드 트루퍼 | melee_shielded | frontalShield | 3 |

### Tier 2 (중급)

| ID | 이름 | 행동 | 특수 | Wave Cost |
|---|---|---|---|---|
| `jumper` | 점퍼 | melee_jumper | jumpAttack | 4 |
| `heavy_trooper` | 헤비 트루퍼 | melee_heavy | grenadeThrow | 5 |
| `hacker` | 해커 | support_hacker | hackTurret | 3 |
| `storm_creature` | 폭풍 생명체 | kamikaze | selfDestruct | 3 |

### Tier 3 (고급)

| ID | 이름 | 행동 | 특수 | Wave Cost |
|---|---|---|---|---|
| `brute` | 브루트 | melee_brute | heavySwing (cleave) | 8 |
| `sniper` | 스나이퍼 | ranged_sniper | sniperShot (laser) | 6 |
| `drone_carrier` | 드론 캐리어 | support_carrier | spawnDrones | 7 |
| `shield_generator` | 실드 제너레이터 | support_shield | aoeShield | 5 |

### Boss

| ID | 이름 | 행동 | 특수 | Wave Cost |
|---|---|---|---|---|
| `pirate_captain` | 해적 대장 | boss_captain | 버프, 돌진, 소환 | 20 |
| `storm_core` | 폭풍 핵 | boss_storm | 무적, 펄스, 위험 지역, 소환 | - |

---

## Behavior Tree System

### Node Types

#### Composite Nodes (BTComposite.gd)
- `Selector` - 자식 중 하나가 SUCCESS하면 SUCCESS
- `Sequence` - 모든 자식이 SUCCESS해야 SUCCESS
- `Parallel` - 모든 자식 동시 실행, policy에 따라 결과
- `RandomSelector` - 랜덤 순서로 선택 실행

#### Decorator Nodes (BTDecorator.gd)
- `Inverter` - 결과 반전 (SUCCESS ↔ FAILURE)
- `Succeeder` - 항상 SUCCESS
- `Failer` - 항상 FAILURE
- `Repeater` - N번 반복 실행
- `RepeatUntilFail` - FAILURE할 때까지 반복
- `Cooldown` - 쿨다운 적용
- `Timeout` - 시간 제한
- `ConditionGuard` - 조건 충족 시에만 실행

#### Leaf Nodes (BTLeaf.gd)
- `Condition` - 조건 검사
- `Action` - 행동 실행
- `Wait` - 시간 대기
- `RandomWait` - 랜덤 시간 대기
- `Log` - 디버그 로그
- `AlwaysSuccess` / `AlwaysFailure`

### Behavior Patterns (EnemyBehaviors.gd)

```gdscript
# 사용 예시
var tree := EnemyBehaviors.create_behavior("melee_basic")
tree.tick(enemy, {"delta": delta})
```

**Available Patterns:**
- `melee_basic` - 기본 근접 (Rusher)
- `melee_shielded` - 실드 근접 (Shield Trooper)
- `ranged_basic` - 기본 원거리 (Gunner)
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

```gdscript
var generator := WaveGenerator.new(seed_value)
var waves := generator.generate_waves(
    station_depth,  # 현재 깊이 (1-20)
    Constants.Difficulty.NORMAL,
    entry_points  # Array[Vector2i]
)
```

### Theme Compositions

| Theme | 구성 |
|---|---|
| `rush` | 80% rusher, 20% gunner |
| `ranged` | 60% gunner, 30% rusher, 10% shield |
| `shield` | 50% shield, 30% rusher, 20% gunner |
| `assault` | 30% jumper, 30% heavy, 40% rusher |
| `hacking` | 20% hacker, 40% shield, 40% rusher |
| `sniper` | 20% sniper, 50% shield, 30% rusher |
| `mixed` | 40% rusher, 30% gunner, 30% shield |
| `elite` | 30% brute, 20% sniper, 20% shield_gen, 30% heavy |
| `swarm` | 90% rusher, 10% gunner |

### Enemy Unlock by Depth

| Depth | Unlocked Enemies |
|---|---|
| 1 | rusher, gunner, shield_trooper |
| 3 | jumper |
| 4 | heavy_trooper, hacker |
| 5 | brute |
| 6 | sniper, shield_generator |
| 7 | drone_carrier |
| 8 | storm_creature |

---

## Special Mechanics Detail

### 1. Sniper - Laser Aiming

```gdscript
# EnemyUnit._process_sniper()
# Flow:
# 1. 가장 가까운 크루 타겟팅
# 2. 정지 후 3초 조준 (sniper_aim_time)
# 3. 조준 중 이동하면 리셋
# 4. 완료 시 즉사 데미지 (9999)

func get_sniper_aim_progress() -> float
func get_sniper_target() -> Node
```

### 2. Hacker - Turret Hacking

```gdscript
# EnemyUnit._process_hacker()
# Flow:
# 1. 해킹 가능한 터렛 탐색 (3타일 범위)
# 2. 해킹 범위 내 이동 (2타일)
# 3. 5초간 해킹 진행
# 4. 완료 시 터렛 무력화

func get_hack_progress() -> float
func get_hack_target() -> Node
```

### 3. Drone Carrier - Drone Spawning

```gdscript
# EnemyUnit._process_drone_carrier()
# - 10초마다 드론 2기 생성
# - 최대 6기 유지
# - 캐리어 사망 시 모든 드론 파괴
```

### 4. Shield Generator - AoE Shield

```gdscript
# EnemyUnit._process_shield_generator()
# - 2타일 범위 내 아군에게 실드 버프
# - 에너지 데미지 완전 면역
# - 제너레이터 사망 시 버프 해제

func apply_shield_buff()
func remove_shield_buff()
func is_shielded() -> bool
```

### 5. Storm Creature - Self Destruct

```gdscript
# EnemyUnit._process_storm_creature()
# - 0.5타일 내 접근 시 자폭
# - 2타일 범위 폭발 데미지
# - 아군 적 모두 피해

func _self_destruct()
```

### 6. Grenade - Heavy Trooper

```gdscript
# EnemyUnit._process_grenade()
# - 쿨다운 8초
# - 범위 1.5타일
# - 데미지 15

func can_throw_grenade() -> bool
func throw_grenade(target_pos: Vector2)
```

### 7. Storm Core - Environmental Hazard Boss

```gdscript
# EnemyUnit._process_storm_core()
# - 무적 (모든 데미지 0)
# - 8초마다 위험 지역 생성 (4초 지속, 틱당 5 데미지)
# - 5초마다 전역 펄스 (3 데미지)

func get_active_hazard_zones() -> Array[Dictionary]
func is_storm_core() -> bool
```

---

## Integration with Other Sessions

### Session 1 (Core Systems)
```gdscript
# EventBus 시그널 사용
EventBus.enemy_spawned.emit(enemy, entry_point)
EventBus.entity_died.connect(_on_entity_died)
EventBus.wave_started.emit(wave_num, total_waves, preview)
EventBus.wave_ended.emit(wave_num)
EventBus.all_waves_cleared.emit()
EventBus.turret_hacked.emit(turret, hacker)

# GameState 참조
var seed := GameState.current_seed
```

### Session 2 (Combat System)
```gdscript
# 데미지 처리
enemy.take_damage(amount, Constants.DamageType.PHYSICAL, source)
enemy.apply_stun(duration)
enemy.apply_slow(multiplier, duration)
enemy.apply_knockback(direction, force)
```

### Session 4 (Campaign)
```gdscript
var wave_manager := WaveManager.new()
wave_manager.initialize(tile_grid, battle_controller, difficulty)
wave_manager.setup_waves(station_depth, entry_points, GameState.current_seed)
wave_manager.start_next_wave()
```

### Session 5 (UI)
```gdscript
# 웨이브 미리보기
var preview := wave_manager.get_next_wave_preview()

# 스나이퍼 레이저 표시
var target := enemy.get_sniper_target()
var progress := enemy.get_sniper_aim_progress()

# 위험 지역 표시 (Storm Core)
var zones := enemy.get_active_hazard_zones()
```

---

## Usage Example

```gdscript
# BattleController.gd

var ai_manager: AIManager
var wave_manager: WaveManager

func _ready() -> void:
    ai_manager = AIManager.new()
    add_child(ai_manager)

    wave_manager = WaveManager.new()
    add_child(wave_manager)

    wave_manager.enemy_spawned.connect(_on_enemy_spawned)
    wave_manager.all_waves_cleared.connect(_on_battle_won)

func start_battle(station_depth: int, entry_points: Array[Vector2i]) -> void:
    ai_manager.initialize(tile_grid, self)
    wave_manager.initialize(tile_grid, self, GameState.difficulty)
    wave_manager.setup_waves(station_depth, entry_points, GameState.current_seed)
    wave_manager.start_next_wave()

func _on_enemy_spawned(enemy: Node) -> void:
    enemies.append(enemy)

func _on_battle_won() -> void:
    EventBus.battle_victory.emit()
```

---

## Constants Reference (Constants.gd)

### ENEMY_COSTS
```gdscript
const ENEMY_COSTS: Dictionary = {
    "rusher": 1,
    "gunner": 2,
    "shield_trooper": 3,
    "jumper": 4,
    "heavy_trooper": 5,
    "hacker": 3,
    "storm_creature": 3,
    "brute": 8,
    "sniper": 6,
    "drone_carrier": 7,
    "shield_generator": 5,
    "pirate_captain": 20,
    "storm_core": 0
}
```

### EntityState
```gdscript
enum EntityState { IDLE, MOVING, ATTACKING, USING_SKILL, STUNNED, DEAD }
```

### BehaviorTree.Status
```gdscript
enum Status { SUCCESS, FAILURE, RUNNING }
```

---

## Implementation Notes

1. **모듈화**: BT 시스템이 BTNode, BTComposite, BTDecorator, BTLeaf로 분리되어 유지보수 용이
2. **데이터 주도**: EnemyData Resource로 모든 적 속성 관리, 에디터에서 조정 가능
3. **플래그 기반 메카닉**: ability_id 대신 is_sniper, can_hack 등 불리언 플래그로 다중 능력 지원
4. **Storm Core**: 파괴 불가 환경 위험 보스로 위험 지역 + 전역 펄스 메카닉 구현

---

## Version

- Session: S03
- Platform: Godot 4.x
- Date: 2026-02-04
- Status: ✅ Complete
