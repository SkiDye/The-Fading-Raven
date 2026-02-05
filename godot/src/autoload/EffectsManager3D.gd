extends Node

## 3D 전역 이펙트 매니저
## 3D 공간에서의 전투 이펙트, 카메라 쉐이크, 오브젝트 풀링 관리

# Preload to avoid autoload resolution issues
const ConstantsScript = preload("res://src/autoload/Constants.gd")

# Local damage type constants (fallback)
enum DamageType { PHYSICAL = 0, ENERGY = 1, EXPLOSIVE = 2, TRUE = 3 }

# ===== SCENE REFERENCES =====

var _hit_effect_scene: PackedScene
var _explosion_scene: PackedScene
var _floating_text_scene: PackedScene


# ===== CONTAINERS =====

var _effects_container: Node3D


# ===== OBJECT POOL =====

var _hit_effect_pool: Array[Node3D] = []
var _explosion_pool: Array[Node3D] = []
const POOL_SIZE: int = 20


# ===== CAMERA SHAKE =====

var _shake_intensity: float = 0.0
var _shake_duration: float = 0.0
var _shake_timer: float = 0.0
var _original_camera_position: Vector3 = Vector3.ZERO
var _active_camera: Camera3D = null


# ===== LIFECYCLE =====

func _ready() -> void:
	_load_scenes()
	_connect_signals()


func _load_scenes() -> void:
	var paths := {
		"hit_effect": "res://src/effects/HitEffect3D.tscn",
		"explosion": "res://src/effects/Explosion3D.tscn",
		"floating_text": "res://src/effects/FloatingText3D.tscn"
	}

	if ResourceLoader.exists(paths["hit_effect"]):
		_hit_effect_scene = load(paths["hit_effect"])

	if ResourceLoader.exists(paths["explosion"]):
		_explosion_scene = load(paths["explosion"])

	if ResourceLoader.exists(paths["floating_text"]):
		_floating_text_scene = load(paths["floating_text"])


func _connect_signals() -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus:
		event_bus.damage_dealt.connect(_on_damage_dealt)
		event_bus.entity_died.connect(_on_entity_died)
		event_bus.skill_used.connect(_on_skill_used)
		event_bus.screen_shake.connect(_on_screen_shake)


func _process(delta: float) -> void:
	if _shake_timer > 0:
		_shake_timer -= delta
		_apply_camera_shake()
	elif _shake_intensity > 0:
		_shake_intensity = 0
		_reset_camera()


# ===== PUBLIC API =====

## 이펙트 컨테이너 설정 (씬 전환 시 호출)
func set_effects_container(container: Node3D) -> void:
	_effects_container = container


## 3D 히트 이펙트 스폰
func spawn_hit_effect_3d(position: Vector3, damage_type: int = 0) -> void:
	if _effects_container == null:
		return

	var effect: Node3D

	if _hit_effect_scene:
		effect = _get_pooled_effect(_hit_effect_pool, _hit_effect_scene)
		if effect.has_method("setup"):
			effect.setup(damage_type)
	else:
		effect = _create_simple_hit_effect(damage_type)

	effect.global_position = position

	if effect.get_parent() == null:
		_effects_container.add_child(effect)


## 3D 폭발 이펙트 스폰
func spawn_explosion_3d(position: Vector3, radius: float = 1.0) -> void:
	if _effects_container == null:
		return

	var effect: Node3D

	if _explosion_scene:
		effect = _get_pooled_effect(_explosion_pool, _explosion_scene)
		if effect.has_method("setup"):
			effect.setup(radius)
	else:
		effect = _create_simple_explosion(radius)

	effect.global_position = position

	if effect.get_parent() == null:
		_effects_container.add_child(effect)


## 3D 플로팅 텍스트 스폰
func spawn_floating_text_3d(text: String, position: Vector3, color: Color = Color.WHITE, scale: float = 1.0) -> void:
	if _effects_container == null:
		return

	var effect: Node3D

	if _floating_text_scene:
		effect = _floating_text_scene.instantiate()
		if effect.has_method("setup"):
			effect.setup(text, color, scale)
	else:
		effect = _create_simple_floating_text(text, color)

	effect.global_position = position
	_effects_container.add_child(effect)


## 3D 데미지 숫자 표시
func spawn_damage_number_3d(position: Vector3, amount: int, is_critical: bool = false) -> void:
	var color := Color.RED if amount > 0 else Color.GREEN
	var scale := 1.5 if is_critical else 1.0
	var text := str(abs(amount))
	if amount < 0:
		text = "+" + text

	var offset := Vector3(randf_range(-0.2, 0.2), randf_range(0, 0.2), randf_range(-0.2, 0.2))
	spawn_floating_text_3d(text, position + offset, color, scale)


## 3D 카메라 쉐이크
func screen_shake_3d(intensity: float = 3.0, duration: float = 0.3) -> void:
	_shake_intensity = intensity
	_shake_duration = duration
	_shake_timer = duration

	_active_camera = get_viewport().get_camera_3d()
	if _active_camera:
		_original_camera_position = _active_camera.position


## 착륙 임팩트 이펙트
func spawn_impact_effect_3d(position: Vector3, radius: float = 2.0) -> void:
	spawn_explosion_3d(position, radius)
	screen_shake_3d(5.0, 0.3)

	# 충격파 링 이펙트
	_spawn_shockwave_ring(position, radius)


## 엔진 트레일 이펙트
func spawn_engine_trail_3d(position: Vector3, direction: Vector3, length: float = 2.0) -> void:
	if _effects_container == null:
		return

	var trail := _create_engine_trail(direction, length)
	trail.global_position = position
	_effects_container.add_child(trail)


## 스킬 이펙트 스폰
func spawn_skill_effect_3d(skill_id: String, position: Vector3, direction: Vector3 = Vector3.FORWARD) -> void:
	match skill_id:
		"shield_bash":
			_spawn_shield_bash_effect(position, direction)
		"lance_charge":
			_spawn_lance_charge_effect(position, direction)
		"volley_fire":
			_spawn_volley_fire_effect(position)
		"deploy_turret":
			_spawn_deploy_turret_effect(position)
		"blink":
			_spawn_blink_effect(position)


## 사망 이펙트 스폰
func spawn_death_effect_3d(position: Vector3, entity_type: String) -> void:
	spawn_explosion_3d(position, 0.8)

	var color := Color.CYAN if entity_type == "enemy" else Color.RED
	spawn_floating_text_3d("X", position + Vector3(0, 0.5, 0), color, 1.5)


# ===== EVENT HANDLERS =====

func _on_damage_dealt(_source: Node, target: Node, amount: int, damage_type: int) -> void:
	if not is_instance_valid(target):
		return

	if not target is Node3D:
		return

	var target_3d: Node3D = target as Node3D
	var pos: Vector3 = target_3d.global_position

	spawn_damage_number_3d(pos + Vector3(0, 1, 0), amount)
	spawn_hit_effect_3d(pos + Vector3(0, 0.5, 0), damage_type)


func _on_entity_died(entity: Node) -> void:
	if not is_instance_valid(entity):
		return

	if not entity is Node3D:
		return

	var entity_3d: Node3D = entity as Node3D
	var entity_type: String = "unknown"
	if entity_3d.is_in_group("crews"):
		entity_type = "crew"
	elif entity_3d.is_in_group("enemies"):
		entity_type = "enemy"

	spawn_death_effect_3d(entity_3d.global_position, entity_type)


func _on_skill_used(caster: Node, skill_id: String, _target: Variant, _level: int) -> void:
	if not is_instance_valid(caster):
		return

	if not caster is Node3D:
		return

	var caster_3d: Node3D = caster as Node3D
	var direction: Vector3 = -caster_3d.global_transform.basis.z
	spawn_skill_effect_3d(skill_id, caster_3d.global_position, direction)


func _on_screen_shake(intensity: float, duration: float) -> void:
	screen_shake_3d(intensity * 0.5, duration)  # 2D 강도를 3D에 맞게 조절


# ===== CAMERA SHAKE IMPLEMENTATION =====

func _apply_camera_shake() -> void:
	if _active_camera == null:
		return

	var progress := _shake_timer / _shake_duration
	var current_intensity := _shake_intensity * progress

	var offset := Vector3(
		randf_range(-current_intensity, current_intensity) * 0.1,
		randf_range(-current_intensity, current_intensity) * 0.1,
		randf_range(-current_intensity, current_intensity) * 0.05
	)

	_active_camera.position = _original_camera_position + offset


func _reset_camera() -> void:
	if _active_camera:
		_active_camera.position = _original_camera_position


# ===== OBJECT POOLING =====

func _get_pooled_effect(pool: Array[Node3D], scene: PackedScene) -> Node3D:
	for effect in pool:
		if is_instance_valid(effect) and not effect.visible:
			effect.visible = true
			return effect

	# 풀에 없으면 새로 생성
	var new_effect: Node3D = scene.instantiate()
	if pool.size() < POOL_SIZE:
		pool.append(new_effect)
	return new_effect


func _return_to_pool(effect: Node3D) -> void:
	if is_instance_valid(effect):
		effect.visible = false


# ===== SIMPLE EFFECT CREATION (FALLBACK) =====

func _create_simple_hit_effect(damage_type: int) -> Node3D:
	var effect := Node3D.new()
	effect.name = "HitEffect"

	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3

	var mat := StandardMaterial3D.new()
	match damage_type:
		DamageType.PHYSICAL:
			mat.albedo_color = Color(1.0, 0.8, 0.2)
		DamageType.ENERGY:
			mat.albedo_color = Color(0.3, 0.8, 1.0)
		DamageType.EXPLOSIVE:
			mat.albedo_color = Color(1.0, 0.4, 0.1)
		_:
			mat.albedo_color = Color.WHITE

	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 2.0
	sphere.material = mat

	mesh.mesh = sphere
	effect.add_child(mesh)

	# 페이드아웃 애니메이션
	var tween := effect.create_tween()
	tween.tween_property(mesh, "scale", Vector3.ZERO, 0.3)
	tween.tween_callback(effect.queue_free)

	return effect


func _create_simple_explosion(radius: float) -> Node3D:
	var effect := Node3D.new()
	effect.name = "Explosion"

	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius * 0.3
	sphere.height = radius * 0.6

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.5, 0.1, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.4, 0.0)
	mat.emission_energy_multiplier = 3.0
	sphere.material = mat

	mesh.mesh = sphere
	effect.add_child(mesh)

	# 확장 + 페이드아웃
	var tween := effect.create_tween()
	tween.tween_property(mesh, "scale", Vector3(radius, radius, radius), 0.2)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tween.tween_callback(effect.queue_free)

	return effect


func _create_simple_floating_text(text: String, color: Color) -> Node3D:
	var effect := Node3D.new()
	effect.name = "FloatingText"

	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	effect.add_child(label)

	# 위로 떠오르며 페이드아웃
	var tween := effect.create_tween()
	tween.tween_property(effect, "position:y", effect.position.y + 1.0, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(effect.queue_free)

	return effect


func _spawn_shockwave_ring(position: Vector3, radius: float) -> void:
	if _effects_container == null:
		return

	var ring := Node3D.new()
	ring.name = "Shockwave"
	ring.position = position

	var mesh := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.1
	torus.outer_radius = 0.3

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.8, 0.4, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.6, 0.2)
	mat.emission_energy_multiplier = 1.5
	torus.material = mat

	mesh.mesh = torus
	mesh.rotation_degrees.x = 90
	ring.add_child(mesh)

	_effects_container.add_child(ring)

	# 확장 + 페이드아웃
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector3(radius * 2, radius * 2, radius * 2), 0.4)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tween.tween_callback(ring.queue_free)


func _create_engine_trail(direction: Vector3, length: float) -> Node3D:
	var trail := Node3D.new()
	trail.name = "EngineTrail"

	# 여러 파티클 생성
	for i in range(5):
		var particle := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.1 + randf() * 0.1
		sphere.height = sphere.radius * 2

		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.6 + randf() * 0.3, 0.2, 0.8)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.5, 0.1)
		mat.emission_energy_multiplier = 2.0
		sphere.material = mat

		particle.mesh = sphere
		particle.position = direction.normalized() * (i * length / 5.0)
		trail.add_child(particle)

		# 개별 페이드아웃
		var tween := particle.create_tween()
		tween.tween_interval(i * 0.05)
		tween.tween_property(mat, "albedo_color:a", 0.0, 0.3 + randf() * 0.2)

	# 전체 트레일 제거
	var cleanup_tween := trail.create_tween()
	cleanup_tween.tween_interval(1.0)
	cleanup_tween.tween_callback(trail.queue_free)

	return trail


# ===== SKILL EFFECTS =====

func _spawn_shield_bash_effect(position: Vector3, direction: Vector3) -> void:
	spawn_floating_text_3d("BASH!", position + Vector3(0, 1, 0), Color.LIGHT_BLUE, 1.2)
	screen_shake_3d(5.0, 0.2)

	# 충격파
	_spawn_shockwave_ring(position + direction * 0.5, 1.5)


func _spawn_lance_charge_effect(position: Vector3, direction: Vector3) -> void:
	spawn_floating_text_3d("CHARGE!", position + Vector3(0, 1, 0), Color.GOLD, 1.2)
	screen_shake_3d(8.0, 0.3)

	# 돌진 트레일
	spawn_engine_trail_3d(position, -direction, 3.0)


func _spawn_volley_fire_effect(position: Vector3) -> void:
	spawn_floating_text_3d("VOLLEY!", position + Vector3(0, 1.2, 0), Color.ORANGE, 1.0)

	# 다중 히트 이펙트
	for i in range(5):
		var offset := Vector3(randf_range(-1, 1), 0.5, randf_range(-1, 1))
		var delayed_pos := position + offset
		get_tree().create_timer(i * 0.1).timeout.connect(
			func(): spawn_hit_effect_3d(delayed_pos, DamageType.ENERGY)
		)


func _spawn_deploy_turret_effect(position: Vector3) -> void:
	spawn_floating_text_3d("DEPLOY!", position + Vector3(0, 1, 0), Color.ORANGE, 1.0)
	screen_shake_3d(3.0, 0.15)
	spawn_explosion_3d(position, 0.5)


func _spawn_blink_effect(position: Vector3) -> void:
	spawn_floating_text_3d("BLINK", position + Vector3(0, 1, 0), Color.PURPLE, 0.8)
	spawn_hit_effect_3d(position, DamageType.ENERGY)
