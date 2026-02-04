extends GutTest

## WaveGenerator 유닛 테스트


var generator: WaveGenerator


func before_each() -> void:
	generator = WaveGenerator.new(12345)  # 고정 시드


func after_each() -> void:
	generator = null


# ===== WAVE GENERATION TESTS =====

func test_generate_waves_returns_array() -> void:
	var entry_points: Array[Vector2i] = [Vector2i(0, 5), Vector2i(10, 5)]
	var waves = generator.generate_waves(1, Constants.Difficulty.NORMAL, entry_points)

	assert_not_null(waves, "Should return waves array")
	assert_true(waves.size() > 0, "Should have at least one wave")


func test_wave_count_scales_with_difficulty() -> void:
	var entry_points: Array[Vector2i] = [Vector2i(0, 5)]

	var normal_waves = generator.generate_waves(1, Constants.Difficulty.NORMAL, entry_points)
	var hard_waves = generator.generate_waves(1, Constants.Difficulty.HARD, entry_points)
	var nightmare_waves = generator.generate_waves(1, Constants.Difficulty.NIGHTMARE, entry_points)

	assert_true(
		hard_waves.size() >= normal_waves.size(),
		"Hard should have >= waves than Normal"
	)
	assert_true(
		nightmare_waves.size() >= hard_waves.size(),
		"Nightmare should have >= waves than Hard"
	)


func test_wave_count_scales_with_depth() -> void:
	var entry_points: Array[Vector2i] = [Vector2i(0, 5)]

	var shallow_waves = generator.generate_waves(1, Constants.Difficulty.NORMAL, entry_points)
	var deep_waves = generator.generate_waves(10, Constants.Difficulty.NORMAL, entry_points)

	assert_true(
		deep_waves.size() >= shallow_waves.size(),
		"Deeper depth should have >= waves"
	)


func test_each_wave_has_enemies() -> void:
	var entry_points: Array[Vector2i] = [Vector2i(0, 5)]
	var waves = generator.generate_waves(1, Constants.Difficulty.NORMAL, entry_points)

	for wave in waves:
		assert_true(wave.enemies.size() > 0, "Each wave should have enemies")


func test_wave_data_structure() -> void:
	var entry_points: Array[Vector2i] = [Vector2i(0, 5)]
	var waves = generator.generate_waves(1, Constants.Difficulty.NORMAL, entry_points)
	var wave: WaveGenerator.WaveData = waves[0]

	assert_not_null(wave.enemies, "Wave should have enemies array")
	assert_not_null(wave.spawn_delays, "Wave should have spawn_delays array")
	assert_true(wave.theme.length() > 0, "Wave should have a theme")
	assert_true(wave.budget > 0, "Wave should have positive budget")


func test_enemy_group_structure() -> void:
	var entry_points: Array[Vector2i] = [Vector2i(0, 5)]
	var waves = generator.generate_waves(1, Constants.Difficulty.NORMAL, entry_points)
	var enemy_group: Dictionary = waves[0].enemies[0]

	assert_true(enemy_group.has("enemy_id"), "Should have enemy_id")
	assert_true(enemy_group.has("count"), "Should have count")
	assert_true(enemy_group.has("entry_point"), "Should have entry_point")

	assert_true(enemy_group.enemy_id.length() > 0, "enemy_id should not be empty")
	assert_true(enemy_group.count > 0, "count should be positive")


# ===== BUDGET TESTS =====

func test_budget_increases_per_wave() -> void:
	var entry_points: Array[Vector2i] = [Vector2i(0, 5)]
	var waves = generator.generate_waves(1, Constants.Difficulty.NORMAL, entry_points)

	if waves.size() >= 2:
		assert_true(
			waves[1].budget >= waves[0].budget,
			"Later waves should have >= budget"
		)


func test_budget_scales_with_difficulty() -> void:
	var entry_points: Array[Vector2i] = [Vector2i(0, 5)]

	generator = WaveGenerator.new(12345)
	var normal_waves = generator.generate_waves(5, Constants.Difficulty.NORMAL, entry_points)

	generator = WaveGenerator.new(12345)
	var nightmare_waves = generator.generate_waves(5, Constants.Difficulty.NIGHTMARE, entry_points)

	assert_true(
		nightmare_waves[0].budget > normal_waves[0].budget,
		"Nightmare should have higher budget"
	)


# ===== THEME TESTS =====

func test_wave_has_valid_theme() -> void:
	var entry_points: Array[Vector2i] = [Vector2i(0, 5)]
	var waves = generator.generate_waves(1, Constants.Difficulty.NORMAL, entry_points)

	var valid_themes: Array = [
		"rush", "ranged", "shield", "mixed", "assault",
		"hacking", "sniper", "elite", "swarm"
	]

	for wave in waves:
		assert_true(
			valid_themes.has(wave.theme),
			"Theme '%s' should be valid" % wave.theme
		)


# ===== ENEMY AVAILABILITY TESTS =====

func test_early_depth_has_basic_enemies() -> void:
	var entry_points: Array[Vector2i] = [Vector2i(0, 5)]
	var waves = generator.generate_waves(1, Constants.Difficulty.NORMAL, entry_points)

	var basic_enemies: Array = ["rusher", "gunner", "shield_trooper"]
	var found_basic: bool = false

	for wave in waves:
		for enemy_group in wave.enemies:
			if basic_enemies.has(enemy_group.enemy_id):
				found_basic = true
				break

	assert_true(found_basic, "Early depth should have basic enemies")


func test_deep_depth_has_advanced_enemies() -> void:
	var entry_points: Array[Vector2i] = [Vector2i(0, 5)]

	# 깊이 8에서 여러 번 생성해서 고급 적 확인
	var found_advanced: bool = false
	var advanced_enemies: Array = ["brute", "sniper", "drone_carrier"]

	for i in range(10):
		generator = WaveGenerator.new(i)
		var waves = generator.generate_waves(8, Constants.Difficulty.NIGHTMARE, entry_points)

		for wave in waves:
			for enemy_group in wave.enemies:
				if advanced_enemies.has(enemy_group.enemy_id):
					found_advanced = true
					break

	assert_true(found_advanced, "Deep depth should eventually have advanced enemies")


# ===== BOSS WAVE TESTS =====

func test_boss_wave_generation() -> void:
	var entry_points: Array[Vector2i] = [Vector2i(0, 5)]
	var boss_wave = generator.generate_boss_wave(
		5, Constants.Difficulty.NORMAL, entry_points, "pirate_captain"
	)

	assert_true(boss_wave.is_boss_wave, "Should be marked as boss wave")
	assert_eq(boss_wave.theme, "boss", "Theme should be 'boss'")

	var has_boss: bool = false
	for enemy_group in boss_wave.enemies:
		if enemy_group.enemy_id == "pirate_captain":
			has_boss = true
			break

	assert_true(has_boss, "Boss wave should contain boss enemy")


# ===== DETERMINISM TESTS =====

func test_same_seed_produces_same_waves() -> void:
	var entry_points: Array[Vector2i] = [Vector2i(0, 5)]

	var gen1 = WaveGenerator.new(99999)
	var waves1 = gen1.generate_waves(5, Constants.Difficulty.HARD, entry_points)

	var gen2 = WaveGenerator.new(99999)
	var waves2 = gen2.generate_waves(5, Constants.Difficulty.HARD, entry_points)

	assert_eq(waves1.size(), waves2.size(), "Same seed should produce same wave count")

	for i in range(waves1.size()):
		assert_eq(
			waves1[i].theme,
			waves2[i].theme,
			"Same seed should produce same themes"
		)
		assert_eq(
			waves1[i].budget,
			waves2[i].budget,
			"Same seed should produce same budgets"
		)


# ===== PREVIEW TESTS =====

func test_wave_preview() -> void:
	var entry_points: Array[Vector2i] = [Vector2i(0, 5)]
	var waves = generator.generate_waves(1, Constants.Difficulty.NORMAL, entry_points)
	var preview = generator.get_wave_preview(waves[0])

	assert_true(preview.size() > 0, "Preview should not be empty")

	for item in preview:
		assert_true(item.has("enemy_id"), "Preview item should have enemy_id")
		assert_true(item.has("count"), "Preview item should have count")
