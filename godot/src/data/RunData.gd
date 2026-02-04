class_name RunData
extends Resource

## 런 전체 상태 데이터
## 세이브/로드 대상, S03에서 상세 구현


@export var run_id: String
@export var seed_value: int
@export var difficulty: int = Constants.Difficulty.NORMAL

@export_group("Progress")
@export var current_depth: int = 0
@export var current_sector: int = 0
@export var stages_completed: int = 0

@export_group("Resources")
@export var credits: int = 100

@export_group("Raven")
@export var raven_charges: Dictionary = {
	Constants.RavenAbility.SCOUT: -1,
	Constants.RavenAbility.FLARE: 2,
	Constants.RavenAbility.RESUPPLY: 1,
	Constants.RavenAbility.ORBITAL_STRIKE: 1
}

@export_group("Crews")
@export var crews: Array[CrewRuntimeData] = []

@export_group("Statistics")
@export var statistics: Dictionary = {
	"enemies_killed": 0,
	"facilities_saved": 0,
	"facilities_lost": 0,
	"damage_dealt": 0,
	"damage_taken": 0,
	"credits_earned": 0,
	"credits_spent": 0,
	"time_played": 0.0
}

@export_group("Metadata")
@export var start_time: int = 0  # Unix timestamp
@export var last_save_time: int = 0


func _init() -> void:
	run_id = _generate_run_id()
	start_time = int(Time.get_unix_time_from_system())


func _generate_run_id() -> String:
	return "%d_%d" % [Time.get_unix_time_from_system(), randi()]


# ===== CREW MANAGEMENT =====

func add_crew(crew: CrewRuntimeData) -> void:
	crews.append(crew)


func remove_crew(crew_id: String) -> void:
	for i in range(crews.size() - 1, -1, -1):
		if crews[i].id == crew_id:
			crews.remove_at(i)
			return


func get_crew(crew_id: String) -> CrewRuntimeData:
	for crew in crews:
		if crew.id == crew_id:
			return crew
	return null


func get_alive_crews() -> Array[CrewRuntimeData]:
	var result: Array[CrewRuntimeData] = []
	for crew in crews:
		if crew.is_alive:
			result.append(crew)
	return result


# ===== RAVEN =====

func get_raven_charges(ability: int) -> int:
	return raven_charges.get(ability, 0)


func use_raven(ability: int) -> bool:
	var charges := get_raven_charges(ability)
	if charges == 0:
		return false
	if charges > 0:
		raven_charges[ability] = charges - 1
	return true


func add_raven_charges(ability: int, amount: int) -> void:
	if ability == Constants.RavenAbility.SCOUT:
		return  # Scout은 무제한
	raven_charges[ability] = raven_charges.get(ability, 0) + amount


# ===== STATISTICS =====

func add_statistic(stat_id: String, amount: int = 1) -> void:
	statistics[stat_id] = statistics.get(stat_id, 0) + amount


func get_statistic(stat_id: String) -> int:
	return statistics.get(stat_id, 0)


# ===== SERIALIZATION =====

func to_dict() -> Dictionary:
	var crews_data: Array = []
	for crew in crews:
		crews_data.append({
			"id": crew.id,
			"class_id": crew.class_id,
			"custom_name": crew.custom_name,
			"rank": crew.rank,
			"skill_level": crew.skill_level,
			"equipment_id": crew.equipment_id,
			"equipment_level": crew.equipment_level,
			"trait_id": crew.trait_id,
			"current_hp_ratio": crew.current_hp_ratio,
			"is_alive": crew.is_alive
		})

	return {
		"run_id": run_id,
		"seed_value": seed_value,
		"difficulty": difficulty,
		"current_depth": current_depth,
		"current_sector": current_sector,
		"stages_completed": stages_completed,
		"credits": credits,
		"raven_charges": raven_charges.duplicate(),
		"crews": crews_data,
		"statistics": statistics.duplicate(),
		"start_time": start_time,
		"last_save_time": int(Time.get_unix_time_from_system())
	}


static func from_dict(data: Dictionary) -> RunData:
	var run := RunData.new()
	run.run_id = data.get("run_id", "")
	run.seed_value = data.get("seed_value", 0)
	run.difficulty = data.get("difficulty", Constants.Difficulty.NORMAL)
	run.current_depth = data.get("current_depth", 0)
	run.current_sector = data.get("current_sector", 0)
	run.stages_completed = data.get("stages_completed", 0)
	run.credits = data.get("credits", 100)
	run.raven_charges = data.get("raven_charges", {})
	run.statistics = data.get("statistics", {})
	run.start_time = data.get("start_time", 0)
	run.last_save_time = data.get("last_save_time", 0)

	# 크루 복원
	run.crews = []
	for crew_data in data.get("crews", []):
		var crew := CrewRuntimeData.new()
		crew.id = crew_data.get("id", "")
		crew.class_id = crew_data.get("class_id", "")
		crew.custom_name = crew_data.get("custom_name", "")
		crew.rank = crew_data.get("rank", 0)
		crew.skill_level = crew_data.get("skill_level", 0)
		crew.equipment_id = crew_data.get("equipment_id", "")
		crew.equipment_level = crew_data.get("equipment_level", 0)
		crew.trait_id = crew_data.get("trait_id", "")
		crew.current_hp_ratio = crew_data.get("current_hp_ratio", 1.0)
		crew.is_alive = crew_data.get("is_alive", true)
		run.crews.append(crew)

	return run
