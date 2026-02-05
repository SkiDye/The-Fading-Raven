extends Node

## 전역 게임 상태 관리
## 런 상태, 크루 관리, 세이브/로드
## S03에서 상세 구현 예정


# ===== SIGNALS =====

signal run_started(seed_value: int)
signal run_ended(victory: bool)
signal stage_started(station_id: String)
signal stage_ended(result: Variant)
signal crew_added(crew: Variant)
signal crew_removed(crew_id: String)
signal credits_changed(old_amount: int, new_amount: int)
signal difficulty_changed(difficulty: int)
signal raven_charges_changed(ability: int, charges: int)
signal achievement_unlocked(achievement_id: String)
signal class_unlocked(class_id: String)
signal equipment_unlocked(equipment_id: String)
signal trait_unlocked(trait_id: String)
signal difficulty_unlocked(difficulty: int)


# ===== CURRENT STATE =====

var current_seed: int = 0
var current_difficulty: int = Constants.Difficulty.NORMAL
var is_paused: bool = false

# 씬 전환 데이터
var current_station: Dictionary = {}  # 현재 스테이션 데이터
var current_node_id: String = ""      # 현재 선택된 노드 ID
var battle_squads: Array = []         # 전투에 투입할 분대
var current_station_layout: Variant = null  # StationLayout - 프리뷰↔전투 공유
var battle_result: Dictionary = {}         # 전투 결과 데이터
var sector_data: Dictionary = {}           # 섹터맵 데이터 (노드, 연결 등)


# ===== META PROGRESSION =====
## 런 간 영구 저장되는 데이터

const META_SAVE_PATH: String = "user://meta.json"
const META_VERSION: int = 1

var meta_data: Dictionary = {
	"unlocked_classes": ["guardian", "sentinel"],  # 시작 해금
	"unlocked_equipment": [],
	"unlocked_traits": [],
	"unlocked_difficulties": [Constants.Difficulty.NORMAL],  # NORMAL은 기본 해금
	"achievements": {},  # achievement_id -> timestamp
	"lifetime_stats": {
		"total_runs": 0,
		"victories": 0,
		"enemies_killed": 0,
		"facilities_saved": 0,
		"facilities_lost": 0,
		"total_credits_earned": 0,
		"highest_depth": 0
	}
}


# ===== RUN DATA =====
## S03에서 RunData 클래스로 대체 예정

var current_run: Dictionary = {}
var current_stage: Dictionary = {}


func _ready() -> void:
	_load_meta_data()


# ===== RUN MANAGEMENT =====

func start_new_run(seed_value: int = -1, difficulty: int = Constants.Difficulty.NORMAL) -> void:
	if seed_value == -1:
		seed_value = randi()

	current_seed = seed_value
	current_difficulty = difficulty

	# 난이도별 Raven 충전량 가져오기
	var raven_charges := {
		Constants.RavenAbility.SCOUT: Constants.get_raven_charges_for_difficulty(Constants.RavenAbility.SCOUT, difficulty),
		Constants.RavenAbility.FLARE: Constants.get_raven_charges_for_difficulty(Constants.RavenAbility.FLARE, difficulty),
		Constants.RavenAbility.RESUPPLY: Constants.get_raven_charges_for_difficulty(Constants.RavenAbility.RESUPPLY, difficulty),
		Constants.RavenAbility.ORBITAL_STRIKE: Constants.get_raven_charges_for_difficulty(Constants.RavenAbility.ORBITAL_STRIKE, difficulty)
	}

	current_run = {
		"seed": seed_value,
		"difficulty": difficulty,
		"credits": 100,
		"crews": [],
		"current_depth": 0,
		"raven_charges": raven_charges,
		"statistics": {
			"enemies_killed": 0,
			"facilities_saved": 0,
			"facilities_lost": 0,
			"stages_completed": 0,
			"damage_dealt": 0,
			"damage_taken": 0
		}
	}

	run_started.emit(seed_value)


func end_run(victory: bool) -> void:
	# 메타 데이터 업데이트 (current_run 클리어 전에 호출)
	_update_meta_on_run_end(victory)

	run_ended.emit(victory)
	current_run = {}
	current_stage = {}


func is_run_active() -> bool:
	return not current_run.is_empty()


# ===== CREDITS =====

func get_credits() -> int:
	if current_run.is_empty():
		return 0
	return current_run.get("credits", 0)


func add_credits(amount: int) -> void:
	if current_run.is_empty() or amount <= 0:
		return
	var old_amount: int = current_run.credits
	current_run.credits += amount
	credits_changed.emit(old_amount, current_run.credits)


func spend_credits(amount: int) -> bool:
	if current_run.is_empty() or amount <= 0:
		return false
	if current_run.credits < amount:
		return false
	var old_amount: int = current_run.credits
	current_run.credits -= amount
	credits_changed.emit(old_amount, current_run.credits)
	return true


# ===== RAVEN =====

func get_raven_charges(ability: int) -> int:
	if current_run.is_empty():
		return 0
	return current_run.raven_charges.get(ability, 0)


func use_raven_ability(ability: int) -> bool:
	if current_run.is_empty():
		return false

	var charges: int = get_raven_charges(ability)
	if charges == 0:
		return false

	if charges > 0:  # -1은 무제한
		current_run.raven_charges[ability] = charges - 1

	EventBus.raven_ability_used.emit(ability)
	raven_charges_changed.emit(ability, current_run.raven_charges[ability])
	return true


func add_raven_charges(ability: int, amount: int) -> void:
	if current_run.is_empty():
		return
	if ability == Constants.RavenAbility.SCOUT:
		return  # Scout은 무제한
	current_run.raven_charges[ability] = current_run.raven_charges.get(ability, 0) + amount
	raven_charges_changed.emit(ability, current_run.raven_charges[ability])


# ===== CREW MANAGEMENT =====
## S03에서 상세 구현 예정

func get_crews() -> Array:
	if current_run.is_empty():
		return []
	return current_run.get("crews", [])


func get_crew(crew_id: String) -> Variant:
	for crew in get_crews():
		if crew.get("id") == crew_id:
			return crew
	return null


func add_crew(crew_data: Dictionary) -> void:
	if current_run.is_empty():
		return
	current_run.crews.append(crew_data)
	crew_added.emit(crew_data)


func remove_crew(crew_id: String) -> void:
	if current_run.is_empty():
		return
	for i in range(current_run.crews.size()):
		if current_run.crews[i].get("id") == crew_id:
			current_run.crews.remove_at(i)
			crew_removed.emit(crew_id)
			return


# ===== STAGE MANAGEMENT =====

func start_stage(station_id: String) -> void:
	if current_run.is_empty():
		push_warning("GameState.start_stage: No active run")
		return

	current_stage = {
		"station_id": station_id,
		"start_time": Time.get_unix_time_from_system(),
		"enemies_killed": 0,
		"damage_dealt": 0,
		"damage_taken": 0,
		"facilities_saved": 0,
		"facilities_lost": 0
	}

	stage_started.emit(station_id)


func end_stage(result: Dictionary) -> void:
	if current_run.is_empty():
		push_warning("GameState.end_stage: No active run")
		return

	if current_stage.is_empty():
		push_warning("GameState.end_stage: No active stage")
		return

	# 통계 업데이트
	current_run.statistics.enemies_killed += result.get("enemies_killed", 0)
	current_run.statistics.damage_dealt += result.get("damage_dealt", 0)
	current_run.statistics.damage_taken += result.get("damage_taken", 0)
	current_run.statistics.facilities_saved += result.get("facilities_saved", 0)
	current_run.statistics.facilities_lost += result.get("facilities_lost", 0)
	current_run.statistics.stages_completed += 1

	# 보상 적용
	var credits_earned: int = result.get("credits_earned", 0)
	if credits_earned > 0:
		add_credits(credits_earned)

	# 크루 상태 업데이트 (체력 등)
	var crew_results: Array = result.get("crew_results", [])
	for crew_result in crew_results:
		var crew_id: String = crew_result.get("id", "")
		var crew: Variant = get_crew(crew_id)
		if crew != null:
			crew.current_hp = crew_result.get("current_hp", crew.current_hp)
			crew.current_squad_size = crew_result.get("current_squad_size", crew.current_squad_size)
			if crew_result.get("is_dead", false):
				crew.is_dead = true

	var stage_result: Dictionary = current_stage.duplicate()
	stage_result.merge(result, true)

	current_stage = {}
	stage_ended.emit(stage_result)


# ===== CREW UPGRADES =====

func upgrade_crew_rank(crew_id: String) -> bool:
	if current_run.is_empty():
		return false

	var crew: Variant = get_crew(crew_id)
	if crew == null:
		return false

	var current_rank: int = crew.get("class_rank", 1)
	if current_rank >= 4:
		return false  # 최대 랭크

	var upgrade_costs: Array = Constants.BALANCE.upgrade_costs.class_rank
	var cost_index: int = current_rank - 1
	if cost_index < 0 or cost_index >= upgrade_costs.size():
		return false

	var cost: int = upgrade_costs[cost_index]
	if not spend_credits(cost):
		return false

	crew.class_rank = current_rank + 1
	return true


func upgrade_crew_skill(crew_id: String) -> bool:
	if current_run.is_empty():
		return false

	var crew: Variant = get_crew(crew_id)
	if crew == null:
		return false

	var current_skill_level: int = crew.get("skill_level", 1)
	if current_skill_level >= 4:
		return false  # 최대 스킬 레벨

	var upgrade_costs: Array = Constants.BALANCE.upgrade_costs.skill_level
	var cost_index: int = current_skill_level - 1
	if cost_index < 0 or cost_index >= upgrade_costs.size():
		return false

	var cost: int = upgrade_costs[cost_index]
	if not spend_credits(cost):
		return false

	crew.skill_level = current_skill_level + 1
	return true


func get_alive_crews() -> Array:
	var alive: Array = []
	for crew in get_crews():
		if not crew.get("is_dead", false):
			alive.append(crew)
	return alive


# ===== SAVE/LOAD =====

const SAVE_PATH: String = "user://savegame.json"
const SAVE_VERSION: int = 1

func save_game() -> bool:
	if current_run.is_empty():
		push_warning("GameState.save_game: No active run to save")
		return false

	var save_data: Dictionary = {
		"version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"current_seed": current_seed,
		"current_difficulty": current_difficulty,
		"current_run": _serialize_run_data(current_run),
		"current_stage": current_stage
	}

	var json_string: String = JSON.stringify(save_data, "\t")

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("GameState.save_game: Failed to open file - %s" % FileAccess.get_open_error())
		return false

	file.store_string(json_string)
	file.close()

	print("[GameState] Game saved successfully")
	return true


func load_game() -> bool:
	if not has_save_game():
		push_warning("GameState.load_game: No save file found")
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("GameState.load_game: Failed to open file - %s" % FileAccess.get_open_error())
		return false

	var json_string: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		push_error("GameState.load_game: JSON parse error at line %d - %s" % [json.get_error_line(), json.get_error_message()])
		return false

	var save_data: Dictionary = json.data
	if not save_data is Dictionary:
		push_error("GameState.load_game: Invalid save data format")
		return false

	var version: int = save_data.get("version", 0)
	if version != SAVE_VERSION:
		push_warning("GameState.load_game: Save version mismatch (expected %d, got %d)" % [SAVE_VERSION, version])
		# 향후 마이그레이션 로직 추가 가능

	current_seed = int(save_data.get("current_seed", 0))
	current_difficulty = int(save_data.get("current_difficulty", Constants.Difficulty.NORMAL))
	current_run = _deserialize_run_data(save_data.get("current_run", {}))
	current_stage = save_data.get("current_stage", {})

	if not current_run.is_empty():
		run_started.emit(current_seed)

	print("[GameState] Game loaded successfully")
	return true


func has_save_game() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save_game() -> void:
	if has_save_game():
		DirAccess.remove_absolute(SAVE_PATH)
		print("[GameState] Save file deleted")


func _serialize_run_data(run_data: Dictionary) -> Dictionary:
	var serialized: Dictionary = run_data.duplicate(true)

	# RavenAbility enum 키를 문자열로 변환 (JSON 호환)
	if serialized.has("raven_charges"):
		var raven_charges: Dictionary = {}
		for key in serialized.raven_charges.keys():
			raven_charges[str(key)] = serialized.raven_charges[key]
		serialized.raven_charges = raven_charges

	return serialized


func _deserialize_run_data(save_data: Dictionary) -> Dictionary:
	if save_data.is_empty():
		return {}

	var run_data: Dictionary = save_data.duplicate(true)

	# 문자열 키를 정수로 복원 (RavenAbility enum)
	if run_data.has("raven_charges"):
		var raven_charges: Dictionary = {}
		for key in run_data.raven_charges.keys():
			raven_charges[int(key)] = int(run_data.raven_charges[key])
		run_data.raven_charges = raven_charges

	# 숫자 타입 보정 (JSON은 모든 숫자를 float로 파싱)
	if run_data.has("seed"):
		run_data.seed = int(run_data.seed)
	if run_data.has("difficulty"):
		run_data.difficulty = int(run_data.difficulty)
	if run_data.has("credits"):
		run_data.credits = int(run_data.credits)
	if run_data.has("current_depth"):
		run_data.current_depth = int(run_data.current_depth)

	# statistics 정수 보정
	if run_data.has("statistics"):
		for key in run_data.statistics.keys():
			run_data.statistics[key] = int(run_data.statistics[key])

	return run_data


# ===== META PROGRESSION =====

func _load_meta_data() -> void:
	if not FileAccess.file_exists(META_SAVE_PATH):
		print("[GameState] No meta save found, using defaults")
		return

	var file := FileAccess.open(META_SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("[GameState] Failed to open meta save")
		return

	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	file.close()

	if parse_result != OK:
		push_warning("[GameState] Meta save parse error")
		return

	var loaded: Dictionary = json.data
	if loaded.has("unlocked_classes"):
		meta_data.unlocked_classes = loaded.unlocked_classes
	if loaded.has("unlocked_equipment"):
		meta_data.unlocked_equipment = loaded.unlocked_equipment
	if loaded.has("unlocked_traits"):
		meta_data.unlocked_traits = loaded.unlocked_traits
	if loaded.has("unlocked_difficulties"):
		meta_data.unlocked_difficulties = loaded.unlocked_difficulties
	if loaded.has("achievements"):
		meta_data.achievements = loaded.achievements
	if loaded.has("lifetime_stats"):
		for key in loaded.lifetime_stats.keys():
			meta_data.lifetime_stats[key] = loaded.lifetime_stats[key]

	print("[GameState] Meta data loaded")


func _save_meta_data() -> void:
	var file := FileAccess.open(META_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[GameState] Failed to save meta data")
		return

	var save_data := {
		"version": META_VERSION,
		"unlocked_classes": meta_data.unlocked_classes,
		"unlocked_equipment": meta_data.unlocked_equipment,
		"unlocked_traits": meta_data.unlocked_traits,
		"unlocked_difficulties": meta_data.unlocked_difficulties,
		"achievements": meta_data.achievements,
		"lifetime_stats": meta_data.lifetime_stats
	}

	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	print("[GameState] Meta data saved")


## 런 종료 시 메타 데이터 업데이트
func _update_meta_on_run_end(victory: bool) -> void:
	meta_data.lifetime_stats.total_runs += 1

	if victory:
		meta_data.lifetime_stats.victories += 1

	# 런 통계 합산
	if current_run.has("statistics"):
		var stats: Dictionary = current_run.statistics
		meta_data.lifetime_stats.enemies_killed += stats.get("enemies_killed", 0)
		meta_data.lifetime_stats.facilities_saved += stats.get("facilities_saved", 0)
		meta_data.lifetime_stats.facilities_lost += stats.get("facilities_lost", 0)

	# 최대 깊이 갱신
	var depth: int = current_run.get("current_depth", 0)
	if depth > meta_data.lifetime_stats.highest_depth:
		meta_data.lifetime_stats.highest_depth = depth

	# 해금 조건 체크
	_check_unlocks(victory)

	# 메타 데이터 저장
	_save_meta_data()


## 해금 조건 체크
func _check_unlocks(victory: bool) -> void:
	# === 클래스 해금 ===
	# Ranger: 첫 승리
	if victory and not is_class_unlocked("ranger"):
		unlock_class("ranger")

	# Engineer: 5번 이상 런 완료 (승패 무관)
	if meta_data.lifetime_stats.total_runs >= 5 and not is_class_unlocked("engineer"):
		unlock_class("engineer")

	# Bionic: 적 100마리 처치
	if meta_data.lifetime_stats.enemies_killed >= 100 and not is_class_unlocked("bionic"):
		unlock_class("bionic")

	# === 난이도 해금 ===
	# HARD: 첫 승리
	if victory and not is_difficulty_unlocked(Constants.Difficulty.HARD):
		unlock_difficulty(Constants.Difficulty.HARD)

	# VERY_HARD: HARD 클리어
	if victory and current_difficulty >= Constants.Difficulty.HARD and not is_difficulty_unlocked(Constants.Difficulty.VERY_HARD):
		unlock_difficulty(Constants.Difficulty.VERY_HARD)

	# NIGHTMARE: VERY_HARD 클리어
	if victory and current_difficulty >= Constants.Difficulty.VERY_HARD and not is_difficulty_unlocked(Constants.Difficulty.NIGHTMARE):
		unlock_difficulty(Constants.Difficulty.NIGHTMARE)

	# === 업적 해금 ===
	_check_achievements(victory)


## 업적 체크
func _check_achievements(victory: bool) -> void:
	# 첫 승리
	if victory and not has_achievement("first_victory"):
		grant_achievement("first_victory")

	# 10번 클리어
	if meta_data.lifetime_stats.victories >= 10 and not has_achievement("veteran"):
		grant_achievement("veteran")

	# 적 500마리 처치
	if meta_data.lifetime_stats.enemies_killed >= 500 and not has_achievement("exterminator"):
		grant_achievement("exterminator")

	# 무손실 (시설 0 파괴)
	if victory and current_run.has("statistics"):
		if current_run.statistics.get("facilities_lost", 0) == 0:
			if not has_achievement("perfect_defense"):
				grant_achievement("perfect_defense")


# ===== UNLOCK METHODS =====

func is_class_unlocked(class_id: String) -> bool:
	return class_id in meta_data.unlocked_classes


func unlock_class(class_id: String) -> void:
	if not is_class_unlocked(class_id):
		meta_data.unlocked_classes.append(class_id)
		class_unlocked.emit(class_id)
		EventBus.class_unlocked.emit(class_id)
		EventBus.show_toast.emit("새 클래스 해금: %s" % class_id, Constants.ToastType.SUCCESS, 4.0)
		_save_meta_data()


func is_equipment_unlocked(equipment_id: String) -> bool:
	return equipment_id in meta_data.unlocked_equipment


func unlock_equipment(equipment_id: String) -> void:
	if not is_equipment_unlocked(equipment_id):
		meta_data.unlocked_equipment.append(equipment_id)
		equipment_unlocked.emit(equipment_id)
		EventBus.equipment_unlocked.emit(equipment_id)
		EventBus.show_toast.emit("새 장비 해금: %s" % equipment_id, Constants.ToastType.SUCCESS, 4.0)
		_save_meta_data()


func is_trait_unlocked(trait_id: String) -> bool:
	return trait_id in meta_data.unlocked_traits


func unlock_trait(trait_id: String) -> void:
	if not is_trait_unlocked(trait_id):
		meta_data.unlocked_traits.append(trait_id)
		trait_unlocked.emit(trait_id)
		EventBus.trait_unlocked.emit(trait_id)
		EventBus.show_toast.emit("새 특성 해금: %s" % trait_id, Constants.ToastType.SUCCESS, 4.0)
		_save_meta_data()


func is_difficulty_unlocked(difficulty: int) -> bool:
	return difficulty in meta_data.unlocked_difficulties


func unlock_difficulty(difficulty: int) -> void:
	if not is_difficulty_unlocked(difficulty):
		meta_data.unlocked_difficulties.append(difficulty)
		difficulty_unlocked.emit(difficulty)
		EventBus.difficulty_unlocked.emit(difficulty)
		var diff_name := Constants.get_difficulty_name_ko(difficulty)
		EventBus.show_toast.emit("새 난이도 해금: %s" % diff_name, Constants.ToastType.SUCCESS, 4.0)
		_save_meta_data()


func has_achievement(achievement_id: String) -> bool:
	return meta_data.achievements.has(achievement_id)


func grant_achievement(achievement_id: String) -> void:
	if not has_achievement(achievement_id):
		meta_data.achievements[achievement_id] = Time.get_unix_time_from_system()
		var achievement_name := _get_achievement_name(achievement_id)
		achievement_unlocked.emit(achievement_id)
		EventBus.achievement_unlocked.emit(achievement_id, achievement_name)
		EventBus.show_toast.emit("업적 달성: %s" % achievement_name, Constants.ToastType.SUCCESS, 4.0)
		_save_meta_data()


func _get_achievement_name(achievement_id: String) -> String:
	match achievement_id:
		"first_victory":
			return "첫 탈출"
		"veteran":
			return "베테랑 (10회 클리어)"
		"exterminator":
			return "말살자 (적 500 처치)"
		"perfect_defense":
			return "완벽한 방어"
		_:
			return achievement_id


func get_unlocked_classes() -> Array:
	return meta_data.unlocked_classes.duplicate()


func get_unlocked_equipment() -> Array:
	return meta_data.unlocked_equipment.duplicate()


func get_unlocked_traits() -> Array:
	return meta_data.unlocked_traits.duplicate()


func get_unlocked_difficulties() -> Array:
	return meta_data.unlocked_difficulties.duplicate()


func get_lifetime_stats() -> Dictionary:
	return meta_data.lifetime_stats.duplicate()


# ===== SCENE TRANSITION HELPERS =====

func set_current_station(station_data: Dictionary) -> void:
	current_station = station_data


func set_current_node_id(node_id: String) -> void:
	current_node_id = node_id


func get_current_node_id() -> String:
	return current_node_id


func clear_battle_data() -> void:
	current_station = {}
	current_node_id = ""
	battle_squads = []
	current_station_layout = null


func set_current_station_layout(layout: Variant) -> void:
	current_station_layout = layout


func get_current_station_layout() -> Variant:
	return current_station_layout


func set_battle_result(result: Dictionary) -> void:
	battle_result = result


func get_battle_result() -> Dictionary:
	return battle_result


func set_sector_data(data: Dictionary) -> void:
	sector_data = data


func get_sector_data() -> Dictionary:
	return sector_data
