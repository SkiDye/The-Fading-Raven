extends Node

## 메타 진행 관리 싱글톤
## 런 간 영구적으로 유지되는 해금/업적/통계를 관리합니다.
## [br][br]
## 저장 위치: user://meta_progress.json


# ===== SIGNALS =====

signal unlock_achieved(unlock_type: String, unlock_id: String)
signal achievement_completed(achievement_id: String)
signal statistics_updated(stat_id: String, value: Variant)


# ===== CONSTANTS =====

const SAVE_PATH: String = "user://meta_progress.json"
const SAVE_VERSION: String = "1.0.0"

const DEFAULT_UNLOCKED_CLASSES: Array[String] = ["guardian", "sentinel", "ranger"]
const DEFAULT_UNLOCKED_DIFFICULTIES: Array[int] = [0]  # Constants.Difficulty.NORMAL

## 업적 정의
const ACHIEVEMENT_DEFS: Dictionary = {
	"first_escape": {
		"name": "First Escape",
		"name_ko": "첫 탈출",
		"description": "캠페인을 처음으로 클리어",
		"condition_type": "stat_threshold",
		"condition_stat": "successful_runs",
		"condition_value": 1,
		"reward_type": "class",
		"reward_id": "engineer"
	},
	"perfectionist": {
		"name": "Perfectionist",
		"name_ko": "완벽주의자",
		"description": "모든 시설을 방어하며 클리어",
		"condition_type": "achievement_progress",
		"condition_value": 1,
		"reward_type": "equipment",
		"reward_id": "special_shield"
	},
	"assassin": {
		"name": "Assassin",
		"name_ko": "암살자",
		"description": "바이오닉으로 보스 10회 처치",
		"condition_type": "achievement_progress",
		"condition_value": 10,
		"reward_type": "trait",
		"reward_id": "shadow_strike"
	},
	"turret_master": {
		"name": "Turret Master",
		"name_ko": "터렛 마스터",
		"description": "터렛으로 100명 처치",
		"condition_type": "achievement_progress",
		"condition_value": 100,
		"reward_type": "cosmetic",
		"reward_id": "turret_skin_gold"
	},
	"hard_mode": {
		"name": "Hard Mode Clear",
		"name_ko": "하드 모드 클리어",
		"description": "Hard 난이도 클리어",
		"condition_type": "achievement_progress",
		"condition_value": 1,
		"reward_type": "class",
		"reward_id": "bionic"
	},
	"very_hard_mode": {
		"name": "Very Hard Mode Clear",
		"name_ko": "베리 하드 모드 클리어",
		"description": "Very Hard 난이도 클리어",
		"condition_type": "achievement_progress",
		"condition_value": 1,
		"reward_type": "difficulty",
		"reward_id": "nightmare"
	},
	"hundred_kills": {
		"name": "Century",
		"name_ko": "센추리",
		"description": "적 100명 처치",
		"condition_type": "stat_threshold",
		"condition_stat": "total_enemies_killed",
		"condition_value": 100,
		"reward_type": "none",
		"reward_id": ""
	},
	"thousand_kills": {
		"name": "Millennium",
		"name_ko": "밀레니엄",
		"description": "적 1000명 처치",
		"condition_type": "stat_threshold",
		"condition_stat": "total_enemies_killed",
		"condition_value": 1000,
		"reward_type": "none",
		"reward_id": ""
	},
}


# ===== PUBLIC VARIABLES =====

## 해금된 클래스 ID 목록
var unlocked_classes: Array[String] = []

## 해금된 난이도 목록 (Constants.Difficulty enum 값)
var unlocked_difficulties: Array[int] = []

## 해금된 특성 ID 목록
var unlocked_traits: Array[String] = []

## 해금된 장비 ID 목록
var unlocked_equipment: Array[String] = []

## 업적 상태 {achievement_id: {completed: bool, progress: int}}
var achievements: Dictionary = {}

## 통계 데이터
var statistics: Dictionary = {
	"total_runs": 0,
	"successful_runs": 0,
	"total_enemies_killed": 0,
	"total_facilities_saved": 0,
	"total_facilities_lost": 0,
	"total_credits_earned": 0,
	"total_crews_lost": 0,
	"bosses_defeated": 0,
	"perfect_stages": 0,
	"turrets_deployed": 0,
	"skills_used": 0,
	"damage_dealt": 0,
	"damage_taken": 0,
	"play_time_seconds": 0,
	"bionic_boss_kills": 0,
	"turret_kills": 0,
}


# ===== PRIVATE VARIABLES =====

var _is_dirty: bool = false
var _auto_save_timer: float = 0.0
const _AUTO_SAVE_INTERVAL: float = 30.0  # 30초마다 자동 저장


# ===== LIFECYCLE =====

func _ready() -> void:
	load_meta_progress()
	_initialize_achievements()


func _process(delta: float) -> void:
	if _is_dirty:
		_auto_save_timer += delta
		if _auto_save_timer >= _AUTO_SAVE_INTERVAL:
			save_meta_progress()
			_auto_save_timer = 0.0


func _notification(what: int) -> void:
	# 게임 종료 시 자동 저장
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _is_dirty:
			save_meta_progress()


# ===== UNLOCK CHECKS =====

## 클래스가 해금되었는지 확인
func is_class_unlocked(class_id: String) -> bool:
	return class_id in unlocked_classes


## 난이도가 해금되었는지 확인
func is_difficulty_unlocked(difficulty: int) -> bool:
	return difficulty in unlocked_difficulties


## 특성이 해금되었는지 확인
func is_trait_unlocked(trait_id: String) -> bool:
	return trait_id in unlocked_traits


## 장비가 해금되었는지 확인
func is_equipment_unlocked(equipment_id: String) -> bool:
	return equipment_id in unlocked_equipment


## 특정 타입의 해금 상태 확인
func is_unlocked(unlock_type: String, id: String) -> bool:
	match unlock_type:
		"class":
			return is_class_unlocked(id)
		"difficulty":
			return is_difficulty_unlocked(int(id))
		"trait":
			return is_trait_unlocked(id)
		"equipment":
			return is_equipment_unlocked(id)
		_:
			return false


# ===== UNLOCK FUNCTIONS =====

## 클래스 해금
func unlock_class(class_id: String) -> bool:
	if class_id in unlocked_classes:
		return false

	unlocked_classes.append(class_id)
	unlock_achieved.emit("class", class_id)
	_mark_dirty()
	return true


## 난이도 해금
func unlock_difficulty(difficulty: int) -> bool:
	if difficulty in unlocked_difficulties:
		return false

	unlocked_difficulties.append(difficulty)
	unlock_achieved.emit("difficulty", str(difficulty))
	_mark_dirty()
	return true


## 특성 해금
func unlock_trait(trait_id: String) -> bool:
	if trait_id in unlocked_traits:
		return false

	unlocked_traits.append(trait_id)
	unlock_achieved.emit("trait", trait_id)
	_mark_dirty()
	return true


## 장비 해금
func unlock_equipment(equipment_id: String) -> bool:
	if equipment_id in unlocked_equipment:
		return false

	unlocked_equipment.append(equipment_id)
	unlock_achieved.emit("equipment", equipment_id)
	_mark_dirty()
	return true


# ===== ACHIEVEMENTS =====

## 업적 완료 여부 확인
func is_achievement_completed(achievement_id: String) -> bool:
	return achievements.get(achievement_id, {}).get("completed", false)


## 업적 진행도 조회
func get_achievement_progress(achievement_id: String) -> int:
	return achievements.get(achievement_id, {}).get("progress", 0)


## 업적 정의 조회
func get_achievement_def(achievement_id: String) -> Dictionary:
	return ACHIEVEMENT_DEFS.get(achievement_id, {})


## 모든 업적 ID 조회
func get_all_achievement_ids() -> Array:
	return ACHIEVEMENT_DEFS.keys()


## 업적 진행도 업데이트
func update_achievement_progress(achievement_id: String, progress: int) -> void:
	if not achievements.has(achievement_id):
		return

	if achievements[achievement_id].completed:
		return

	achievements[achievement_id].progress = progress
	_check_achievement_completion(achievement_id)
	_mark_dirty()


## 업적 진행도 증가
func increment_achievement_progress(achievement_id: String, amount: int = 1) -> void:
	if not achievements.has(achievement_id):
		return

	if achievements[achievement_id].completed:
		return

	achievements[achievement_id].progress += amount
	_check_achievement_completion(achievement_id)
	_mark_dirty()


# ===== STATISTICS =====

## 통계 값 조회
func get_stat(stat_id: String) -> Variant:
	return statistics.get(stat_id, 0)


## 통계 값 기록 (누적)
func record_stat(stat_id: String, value: Variant) -> void:
	if not statistics.has(stat_id):
		push_warning("MetaProgress.record_stat: Unknown stat '%s'" % stat_id)
		return

	if value is int or value is float:
		statistics[stat_id] += value
	else:
		statistics[stat_id] = value

	statistics_updated.emit(stat_id, statistics[stat_id])
	_check_stat_achievements(stat_id)
	_mark_dirty()


## 통계 값 직접 설정
func set_stat(stat_id: String, value: Variant) -> void:
	if not statistics.has(stat_id):
		push_warning("MetaProgress.set_stat: Unknown stat '%s'" % stat_id)
		return

	statistics[stat_id] = value
	statistics_updated.emit(stat_id, value)
	_check_stat_achievements(stat_id)
	_mark_dirty()


# ===== RUN RECORDING =====

## 런 결과 기록
func record_run_result(run_data: Dictionary, victory: bool) -> void:
	statistics["total_runs"] += 1

	if victory:
		statistics["successful_runs"] += 1
		_check_achievement_completion("first_escape")

		# 난이도별 클리어 체크
		var difficulty: int = run_data.get("difficulty", 0)
		match difficulty:
			Constants.Difficulty.HARD:
				increment_achievement_progress("hard_mode", 1)
			Constants.Difficulty.VERY_HARD:
				increment_achievement_progress("very_hard_mode", 1)
				unlock_difficulty(Constants.Difficulty.NIGHTMARE)

	# 런 통계 누적
	var run_stats: Dictionary = run_data.get("statistics", {})
	statistics["total_enemies_killed"] += run_stats.get("enemies_killed", 0)
	statistics["total_facilities_saved"] += run_stats.get("facilities_saved", 0)
	statistics["total_facilities_lost"] += run_stats.get("facilities_lost", 0)
	statistics["total_crews_lost"] += run_stats.get("crews_lost", 0)
	statistics["damage_dealt"] += run_stats.get("damage_dealt", 0)
	statistics["damage_taken"] += run_stats.get("damage_taken", 0)

	# 통계 기반 업적 체크
	_check_stat_achievements("total_enemies_killed")

	_mark_dirty()
	save_meta_progress()


## 스테이지 결과 기록
func record_stage_result(stage_data: Dictionary, result: Dictionary) -> void:
	var facilities_saved: int = result.get("facilities_saved", 0)
	var facilities_total: int = result.get("facilities_total", 0)

	# 완벽 스테이지 체크
	if facilities_total > 0 and facilities_saved == facilities_total:
		statistics["perfect_stages"] += 1

	# 보스 처치 체크
	var node_type: int = stage_data.get("node_type", -1)
	var is_victory: bool = result.get("victory", false)
	if node_type == Constants.NodeType.BOSS and is_victory:
		statistics["bosses_defeated"] += 1

	_mark_dirty()


## 완벽 런 기록 (모든 시설 방어)
func record_perfect_run() -> void:
	increment_achievement_progress("perfectionist", 1)


## 바이오닉 보스 킬 기록
func record_bionic_boss_kill() -> void:
	statistics["bionic_boss_kills"] += 1
	increment_achievement_progress("assassin", 1)
	_mark_dirty()


## 터렛 킬 기록
func record_turret_kill(count: int = 1) -> void:
	statistics["turret_kills"] += count
	increment_achievement_progress("turret_master", count)
	_mark_dirty()


# ===== SAVE / LOAD =====

## 메타 진행 저장
func save_meta_progress() -> bool:
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"unlocked_classes": unlocked_classes,
		"unlocked_difficulties": unlocked_difficulties,
		"unlocked_traits": unlocked_traits,
		"unlocked_equipment": unlocked_equipment,
		"achievements": achievements,
		"statistics": statistics,
		"saved_at": Time.get_unix_time_from_system()
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("MetaProgress.save_meta_progress: Failed to open file - %s" % FileAccess.get_open_error())
		return false

	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	_is_dirty = false
	return true


## 메타 진행 로드
func load_meta_progress() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		_reset_to_defaults()
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("MetaProgress.load_meta_progress: Failed to open file")
		_reset_to_defaults()
		return false

	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()

	if error != OK:
		push_error("MetaProgress.load_meta_progress: JSON parse error - %s" % json.get_error_message())
		_reset_to_defaults()
		return false

	var data: Dictionary = json.data

	# 버전 체크 (마이그레이션 필요 시)
	var version: String = data.get("version", "0.0.0")
	if version != SAVE_VERSION:
		push_warning("MetaProgress: Save version mismatch (%s vs %s), migrating..." % [version, SAVE_VERSION])
		_migrate_save_data(data, version)

	# 데이터 로드
	_load_array_string(data, "unlocked_classes", unlocked_classes)
	_load_array_int(data, "unlocked_difficulties", unlocked_difficulties)
	_load_array_string(data, "unlocked_traits", unlocked_traits)
	_load_array_string(data, "unlocked_equipment", unlocked_equipment)

	var loaded_achievements: Dictionary = data.get("achievements", {})
	for ach_id in loaded_achievements:
		achievements[ach_id] = loaded_achievements[ach_id]

	var loaded_stats: Dictionary = data.get("statistics", {})
	for stat_id in loaded_stats:
		if statistics.has(stat_id):
			statistics[stat_id] = loaded_stats[stat_id]

	_is_dirty = false
	return true


## 메타 진행 초기화
func reset_meta_progress() -> void:
	_reset_to_defaults()
	save_meta_progress()


# ===== DEBUG =====

## 모든 콘텐츠 해금 (디버그용)
func unlock_all() -> void:
	unlocked_classes = ["guardian", "sentinel", "ranger", "engineer", "bionic"]
	unlocked_difficulties = [
		Constants.Difficulty.NORMAL,
		Constants.Difficulty.HARD,
		Constants.Difficulty.VERY_HARD,
		Constants.Difficulty.NIGHTMARE
	]

	# Constants에서 모든 특성/장비 가져오기
	for trait_data in Constants.get_all_traits():
		if trait_data and trait_data.has("id"):
			unlocked_traits.append(trait_data.id)

	for equip_data in Constants.get_all_equipment():
		if equip_data and equip_data.has("id"):
			unlocked_equipment.append(equip_data.id)

	_mark_dirty()
	save_meta_progress()


## 현재 상태 출력 (디버그용)
func print_status() -> void:
	print("=== MetaProgress Status ===")
	print("Unlocked Classes: ", unlocked_classes)
	print("Unlocked Difficulties: ", unlocked_difficulties)
	print("Unlocked Traits: ", unlocked_traits)
	print("Unlocked Equipment: ", unlocked_equipment)
	print("Achievements: ", achievements)
	print("Statistics: ", statistics)
	print("===========================")


# ===== PRIVATE FUNCTIONS =====

func _initialize_achievements() -> void:
	for ach_id in ACHIEVEMENT_DEFS:
		if not achievements.has(ach_id):
			achievements[ach_id] = {
				"completed": false,
				"progress": 0
			}


func _check_achievement_completion(achievement_id: String) -> void:
	if not ACHIEVEMENT_DEFS.has(achievement_id):
		return

	if not achievements.has(achievement_id):
		return

	if achievements[achievement_id].completed:
		return

	var def: Dictionary = ACHIEVEMENT_DEFS[achievement_id]
	var completed: bool = false

	var condition_type: String = def.get("condition_type", "")
	var condition_value: int = def.get("condition_value", 0)

	match condition_type:
		"stat_threshold":
			var stat_id: String = def.get("condition_stat", "")
			completed = statistics.get(stat_id, 0) >= condition_value
		"achievement_progress":
			completed = achievements[achievement_id].progress >= condition_value

	if completed:
		_complete_achievement(achievement_id)


func _complete_achievement(achievement_id: String) -> void:
	achievements[achievement_id].completed = true

	var def: Dictionary = ACHIEVEMENT_DEFS.get(achievement_id, {})
	var reward_type: String = def.get("reward_type", "none")
	var reward_id: String = def.get("reward_id", "")

	# 보상 지급
	match reward_type:
		"class":
			unlock_class(reward_id)
		"difficulty":
			if reward_id == "nightmare":
				unlock_difficulty(Constants.Difficulty.NIGHTMARE)
			else:
				unlock_difficulty(int(reward_id))
		"trait":
			unlock_trait(reward_id)
		"equipment":
			unlock_equipment(reward_id)
		# "cosmetic", "none" 등은 별도 처리 없음

	achievement_completed.emit(achievement_id)
	_mark_dirty()


func _check_stat_achievements(stat_id: String) -> void:
	match stat_id:
		"total_enemies_killed":
			_check_achievement_completion("hundred_kills")
			_check_achievement_completion("thousand_kills")
		"successful_runs":
			_check_achievement_completion("first_escape")


func _reset_to_defaults() -> void:
	unlocked_classes.clear()
	for class_id in DEFAULT_UNLOCKED_CLASSES:
		unlocked_classes.append(class_id)

	unlocked_difficulties.clear()
	for diff in DEFAULT_UNLOCKED_DIFFICULTIES:
		unlocked_difficulties.append(diff)

	unlocked_traits.clear()
	unlocked_equipment.clear()

	achievements.clear()
	_initialize_achievements()

	for key in statistics:
		statistics[key] = 0


func _migrate_save_data(_data: Dictionary, _from_version: String) -> void:
	# 버전별 마이그레이션 로직 (필요 시 구현)
	pass


func _load_array_string(data: Dictionary, key: String, target: Array[String]) -> void:
	target.clear()
	var source: Array = data.get(key, [])
	for item in source:
		if item is String:
			target.append(item)


func _load_array_int(data: Dictionary, key: String, target: Array[int]) -> void:
	target.clear()
	var source: Array = data.get(key, [])
	for item in source:
		if item is int:
			target.append(item)
		elif item is float:
			target.append(int(item))


func _mark_dirty() -> void:
	_is_dirty = true
