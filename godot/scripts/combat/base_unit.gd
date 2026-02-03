## BaseUnit - 모든 유닛의 기본 클래스
## 크루와 적 유닛 공통 로직
extends CharacterBody2D
class_name BaseUnit

# ===========================================
# 상태
# ===========================================

@export var unit_id: String = ""
@export var unit_name: String = ""
@export var team: int = 0  # 0 = 크루, 1 = 적

var grid_position: Vector2i = Vector2i.ZERO
var target_position: Vector2i = Vector2i.ZERO
var combat_state: CombatMechanics.CombatState = CombatMechanics.CombatState.IDLE

var current_target: BaseUnit = null
var is_alive: bool = true

# 이동
var move_speed: float = 100.0
var path: Array[Vector2i] = []
var path_index: int = 0

# 전투
var attack_damage: int = 10
var attack_range: int = 1
var attack_cooldown: float = 1.0
var attack_timer: float = 0.0

# 시각 요소
@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar: ProgressBar = $HealthBar if has_node("HealthBar") else null
@onready var selection_indicator: Node2D = $SelectionIndicator if has_node("SelectionIndicator") else null

# 참조
var grid: TileGrid = null
var pathfinder: Pathfinder = null


# ===========================================
# 시그널
# ===========================================

signal died(unit: BaseUnit)
signal took_damage(unit: BaseUnit, amount: int, source: BaseUnit)
signal state_changed(unit: BaseUnit, new_state: CombatMechanics.CombatState)
signal reached_destination(unit: BaseUnit)


# ===========================================
# 초기화
# ===========================================

func _ready() -> void:
	add_to_group("units")
	_setup_unit()


func _setup_unit() -> void:
	# 서브클래스에서 오버라이드
	pass


func initialize(unit_data: Dictionary, tile_grid: TileGrid, path_finder: Pathfinder) -> void:
	grid = tile_grid
	pathfinder = path_finder

	unit_id = unit_data.get("id", "")
	unit_name = unit_data.get("name", "Unit")

	grid_position = unit_data.get("position", Vector2i.ZERO)
	position = _grid_to_world(grid_position)

	# 그리드에 등록
	if grid:
		grid.add_entity(grid_position, self)


# ===========================================
# 게임 루프
# ===========================================

func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	# 공격 쿨다운
	if attack_timer > 0:
		attack_timer -= delta

	# 상태별 처리
	match combat_state:
		CombatMechanics.CombatState.MOVING:
			_process_movement(delta)
		CombatMechanics.CombatState.ENGAGING:
			_process_combat(delta)
		CombatMechanics.CombatState.RECOVERING:
			_process_recovery(delta)


func _process_movement(delta: float) -> void:
	if path.is_empty() or path_index >= path.size():
		_on_path_complete()
		return

	var target_world := _grid_to_world(path[path_index])
	var direction := (target_world - position).normalized()
	var distance := position.distance_to(target_world)

	if distance < 5.0:
		# 다음 경로 지점
		_update_grid_position(path[path_index])
		path_index += 1
	else:
		velocity = direction * move_speed
		move_and_slide()


func _process_combat(_delta: float) -> void:
	# 서브클래스에서 오버라이드
	pass


func _process_recovery(_delta: float) -> void:
	# 서브클래스에서 오버라이드
	pass


# ===========================================
# 이동
# ===========================================

func move_to(target: Vector2i) -> bool:
	if not pathfinder or not grid:
		return false

	if not grid.is_walkable_v(target):
		return false

	path = pathfinder.find_path(grid_position, target)

	if path.is_empty():
		return false

	target_position = target
	path_index = 1  # 시작점 건너뛰기
	_set_state(CombatMechanics.CombatState.MOVING)

	return true


func stop_movement() -> void:
	path.clear()
	path_index = 0
	velocity = Vector2.ZERO

	if combat_state == CombatMechanics.CombatState.MOVING:
		_set_state(CombatMechanics.CombatState.IDLE)


func _on_path_complete() -> void:
	path.clear()
	path_index = 0
	velocity = Vector2.ZERO
	_set_state(CombatMechanics.CombatState.IDLE)
	reached_destination.emit(self)


func _update_grid_position(new_pos: Vector2i) -> void:
	if grid:
		grid.move_entity(self, grid_position, new_pos)
	grid_position = new_pos


# ===========================================
# 전투
# ===========================================

func take_damage(amount: int, source: BaseUnit = null, damage_type: CombatMechanics.DamageType = CombatMechanics.DamageType.MELEE) -> void:
	if not is_alive:
		return

	var final_damage := _calculate_damage_taken(amount, damage_type, source)
	_apply_damage(final_damage)

	took_damage.emit(self, final_damage, source)

	if _check_death():
		_die()


func _calculate_damage_taken(base_damage: int, _damage_type: CombatMechanics.DamageType, _source: BaseUnit) -> int:
	# 서브클래스에서 오버라이드
	return base_damage


func _apply_damage(_damage: int) -> void:
	# 서브클래스에서 오버라이드
	pass


func _check_death() -> bool:
	# 서브클래스에서 오버라이드
	return false


func _die() -> void:
	is_alive = false
	combat_state = CombatMechanics.CombatState.IDLE

	# 그리드에서 제거
	if grid:
		grid.remove_entity(grid_position, self)

	died.emit(self)

	# 시각 효과 후 제거
	_play_death_effect()


func _play_death_effect() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)


func attack(target: BaseUnit) -> void:
	if attack_timer > 0 or not is_alive or not target.is_alive:
		return

	attack_timer = attack_cooldown
	_perform_attack(target)


func _perform_attack(_target: BaseUnit) -> void:
	# 서브클래스에서 오버라이드
	pass


# ===========================================
# 상태 관리
# ===========================================

func _set_state(new_state: CombatMechanics.CombatState) -> void:
	if combat_state != new_state:
		combat_state = new_state
		state_changed.emit(self, new_state)


func set_target(target: BaseUnit) -> void:
	current_target = target


func clear_target() -> void:
	current_target = null


# ===========================================
# 선택/하이라이트
# ===========================================

func select() -> void:
	if selection_indicator:
		selection_indicator.visible = true


func deselect() -> void:
	if selection_indicator:
		selection_indicator.visible = false


func highlight(color: Color = Color.WHITE) -> void:
	modulate = color


func unhighlight() -> void:
	modulate = Color.WHITE


# ===========================================
# 좌표 변환
# ===========================================

const TILE_SIZE := Vector2(32, 32)
const ISO_OFFSET := Vector2(0.5, 0.25)

func _grid_to_world(grid_pos: Vector2i) -> Vector2:
	# 아이소메트릭 좌표 변환
	var x := (grid_pos.x - grid_pos.y) * TILE_SIZE.x * ISO_OFFSET.x
	var y := (grid_pos.x + grid_pos.y) * TILE_SIZE.y * ISO_OFFSET.y
	return Vector2(x, y)


func _world_to_grid(world_pos: Vector2) -> Vector2i:
	var x := (world_pos.x / (TILE_SIZE.x * ISO_OFFSET.x) + world_pos.y / (TILE_SIZE.y * ISO_OFFSET.y)) / 2
	var y := (world_pos.y / (TILE_SIZE.y * ISO_OFFSET.y) - world_pos.x / (TILE_SIZE.x * ISO_OFFSET.x)) / 2
	return Vector2i(int(round(x)), int(round(y)))


# ===========================================
# 유틸리티
# ===========================================

func get_distance_to(other: BaseUnit) -> float:
	return position.distance_to(other.position)


func get_grid_distance_to(other: BaseUnit) -> int:
	return absi(grid_position.x - other.grid_position.x) + absi(grid_position.y - other.grid_position.y)


func is_in_range(target: BaseUnit, range_val: int) -> bool:
	return get_grid_distance_to(target) <= range_val
