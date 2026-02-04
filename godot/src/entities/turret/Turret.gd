class_name Turret
extends Node2D

## 엔지니어가 배치하는 자동 포탑
## 자동 타겟팅, 해킹 메카닉 지원


# ===== SIGNALS =====

signal destroyed()
signal hacked(hacker: Node)
signal hack_cleared()
signal target_acquired(target: Node)
signal attack_performed(target: Node, damage: int)


# ===== CONSTANTS =====

const BASE_HP: Array[int] = [50, 75, 100]
const BASE_DPS: Array[float] = [5.0, 7.5, 10.0]
const ATTACK_SPEED: float = 2.0
const ATTACK_RANGE: float = 4.0  # 타일 단위
const SLOW_AMOUNT: float = 0.5  # 레벨 3 슬로우
const SLOW_DURATION: float = 2.0


# ===== EXPORTS =====

@export var level: int = 0


# ===== PUBLIC VARIABLES =====

var owner_squad: Node  # CrewSquad 참조
var tile_position: Vector2i
var current_hp: int
var max_hp: int
var is_hacked: bool = false
var current_target: Node


# ===== PRIVATE VARIABLES =====

var _attack_cooldown: float = 0.0
var _hack_progress: float = 0.0
var _hacker: Node = null
var _is_being_hacked: bool = false
var _has_slow: bool = false  # 레벨 3


# ===== ONREADY =====

@onready var sprite: Sprite2D = $Sprite
@onready var health_bar: ProgressBar = $HealthBar
@onready var range_indicator: ColorRect = $RangeIndicator
@onready var hack_progress_bar: ProgressBar = $HackProgressBar


# ===== LIFECYCLE =====

func _ready() -> void:
	add_to_group("turrets")
	_initialize()
	_update_visuals()


func _process(delta: float) -> void:
	_process_hacking(delta)

	if _is_being_hacked:
		return  # 해킹 중에는 공격 불가

	_attack_cooldown -= delta

	if current_target == null or not _is_valid_target(current_target):
		_find_target()

	if current_target and _attack_cooldown <= 0:
		_attack()


# ===== INITIALIZATION =====

func _initialize() -> void:
	level = clampi(level, 0, 2)
	max_hp = BASE_HP[level]
	current_hp = max_hp

	# Tech Savvy 특성 (+50% HP)
	if _has_tech_savvy():
		max_hp = int(max_hp * 1.5)
		current_hp = max_hp

	# 레벨 3 슬로우
	_has_slow = (level >= 2)


func _has_tech_savvy() -> bool:
	if owner_squad and "trait_id" in owner_squad:
		return owner_squad.trait_id == "tech_savvy"
	return false


# ===== TARGETING =====

func _find_target() -> void:
	var target_group = "enemies" if not is_hacked else "crews"
	var targets = get_tree().get_nodes_in_group(target_group)

	var closest: Node = null
	var closest_dist = INF

	for target in targets:
		if not _is_valid_target(target):
			continue

		var dist = global_position.distance_to(target.global_position)
		var range_pixels = ATTACK_RANGE * Constants.TILE_SIZE

		if dist <= range_pixels and dist < closest_dist:
			closest_dist = dist
			closest = target

	if closest != current_target:
		current_target = closest
		if current_target:
			target_acquired.emit(current_target)


func _is_valid_target(target: Node) -> bool:
	if target == null:
		return false
	if not is_instance_valid(target):
		return false
	if "is_alive" in target and not target.is_alive:
		return false
	return true


# ===== COMBAT =====

func _attack() -> void:
	if current_target == null:
		return

	_attack_cooldown = 1.0 / ATTACK_SPEED

	var damage = _calculate_damage()

	if current_target.has_method("take_damage"):
		current_target.take_damage(damage, Constants.DamageType.ENERGY, self)

	# 레벨 3 슬로우 적용
	if _has_slow and current_target.has_method("apply_slow"):
		current_target.apply_slow(SLOW_AMOUNT, SLOW_DURATION)

	attack_performed.emit(current_target, damage)

	# 시각 효과 (공격 라인)
	_show_attack_effect()


func _calculate_damage() -> int:
	var base_damage = BASE_DPS[level] / ATTACK_SPEED

	# Tech Savvy 특성 (+50% 데미지)
	if _has_tech_savvy():
		base_damage *= 1.5

	return int(base_damage)


func _show_attack_effect() -> void:
	# TODO: 공격 이펙트 (레이저 라인 등)
	pass


# ===== DAMAGE =====

## 데미지를 받습니다.
func take_damage(amount: int, _damage_type: Constants.DamageType = Constants.DamageType.PHYSICAL, _source: Node = null) -> int:
	var actual_damage = mini(amount, current_hp)
	current_hp = max(0, current_hp - actual_damage)
	_update_visuals()

	if current_hp <= 0:
		_destroy()

	return actual_damage


func _destroy() -> void:
	destroyed.emit()
	EventBus.turret_destroyed.emit(self)
	queue_free()


# ===== HACKING =====

## 해킹을 시작합니다.
## [param hacker]: 해킹하는 적 (Hacker)
func start_hack(hacker: Node) -> void:
	if is_hacked or _is_being_hacked:
		return

	_hacker = hacker
	_is_being_hacked = true
	_hack_progress = 0.0

	if hack_progress_bar:
		hack_progress_bar.visible = true
		hack_progress_bar.value = 0


## 해킹 진행을 업데이트합니다.
## [param delta]: 경과 시간
## [return]: 해킹 완료 여부
func update_hack(delta: float) -> bool:
	if not _is_being_hacked:
		return false

	# 5초간 해킹
	_hack_progress += delta / 5.0

	if hack_progress_bar:
		hack_progress_bar.value = _hack_progress * 100.0

	if _hack_progress >= 1.0:
		_complete_hack()
		return true

	return false


func _process_hacking(_delta: float) -> void:
	# 해커가 사라지면 해킹 취소
	if _is_being_hacked and not _is_valid_target(_hacker):
		cancel_hack()


## 해킹을 취소합니다.
func cancel_hack() -> void:
	_is_being_hacked = false
	_hacker = null
	_hack_progress = 0.0

	if hack_progress_bar:
		hack_progress_bar.visible = false


func _complete_hack() -> void:
	is_hacked = true
	_is_being_hacked = false
	current_target = null  # 타겟 재설정

	if hack_progress_bar:
		hack_progress_bar.visible = false

	hacked.emit(_hacker)
	EventBus.turret_hacked.emit(self, _hacker)

	_hacker = null


## 해킹을 해제합니다.
func clear_hack() -> void:
	is_hacked = false
	current_target = null

	hack_cleared.emit()
	EventBus.turret_hack_cleared.emit(self)

	_update_visuals()


## 해킹 가능 여부를 반환합니다.
func can_be_hacked() -> bool:
	return not is_hacked and not _is_being_hacked


## 해킹 진행도를 반환합니다. (0.0 ~ 1.0)
func get_hack_progress() -> float:
	return _hack_progress


# ===== VISUALS =====

func _update_visuals() -> void:
	if health_bar:
		health_bar.value = get_health_ratio() * 100.0

	if sprite:
		if is_hacked:
			sprite.modulate = Color(1.0, 0.3, 0.3)  # 해킹됨: 빨간색
		else:
			sprite.modulate = Color(1.0, 0.5, 0.0)  # 정상: 주황색


## 체력 비율을 반환합니다.
func get_health_ratio() -> float:
	if max_hp <= 0:
		return 0.0
	return float(current_hp) / float(max_hp)


## 범위 표시를 토글합니다.
func show_range(visible_flag: bool) -> void:
	if range_indicator:
		range_indicator.visible = visible_flag


# ===== UTILITY =====

## 레벨을 반환합니다.
func get_level() -> int:
	return level


## 슬로우 적용 여부를 반환합니다.
func has_slow_effect() -> bool:
	return _has_slow


## 소유 스쿼드를 반환합니다.
func get_owner_squad() -> Node:
	return owner_squad
