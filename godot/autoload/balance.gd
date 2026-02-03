## Balance - 게임 밸런스 상수
## GDD 14장 밸런싱 수치 기준
extends Node

# ===========================================
# 난이도 설정
# ===========================================

enum Difficulty { NORMAL, HARD, VERYHARD, NIGHTMARE }

const DIFFICULTY_CONFIG := {
	Difficulty.NORMAL: {
		"id": "normal",
		"name": "보통",
		"enemy_health_mult": 1.0,
		"enemy_damage_mult": 1.0,
		"enemy_count_mult": 1.0,
		"wave_count_bonus": 0,
		"credit_mult": 1.0,
		"score_mult": 1.0,
		"unlock_requirement": null,
	},
	Difficulty.HARD: {
		"id": "hard",
		"name": "어려움",
		"enemy_health_mult": 1.25,
		"enemy_damage_mult": 1.25,
		"enemy_count_mult": 1.5,
		"wave_count_bonus": 1,
		"credit_mult": 1.25,
		"score_mult": 1.5,
		"unlock_requirement": "normal_cleared",
	},
	Difficulty.VERYHARD: {
		"id": "veryhard",
		"name": "매우 어려움",
		"enemy_health_mult": 1.5,
		"enemy_damage_mult": 1.5,
		"enemy_count_mult": 2.0,
		"wave_count_bonus": 2,
		"credit_mult": 1.5,
		"score_mult": 2.0,
		"unlock_requirement": "hard_cleared",
	},
	Difficulty.NIGHTMARE: {
		"id": "nightmare",
		"name": "악몽",
		"enemy_health_mult": 2.0,
		"enemy_damage_mult": 1.75,
		"enemy_count_mult": 2.5,
		"wave_count_bonus": 3,
		"credit_mult": 2.0,
		"score_mult": 3.0,
		"unlock_requirement": "veryhard_cleared",
	},
}

# ===========================================
# 경제 시스템
# ===========================================

const ECONOMY := {
	"starting_credits": 0,
	"heal_cost": 12,
	"heal_amount": 2,
	"perfect_defense_bonus": 5,
	"boss_kill_bonus": 5,

	# 스킬 업그레이드 비용
	"skill_upgrade_costs": {
		1: 7,
		2: 10,
		3: 14,
	},

	# 랭크업 비용
	"rank_up_costs": {
		"standard": 0,
		"veteran": 100,
		"elite": 200,
	},

	# 랭크 보너스
	"rank_bonuses": {
		"veteran": {
			"max_squad_bonus": 1,
			"damage_mult": 1.1,
			"accuracy_bonus": 0.15,
		},
		"elite": {
			"max_squad_bonus": 2,
			"damage_mult": 1.2,
			"accuracy_bonus": 0.25,
		},
	},
}

# ===========================================
# 전투 메카닉 (Bad North 핵심)
# ===========================================

const COMBAT := {
	# 슬로우 모션 (크루 선택 시)
	"slow_motion_factor": 0.25,

	# 기본 쿨다운
	"skill_cooldown_base": 10.0,  # 초

	# 넉백
	"knockback_base": 50.0,  # 픽셀
	"knockback_decay": 0.9,

	# 스턴
	"stun_duration_base": 1.0,  # 초

	# 보충 시스템 (Bad North: 2초 × 분대원 수)
	"recovery_time_per_member": 2.0,  # 초
	"recovery_time_base": 5.0,

	# 분대 포메이션
	"formation_spread": 15.0,  # 픽셀

	# 프렌들리 파이어
	"friendly_fire_mult": 0.3,

	# 우주 공간 추락 (즉사)
	"void_damage": 9999,

	# 엄폐 데미지 감소
	"cover_damage_reduction": 0.3,
}

# ===========================================
# 회복 시스템
# ===========================================

const RECOVERY := {
	"base_time": 2.0,  # 분대원당 회복 시간 (초)
	"facility_required": true,
}

# ===========================================
# 높은 지형 보너스
# ===========================================

const ELEVATED_TERRAIN := {
	"damage_bonus": 1.15,  # 15% 데미지 증가
	"range_bonus": 2,      # 사거리 +2 타일
	"accuracy_bonus": 0.1, # 명중률 10% 증가
}

# ===========================================
# 보상 시스템
# ===========================================

const REWARDS := {
	"base_station_clear": 10,  # 기본 스테이션 클리어 보상
	"per_enemy_kill": 1,       # 적 처치당 보상
	"perfect_defense_bonus": 0.5,  # 완벽 방어 보너스 (비율)
}

# ===========================================
# 시설
# ===========================================

const FACILITY := {
	"health": 100,
	"repair_cost": 20,
	"repair_amount": 50,
}

# ===========================================
# 상륙 넉백 시스템 (Bad North)
# ===========================================

const LANDING_KNOCKBACK := {
	"base_knockback": 80.0,
	"range": 60.0,     # 넉백 영향 범위 (픽셀)
	"distance": 2,     # 넉백 거리 (타일)

	# 보트 크기 배율
	"boat_size_mult": {
		"small": 0.5,   # 1-3 적
		"medium": 1.0,  # 4-6 적
		"large": 1.5,   # 7-10 적
		"xlarge": 2.0,  # 11+ 적
	},

	# 적 수 팩터
	"enemy_count_factor": 0.1,

	# 유닛 등급 저항
	"grade_resistance": {
		"standard": 1.0,
		"veteran": 1.5,
		"elite": 2.0,
	},

	# 넉백 임계값
	"weak_threshold": 30.0,
	"strong_threshold": 60.0,
	"stun_duration": 1.5,

	# Steady Stance 특성 저항
	"steady_stance_resist": 0.8,
}

# ===========================================
# 실드 메카닉 (Guardian - Bad North)
# ===========================================

const SHIELD := {
	# 원거리 데미지 감소 (교전 중이 아닐 때)
	"ranged_damage_reduction": 0.9,
	"block_chance": 0.9,  # 블록 확률 (combat_mechanics.gd용)

	# 근접전 중 실드 비활성화 (핵심!)
	"disabled_during_melee": true,

	# 실드 방향 (전방만 방어)
	"facing_angle": 90.0,  # 도
}

# ===========================================
# 랜스 메카닉 (Sentinel - Bad North "Lance Raise")
# ===========================================

const LANCE := {
	# 적이 너무 가까이 오면 랜스를 들어올림
	"grapple_range": 30.0,  # 픽셀 (combat_mechanics.gd 참조용)
	"grappling_range": 30.0,  # 픽셀

	# 랜스를 들어올린 상태
	"raised_can_attack": false,
	"raised_can_move": true,

	# 최적 사거리 보너스
	"optimal_range_bonus": 1.5,
	"optimal_range_min": 40.0,
	"optimal_range_max": 80.0,
}

# ===========================================
# 근접전 상태
# ===========================================

const MELEE := {
	"engage_range": 25.0,  # 픽셀
	"disengage_distance": 50.0,
}

# ===========================================
# 웨이브 생성
# ===========================================

const WAVE := {
	"base_budget": 10,
	"budget_per_turn": 3,  # 턴당 예산 증가
	"budget_per_wave": 2,

	"base_waves": 2,       # 기본 웨이브 수
	"max_waves": 5,        # 최대 웨이브 수

	"min_enemies": 3,
	"max_enemies": 30,

	"spawn_stagger_ms": 300,
	"initial_delay": 3.0,   # 첫 웨이브 딜레이 (초)
	"wave_interval": 5.0,   # 웨이브 간 딜레이 (초)
	"boss_spawn_delay": 5.0,

	# 티어 해금 깊이
	"tier_unlock_depth": {
		1: 0,
		2: 3,
		3: 5,
	},

	# 보스 간격
	"boss_depth_interval": 5,
}

# ===========================================
# 캠페인 진행
# ===========================================

const PROGRESSION := {
	# 섹터 깊이 (난이도별)
	"sector_depth": {
		"normal": {"min": 12, "max": 15},
		"hard": {"min": 15, "max": 18},
		"veryhard": {"min": 18, "max": 22},
		"nightmare": {"min": 22, "max": 25},
	},

	# 깊이당 노드 수
	"nodes_per_depth": {
		"normal": {"min": 2, "max": 3},
		"hard": {"min": 2, "max": 4},
		"veryhard": {"min": 3, "max": 4},
		"nightmare": {"min": 3, "max": 5},
	},

	# Storm Front
	"storm_advance_rate": 1,
	"storm_start_depth": 0,

	# 이벤트 분포
	"event_distribution": {
		"battle": 50,
		"elite": 10,
		"shop": 15,
		"event": 15,
		"rest": 10,
	},
}

# ===========================================
# Raven 드론
# ===========================================

const RAVEN := {
	"scout_uses": -1,  # 무제한
	"flare_uses": 2,
	"resupply_uses": 1,
	"orbital_strike_uses": 1,

	"flare_duration": 10.0,
	"resupply_heal_percent": 1.0,

	"orbital_strike": {
		"damage": 50,
		"radius": 1.5,
		"delay": 2.0,
		"friendly_fire": true,
	},
}

# ===========================================
# 정거장 레이아웃
# ===========================================

const STATION := {
	"map_sizes": {
		"small": {"width": 5, "height": 5, "facilities_min": 2, "facilities_max": 3},
		"medium": {"width": 7, "height": 7, "facilities_min": 3, "facilities_max": 4},
		"large": {"width": 9, "height": 9, "facilities_min": 4, "facilities_max": 5},
		"xlarge": {"width": 11, "height": 11, "facilities_min": 5, "facilities_max": 6},
	},

	"size_thresholds": {
		"small": 0.0,
		"medium": 2.0,
		"large": 3.0,
		"xlarge": 4.5,
	},

	"min_spawn_points": 2,
	"max_spawn_points": 4,
}

# ===========================================
# 점수 계산
# ===========================================

const SCORING := {
	"station_defended": 500,
	"perfect_defense": 200,
	"enemy_killed": 10,
	"credits_earned": 5,
	"crew_lost": -1000,
}

# ===========================================
# 유닛 등급 스탯
# ===========================================

const UNIT_GRADES := {
	"standard": {
		"attack_power": 1.0,
		"defense": 1.0,
		"move_speed": 1.0,
		"attack_speed": 1.0,
		"max_squad_size": 8,
		"knockback_resist": 1.0,
		"morale": 1.0,
	},
	"veteran": {
		"attack_power": 1.15,
		"defense": 1.2,
		"move_speed": 1.05,
		"attack_speed": 1.1,
		"max_squad_size": 9,
		"knockback_resist": 1.5,
		"morale": 1.3,
	},
	"elite": {
		"attack_power": 1.35,
		"defense": 1.4,
		"move_speed": 1.1,
		"attack_speed": 1.2,
		"max_squad_size": 10,
		"knockback_resist": 2.0,
		"morale": 1.6,
	},
}

# ===========================================
# API 함수
# ===========================================

func get_difficulty_config(difficulty: Difficulty) -> Dictionary:
	return DIFFICULTY_CONFIG.get(difficulty, DIFFICULTY_CONFIG[Difficulty.NORMAL])


func get_wave_config(depth: int, difficulty: Difficulty) -> Dictionary:
	var diff := get_difficulty_config(difficulty)
	var base_budget := WAVE["base_budget"] + (depth * WAVE["budget_per_depth"])
	var budget := int(base_budget * diff["enemy_count_mult"])

	return {
		"budget": budget,
		"wave_count": 2 + int(depth / 3) + diff["wave_count_bonus"],
		"min_enemies": WAVE["min_enemies"],
		"max_enemies": WAVE["max_enemies"],
		"tier1_available": depth >= WAVE["tier_unlock_depth"][1],
		"tier2_available": depth >= WAVE["tier_unlock_depth"][2],
		"tier3_available": depth >= WAVE["tier_unlock_depth"][3],
	}


func calculate_recovery_time(squad_size: int, has_quick_recovery: bool = false) -> float:
	var base_time := squad_size * COMBAT["recovery_time_per_member"]
	return base_time * (0.67 if has_quick_recovery else 1.0)


func calculate_landing_knockback(config: Dictionary) -> Dictionary:
	var boat_size: String = config.get("boat_size", "medium")
	var enemy_count: int = config.get("enemy_count", 5)
	var unit_grade: String = config.get("unit_grade", "standard")
	var has_steady_stance: bool = config.get("has_steady_stance", false)

	var size_mult: float = LANDING_KNOCKBACK["boat_size_mult"].get(boat_size, 1.0)
	var count_factor: float = 1.0 + (enemy_count * LANDING_KNOCKBACK["enemy_count_factor"])
	var grade_resist: float = LANDING_KNOCKBACK["grade_resistance"].get(unit_grade, 1.0)

	var knockback_px: float = (LANDING_KNOCKBACK["base_knockback"] * size_mult * count_factor) / grade_resist

	if has_steady_stance:
		knockback_px *= (1.0 - LANDING_KNOCKBACK["steady_stance_resist"])

	var is_weak := knockback_px < LANDING_KNOCKBACK["weak_threshold"]
	var is_strong := knockback_px >= LANDING_KNOCKBACK["strong_threshold"]

	return {
		"knockback_px": int(knockback_px),
		"is_weak": is_weak,
		"is_strong": is_strong,
		"stun_duration": LANDING_KNOCKBACK["stun_duration"] if is_strong else 0.0,
	}


func get_boat_size_category(enemy_count: int) -> String:
	if enemy_count <= 3:
		return "small"
	elif enemy_count <= 6:
		return "medium"
	elif enemy_count <= 10:
		return "large"
	else:
		return "xlarge"


func is_in_melee_combat(distance: float) -> bool:
	return distance <= MELEE["engage_range"]


func check_shield_block(is_in_melee: bool, facing_angle: float, attack_angle: float) -> Dictionary:
	if SHIELD["disabled_during_melee"] and is_in_melee:
		return {"blocked": false, "damage_reduction": 0.0}

	var angle_diff := abs(facing_angle - attack_angle)
	var normalized_diff := angle_diff if angle_diff <= 180.0 else 360.0 - angle_diff

	if normalized_diff <= SHIELD["facing_angle"] / 2.0:
		return {"blocked": true, "damage_reduction": SHIELD["ranged_damage_reduction"]}

	return {"blocked": false, "damage_reduction": 0.0}


func check_lance_state(distance_to_enemy: float) -> Dictionary:
	# 적이 너무 가까우면 랜스를 들어올림 (무력화)
	if distance_to_enemy <= LANCE["grappling_range"]:
		return {
			"lance_raised": true,
			"can_attack": LANCE["raised_can_attack"],
			"damage_mult": 0.0,
		}

	# 최적 사거리 보너스
	if distance_to_enemy >= LANCE["optimal_range_min"] and distance_to_enemy <= LANCE["optimal_range_max"]:
		return {
			"lance_raised": false,
			"can_attack": true,
			"damage_mult": LANCE["optimal_range_bonus"],
		}

	return {
		"lance_raised": false,
		"can_attack": true,
		"damage_mult": 1.0,
	}


func get_unit_grade_stats(grade: String) -> Dictionary:
	return UNIT_GRADES.get(grade, UNIT_GRADES["standard"])


func get_map_size_for_score(score: float) -> String:
	if score >= STATION["size_thresholds"]["xlarge"]:
		return "xlarge"
	elif score >= STATION["size_thresholds"]["large"]:
		return "large"
	elif score >= STATION["size_thresholds"]["medium"]:
		return "medium"
	return "small"


func calculate_final_score(stats: Dictionary, difficulty: Difficulty) -> int:
	var diff := get_difficulty_config(difficulty)

	var score := 0
	score += stats.get("stations_defended", 0) * SCORING["station_defended"]
	score += stats.get("perfect_defenses", 0) * SCORING["perfect_defense"]
	score += stats.get("enemies_killed", 0) * SCORING["enemy_killed"]
	score += stats.get("credits_earned", 0) * SCORING["credits_earned"]
	score += stats.get("crews_lost", 0) * SCORING["crew_lost"]

	return maxi(0, int(score * diff["score_mult"]))
