class_name BattleController
extends Node

## 전투 메인 컨트롤러
## 전투 루프, 크루 선택/명령, 웨이브 관리 통합


# ===== SIGNALS =====

signal battle_started()
signal battle_ended(result: BattleResult)
signal pause_state_changed(is_paused: bool)
signal slow_motion_changed(is_slow: bool)
signal selection_changed(selected: Node)
signal wave_progress_changed(current: int, total: int)
signal emergency_evac_started()
signal emergency_evac_completed()


# ===== INNER CLASS =====

class BattleResult:
	var victory: bool = false
	var facilities_saved: int = 0
	var facilities_total: int = 0
	var credits_earned: int = 0
	var enemies_killed: int = 0
	var crew_casualties: Array[String] = []

	func _to_string() -> String:
		return "BattleResult(victory=%s, credits=%d, killed=%d)" % [victory, credits_earned, enemies_killed]


# ===== CONFIGURATION =====

@export var slow_motion_factor: float = 0.3
@export var enable_auto_slow_on_select: bool = false  # 비활성화


# ===== PRELOADS =====

const SkillSystemClass = preload("res://src/systems/combat/SkillSystem.gd")
const EquipmentSystemClass = preload("res://src/systems/combat/EquipmentSystem.gd")
const DamageCalculatorClass = preload("res://src/systems/combat/DamageCalculator.gd")
const RavenSystemClass = preload("res://src/systems/combat/RavenSystem.gd")
const FacilityBonusManagerClass = preload("res://src/systems/combat/FacilityBonusManager.gd")
const StormStageManagerClass = preload("res://src/systems/combat/StormStageManager.gd")
const RescueMissionManagerClass = preload("res://src/systems/combat/RescueMissionManager.gd")


# ===== COMPONENTS =====

var tile_grid: Node = null
var wave_manager: Node = null
var skill_system = null  # SkillSystem
var equipment_system = null  # EquipmentSystem
var damage_calculator = null  # DamageCalculator
var raven_system = null  # RavenSystem
var facility_bonus_manager = null  # FacilityBonusManager
var storm_stage_manager = null  # StormStageManager
var rescue_mission_manager = null  # RescueMissionManager


# ===== STATE =====

var is_paused: bool = false
var is_slow_motion: bool = false
var is_battle_active: bool = false
var is_evacuating: bool = false
var evac_timer: float = 0.0
var selected_squad: Node = null
var targeting_mode: String = ""  # "", "skill", "equipment", "raven"
var targeting_data: Dictionary = {}

const EVAC_DELAY: float = 5.0  # Raven 셔틀 도착까지 5초


# ===== ENTITIES =====

var crews: Array = []
var enemies: Array = []
var facilities: Array = []
var turrets: Array = []
var projectiles: Array = []


# ===== STATION DATA =====

var station_data: Variant = null


# ===== STATISTICS =====

var enemies_killed: int = 0
var current_wave: int = 0
var total_waves: int = 0


# ===== LIFECYCLE =====

func _ready() -> void:
	_setup_components()
	_connect_signals()


func _setup_components() -> void:
	# 컴포넌트 찾기 (여러 가능한 경로 시도)
	tile_grid = _find_node_recursive("TileGrid")
	wave_manager = _find_node_recursive("WaveManager")

	# 시스템 노드들 (Systems/ 하위 또는 직접 자식)
	skill_system = _find_or_create_system("SkillSystem", SkillSystemClass)
	equipment_system = _find_or_create_system("EquipmentSystem", EquipmentSystemClass)
	damage_calculator = _find_or_create_system("DamageCalculator", DamageCalculatorClass)
	raven_system = _find_or_create_system("RavenSystem", RavenSystemClass)
	facility_bonus_manager = _find_or_create_system("FacilityBonusManager", FacilityBonusManagerClass)
	storm_stage_manager = _find_or_create_system("StormStageManager", StormStageManagerClass)

	# 시스템 간 연결
	if damage_calculator and facility_bonus_manager:
		damage_calculator.facility_bonus_manager = facility_bonus_manager
	if raven_system and facility_bonus_manager:
		raven_system.facility_bonus_manager = facility_bonus_manager
	if storm_stage_manager and tile_grid:
		storm_stage_manager.initialize(tile_grid, self)
	if raven_system and storm_stage_manager:
		raven_system.storm_stage_manager = storm_stage_manager

	# RESCUE 미션 매니저
	rescue_mission_manager = _find_or_create_system("RescueMissionManager", RescueMissionManagerClass)
	if rescue_mission_manager:
		rescue_mission_manager.initialize(self)


func _find_node_recursive(node_name: String) -> Node:
	# 직접 자식
	var node := get_node_or_null(node_name)
	if node:
		return node

	# Systems/ 하위
	node = get_node_or_null("Systems/" + node_name)
	if node:
		return node

	# TileGridContainer/ 하위
	node = get_node_or_null("TileGridContainer/" + node_name)
	if node:
		return node

	return null


func _find_or_create_system(system_name: String, system_class: Variant) -> Node:
	# 직접 자식에서 찾기
	var system := get_node_or_null(system_name)
	if system:
		return system

	# Systems/ 하위에서 찾기
	system = get_node_or_null("Systems/" + system_name)
	if system:
		return system

	# 없으면 생성
	system = system_class.new()
	system.name = system_name

	# Systems 노드가 있으면 그 아래에, 없으면 직접 자식으로
	var systems_node := get_node_or_null("Systems")
	if systems_node:
		systems_node.add_child(system)
	else:
		add_child(system)

	return system


func _connect_signals() -> void:
	EventBus.entity_died.connect(_on_entity_died)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_ended.connect(_on_wave_ended)
	EventBus.all_waves_cleared.connect(_on_all_waves_cleared)
	EventBus.facility_destroyed.connect(_on_facility_destroyed)
	EventBus.turret_deployed.connect(_on_turret_deployed)
	EventBus.turret_destroyed.connect(_on_turret_destroyed)
	EventBus.crew_selected.connect(_on_external_crew_selected)
	EventBus.raven_ability_used.connect(_on_raven_ability_used)
	EventBus.orbital_strike_targeting_started.connect(_on_orbital_strike_targeting_started)


func _exit_tree() -> void:
	if EventBus:
		EventBus.entity_died.disconnect(_on_entity_died)
		EventBus.wave_started.disconnect(_on_wave_started)
		EventBus.wave_ended.disconnect(_on_wave_ended)
		EventBus.all_waves_cleared.disconnect(_on_all_waves_cleared)
		EventBus.facility_destroyed.disconnect(_on_facility_destroyed)
		EventBus.turret_deployed.disconnect(_on_turret_deployed)
		EventBus.turret_destroyed.disconnect(_on_turret_destroyed)
		EventBus.crew_selected.disconnect(_on_external_crew_selected)
		EventBus.raven_ability_used.disconnect(_on_raven_ability_used)
		EventBus.orbital_strike_targeting_started.disconnect(_on_orbital_strike_targeting_started)


func _process(delta: float) -> void:
	if not is_battle_active or is_paused:
		return

	var actual_delta := delta

	# Emergency Evac 처리
	if is_evacuating:
		_process_evac(actual_delta)
		return

	_process_combat(actual_delta)
	_check_battle_end()


func _input(event: InputEvent) -> void:
	if not is_battle_active:
		return

	# 일시정지
	if event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()
		return

	# 타겟팅 취소
	if event.is_action_pressed("ui_cancel") and targeting_mode != "":
		cancel_targeting()
		get_viewport().set_input_as_handled()
		return

	# 마우스 입력
	if event is InputEventMouseButton:
		_handle_mouse_input(event)


# ===== BATTLE LIFECYCLE =====

## 전투 시작
func start_battle(station: Variant, crew_data_list: Array) -> void:
	station_data = station
	is_battle_active = true
	enemies_killed = 0

	# 기존 엔티티 초기화
	_clear_entities()

	# 그리드 초기화
	if tile_grid and tile_grid.has_method("initialize_from_station_data"):
		tile_grid.initialize_from_station_data(station)

	# 시설 생성
	_spawn_facilities(station)

	# 크루 생성
	_spawn_crews(crew_data_list)

	# 장비 시스템 초기화
	for crew in crews:
		equipment_system.register_crew(crew)

	# 웨이브 매니저 설정
	if wave_manager and wave_manager.has_method("initialize"):
		wave_manager.initialize(station, GameState.current_difficulty)
		total_waves = wave_manager.get_total_waves() if wave_manager.has_method("get_total_waves") else 5

	battle_started.emit()
	EventBus.battle_started.emit()

	# 폭풍 스테이지 체크
	if _is_storm_station(station):
		if storm_stage_manager:
			storm_stage_manager.activate_storm_mode()

	# RESCUE 미션 체크
	if _is_rescue_station(station):
		if rescue_mission_manager:
			rescue_mission_manager.start_rescue_mission(station)

	# 첫 웨이브 시작
	if wave_manager and wave_manager.has_method("start_next_wave"):
		wave_manager.start_next_wave()


## 전투 종료
func end_battle(victory: bool) -> BattleResult:
	is_battle_active = false

	# 폭풍 모드 비활성화
	if storm_stage_manager:
		storm_stage_manager.deactivate_storm_mode()

	var result := BattleResult.new()
	result.victory = victory
	result.facilities_saved = _count_alive_facilities()
	result.facilities_total = facilities.size()
	result.enemies_killed = enemies_killed
	result.credits_earned = _calculate_credits_earned(result)
	result.crew_casualties = _get_crew_casualties()

	battle_ended.emit(result)
	EventBus.battle_ended.emit(victory)

	return result


func _clear_entities() -> void:
	for entity in crews + enemies + turrets + projectiles:
		if is_instance_valid(entity):
			entity.queue_free()

	crews.clear()
	enemies.clear()
	turrets.clear()
	projectiles.clear()


# ===== SPAWNING =====

func _spawn_facilities(station: Variant) -> void:
	if station == null:
		return

	var facility_placements: Array = []
	if station is Resource and "facilities" in station:
		facility_placements = station.facilities
	elif station is Dictionary:
		facility_placements = station.get("facilities", [])

	# Facility 씬 로드 시도
	var facility_scene: PackedScene = null
	if ResourceLoader.exists("res://src/entities/facility/Facility.tscn"):
		facility_scene = load("res://src/entities/facility/Facility.tscn")

	for placement in facility_placements:
		var position: Vector2i
		var data: Variant = null

		if placement is Dictionary:
			position = placement.get("position", Vector2i.ZERO)
			data = placement.get("data")
		elif "position" in placement:
			position = placement.position
			data = placement.data if "data" in placement else null

		if facility_scene:
			var facility := facility_scene.instantiate()
			if facility.has_method("initialize"):
				facility.initialize(data, position)
			facility.tile_position = position
			facility.global_position = _tile_to_world(position)
			add_child(facility)
			facilities.append(facility)
			facility.add_to_group("facilities")
		else:
			# 씬 없으면 더미 데이터만 저장
			facilities.append({"position": position, "data": data, "is_alive": true})

	# 시설 보너스 매니저 초기화
	if facility_bonus_manager:
		facility_bonus_manager.set_facilities(facilities)


func _spawn_crews(crew_data_list: Array) -> void:
	var start_positions := _get_crew_start_positions(crew_data_list.size())

	# CrewSquad 씬 로드 시도
	var squad_scene: PackedScene = null
	if ResourceLoader.exists("res://src/entities/crew/CrewSquad.tscn"):
		squad_scene = load("res://src/entities/crew/CrewSquad.tscn")

	for i in range(crew_data_list.size()):
		var crew_data = crew_data_list[i]
		var pos: Vector2i = start_positions[i] if i < start_positions.size() else Vector2i(5 + i, 5)

		if squad_scene:
			var squad := squad_scene.instantiate()
			if "crew_data" in squad:
				squad.crew_data = crew_data
			if squad.has_method("initialize"):
				squad.initialize(crew_data)
			squad.tile_position = pos
			squad.global_position = _tile_to_world(pos)
			add_child(squad)
			crews.append(squad)
			squad.add_to_group("crews")
		else:
			# 씬 없으면 더미 노드 생성
			var dummy := Node2D.new()
			dummy.name = "CrewSquad_%d" % i
			dummy.set_meta("crew_data", crew_data)
			dummy.set("tile_position", pos)
			dummy.set("is_alive", true)
			dummy.set("current_hp", 100)
			dummy.set("max_hp", 100)
			dummy.global_position = _tile_to_world(pos)
			add_child(dummy)
			crews.append(dummy)
			dummy.add_to_group("crews")


func _get_crew_start_positions(count: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []

	if tile_grid == null:
		# 기본 위치
		for i in range(count):
			result.append(Vector2i(5 + i * 2, 5))
		return result

	# 중앙 위치
	var center := Vector2i(10, 7)
	if "width" in tile_grid and "height" in tile_grid:
		center = Vector2i(tile_grid.width / 2, tile_grid.height / 2)

	# 이동 가능한 타일 찾기
	if tile_grid.has_method("get_reachable_tiles"):
		var candidates: Array = tile_grid.get_reachable_tiles(center, 5)
		for i in range(mini(count, candidates.size())):
			result.append(candidates[i])
	else:
		# 기본: 중앙 주변
		for i in range(count):
			var offset := Vector2i((i % 3) - 1, (i / 3) - 1)
			result.append(center + offset)

	return result


# ===== COMBAT PROCESSING =====

func _process_combat(_delta: float) -> void:
	# 크루 자동 전투 처리
	for crew in crews:
		if _is_crew_alive(crew) and _is_in_combat(crew):
			_process_crew_combat(crew)


func _process_crew_combat(crew: Node) -> void:
	# 타겟 없으면 새 타겟 찾기
	var current_target = crew.get("current_target") if "current_target" in crew else null
	if current_target == null or not _is_entity_alive(current_target):
		var new_target := _find_nearest_enemy(crew)
		if crew.has_method("set_target"):
			crew.set_target(new_target)
		elif "current_target" in crew:
			crew.current_target = new_target


func _find_nearest_enemy(crew: Node) -> Node:
	var nearest: Node = null
	var nearest_dist := INF

	for enemy in enemies:
		if _is_entity_alive(enemy):
			var dist: float = crew.global_position.distance_to(enemy.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = enemy

	return nearest


# ===== INPUT HANDLING =====

func _handle_mouse_input(event: InputEventMouseButton) -> void:
	var world_pos := _get_world_mouse_position()
	var tile_pos := _world_to_tile(world_pos)

	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if targeting_mode != "":
			_execute_targeting(tile_pos)
		else:
			_handle_selection(tile_pos)

	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if selected_squad and targeting_mode == "":
			_handle_command(tile_pos)


func _handle_selection(tile_pos: Vector2i) -> void:
	# 해당 타일의 크루 선택
	for crew in crews:
		if _is_crew_alive(crew):
			var crew_tile: Vector2i = crew.tile_position if "tile_position" in crew else Vector2i.ZERO
			if crew_tile == tile_pos:
				select_squad(crew)
				return

	# 빈 공간 클릭 = 선택 해제
	deselect_squad()


func _handle_command(tile_pos: Vector2i) -> void:
	if selected_squad == null:
		return

	# 적이 있으면 공격 명령
	var occupant := _get_occupant(tile_pos)
	if occupant and _is_enemy(occupant) and _is_entity_alive(occupant):
		if selected_squad.has_method("command_attack"):
			selected_squad.command_attack(occupant)
		EventBus.move_command_issued.emit(selected_squad, tile_pos)
		return

	# 시설이 있으면 회복 명령
	var facility: Variant = _get_facility_at(tile_pos)
	if facility and _is_facility_alive(facility):
		if selected_squad.has_method("start_recovery"):
			selected_squad.start_recovery(facility)
		return

	# 이동 명령
	if tile_grid and tile_grid.has_method("find_path"):
		var crew_pos: Vector2i = selected_squad.tile_position if "tile_position" in selected_squad else Vector2i.ZERO
		var path: Array = tile_grid.find_path(crew_pos, tile_pos)
		if not path.is_empty():
			if selected_squad.has_method("command_move"):
				selected_squad.command_move(tile_pos, path)
			else:
				# 직접 이동
				selected_squad.tile_position = tile_pos
				selected_squad.global_position = _tile_to_world(tile_pos)
			EventBus.move_command_issued.emit(selected_squad, tile_pos)
	else:
		# 경로탐색 없이 직접 이동
		if selected_squad.has_method("command_move"):
			selected_squad.command_move(tile_pos, [tile_pos])
		else:
			selected_squad.tile_position = tile_pos
			selected_squad.global_position = _tile_to_world(tile_pos)
		EventBus.move_command_issued.emit(selected_squad, tile_pos)


# ===== SELECTION =====

func select_squad(squad: Node) -> void:
	if selected_squad != squad:
		selected_squad = squad
		selection_changed.emit(squad)
		EventBus.crew_selected.emit(squad)

		# 슬로우 모션 활성화
		if enable_auto_slow_on_select:
			set_slow_motion(true)


func deselect_squad() -> void:
	if selected_squad != null:
		selected_squad = null
		selection_changed.emit(null)
		EventBus.crew_deselected.emit()

		# 슬로우 모션 해제
		set_slow_motion(false)


# ===== TARGETING =====

## 스킬 타겟팅 시작
func start_skill_targeting(crew: Node, skill_id: String) -> void:
	targeting_mode = "skill"
	targeting_data = {"crew": crew, "skill_id": skill_id}
	EventBus.skill_targeting_started.emit(crew, skill_id)


## 장비 타겟팅 시작
func start_equipment_targeting(crew: Node) -> void:
	targeting_mode = "equipment"
	targeting_data = {"crew": crew}


## Raven 타겟팅 시작
func start_raven_targeting(ability: Constants.RavenAbility) -> void:
	targeting_mode = "raven"
	targeting_data = {"ability": ability}
	raven_system.start_targeting(ability)


## 타겟팅 취소
func cancel_targeting() -> void:
	if targeting_mode == "raven":
		raven_system.cancel_targeting()

	targeting_mode = ""
	targeting_data = {}
	EventBus.skill_targeting_ended.emit()


func _execute_targeting(tile_pos: Vector2i) -> void:
	match targeting_mode:
		"skill":
			var crew = targeting_data.get("crew")
			var skill_id: String = targeting_data.get("skill_id", "")
			if crew and skill_id != "":
				skill_system.execute_skill(crew, skill_id, tile_pos)

		"equipment":
			var crew = targeting_data.get("crew")
			if crew:
				equipment_system.execute_equipment(crew, tile_pos)

		"raven":
			raven_system.confirm_targeting(tile_pos)

	cancel_targeting()


# ===== PAUSE / SLOW MOTION =====

func toggle_pause() -> void:
	is_paused = not is_paused
	pause_state_changed.emit(is_paused)

	if is_paused:
		EventBus.game_paused.emit()
	else:
		EventBus.game_resumed.emit()


func set_slow_motion(enabled: bool) -> void:
	if is_slow_motion != enabled:
		is_slow_motion = enabled
		slow_motion_changed.emit(enabled)

		if enabled:
			EventBus.slow_motion_started.emit()
		else:
			EventBus.slow_motion_ended.emit()


# ===== EVENT HANDLERS =====

func _on_entity_died(entity: Node) -> void:
	if entity in enemies:
		enemies.erase(entity)
		enemies_killed += 1


func _on_wave_started(wave_num: int, _total: int, _preview: Array) -> void:
	if wave_num >= 0:  # -1은 프리뷰
		current_wave = wave_num
		wave_progress_changed.emit(current_wave, total_waves)


func _on_wave_ended(_wave_num: int) -> void:
	pass


func _on_all_waves_cleared() -> void:
	end_battle(true)


func _on_facility_destroyed(facility: Node) -> void:
	# 시설 보너스 재계산
	if facility_bonus_manager:
		facility_bonus_manager.remove_facility(facility)

	# 해당 시설에서 회복 중인 크루 영구 손실 처리 (Bad North 규칙)
	for crew in crews:
		if not _is_crew_alive(crew):
			continue
		if crew.has_method("get_recovery_facility"):
			var recovery_facility = crew.get_recovery_facility()
			if recovery_facility == facility:
				crew.on_recovery_facility_destroyed()


func _on_turret_deployed(turret: Node, _pos: Vector2i) -> void:
	if turret not in turrets:
		turrets.append(turret)


func _on_turret_destroyed(turret: Node) -> void:
	turrets.erase(turret)


func _on_external_crew_selected(crew: Node) -> void:
	# 외부에서 크루가 선택된 경우 (HUD 등)
	if crew != selected_squad:
		selected_squad = crew
		if enable_auto_slow_on_select:
			set_slow_motion(true)


## 적 등록 (WaveManager에서 호출)
func register_enemy(enemy: Node) -> void:
	if enemy not in enemies:
		enemies.append(enemy)
		enemy.add_to_group("enemies")


## 투사체 등록
func register_projectile(proj: Node) -> void:
	if proj not in projectiles:
		projectiles.append(proj)


func unregister_projectile(proj: Node) -> void:
	projectiles.erase(proj)


# ===== EMERGENCY EVAC =====

## 긴급 귀환 시작 (Raven 셔틀 호출)
func start_emergency_evac() -> bool:
	if is_evacuating:
		return false

	if not is_battle_active:
		return false

	# 살아있는 크루가 있어야 귀환 가능
	var alive_crews := crews.filter(func(c): return _is_crew_alive(c))
	if alive_crews.is_empty():
		return false

	is_evacuating = true
	evac_timer = EVAC_DELAY

	emergency_evac_started.emit()
	EventBus.emergency_evac_started.emit()
	EventBus.show_toast.emit("Raven: 긴급 귀환 셔틀 발진! %.0f초 후 도착" % EVAC_DELAY, Constants.ToastType.WARNING, 3.0)

	return true


func _process_evac(delta: float) -> void:
	evac_timer -= delta

	# 진행률 이벤트
	var progress: float = 1.0 - (evac_timer / EVAC_DELAY)
	EventBus.emergency_evac_progress.emit(progress)

	if evac_timer <= 0:
		_complete_evac()


func _complete_evac() -> void:
	is_evacuating = false

	# 귀환 완료 - 크레딧 0, 크루 생존
	var result := BattleResult.new()
	result.victory = true  # 생존으로 취급
	result.facilities_saved = 0
	result.facilities_total = facilities.size()
	result.enemies_killed = enemies_killed
	result.credits_earned = 0  # 긴급 귀환 = 크레딧 없음
	result.crew_casualties = []

	is_battle_active = false

	emergency_evac_completed.emit()
	EventBus.emergency_evac_completed.emit()
	EventBus.show_toast.emit("Raven: 귀환 완료. 크레딧 획득 없음.", Constants.ToastType.INFO, 3.0)

	battle_ended.emit(result)
	EventBus.battle_ended.emit(true)


## 긴급 귀환 취소 (셔틀 도착 전에만 가능)
func cancel_emergency_evac() -> bool:
	if not is_evacuating:
		return false

	is_evacuating = false
	evac_timer = 0.0

	EventBus.show_toast.emit("긴급 귀환 취소됨", Constants.ToastType.INFO, 2.0)

	return true


# ===== BATTLE END CONDITIONS =====

func _check_battle_end() -> void:
	# 귀환 중에는 체크 안 함
	if is_evacuating:
		return

	# 모든 크루 전멸 = 게임 오버
	var alive_crews := crews.filter(func(c): return _is_crew_alive(c))
	if alive_crews.is_empty():
		end_battle(false)


# ===== UTILITIES =====

func _count_alive_facilities() -> int:
	return facilities.filter(func(f): return _is_facility_alive(f)).size()


func _calculate_credits_earned(result: BattleResult) -> int:
	var credits := 0

	for facility in facilities:
		if _is_facility_alive(facility):
			var fac_data = _get_facility_data(facility)
			if fac_data:
				credits += fac_data.get("credits", 3) if fac_data is Dictionary else (fac_data.credits if "credits" in fac_data else 3)

	# 완벽 방어 보너스
	if result.facilities_saved == result.facilities_total and result.facilities_total > 0:
		credits += 2

	# Salvage Core 보너스
	for crew in crews:
		var equip_id := _get_equipment_id(crew)
		if equip_id == "salvage_core":
			var level := _get_equipment_level(crew)
			credits += [1, 2, 3][clampi(level, 0, 2)]

	# 난이도 크레딧 배율 적용
	var credit_mult := Constants.get_credit_multiplier(GameState.current_difficulty)
	credits = int(float(credits) * credit_mult)

	return credits


func _get_crew_casualties() -> Array[String]:
	var result: Array[String] = []
	for crew in crews:
		if not _is_crew_alive(crew):
			var crew_id: String = ""
			if "entity_id" in crew:
				crew_id = crew.entity_id
			elif "crew_data" in crew:
				var data = crew.crew_data
				crew_id = data.id if data is Resource and "id" in data else data.get("id", "")
			if crew_id != "":
				result.append(crew_id)
	return result


func _is_crew_alive(crew: Node) -> bool:
	if not is_instance_valid(crew):
		return false
	if "is_alive" in crew:
		return crew.is_alive
	return true


func _is_entity_alive(entity: Node) -> bool:
	if not is_instance_valid(entity):
		return false
	if "is_alive" in entity:
		return entity.is_alive
	return true


func _is_facility_alive(facility: Variant) -> bool:
	if facility is Dictionary:
		return facility.get("is_alive", true)
	if facility is Node:
		if "is_alive" in facility:
			return facility.is_alive
	return true


func _is_enemy(entity: Node) -> bool:
	if "team" in entity:
		return entity.team == 1
	return entity.is_in_group("enemies")


func _is_in_combat(entity: Node) -> bool:
	if "is_in_combat" in entity:
		return entity.is_in_combat
	return false


func _is_storm_station(station: Variant) -> bool:
	## 폭풍 스테이지인지 확인
	if station == null:
		return false

	# Resource 타입 체크
	if station is Resource:
		if "is_storm" in station and station.is_storm:
			return true
		if "node_type" in station:
			return station.node_type == Constants.NodeType.STORM

	# Dictionary 타입 체크
	if station is Dictionary:
		if station.get("is_storm", false):
			return true
		if station.get("node_type", -1) == Constants.NodeType.STORM:
			return true

	return false


func _is_rescue_station(station: Variant) -> bool:
	## RESCUE 스테이지인지 확인
	if station == null:
		return false

	# Resource 타입 체크
	if station is Resource:
		if "node_type" in station:
			return station.node_type == Constants.NodeType.RESCUE

	# Dictionary 타입 체크
	if station is Dictionary:
		if station.get("node_type", -1) == Constants.NodeType.RESCUE:
			return true

	return false


func _get_occupant(tile_pos: Vector2i) -> Node:
	if tile_grid and tile_grid.has_method("get_occupant"):
		return tile_grid.get_occupant(tile_pos)
	return null


func _get_facility_at(tile_pos: Vector2i) -> Variant:
	for facility in facilities:
		var fac_pos: Vector2i = Vector2i.ZERO
		if facility is Dictionary:
			fac_pos = facility.get("position", Vector2i.ZERO)
		elif "tile_position" in facility:
			fac_pos = facility.tile_position
		if fac_pos == tile_pos:
			return facility
	return null


func _get_facility_data(facility: Variant) -> Variant:
	if facility is Dictionary:
		return facility.get("data")
	if facility is Node and "facility_data" in facility:
		return facility.facility_data
	return null


func _get_equipment_id(crew: Node) -> String:
	if not "crew_data" in crew:
		return ""
	var crew_data = crew.crew_data
	if crew_data is Resource:
		return crew_data.equipment_id if "equipment_id" in crew_data else ""
	elif crew_data is Dictionary:
		return crew_data.get("equipment_id", "")
	return ""


func _get_equipment_level(crew: Node) -> int:
	if not "crew_data" in crew:
		return 0
	var crew_data = crew.crew_data
	if crew_data is Resource:
		return crew_data.equipment_level if "equipment_level" in crew_data else 0
	elif crew_data is Dictionary:
		return crew_data.get("equipment_level", 0)
	return 0


func _tile_to_world(tile_pos: Vector2i) -> Vector2:
	if tile_grid and tile_grid.has_method("tile_to_world"):
		return tile_grid.tile_to_world(tile_pos)
	return Vector2(
		tile_pos.x * Constants.TILE_SIZE + Constants.TILE_SIZE_HALF,
		tile_pos.y * Constants.TILE_SIZE + Constants.TILE_SIZE_HALF
	)


func _world_to_tile(world_pos: Vector2) -> Vector2i:
	if tile_grid and tile_grid.has_method("world_to_tile"):
		return tile_grid.world_to_tile(world_pos)
	return Vector2i(
		int(world_pos.x / Constants.TILE_SIZE),
		int(world_pos.y / Constants.TILE_SIZE)
	)


func _get_world_mouse_position() -> Vector2:
	return get_viewport().get_mouse_position()


## TileGrid 접근자 (다른 시스템에서 사용)
func get_tile_grid() -> Node:
	return tile_grid


# ===== RAVEN ABILITY HANDLERS =====

## Raven 능력 사용 요청 (RavenPanel에서 호출)
func _on_raven_ability_used(ability: int) -> void:
	if raven_system == null:
		push_warning("BattleController: RavenSystem not initialized")
		return

	# Scout은 타겟팅 없이 즉시 실행
	if ability == Constants.RavenAbility.SCOUT:
		raven_system.execute_ability(ability)
	else:
		# Flare, Resupply, Orbital Strike는 타겟팅 필요
		start_raven_targeting(ability)


## Orbital Strike 타겟팅 시작 (RavenPanel에서 직접 호출 시)
func _on_orbital_strike_targeting_started() -> void:
	start_raven_targeting(Constants.RavenAbility.ORBITAL_STRIKE)
