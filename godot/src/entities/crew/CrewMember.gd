class_name CrewMember
extends Node2D

## 개별 크루원 유닛
## CrewSquad의 구성원으로 개별 공격 및 체력 관리


# ===== SIGNALS =====

signal died()
signal revived()
signal attack_performed(target: Node)


# ===== EXPORTS =====

@export var is_leader: bool = false


# ===== PUBLIC VARIABLES =====

var squad: Node  # CrewSquad 참조 (순환 참조 방지)
var class_id: String
var current_hp: int
var max_hp: int
var is_alive: bool = true
var current_target: Node


# ===== PRIVATE VARIABLES =====

var _attack_cooldown: float = 0.0
var _base_damage: int = 3
var _attack_speed: float = 1.0
var _color: Color = Color.WHITE


# ===== ONREADY =====

@onready var sprite: Sprite2D = $Sprite
@onready var health_bar: ProgressBar = $HealthBar


# ===== LIFECYCLE =====

func _ready() -> void:
	_update_visuals()


func _process(delta: float) -> void:
	if not is_alive:
		return

	_process_attack(delta)


# ===== INITIALIZATION =====

## 크루원을 초기화합니다.
## [param p_class_id]: 클래스 ID
## [param p_base_hp]: 기본 체력
## [param p_base_damage]: 기본 공격력
## [param p_attack_speed]: 공격 속도
## [param p_color]: 클래스 색상
func initialize(p_class_id: String, p_base_hp: int, p_base_damage: int, p_attack_speed: float, p_color: Color) -> void:
	class_id = p_class_id
	max_hp = p_base_hp
	current_hp = max_hp
	_base_damage = p_base_damage
	_attack_speed = p_attack_speed
	_color = p_color
	_update_visuals()


## 리더 보너스를 적용합니다 (Titan Frame 특성 등).
func apply_leader_bonus(hp_multiplier: float) -> void:
	if is_leader:
		max_hp = int(max_hp * hp_multiplier)
		current_hp = max_hp
		_update_visuals()


# ===== TARGETING =====

## 타겟을 설정합니다.
func set_target(target: Node) -> void:
	current_target = target


## 타겟을 해제합니다.
func clear_target() -> void:
	current_target = null


# ===== COMBAT =====

func _process_attack(delta: float) -> void:
	_attack_cooldown -= delta

	if _attack_cooldown <= 0 and _has_valid_target():
		_perform_attack()


func _has_valid_target() -> bool:
	if current_target == null:
		return false
	if not is_instance_valid(current_target):
		current_target = null
		return false
	if current_target.has_method("is_alive") or "is_alive" in current_target:
		return current_target.is_alive
	return true


func _perform_attack() -> void:
	if current_target == null:
		return

	_attack_cooldown = 1.0 / _get_effective_attack_speed()

	var damage = _calculate_attack_damage()

	if current_target.has_method("take_damage"):
		current_target.take_damage(damage, Constants.DamageType.PHYSICAL, self)

	attack_performed.emit(current_target)


func _get_effective_attack_speed() -> float:
	# 스쿼드에서 스탯 가져오기
	if squad and squad.has_method("get_effective_attack_speed"):
		return squad.get_effective_attack_speed()
	return _attack_speed


func _calculate_attack_damage() -> int:
	var damage = _base_damage

	# 스쿼드에서 데미지 가져오기
	if squad and squad.has_method("get_effective_damage"):
		damage = squad.get_effective_damage()

	# 바이오닉 암살 보너스 (타겟이 전투 중이 아닐 때)
	if class_id == "bionic" and current_target:
		var target_state = Constants.EntityState.IDLE
		if "current_state" in current_target:
			target_state = current_target.current_state
		if target_state != Constants.EntityState.ATTACKING:
			damage = int(damage * Constants.BALANCE.assassination_multiplier)

	return damage


# ===== DAMAGE =====

## 데미지를 받습니다.
## [param amount]: 데미지량
## [return]: 실제 받은 데미지
func take_damage(amount: int) -> int:
	if not is_alive:
		return 0

	var actual_damage = min(amount, current_hp)
	current_hp = max(0, current_hp - actual_damage)
	_update_visuals()

	if current_hp <= 0:
		_die()

	return actual_damage


func _die() -> void:
	is_alive = false
	visible = false
	died.emit()


# ===== RECOVERY =====

## 크루원을 부활시킵니다.
func revive() -> void:
	is_alive = true
	current_hp = max_hp
	visible = true
	_update_visuals()
	revived.emit()


## 체력을 회복합니다.
func heal(amount: int) -> int:
	if not is_alive:
		return 0

	var actual_heal = min(amount, max_hp - current_hp)
	current_hp += actual_heal
	_update_visuals()
	return actual_heal


# ===== VISUALS =====

func _update_visuals() -> void:
	if health_bar:
		health_bar.value = get_health_ratio() * 100.0
		health_bar.visible = is_alive

	if sprite:
		sprite.modulate = _color
		if is_leader:
			# 리더는 약간 밝게 표시
			sprite.modulate = _color.lightened(0.2)


## 체력 비율을 반환합니다.
func get_health_ratio() -> float:
	if max_hp <= 0:
		return 0.0
	return float(current_hp) / float(max_hp)


# ===== UTILITY =====

## 월드 위치로 이동합니다 (보간).
func move_towards_position(target_pos: Vector2, lerp_weight: float = 0.1) -> void:
	global_position = global_position.lerp(target_pos, lerp_weight)
