class_name Turret3D
extends Node3D

## 3D 터렛 엔티티
## Engineer가 배치하는 자동 공격 포탑


# ===== SIGNALS =====

signal destroyed()
signal hacked(hacker: Node3D)
signal hack_cleared()
signal target_acquired(target: Node3D)
signal attack_performed(target: Node3D, damage: int)


# ===== CONSTANTS =====

const BASE_HP: Array[int] = [50, 75, 100]
const BASE_DPS: Array[float] = [5.0, 7.5, 10.0]
const ATTACK_SPEED: float = 2.0
const ATTACK_RANGE: float = 6.0  # 월드 단위
const ROTATION_SPEED: float = 5.0
const SLOW_AMOUNT: float = 0.5
const SLOW_DURATION: float = 2.0


# ===== EXPORTS =====

@export var level: int = 0


# ===== STATE =====

var owner_squad: Node3D = null
var tile_position: Vector2i = Vector2i.ZERO
var current_hp: int = 50
var max_hp: int = 50
var is_hacked: bool = false
var is_alive: bool = true
var current_target: Node3D = null

var _attack_cooldown: float = 0.0
var _hack_progress: float = 0.0
var _hacker: Node3D = null
var _is_being_hacked: bool = false
var _has_slow: bool = false


# ===== CHILD NODES =====

@onready var model_container: Node3D = $ModelContainer
@onready var turret_head: Node3D = $ModelContainer/TurretHead
@onready var barrel: Node3D = $ModelContainer/TurretHead/Barrel
@onready var muzzle_point: Node3D = $ModelContainer/TurretHead/Barrel/MuzzlePoint
@onready var health_bar: Node3D = $HealthBar3D
@onready var hack_indicator: Node3D = $HackIndicator
@onready var range_indicator: MeshInstance3D = $RangeIndicator
@onready var attack_timer: Timer = $AttackTimer


# ===== LIFECYCLE =====

func _ready() -> void:
	add_to_group("turrets")
	add_to_group("units")
	_initialize()
	_update_visuals()

	if attack_timer:
		attack_timer.timeout.connect(_on_attack_timer_timeout)
		attack_timer.wait_time = 1.0 / ATTACK_SPEED
		attack_timer.start()


func _process(delta: float) -> void:
	if not is_alive:
		return

	_process_hacking(delta)

	if _is_being_hacked:
		return

	# 타겟 추적
	if current_target and is_instance_valid(current_target):
		_rotate_towards_target(delta)
	else:
		_find_target()


# ===== INITIALIZATION =====

func _initialize() -> void:
	level = clampi(level, 0, 2)
	max_hp = BASE_HP[level]
	current_hp = max_hp

	# Tech Savvy 특성 체크
	if _has_tech_savvy():
		max_hp = int(max_hp * 1.5)
		current_hp = max_hp

	_has_slow = (level >= 2)


func initialize(data: Dictionary) -> void:
	if data.has("level"):
		level = data.level
	if data.has("owner_squad"):
		owner_squad = data.owner_squad
	if data.has("tile_position"):
		tile_position = data.tile_position

	_initialize()
	_update_visuals()


func _has_tech_savvy() -> bool:
	if owner_squad and "trait_id" in owner_squad:
		return owner_squad.trait_id == "tech_savvy"
	return false


# ===== TARGETING =====

func _find_target() -> void:
	var target_group := "enemies" if not is_hacked else "crews"
	var targets := get_tree().get_nodes_in_group(target_group)

	var closest: Node3D = null
	var closest_dist := INF

	for target in targets:
		if not _is_valid_target(target):
			continue

		var dist := global_position.distance_to(target.global_position)

		if dist <= ATTACK_RANGE and dist < closest_dist:
			closest_dist = dist
			closest = target

	if closest != current_target:
		current_target = closest
		if current_target:
			target_acquired.emit(current_target)


func _is_valid_target(target: Node) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if target is not Node3D:
		return false
	if "is_alive" in target and not target.is_alive:
		return false
	return true


func _rotate_towards_target(delta: float) -> void:
	if current_target == null or turret_head == null:
		return

	var target_pos := current_target.global_position
	var direction := (target_pos - global_position).normalized()

	# Y축 회전만 (수평 회전)
	var target_angle := atan2(direction.x, direction.z)
	var current_angle := turret_head.rotation.y

	turret_head.rotation.y = lerp_angle(current_angle, target_angle, delta * ROTATION_SPEED)

	# 포신 상하 회전 (선택적)
	if barrel:
		var height_diff := target_pos.y - barrel.global_position.y
		var horizontal_dist := Vector2(direction.x, direction.z).length()
		var pitch := atan2(height_diff, horizontal_dist)
		barrel.rotation.x = lerp(barrel.rotation.x, -pitch, delta * ROTATION_SPEED)


# ===== COMBAT =====

func _on_attack_timer_timeout() -> void:
	if not is_alive or _is_being_hacked:
		return

	if current_target and _is_valid_target(current_target):
		_attack()
	else:
		current_target = null


func _attack() -> void:
	if current_target == null:
		return

	var damage := _calculate_damage()

	if current_target.has_method("take_damage"):
		current_target.take_damage(damage, self)

	# 레벨 3 슬로우
	if _has_slow and current_target.has_method("apply_slow"):
		current_target.apply_slow(SLOW_AMOUNT, SLOW_DURATION)

	attack_performed.emit(current_target, damage)
	_show_attack_effect()


func _calculate_damage() -> int:
	var base_damage := BASE_DPS[level] / ATTACK_SPEED

	# Tech Savvy 보너스
	if _has_tech_savvy():
		base_damage *= 1.5

	# 시설 보너스
	var facility_bonus := _get_turret_damage_bonus()
	if facility_bonus > 0:
		base_damage *= (1.0 + facility_bonus)

	return int(base_damage)


func _get_turret_damage_bonus() -> float:
	# FacilityBonusManager에서 보너스 가져오기
	var managers := get_tree().get_nodes_in_group("facility_bonus_manager")
	if not managers.is_empty():
		var manager: Node = managers[0]
		if manager.has_method("get_turret_damage_bonus"):
			return manager.get_turret_damage_bonus()
	return 0.0


func _show_attack_effect() -> void:
	if muzzle_point == null or current_target == null:
		return

	# 투사체 또는 레이저 이펙트 생성
	EventBus.projectile_fired.emit(
		muzzle_point.global_position,
		current_target.global_position,
		"turret_laser"
	)


# ===== DAMAGE =====

func take_damage(amount: int, _source: Node = null) -> int:
	if not is_alive:
		return 0

	var actual_damage := mini(amount, current_hp)
	current_hp -= actual_damage
	_update_visuals()

	if current_hp <= 0:
		_destroy()

	return actual_damage


func _destroy() -> void:
	is_alive = false
	destroyed.emit()
	EventBus.turret_destroyed.emit(self)

	# 파괴 이펙트
	EventBus.explosion_requested.emit(global_position, "small")

	# 페이드 아웃 후 제거
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)


# ===== HACKING =====

func start_hack(hacker: Node3D) -> void:
	if is_hacked or _is_being_hacked:
		return

	_hacker = hacker
	_is_being_hacked = true
	_hack_progress = 0.0

	if hack_indicator:
		hack_indicator.visible = true


func update_hack(delta: float) -> bool:
	if not _is_being_hacked:
		return false

	_hack_progress += delta / 5.0  # 5초 해킹

	if hack_indicator:
		# 프로그레스 표시 (스케일 또는 색상)
		hack_indicator.scale = Vector3.ONE * (1.0 + _hack_progress * 0.5)

	if _hack_progress >= 1.0:
		_complete_hack()
		return true

	return false


func _process_hacking(_delta: float) -> void:
	if _is_being_hacked and not _is_valid_target(_hacker):
		cancel_hack()


func cancel_hack() -> void:
	_is_being_hacked = false
	_hacker = null
	_hack_progress = 0.0

	if hack_indicator:
		hack_indicator.visible = false
		hack_indicator.scale = Vector3.ONE


func _complete_hack() -> void:
	is_hacked = true
	_is_being_hacked = false
	current_target = null

	if hack_indicator:
		hack_indicator.visible = false

	hacked.emit(_hacker)
	EventBus.turret_hacked.emit(self, _hacker)

	_hacker = null
	_update_visuals()


func clear_hack() -> void:
	is_hacked = false
	current_target = null

	hack_cleared.emit()
	EventBus.turret_hack_cleared.emit(self)

	_update_visuals()


func can_be_hacked() -> bool:
	return not is_hacked and not _is_being_hacked


func get_hack_progress() -> float:
	return _hack_progress


# ===== VISUALS =====

func _update_visuals() -> void:
	if model_container:
		if is_hacked:
			model_container.modulate = Color(1.0, 0.3, 0.3)
		else:
			model_container.modulate = Color(1.0, 0.6, 0.2)

	if health_bar and health_bar.has_method("set_value"):
		health_bar.set_value(get_health_ratio())


func get_health_ratio() -> float:
	if max_hp <= 0:
		return 0.0
	return float(current_hp) / float(max_hp)


func show_range(visible_flag: bool) -> void:
	if range_indicator:
		range_indicator.visible = visible_flag


# ===== UTILITIES =====

func get_level() -> int:
	return level


func has_slow_effect() -> bool:
	return _has_slow


func get_owner_squad() -> Node3D:
	return owner_squad
