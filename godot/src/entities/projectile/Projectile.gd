class_name Projectile
extends Node2D

## 투사체 엔티티
## 단일 타겟, AOE, 호밍 기능 지원

signal hit(target: Node)
signal missed()
signal expired()

enum ProjectileType { BULLET, LASER, GRENADE, ORBITAL }

@export var projectile_type: ProjectileType = ProjectileType.BULLET
@export var speed: float = 500.0
@export var damage: int = 5
@export var damage_type: Constants.DamageType = Constants.DamageType.ENERGY
@export var aoe_radius: float = 0.0  # 0 = 단일 타겟
@export var lifetime: float = 5.0
@export var homing: bool = false
@export var homing_strength: float = 5.0

var source: Node
var target: Node
var target_position: Vector2
var direction: Vector2
var time_alive: float = 0.0

@onready var sprite: Sprite2D = $Sprite
@onready var trail: GPUParticles2D = $Trail


func _ready() -> void:
	add_to_group("projectiles")
	_setup_visual()


func _setup_visual() -> void:
	if sprite == null:
		return

	match projectile_type:
		ProjectileType.BULLET:
			sprite.modulate = Color.YELLOW
		ProjectileType.LASER:
			sprite.modulate = Color.RED
		ProjectileType.GRENADE:
			sprite.modulate = Color.ORANGE
		ProjectileType.ORBITAL:
			sprite.modulate = Color.CYAN
			speed = 1000.0


## 투사체 초기화
## [param src]: 발사 소스 노드
## [param tgt]: 타겟 (Node, Vector2, 또는 Vector2i)
## [param dmg]: 데미지량
## [param dmg_type]: 데미지 타입
func initialize(src: Node, tgt: Variant, dmg: int, dmg_type: Constants.DamageType) -> void:
	source = src
	damage = dmg
	damage_type = dmg_type

	if tgt is Node:
		target = tgt
		target_position = tgt.global_position
	elif tgt is Vector2:
		target_position = tgt
	elif tgt is Vector2i:
		target_position = Vector2(
			tgt.x * Constants.TILE_SIZE + Constants.TILE_SIZE_HALF,
			tgt.y * Constants.TILE_SIZE + Constants.TILE_SIZE_HALF
		)

	direction = (target_position - global_position).normalized()
	rotation = direction.angle()


func _process(delta: float) -> void:
	time_alive += delta

	if time_alive >= lifetime:
		_expire()
		return

	# 호밍 처리
	if homing and is_instance_valid(target) and _is_target_alive():
		var desired_dir: Vector2 = (target.global_position - global_position).normalized()
		direction = direction.lerp(desired_dir, homing_strength * delta)
		rotation = direction.angle()

	# 이동
	global_position += direction * speed * delta

	# 충돌 체크
	_check_collision()


func _check_collision() -> void:
	if aoe_radius > 0:
		# AOE 투사체 - 목표 지점 도달 체크
		if global_position.distance_to(target_position) < 10:
			_explode()
			return
	else:
		# 단일 타겟 투사체
		if target and _is_target_alive():
			if global_position.distance_to(target.global_position) < 20:
				_hit_target(target)


func _hit_target(tgt: Node) -> void:
	if tgt.has_method("take_damage"):
		tgt.take_damage(damage, damage_type, source)

	hit.emit(tgt)

	# 히트 이펙트
	if EffectsManager:
		EffectsManager.spawn_hit_effect(global_position, damage_type)

	queue_free()


func _explode() -> void:
	# AOE 데미지
	var targets := _get_targets_in_radius(aoe_radius)

	for tgt in targets:
		var dist := global_position.distance_to(tgt.global_position)
		var falloff := 1.0 - (dist / aoe_radius) * 0.5  # 거리에 따른 감소
		var actual_damage := int(damage * falloff)

		if tgt.has_method("take_damage"):
			tgt.take_damage(actual_damage, damage_type, source)

	hit.emit(null)

	# 폭발 이펙트
	if EffectsManager:
		EffectsManager.spawn_explosion(global_position, aoe_radius)

	queue_free()


func _get_targets_in_radius(radius: float) -> Array:
	var result: Array = []
	var all_entities := get_tree().get_nodes_in_group("crews") + get_tree().get_nodes_in_group("enemies")

	for entity in all_entities:
		if entity == source:
			continue
		if global_position.distance_to(entity.global_position) <= radius:
			result.append(entity)

	return result


func _expire() -> void:
	expired.emit()
	missed.emit()
	queue_free()


func _is_target_alive() -> bool:
	if target == null:
		return false
	if target.has_method("is_alive"):
		return target.is_alive()
	return target.is_inside_tree()
