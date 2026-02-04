extends Node

## 전역 상수 및 열거형 정의
## 다른 모든 세션에서 참조하는 공유 상수


# ===== ENUMS =====

enum Difficulty {
	NORMAL = 0,
	HARD = 1,
	VERY_HARD = 2,
	NIGHTMARE = 3
}

enum CrewClass {
	GUARDIAN,
	SENTINEL,
	RANGER,
	ENGINEER,
	BIONIC
}

enum EnemyTier {
	TIER_1 = 1,
	TIER_2 = 2,
	TIER_3 = 3,
	BOSS = 4
}

enum DamageType {
	PHYSICAL,
	ENERGY,
	EXPLOSIVE,
	TRUE
}

enum TileType {
	VOID,
	FLOOR,
	WALL,
	AIRLOCK,
	ELEVATED,
	LOWERED,
	FACILITY,
	COVER_HALF,
	COVER_FULL
}

enum EquipmentType {
	PASSIVE,
	ACTIVE_COOLDOWN,
	ACTIVE_CHARGES
}

enum NodeType {
	START,
	BATTLE,
	COMMANDER,
	EQUIPMENT,
	STORM,
	BOSS,
	REST,
	GATE
}

enum RavenAbility {
	SCOUT,
	FLARE,
	RESUPPLY,
	ORBITAL_STRIKE
}

enum ToastType {
	INFO,
	SUCCESS,
	WARNING,
	ERROR
}

enum EntityState {
	IDLE,
	MOVING,
	ATTACKING,
	USING_SKILL,
	STUNNED,
	DEAD
}

enum FacilityType {
	HOUSING,
	MEDICAL,
	ARMORY,
	COMM_TOWER,
	POWER_PLANT
}


# ===== CONSTANTS =====

const TILE_SIZE: int = 32
const TILE_SIZE_HALF: int = 16


# ===== BALANCE =====
## S02에서 상세 정의 예정

var BALANCE: Dictionary = {
	# 타일/전투
	"tile_size": TILE_SIZE,
	"cover_half_reduction": 0.25,
	"cover_full_reduction": 0.50,
	"elevation_damage_bonus": 0.15,
	"flanking_bonus": 0.25,
	"critical_multiplier": 1.5,
	"assassination_multiplier": 2.0,

	# 분대 크기
	"squad_size": {
		"guardian": 8,
		"sentinel": 8,
		"ranger": 8,
		"engineer": 6,
		"bionic": 5
	},

	# 회복
	"recovery_time_per_unit": 2.0,

	# 스킬 쿨다운
	"skill_cooldowns": {
		"shield_bash": 20.0,
		"lance_charge": 25.0,
		"volley_fire": 15.0,
		"deploy_turret": 30.0,
		"blink": 15.0
	},

	# 업그레이드 비용
	"upgrade_costs": {
		"class_rank": [6, 12, 20],
		"skill_level": [7, 10, 14]
	},

	# Raven 충전량
	"raven_charges": {
		RavenAbility.SCOUT: -1,
		RavenAbility.FLARE: 2,
		RavenAbility.RESUPPLY: 1,
		RavenAbility.ORBITAL_STRIKE: 1
	},

	# 웨이브
	"wave": {
		"base_budget": 10,
		"budget_per_wave": 0.2,
		"spawn_interval": 5.0
	},

	# 전투
	"combat": {
		"slow_motion_factor": 0.3,
		"knockback_base": 1.0,
		"cover_damage_reduction": 0.5,
		"elevation_damage_bonus": 0.2
	},

	# 캠페인 (S10)
	"campaign": {
		# 난이도별 섹터 깊이 범위 [min, max]
		"depth_range": {
			Difficulty.NORMAL: [8, 12],
			Difficulty.HARD: [10, 14],
			Difficulty.VERY_HARD: [12, 16],
			Difficulty.NIGHTMARE: [14, 20]
		},
		# 난이도별 레이어당 노드 수 범위 [min, max]
		"nodes_per_layer": {
			Difficulty.NORMAL: [2, 3],
			Difficulty.HARD: [2, 4],
			Difficulty.VERY_HARD: [3, 4],
			Difficulty.NIGHTMARE: [3, 5]
		},
		# 스톰 진행 속도 (턴당)
		"storm_advance_rate": {
			Difficulty.NORMAL: 2,
			Difficulty.HARD: 2,
			Difficulty.VERY_HARD: 1,
			Difficulty.NIGHTMARE: 1
		},
		# 이벤트 출현 확률
		"event_chances": {
			"commander": 0.6,
			"equipment": 0.5,
			"storm": 0.2,
			"boss": 0.3,
			"rest": 0.4
		},
		# 이벤트 간격 (최소 레이어)
		"event_intervals": {
			"commander": 3,
			"equipment": 2,
			"storm": 2,
			"boss": 4
		}
	}
}


# ===== ENEMY WAVE COSTS =====

const ENEMY_COSTS: Dictionary = {
	"rusher": 1,
	"gunner": 2,
	"shield_trooper": 3,
	"jumper": 4,
	"heavy_trooper": 5,
	"hacker": 3,
	"storm_creature": 3,
	"brute": 8,
	"sniper": 6,
	"drone_carrier": 7,
	"shield_generator": 5,
	"pirate_captain": 20,
	"storm_core": 0
}


# ===== DATA CACHES =====
## S02에서 구현 예정

var _crew_classes: Dictionary = {}
var _enemies: Dictionary = {}
var _equipment: Dictionary = {}
var _traits: Dictionary = {}
var _facilities: Dictionary = {}


func _ready() -> void:
	_load_all_data()


func _load_all_data() -> void:
	_load_crew_classes()
	_load_enemies()
	_load_equipment()
	_load_traits()
	_load_facilities()
	print("[Constants] Data loaded: %d crews, %d enemies, %d equipment, %d traits, %d facilities" % [
		_crew_classes.size(),
		_enemies.size(),
		_equipment.size(),
		_traits.size(),
		_facilities.size()
	])


func _load_crew_classes() -> void:
	_crew_classes.clear()
	var path := "res://resources/crews/"
	_load_resources_from_directory(path, _crew_classes)


func _load_enemies() -> void:
	_enemies.clear()
	var path := "res://resources/enemies/"
	_load_resources_from_directory(path, _enemies)


func _load_equipment() -> void:
	_equipment.clear()
	var path := "res://resources/equipment/"
	_load_resources_from_directory(path, _equipment)


func _load_traits() -> void:
	_traits.clear()
	var path := "res://resources/traits/"
	_load_resources_from_directory(path, _traits)


func _load_facilities() -> void:
	_facilities.clear()
	var path := "res://resources/facilities/"
	_load_resources_from_directory(path, _facilities)


func _load_resources_from_directory(path: String, cache: Dictionary) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("[Constants] Cannot open directory: %s" % path)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if file_name.ends_with(".tres"):
			var full_path := path + file_name
			var resource := load(full_path)
			if resource and resource.has_method("get") and "id" in resource:
				var id: String = resource.id
				if id != "":
					cache[id] = resource
				else:
					push_warning("[Constants] Resource has empty id: %s" % full_path)
			elif resource:
				# id 속성이 없는 경우 파일 이름 사용
				var id := file_name.get_basename()
				cache[id] = resource
		file_name = dir.get_next()

	dir.list_dir_end()


# ===== DATA ACCESSORS =====
## S02에서 구현 예정

func get_crew_class(class_id: String) -> Resource:
	if _crew_classes.has(class_id):
		return _crew_classes[class_id]
	push_warning("Constants.get_crew_class: '%s' not found" % class_id)
	return null


func get_enemy(enemy_id: String) -> Resource:
	if _enemies.has(enemy_id):
		return _enemies[enemy_id]
	push_warning("Constants.get_enemy: '%s' not found" % enemy_id)
	return null


func get_equipment(equipment_id: String) -> Resource:
	if _equipment.has(equipment_id):
		return _equipment[equipment_id]
	push_warning("Constants.get_equipment: '%s' not found" % equipment_id)
	return null


func get_trait(trait_id: String) -> Resource:
	if _traits.has(trait_id):
		return _traits[trait_id]
	push_warning("Constants.get_trait: '%s' not found" % trait_id)
	return null


func get_facility(facility_id: String) -> Resource:
	if _facilities.has(facility_id):
		return _facilities[facility_id]
	push_warning("Constants.get_facility: '%s' not found" % facility_id)
	return null


func get_all_crew_classes() -> Array:
	return _crew_classes.values()


func get_all_enemies() -> Array:
	return _enemies.values()


func get_all_equipment() -> Array:
	return _equipment.values()


func get_all_traits() -> Array:
	return _traits.values()


func get_all_facilities() -> Array:
	return _facilities.values()
