class_name WaveManager
extends Node

## 웨이브 상태 관리자
## 웨이브 생성, 진행, 완료를 관리


# ===== SIGNALS =====

signal wave_started(wave_num: int)
signal wave_ended(wave_num: int)
signal all_waves_cleared()
signal enemy_spawned(enemy: Node)
signal wave_preview_ready(wave_num: int, preview: Array)


# ===== CONSTANTS =====

const WAVE_TRANSITION_DELAY: float = 2.0  # 웨이브 간 딜레이

const WaveGeneratorClass = preload("res://src/systems/wave/WaveGenerator.gd")
const SpawnControllerClass = preload("res://src/systems/wave/SpawnController.gd")


# ===== VARIABLES =====

var wave_generator  # WaveGenerator
var spawn_controller  # SpawnController

var waves: Array = []  # Array of WaveGenerator.WaveData
var current_wave_index: int = -1
var active_enemies: Array = []  # Array of EnemyUnit
var is_wave_active: bool = false
var is_battle_active: bool = false

var _tile_grid: Node
var _battle_controller: Node
var _difficulty: Constants.Difficulty = Constants.Difficulty.NORMAL


# ===== INITIALIZATION =====

func _ready() -> void:
	# SpawnController 생성
	spawn_controller = SpawnControllerClass.new()
	spawn_controller.name = "SpawnController"
	add_child(spawn_controller)

	# 시그널 연결
	spawn_controller.enemy_spawned.connect(_on_enemy_spawned)
	spawn_controller.spawning_complete.connect(_on_spawning_complete)

	# EventBus 연결
	EventBus.entity_died.connect(_on_entity_died)


func _exit_tree() -> void:
	# EventBus 연결 해제
	if EventBus:
		EventBus.entity_died.disconnect(_on_entity_died)


## 웨이브 시스템 초기화
func initialize(
	tile_grid: Node,
	battle_controller: Node,
	difficulty: Constants.Difficulty = Constants.Difficulty.NORMAL
) -> void:
	_tile_grid = tile_grid
	_battle_controller = battle_controller
	_difficulty = difficulty

	# SpawnController 초기화
	spawn_controller.initialize(tile_grid, battle_controller)


## 스테이션/전투 시작 시 웨이브 생성
func setup_waves(station_depth: int, entry_points: Array[Vector2i], seed_value: int = 0) -> void:
	# 시드 설정
	if seed_value == 0 and GameState != null and GameState.current_seed != 0:
		seed_value = GameState.current_seed

	# 웨이브 생성
	wave_generator = WaveGeneratorClass.new(seed_value)
	waves = wave_generator.generate_waves(station_depth, _difficulty, entry_points)

	# 상태 초기화
	current_wave_index = -1
	active_enemies.clear()
	is_wave_active = false
	is_battle_active = true


## 보스 웨이브 설정
func setup_boss_wave(
	station_depth: int,
	entry_points: Array[Vector2i],
	boss_id: String = "pirate_captain",
	seed_value: int = 0
) -> void:
	if seed_value == 0 and GameState != null:
		seed_value = GameState.current_seed

	wave_generator = WaveGeneratorClass.new(seed_value)
	var boss_wave = wave_generator.generate_boss_wave(
		station_depth, _difficulty, entry_points, boss_id
	)

	waves = [boss_wave]
	current_wave_index = -1
	active_enemies.clear()
	is_wave_active = false
	is_battle_active = true


# ===== PUBLIC METHODS =====

## 총 웨이브 수
func get_total_waves() -> int:
	return waves.size()


## 현재 웨이브 번호 (1-based)
func get_current_wave() -> int:
	return current_wave_index + 1


## 현재 웨이브 데이터
func get_current_wave_data() -> Variant:
	if current_wave_index >= 0 and current_wave_index < waves.size():
		return waves[current_wave_index]
	return null


## 다음 웨이브 미리보기
func get_next_wave_preview() -> Array:
	var next_index: int = current_wave_index + 1
	if next_index >= 0 and next_index < waves.size():
		return wave_generator.get_wave_preview(waves[next_index])
	return []


## 남은 적 수
func get_remaining_enemies() -> int:
	return active_enemies.size()


## 다음 웨이브 시작
func start_next_wave() -> void:
	if not is_battle_active:
		push_warning("WaveManager: Battle not active")
		return

	current_wave_index += 1

	# 모든 웨이브 클리어 체크
	if current_wave_index >= waves.size():
		_on_all_waves_cleared()
		return

	is_wave_active = true
	var wave_data = waves[current_wave_index]

	# 웨이브 미리보기 생성
	var preview: Array = wave_generator.get_wave_preview(wave_data)
	wave_preview_ready.emit(current_wave_index + 1, preview)

	# 로컬 시그널
	wave_started.emit(current_wave_index + 1)

	# EventBus 시그널
	EventBus.wave_started.emit(
		current_wave_index + 1,
		waves.size(),
		preview
	)

	# 스폰 시작
	spawn_controller.start_spawning(wave_data)


## 웨이브 강제 종료
func force_end_wave() -> void:
	if not is_wave_active:
		return

	spawn_controller.stop_spawning()
	is_wave_active = false

	wave_ended.emit(current_wave_index + 1)
	EventBus.wave_ended.emit(current_wave_index + 1)


## 전투 종료
func end_battle() -> void:
	is_battle_active = false
	is_wave_active = false
	spawn_controller.stop_spawning()
	active_enemies.clear()


## 적 제거 (전투에서 직접 제거 시)
func remove_enemy(enemy: Node) -> void:
	active_enemies.erase(enemy)
	_check_wave_clear()


# ===== SIGNAL HANDLERS =====

func _on_enemy_spawned(enemy: Node) -> void:
	active_enemies.append(enemy)
	enemy_spawned.emit(enemy)


func _on_spawning_complete() -> void:
	# 스폰 완료 후 웨이브 클리어 체크
	_check_wave_clear()


func _on_entity_died(entity: Node) -> void:
	# 적인지 확인
	if not _is_enemy(entity):
		return

	# 활성 적 목록에서 제거
	if active_enemies.has(entity):
		active_enemies.erase(entity)
		_check_wave_clear()


func _is_enemy(entity: Node) -> bool:
	# EnemyUnit 클래스 체크
	if entity.get_class() == "EnemyUnit":
		return true

	# 그룹 체크
	if entity.is_in_group("enemies"):
		return true

	# team 속성 체크
	if entity.has_method("get") and entity.get("team") == 1:
		return true

	return false


# ===== PRIVATE METHODS =====

func _check_wave_clear() -> void:
	if not is_wave_active:
		return

	# 모든 적 처치 + 스폰 완료
	if active_enemies.is_empty() and spawn_controller.is_spawning_complete():
		_on_wave_cleared()


func _on_wave_cleared() -> void:
	is_wave_active = false

	# 로컬 시그널
	wave_ended.emit(current_wave_index + 1)

	# EventBus 시그널
	EventBus.wave_ended.emit(current_wave_index + 1)

	# 다음 웨이브가 있으면 딜레이 후 자동 시작
	if current_wave_index + 1 < waves.size():
		_schedule_next_wave()
	else:
		_on_all_waves_cleared()


func _schedule_next_wave() -> void:
	await get_tree().create_timer(WAVE_TRANSITION_DELAY).timeout

	if is_battle_active:
		start_next_wave()


func _on_all_waves_cleared() -> void:
	is_battle_active = false

	# 로컬 시그널
	all_waves_cleared.emit()

	# EventBus 시그널
	EventBus.all_waves_cleared.emit()


# ===== DEBUG / UTILITY =====

## 현재 상태 정보
func get_status() -> Dictionary:
	return {
		"is_battle_active": is_battle_active,
		"is_wave_active": is_wave_active,
		"current_wave": get_current_wave(),
		"total_waves": get_total_waves(),
		"active_enemies": active_enemies.size(),
		"spawning_complete": spawn_controller.is_spawning_complete()
	}


## 디버그: 현재 웨이브 즉시 클리어
func debug_clear_current_wave() -> void:
	for enemy in active_enemies.duplicate():
		if enemy != null and enemy.has_method("die"):
			enemy.die()
		else:
			active_enemies.erase(enemy)

	spawn_controller.stop_spawning()
	_check_wave_clear()


## 디버그: 특정 웨이브로 점프
func debug_jump_to_wave(wave_num: int) -> void:
	current_wave_index = wave_num - 2  # start_next_wave에서 +1 되므로
	active_enemies.clear()
	spawn_controller.stop_spawning()
	is_wave_active = false
	start_next_wave()
