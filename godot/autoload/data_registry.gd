## DataRegistry - 데이터 리소스 중앙 관리
## 크루, 적, 장비, 특성 등 모든 데이터 로드 및 접근
extends Node

# 리소스 경로
const CREW_PATH := "res://resources/crews/"
const ENEMY_PATH := "res://resources/enemies/"
const EQUIPMENT_PATH := "res://resources/equipment/"
const TRAIT_PATH := "res://resources/traits/"
const FACILITY_PATH := "res://resources/facilities/"

# 캐시된 데이터
var _crews: Dictionary = {}
var _enemies: Dictionary = {}
var _equipment: Dictionary = {}
var _traits: Dictionary = {}
var _facilities: Dictionary = {}

var _is_loaded: bool = false

signal data_loaded()


func _ready() -> void:
	load_all_data()


## 모든 데이터 로드
func load_all_data() -> void:
	_load_crews()
	_load_enemies()
	_load_equipment()
	_load_traits()
	_load_facilities()
	_is_loaded = true
	data_loaded.emit()


## 데이터 로드 완료 여부
func is_loaded() -> bool:
	return _is_loaded


# ===========================================
# 크루 클래스
# ===========================================

func _load_crews() -> void:
	_crews = {
		"guardian": _create_guardian(),
		"sentinel": _create_sentinel(),
		"ranger": _create_ranger(),
		"engineer": _create_engineer(),
		"bionic": _create_bionic(),
	}


func _create_guardian() -> Dictionary:
	return {
		"id": "guardian",
		"name": "가디언",
		"name_en": "Guardian",
		"base_squad_size": 8,
		"weapon": "에너지 실드 + 블래스터",
		"role": "올라운더, 대원거리",
		"color": Color("#4a9eff"),

		"stats": {
			"damage": 10,
			"attack_speed": 1.0,
			"move_speed": 80.0,
			"attack_range": 60.0,
			"defense": 0.9,  # 실드 원거리 데미지 감소
		},

		"skill": {
			"id": "shield_bash",
			"name": "실드 배쉬",
			"type": "direction",
			"base_cooldown": 10.0,
			"description": "지정 방향으로 돌진하여 적에게 피해를 주고 밀쳐냅니다.",
			"levels": [
				{"level": 1, "distance": 3, "knockback": 1.0, "damage": 1.0, "stun": 0.0, "budget": 7},
				{"level": 2, "distance": 5, "knockback": 1.5, "damage": 1.2, "stun": 0.0, "budget": 10},
				{"level": 3, "distance": -1, "knockback": 2.0, "damage": 1.5, "stun": 2.0, "budget": 14},
			],
		},

		"strengths": ["원거리 적 대응 (실드)", "기동성", "유연성"],
		"weaknesses": ["짧은 리치", "대형 적 취약", "교전 중 실드 무효"],

		# Bad North 핵심: 근접전 중 실드 비활성화
		"special_mechanics": {
			"shield_in_melee": false,
		},
	}


func _create_sentinel() -> Dictionary:
	return {
		"id": "sentinel",
		"name": "센티넬",
		"name_en": "Sentinel",
		"base_squad_size": 8,
		"weapon": "에너지 랜스",
		"role": "병목 방어, 대브루트",
		"color": Color("#f6ad55"),

		"stats": {
			"damage": 15,
			"attack_speed": 1.2,
			"move_speed": 70.0,
			"attack_range": 80.0,
			"defense": 0.0,
		},

		"skill": {
			"id": "lance_charge",
			"name": "랜스 차지",
			"type": "direction",
			"base_cooldown": 12.0,
			"description": "지정 방향으로 돌격하여 경로상 모든 적에게 고데미지를 줍니다.",
			"levels": [
				{"level": 1, "distance": 3, "damage": 2.0, "brute_kill": false, "piercing": true, "budget": 7},
				{"level": 2, "distance": -1, "damage": 2.5, "brute_kill": false, "piercing": true, "budget": 10},
				{"level": 3, "distance": -1, "damage": 3.0, "brute_kill": true, "piercing": true, "budget": 14},
			],
		},

		"strengths": ["긴 리치", "병목 최강", "브루트 카운터"],
		"weaknesses": ["정지 공격", "근접 무력화", "원거리 취약", "측면 취약"],

		# Bad North 핵심: 적 밀착 시 랜스 들어올림 (공격 불가)
		"special_mechanics": {
			"lance_raise_range": 30.0,
		},
	}


func _create_ranger() -> Dictionary:
	return {
		"id": "ranger",
		"name": "레인저",
		"name_en": "Ranger",
		"base_squad_size": 8,
		"weapon": "레이저 라이플",
		"role": "원거리 딜러, 침투 저지",
		"color": Color("#68d391"),

		"stats": {
			"damage": 8,
			"attack_speed": 0.8,
			"move_speed": 75.0,
			"attack_range": 200.0,
			"defense": 0.0,
		},

		"skill": {
			"id": "volley_fire",
			"name": "볼리 파이어",
			"type": "position",
			"base_cooldown": 8.0,
			"description": "지정 위치에 분대 전체가 일제 사격합니다.",
			"levels": [
				{"level": 1, "aoe_radius": 1.0, "shots_per_unit": 1, "shield_pen": 0.3, "piercing": false, "budget": 7},
				{"level": 2, "aoe_radius": 1.5, "shots_per_unit": 2, "shield_pen": 0.5, "piercing": false, "budget": 10},
				{"level": 3, "aoe_radius": 2.0, "shots_per_unit": 3, "shield_pen": 0.7, "piercing": true, "budget": 14},
			],
		},

		"strengths": ["원거리 공격", "침투 저지", "고지대 보너스"],
		"weaknesses": ["실드 무효화", "이동 타겟 명중률 낮음", "근접 취약", "초기 정확도 낮음"],

		"accuracy_by_rank": {
			"standard": 0.5,
			"veteran": 0.75,
			"elite": 0.95,
		},
	}


func _create_engineer() -> Dictionary:
	return {
		"id": "engineer",
		"name": "엔지니어",
		"name_en": "Engineer",
		"base_squad_size": 6,  # 작은 분대
		"weapon": "권총 + 터렛",
		"role": "지원, 설치, 시설 수리",
		"color": Color("#fc8181"),

		"stats": {
			"damage": 5,
			"attack_speed": 1.5,
			"move_speed": 65.0,
			"attack_range": 80.0,
			"defense": 0.0,
		},

		"skill": {
			"id": "deploy_turret",
			"name": "터렛 배치",
			"type": "position",
			"base_cooldown": 15.0,
			"description": "지정 위치에 자동 공격 터렛을 설치합니다.",
			"levels": [
				{"level": 1, "max_turrets": 1, "turret_damage": 1.0, "turret_health": 1.0, "turret_range": 150.0, "slow": false, "budget": 7},
				{"level": 2, "max_turrets": 2, "turret_damage": 1.5, "turret_health": 1.5, "turret_range": 175.0, "slow": false, "budget": 10},
				{"level": 3, "max_turrets": 3, "turret_damage": 2.0, "turret_health": 2.0, "turret_range": 200.0, "slow": true, "budget": 14},
			],
		},

		"strengths": ["터렛 화력", "시설 수리", "병목 강화"],
		"weaknesses": ["약한 전투력", "호위 필요", "터렛 제한", "해커 취약"],

		"repair_ability": {
			"repair_time": 20.0,
			"repair_health_percent": 0.5,
			"repair_credit_percent": 0.5,
		},
	}


func _create_bionic() -> Dictionary:
	return {
		"id": "bionic",
		"name": "바이오닉",
		"name_en": "Bionic",
		"base_squad_size": 5,  # 가장 작은 분대
		"weapon": "에너지 블레이드",
		"role": "고기동, 암살",
		"color": Color("#b794f4"),

		"stats": {
			"damage": 12,
			"attack_speed": 0.6,
			"move_speed": 120.0,  # 기본 +50%
			"attack_range": 50.0,
			"defense": 0.0,
		},

		"skill": {
			"id": "blink",
			"name": "블링크",
			"type": "position",
			"base_cooldown": 15.0,
			"description": "지정 위치로 순간이동합니다. 벽을 통과할 수 있습니다.",
			"levels": [
				{"level": 1, "distance": 2, "cooldown_reduction": 0.0, "stun_on_land": false, "invuln_time": 0.2, "budget": 7},
				{"level": 2, "distance": 4, "cooldown_reduction": 0.2, "stun_on_land": false, "invuln_time": 0.3, "budget": 10},
				{"level": 3, "distance": 6, "cooldown_reduction": 0.33, "stun_on_land": true, "stun_radius": 1.0, "stun_duration": 1.5, "invuln_time": 0.5, "budget": 14},
			],
		},

		"strengths": ["고기동", "암살 보너스", "우선순위 처치"],
		"weaknesses": ["적은 인원", "낮은 체력", "정면전 약함"],

		"assassination_bonus": {
			"damage_mult": 2.0,
			"condition": "target_not_engaged",
		},
	}


func get_crew_class(class_id: String) -> Dictionary:
	return _crews.get(class_id, {})


func get_all_crew_classes() -> Array:
	return _crews.keys()


func get_crew_skill(class_id: String, level: int = 1) -> Dictionary:
	var crew := get_crew_class(class_id)
	if crew.is_empty():
		return {}

	var skill: Dictionary = crew["skill"]
	var level_data: Dictionary = skill["levels"][mini(level, skill["levels"].size()) - 1]

	return {
		"id": skill["id"],
		"name": skill["name"],
		"type": skill["type"],
		"base_cooldown": skill["base_cooldown"],
		"description": skill["description"],
		"current_level": level,
		"effect": level_data,
	}


# ===========================================
# 적
# ===========================================

func _load_enemies() -> void:
	_enemies = {
		# Tier 1 - 기본 적
		"rusher": _create_rusher(),
		"gunner": _create_gunner(),
		"shield_trooper": _create_shield_trooper(),

		# Tier 2 - 중급 적
		"jumper": _create_jumper(),
		"heavy_trooper": _create_heavy_trooper(),
		"hacker": _create_hacker(),
		"storm_creature": _create_storm_creature(),

		# Tier 3 - 고급 적
		"brute": _create_brute(),
		"sniper": _create_sniper(),
		"drone_carrier": _create_drone_carrier(),
		"shield_generator": _create_shield_generator(),

		# 보스
		"pirate_captain": _create_pirate_captain(),
		"storm_core": _create_storm_core(),
	}


func _create_rusher() -> Dictionary:
	return {
		"id": "rusher",
		"name": "러셔",
		"tier": 1,
		"budget": 1,
		"min_depth": 0,
		"stats": {"health": 1, "damage": 5, "speed": 70.0, "attack_speed": 1.2, "attack_range": 40.0},
		"visual": {"color": Color("#fc8181"), "size": 12},
		"behavior": {"type": "melee_basic", "priority": "nearest_crew", "attacks_station": true},
		"counters": ["guardian", "sentinel", "ranger"],
	}


func _create_gunner() -> Dictionary:
	return {
		"id": "gunner",
		"name": "건너",
		"tier": 1,
		"budget": 2,
		"min_depth": 0,
		"stats": {"health": 1, "damage": 8, "speed": 50.0, "attack_speed": 1.5, "attack_range": 150.0},
		"visual": {"color": Color("#f6ad55"), "size": 12},
		"behavior": {"type": "ranged_basic", "priority": "nearest_crew", "attacks_station": true, "keep_distance": true},
		"counters": ["guardian"],
		"threats": ["sentinel", "ranger"],
	}


func _create_shield_trooper() -> Dictionary:
	return {
		"id": "shield_trooper",
		"name": "실드 트루퍼",
		"tier": 1,
		"budget": 3,
		"min_depth": 0,
		"stats": {"health": 2, "damage": 6, "speed": 55.0, "attack_speed": 1.3, "attack_range": 45.0, "front_shield": 0.9},
		"visual": {"color": Color("#4a9eff"), "size": 14},
		"behavior": {"type": "melee_shielded", "priority": "nearest_crew", "attacks_station": true},
		"counters": ["sentinel", "bionic"],
		"threats": ["ranger"],
	}


func _create_jumper() -> Dictionary:
	return {
		"id": "jumper",
		"name": "점퍼",
		"tier": 2,
		"budget": 4,
		"min_depth": 3,
		"stats": {"health": 2, "damage": 10, "speed": 85.0, "attack_speed": 0.9, "attack_range": 45.0},
		"visual": {"color": Color("#9f7aea"), "size": 13},
		"behavior": {"type": "melee_jumper", "priority": "crew_bypassing", "attacks_station": false},
		"special": {"jump_range": 4, "jump_cooldown": 3.0, "bypasses_sentinel": true},
		"counters": ["ranger", "bionic"],
		"threats": ["sentinel", "engineer"],
	}


func _create_heavy_trooper() -> Dictionary:
	return {
		"id": "heavy_trooper",
		"name": "헤비 트루퍼",
		"tier": 2,
		"budget": 5,
		"min_depth": 4,
		"stats": {"health": 3, "damage": 12, "speed": 45.0, "attack_speed": 1.6, "attack_range": 50.0, "front_shield": 0.8},
		"visual": {"color": Color("#718096"), "size": 18},
		"behavior": {"type": "melee_heavy", "priority": "nearest_crew", "attacks_station": true},
		"special": {"grenade_range": 3, "grenade_damage": 15, "grenade_radius": 1.5, "grenade_cooldown": 8.0},
		"threats": ["sentinel"],
	}


func _create_hacker() -> Dictionary:
	return {
		"id": "hacker",
		"name": "해커",
		"tier": 2,
		"budget": 3,
		"min_depth": 4,
		"stats": {"health": 1, "damage": 0, "speed": 60.0},
		"visual": {"color": Color("#68d391"), "size": 11},
		"behavior": {"type": "support_hacker", "priority": "nearest_turret", "attacks_station": false, "flees": true},
		"special": {"hack_range": 2, "hack_time": 5.0, "hack_effect": "turn_hostile"},
		"counters": ["bionic", "ranger"],
		"threats": ["engineer"],
	}


func _create_storm_creature() -> Dictionary:
	return {
		"id": "storm_creature",
		"name": "폭풍 생명체",
		"tier": 2,
		"budget": 3,
		"min_depth": 0,
		"storm_only": true,
		"stats": {"health": 2, "damage": 20, "speed": 75.0},
		"visual": {"color": Color("#e53e3e"), "size": 14},
		"behavior": {"type": "kamikaze", "priority": "nearest_crew", "attacks_station": true},
		"special": {"trigger_range": 30.0, "explosion_radius": 2, "explosion_damage": 20},
		"counters": ["ranger"],
		"threats": ["guardian", "sentinel"],
	}


func _create_brute() -> Dictionary:
	return {
		"id": "brute",
		"name": "브루트",
		"tier": 3,
		"budget": 8,
		"min_depth": 5,
		"stats": {"health": 6, "damage": 25, "speed": 35.0, "attack_speed": 2.0, "attack_range": 60.0, "knockback": 3},
		"visual": {"color": Color("#9f7aea"), "size": 28},
		"behavior": {"type": "melee_brute", "priority": "nearest_crew", "attacks_station": true},
		"special": {"cleave_angle": 120, "one_hit_kill": true},
		"counters": ["sentinel"],
		"threats": ["guardian", "ranger", "bionic", "engineer"],
		"group_size": {"min": 2, "max": 4},
	}


func _create_sniper() -> Dictionary:
	return {
		"id": "sniper",
		"name": "스나이퍼",
		"tier": 3,
		"budget": 6,
		"min_depth": 6,
		"stats": {"health": 1, "damage": 30, "speed": 30.0, "attack_speed": 4.0, "attack_range": 500.0},
		"visual": {"color": Color("#ed64a6"), "size": 12},
		"behavior": {"type": "ranged_sniper", "priority": "highest_threat", "attacks_station": false, "stays_back": true},
		"special": {"aim_time": 3.0, "laser_visible": true, "cant_move_while_aiming": true},
		"counters": ["bionic"],
		"threats": ["ranger", "guardian", "sentinel"],
	}


func _create_drone_carrier() -> Dictionary:
	return {
		"id": "drone_carrier",
		"name": "드론 캐리어",
		"tier": 3,
		"budget": 7,
		"min_depth": 7,
		"stats": {"health": 3, "damage": 5, "speed": 40.0, "attack_speed": 2.0, "attack_range": 100.0},
		"visual": {"color": Color("#4fd1c5"), "size": 22},
		"behavior": {"type": "support_carrier", "priority": "safe_position", "stays_back": true},
		"special": {"spawn_interval": 10.0, "drones_per_spawn": 2, "max_drones": 6, "drones_die_on_death": true},
		"counters": ["bionic", "ranger"],
		"threats": ["engineer"],
	}


func _create_shield_generator() -> Dictionary:
	return {
		"id": "shield_generator",
		"name": "실드 제너레이터",
		"tier": 3,
		"budget": 5,
		"min_depth": 6,
		"stats": {"health": 2, "damage": 0, "speed": 50.0},
		"visual": {"color": Color("#63b3ed"), "size": 16},
		"behavior": {"type": "support_shield", "priority": "center_of_allies", "stays_with_allies": true},
		"special": {"shield_radius": 2, "shield_effect": "ranged_immunity", "shields_die_on_death": true},
		"counters": ["bionic", "guardian"],
		"threats": ["ranger"],
	}


func _create_pirate_captain() -> Dictionary:
	return {
		"id": "pirate_captain",
		"name": "해적 대장",
		"tier": "boss",
		"budget": 20,
		"is_boss": true,
		"min_depth": 5,
		"stats": {"health": 15, "damage": 20, "speed": 45.0, "attack_speed": 1.8, "attack_range": 60.0},
		"visual": {"color": Color("#e53e3e"), "size": 35},
		"behavior": {"type": "boss_captain", "priority": "nearest_crew", "attacks_station": true},
		"phases": [
			{"health_threshold": 1.0, "pattern": "aggressive"},
			{"health_threshold": 0.5, "pattern": "summon"},
			{"health_threshold": 0.25, "pattern": "enraged"},
		],
		"reward": {"credits": 5, "equipment": true},
	}


func _create_storm_core() -> Dictionary:
	return {
		"id": "storm_core",
		"name": "폭풍 핵",
		"tier": "boss",
		"budget": 0,
		"is_boss": true,
		"invulnerable": true,
		"storm_only": true,
		"min_depth": 0,
		"stats": {"health": -1, "damage": 10, "speed": 0.0, "attack_speed": 5.0, "attack_range": 999.0},
		"visual": {"color": Color("#ed64a6"), "size": 50},
		"behavior": {"type": "boss_storm", "stationary": true, "attacks_station": true},
		"special": {"pulse_damage": 10, "pulse_interval": 10.0, "spawn_creatures_interval": 15.0, "retreat_condition": "all_waves_cleared"},
	}


func get_enemy(enemy_id: String) -> Dictionary:
	return _enemies.get(enemy_id, {})


func get_all_enemies() -> Array:
	return _enemies.keys()


func get_enemies_by_tier(tier: int) -> Array:
	var result: Array = []
	for enemy_id in _enemies:
		var enemy := _enemies[enemy_id] as Dictionary
		if enemy.get("tier") == tier:
			result.append(enemy)
	return result


func get_enemies_available_at_depth(depth: int, is_storm: bool = false) -> Array:
	var result: Array = []
	for enemy_id in _enemies:
		var enemy := _enemies[enemy_id] as Dictionary
		if enemy.get("min_depth", 0) > depth:
			continue
		if enemy.get("storm_only", false) and not is_storm:
			continue
		if enemy.get("is_boss", false):
			continue
		result.append(enemy)
	return result


func get_enemy_cost(enemy_id: String) -> int:
	return _enemies.get(enemy_id, {}).get("cost", 0)


func is_boss(enemy_id: String) -> bool:
	return _enemies.get(enemy_id, {}).get("is_boss", false)


# ===========================================
# 장비
# ===========================================

func _load_equipment() -> void:
	_equipment = {
		"command_module": _create_command_module(),
		"shock_wave": _create_shock_wave(),
		"frag_grenade": _create_frag_grenade(),
		"proximity_mine": _create_proximity_mine(),
		"rally_horn": _create_rally_horn(),
		"revive_kit": _create_revive_kit(),
		"stim_pack": _create_stim_pack(),
		"salvage_core": _create_salvage_core(),
		"shield_generator_equip": _create_shield_generator_equip(),
		"hacking_device": _create_hacking_device(),
	}


func _create_command_module() -> Dictionary:
	return {
		"id": "command_module",
		"name": "커맨드 모듈",
		"type": "passive",
		"base_cost": 60,
		"recommended_classes": ["ranger"],
		"levels": [
			{"level": 1, "squad_bonus": 3, "recovery_mult": 1.375, "upgrade_cost": 0},
			{"level": 2, "squad_bonus": 6, "recovery_mult": 1.75, "upgrade_cost": 16},
		],
	}


func _create_shock_wave() -> Dictionary:
	return {
		"id": "shock_wave",
		"name": "충격파",
		"type": "active_cooldown",
		"cooldown": 40.0,
		"base_cost": 75,
		"recommended_classes": ["sentinel", "guardian"],
		"friendly_fire": true,
		"levels": [
			{"level": 1, "damage": 20, "knockback": 2, "radius": 2.0, "jump_dist": 1, "upgrade_cost": 0},
			{"level": 2, "damage": 30, "knockback": 3, "radius": 2.5, "jump_dist": 2, "stun": 0.5, "upgrade_cost": 12},
		],
	}


func _create_frag_grenade() -> Dictionary:
	return {
		"id": "frag_grenade",
		"name": "파편 수류탄",
		"type": "active_charges",
		"base_cost": 60,
		"recommended_classes": ["ranger", "guardian"],
		"friendly_fire": true,
		"levels": [
			{"level": 1, "charges": 1, "damage": 40, "radius": 1.5, "range": 2.0, "upgrade_cost": 0},
			{"level": 2, "charges": 2, "damage": 45, "radius": 1.5, "range": 2.5, "upgrade_cost": 8},
			{"level": 3, "charges": 3, "damage": 50, "radius": 2.0, "range": 3.0, "upgrade_cost": 14},
		],
	}


func _create_proximity_mine() -> Dictionary:
	return {
		"id": "proximity_mine",
		"name": "근접 지뢰",
		"type": "active_charges",
		"base_cost": 55,
		"recommended_classes": ["engineer"],
		"levels": [
			{"level": 1, "charges": 1, "damage": 50, "radius": 1.5, "trigger_delay": 0.3, "upgrade_cost": 0},
			{"level": 2, "charges": 2, "damage": 55, "radius": 1.5, "trigger_delay": 0.2, "upgrade_cost": 8},
			{"level": 3, "charges": 3, "damage": 65, "radius": 2.0, "trigger_delay": 0.1, "upgrade_cost": 14},
		],
	}


func _create_rally_horn() -> Dictionary:
	return {
		"id": "rally_horn",
		"name": "랠리 혼",
		"type": "active_charges",
		"base_cost": 70,
		"recommended_classes": ["guardian"],
		"levels": [
			{"level": 1, "charges": 1, "heal_amount": 3, "upgrade_cost": 0},
			{"level": 2, "charges": 2, "heal_amount": 4, "upgrade_cost": 10},
			{"level": 3, "charges": 3, "heal_percent": 1.0, "upgrade_cost": 16},
		],
	}


func _create_revive_kit() -> Dictionary:
	return {
		"id": "revive_kit",
		"name": "리바이브 키트",
		"type": "active_charges",
		"base_cost": 100,
		"recommended_classes": ["guardian", "sentinel"],
		"levels": [
			{"level": 1, "charges": 1, "revive_health": 0.5, "scope": "campaign", "upgrade_cost": 0},
		],
	}


func _create_stim_pack() -> Dictionary:
	return {
		"id": "stim_pack",
		"name": "스팀 팩",
		"type": "passive",
		"base_cost": 65,
		"recommended_classes": ["bionic"],
		"levels": [
			{"level": 1, "attack_speed_mult": 1.25, "move_speed_mult": 1.1, "upgrade_cost": 0},
			{"level": 2, "attack_speed_mult": 1.5, "move_speed_mult": 1.2, "extra_action": true, "upgrade_cost": 14},
		],
	}


func _create_salvage_core() -> Dictionary:
	return {
		"id": "salvage_core",
		"name": "샐비지 코어",
		"type": "passive",
		"base_cost": 40,
		"levels": [
			{"level": 1, "bonus_credits": 1, "upgrade_cost": 0},
			{"level": 2, "bonus_credits": 2, "upgrade_cost": 5},
			{"level": 3, "bonus_credits": 3, "upgrade_cost": 9},
		],
	}


func _create_shield_generator_equip() -> Dictionary:
	return {
		"id": "shield_generator_equip",
		"name": "보호막 생성기",
		"type": "active_cooldown",
		"cooldown": 60.0,
		"base_cost": 85,
		"recommended_classes": ["sentinel", "ranger"],
		"levels": [
			{"level": 1, "duration": 5.0, "damage_reduction": 0.75, "upgrade_cost": 0},
			{"level": 2, "duration": 7.0, "damage_reduction": 0.9, "reflect": true, "upgrade_cost": 14},
		],
	}


func _create_hacking_device() -> Dictionary:
	return {
		"id": "hacking_device",
		"name": "해킹 장치",
		"type": "active_charges",
		"base_cost": 70,
		"recommended_classes": ["engineer"],
		"levels": [
			{"level": 1, "charges": 1, "hack_range": 3, "hack_time": 3.0, "targets": ["turret"], "upgrade_cost": 0},
			{"level": 2, "charges": 2, "hack_range": 4, "hack_time": 2.5, "targets": ["turret", "small_drone"], "upgrade_cost": 10},
			{"level": 3, "charges": 3, "hack_range": 5, "hack_time": 2.0, "targets": ["turret", "small_drone", "large_drone"], "upgrade_cost": 16},
		],
	}


func get_equipment(equipment_id: String) -> Dictionary:
	return _equipment.get(equipment_id, {})


func get_all_equipment() -> Array:
	return _equipment.keys()


func get_equipment_effect(equipment_id: String, level: int) -> Dictionary:
	var equip := get_equipment(equipment_id)
	if equip.is_empty():
		return {}
	var levels: Array = equip.get("levels", [])
	var idx := mini(level, levels.size()) - 1
	if idx >= 0 and idx < levels.size():
		return levels[idx]
	return {}


# ===========================================
# 특성
# ===========================================

func _load_traits() -> void:
	_traits = {
		# 전투
		"sharp_edge": {"id": "sharp_edge", "name": "날카로운 공격", "category": "combat", "effect": {"damage_mult": 1.2, "knockback_mult": 0.7}},
		"heavy_impact": {"id": "heavy_impact", "name": "강력한 충격", "category": "combat", "effect": {"knockback_mult": 1.5, "stun_duration_mult": 1.5}},
		"titan_frame": {"id": "titan_frame", "name": "타이탄 프레임", "category": "combat", "effect": {"leader_health_mult": 3.0}},
		"reinforced_armor": {"id": "reinforced_armor", "name": "강화 장갑", "category": "combat", "effect": {"damage_reduction": 0.25}},
		"steady_stance": {"id": "steady_stance", "name": "안정된 자세", "category": "combat", "effect": {"knockback_resist": 0.8, "stun_resist": 0.8}},
		"fearless": {"id": "fearless", "name": "두려움 없음", "category": "combat", "effect": {"cannot_retreat": true, "morale_bonus": 1.5}, "warning": "철수 불가능!"},

		# 유틸리티
		"energetic": {"id": "energetic", "name": "활력 넘침", "category": "utility", "effect": {"skill_cooldown_mult": 0.67}},
		"swift_movement": {"id": "swift_movement", "name": "빠른 이동", "category": "utility", "effect": {"move_speed_mult": 1.33}},
		"popular": {"id": "popular", "name": "인기 많음", "category": "utility", "effect": {"squad_size_bonus": 1}},
		"quick_recovery": {"id": "quick_recovery", "name": "빠른 회복", "category": "utility", "effect": {"recovery_time_mult": 0.67}},
		"tech_savvy": {"id": "tech_savvy", "name": "기술 숙련", "category": "utility", "effect": {"turret_damage_mult": 1.5, "turret_health_mult": 1.5}},

		# 경제
		"skillful": {"id": "skillful", "name": "숙련됨", "category": "economy", "effect": {"skill_upgrade_cost_mult": 0.5}},
		"collector": {"id": "collector", "name": "수집가", "category": "economy", "effect": {"equipment_upgrade_cost_mult": 0.5}},
		"heavy_load": {"id": "heavy_load", "name": "무거운 짐", "category": "economy", "effect": {"bonus_charges": 1}},
		"salvager": {"id": "salvager", "name": "약탈자", "category": "economy", "effect": {"credit_per_kill": 0.1}},
	}


func get_trait(trait_id: String) -> Dictionary:
	return _traits.get(trait_id, {})


func get_all_traits() -> Array:
	return _traits.keys()


func get_traits_by_category(category: String) -> Array:
	var result: Array = []
	for trait_id in _traits:
		var t := _traits[trait_id] as Dictionary
		if t.get("category") == category:
			result.append(t)
	return result


func get_random_trait(stream: String = RngManager.STREAM_TRAITS, exclude: Array = []) -> String:
	var available: Array = []
	for trait_id in _traits:
		if trait_id not in exclude:
			available.append(trait_id)

	if available.is_empty():
		return ""

	return RngManager.pick(stream, available)


# ===========================================
# 시설
# ===========================================

func _load_facilities() -> void:
	_facilities = {
		"residential_s": {"id": "residential_s", "name": "소형 주거 모듈", "credits": 1},
		"residential_m": {"id": "residential_m", "name": "중형 주거 모듈", "credits": 2},
		"residential_l": {"id": "residential_l", "name": "대형 주거 모듈", "credits": 3},
		"medical": {"id": "medical", "name": "의료 시설", "credits": 2},
		"armory": {"id": "armory", "name": "무기고", "credits": 2},
		"comm_tower": {"id": "comm_tower", "name": "통신 중계소", "credits": 2},
		"power_plant": {"id": "power_plant", "name": "발전소", "credits": 3},
	}


func get_facility(facility_id: String) -> Dictionary:
	return _facilities.get(facility_id, {})


func get_facility_credits(facility_id: String) -> int:
	return _facilities.get(facility_id, {}).get("credits", 0)
