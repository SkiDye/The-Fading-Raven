class_name Entity
extends Node2D

## 모든 엔티티(크루, 적)의 기본 클래스
## 체력, 상태, 이동, 데미지, 상태이상 등 공통 기능 제공


# ===== SIGNALS =====

signal health_changed(current_hp: int, max_hp: int)
signal died()
signal state_changed(new_state: int)
signal position_changed(old_pos: Vector2i, new_pos: Vector2i)
signal damage_taken(amount: int, source: Node, damage_type: int)
signal knockback_started(direction: Vector2, force: float)
signal knockback_ended()
signal stun_started(duration: float)
signal stun_ended()
signal movement_started(target: Vector2i)
signal movement_ended()


# ===== CONSTANTS =====

const KNOCKBACK_FRICTION: float = 8.0


# ===== EXPORTS =====

@export var entity_id: String
@export var team: int = 0  # 0 = player, 1 = enemy
@export var max_hp: int = 100
@export var base_move_speed: float = 2.0  # tiles per second
@export var knockback_resistance: float = 0.0  # 0.0 ~ 1.0


# ===== PUBLIC VARIABLES =====

var current_hp: int = 0
var current_state: int = Constants.EntityState.IDLE
var tile_position: Vector2i = Vector2i.ZERO
var facing_direction: Vector2 = Vector2.RIGHT


# ===== PRIVATE VARIABLES =====

# 이동
var _move_path: Array[Vector2i] = []
var _move_target: Vector2 = Vector2.ZERO
var _is_moving: bool = false

# 넉백
var _knockback_velocity: Vector2 = Vector2.ZERO
var _is_knocked_back: bool = false

# 스턴
var _stun_timer: float = 0.0
var _is_stunned: bool = false

# 슬로우
var _slow_timer: float = 0.0
var _slow_multiplier: float = 1.0

# 무적
var _invulnerable_timer: float = 0.0
var _is_invulnerable: bool = false


# ===== COMPUTED PROPERTIES =====

var is_alive: bool:
	get: return current_hp > 0 and current_state != Constants.EntityState.DEAD

var is_stunned: bool:
	get: return _is_stunned

var is_moving: bool:
	get: return _is_moving

var move_speed: float:
	get: return base_move_speed * _slow_multiplier


# ===== LIFECYCLE =====

func _ready() -> void:
	current_hp = max_hp
	add_to_group("entities")
	_update_tile_position()


func _process(delta: float) -> void:
	_process_timers(delta)
	_process_knockback(delta)
	_process_movement(delta)


func _process_timers(delta: float) -> void:
	# 스턴 타이머
	if _is_stunned:
		_stun_timer -= delta
		if _stun_timer <= 0:
			_end_stun()

	# 슬로우 타이머
	if _slow_multiplier < 1.0:
		_slow_timer -= delta
		if _slow_timer <= 0:
			_slow_multiplier = 1.0

	# 무적 타이머
	if _is_invulnerable and _invulnerable_timer > 0:
		_invulnerable_timer -= delta
		if _invulnerable_timer <= 0:
			_is_invulnerable = false


func _process_knockback(delta: float) -> void:
	if not _is_knocked_back:
		return

	# 넉백 이동 적용
	position += _knockback_velocity * delta

	# 넉백 감속
	var friction := KNOCKBACK_FRICTION * Constants.TILE_SIZE * delta
	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, friction)

	# 넉백 종료 확인
	if _knockback_velocity.length() < 5.0:
		_is_knocked_back = false
		_knockback_velocity = Vector2.ZERO
		_update_tile_position()
		knockback_ended.emit()


func _process_movement(delta: float) -> void:
	if not _is_moving or _is_stunned or _is_knocked_back:
		return

	var speed := move_speed * Constants.TILE_SIZE
	var direction := (_move_target - position).normalized()
	var distance := position.distance_to(_move_target)
	var move_distance := speed * delta

	if move_distance >= distance:
		# 목표 도달
		position = _move_target
		_update_tile_position()

		# 다음 경로 확인
		if _move_path.size() > 0:
			var next_tile: Variant = _move_path.pop_front()
			_move_target = _tile_to_world(next_tile)
		else:
			_is_moving = false
			movement_ended.emit()
			if current_state == Constants.EntityState.MOVING:
				_set_state(Constants.EntityState.IDLE)
	else:
		position += direction * move_distance
		facing_direction = direction


# ===== DAMAGE & HEALING =====

## 데미지를 받습니다.
## [param amount]: 기본 데미지량
## [param damage_type]: 데미지 타입 (Constants.DamageType)
## [param source]: 데미지 출처 노드
## [return]: 실제 적용된 데미지량
func take_damage(amount: int, damage_type: int, source: Node = null) -> int:
	if not is_alive:
		return 0

	if _is_invulnerable:
		return 0

	var actual_damage := _calculate_actual_damage(amount, damage_type, source)
	current_hp = maxi(0, current_hp - actual_damage)

	health_changed.emit(current_hp, max_hp)
	damage_taken.emit(actual_damage, source, damage_type)
	EventBus.damage_dealt.emit(source, self, actual_damage, damage_type)

	if current_hp <= 0:
		_die()

	return actual_damage


## 데미지 계산 (서브클래스에서 오버라이드)
func _calculate_actual_damage(amount: int, _type: int, _source: Node) -> int:
	return amount


## 체력을 회복합니다.
## [param amount]: 회복량
## [return]: 실제 회복된 양
func heal(amount: int) -> int:
	if not is_alive:
		return 0

	var old_hp := current_hp
	current_hp = mini(current_hp + amount, max_hp)
	var healed := current_hp - old_hp

	if healed > 0:
		health_changed.emit(current_hp, max_hp)

	return healed


# ===== MOVEMENT =====

## 타일 좌표로 이동 명령
func move_to_tile(target: Vector2i) -> void:
	if _is_stunned or not is_alive:
		return

	_move_path.clear()
	_move_target = _tile_to_world(target)
	_is_moving = true
	_set_state(Constants.EntityState.MOVING)
	movement_started.emit(target)


## 경로를 따라 이동 명령
func move_along_path(path: Array[Vector2i]) -> void:
	if path.is_empty() or _is_stunned or not is_alive:
		return

	_move_path = path.duplicate()
	var first_tile: Variant = _move_path.pop_front()
	_move_target = _tile_to_world(first_tile)
	_is_moving = true
	_set_state(Constants.EntityState.MOVING)
	movement_started.emit(first_tile)


## 월드 좌표로 직접 이동
func move_to_position(target: Vector2) -> void:
	if _is_stunned or not is_alive:
		return

	_move_path.clear()
	_move_target = target
	_is_moving = true
	_set_state(Constants.EntityState.MOVING)


## 이동 중지
func stop_movement() -> void:
	_is_moving = false
	_move_path.clear()
	_update_tile_position()

	if current_state == Constants.EntityState.MOVING:
		_set_state(Constants.EntityState.IDLE)
	movement_ended.emit()


## 월드 좌표에서 타일 좌표 업데이트
func _update_tile_position() -> void:
	var new_pos := _world_to_tile(position)
	if new_pos != tile_position:
		var old_pos := tile_position
		tile_position = new_pos
		position_changed.emit(old_pos, new_pos)


# ===== STATUS EFFECTS =====

## 넉백 적용
func apply_knockback(direction: Vector2, force: float) -> void:
	if _is_stunned or not is_alive:
		return

	var actual_force := force * (1.0 - knockback_resistance)
	if actual_force <= 0:
		return

	_knockback_velocity = direction.normalized() * actual_force * Constants.TILE_SIZE
	_is_knocked_back = true
	stop_movement()

	knockback_started.emit(direction, actual_force)
	EventBus.knockback_applied.emit(self, direction, actual_force)


## 스턴 적용
func apply_stun(duration: float) -> void:
	if not is_alive:
		return

	_is_stunned = true
	_stun_timer = maxf(_stun_timer, duration)
	stop_movement()
	_set_state(Constants.EntityState.STUNNED)

	stun_started.emit(duration)
	EventBus.stun_applied.emit(self, duration)


func _end_stun() -> void:
	_is_stunned = false
	_stun_timer = 0.0
	stun_ended.emit()

	if is_alive and current_state == Constants.EntityState.STUNNED:
		_set_state(Constants.EntityState.IDLE)


## 슬로우 적용
func apply_slow(multiplier: float, duration: float) -> void:
	_slow_multiplier = minf(_slow_multiplier, multiplier)
	_slow_timer = maxf(_slow_timer, duration)


## 무적 적용
func set_invulnerable(duration: float) -> void:
	_is_invulnerable = true
	_invulnerable_timer = maxf(_invulnerable_timer, duration)


# ===== STATE MANAGEMENT =====

func _set_state(new_state: int) -> void:
	if current_state != new_state:
		current_state = new_state
		state_changed.emit(new_state)


func set_tile_position(new_pos: Vector2i) -> void:
	var old_pos := tile_position
	tile_position = new_pos
	position = _tile_to_world(new_pos)
	position_changed.emit(old_pos, new_pos)


# ===== DEATH =====

func _die() -> void:
	_set_state(Constants.EntityState.DEAD)
	stop_movement()
	died.emit()
	EventBus.entity_died.emit(self)


# ===== COORDINATE CONVERSION =====

func _tile_to_world(tile: Vector2i) -> Vector2:
	return Vector2(
		tile.x * Constants.TILE_SIZE + Constants.TILE_SIZE_HALF,
		tile.y * Constants.TILE_SIZE + Constants.TILE_SIZE_HALF
	)


func _world_to_tile(world: Vector2) -> Vector2i:
	return Vector2i(
		int(world.x / Constants.TILE_SIZE),
		int(world.y / Constants.TILE_SIZE)
	)


# ===== UTILITY =====

## 체력 비율 (0.0 ~ 1.0)
func get_health_ratio() -> float:
	if max_hp <= 0:
		return 0.0
	return float(current_hp) / float(max_hp)


## 다른 엔티티와의 거리 (타일 단위)
func distance_to_entity(other: Node2D) -> float:
	return position.distance_to(other.position) / Constants.TILE_SIZE


## 다른 엔티티 방향
func direction_to_entity(other: Node2D) -> Vector2:
	return (other.position - position).normalized()


## 공격 범위 내 여부
func is_in_range(other: Node2D, attack_range: float) -> bool:
	return distance_to_entity(other) <= attack_range


## 디버그 문자열
func _to_string() -> String:
	return "Entity(%s, HP:%d/%d, State:%d)" % [entity_id, current_hp, max_hp, current_state]
