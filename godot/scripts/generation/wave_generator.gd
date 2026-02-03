## WaveGenerator - 웨이브 생성
## 예산 기반 적 구성 및 스폰 패턴
extends RefCounted
class_name WaveGenerator

# ===========================================
# 웨이브 템플릿
# ===========================================

const WAVE_TEMPLATES := {
	"standard": {
		"weights": {"rusher": 3, "gunner": 2, "brute": 1},
		"min_types": 1,
		"max_types": 3,
	},
	"rush": {
		"weights": {"rusher": 5, "jumper": 2},
		"min_types": 1,
		"max_types": 2,
	},
	"heavy": {
		"weights": {"brute": 3, "heavy_trooper": 2, "shield_trooper": 1},
		"min_types": 1,
		"max_types": 2,
	},
	"ranged": {
		"weights": {"sniper": 3, "gunner": 2},
		"min_types": 1,
		"max_types": 2,
	},
	"elite": {
		"weights": {"brute": 2, "sniper": 2, "drone_carrier": 1},
		"min_types": 2,
		"max_types": 3,
	},
	"swarm": {
		"weights": {"rusher": 10},
		"min_types": 1,
		"max_types": 1,
	},
}

# 턴별 사용 가능 적 티어
const TURN_ENEMY_TIERS := {
	1: ["tier1"],
	2: ["tier1"],
	3: ["tier1", "tier2"],
	4: ["tier1", "tier2"],
	5: ["tier1", "tier2", "tier3"],
	6: ["tier1", "tier2", "tier3"],
}

# 적 티어 분류 (data_registry.gd와 일치)
const ENEMY_TIERS := {
	"tier1": ["rusher", "gunner", "shield_trooper"],
	"tier2": ["jumper", "heavy_trooper", "hacker", "storm_creature"],
	"tier3": ["brute", "sniper", "drone_carrier", "shield_generator"],
}


# ===========================================
# 웨이브 생성
# ===========================================

## 전체 웨이브 데이터 생성
static func generate_waves(
	turn: int,
	difficulty: int,
	airlock_count: int
) -> Array[Dictionary]:
	var waves: Array[Dictionary] = []

	# 웨이브 수 결정
	var wave_count := _calculate_wave_count(turn, difficulty)

	# 총 예산 계산
	var total_budget := _calculate_total_budget(turn, difficulty)
	var budget_per_wave := total_budget / wave_count

	for i in range(wave_count):
		# 후반 웨이브일수록 예산 증가
		var wave_budget := int(budget_per_wave * (1.0 + i * 0.2))

		# 웨이브 생성
		var wave := _generate_single_wave(i, wave_budget, turn, difficulty, airlock_count)
		waves.append(wave)

	return waves


## 단일 웨이브 생성
static func _generate_single_wave(
	wave_index: int,
	budget: int,
	turn: int,
	difficulty: int,
	airlock_count: int
) -> Dictionary:
	# 템플릿 선택
	var template_name := _select_template(wave_index, turn)
	var template: Dictionary = WAVE_TEMPLATES[template_name]

	# 사용 가능한 적 타입 필터링
	var available_enemies := _get_available_enemies(turn, template)

	# 적 구성 생성
	var enemies := _fill_wave_with_enemies(budget, available_enemies)

	# 스폰 그룹 분배
	var spawn_groups := _distribute_to_spawn_groups(enemies, airlock_count)

	return {
		"index": wave_index,
		"template": template_name,
		"budget": budget,
		"enemies": enemies,
		"spawn_groups": spawn_groups,
		"delay_before": _get_wave_delay(wave_index),
	}


# ===========================================
# 예산 계산
# ===========================================

static func _calculate_wave_count(turn: int, difficulty: int) -> int:
	var base := Balance.WAVE["base_waves"]
	var turn_bonus := (turn - 1) / 3  # 3턴마다 웨이브 +1

	var diff_config: Dictionary = Balance.get_difficulty_config(difficulty)
	var diff_bonus: int = diff_config.get("extra_waves", 0)

	return mini(base + turn_bonus + diff_bonus, Balance.WAVE["max_waves"])


static func _calculate_total_budget(turn: int, difficulty: int) -> int:
	var base := Balance.WAVE["base_budget"]
	var scaling := Balance.WAVE["budget_per_turn"]

	var budget := base + (turn - 1) * scaling

	# 난이도 배율
	var diff_config: Dictionary = Balance.get_difficulty_config(difficulty)
	budget = int(budget * diff_config.get("enemy_stat_multiplier", 1.0))

	return budget


# ===========================================
# 템플릿 선택
# ===========================================

static func _select_template(wave_index: int, turn: int) -> String:
	var templates := WAVE_TEMPLATES.keys()

	# 첫 웨이브는 표준
	if wave_index == 0:
		return "standard"

	# 턴이 진행될수록 다양한 템플릿
	var available: Array[String] = ["standard"]

	if turn >= 2:
		available.append("rush")
	if turn >= 3:
		available.append("heavy")
		available.append("ranged")
	if turn >= 5:
		available.append("elite")
	if turn >= 4 and wave_index > 0:
		available.append("swarm")

	return RngManager.pick(RngManager.STREAM_ENEMY_WAVES, available)


# ===========================================
# 적 선택
# ===========================================

static func _get_available_enemies(turn: int, template: Dictionary) -> Array[Dictionary]:
	var available: Array[Dictionary] = []

	# 턴에 따른 티어 제한
	var max_turn := mini(turn, 6)
	var allowed_tiers: Array = TURN_ENEMY_TIERS.get(max_turn, ["tier1"])

	var template_weights: Dictionary = template.get("weights", {})

	for tier in allowed_tiers:
		var tier_enemies: Array = ENEMY_TIERS.get(tier, [])
		for enemy_type in tier_enemies:
			var enemy_data: Dictionary = DataRegistry.get_enemy(enemy_type)
			if enemy_data.is_empty():
				continue

			# 템플릿 가중치 적용
			var weight: int = template_weights.get(enemy_type, 0)
			if weight > 0:
				available.append({
					"type": enemy_type,
					"data": enemy_data,
					"weight": weight,
				})

	# 가중치가 있는 적이 없으면 기본 적 추가
	if available.is_empty():
		var rusher := DataRegistry.get_enemy("rusher")
		available.append({"type": "rusher", "data": rusher, "weight": 1})

	return available


static func _fill_wave_with_enemies(budget: int, available: Array[Dictionary]) -> Array[Dictionary]:
	var enemies: Array[Dictionary] = []
	var remaining := budget

	# 가중치 기반 선택
	var types: Array = []
	var weights: Array = []
	for e in available:
		types.append(e)
		weights.append(e["weight"])

	while remaining > 0:
		var selected: Dictionary = RngManager.weighted_pick(RngManager.STREAM_ENEMY_WAVES, types, weights)
		if selected.is_empty():
			break

		var cost: int = selected["data"].get("budget", 1)

		if cost > remaining:
			# 비용이 너무 높으면 더 저렴한 적 찾기
			var found := false
			for e in available:
				if e["data"].get("budget", 1) <= remaining:
					selected = e
					cost = e["data"].get("budget", 1)
					found = true
					break

			if not found:
				break

		enemies.append({
			"type": selected["type"],
			"data": selected["data"].duplicate(),
		})

		remaining -= cost

	return enemies


# ===========================================
# 스폰 그룹 분배
# ===========================================

static func _distribute_to_spawn_groups(enemies: Array[Dictionary], airlock_count: int) -> Array[Dictionary]:
	var groups: Array[Dictionary] = []

	# 에어락 수만큼 그룹 생성
	for i in range(airlock_count):
		groups.append({
			"airlock_index": i,
			"enemies": [],
			"spawn_delay": i * 0.5,  # 순차 스폰
		})

	if groups.is_empty():
		return groups

	# 적 분배
	var shuffled := RngManager.shuffle(RngManager.STREAM_ENEMY_WAVES, enemies)

	for i in range(shuffled.size()):
		var group_index := i % groups.size()
		groups[group_index]["enemies"].append(shuffled[i])

	return groups


# ===========================================
# 웨이브 딜레이
# ===========================================

static func _get_wave_delay(wave_index: int) -> float:
	if wave_index == 0:
		return Balance.WAVE["initial_delay"]
	return Balance.WAVE["wave_interval"]


# ===========================================
# 보스 웨이브
# ===========================================

static func generate_boss_wave(boss_type: String, turn: int, difficulty: int) -> Dictionary:
	var boss_data: Dictionary = DataRegistry.get_enemy(boss_type)

	# 보스 + 수행원
	var minions := _generate_boss_minions(turn, difficulty)

	return {
		"index": 0,
		"template": "boss",
		"is_boss_wave": true,
		"boss": {
			"type": boss_type,
			"data": boss_data,
		},
		"minions": minions,
		"delay_before": Balance.WAVE["boss_spawn_delay"],
	}


static func _generate_boss_minions(turn: int, difficulty: int) -> Array[Dictionary]:
	# 보스 수행원 (예산의 50%)
	var budget := _calculate_total_budget(turn, difficulty) / 2
	var template: Dictionary = WAVE_TEMPLATES["standard"]
	var available := _get_available_enemies(turn, template)

	return _fill_wave_with_enemies(budget, available)
