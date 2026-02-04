# The Fading Raven - 코딩 표준 및 세션 호환성 가이드

> **버전**: 1.1.0
> **최종 업데이트**: 2026-02-04
> **목적**: 12개 병렬 세션의 코드 호환성 보장

---

## 1. 프로젝트 구조

### 1.1 Godot 프로젝트 경로

```
The-Fading-Raven/
├── docs/                    # 문서 (기존)
├── demo/                    # 웹 프로토타입 (기존)
├── sessions/                # 세션 문서
├── MASTER-PLAN.md
├── CODING-STANDARDS.md      # 이 문서
│
└── godot/                   # ★ Godot 프로젝트 루트
    ├── project.godot
    ├── .gitignore
    ├── assets/
    ├── resources/
    ├── src/
    ├── scenes/
    └── tests/
```

**중요**: 모든 Godot 파일은 `godot/` 폴더 안에 위치. 문서와 프로토타입은 루트에 유지.

---

## 2. 세션 간 호환성 분석 결과

### 2.1 발견된 문제점

| # | 문제 | 영향 세션 | 심각도 | 해결책 |
|---|------|----------|--------|--------|
| 1 | 내부 클래스를 @export에 사용 | S03, S04 | 🔴 높음 | Resource 클래스 분리 |
| 2 | TILE_SIZE 상수 중복 | S04, S07 | 🟡 중간 | Constants에서 중앙 관리 |
| 3 | 타입 힌트 불일치 | 전체 | 🟡 중간 | 표준 규칙 적용 |
| 4 | preload 경로 미존재 파일 참조 | S04, S05, S06 | 🟡 중간 | 조건부 로드 또는 지연 로드 |
| 5 | Signal 파라미터 명명 불일치 | S03, S12 | 🟢 낮음 | 명명 규칙 통일 |
| 6 | 순환 의존성 위험 | S04↔S07 | 🟡 중간 | 의존성 주입 패턴 |

### 2.2 해결 방안

#### 문제 1: 내부 클래스 → Resource 분리

**AS-IS (문제)**
```gdscript
# GameState.gd
class CrewData:
    var id: String
    ...

# CrewSquad.gd
@export var crew_data: GameState.CrewData  # ❌ 에디터 호환 불가
```

**TO-BE (해결)**
```gdscript
# src/data/CrewRuntimeData.gd
class_name CrewRuntimeData
extends Resource

@export var id: String
@export var class_id: String
@export var rank: int
...
```

#### 문제 2: 상수 중앙 관리

**모든 공유 상수는 Constants.gd에서 정의**
```gdscript
# Constants.gd
const TILE_SIZE: int = 32
const TILE_SIZE_HALF: int = 16

# 다른 스크립트에서
var pos = tile * Constants.TILE_SIZE
```

#### 문제 4: 안전한 리소스 로딩

```gdscript
# 조건부 로드 (권장)
var _member_scene: PackedScene

func _ready():
    if ResourceLoader.exists("res://godot/src/entities/crew/CrewMember.tscn"):
        _member_scene = load("res://godot/src/entities/crew/CrewMember.tscn")

# 또는 지연 로드
func _get_member_scene() -> PackedScene:
    if _member_scene == null:
        _member_scene = load("res://godot/src/entities/crew/CrewMember.tscn")
    return _member_scene
```

#### 문제 6: 의존성 주입

```gdscript
# ❌ 직접 참조
func _tile_to_world(tile: Vector2i) -> Vector2:
    return TileGrid.tile_to_world(tile)  # TileGrid 직접 참조

# ✅ 의존성 주입
var _tile_grid: TileGrid

func set_tile_grid(grid: TileGrid):
    _tile_grid = grid

func _tile_to_world(tile: Vector2i) -> Vector2:
    if _tile_grid:
        return _tile_grid.tile_to_world(tile)
    return Vector2(tile.x * Constants.TILE_SIZE, tile.y * Constants.TILE_SIZE)
```

---

## 3. GDScript 코딩 규칙

### 3.1 파일 구조 (필수 순서)

```gdscript
# 1. class_name (있으면)
class_name MyClass

# 2. extends
extends Node2D

# 3. 문서 주석
## 이 클래스는 ~를 담당합니다.
## [br][br]
## 사용 예:
## [codeblock]
## var obj = MyClass.new()
## [/codeblock]

# 4. signals
signal health_changed(current: int, max_hp: int)
signal died()

# 5. enums (클래스 로컬)
enum State { IDLE, MOVING, ATTACKING }

# 6. constants
const MAX_HEALTH: int = 100
const SPEED: float = 5.0

# 7. @export 변수
@export var entity_id: String
@export var team: int = 0

# 8. public 변수
var current_hp: int
var is_alive: bool = true

# 9. private 변수 (_prefix)
var _internal_timer: float = 0.0
var _cached_data: Dictionary = {}

# 10. @onready 변수
@onready var sprite: Sprite2D = $Sprite
@onready var collision: CollisionShape2D = $Collision

# 11. 빌트인 함수
func _init():
    pass

func _ready():
    pass

func _process(delta: float):
    pass

func _physics_process(delta: float):
    pass

# 12. public 함수
func take_damage(amount: int) -> int:
    pass

# 13. private 함수 (_prefix)
func _calculate_damage() -> int:
    pass
```

### 3.2 명명 규칙

| 대상 | 규칙 | 예시 |
|------|------|------|
| 클래스 | PascalCase | `CrewSquad`, `TileGrid` |
| 함수 | snake_case | `get_alive_count()`, `apply_damage()` |
| 변수 | snake_case | `current_hp`, `tile_position` |
| 상수 | UPPER_SNAKE_CASE | `MAX_HEALTH`, `TILE_SIZE` |
| private | _prefix | `_internal_state`, `_cache` |
| Signal | snake_case, 과거형 | `damage_dealt`, `wave_started` |
| Enum 값 | UPPER_SNAKE_CASE | `State.IDLE`, `DamageType.PHYSICAL` |

### 3.3 타입 힌트 (필수)

```gdscript
# ✅ 올바른 사용
func calculate_damage(base: int, multiplier: float) -> int:
    return int(base * multiplier)

var crews: Array[CrewSquad] = []
var position: Vector2i = Vector2i.ZERO
var stats: Dictionary = {}

# ✅ 제네릭 배열
func get_neighbors() -> Array[Vector2i]:
    var result: Array[Vector2i] = []
    return result

# ❌ 잘못된 사용
func calculate_damage(base, multiplier):  # 타입 힌트 누락
    return base * multiplier

var crews = []  # 타입 힌트 누락
```

### 3.4 Signal 정의 규칙

```gdscript
# ✅ 파라미터에 타입과 의미 있는 이름
signal damage_dealt(source: Node, target: Node, amount: int, damage_type: int)
signal wave_started(wave_number: int, total_waves: int, enemy_preview: Array)

# ❌ 피해야 할 것
signal damage_dealt(a, b, c, d)  # 의미 없는 이름
signal wave_started(n: int)      # 불명확한 이름
```

### 3.5 문서화 주석

```gdscript
## 주어진 타일에서 목표까지의 경로를 계산합니다.
## [br][br]
## A* 알고리즘을 사용하며, 이동 불가 타일은 우회합니다.
## [br][br]
## [param from]: 시작 타일 좌표
## [param to]: 목표 타일 좌표
## [param ignore_occupants]: true면 점유된 타일도 통과 가능
## [return]: 경로 타일 배열 (시작점 제외, 목표점 포함). 경로가 없으면 빈 배열.
func find_path(from: Vector2i, to: Vector2i, ignore_occupants: bool = false) -> Array[Vector2i]:
    pass
```

---

## 4. Autoload 규칙

### 4.1 로드 순서 (project.godot)

```ini
[autoload]
Constants="*res://godot/src/autoload/Constants.gd"
EventBus="*res://godot/src/autoload/EventBus.gd"
GameState="*res://godot/src/autoload/GameState.gd"
AudioManager="*res://godot/src/autoload/AudioManager.gd"
EffectsManager="*res://godot/src/autoload/EffectsManager.gd"
MetaProgress="*res://godot/src/autoload/MetaProgress.gd"
```

**순서 규칙**:
1. `Constants` - 다른 모든 것이 참조 (가장 먼저)
2. `EventBus` - Signal 허브 (Constants만 참조)
3. `GameState` - 게임 상태 (Constants, EventBus 참조)
4. 나머지 - 위 3개 참조 가능

### 4.2 Autoload 접근

```gdscript
# ✅ 직접 전역 이름 사용
Constants.TILE_SIZE
GameState.current_run
EventBus.damage_dealt.emit(...)

# ❌ get_node 사용 금지
get_node("/root/Constants")  # 불필요
```

---

## 5. Signal 사용 패턴

### 5.1 EventBus 발행 규칙

```gdscript
# ✅ 이벤트 발생 시점에 emit
func _die():
    is_alive = false
    died.emit()
    EventBus.entity_died.emit(self)  # 전역 알림

# ✅ 데이터와 함께 emit
func take_damage(amount: int, type: int, source: Node) -> int:
    var actual = _calculate_damage(amount, type)
    current_hp -= actual
    EventBus.damage_dealt.emit(source, self, actual, type)
    return actual
```

### 5.2 Signal 구독 규칙

```gdscript
func _ready():
    # ✅ 로컬 시그널 연결
    health_changed.connect(_on_health_changed)

    # ✅ EventBus 구독
    EventBus.wave_started.connect(_on_wave_started)
    EventBus.entity_died.connect(_on_entity_died)

func _exit_tree():
    # ✅ EventBus 구독 해제 (씬 전환 시 중요)
    if EventBus:
        EventBus.wave_started.disconnect(_on_wave_started)
        EventBus.entity_died.disconnect(_on_entity_died)
```

---

## 6. Resource 클래스 규칙

### 6.1 데이터 Resource vs 런타임 Resource

| 구분 | 용도 | 저장 위치 | 예시 |
|------|------|----------|------|
| **데이터 Resource** | 정적 게임 데이터 | `resources/` | CrewClassData, EnemyData |
| **런타임 Resource** | 런타임 상태 | 메모리/세이브 | CrewRuntimeData, RunData |

### 6.2 데이터 Resource 예시

```gdscript
# src/data/CrewClassData.gd
class_name CrewClassData
extends Resource

@export var id: String
@export var display_name: String
@export var display_name_ko: String
@export var base_squad_size: int = 8
@export var base_hp: int = 10
@export var base_damage: int = 3
@export var attack_speed: float = 1.0
@export var move_speed: float = 1.5
@export var attack_range: float = 1.0
@export var color: Color = Color.WHITE
@export var skill_id: String
@export var strengths: Array[String] = []
@export var weaknesses: Array[String] = []
```

### 6.3 런타임 Resource 예시

```gdscript
# src/data/CrewRuntimeData.gd
class_name CrewRuntimeData
extends Resource

## 런타임 크루 상태 (세이브/로드 대상)

@export var id: String
@export var class_id: String  # CrewClassData.id 참조
@export var rank: int = 0
@export var skill_level: int = 0
@export var equipment_id: String = ""
@export var equipment_level: int = 0
@export var trait_id: String = ""
@export var current_hp_ratio: float = 1.0
@export var is_alive: bool = true

func get_class_data() -> CrewClassData:
    return Constants.get_crew_class(class_id)
```

---

## 7. 씬(Scene) 규칙

### 7.1 씬-스크립트 매칭

```
# 1:1 매칭 원칙
CrewSquad.gd  ↔  CrewSquad.tscn
EnemyUnit.gd  ↔  EnemyUnit.tscn
Tooltip.gd    ↔  Tooltip.tscn
```

### 7.2 노드 명명

```
# PascalCase, 역할 명확히
CrewSquad (루트)
├── Members (컨테이너)
│   ├── Member0
│   ├── Member1
│   └── ...
├── SkillCooldownTimer (Timer)
├── RecoveryTimer (Timer)
├── Sprite (Sprite2D)
├── HealthBar (ProgressBar)
└── SelectionIndicator (ColorRect)
```

### 7.3 그룹(Group) 규칙

```gdscript
# 표준 그룹 이름
"crews"      # 플레이어 크루 스쿼드
"enemies"    # 적 유닛
"turrets"    # 터렛
"facilities" # 시설
"projectiles"# 투사체

# 그룹 추가
func _ready():
    add_to_group("crews")

# 그룹으로 검색
var all_enemies = get_tree().get_nodes_in_group("enemies")
```

---

## 8. 에러 처리

### 8.1 Null 체크

```gdscript
# ✅ 안전한 접근
func get_crew(crew_id: String) -> CrewRuntimeData:
    if current_run == null:
        return null
    for crew in current_run.crews:
        if crew.id == crew_id:
            return crew
    return null

# ✅ 사용 전 체크
var crew = GameState.get_crew(id)
if crew:
    crew.rank += 1
```

### 8.2 경고 메시지

```gdscript
# 개발 중 스텁 함수
func get_crew_class(id: String) -> CrewClassData:
    if not _crew_classes.has(id):
        push_warning("CrewClass not found: " + id)
        return null
    return _crew_classes[id]

# 구현 예정 표시
func some_feature():
    push_warning("some_feature: 미구현 - S08에서 구현 예정")
```

---

## 9. 테스트 규칙

### 9.1 테스트 파일 명명

```
tests/
├── test_tile_grid.gd      # S07
├── test_pathfinding.gd    # S07
├── test_crew_squad.gd     # S04
├── test_enemy_unit.gd     # S05
├── test_game_state.gd     # S03
└── test_wave_generator.gd # S09
```

### 9.2 테스트 구조 (GUT 프레임워크)

```gdscript
extends GutTest

var _grid: TileGrid

func before_each():
    _grid = TileGrid.new()
    _grid.initialize(10, 10)
    add_child(_grid)

func after_each():
    _grid.queue_free()

func test_is_walkable_floor():
    _grid.set_tile_type(Vector2i(5, 5), Constants.TileType.FLOOR)
    assert_true(_grid.is_walkable(Vector2i(5, 5)), "Floor should be walkable")

func test_is_walkable_wall():
    _grid.set_tile_type(Vector2i(5, 5), Constants.TileType.WALL)
    assert_false(_grid.is_walkable(Vector2i(5, 5)), "Wall should not be walkable")
```

---

## 10. 세션 문서 규칙

### 10.1 진행 상황 업데이트 형식

```markdown
## 6. 진행 상황

### [2026-02-04] 작업 시작

- **상태**: 🟢 정상 / 🟡 지연 / 🔴 블로킹
- **완료**:
  - [x] TileData.gd
  - [x] TileGrid.gd
- **진행 중**:
  - [ ] Pathfinding.gd (70%)
- **이슈**:
  - ⚠️ StationData 구조 확인 필요 (S10 대기)
- **다른 세션 요청**:
  - S10에게: StationData.height_map 타입 확인
  - S02에게: Constants.TileType에 COVER_HALF 추가 요청

### [2026-02-05] 업데이트

- **상태**: 🟢 정상
- **완료**:
  - [x] Pathfinding.gd
  - [x] LineOfSight.gd
- **이슈**:
  - ✅ StationData 구조 확인 완료 (S10 응답)
```

### 10.2 인터페이스 변경 요청 형식

```markdown
## 인터페이스 변경 요청

### [요청] Constants에 TileType 추가

**요청 세션**: S07
**대상 세션**: S02
**내용**: TileType enum에 COVER_HALF, COVER_FULL 추가 필요

```gdscript
enum TileType {
    # 기존
    VOID, FLOOR, WALL, AIRLOCK, ELEVATED, LOWERED, FACILITY,
    # 추가 요청
    COVER_HALF,  # 반엄폐물
    COVER_FULL   # 완전엄폐물
}
```

**이유**: 엄폐 시스템 구현에 필요
**영향**: S08 (데미지 계산에서 참조)
```

---

## 11. 버전 관리

### 11.1 커밋 메시지 형식

```
[S##] 작업 내용 요약

예:
[S01] project.godot 초기 설정
[S07] TileGrid 경로탐색 구현
[S04] CrewSquad 스킬 시스템 추가
[MASTER] 인터페이스 변경: TileType에 COVER 추가
```

### 11.2 브랜치 전략 (선택)

```
main           # 안정 버전
├── develop    # 통합 개발
├── session/01 # S01 작업
├── session/02 # S02 작업
└── ...
```

---

## 12. GDScript 4.x 오류 방지 가이드

> **2026-02-04 추가**: 실제 개발 중 발생한 오류와 해결책 정리

### 12.1 Godot 네이티브 클래스명 충돌

**문제**: `class_name`이 Godot 내장 클래스와 충돌

```gdscript
# ❌ 오류: "Class 'TileData' hides a native class"
class_name TileData
extends RefCounted

# ✅ 해결: 접두사 추가
class_name GridTileData
extends RefCounted
```

**주의할 네이티브 클래스**: `TileData`, `Animation`, `Image`, `Texture`, `Font`, `Theme` 등

---

### 12.2 Variant 타입 추론 오류

**문제**: `:=` 연산자가 Variant에서 타입을 추론하려 할 때 발생

```gdscript
# ❌ 오류: "Cannot infer the type of X variable because the value doesn't have a set type"
var current := queue.pop_front()    # pop_front()는 Variant 반환
var tile := some_dict[key]          # Dictionary 값은 Variant
var data := some_array[0]           # untyped Array 값은 Variant

# ✅ 해결 방법 1: 명시적 캐스트
var current: String = queue.pop_front() as String

# ✅ 해결 방법 2: 타입 어노테이션
var current: String = queue.pop_front()

# ✅ 해결 방법 3: 타입 추론 안 쓰기
var tile = tiles[pos.y][pos.x]  # := 대신 = 사용
```

**Variant를 반환하는 메서드들**:
- `Array.pop_front()`, `Array.pop_back()`, `Array.front()`, `Array.back()`
- `Dictionary.get()`, `Dictionary[]` 인덱싱
- 타입이 지정되지 않은 `Array[]` 인덱싱

---

### 12.3 preload vs load

**문제**: `preload`는 파싱 시점에 파일을 로드하므로 순환 참조 발생 가능

```gdscript
# ❌ 오류: "Could not resolve script" (순환 참조 또는 로드 순서 문제)
const MyClass = preload("res://path/to/Script.gd")

# ✅ 해결: 런타임 load() 사용
var MyClass: GDScript

func _init() -> void:
    MyClass = load("res://path/to/Script.gd")

# ✅ 또는 _ready()에서 로드
func _ready() -> void:
    MyClass = load("res://path/to/Script.gd")
```

**규칙**:
- `preload`: 항상 존재하고 순환 참조 없는 리소스만
- `load`: 동적 로드, 순환 참조 가능성 있는 스크립트

---

### 12.4 preload된 스크립트를 타입으로 사용 불가

**문제**: `const`로 preload한 스크립트는 타입 어노테이션으로 사용 불가

```gdscript
const MyScript = preload("res://MyScript.gd")

# ❌ 오류: preload된 const는 타입으로 사용 불가
func get_data() -> MyScript:
    pass
var data: MyScript = MyScript.new()

# ✅ 해결: 타입 어노테이션 제거
func get_data():
    return MyScript.new()
var data = MyScript.new()

# ✅ 또는: class_name이 있으면 그것 사용
# MyScript.gd에 class_name MyClass가 있다면:
func get_data() -> MyClass:
    pass
```

---

### 12.5 씬 파일 UID 불일치

**문제**: `.tscn` 파일 간 UID 참조 불일치로 씬 로드 실패

```
# Campaign.tscn
[ext_resource uid="uid://abc123" path="res://SectorMapUI.tscn"]

# SectorMapUI.tscn (UID가 다름)
[gd_scene uid="uid://xyz789" ...]  # ❌ 불일치!
```

**해결**:
1. 참조하는 쪽의 UID에 맞춰 수정
2. 또는 `.godot/uid_cache.bin` 삭제 후 Godot 재시작

```bash
# 캐시 삭제 (Godot 닫은 상태에서)
rm godot/.godot/uid_cache.bin
rm godot/.godot/global_script_class_cache.cfg
```

---

### 12.6 BehaviorTree/상속 리턴 타입 오류

**문제**: 자식 클래스 반환 시 부모 클래스 타입으로 선언된 경우

```gdscript
# BTNode.gd
class_name BTNode
func evaluate() -> BTNode:
    pass

# BTSelector.gd
class_name BTSelector
extends BTNode

# ❌ 오류: "Cannot return value of type 'BTSelector' because the function return type is 'BTNode'"
func create_tree() -> BTNode:
    var selector = BTSelector.new()
    return selector  # BTSelector는 BTNode의 자식인데도 오류

# ✅ 해결: 완전한 클래스 경로 사용 또는 리턴 타입 변경
func create_tree() -> BehaviorTree.BTSelector:
    var selector = BTSelector.new()
    return selector
```

---

### 12.7 class_name 등록 실패

**문제**: `class_name`이 전역에 등록되지 않아 다른 스크립트에서 인식 불가

**원인**:
1. 스크립트에 파싱 오류가 있음
2. 캐시가 오래됨
3. Godot 재시작 필요

**해결**:
```bash
# 1. 캐시 삭제
rm godot/.godot/global_script_class_cache.cfg

# 2. Godot 완전히 종료 후 재시작

# 3. 스크립트 오류 확인 (에디터에서 빨간 X 표시)
```

---

### 12.8 타입 추론 경고를 에러로 처리

**문제**: project.godot 설정으로 경고가 에러로 처리됨

```ini
# project.godot
[debug]
gdscript/warnings/untyped_declaration=1        # 경고
gdscript/warnings/inferred_declaration=1       # 경고
gdscript/warnings/treat_warnings_as_errors=true # ❌ 경고→에러
```

**해결**: 개발 중에는 `false`로 설정

```ini
[debug]
gdscript/warnings/treat_warnings_as_errors=false
```

---

### 12.9 typed Array 메서드 반환값

**문제**: `Array[Type]`이어도 `pop_front()` 등은 여전히 `Variant` 반환

```gdscript
var queue: Array[String] = ["a", "b", "c"]

# ❌ 오류: pop_front()는 Variant 반환
var item := queue.pop_front()

# ✅ 해결
var item: String = queue.pop_front() as String
# 또는
var item = queue.pop_front()  # 타입 추론 안 씀
```

---

### 12.10 요약: 안전한 코딩 패턴

```gdscript
# 1. 타입 추론 대신 명시적 타입 사용
var tile: MyTileData = tiles[y][x]        # ✅
var tile := tiles[y][x]                    # ❌ Variant 추론 오류

# 2. class_name 네이티브 충돌 방지
class_name GridTileData                    # ✅ 접두사
class_name TileData                        # ❌ 네이티브 충돌

# 3. preload 대신 load (순환 참조 시)
var Script = load("res://script.gd")       # ✅
const Script = preload("res://script.gd")  # ❌ 순환 참조 위험

# 4. Array 메서드 캐스팅
var s: String = arr.pop_front() as String  # ✅
var s := arr.pop_front()                   # ❌ Variant 추론 오류

# 5. 캐시 문제 시 삭제
# rm .godot/uid_cache.bin
# rm .godot/global_script_class_cache.cfg
```

---

## 13. 참고 자료

### Godot 공식 문서
- [GDScript Style Guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)
- [Best Practices](https://docs.godotengine.org/en/stable/tutorials/best_practices/index.html)
- [Signals](https://docs.godotengine.org/en/stable/getting_started/step_by_step/signals.html)

### 커뮤니티 가이드
- [GDQuest Guidelines](https://gdquest.gitbook.io/gdquests-guidelines/godot-gdscript-guidelines)
- [Godot Community Conventions](https://godot.community/topic/27/gdscript-coding-conventions-best-practices-for-readable-and-maintainable-code)

---

## 변경 이력

| 버전 | 날짜 | 변경 내용 |
|------|------|----------|
| 1.0.0 | 2026-02-04 | 초기 버전 작성 |
| 1.1.0 | 2026-02-04 | GDScript 4.x 오류 방지 가이드 추가 (섹션 12) |
