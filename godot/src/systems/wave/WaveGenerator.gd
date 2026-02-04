class_name WaveGenerator
extends RefCounted

## 웨이브 구성 생성기
## 난이도와 깊이에 따라 적 구성을 생성

const UtilsClass = preload("res://src/utils/Utils.gd")


# ===== INNER CLASSES =====

class WaveData:
	## 단일 웨이브 데이터

	var wave_index: int = 0
	var enemies: Array = []  # [{enemy_id, count, entry_point}]
	var spawn_delays: Array[float] = []
	var theme: String = "mixed"
	var budget: int = 0
	var is_boss_wave: bool = false


class EnemyGroup:
	## 적 그룹 데이터

	var enemy_id: String
	var count: int
	var entry_point: Vector2i

	func _init(id: String, cnt: int, entry: Vector2i):
		enemy_id = id
		count = cnt
		entry_point = entry

	func to_dict() -> Dictionary:
		return {
			"enemy_id": enemy_id,
			"count": count,
			"entry_point": entry_point
		}


# ===== VARIABLES =====

var rng: RandomNumberGenerator
var difficulty: Constants.Difficulty
var depth: int


# ===== THEME COMPOSITIONS =====

const THEME_COMPOSITIONS: Dictionary = {
	"rush": [
		{"id": "rusher", "ratio": 0.8},
		{"id": "gunner", "ratio": 0.2}
	],
	"ranged": [
		{"id": "gunner", "ratio": 0.6},
		{"id": "rusher", "ratio": 0.3},
		{"id": "shield_trooper", "ratio": 0.1}
	],
	"shield": [
		{"id": "shield_trooper", "ratio": 0.5},
		{"id": "rusher", "ratio": 0.3},
		{"id": "gunner", "ratio": 0.2}
	],
	"assault": [
		{"id": "jumper", "ratio": 0.3},
		{"id": "heavy_trooper", "ratio": 0.3},
		{"id": "rusher", "ratio": 0.4}
	],
	"hacking": [
		{"id": "hacker", "ratio": 0.2},
		{"id": "shield_trooper", "ratio": 0.4},
		{"id": "rusher", "ratio": 0.4}
	],
	"sniper": [
		{"id": "sniper", "ratio": 0.2},
		{"id": "shield_trooper", "ratio": 0.5},
		{"id": "rusher", "ratio": 0.3}
	],
	"mixed": [
		{"id": "rusher", "ratio": 0.4},
		{"id": "gunner", "ratio": 0.3},
		{"id": "shield_trooper", "ratio": 0.3}
	],
	"elite": [
		{"id": "brute", "ratio": 0.3},
		{"id": "sniper", "ratio": 0.2},
		{"id": "shield_generator", "ratio": 0.2},
		{"id": "heavy_trooper", "ratio": 0.3}
	],
	"swarm": [
		{"id": "rusher", "ratio": 0.9},
		{"id": "gunner", "ratio": 0.1}
	]
}


# ===== INITIALIZATION =====

func _init(seed_value: int = 0):
	rng = RandomNumberGenerator.new()
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()


# ===== PUBLIC METHODS =====

## 웨이브 배열 생성
func generate_waves(
	station_depth: int,
	diff: Constants.Difficulty,
	entry_points: Array[Vector2i]
) -> Array[WaveData]:
	depth = station_depth
	difficulty = diff

	var wave_count: int = _calculate_wave_count()
	var result: Array[WaveData] = []

	for i in range(wave_count):
		var wave := _generate_single_wave(i, wave_count, entry_points)
		result.append(wave)

	return result


## 보스 웨이브 생성
func generate_boss_wave(
	station_depth: int,
	diff: Constants.Difficulty,
	entry_points: Array[Vector2i],
	boss_id: String = "pirate_captain"
) -> WaveData:
	depth = station_depth
	difficulty = diff

	var wave := WaveData.new()
	wave.is_boss_wave = true
	wave.theme = "boss"
	wave.budget = _calculate_budget(0) * 2

	# 보스 추가
	var boss_entry: Vector2i = _select_entry_point(entry_points)
	wave.enemies.append(EnemyGroup.new(boss_id, 1, boss_entry).to_dict())
	wave.spawn_delays.append(0.0)

	# 호위병 추가
	var escort_budget: int = wave.budget / 3
	_fill_wave_with_budget(wave, escort_budget, entry_points, ["shield_trooper", "gunner"])

	return wave


## 웨이브 미리보기 정보 생성
func get_wave_preview(wave_data: WaveData) -> Array:
	var preview: Array = []
	for enemy_group in wave_data.enemies:
		preview.append({
			"enemy_id": enemy_group.enemy_id,
			"count": enemy_group.count
		})
	return preview


# ===== PRIVATE METHODS =====

func _calculate_wave_count() -> int:
	var base: int = 3
	var diff_bonus: int = [0, 1, 2, 3][difficulty]
	var depth_bonus: int = depth / 5

	return base + diff_bonus + depth_bonus


func _generate_single_wave(
	wave_index: int,
	total_waves: int,
	entry_points: Array[Vector2i]
) -> WaveData:
	var wave := WaveData.new()
	wave.wave_index = wave_index
	wave.budget = _calculate_budget(wave_index)
	wave.theme = _select_theme(wave_index, total_waves)
	wave.enemies = []
	wave.spawn_delays = []

	var remaining_budget: int = wave.budget
	var composition: Array = _get_theme_composition(wave.theme)
	var available_enemies: Array[String] = _get_available_enemies()

	# 테마에 따른 적 구성
	for enemy_type in composition:
		var enemy_id: String = enemy_type.id

		# 사용 가능한 적인지 확인
		if not available_enemies.has(enemy_id):
			continue

		var enemy_cost: int = _get_enemy_cost(enemy_id)
		if enemy_cost <= 0:
			continue

		var ratio: float = enemy_type.ratio
		var target_count: int = int(float(remaining_budget) * ratio / float(enemy_cost))
		target_count = clampi(target_count, 1, 12)  # 1~12 제한

		if target_count > 0 and enemy_cost * target_count <= remaining_budget:
			var entry: Vector2i = _select_entry_point(entry_points)

			wave.enemies.append(EnemyGroup.new(enemy_id, target_count, entry).to_dict())
			remaining_budget -= enemy_cost * target_count

	# 남은 예산으로 기본 적 추가
	if remaining_budget > 0:
		_fill_remaining_budget(wave, remaining_budget, entry_points)

	# 스폰 딜레이 설정
	var spawn_interval: float = Constants.BALANCE.wave.spawn_interval
	for i in range(wave.enemies.size()):
		wave.spawn_delays.append(float(i) * spawn_interval)

	return wave


func _calculate_budget(wave_index: int) -> int:
	var base_budget: int = Constants.BALANCE.wave.base_budget
	var budget_per_wave: float = Constants.BALANCE.wave.budget_per_wave

	# 난이도별 기본 예산 조정 (Constants에서 가져옴)
	var diff_mult: float = Constants.get_wave_budget_multiplier(difficulty)

	# 웨이브/깊이 스케일링
	var wave_mult: float = 1.0 + wave_index * budget_per_wave
	var depth_mult: float = 1.0 + depth * 0.1

	return int(float(base_budget) * diff_mult * wave_mult * depth_mult)


func _select_theme(wave_index: int, total_waves: int) -> String:
	var themes: Array[String] = ["rush", "ranged", "shield", "mixed", "assault"]
	var weights: Array[float] = [0.25, 0.15, 0.15, 0.30, 0.15]

	# 깊이에 따라 특수 테마 추가
	if depth >= 4:
		themes.append("hacking")
		weights.append(0.10)

	if depth >= 6:
		themes.append("sniper")
		weights.append(0.10)

	if depth >= 8:
		themes.append("elite")
		weights.append(0.15)

	# 마지막 웨이브는 swarm 가능성
	if wave_index == total_waves - 1 and rng.randf() < 0.3:
		return "swarm"

	return UtilsClass.weighted_random_choice(themes, weights, rng)


func _get_theme_composition(theme: String) -> Array:
	if THEME_COMPOSITIONS.has(theme):
		return THEME_COMPOSITIONS[theme]
	return THEME_COMPOSITIONS["mixed"]


func _get_available_enemies() -> Array[String]:
	var result: Array[String] = ["rusher", "gunner", "shield_trooper"]

	if depth >= 3:
		result.append("jumper")
	if depth >= 4:
		result.append_array(["heavy_trooper", "hacker"])
	if depth >= 5:
		result.append("brute")
	if depth >= 6:
		result.append_array(["sniper", "shield_generator"])
	if depth >= 7:
		result.append("drone_carrier")
	if depth >= 8:
		result.append("storm_creature")

	return result


func _get_enemy_cost(enemy_id: String) -> int:
	if Constants.ENEMY_COSTS.has(enemy_id):
		return Constants.ENEMY_COSTS[enemy_id]
	return 1


func _select_entry_point(entry_points: Array[Vector2i]) -> Vector2i:
	if entry_points.is_empty():
		return Vector2i.ZERO
	return entry_points[rng.randi() % entry_points.size()]


func _fill_remaining_budget(
	wave: WaveData,
	remaining: int,
	entry_points: Array[Vector2i]
) -> void:
	var rusher_cost: int = _get_enemy_cost("rusher")
	if rusher_cost <= 0:
		return

	var count: int = remaining / rusher_cost
	if count > 0:
		var entry: Vector2i = _select_entry_point(entry_points)
		wave.enemies.append(EnemyGroup.new("rusher", count, entry).to_dict())


func _fill_wave_with_budget(
	wave: WaveData,
	budget: int,
	entry_points: Array[Vector2i],
	enemy_ids: Array
) -> void:
	var remaining: int = budget

	for enemy_id in enemy_ids:
		var cost: int = _get_enemy_cost(enemy_id)
		if cost <= 0:
			continue

		var count: int = remaining / (cost * enemy_ids.size())
		count = clampi(count, 1, 6)

		if count > 0 and cost * count <= remaining:
			var entry: Vector2i = _select_entry_point(entry_points)
			wave.enemies.append(EnemyGroup.new(enemy_id, count, entry).to_dict())
			wave.spawn_delays.append(wave.spawn_delays.size() * 2.0)
			remaining -= cost * count
