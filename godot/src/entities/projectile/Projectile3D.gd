class_name Projectile3D
extends Node3D

## 3D 투사체
## Ranger, Turret 등의 원거리 공격용


# ===== SIGNALS =====

signal hit_target(target: Node3D)
signal missed()
signal expired()


# ===== EXPORTS =====

@export var speed: float = 15.0
@export var damage: int = 10
@export var damage_type: Constants.DamageType = Constants.DamageType.ENERGY
@export var max_lifetime: float = 3.0
@export var homing: bool = false
@export var homing_strength: float = 5.0


# ===== STATE =====

var source: Node = null
var target: Node3D = null
var target_position: Vector3 = Vector3.ZERO
var direction: Vector3 = Vector3.FORWARD
var is_active: bool = true

var _lifetime: float = 0.0
var _trail_positions: Array[Vector3] = []
var _trail_max_length: int = 10


# ===== CHILD NODES =====

@onready var mesh: MeshInstance3D = $Mesh
@onready var trail: Node3D = $Trail
@onready var collision_area: Area3D = $Area3D
@onready var impact_particles: GPUParticles3D = $ImpactParticles


# ===== LIFECYCLE =====

func _ready() -> void:
	add_to_group("projectiles")

	if collision_area:
		collision_area.body_entered.connect(_on_body_entered)
		collision_area.area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	if not is_active:
		return

	_lifetime += delta

	if _lifetime >= max_lifetime:
		_expire()
		return

	# 이동
	_update_movement(delta)

	# 트레일 업데이트
	_update_trail()


# ===== INITIALIZATION =====

func initialize(data: Dictionary) -> void:
	if data.has("source"):
		source = data.source
	if data.has("target"):
		target = data.target
	if data.has("target_position"):
		target_position = data.target_position
	if data.has("damage"):
		damage = data.damage
	if data.has("damage_type"):
		damage_type = data.damage_type
	if data.has("speed"):
		speed = data.speed
	if data.has("homing"):
		homing = data.homing

	# 초기 방향 계산
	if target:
		direction = (target.global_position - global_position).normalized()
	elif target_position != Vector3.ZERO:
		direction = (target_position - global_position).normalized()

	# 투사체 방향으로 회전
	if direction.length() > 0.01:
		look_at(global_position + direction)


func launch(from: Vector3, to: Vector3, dmg: int = 10, src: Node = null) -> void:
	global_position = from
	target_position = to
	damage = dmg
	source = src
	direction = (to - from).normalized()

	if direction.length() > 0.01:
		look_at(global_position + direction)

	is_active = true


func launch_at_target(from: Vector3, target_node: Node3D, dmg: int = 10, src: Node = null) -> void:
	global_position = from
	target = target_node
	damage = dmg
	source = src
	homing = true

	if target:
		direction = (target.global_position - from).normalized()

	if direction.length() > 0.01:
		look_at(global_position + direction)

	is_active = true


# ===== MOVEMENT =====

func _update_movement(delta: float) -> void:
	# 호밍
	if homing and target and is_instance_valid(target):
		var to_target := (target.global_position - global_position).normalized()
		direction = direction.lerp(to_target, homing_strength * delta).normalized()

		# 타겟에 도달했는지 확인
		var dist := global_position.distance_to(target.global_position)
		if dist < 0.5:
			_hit(target)
			return

	# 이동
	global_position += direction * speed * delta

	# 방향으로 회전
	if direction.length() > 0.01:
		look_at(global_position + direction)

	# 비호밍: 목표 지점 도달 확인
	if not homing and target_position != Vector3.ZERO:
		var dist := global_position.distance_to(target_position)
		if dist < 0.3:
			_hit_position(target_position)


# ===== TRAIL =====

func _update_trail() -> void:
	_trail_positions.push_front(global_position)

	if _trail_positions.size() > _trail_max_length:
		_trail_positions.pop_back()

	# 트레일 렌더링 (간단한 라인 또는 파티클)
	if trail and trail.has_method("update_trail"):
		trail.update_trail(_trail_positions)


# ===== COLLISION =====

func _on_body_entered(body: Node3D) -> void:
	if not is_active:
		return

	# 소스 제외
	if body == source:
		return

	# 유효한 타겟인지 확인
	if _is_valid_hit_target(body):
		_hit(body)


func _on_area_entered(area: Area3D) -> void:
	if not is_active:
		return

	var parent := area.get_parent()
	if parent == source:
		return

	if _is_valid_hit_target(parent):
		_hit(parent)


func _is_valid_hit_target(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false

	# 적 또는 아군 확인 (소스와 반대 팀)
	if "team" in node and "team" in source:
		return node.team != source.team

	# 그룹으로 확인
	if source and source.is_in_group("crews"):
		return node.is_in_group("enemies")
	if source and source.is_in_group("enemies"):
		return node.is_in_group("crews") or node.is_in_group("facilities")

	return true


# ===== HIT =====

func _hit(hit_target: Node) -> void:
	if not is_active:
		return

	is_active = false

	# 데미지 적용
	if hit_target.has_method("take_damage"):
		hit_target.take_damage(damage, source)

	hit_target.emit(hit_target)

	# 이펙트
	_spawn_hit_effect()

	# 제거
	_destroy()


func _hit_position(pos: Vector3) -> void:
	if not is_active:
		return

	is_active = false
	global_position = pos

	# 범위 검사 (폭발 등)
	var nearby := _get_nearby_targets(1.0)
	for t in nearby:
		if t.has_method("take_damage"):
			t.take_damage(damage, source)

	if nearby.is_empty():
		missed.emit()

	_spawn_hit_effect()
	_destroy()


func _get_nearby_targets(radius: float) -> Array:
	var results: Array = []
	var space := get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = radius

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, global_position)

	var hits := space.intersect_shape(query)
	for hit in hits:
		var collider = hit.get("collider")
		if collider and _is_valid_hit_target(collider):
			results.append(collider)

	return results


func _expire() -> void:
	is_active = false
	expired.emit()
	_destroy()


# ===== EFFECTS =====

func _spawn_hit_effect() -> void:
	# 충돌 이펙트 생성
	EventBus.hit_effect_requested.emit(global_position)

	if impact_particles:
		impact_particles.emitting = true


func _destroy() -> void:
	# 파티클이 끝날 때까지 대기
	if impact_particles and impact_particles.emitting:
		if mesh:
			mesh.visible = false
		await get_tree().create_timer(0.5).timeout

	queue_free()
