## BattleManager - 전투 진행 관리
## 웨이브 스폰, 전투 상태, 승패 판정
extends Node
class_name BattleManager

# ===========================================
# 전투 상태
# ===========================================

enum BattleState {
	SETUP,      # 초기 배치
	FIGHTING,   # 전투 중
	WAVE_CLEAR, # 웨이브 클리어 대기
	VICTORY,    # 승리
	DEFEAT,     # 패배
}

var state: BattleState = BattleState.SETUP
var is_paused: bool = false

# 그리드 & 경로
var grid: TileGrid = null
var pathfinder: Pathfinder = null

# 웨이브
var waves: Array[Dictionary] = []
var current_wave_index: int = 0
var wave_spawn_timer: float = 0.0
var spawn_queue: Array[Dictionary] = []

# 엔티티 추적
var crew_units: Array[CrewUnit] = []
var enemy_units: Array[EnemyUnit] = []

# 전투 통계
var stats: Dictionary = {
	"enemies_killed": 0,
	"damage_dealt": 0,
	"damage_taken": 0,
	"facilities_destroyed": 0,
}

# 씬 참조
var crew_unit_scene: PackedScene = preload("res://scenes/battle/crew_unit.tscn")
var enemy_unit_scene: PackedScene = preload("res://scenes/battle/enemy_unit.tscn")

# 컨테이너 참조
var crews_container: Node2D = null
var enemies_container: Node2D = null


# ===========================================
# 시그널
# ===========================================

signal battle_started()
signal wave_started(wave_index: int, total: int)
signal wave_cleared(wave_index: int)
signal all_waves_cleared()
signal battle_ended(is_victory: bool, rewards: Dictionary)
signal enemy_spawned(enemy: EnemyUnit)
signal facility_destroyed(position: Vector2i)


# ===========================================
# 초기화
# ===========================================

func initialize(station_data: Dictionary, crew_list: Array[Dictionary]) -> void:
	# 그리드 생성/로드
	if station_data.has("grid"):
		grid = station_data["grid"]
	else:
		var turn: int = station_data.get("turn", 1)
		var difficulty: int = station_data.get("difficulty", 0)
		grid = StationGenerator.generate(20, 15, turn, difficulty)

	pathfinder = Pathfinder.new(grid)

	# 웨이브 생성
	var turn: int = station_data.get("turn", 1)
	var difficulty: int = station_data.get("difficulty", 0)
	waves = WaveGenerator.generate_waves(turn, difficulty, grid.airlocks.size())

	# 크루 배치
	_setup_crews(crew_list)

	state = BattleState.SETUP


func _setup_crews(crew_list: Array[Dictionary]) -> void:
	if crews_container == null:
		return

	# 시설 근처에 크루 배치
	var facilities := grid.get_intact_facilities()
	var spawn_positions: Array[Vector2i] = []

	for facility in facilities:
		var facility_pos: Vector2i = facility["position"]
		for neighbor in grid.get_walkable_neighbors(facility_pos, true):
			if neighbor not in spawn_positions:
				spawn_positions.append(neighbor)

	for i in range(crew_list.size()):
		var crew_data: Dictionary = crew_list[i]

		if not crew_data.get("is_alive", true):
			continue

		var unit := crew_unit_scene.instantiate() as CrewUnit
		crews_container.add_child(unit)

		# 배치 위치
		var pos := spawn_positions[i % spawn_positions.size()] if not spawn_positions.is_empty() else Vector2i(10, 7)
		crew_data["position"] = pos

		unit.initialize_crew(crew_data, grid, pathfinder)
		crew_units.append(unit)

		# 시그널 연결
		unit.died.connect(_on_crew_died)
		unit.took_damage.connect(_on_unit_took_damage)


# ===========================================
# 게임 루프
# ===========================================

func _process(delta: float) -> void:
	if is_paused:
		return

	match state:
		BattleState.SETUP:
			pass  # 플레이어 배치 대기
		BattleState.FIGHTING:
			_process_fighting(delta)
		BattleState.WAVE_CLEAR:
			_process_wave_clear(delta)


func _process_fighting(delta: float) -> void:
	# 스폰 큐 처리
	_process_spawn_queue(delta)

	# 승패 체크
	_check_battle_end()


func _process_spawn_queue(delta: float) -> void:
	if spawn_queue.is_empty():
		return

	wave_spawn_timer -= delta

	if wave_spawn_timer <= 0:
		var spawn_data: Dictionary = spawn_queue.pop_front()
		_spawn_enemy(spawn_data)

		# 다음 스폰 타이머
		wave_spawn_timer = 0.3


func _process_wave_clear(_delta: float) -> void:
	# 다음 웨이브 준비
	current_wave_index += 1

	if current_wave_index >= waves.size():
		_on_all_waves_cleared()
	else:
		_start_next_wave()


# ===========================================
# 전투 시작
# ===========================================

func start_battle() -> void:
	state = BattleState.FIGHTING
	battle_started.emit()
	EventBus.battle_started.emit(grid.serialize())

	_start_next_wave()


func _start_next_wave() -> void:
	if current_wave_index >= waves.size():
		_on_all_waves_cleared()
		return

	var wave: Dictionary = waves[current_wave_index]

	wave_started.emit(current_wave_index, waves.size())
	EventBus.wave_started.emit(current_wave_index, waves.size())

	# 스폰 큐 설정
	_queue_wave_spawns(wave)

	# 웨이브 딜레이
	wave_spawn_timer = wave.get("delay_before", 2.0)


func _queue_wave_spawns(wave: Dictionary) -> void:
	var spawn_groups: Array = wave.get("spawn_groups", [])

	for group in spawn_groups:
		var airlock_index: int = group.get("airlock_index", 0)
		var enemies: Array = group.get("enemies", [])

		if airlock_index >= grid.airlocks.size():
			airlock_index = 0

		var airlock_pos := grid.airlocks[airlock_index] if not grid.airlocks.is_empty() else Vector2i(0, 0)

		for enemy_data in enemies:
			spawn_queue.append({
				"type": enemy_data["type"],
				"position": airlock_pos,
				"delay": group.get("spawn_delay", 0.0),
			})


# ===========================================
# 적 스폰
# ===========================================

func _spawn_enemy(spawn_data: Dictionary) -> void:
	if enemies_container == null:
		return

	var enemy_type: String = spawn_data["type"]
	var spawn_pos: Vector2i = spawn_data["position"]

	var unit := enemy_unit_scene.instantiate() as EnemyUnit
	enemies_container.add_child(unit)

	unit.initialize_enemy(enemy_type, grid, pathfinder, spawn_pos)
	unit.land(spawn_pos)

	enemy_units.append(unit)

	# 시그널 연결
	unit.died.connect(_on_enemy_died)
	unit.took_damage.connect(_on_unit_took_damage)
	unit.enemy_reached_facility.connect(_on_enemy_reached_facility)

	enemy_spawned.emit(unit)
	EventBus.enemy_spawned.emit(unit, spawn_pos)


# ===========================================
# 이벤트 핸들러
# ===========================================

func _on_crew_died(unit: BaseUnit) -> void:
	var crew := unit as CrewUnit
	if crew:
		crew_units.erase(crew)
		stats["damage_taken"] += crew.max_squad_size * 10


func _on_enemy_died(unit: BaseUnit) -> void:
	var enemy := unit as EnemyUnit
	if enemy:
		enemy_units.erase(enemy)
		stats["enemies_killed"] += 1

	# 웨이브 클리어 체크
	if enemy_units.is_empty() and spawn_queue.is_empty():
		_on_wave_cleared()


func _on_unit_took_damage(unit: BaseUnit, amount: int, _source: BaseUnit) -> void:
	if unit.team == 0:
		stats["damage_taken"] += amount
	else:
		stats["damage_dealt"] += amount


func _on_enemy_reached_facility(enemy: EnemyUnit, facility_pos: Vector2i) -> void:
	# 시설 공격
	var destroyed := grid.damage_facility(facility_pos, enemy.attack_damage)

	if destroyed:
		stats["facilities_destroyed"] += 1
		facility_destroyed.emit(facility_pos)
		EventBus.facility_destroyed.emit(facility_pos)

		# 모든 시설 파괴 체크
		if grid.get_intact_facilities().is_empty():
			_on_defeat()


func _on_wave_cleared() -> void:
	wave_cleared.emit(current_wave_index)
	EventBus.wave_cleared.emit(current_wave_index)

	state = BattleState.WAVE_CLEAR


func _on_all_waves_cleared() -> void:
	all_waves_cleared.emit()
	EventBus.all_waves_cleared.emit()

	_on_victory()


# ===========================================
# 승패 판정
# ===========================================

func _check_battle_end() -> void:
	# 모든 크루 전멸
	var alive_crews := crew_units.filter(func(c: CrewUnit) -> bool: return c.is_alive)
	if alive_crews.is_empty():
		# 크루 전멸이지만 시설이 남아있으면 계속 진행 (자동 방어)
		# 시설도 없으면 패배
		if grid.get_intact_facilities().is_empty():
			_on_defeat()


func _on_victory() -> void:
	state = BattleState.VICTORY

	var is_perfect := stats["facilities_destroyed"] == 0
	var rewards := CombatMechanics.calculate_battle_rewards(
		stats,
		GameState.get_current_run().difficulty if GameState.get_current_run() else 0,
		is_perfect
	)

	battle_ended.emit(true, rewards)
	EventBus.battle_ended.emit(true, rewards)


func _on_defeat() -> void:
	state = BattleState.DEFEAT

	battle_ended.emit(false, {})
	EventBus.battle_ended.emit(false, {})


# ===========================================
# 일시정지
# ===========================================

func pause() -> void:
	is_paused = true
	get_tree().paused = true
	EventBus.game_paused.emit()


func resume() -> void:
	is_paused = false
	get_tree().paused = false
	EventBus.game_resumed.emit()


func toggle_pause() -> void:
	if is_paused:
		resume()
	else:
		pause()


# ===========================================
# 유틸리티
# ===========================================

func get_crew_at(pos: Vector2i) -> CrewUnit:
	for crew in crew_units:
		if crew.grid_position == pos:
			return crew
	return null


func get_enemy_at(pos: Vector2i) -> EnemyUnit:
	for enemy in enemy_units:
		if enemy.grid_position == pos:
			return enemy
	return null


func get_all_enemies_in_range(center: Vector2i, range_val: int) -> Array[EnemyUnit]:
	var result: Array[EnemyUnit] = []
	for enemy in enemy_units:
		if enemy.is_alive and enemy.get_grid_distance_to_pos(center) <= range_val:
			result.append(enemy)
	return result


func sync_crew_data() -> Array[Dictionary]:
	var data: Array[Dictionary] = []
	for crew in crew_units:
		data.append(crew.get_data())
	return data
