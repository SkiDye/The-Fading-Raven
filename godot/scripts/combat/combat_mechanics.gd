## CombatMechanics - 전투 메카닉 처리
## Bad North 스타일 전투 시스템의 핵심 로직
extends RefCounted
class_name CombatMechanics

# ===========================================
# 전투 상태 열거형
# ===========================================

enum CombatState {
	IDLE,           # 대기
	MOVING,         # 이동 중
	ENGAGING,       # 교전 중
	RECOVERING,     # 회복 중
	DISABLED,       # 무력화 (Lance Raise 등)
}

enum DamageType {
	MELEE,
	RANGED,
	EXPLOSIVE,
	VOID,           # 우주 추락
}


# ===========================================
# 데미지 계산
# ===========================================

## 기본 데미지 계산
static func calculate_damage(
	base_damage: int,
	damage_type: DamageType,
	attacker: Dictionary,
	defender: Dictionary,
	grid: TileGrid
) -> int:
	var damage := base_damage

	# 공격자 보너스
	damage = _apply_attacker_bonuses(damage, attacker)

	# 방어자 감소
	damage = _apply_defender_reductions(damage, damage_type, defender, grid)

	# 최소 1 데미지
	return maxi(1, damage)


static func _apply_attacker_bonuses(damage: int, attacker: Dictionary) -> int:
	var result := float(damage)

	# 랭크 보너스
	var rank: String = attacker.get("rank", "standard")
	var rank_bonus: Dictionary = Balance.ECONOMY["rank_bonuses"].get(rank, {})
	result *= 1.0 + rank_bonus.get("damage_bonus", 0.0)

	# 특성 보너스
	var trait_id: String = attacker.get("trait_id", "")
	if trait_id == "sharp_edge":
		result *= 1.1

	# 높은 지형 보너스
	if attacker.get("is_elevated", false):
		result *= Balance.ELEVATED_TERRAIN["damage_bonus"]

	return int(result)


static func _apply_defender_reductions(
	damage: int,
	damage_type: DamageType,
	defender: Dictionary,
	grid: TileGrid
) -> int:
	var result := float(damage)

	# 엄폐 보너스
	var pos: Vector2i = defender.get("position", Vector2i.ZERO)
	if grid and grid.provides_cover_v(pos):
		if damage_type == DamageType.RANGED:
			result *= (1.0 - Balance.COMBAT["cover_damage_reduction"])

	# 가디언 실드 블록 (근접 교전 중이 아닐 때만)
	if defender.get("class_id") == "guardian" and not defender.get("in_melee", false):
		if damage_type == DamageType.RANGED:
			result *= (1.0 - Balance.SHIELD["block_chance"])

	# 방어 특성
	var trait_id: String = defender.get("trait_id", "")
	if trait_id == "iron_skin":
		result *= 0.9

	return int(result)


# ===========================================
# Bad North 핵심 메카닉
# ===========================================

## 실드 블록 체크 (가디언)
## 근접 교전 중에는 실드가 비활성화됨
static func check_shield_block(
	defender: Dictionary,
	damage_type: DamageType,
	rng_stream: String = RngManager.STREAM_COMBAT
) -> bool:
	# 가디언만 실드 보유
	if defender.get("class_id") != "guardian":
		return false

	# 근접 교전 중이면 실드 비활성화
	if defender.get("in_melee", false):
		return false

	# 원거리 공격만 블록 가능
	if damage_type != DamageType.RANGED:
		return false

	# 확률 체크
	return RngManager.chance(rng_stream, Balance.SHIELD["block_chance"])


## 랜스 상태 체크 (센티넬)
## 적이 너무 가까우면 랜스가 무력화됨
static func check_lance_state(
	crew_position: Vector2,
	nearest_enemy_distance: float
) -> Dictionary:
	var grapple_range: float = Balance.LANCE["grapple_range"]
	var is_raised := nearest_enemy_distance > grapple_range

	return {
		"is_raised": is_raised,
		"is_disabled": not is_raised,
		"nearest_distance": nearest_enemy_distance,
		"grapple_range": grapple_range,
	}


## 상륙 넉백 계산
## 적 상륙 시 방어 크루를 밀어냄
static func calculate_landing_knockback(
	landing_position: Vector2,
	defender_position: Vector2,
	grid: TileGrid
) -> Dictionary:
	var distance := landing_position.distance_to(defender_position)
	var knockback_range: float = Balance.LANDING_KNOCKBACK["range"]

	if distance > knockback_range:
		return {"applied": false}

	# 넉백 방향
	var direction := (defender_position - landing_position).normalized()
	var knockback_distance: int = Balance.LANDING_KNOCKBACK["distance"]

	# 넉백 목표 위치
	var target := Vector2i(
		int(defender_position.x + direction.x * knockback_distance),
		int(defender_position.y + direction.y * knockback_distance)
	)

	# 유효성 검사
	var is_void := grid.is_void_v(target)
	var is_valid := grid.is_walkable_v(target) or is_void

	return {
		"applied": true,
		"direction": direction,
		"target_position": target,
		"is_void_death": is_void,
		"is_valid": is_valid,
	}


## 회복 시간 계산
## 분대원 수에 비례
static func calculate_recovery_time(squad_size: int) -> float:
	return Balance.RECOVERY["base_time"] * squad_size


## Void 데스 체크
## 우주 공간으로 넉백되면 즉사
static func check_void_death(position: Vector2i, grid: TileGrid) -> bool:
	return grid.is_void_v(position)


# ===========================================
# 교전 판정
# ===========================================

## 근접 교전 시작 조건
static func should_engage_melee(
	attacker_pos: Vector2,
	defender_pos: Vector2,
	attacker_data: Dictionary
) -> bool:
	var distance := attacker_pos.distance_to(defender_pos)
	var melee_range: float = Balance.MELEE["engage_range"]

	# 클래스별 교전 거리 수정
	var class_id: String = attacker_data.get("class_id", "")
	if class_id == "guardian":
		melee_range *= 1.2  # 가디언은 약간 더 넓은 교전 범위

	return distance <= melee_range


## 원거리 공격 가능 여부
static func can_attack_ranged(
	attacker_pos: Vector2i,
	target_pos: Vector2i,
	attacker_data: Dictionary,
	grid: TileGrid
) -> Dictionary:
	var class_id: String = attacker_data.get("class_id", "")
	var class_data: Dictionary = DataRegistry.get_crew_class(class_id)

	# 원거리 공격 가능한 클래스인지
	if class_data.get("attack_type") != "ranged":
		return {"can_attack": false, "reason": "not_ranged_class"}

	# 사거리 체크
	var range_val: int = class_data.get("attack_range", 0)
	var distance := _tile_distance(attacker_pos, target_pos)

	if distance > range_val:
		return {"can_attack": false, "reason": "out_of_range", "distance": distance, "range": range_val}

	# 시야 체크
	if not grid.has_line_of_sight(attacker_pos, target_pos):
		return {"can_attack": false, "reason": "no_line_of_sight"}

	# 높은 지형 사거리 보너스
	var effective_range := range_val
	if grid.is_elevated_v(attacker_pos):
		effective_range += Balance.ELEVATED_TERRAIN["range_bonus"]

	return {
		"can_attack": true,
		"distance": distance,
		"range": range_val,
		"effective_range": effective_range,
	}


static func _tile_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


# ===========================================
# 스킬 사용
# ===========================================

## 스킬 사용 가능 여부
static func can_use_skill(
	crew_data: Dictionary,
	skill_level: int
) -> Dictionary:
	if skill_level <= 0:
		return {"can_use": false, "reason": "skill_not_unlocked"}

	# 쿨다운 체크
	var cooldown: float = crew_data.get("skill_cooldown", 0.0)
	if cooldown > 0:
		return {"can_use": false, "reason": "on_cooldown", "remaining": cooldown}

	# 사용 횟수 체크 (일부 스킬)
	var class_id: String = crew_data.get("class_id", "")
	var charges_used: Dictionary = crew_data.get("charges_used", {})
	var max_charges: int = _get_skill_max_charges(class_id, skill_level)

	if max_charges > 0:
		var used: int = charges_used.get("skill", 0)
		if used >= max_charges:
			return {"can_use": false, "reason": "no_charges", "used": used, "max": max_charges}

	return {"can_use": true}


static func _get_skill_max_charges(class_id: String, skill_level: int) -> int:
	# 무한 사용 가능한 스킬은 0 반환
	match class_id:
		"ranger":
			return 0  # 연사는 쿨다운만 있음
		"engineer":
			return [0, 2, 3, 4][skill_level]  # 터렛 설치 횟수
		_:
			return 0


## 스킬 쿨다운 가져오기
static func get_skill_cooldown(class_id: String, skill_level: int) -> float:
	var class_data: Dictionary = DataRegistry.get_crew_class(class_id)
	var skill: Dictionary = class_data.get("skill", {})
	var cooldowns: Array = skill.get("cooldown", [])

	if skill_level > 0 and skill_level <= cooldowns.size():
		return cooldowns[skill_level - 1]

	return 0.0


# ===========================================
# 유닛 상성
# ===========================================

## 유닛 상성 배율 계산
static func get_matchup_multiplier(attacker_class: String, defender_type: String) -> float:
	# 가디언: 근접 적에게 강함
	# 센티넬: 돌격 적에게 강함 (진입 차단)
	# 레인저: 중장갑에 약함, 경장갑에 강함

	match attacker_class:
		"guardian":
			if defender_type in ["rusher", "brute", "berserker"]:
				return 1.3
		"sentinel":
			if defender_type in ["rusher", "leaper"]:
				return 1.5
		"ranger":
			if defender_type in ["rusher", "infiltrator"]:
				return 1.2
			if defender_type in ["brute", "heavy_gunner", "shieldbearer"]:
				return 0.7

	return 1.0


# ===========================================
# 전투 결과 판정
# ===========================================

## 분대원 사상자 계산
static func calculate_casualties(
	damage_taken: int,
	squad_size: int,
	defender_data: Dictionary
) -> Dictionary:
	# 기본: damage_per_member HP당 1명 사망
	var hp_per_member := 10  # 분대원당 HP

	var casualties := damage_taken / hp_per_member
	var remaining_damage := damage_taken % hp_per_member

	# 특성: 끈질긴 (사상자 감소)
	if defender_data.get("trait_id") == "tenacious":
		casualties = maxi(0, casualties - 1)

	casualties = mini(casualties, squad_size)
	var remaining := squad_size - casualties
	var is_wiped := remaining <= 0

	return {
		"casualties": casualties,
		"remaining": remaining,
		"is_wiped": is_wiped,
		"overkill_damage": remaining_damage if not is_wiped else 0,
	}


## 전투 종료 보상 계산
static func calculate_battle_rewards(
	stats: Dictionary,
	difficulty: int,
	is_perfect: bool
) -> Dictionary:
	var base_credits: int = Balance.REWARDS["base_station_clear"]

	# 킬 보너스
	var kill_credits: int = stats.get("enemies_killed", 0) * Balance.REWARDS["per_enemy_kill"]

	# 완벽 방어 보너스
	var perfect_bonus := 0
	if is_perfect:
		perfect_bonus = int(base_credits * Balance.REWARDS["perfect_defense_bonus"])

	# 난이도 배율
	var diff_config: Dictionary = Balance.get_difficulty_config(difficulty)
	var diff_multiplier: float = diff_config.get("reward_multiplier", 1.0)

	var total := int((base_credits + kill_credits + perfect_bonus) * diff_multiplier)

	return {
		"base_credits": base_credits,
		"kill_credits": kill_credits,
		"perfect_bonus": perfect_bonus,
		"difficulty_multiplier": diff_multiplier,
		"total": total,
	}
