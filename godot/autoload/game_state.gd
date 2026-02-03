## GameState - 게임 상태 관리
## 런 상태, 세이브/로드, 크레딧 관리
extends Node

const SAVE_PATH := "user://save_data.tres"
const SETTINGS_PATH := "user://settings.tres"
const PROGRESS_PATH := "user://progress.tres"

# 현재 런 데이터
var current_run: RunData = null

# 설정
var settings: Dictionary = {
	"difficulty": Balance.Difficulty.NORMAL,
	"game_speed": 1.0,
	"sound_volume": 70,
	"music_volume": 50,
	"show_tutorial": true,
	"screen_shake": true,
	"language": "ko",
}

# 메타 진행 (영구 저장)
var progress: Dictionary = {
	"highest_difficulty": Balance.Difficulty.NORMAL,
	"normal_cleared": false,
	"hard_cleared": false,
	"veryhard_cleared": false,
	"nightmare_cleared": false,
	"total_runs": 0,
	"total_victories": 0,
	"total_enemies_killed": 0,
	"total_stations_defended": 0,
	"unlocked_classes": ["guardian", "sentinel", "ranger"],
	"unlocked_equipment": ["shock_wave", "frag_grenade"],
	"achievements": [],
}

signal run_started(run_data: RunData)
signal run_ended(is_victory: bool)
signal credits_changed(new_amount: int)


func _ready() -> void:
	load_settings()
	load_progress()


# ===========================================
# 새 런 시작
# ===========================================

func start_new_run(seed_string: String, difficulty: Balance.Difficulty) -> RunData:
	# RNG 시드 설정
	RngManager.set_master_seed(seed_string)

	# 새 런 데이터 생성
	current_run = RunData.new()
	current_run.id = _generate_id()
	current_run.seed_string = seed_string
	current_run.difficulty = difficulty
	current_run.start_time = Time.get_unix_time_from_system()

	# 시작 크레딧
	current_run.credits = Balance.ECONOMY["starting_credits"]

	# 시작 크루 생성
	current_run.crews = _create_starting_crews()

	# Raven 능력 초기화
	current_run.raven_abilities = {
		"scout": Balance.RAVEN["scout_uses"],
		"flare": Balance.RAVEN["flare_uses"],
		"resupply": Balance.RAVEN["resupply_uses"],
		"orbital_strike": Balance.RAVEN["orbital_strike_uses"],
	}

	# 통계 초기화
	current_run.stats = {
		"stations_defended": 0,
		"stations_lost": 0,
		"enemies_killed": 0,
		"crews_lost": 0,
		"credits_earned": 0,
		"perfect_defenses": 0,
		"bosses_killed": 0,
		"turrets_built": 0,
		"skills_used": 0,
	}

	# 메타 진행 업데이트
	progress["total_runs"] += 1
	save_progress()

	run_started.emit(current_run)
	EventBus.run_started.emit(current_run)

	return current_run


func _create_starting_crews() -> Array[Dictionary]:
	var crews: Array[Dictionary] = []

	crews.append(_create_crew("Marcus", "guardian"))
	crews.append(_create_crew("Elena", "sentinel"))
	crews.append(_create_crew("Kai", "ranger"))

	return crews


func _create_crew(crew_name: String, class_id: String, trait_id: String = "") -> Dictionary:
	var class_data := DataRegistry.get_crew_class(class_id)

	if trait_id.is_empty():
		trait_id = DataRegistry.get_random_trait()

	return {
		"id": _generate_id(),
		"name": crew_name,
		"class_id": class_id,
		"rank": "standard",  # standard, veteran, elite
		"trait_id": trait_id,
		"skill_level": 0,  # 0-3
		"equipment_id": "",
		"equipment_level": 0,

		# 현재 상태
		"squad_size": class_data.get("base_squad_size", 8),
		"max_squad_size": class_data.get("base_squad_size", 8),
		"is_alive": true,
		"is_deployed": false,

		# 전투 상태 (스테이지마다 리셋)
		"skill_cooldown": 0.0,
		"charges_used": {},

		# 통계
		"kills": 0,
		"battles_participated": 0,
		"damage_dealt": 0,
		"damage_taken": 0,
	}


# ===========================================
# 런 상태 관리
# ===========================================

func has_active_run() -> bool:
	return current_run != null and not current_run.is_complete


func get_current_run() -> RunData:
	return current_run


func end_run(is_victory: bool) -> void:
	if current_run == null:
		return

	current_run.is_complete = true
	current_run.is_victory = is_victory
	current_run.end_time = Time.get_unix_time_from_system()

	if is_victory:
		progress["total_victories"] += 1

		# 난이도 클리어 기록
		match current_run.difficulty:
			Balance.Difficulty.NORMAL:
				progress["normal_cleared"] = true
			Balance.Difficulty.HARD:
				progress["hard_cleared"] = true
			Balance.Difficulty.VERYHARD:
				progress["veryhard_cleared"] = true
			Balance.Difficulty.NIGHTMARE:
				progress["nightmare_cleared"] = true

		# 클래스 해금
		if current_run.difficulty == Balance.Difficulty.NORMAL:
			unlock_class("engineer")
		if current_run.difficulty == Balance.Difficulty.HARD:
			unlock_class("bionic")

		# 최고 난이도 업데이트
		if current_run.difficulty > progress["highest_difficulty"]:
			progress["highest_difficulty"] = current_run.difficulty

	save_progress()
	run_ended.emit(is_victory)
	EventBus.run_ended.emit(is_victory, current_run.stats)


# ===========================================
# 크레딧 관리
# ===========================================

func add_credits(amount: int) -> void:
	if current_run == null:
		return

	current_run.credits += amount
	current_run.stats["credits_earned"] += amount
	credits_changed.emit(current_run.credits)
	EventBus.credits_changed.emit(current_run.credits, amount)


func spend_credits(amount: int) -> bool:
	if current_run == null or current_run.credits < amount:
		return false

	current_run.credits -= amount
	credits_changed.emit(current_run.credits)
	EventBus.credits_changed.emit(current_run.credits, -amount)
	return true


func get_credits() -> int:
	return current_run.credits if current_run else 0


# ===========================================
# 크루 관리
# ===========================================

func get_alive_crews() -> Array[Dictionary]:
	if current_run == null:
		return []

	var alive: Array[Dictionary] = []
	for crew in current_run.crews:
		if crew["is_alive"]:
			alive.append(crew)
	return alive


func get_crew_by_id(crew_id: String) -> Dictionary:
	if current_run == null:
		return {}

	for crew in current_run.crews:
		if crew["id"] == crew_id:
			return crew
	return {}


func recruit_crew(crew_name: String, class_id: String, trait_id: String = "") -> Dictionary:
	if current_run == null:
		return {}

	var crew := _create_crew(crew_name, class_id, trait_id)
	current_run.crews.append(crew)
	save_run()

	EventBus.crew_recruited.emit(crew)
	return crew


func upgrade_crew_skill(crew_id: String) -> bool:
	var crew := get_crew_by_id(crew_id)
	if crew.is_empty() or crew["skill_level"] >= 3:
		return false

	var target_level := crew["skill_level"] + 1
	var has_skillful := crew["trait_id"] == "skillful"
	var cost := Balance.ECONOMY["skill_upgrade_costs"][target_level]
	if has_skillful:
		cost = int(cost * 0.5)

	if not spend_credits(cost):
		return false

	crew["skill_level"] = target_level
	save_run()

	EventBus.crew_skill_upgraded.emit(crew, target_level)
	return true


func rank_up_crew(crew_id: String) -> bool:
	var crew := get_crew_by_id(crew_id)
	if crew.is_empty() or crew["rank"] == "elite":
		return false

	var next_rank := "veteran" if crew["rank"] == "standard" else "elite"
	var cost: int = Balance.ECONOMY["rank_up_costs"][next_rank]

	if not spend_credits(cost):
		return false

	crew["rank"] = next_rank

	# 랭크 보너스 적용
	var bonus: Dictionary = Balance.ECONOMY["rank_bonuses"].get(next_rank, {})
	crew["max_squad_size"] += bonus.get("max_squad_bonus", 0)

	save_run()

	EventBus.crew_ranked_up.emit(crew, next_rank)
	return true


func heal_crew(crew_id: String) -> bool:
	var crew := get_crew_by_id(crew_id)
	if crew.is_empty() or not crew["is_alive"]:
		return false

	var cost: int = Balance.ECONOMY["heal_cost"]
	var amount: int = Balance.ECONOMY["heal_amount"]

	if not spend_credits(cost):
		return false

	crew["squad_size"] = mini(crew["squad_size"] + amount, crew["max_squad_size"])
	save_run()

	return true


func equip_item(crew_id: String, equipment_id: String) -> bool:
	var crew := get_crew_by_id(crew_id)
	if crew.is_empty() or not crew["equipment_id"].is_empty():
		return false  # 장비 교체 불가

	crew["equipment_id"] = equipment_id
	crew["equipment_level"] = 1
	save_run()

	EventBus.equipment_equipped.emit(crew, DataRegistry.get_equipment(equipment_id))
	return true


# ===========================================
# 전투 기록
# ===========================================

func record_station_defended(credits: int, is_perfect: bool = false) -> void:
	if current_run == null:
		return

	current_run.stats["stations_defended"] += 1
	if is_perfect:
		current_run.stats["perfect_defenses"] += 1

	add_credits(credits)
	progress["total_stations_defended"] += 1
	save_progress()
	save_run()


func record_enemies_killed(count: int) -> void:
	if current_run == null:
		return

	current_run.stats["enemies_killed"] += count
	progress["total_enemies_killed"] += count
	save_progress()
	save_run()


func record_crew_death(crew_id: String) -> void:
	var crew := get_crew_by_id(crew_id)
	if crew.is_empty():
		return

	crew["is_alive"] = false
	crew["squad_size"] = 0
	current_run.stats["crews_lost"] += 1
	save_run()

	EventBus.crew_wiped.emit(crew)


func advance_turn() -> void:
	if current_run == null:
		return

	current_run.turn += 1
	current_run.storm_line += 1

	# 스테이지별 상태 리셋
	current_run.active_turrets = []

	save_run()
	EventBus.turn_advanced.emit(current_run.turn)


# ===========================================
# 점수 계산
# ===========================================

func calculate_score() -> int:
	if current_run == null:
		return 0

	return Balance.calculate_final_score(current_run.stats, current_run.difficulty)


func get_run_duration() -> int:
	if current_run == null:
		return 0

	var end_time := current_run.end_time if current_run.end_time > 0 else Time.get_unix_time_from_system()
	return int(end_time - current_run.start_time)


# ===========================================
# 해금 관리
# ===========================================

func unlock_class(class_id: String) -> bool:
	if class_id in progress["unlocked_classes"]:
		return false

	progress["unlocked_classes"].append(class_id)
	save_progress()

	EventBus.class_unlocked.emit(class_id)
	return true


func is_class_unlocked(class_id: String) -> bool:
	return class_id in progress["unlocked_classes"]


func is_difficulty_unlocked(difficulty: Balance.Difficulty) -> bool:
	var config := Balance.get_difficulty_config(difficulty)
	var requirement: Variant = config.get("unlock_requirement")

	if requirement == null:
		return true

	return progress.get(requirement, false)


# ===========================================
# 세이브/로드
# ===========================================

func save_run() -> void:
	if current_run == null:
		return

	var save_data := {
		"run": current_run.serialize(),
		"version": 1,
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()


func load_run() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var save_data: Dictionary = file.get_var()
		file.close()

		if save_data.has("run"):
			current_run = RunData.new()
			current_run.deserialize(save_data["run"])


func clear_run() -> void:
	current_run = null
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_var(settings)
		file.close()


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return

	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file:
		var data: Variant = file.get_var()
		file.close()
		if data is Dictionary:
			for key in data:
				settings[key] = data[key]


func save_progress() -> void:
	var file := FileAccess.open(PROGRESS_PATH, FileAccess.WRITE)
	if file:
		file.store_var(progress)
		file.close()


func load_progress() -> void:
	if not FileAccess.file_exists(PROGRESS_PATH):
		return

	var file := FileAccess.open(PROGRESS_PATH, FileAccess.READ)
	if file:
		var data: Variant = file.get_var()
		file.close()
		if data is Dictionary:
			for key in data:
				progress[key] = data[key]


func reset_progress() -> void:
	progress = {
		"highest_difficulty": Balance.Difficulty.NORMAL,
		"normal_cleared": false,
		"hard_cleared": false,
		"veryhard_cleared": false,
		"nightmare_cleared": false,
		"total_runs": 0,
		"total_victories": 0,
		"total_enemies_killed": 0,
		"total_stations_defended": 0,
		"unlocked_classes": ["guardian", "sentinel", "ranger"],
		"unlocked_equipment": ["shock_wave", "frag_grenade"],
		"achievements": [],
	}
	save_progress()


# ===========================================
# 유틸리티
# ===========================================

func _generate_id() -> String:
	return str(Time.get_ticks_msec()) + "_" + str(randi() % 10000)
