class_name SpawnController3D
extends Node

## 드롭팟 스폰 컨트롤러
## 적 그룹을 드롭팟을 통해 스폰


# ===== SIGNALS =====

signal drop_pod_approaching(pod: Node3D, eta: float, target_tile: Vector2i)
signal drop_pod_landed(pod: Node3D, target_tile: Vector2i)
signal enemies_spawned(enemies: Array)
signal wave_spawn_complete()


# ===== CONFIGURATION =====

@export var approach_time: float = 3.0  # 드롭팟 접근 시간
@export var warning_time: float = 2.0   # 경고 표시 시간
@export var spawn_delay: float = 0.5    # 적 스폰 간 딜레이


# ===== REFERENCES =====

var battle_map: Node3D
var _drop_pod_scene: PackedScene
var _warning_scene: PackedScene
var _enemy_scene: PackedScene


# ===== STATE =====

var _active_pods: Array[Node3D] = []
var _pending_spawns: Array[Dictionary] = []
var _warnings: Dictionary = {}  # Vector2i -> DropPodWarning3D


# ===== LIFECYCLE =====

func _ready() -> void:
	_load_scenes()


func _load_scenes() -> void:
	var pod_path := "res://src/entities/vehicle/DropPod3D.tscn"
	var warning_path := "res://src/ui/battle_hud/DropPodWarning3D.tscn"
	var enemy_path := "res://src/entities/enemy/EnemyUnit3D.tscn"

	if ResourceLoader.exists(pod_path):
		_drop_pod_scene = load(pod_path)

	if ResourceLoader.exists(warning_path):
		_warning_scene = load(warning_path)

	if ResourceLoader.exists(enemy_path):
		_enemy_scene = load(enemy_path)


# ===== PUBLIC API =====

## 배틀맵 설정
func set_battle_map(map: Node3D) -> void:
	battle_map = map


## 드롭팟을 통해 적 그룹 스폰
## [param enemy_id]: 적 타입 ID
## [param count]: 적 수
## [param entry_tile]: 착륙 타일 좌표
## [param approach_dir]: 접근 방향 (기본: 자동 계산)
func spawn_enemy_group_via_pod(enemy_id: String, count: int, entry_tile: Vector2i, approach_dir: Vector3 = Vector3.ZERO) -> void:
	if battle_map == null:
		push_warning("SpawnController3D: battle_map not set")
		return

	# 접근 방향 계산 (맵 바깥에서 오는 방향)
	if approach_dir == Vector3.ZERO:
		approach_dir = _calculate_approach_direction(entry_tile)

	# 경고 표시
	_show_landing_warning(entry_tile, approach_time)

	# 드롭팟 스폰 예약
	var spawn_data := {
		"enemy_id": enemy_id,
		"count": count,
		"entry_tile": entry_tile,
		"approach_dir": approach_dir
	}

	# 경고 시간 후 드롭팟 스폰
	get_tree().create_timer(warning_time).timeout.connect(
		func(): _spawn_drop_pod(spawn_data)
	)


## 다중 그룹 동시 스폰
func spawn_wave_via_pods(wave_data: Array[Dictionary]) -> void:
	for group in wave_data:
		var enemy_id: String = group.get("enemy_id", "rusher")
		var count: int = group.get("count", 3)
		var entry_tile: Vector2i = group.get("entry_tile", Vector2i.ZERO)

		spawn_enemy_group_via_pod(enemy_id, count, entry_tile)


## 모든 활성 드롭팟 가져오기
func get_active_pods() -> Array[Node3D]:
	return _active_pods


## 드롭팟 수 가져오기
func get_pending_pod_count() -> int:
	return _active_pods.size()


# ===== DROP POD SPAWNING =====

func _spawn_drop_pod(spawn_data: Dictionary) -> void:
	if battle_map == null:
		return

	var entry_tile: Vector2i = spawn_data.entry_tile
	var approach_dir: Vector3 = spawn_data.approach_dir
	var enemy_id: String = spawn_data.enemy_id
	var count: int = spawn_data.count

	# 적 페이로드 생성
	var enemy_payload: Array = []
	for i in range(count):
		enemy_payload.append({
			"enemy_id": enemy_id,
			"index": i
		})

	# 드롭팟 생성
	var pod: Node3D

	if _drop_pod_scene:
		pod = _drop_pod_scene.instantiate()
	else:
		pod = _create_fallback_pod()

	battle_map.add_child(pod)

	# 드롭팟 초기화
	if pod.has_method("initialize"):
		pod.initialize({
			"target_tile": entry_tile,
			"enemies": enemy_payload,
			"approach_direction": approach_dir
		})

		if pod.has_method("start_approach"):
			pod.start_approach()

	# 시그널 연결
	if pod.has_signal("approaching"):
		pod.approaching.connect(_on_pod_approaching.bind(pod, entry_tile))

	if pod.has_signal("landed"):
		pod.landed.connect(_on_pod_landed.bind(pod))

	if pod.has_signal("enemies_deployed"):
		pod.enemies_deployed.connect(_on_pod_enemies_deployed.bind(pod, entry_tile))

	if pod.has_signal("departed"):
		pod.departed.connect(_on_pod_departed.bind(pod))

	_active_pods.append(pod)

	# 접근 시그널 발신
	drop_pod_approaching.emit(pod, approach_time, entry_tile)

	# 경고 제거
	_remove_landing_warning(entry_tile)


func _create_fallback_pod() -> Node3D:
	# 드롭팟 씬이 없을 때 폴백
	var pod := Node3D.new()
	pod.name = "FallbackPod"

	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.2

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.35, 0.3)
	capsule.material = mat

	mesh.mesh = capsule
	mesh.position.y = 0.6
	pod.add_child(mesh)

	return pod


# ===== WARNING SYSTEM =====

func _show_landing_warning(tile_pos: Vector2i, eta: float) -> void:
	if battle_map == null:
		return

	# 3D 경고 효과
	if EffectsManager3D:
		var world_pos := _tile_to_world(tile_pos)
		EffectsManager3D.spawn_floating_text_3d("!", world_pos + Vector3(0, 2, 0), Color.RED, 1.5)

	# 경고 씬 스폰
	if _warning_scene:
		var warning := _warning_scene.instantiate()
		warning.position = _tile_to_world(tile_pos)
		battle_map.add_child(warning)

		if warning.has_method("initialize"):
			warning.initialize(tile_pos, _tile_to_world(tile_pos), eta)

		_warnings[tile_pos] = warning
	else:
		# 폴백: 간단한 경고 표시
		_create_simple_warning(tile_pos, eta)


func _create_simple_warning(tile_pos: Vector2i, eta: float) -> void:
	var warning := Node3D.new()
	warning.name = "LandingWarning"
	warning.position = _tile_to_world(tile_pos)

	# 경고 링
	var mesh := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.3
	torus.outer_radius = 0.5

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.3, 0.1, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.3, 0.1)
	mat.emission_energy_multiplier = 1.0
	torus.material = mat

	mesh.mesh = torus
	mesh.rotation_degrees.x = 90
	warning.add_child(mesh)

	if battle_map:
		battle_map.add_child(warning)

	_warnings[tile_pos] = warning

	# 펄스 애니메이션
	var tween := warning.create_tween()
	tween.set_loops(int(eta / 0.6))
	tween.tween_property(warning, "scale", Vector3(1.3, 1.3, 1.3), 0.3)
	tween.tween_property(warning, "scale", Vector3(1.0, 1.0, 1.0), 0.3)

	# ETA 후 자동 제거
	get_tree().create_timer(eta + 0.5).timeout.connect(
		func():
			if is_instance_valid(warning):
				warning.queue_free()
	)


func _remove_landing_warning(tile_pos: Vector2i) -> void:
	if _warnings.has(tile_pos):
		var warning := _warnings[tile_pos]
		if is_instance_valid(warning):
			warning.queue_free()
		_warnings.erase(tile_pos)


# ===== POD EVENT HANDLERS =====

func _on_pod_approaching(_eta: float, pod: Node3D, tile_pos: Vector2i) -> void:
	# 접근 중 이펙트
	if EffectsManager3D:
		EffectsManager3D.spawn_engine_trail_3d(pod.global_position, Vector3.DOWN, 2.0)


func _on_pod_landed(tile_pos: Vector2i, pod: Node3D) -> void:
	drop_pod_landed.emit(pod, tile_pos)

	# 착륙 이펙트
	if EffectsManager3D:
		EffectsManager3D.spawn_impact_effect_3d(pod.global_position, 2.0)


func _on_pod_enemies_deployed(deployed: Array, pod: Node3D, tile_pos: Vector2i) -> void:
	# 실제 적 스폰
	var spawned_enemies: Array = []

	for i in range(deployed.size()):
		var enemy_data: Dictionary = deployed[i]
		var enemy_id: String = enemy_data.get("enemy_id", "rusher")

		# 약간의 오프셋으로 스폰
		var offset := Vector3(
			randf_range(-0.5, 0.5),
			0,
			randf_range(-0.5, 0.5)
		)
		var spawn_pos := _tile_to_world(tile_pos) + offset

		# 적 생성
		var enemy := _spawn_enemy(enemy_id, spawn_pos, tile_pos)
		if enemy:
			spawned_enemies.append(enemy)

		# 스폰 간 딜레이
		if i < deployed.size() - 1 and spawn_delay > 0:
			await get_tree().create_timer(spawn_delay).timeout

	enemies_spawned.emit(spawned_enemies)

	# EventBus 알림
	if EventBus:
		for enemy in spawned_enemies:
			EventBus.enemy_spawned.emit(enemy, tile_pos)


func _on_pod_departed(pod: Node3D) -> void:
	_active_pods.erase(pod)

	# 모든 팟이 퇴각하면 웨이브 스폰 완료
	if _active_pods.is_empty():
		wave_spawn_complete.emit()


# ===== ENEMY SPAWNING =====

func _spawn_enemy(enemy_id: String, world_pos: Vector3, tile_pos: Vector2i) -> Node3D:
	if battle_map == null:
		return null

	var enemy: Node3D

	if _enemy_scene:
		enemy = _enemy_scene.instantiate()
	elif battle_map.has_method("spawn_enemy"):
		return battle_map.spawn_enemy(tile_pos, enemy_id)
	else:
		enemy = _create_fallback_enemy(enemy_id)

	if enemy:
		battle_map.add_child(enemy)
		enemy.global_position = world_pos

		if enemy.has_method("initialize"):
			enemy.initialize({
				"enemy_id": enemy_id,
				"tile_position": tile_pos
			})

	return enemy


func _create_fallback_enemy(enemy_id: String) -> Node3D:
	var enemy := Node3D.new()
	enemy.name = "Enemy_" + enemy_id

	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.2
	capsule.height = 0.8

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.RED
	capsule.material = mat

	mesh.mesh = capsule
	mesh.position.y = 0.4
	enemy.add_child(mesh)

	return enemy


# ===== UTILITIES =====

func _calculate_approach_direction(tile_pos: Vector2i) -> Vector3:
	if battle_map == null:
		return Vector3.BACK

	# 맵 경계 확인
	var map_width := 15
	var map_height := 12

	if battle_map.has_method("get_map_bounds"):
		var bounds: AABB = battle_map.get_map_bounds()
		map_width = int(bounds.size.x)
		map_height = int(bounds.size.z)

	# 가장 가까운 가장자리에서 접근
	var center := Vector2(map_width / 2.0, map_height / 2.0)
	var tile_vec := Vector2(tile_pos.x, tile_pos.y)
	var dir := (tile_vec - center).normalized()

	# 주요 방향으로 스냅
	if abs(dir.x) > abs(dir.y):
		return Vector3(sign(dir.x), 0, 0)
	else:
		return Vector3(0, 0, sign(dir.y))


func _tile_to_world(tile_pos: Vector2i) -> Vector3:
	if battle_map and battle_map.has_method("tile_to_world"):
		return battle_map.tile_to_world(tile_pos)
	return Vector3(tile_pos.x + 0.5, 0, tile_pos.y + 0.5)
