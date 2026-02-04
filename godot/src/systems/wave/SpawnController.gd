class_name SpawnController
extends Node

## 적 스폰 컨트롤러
## 웨이브 데이터를 받아 적을 순차적으로 스폰

const UtilsClass = preload("res://src/utils/Utils.gd")

# ===== SIGNALS =====

signal enemy_spawned(enemy: Node)
signal group_spawned(enemy_id: String, count: int, entry_point: Vector2i)
signal spawning_complete()


# ===== CONSTANTS =====

const SPAWN_STAGGER_DELAY: float = 0.3  # 같은 그룹 내 개체 간 딜레이
const LANDING_DURATION: float = 1.0     # 착륙 애니메이션 시간


# ===== VARIABLES =====

var current_wave_data  # WaveGenerator.WaveData
var spawn_queue: Array = []
var is_spawning: bool = false
var spawning_complete_flag: bool = true

var _enemy_scene: PackedScene
var _tile_grid: Node  # TileGrid reference
var _battle_controller: Node  # BattleController reference


# ===== INITIALIZATION =====

func _ready() -> void:
	_try_load_enemy_scene()


func initialize(tile_grid: Node, battle_controller: Node) -> void:
	_tile_grid = tile_grid
	_battle_controller = battle_controller


func _try_load_enemy_scene() -> void:
	var path := "res://src/entities/enemy/EnemyUnit.tscn"
	if ResourceLoader.exists(path):
		_enemy_scene = load(path)
	else:
		push_warning("SpawnController: EnemyUnit.tscn not found at %s" % path)


# ===== PUBLIC METHODS =====

## 웨이브 스폰 시작
func start_spawning(wave_data) -> void:
	if is_spawning:
		push_warning("SpawnController: Already spawning, ignoring new request")
		return

	current_wave_data = wave_data
	spawning_complete_flag = false
	is_spawning = true
	spawn_queue.clear()

	# 스폰 큐 생성
	for i in range(wave_data.enemies.size()):
		var enemy_group: Dictionary = wave_data.enemies[i]
		var delay: float = 0.0

		if i < wave_data.spawn_delays.size():
			delay = wave_data.spawn_delays[i]

		spawn_queue.append({
			"enemy_id": enemy_group.enemy_id,
			"count": enemy_group.count,
			"entry_point": enemy_group.entry_point,
			"delay": delay
		})

	# 스폰 처리 시작
	_process_spawn_queue()


## 스폰 중단
func stop_spawning() -> void:
	is_spawning = false
	spawn_queue.clear()
	spawning_complete_flag = true


## 스폰 완료 여부
func is_spawning_complete() -> bool:
	return spawning_complete_flag


## 현재 스폰 진행률 (0.0 ~ 1.0)
func get_spawn_progress() -> float:
	if current_wave_data == null or current_wave_data.enemies.is_empty():
		return 1.0

	var total: int = current_wave_data.enemies.size()
	var remaining: int = spawn_queue.size()

	return 1.0 - (float(remaining) / float(total))


# ===== PRIVATE METHODS =====

func _process_spawn_queue() -> void:
	for spawn_info in spawn_queue:
		if not is_spawning:
			break

		# 그룹 딜레이 대기
		if spawn_info.delay > 0:
			await get_tree().create_timer(spawn_info.delay).timeout

		if not is_spawning:
			break

		# 그룹 스폰
		await _spawn_enemy_group(spawn_info)

	# 스폰 완료
	is_spawning = false
	spawning_complete_flag = true
	spawning_complete.emit()


func _spawn_enemy_group(spawn_info: Dictionary) -> void:
	var enemy_id: String = spawn_info.enemy_id
	var count: int = spawn_info.count
	var entry_point: Vector2i = spawn_info.entry_point

	# 착륙 경고 이벤트
	EventBus.enemy_group_landing.emit(entry_point, count)

	# 그룹 스폰 시그널
	group_spawned.emit(enemy_id, count, entry_point)

	# 개체별 스폰 (시차 적용)
	for i in range(count):
		if not is_spawning:
			break

		await _spawn_single_enemy(enemy_id, entry_point)

		# 다음 개체 스폰 전 딜레이
		if i < count - 1:
			await get_tree().create_timer(SPAWN_STAGGER_DELAY).timeout


func _spawn_single_enemy(enemy_id: String, entry_point: Vector2i) -> void:
	# 적 데이터 가져오기
	var enemy_data: Resource = Constants.get_enemy(enemy_id)
	if enemy_data == null:
		push_warning("SpawnController: Enemy data not found for '%s'" % enemy_id)
		return

	# 씬 인스턴스 생성
	var enemy: Node = _create_enemy_instance()
	if enemy == null:
		return

	# 초기화
	if enemy.has_method("initialize"):
		enemy.initialize(enemy_data, entry_point)

	# 월드 위치 설정
	var world_pos: Vector2 = _get_world_position(entry_point)
	enemy.global_position = world_pos

	# 씬에 추가
	_add_enemy_to_scene(enemy)

	# 착륙 처리
	await _handle_enemy_landing(enemy)

	# 스폰 완료 시그널
	enemy_spawned.emit(enemy)
	EventBus.enemy_spawned.emit(enemy, entry_point)


func _create_enemy_instance() -> Node:
	if _enemy_scene != null:
		return _enemy_scene.instantiate()

	# 씬이 없으면 동적 로드 시도
	_try_load_enemy_scene()
	if _enemy_scene != null:
		return _enemy_scene.instantiate()

	# 폴백: 빈 Node2D 생성 (테스트/스텁용)
	push_warning("SpawnController: Creating stub enemy (scene not available)")
	var stub := Node2D.new()
	stub.set_meta("is_stub", true)
	stub.set_meta("enemy_id", "unknown")
	return stub


func _get_world_position(tile_pos: Vector2i) -> Vector2:
	if _tile_grid != null and _tile_grid.has_method("tile_to_world"):
		return _tile_grid.tile_to_world(tile_pos)

	# 폴백: Utils 사용
	return UtilsClass.tile_to_world(tile_pos)


func _add_enemy_to_scene(enemy: Node) -> void:
	if _battle_controller != null:
		_battle_controller.add_child(enemy)

		# BattleController에 등록
		if _battle_controller.has_method("register_enemy"):
			_battle_controller.register_enemy(enemy)
	else:
		# 폴백: 부모 노드에 추가
		var parent: Node = get_parent()
		if parent != null:
			parent.add_child(enemy)
		else:
			add_child(enemy)


func _handle_enemy_landing(enemy: Node) -> void:
	# 착륙 시작
	if enemy.has_method("start_landing"):
		enemy.start_landing()

	# 착륙 애니메이션 대기
	await get_tree().create_timer(LANDING_DURATION).timeout

	# 착륙 완료
	if enemy.has_method("complete_landing"):
		enemy.complete_landing()


# ===== UTILITY =====

## 특정 진입점 주변의 스폰 가능 위치 찾기
func find_spawn_positions(entry_point: Vector2i, count: int) -> Array[Vector2i]:
	var positions: Array[Vector2i] = [entry_point]

	if count <= 1:
		return positions

	# 주변 타일 탐색
	var offsets: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, -1),
		Vector2i(1, -1), Vector2i(-1, 1)
	]

	for offset in offsets:
		if positions.size() >= count:
			break

		var pos: Vector2i = entry_point + offset

		# 타일 유효성 확인
		if _is_valid_spawn_position(pos):
			positions.append(pos)

	return positions


func _is_valid_spawn_position(pos: Vector2i) -> bool:
	if _tile_grid == null:
		return true  # 그리드 없으면 모든 위치 허용

	if _tile_grid.has_method("is_walkable"):
		return _tile_grid.is_walkable(pos)

	if _tile_grid.has_method("is_valid_position"):
		return _tile_grid.is_valid_position(pos)

	return true
