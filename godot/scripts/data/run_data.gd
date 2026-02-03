## RunData - 런 상태 데이터 리소스
## 단일 게임 런의 모든 상태를 저장
extends Resource
class_name RunData

# ===========================================
# 기본 정보
# ===========================================

@export var id: String = ""
@export var seed_string: String = ""
@export var difficulty: int = 0  # Balance.Difficulty enum
@export var start_time: float = 0.0
@export var end_time: float = 0.0
@export var is_complete: bool = false
@export var is_victory: bool = false

# ===========================================
# 진행 상태
# ===========================================

@export var turn: int = 1
@export var storm_line: int = 0
@export var credits: int = 0

# ===========================================
# 섹터 맵 데이터
# ===========================================

@export var sector_nodes: Array[Dictionary] = []
@export var current_node_id: int = -1
@export var visited_nodes: Array[int] = []

# ===========================================
# 크루 데이터
# ===========================================

@export var crews: Array[Dictionary] = []

# ===========================================
# Raven 능력 사용 횟수
# ===========================================

@export var raven_abilities: Dictionary = {
	"scout": 3,
	"flare": 2,
	"resupply": 2,
	"orbital_strike": 1,
}

# ===========================================
# 인벤토리
# ===========================================

@export var inventory_equipment: Array[String] = []
@export var active_turrets: Array[Dictionary] = []

# ===========================================
# 통계
# ===========================================

@export var stats: Dictionary = {
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


# ===========================================
# 직렬화
# ===========================================

func serialize() -> Dictionary:
	return {
		"id": id,
		"seed_string": seed_string,
		"difficulty": difficulty,
		"start_time": start_time,
		"end_time": end_time,
		"is_complete": is_complete,
		"is_victory": is_victory,
		"turn": turn,
		"storm_line": storm_line,
		"credits": credits,
		"sector_nodes": sector_nodes,
		"current_node_id": current_node_id,
		"visited_nodes": visited_nodes,
		"crews": crews,
		"raven_abilities": raven_abilities,
		"inventory_equipment": inventory_equipment,
		"active_turrets": active_turrets,
		"stats": stats,
	}


func deserialize(data: Dictionary) -> void:
	id = data.get("id", "")
	seed_string = data.get("seed_string", "")
	difficulty = data.get("difficulty", 0)
	start_time = data.get("start_time", 0.0)
	end_time = data.get("end_time", 0.0)
	is_complete = data.get("is_complete", false)
	is_victory = data.get("is_victory", false)
	turn = data.get("turn", 1)
	storm_line = data.get("storm_line", 0)
	credits = data.get("credits", 0)
	sector_nodes = data.get("sector_nodes", [])
	current_node_id = data.get("current_node_id", -1)
	visited_nodes = data.get("visited_nodes", [])
	crews = data.get("crews", [])
	raven_abilities = data.get("raven_abilities", {})
	inventory_equipment = data.get("inventory_equipment", [])
	active_turrets = data.get("active_turrets", [])
	stats = data.get("stats", {})


# ===========================================
# 유틸리티
# ===========================================

func get_alive_crew_count() -> int:
	var count := 0
	for crew in crews:
		if crew.get("is_alive", false):
			count += 1
	return count


func get_total_squad_size() -> int:
	var total := 0
	for crew in crews:
		if crew.get("is_alive", false):
			total += crew.get("squad_size", 0)
	return total


func get_run_duration_seconds() -> int:
	var end := end_time if end_time > 0 else Time.get_unix_time_from_system()
	return int(end - start_time)


func get_run_duration_formatted() -> String:
	var seconds := get_run_duration_seconds()
	var minutes := seconds / 60
	var hours := minutes / 60
	minutes = minutes % 60
	seconds = seconds % 60

	if hours > 0:
		return "%d:%02d:%02d" % [hours, minutes, seconds]
	else:
		return "%d:%02d" % [minutes, seconds]
