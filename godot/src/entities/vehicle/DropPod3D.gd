class_name DropPod3D
extends Node3D

## 3D 침투정 (적 수송선)
## 적을 실어와 정거장에 상륙시킴
## 엔진 트레일 및 착륙 임팩트 이펙트 포함

# ===== SIGNALS =====

signal approaching(eta: float)
signal landed(tile_pos: Vector2i)
signal enemies_deployed(enemies: Array)
signal departed()


# ===== CONFIGURATION =====

@export var approach_speed: float = 5.0
@export var landing_duration: float = 1.0
@export var trail_spawn_interval: float = 0.1


# ===== STATE =====

enum State { APPROACHING, LANDING, DEPLOYED, DEPARTING }

var current_state: State = State.APPROACHING
var target_tile: Vector2i = Vector2i.ZERO
var target_position: Vector3 = Vector3.ZERO
var enemy_payload: Array = []

var _approach_start: Vector3 = Vector3.ZERO
var _landing_timer: float = 0.0
var _trail_timer: float = 0.0

# 엔진 노드 참조 (이펙트용)
var _engine_glow: MeshInstance3D


# ===== CHILD NODES =====

@onready var model_container: Node3D = $ModelContainer
@onready var animation_player: AnimationPlayer = $AnimationPlayer


# ===== LIFECYCLE =====

func _ready() -> void:
	add_to_group("drop_pods")
	_load_model()


func _process(delta: float) -> void:
	match current_state:
		State.APPROACHING:
			_process_approach(delta)
		State.LANDING:
			_process_landing(delta)
		State.DEPARTING:
			_process_depart(delta)


# ===== INITIALIZATION =====

func initialize(data: Dictionary) -> void:
	if data.has("target_tile"):
		target_tile = data.target_tile
		target_position = Vector3(target_tile.x + 0.5, 0, target_tile.y + 0.5)

	if data.has("enemies"):
		enemy_payload = data.enemies

	if data.has("approach_direction"):
		var dir: Vector3 = data.approach_direction
		_approach_start = target_position - dir.normalized() * 20.0
		_approach_start.y = 5.0
		global_position = _approach_start

	_load_model()


func _load_model() -> void:
	if model_container == null:
		return

	for child in model_container.get_children():
		child.queue_free()

	var model_path := "res://assets/models/vehicles/boarding_pod.glb"

	if ResourceLoader.exists(model_path):
		var model_scene: PackedScene = load(model_path)
		if model_scene:
			var model := model_scene.instantiate()
			model_container.add_child(model)
			return

	_create_procedural_model()


func _create_procedural_model() -> void:
	if model_container == null:
		return

	var pod_color := Color(0.4, 0.35, 0.3)
	var accent_color := Color(0.8, 0.3, 0.2)

	# 메인 몸체 (캡슐형)
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.4
	body_mesh.height = 1.2
	body.mesh = body_mesh
	body.position = Vector3(0, 0.6, 0)
	body.material_override = _create_material(pod_color)
	model_container.add_child(body)

	# 노즈콘 (상단)
	var nose := MeshInstance3D.new()
	var nose_mesh := CylinderMesh.new()
	nose_mesh.top_radius = 0.0
	nose_mesh.bottom_radius = 0.35
	nose_mesh.height = 0.4
	nose.mesh = nose_mesh
	nose.position = Vector3(0, 1.4, 0)
	nose.material_override = _create_material(pod_color.darkened(0.2))
	model_container.add_child(nose)

	# 착륙 다리 (4개)
	for i in range(4):
		var leg := MeshInstance3D.new()
		var leg_mesh := BoxMesh.new()
		leg_mesh.size = Vector3(0.08, 0.3, 0.08)
		leg.mesh = leg_mesh
		var angle := deg_to_rad(i * 90 + 45)
		leg.position = Vector3(
			cos(angle) * 0.35,
			0.15,
			sin(angle) * 0.35
		)
		leg.rotation_degrees = Vector3(15 if i % 2 == 0 else -15, 0, 15 if i < 2 else -15)
		leg.material_override = _create_material(Color(0.3, 0.3, 0.35))
		model_container.add_child(leg)

	# 해치 (전면)
	var hatch := MeshInstance3D.new()
	var hatch_mesh := BoxMesh.new()
	hatch_mesh.size = Vector3(0.3, 0.5, 0.05)
	hatch.mesh = hatch_mesh
	hatch.position = Vector3(0, 0.5, -0.38)
	hatch.material_override = _create_material(accent_color)
	model_container.add_child(hatch)

	# 엔진 글로우 (하단)
	_engine_glow = MeshInstance3D.new()
	_engine_glow.name = "EngineGlow"
	var engine_mesh := CylinderMesh.new()
	engine_mesh.top_radius = 0.25
	engine_mesh.bottom_radius = 0.15
	engine_mesh.height = 0.15
	_engine_glow.mesh = engine_mesh
	_engine_glow.position = Vector3(0, 0.08, 0)
	var engine_mat := _create_material(Color(0.9, 0.5, 0.2))
	engine_mat.emission_enabled = true
	engine_mat.emission = Color(0.9, 0.4, 0.1)
	engine_mat.emission_energy_multiplier = 2.0
	_engine_glow.material_override = engine_mat
	model_container.add_child(_engine_glow)


func _create_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.5
	mat.metallic = 0.3
	return mat


# ===== APPROACH =====

func start_approach() -> void:
	current_state = State.APPROACHING

	# 타겟 방향으로 회전
	var look_target := target_position
	look_target.y = global_position.y
	if global_position.distance_to(look_target) > 0.1:
		look_at(look_target)

	# 엔진 이펙트 시작
	_start_engine_effects()


func _start_engine_effects() -> void:
	if _engine_glow:
		# 엔진 글로우 펄스 애니메이션
		var tween := create_tween()
		tween.set_loops()
		tween.tween_property(_engine_glow, "scale", Vector3(1.3, 1.3, 1.3), 0.2)
		tween.tween_property(_engine_glow, "scale", Vector3(1.0, 1.0, 1.0), 0.2)


func _process_approach(delta: float) -> void:
	var direction := (target_position - global_position).normalized()
	var distance := global_position.distance_to(target_position)

	var eta := distance / approach_speed
	approaching.emit(eta)

	# 엔진 트레일 생성
	_trail_timer += delta
	if _trail_timer >= trail_spawn_interval:
		_trail_timer = 0.0
		_spawn_engine_trail()

	# 착륙 지점 도달
	if distance < 0.5:
		_start_landing()
		return

	# 이동
	global_position += direction * approach_speed * delta


func _spawn_engine_trail() -> void:
	var effects_mgr := get_node_or_null("/root/EffectsManager3D")
	if effects_mgr:
		var trail_pos := global_position + Vector3(0, -0.5, 0)
		effects_mgr.spawn_engine_trail_3d(trail_pos, Vector3.UP, 1.5)
	else:
		# 폴백: 간단한 파티클 생성
		_create_simple_trail_particle()


func _create_simple_trail_particle() -> void:
	var particle := MeshInstance3D.new()
	particle.name = "TrailParticle"

	var sphere := SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.6, 0.2, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.5, 0.1)
	mat.emission_energy_multiplier = 2.0
	sphere.material = mat

	particle.mesh = sphere
	particle.global_position = global_position + Vector3(0, -0.3, 0)

	get_parent().add_child(particle)

	# 페이드아웃 + 축소
	var tween := particle.create_tween()
	tween.tween_property(particle, "scale", Vector3.ZERO, 0.5)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.5)
	tween.tween_callback(particle.queue_free)


func _start_landing() -> void:
	current_state = State.LANDING
	_landing_timer = 0.0

	# 착륙 위치로 스냅
	global_position = target_position

	# 착륙 애니메이션
	if animation_player and animation_player.has_animation("land"):
		animation_player.play("land")

	# 착륙 이펙트
	_on_landing_start()


func _on_landing_start() -> void:
	# 먼지/연기 이펙트
	var effects_mgr := get_node_or_null("/root/EffectsManager3D")
	if effects_mgr:
		effects_mgr.spawn_explosion_3d(global_position, 0.5)


func _process_landing(delta: float) -> void:
	_landing_timer += delta

	if _landing_timer >= landing_duration:
		_on_landing_complete()
		_deploy_enemies()


func _on_landing_complete() -> void:
	# 착륙 완료 이펙트
	var effects_mgr := get_node_or_null("/root/EffectsManager3D")
	if effects_mgr:
		effects_mgr.screen_shake_3d(5.0, 0.3)
		effects_mgr.spawn_impact_effect_3d(global_position, 2.0)
	else:
		# 폴백: EventBus로 화면 흔들림 요청
		var event_bus := get_node_or_null("/root/EventBus")
		if event_bus:
			event_bus.screen_shake.emit(5.0, 0.3)

	# 엔진 글로우 끄기
	if _engine_glow:
		var mat: StandardMaterial3D = _engine_glow.material_override
		if mat:
			mat.emission_energy_multiplier = 0.5


# ===== DEPLOY =====

func _deploy_enemies() -> void:
	current_state = State.DEPLOYED
	landed.emit(target_tile)

	# 해치 열림 애니메이션 (간단한 버전)
	_animate_hatch_open()

	# 적 생성 요청
	var deployed: Array = []
	for enemy_data in enemy_payload:
		deployed.append(enemy_data)

	enemies_deployed.emit(deployed)

	# 잠시 후 퇴각
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_callback(_start_depart)


func _animate_hatch_open() -> void:
	# 해치 노드 찾기
	var hatch: MeshInstance3D = null
	for child in model_container.get_children():
		if child is MeshInstance3D and child.mesh is BoxMesh:
			var box: BoxMesh = child.mesh
			if box.size.z < 0.1:  # 얇은 해치
				hatch = child
				break

	if hatch:
		var tween := create_tween()
		tween.tween_property(hatch, "rotation_degrees:x", -90, 0.5)


# ===== DEPART =====

func _start_depart() -> void:
	current_state = State.DEPARTING
	departed.emit()

	if animation_player and animation_player.has_animation("depart"):
		animation_player.play("depart")

	# 엔진 재점화
	_restart_engine_for_depart()


func _restart_engine_for_depart() -> void:
	if _engine_glow:
		var mat: StandardMaterial3D = _engine_glow.material_override
		if mat:
			mat.emission_energy_multiplier = 3.0

		# 엔진 글로우 펄스
		var tween := create_tween()
		tween.set_loops()
		tween.tween_property(_engine_glow, "scale", Vector3(1.5, 1.5, 1.5), 0.15)
		tween.tween_property(_engine_glow, "scale", Vector3(1.0, 1.0, 1.0), 0.15)


func _process_depart(delta: float) -> void:
	# 위로 상승
	global_position.y += approach_speed * 1.5 * delta

	# 트레일 생성
	_trail_timer += delta
	if _trail_timer >= trail_spawn_interval:
		_trail_timer = 0.0
		_spawn_engine_trail()

	if global_position.y > 15.0:
		queue_free()


# ===== UTILITIES =====

func get_enemy_count() -> int:
	return enemy_payload.size()


func get_state() -> State:
	return current_state


func get_target_tile() -> Vector2i:
	return target_tile
