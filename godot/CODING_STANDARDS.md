# The Fading Raven - GDScript 코딩 규범

Godot 4.5의 엄격한 타입 시스템에 맞춘 코딩 표준입니다.

---

## 1. 타입 명시 규칙

### 반드시 명시적 타입을 사용하는 경우

```gdscript
# ❌ 금지: 삼항 연산자에서 타입 추론
var damage := enemy_data.damage if enemy_data else 10

# ✅ 권장: 명시적 타입
var damage: int = enemy_data.damage if enemy_data else 10
```

```gdscript
# ❌ 금지: Dictionary/Array에서 값 가져올 때 타입 추론
var item := my_dict[key]
var element := my_array[i]

# ✅ 권장: 명시적 타입
var item: Node3D = my_dict[key]
var element: Vector2i = my_array[i]
```

```gdscript
# ❌ 금지: 함수 반환값이 Variant일 때 타입 추론
var result := some_function_returning_variant()

# ✅ 권장: 명시적 타입
var result: Dictionary = some_function_returning_variant()
```

### 타입 추론 허용 경우 (`:=`)

```gdscript
# ✅ 허용: 리터럴 값
var count := 0
var name := "player"
var position := Vector3.ZERO

# ✅ 허용: 생성자 호출
var timer := Timer.new()
var mesh := BoxMesh.new()

# ✅ 허용: 명확한 타입의 함수 반환
var length := my_string.length()  # int 반환 명확
```

---

## 2. 클래스 이름 충돌 방지

### 전역 클래스 (`class_name`)

```gdscript
# ❌ 금지: 내부 클래스와 전역 클래스 이름 충돌
# file: BTNode.gd
class_name BTNode  # 전역 등록

# file: BehaviorTree.gd
class BTNode:  # 충돌!
    pass
```

```gdscript
# ✅ 권장: 고유한 이름 사용
# 전역 클래스는 프로젝트 전체에서 유일해야 함
class_name MyUniqueClassName
```

### 파일당 하나의 `class_name`만 사용

---

## 3. Null 안전성

```gdscript
# ❌ 금지: null 체크 없이 접근
var node := get_node("Child")
node.do_something()

# ✅ 권장: null 체크 포함
var node: Node = get_node_or_null("Child")
if node:
    node.do_something()
```

---

## 4. 노드 타입별 속성 주의

```gdscript
# ❌ 금지: Node2D에서 Control 속성 사용
# (Node2D에는 mouse_filter가 없음)
extends Node2D
func _ready():
    mouse_filter = Control.MOUSE_FILTER_PASS  # 에러!

# ✅ 권장: 상속 계층 확인 후 사용
extends Control
func _ready():
    mouse_filter = Control.MOUSE_FILTER_PASS  # OK
```

---

## 5. 신호 연결

```gdscript
# ✅ 권장: 명시적 타입과 함께 연결
signal damage_taken(amount: int, source: Node)

func _ready():
    damage_taken.connect(_on_damage_taken)

func _on_damage_taken(amount: int, source: Node) -> void:
    pass
```

---

## 6. 상수 및 열거형

```gdscript
# ✅ 권장: 상수는 대문자
const MAX_HEALTH: int = 100
const TILE_SIZE: float = 32.0

# ✅ 권장: 열거형은 PascalCase
enum State { IDLE, MOVING, ATTACKING }
```

---

## 7. 함수 시그니처

```gdscript
# ✅ 권장: 반환 타입 항상 명시
func calculate_damage(base: int, multiplier: float) -> int:
    return int(base * multiplier)

# ✅ 권장: void 반환도 명시
func apply_damage(amount: int) -> void:
    health -= amount
```

---

## 8. 테스트 데이터 / 폴백 금지

```gdscript
# ❌ 금지: 프로덕션 코드에 테스트 폴백
func load_squads() -> void:
    var squads = GameState.get_crews()
    if squads.is_empty():
        squads = _create_test_squads()  # 금지!

# ✅ 권장: 데이터 무결성 유지
func load_squads() -> void:
    var squads = GameState.get_crews()
    if squads.is_empty():
        push_warning("No squads available")
        return
```

---

## 9. 파일 구조

```
src/
├── autoload/        # 전역 싱글톤
├── entities/        # 게임 엔티티 (crew, enemy)
├── scenes/          # 씬 컨트롤러
├── systems/         # 게임 시스템 (ai, combat, wave)
├── ui/              # UI 컴포넌트
└── rendering/       # 렌더링 관련
```

---

## 체크리스트 (커밋 전)

- [ ] 모든 변수에 타입 명시 (특히 삼항연산자, Dictionary 접근)
- [ ] `class_name` 충돌 없음
- [ ] null 체크 완료
- [ ] 테스트 폴백 코드 제거
- [ ] `--headless --quit`으로 파싱 에러 확인
