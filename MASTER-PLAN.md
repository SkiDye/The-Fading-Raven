# The Fading Raven - Godot 이관 마스터 플랜

> **단일 진실 문서 (Single Source of Truth)**
> 최종 업데이트: 2026-02-04
> 버전: 1.0.0

---

## 1. 프로젝트 개요

### 1.1 목표
웹 프로토타입을 Godot 4.x로 완전 이관하여 프로덕션 품질의 게임 구현

### 1.2 핵심 원칙
| 원칙 | 설명 |
|------|------|
| **단일 진실** | 이 문서가 모든 인터페이스/상수의 기준 |
| **느슨한 결합** | 세션 간 직접 의존 최소화, 시그널/인터페이스 통신 |
| **병렬 최적화** | 12개 세션이 동시 작업 가능하도록 설계 |
| **테스트 우선** | 각 세션은 유닛 테스트 포함 필수 |
| **일관된 코드 스타일** | GDScript 스타일 가이드 준수 |

---

## 2. 아키텍처 개요

```
┌─────────────────────────────────────────────────────────────────────┐
│                         UI Layer (Session 12)                        │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐   │
│  │  BattleHUD  │ │  SectorMap  │ │   Menus     │ │  Tooltips   │   │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘   │
├─────────────────────────────────────────────────────────────────────┤
│                      Campaign Layer (Sessions 10-11)                 │
│  ┌─────────────────────────────┐ ┌─────────────────────────────┐   │
│  │  SectorGenerator (S10)      │ │  MetaProgress (S11)         │   │
│  │  StationGenerator (S10)     │ │  SaveSystem (S11)           │   │
│  └─────────────────────────────┘ └─────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────────┤
│                      Combat Layer (Sessions 7-9)                     │
│  ┌───────────────┐ ┌───────────────┐ ┌───────────────┐             │
│  │ TileGrid (S7) │ │ Combat (S8)   │ │ Wave/AI (S9)  │             │
│  │ Pathfinding   │ │ Skills        │ │ BehaviorTree  │             │
│  │ LineOfSight   │ │ Equipment     │ │ WaveGenerator │             │
│  └───────────────┘ └───────────────┘ └───────────────┘             │
├─────────────────────────────────────────────────────────────────────┤
│                      Entity Layer (Sessions 4-6)                     │
│  ┌───────────────┐ ┌───────────────┐ ┌───────────────┐             │
│  │  Crew (S4)    │ │  Enemy (S5)   │ │ Effects (S6)  │             │
│  │  CrewSquad    │ │  EnemySquad   │ │ Projectile    │             │
│  │  CrewMember   │ │  EnemyUnit    │ │ Particles     │             │
│  └───────────────┘ └───────────────┘ └───────────────┘             │
├─────────────────────────────────────────────────────────────────────┤
│                       Core Layer (Sessions 1-3)                      │
│  ┌───────────────┐ ┌───────────────┐ ┌───────────────┐             │
│  │ Setup (S1)    │ │  Data (S2)    │ │ State (S3)    │             │
│  │ project.godot │ │  Resources    │ │ GameState     │             │
│  │ Autoloads     │ │  Constants    │ │ EventBus      │             │
│  └───────────────┘ └───────────────┘ └───────────────┘             │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 3. 세션 할당

### 3.1 세션 목록

| 세션 | 레이어 | 담당 영역 | 의존성 | 우선순위 |
|------|--------|----------|--------|----------|
| **S01** | Core | Project Setup & Autoloads | 없음 | P0 |
| **S02** | Core | Data Resources & Definitions | S01 | P0 |
| **S03** | Core | GameState & EventBus | S01 | P0 |
| **S04** | Entity | Crew System | S02, S03 | P1 |
| **S05** | Entity | Enemy System | S02, S03 | P1 |
| **S06** | Entity | Effects & Projectiles | S02, S03 | P1 |
| **S07** | Combat | TileGrid & Pathfinding | S01 | P1 |
| **S08** | Combat | Combat Controller & Skills | S03, S04, S05, S07 | P2 |
| **S09** | Combat | Wave Generator & AI | S02, S05, S07 | P2 |
| **S10** | Campaign | Sector & Station Generation | S02, S03 | P1 |
| **S11** | Campaign | Meta Progress & Save | S02, S03 | P1 |
| **S12** | UI | UI Components & HUD | S03 | P1 |

### 3.2 의존성 그래프

```
Phase 0 (병렬 시작 가능)
┌─────┐  ┌─────┐  ┌─────┐
│ S01 │  │ S07 │  │ S12 │ ← UI 스켈레톤
└──┬──┘  └──┬──┘  └──┬──┘
   │        │        │
Phase 1 (S01 완료 후 병렬)
   ▼        │        │
┌─────┐  ┌─────┐     │
│ S02 │  │     │     │
└──┬──┘  │     │     │
   │     │     │     │
┌──┴──┐  │     │     │
│ S03 │  │     │     │
└──┬──┘  │     │     │
   │     │     │     │
Phase 2 (S02, S03 완료 후 병렬)
   ▼     ▼     │     │
┌─────┬─────┬─────┐  │
│ S04 │ S05 │ S06 │  │
└──┬──┴──┬──┴──┬──┘  │
   │     │     │     │
┌─────┬─────┐  │     │
│ S10 │ S11 │  │     │
└──┬──┴──┬──┘  │     │
   │     │     │     │
Phase 3 (Entity 완료 후)
   ▼     ▼     ▼     ▼
┌─────────────────────┐
│    S08 (Combat)     │
└──────────┬──────────┘
           │
┌──────────┴──────────┐
│    S09 (Wave/AI)    │
└─────────────────────┘
```

---

## 4. 공유 인터페이스 정의

### 4.1 Autoload 싱글톤

```gdscript
# ===== GameState (S03) =====
# 전역 게임 상태 관리
extends Node

signal run_started(seed: int)
signal run_ended(victory: bool)
signal stage_started(station_id: String)
signal stage_ended(result: StageResult)
signal crew_changed(crew_id: String)
signal credits_changed(amount: int)

var current_seed: int
var current_run: RunData
var current_stage: StageData
var crews: Array[CrewData]
var credits: int

func start_new_run(seed: int = -1) -> void
func end_run(victory: bool) -> void
func start_stage(station: StationData) -> void
func end_stage(result: StageResult) -> void
func add_crew(crew: CrewData) -> void
func remove_crew(crew_id: String) -> void
func add_credits(amount: int) -> void
func spend_credits(amount: int) -> bool
func save_game() -> void
func load_game() -> bool
```

```gdscript
# ===== EventBus (S03) =====
# 전역 이벤트 시스템
extends Node

# Combat Events
signal damage_dealt(source: Node, target: Node, amount: int, type: DamageType)
signal entity_died(entity: Node)
signal skill_used(caster: Node, skill: SkillData, targets: Array)
signal equipment_activated(user: Node, equipment: EquipmentData)

# Wave Events
signal wave_started(wave_num: int, enemies: Array)
signal wave_ended(wave_num: int)
signal enemy_spawned(enemy: Node, entry_point: Vector2i)
signal all_waves_cleared()

# Facility Events
signal facility_damaged(facility: Node, amount: int)
signal facility_destroyed(facility: Node)
signal facility_repaired(facility: Node)

# UI Events
signal show_tooltip(content: String, position: Vector2)
signal hide_tooltip()
signal show_toast(message: String, type: ToastType)
signal show_modal(modal_data: ModalData)

# Raven Events
signal raven_ability_used(ability: RavenAbility)
signal raven_charges_changed(ability: RavenAbility, charges: int)
```

```gdscript
# ===== Constants (S02) =====
# 전역 상수 및 열거형
extends Node

# 난이도
enum Difficulty { NORMAL, HARD, VERY_HARD, NIGHTMARE }

# 클래스
enum CrewClass { GUARDIAN, SENTINEL, RANGER, ENGINEER, BIONIC }

# 적 티어
enum EnemyTier { TIER_1, TIER_2, TIER_3, BOSS }

# 데미지 타입
enum DamageType { PHYSICAL, ENERGY, EXPLOSIVE, TRUE }

# 타일 타입
enum TileType { VOID, FLOOR, WALL, AIRLOCK, ELEVATED, LOWERED, FACILITY }

# 장비 타입
enum EquipmentType { PASSIVE, ACTIVE_COOLDOWN, ACTIVE_CHARGES }

# 노드 타입 (섹터 맵)
enum NodeType { START, BATTLE, COMMANDER, EQUIPMENT, STORM, BOSS, REST, GATE }

# Raven 능력
enum RavenAbility { SCOUT, FLARE, RESUPPLY, ORBITAL_STRIKE }

# Toast 타입
enum ToastType { INFO, SUCCESS, WARNING, ERROR }

# 밸런스 상수
const BALANCE = {
    "squad_size": {
        "guardian": 8,
        "sentinel": 8,
        "ranger": 8,
        "engineer": 6,
        "bionic": 5
    },
    "recovery_time_per_unit": 2.0,  # 초
    "skill_cooldowns": {
        "shield_bash": 20.0,
        "lance_charge": 25.0,
        "volley_fire": 15.0,
        "deploy_turret": 30.0,
        "blink": 15.0
    },
    "upgrade_costs": {
        "class_rank": [6, 12, 20],
        "skill_level": [7, 10, 14]
    }
}
```

### 4.2 Resource 클래스 정의 (S02)

```gdscript
# ===== CrewClassData =====
class_name CrewClassData extends Resource

@export var id: String
@export var display_name: String
@export var display_name_ko: String
@export var base_squad_size: int
@export var base_hp: int
@export var base_damage: int
@export var attack_speed: float  # attacks per second
@export var move_speed: float    # tiles per second
@export var attack_range: float  # tiles
@export var color: Color
@export var skill: SkillData
@export var strengths: Array[String]
@export var weaknesses: Array[String]
```

```gdscript
# ===== SkillData =====
class_name SkillData extends Resource

@export var id: String
@export var display_name: String
@export var skill_type: SkillType  # DIRECTION, POSITION, SELF
@export var base_cooldown: float
@export var levels: Array[SkillLevelData]

enum SkillType { DIRECTION, POSITION, SELF }
```

```gdscript
# ===== EnemyData =====
class_name EnemyData extends Resource

@export var id: String
@export var display_name: String
@export var tier: int  # 1, 2, 3, 4(boss)
@export var base_hp: int
@export var base_damage: int
@export var move_speed: float
@export var attack_speed: float
@export var attack_range: float
@export var wave_cost: int
@export var min_depth: int
@export var behavior_id: String
@export var color: Color
@export var size: float
@export var special_mechanics: Dictionary
```

```gdscript
# ===== EquipmentData =====
class_name EquipmentData extends Resource

@export var id: String
@export var display_name: String
@export var description: String
@export var equipment_type: int  # EquipmentType enum
@export var base_cost: int
@export var cooldown: float  # for ACTIVE_COOLDOWN
@export var charges: int     # for ACTIVE_CHARGES
@export var levels: Array[EquipmentLevelData]
@export var recommended_classes: Array[String]
```

```gdscript
# ===== TraitData =====
class_name TraitData extends Resource

@export var id: String
@export var display_name: String
@export var category: String  # combat, utility, economy
@export var description: String
@export var effect_type: String
@export var effect_value: float
@export var effect_target: String
@export var recommended_classes: Array[String]
@export var conflicts_with: Array[String]
```

```gdscript
# ===== FacilityData =====
class_name FacilityData extends Resource

@export var id: String
@export var display_name: String
@export var credits: int
@export var size: String  # small, medium, large
@export var effect_type: String
@export var effect_value: float
@export var spawn_weight: float
```

### 4.3 Entity 인터페이스 (S04, S05)

```gdscript
# ===== Entity (Base) =====
class_name Entity extends Node2D

signal health_changed(current: int, max_health: int)
signal died()
signal state_changed(new_state: EntityState)

enum EntityState { IDLE, MOVING, ATTACKING, USING_SKILL, STUNNED, DEAD }

var entity_id: String
var current_hp: int
var max_hp: int
var current_state: EntityState
var tile_position: Vector2i
var team: int  # 0 = player, 1 = enemy

func take_damage(amount: int, type: DamageType, source: Node) -> int
func heal(amount: int) -> int
func apply_knockback(direction: Vector2, force: float) -> void
func apply_stun(duration: float) -> void
func move_to_tile(target: Vector2i) -> void
func is_alive() -> bool
```

```gdscript
# ===== CrewSquad (S04) =====
class_name CrewSquad extends Entity

signal member_died(member: CrewMember)
signal squad_wiped()
signal skill_cooldown_changed(skill_id: String, remaining: float)

var crew_class: CrewClassData
var squad_leader: CrewMember
var members: Array[CrewMember]
var equipment: EquipmentData
var trait_data: TraitData
var rank: int  # 0=Rookie, 1=Standard, 2=Veteran, 3=Elite
var skill_level: int

func use_skill(target) -> bool
func use_equipment() -> bool
func get_alive_count() -> int
func replenish_at_facility(facility: Node) -> void
```

```gdscript
# ===== EnemyUnit (S05) =====
class_name EnemyUnit extends Entity

signal target_changed(new_target: Node)

var enemy_data: EnemyData
var current_target: Node
var behavior_tree: BehaviorTree
var special_state: Dictionary  # 해커 해킹 진행도 등

func set_target(target: Node) -> void
func execute_special_mechanic() -> void
```

### 4.4 Combat 인터페이스 (S07, S08)

```gdscript
# ===== TileGrid (S07) =====
class_name TileGrid extends Node2D

signal tile_changed(pos: Vector2i, old_type: TileType, new_type: TileType)

var width: int
var height: int
var tiles: Array  # 2D array of TileData

func get_tile(pos: Vector2i) -> TileData
func set_tile(pos: Vector2i, type: TileType) -> void
func is_walkable(pos: Vector2i) -> bool
func is_valid_position(pos: Vector2i) -> bool
func get_neighbors(pos: Vector2i) -> Array[Vector2i]
func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]
func get_line_of_sight(from: Vector2i, to: Vector2i) -> Array[Vector2i]
func has_line_of_sight(from: Vector2i, to: Vector2i) -> bool
func get_tiles_in_range(center: Vector2i, range_val: int) -> Array[Vector2i]
func world_to_tile(world_pos: Vector2) -> Vector2i
func tile_to_world(tile_pos: Vector2i) -> Vector2
func get_elevation(pos: Vector2i) -> int
```

```gdscript
# ===== BattleController (S08) =====
class_name BattleController extends Node

signal battle_started()
signal battle_ended(result: BattleResult)
signal pause_state_changed(is_paused: bool)
signal slow_motion_changed(is_slow: bool)
signal selection_changed(selected: CrewSquad)

var is_paused: bool
var is_slow_motion: bool
var selected_squad: CrewSquad
var all_crews: Array[CrewSquad]
var all_enemies: Array[EnemyUnit]
var facilities: Array[Facility]
var current_wave: int
var tile_grid: TileGrid

func start_battle(station: StationData, crews: Array[CrewData]) -> void
func end_battle() -> BattleResult
func pause() -> void
func resume() -> void
func select_squad(squad: CrewSquad) -> void
func command_move(squad: CrewSquad, target_tile: Vector2i) -> void
func command_skill(squad: CrewSquad, target) -> void
func spawn_enemy(enemy_data: EnemyData, entry_point: Vector2i) -> EnemyUnit
func process_combat(delta: float) -> void
```

### 4.5 Campaign 인터페이스 (S10, S11)

```gdscript
# ===== SectorGenerator (S10) =====
class_name SectorGenerator extends RefCounted

func generate(seed: int, difficulty: Difficulty) -> SectorData

class SectorData:
    var seed: int
    var layers: Array[Array]  # Array of Array[SectorNode]
    var total_depth: int
```

```gdscript
# ===== StationGenerator (S10) =====
class_name StationGenerator extends RefCounted

func generate(seed: int, difficulty_score: float) -> StationData

class StationData:
    var seed: int
    var width: int
    var height: int
    var tiles: Array  # 2D TileType array
    var facilities: Array[FacilityPlacement]
    var entry_points: Array[Vector2i]
    var height_map: Array  # 2D elevation array
```

```gdscript
# ===== MetaProgress (S11) =====
class_name MetaProgress extends Node

signal unlock_achieved(unlock_id: String)
signal achievement_completed(achievement_id: String)

var unlocked_classes: Array[String]
var unlocked_traits: Array[String]
var unlocked_equipment: Array[String]
var unlocked_difficulties: Array[int]
var achievements: Dictionary
var statistics: Dictionary

func check_unlock_conditions() -> void
func is_unlocked(type: String, id: String) -> bool
func record_stat(stat_id: String, value) -> void
func get_stat(stat_id: String)
```

---

## 5. 디렉토리 구조

```
The-Fading-Raven/
├── docs/                            # 기획 문서
├── demo/                            # 웹 프로토타입
├── sessions/                        # 세션별 작업 문서
├── MASTER-PLAN.md                   # 이 문서
├── CODING-STANDARDS.md              # 코딩 규칙
│
└── godot/                           # ★ Godot 프로젝트 루트
    ├── project.godot                # S01
    ├── .gitignore                   # S01
    │
    ├── addons/                      # 외부 플러그인
    │
    ├── assets/
    │   ├── sprites/
    │   │   ├── crews/               # S04
    │   │   ├── enemies/             # S05
    │   │   ├── effects/             # S06
    │   │   ├── facilities/          # S10
    │   │   └── ui/                  # S12
    │   ├── audio/
    │   │   ├── sfx/                 # S06
    │   │   └── music/               # S11
    │   └── fonts/                   # S12
    │
    ├── resources/
    │   ├── crews/                   # S02 (.tres)
    │   ├── enemies/                 # S02 (.tres)
    │   ├── equipment/               # S02 (.tres)
    │   ├── traits/                  # S02 (.tres)
    │   ├── facilities/              # S02 (.tres)
    │   └── themes/                  # S12 (.tres)
    │
    ├── src/
    │   ├── autoload/                # S01, S03
    │   │   ├── Constants.gd         # S02
    │   │   ├── GameState.gd         # S03
    │   │   ├── EventBus.gd          # S03
    │   │   ├── AudioManager.gd      # S06
    │   │   └── MetaProgress.gd      # S11
    │   │
    │   ├── data/                    # S02
    │   │   ├── CrewClassData.gd
    │   │   ├── SkillData.gd
    │   │   ├── EnemyData.gd
    │   │   ├── EquipmentData.gd
    │   │   ├── TraitData.gd
    │   │   └── FacilityData.gd
    │   │
    │   ├── entities/                # S04, S05, S06
    │   │   ├── Entity.gd            # S04 (base)
    │   │   ├── crew/                # S04
    │   │   │   ├── CrewSquad.gd
    │   │   │   ├── CrewSquad.tscn
    │   │   │   ├── CrewMember.gd
    │   │   │   └── CrewMember.tscn
    │   │   ├── enemy/               # S05
    │   │   │   ├── EnemyUnit.gd
    │   │   │   ├── EnemyUnit.tscn
    │   │   │   ├── EnemySquad.gd
    │   │   │   └── EnemySquad.tscn
    │   │   ├── projectile/          # S06
    │   │   │   ├── Projectile.gd
    │   │   │   └── Projectile.tscn
    │   │   ├── turret/              # S04
    │   │   │   ├── Turret.gd
    │   │   │   └── Turret.tscn
    │   │   └── facility/            # S10
    │   │       ├── Facility.gd
    │   │       └── Facility.tscn
    │   │
    │   ├── systems/
    │   │   ├── combat/              # S07, S08
    │   │   │   ├── TileGrid.gd      # S07
    │   │   │   ├── Pathfinding.gd   # S07
    │   │   │   ├── LineOfSight.gd   # S07
    │   │   │   ├── BattleController.gd  # S08
    │   │   │   ├── SkillSystem.gd       # S08
    │   │   │   ├── EquipmentSystem.gd   # S08
    │   │   │   ├── DamageCalculator.gd  # S08
    │   │   │   └── RavenSystem.gd       # S08
    │   │   ├── wave/                # S09
    │   │   │   ├── WaveGenerator.gd
    │   │   │   ├── WaveManager.gd
    │   │   │   └── SpawnController.gd
    │   │   ├── ai/                  # S09
    │   │   │   ├── BehaviorTree.gd
    │   │   │   ├── AIManager.gd
    │   │   │   ├── behaviors/
    │   │   │   │   ├── BTNode.gd
    │   │   │   │   ├── BTSelector.gd
    │   │   │   │   ├── BTSequence.gd
    │   │   │   │   └── ...
    │   │   │   └── profiles/
    │   │   │       ├── RusherAI.gd
    │   │   │       ├── SniperAI.gd
    │   │   │       └── ...
    │   │   └── campaign/            # S10
    │   │       ├── SectorGenerator.gd
    │   │       ├── StationGenerator.gd
    │   │       ├── BSPGenerator.gd
    │   │       └── SeededRNG.gd
    │   │
    │   ├── ui/                      # S12
    │   │   ├── components/
    │   │   │   ├── Tooltip.gd
    │   │   │   ├── Tooltip.tscn
    │   │   │   ├── Toast.gd
    │   │   │   ├── Toast.tscn
    │   │   │   ├── Modal.gd
    │   │   │   ├── Modal.tscn
    │   │   │   ├── ProgressBar.gd
    │   │   │   └── ProgressBar.tscn
    │   │   ├── battle_hud/
    │   │   │   ├── BattleHUD.gd
    │   │   │   ├── BattleHUD.tscn
    │   │   │   ├── CrewPanel.gd
    │   │   │   ├── CrewPanel.tscn
    │   │   │   ├── WaveIndicator.gd
    │   │   │   └── RavenPanel.gd
    │   │   ├── menus/
    │   │   │   ├── MainMenu.gd
    │   │   │   ├── MainMenu.tscn
    │   │   │   ├── PauseMenu.gd
    │   │   │   ├── SettingsMenu.gd
    │   │   │   └── SettingsMenu.tscn
    │   │   ├── campaign/
    │   │   │   ├── SectorMapUI.gd
    │   │   │   ├── SectorMapUI.tscn
    │   │   │   ├── UpgradeScreen.gd
    │   │   │   └── UpgradeScreen.tscn
    │   │   └── effects/             # S06
    │   │       ├── ScreenEffects.gd
    │   │       ├── FloatingText.gd
    │   │       └── FloatingText.tscn
    │   │
    │   └── utils/                   # S01
    │       ├── Utils.gd
    │       └── SeededRNG.gd
    │
    ├── scenes/
    │   ├── Main.tscn                # S01
    │   ├── battle/
    │   │   └── Battle.tscn          # S08
    │   ├── campaign/
    │   │   ├── SectorMap.tscn       # S10
    │   │   └── StationPreview.tscn  # S10
    │   └── test/                    # 각 세션
    │       ├── TestBattle.tscn
    │       ├── TestGrid.tscn
    │       └── ...
    │
    └── tests/                       # 각 세션
        ├── test_tile_grid.gd        # S07
        ├── test_pathfinding.gd      # S07
        ├── test_crew.gd             # S04
        ├── test_enemy.gd            # S05
        ├── test_combat.gd           # S08
        ├── test_wave.gd             # S09
        ├── test_sector_gen.gd       # S10
        └── test_station_gen.gd      # S10
```

---

## 6. 코드 스타일 가이드

### 6.1 GDScript 규칙

```gdscript
# ===== 파일 구조 =====
# 1. class_name (있다면)
# 2. extends
# 3. 주석/문서화
# 4. signals
# 5. enums
# 6. constants
# 7. @export 변수
# 8. public 변수
# 9. private 변수 (_prefix)
# 10. @onready 변수
# 11. _init, _ready, _process 등 빌트인
# 12. public 함수
# 13. private 함수 (_prefix)

# ===== 네이밍 =====
# 클래스: PascalCase (CrewSquad)
# 함수/변수: snake_case (get_alive_count)
# 상수: UPPER_SNAKE_CASE (MAX_SQUAD_SIZE)
# 시그널: snake_case, 과거형 (damage_dealt, wave_ended)
# private: _prefix (_internal_state)

# ===== 타입 힌트 필수 =====
func calculate_damage(base: int, multiplier: float) -> int:
    return int(base * multiplier)

var crews: Array[CrewSquad] = []

# ===== 문서화 =====
## 주어진 타일에서 목표까지의 경로를 계산합니다.
## [br][br]
## [param from]: 시작 타일 좌표
## [param to]: 목표 타일 좌표
## [return]: 경로 타일 배열 (시작 제외, 목표 포함)
func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
    pass
```

### 6.2 씬 구조 규칙

```
# 씬 노드 네이밍
- PascalCase 사용
- 역할 명확히 (HealthBar, not Bar1)
- 컨테이너: HBox, VBox, Grid 등 접미사

# 씬 파일
- 하나의 .gd는 하나의 .tscn과 매칭
- 재사용 컴포넌트는 components/ 에
```

### 6.3 시그널 사용 규칙

```gdscript
# 직접 참조 대신 시그널 사용
# BAD
func _on_enemy_died():
    game_state.add_credits(10)  # 직접 참조

# GOOD
func _on_enemy_died():
    EventBus.enemy_killed.emit(self)  # 이벤트 발행
# GameState에서 구독하여 처리
```

---

## 7. 테스트 가이드

### 7.1 유닛 테스트 구조

```gdscript
# tests/test_tile_grid.gd
extends GutTest

var grid: TileGrid

func before_each():
    grid = TileGrid.new()
    grid.initialize(10, 10)

func after_each():
    grid.free()

func test_is_walkable_floor():
    grid.set_tile(Vector2i(5, 5), TileType.FLOOR)
    assert_true(grid.is_walkable(Vector2i(5, 5)))

func test_is_walkable_wall():
    grid.set_tile(Vector2i(5, 5), TileType.WALL)
    assert_false(grid.is_walkable(Vector2i(5, 5)))

func test_pathfinding_simple():
    # 5x5 빈 그리드
    var path = grid.find_path(Vector2i(0, 0), Vector2i(4, 4))
    assert_not_null(path)
    assert_gt(path.size(), 0)
```

### 7.2 테스트 커버리지 요구사항

| 세션 | 최소 커버리지 | 핵심 테스트 |
|------|--------------|-------------|
| S02 | 80% | 데이터 로드, 유효성 검증 |
| S04 | 70% | 스쿼드 생성, 데미지, 회복 |
| S05 | 70% | 적 생성, 행동, 특수 메카닉 |
| S07 | 90% | 경로탐색, 시야선, 타일 연산 |
| S08 | 80% | 데미지 계산, 스킬 효과 |
| S09 | 80% | 웨이브 생성, AI 행동 |
| S10 | 85% | 맵 생성, 유효성 검증 |

---

## 8. 동기화 프로토콜

### 8.1 상태 보고 형식

각 세션은 세션 문서에 다음 형식으로 상태 업데이트:

```markdown
## 진행 상황

### [날짜] 업데이트
- **상태**: 🟢 정상 / 🟡 지연 / 🔴 블로킹
- **완료**:
  - [x] 항목 1
  - [x] 항목 2
- **진행 중**:
  - [ ] 항목 3 (50%)
- **이슈**:
  - 이슈 설명 (해결/미해결)
- **다른 세션 요청**:
  - S03에게: EventBus에 signal_name 추가 필요
```

### 8.2 인터페이스 변경 프로토콜

1. MASTER-PLAN.md의 인터페이스 정의 변경 시:
   - 변경 제안 → 관련 세션 검토 → 승인 → 반영
   - 모든 변경은 버전 기록

2. 긴급 변경 시:
   - MASTER-PLAN.md에 `[BREAKING]` 태그와 함께 기록
   - 영향받는 세션 목록 명시

### 8.3 의존성 해결

```
의존하는 세션이 미완료일 때:
1. 인터페이스만 사용하여 구현 (stub/mock)
2. 테스트는 mock 객체 사용
3. 통합 테스트는 나중에 추가
```

---

## 9. 버전 기록

| 버전 | 날짜 | 변경 내용 |
|------|------|----------|
| 1.0.0 | 2026-02-04 | 초기 마스터 플랜 생성 |

---

## 10. 세션 문서 링크

- [SESSION-01: Project Setup](sessions/SESSION-01.md)
- [SESSION-02: Data Resources](sessions/SESSION-02.md)
- [SESSION-03: GameState & EventBus](sessions/SESSION-03.md)
- [SESSION-04: Crew System](sessions/SESSION-04.md)
- [SESSION-05: Enemy System](sessions/SESSION-05.md)
- [SESSION-06: Effects & Projectiles](sessions/SESSION-06.md)
- [SESSION-07: TileGrid & Pathfinding](sessions/SESSION-07.md)
- [SESSION-08: Combat Controller](sessions/SESSION-08.md)
- [SESSION-09: Wave & AI System](sessions/SESSION-09.md)
- [SESSION-10: Campaign Generation](sessions/SESSION-10.md)
- [SESSION-11: Meta Progress & Save](sessions/SESSION-11.md)
- [SESSION-12: UI Components](sessions/SESSION-12.md)
