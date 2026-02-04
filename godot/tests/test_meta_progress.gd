extends GutTest

## MetaProgress 유닛 테스트
## GUT 프레임워크 사용


var _meta_progress: Node


func before_each() -> void:
	# MetaProgress 인스턴스 생성
	_meta_progress = load("res://src/autoload/MetaProgress.gd").new()
	_meta_progress._reset_to_defaults()
	_meta_progress._initialize_achievements()
	add_child(_meta_progress)


func after_each() -> void:
	_meta_progress.queue_free()


# ===== UNLOCK TESTS =====

func test_default_unlocked_classes() -> void:
	assert_true(_meta_progress.is_class_unlocked("guardian"), "Guardian should be unlocked by default")
	assert_true(_meta_progress.is_class_unlocked("sentinel"), "Sentinel should be unlocked by default")
	assert_true(_meta_progress.is_class_unlocked("ranger"), "Ranger should be unlocked by default")
	assert_false(_meta_progress.is_class_unlocked("engineer"), "Engineer should NOT be unlocked by default")
	assert_false(_meta_progress.is_class_unlocked("bionic"), "Bionic should NOT be unlocked by default")


func test_default_unlocked_difficulties() -> void:
	assert_true(_meta_progress.is_difficulty_unlocked(Constants.Difficulty.NORMAL), "Normal should be unlocked by default")
	assert_false(_meta_progress.is_difficulty_unlocked(Constants.Difficulty.HARD), "Hard should NOT be unlocked by default")
	assert_false(_meta_progress.is_difficulty_unlocked(Constants.Difficulty.VERY_HARD), "Very Hard should NOT be unlocked by default")
	assert_false(_meta_progress.is_difficulty_unlocked(Constants.Difficulty.NIGHTMARE), "Nightmare should NOT be unlocked by default")


func test_unlock_class() -> void:
	var result := _meta_progress.unlock_class("engineer")
	assert_true(result, "unlock_class should return true for new unlock")
	assert_true(_meta_progress.is_class_unlocked("engineer"), "Engineer should be unlocked after unlock_class")


func test_unlock_class_duplicate() -> void:
	_meta_progress.unlock_class("engineer")
	var result := _meta_progress.unlock_class("engineer")
	assert_false(result, "unlock_class should return false for duplicate unlock")


func test_unlock_difficulty() -> void:
	var result := _meta_progress.unlock_difficulty(Constants.Difficulty.HARD)
	assert_true(result, "unlock_difficulty should return true for new unlock")
	assert_true(_meta_progress.is_difficulty_unlocked(Constants.Difficulty.HARD), "Hard should be unlocked")


func test_unlock_trait() -> void:
	var result := _meta_progress.unlock_trait("shadow_strike")
	assert_true(result, "unlock_trait should return true for new unlock")
	assert_true(_meta_progress.is_trait_unlocked("shadow_strike"), "Trait should be unlocked")


func test_unlock_equipment() -> void:
	var result := _meta_progress.unlock_equipment("special_shield")
	assert_true(result, "unlock_equipment should return true for new unlock")
	assert_true(_meta_progress.is_equipment_unlocked("special_shield"), "Equipment should be unlocked")


func test_is_unlocked_generic() -> void:
	_meta_progress.unlock_class("engineer")
	_meta_progress.unlock_trait("test_trait")

	assert_true(_meta_progress.is_unlocked("class", "engineer"), "is_unlocked should work for class")
	assert_true(_meta_progress.is_unlocked("trait", "test_trait"), "is_unlocked should work for trait")
	assert_false(_meta_progress.is_unlocked("class", "bionic"), "is_unlocked should return false for not unlocked")


# ===== ACHIEVEMENT TESTS =====

func test_achievements_initialized() -> void:
	var all_ids := _meta_progress.get_all_achievement_ids()
	assert_gt(all_ids.size(), 0, "Should have achievement definitions")

	for ach_id in all_ids:
		assert_false(_meta_progress.is_achievement_completed(ach_id), "Achievement should not be completed initially")
		assert_eq(_meta_progress.get_achievement_progress(ach_id), 0, "Achievement progress should be 0 initially")


func test_achievement_progress_update() -> void:
	_meta_progress.update_achievement_progress("turret_master", 50)
	assert_eq(_meta_progress.get_achievement_progress("turret_master"), 50, "Progress should be updated")


func test_achievement_progress_increment() -> void:
	_meta_progress.increment_achievement_progress("turret_master", 10)
	_meta_progress.increment_achievement_progress("turret_master", 5)
	assert_eq(_meta_progress.get_achievement_progress("turret_master"), 15, "Progress should be incremented")


func test_achievement_completion_by_progress() -> void:
	# turret_master requires 100 progress
	_meta_progress.update_achievement_progress("turret_master", 100)
	assert_true(_meta_progress.is_achievement_completed("turret_master"), "Achievement should be completed when progress meets target")


func test_achievement_no_progress_after_completion() -> void:
	_meta_progress.update_achievement_progress("turret_master", 100)
	_meta_progress.increment_achievement_progress("turret_master", 50)
	# Progress should stay at 100 (or not increase after completion)
	assert_true(_meta_progress.is_achievement_completed("turret_master"), "Achievement should remain completed")


func test_achievement_def_retrieval() -> void:
	var def := _meta_progress.get_achievement_def("first_escape")
	assert_not_null(def, "Achievement def should exist")
	assert_eq(def.get("name"), "First Escape", "Achievement name should match")
	assert_eq(def.get("reward_type"), "class", "Reward type should match")
	assert_eq(def.get("reward_id"), "engineer", "Reward ID should match")


# ===== STATISTICS TESTS =====

func test_statistics_default_values() -> void:
	assert_eq(_meta_progress.get_stat("total_runs"), 0, "total_runs should be 0 initially")
	assert_eq(_meta_progress.get_stat("successful_runs"), 0, "successful_runs should be 0 initially")
	assert_eq(_meta_progress.get_stat("total_enemies_killed"), 0, "total_enemies_killed should be 0 initially")


func test_record_stat() -> void:
	_meta_progress.record_stat("total_enemies_killed", 50)
	assert_eq(_meta_progress.get_stat("total_enemies_killed"), 50, "Stat should be recorded")

	_meta_progress.record_stat("total_enemies_killed", 30)
	assert_eq(_meta_progress.get_stat("total_enemies_killed"), 80, "Stat should be accumulated")


func test_set_stat() -> void:
	_meta_progress.set_stat("total_enemies_killed", 100)
	assert_eq(_meta_progress.get_stat("total_enemies_killed"), 100, "Stat should be set directly")


func test_unknown_stat_warning() -> void:
	# This should trigger a warning but not crash
	_meta_progress.record_stat("unknown_stat_id", 10)
	# If we reach here without crash, test passes


# ===== RUN RECORDING TESTS =====

func test_record_run_result_victory() -> void:
	var run_data := {
		"difficulty": Constants.Difficulty.NORMAL,
		"statistics": {
			"enemies_killed": 50,
			"facilities_saved": 3,
			"facilities_lost": 1,
			"crews_lost": 0,
			"damage_dealt": 1000,
			"damage_taken": 500
		}
	}

	_meta_progress.record_run_result(run_data, true)

	assert_eq(_meta_progress.get_stat("total_runs"), 1, "total_runs should be 1")
	assert_eq(_meta_progress.get_stat("successful_runs"), 1, "successful_runs should be 1")
	assert_eq(_meta_progress.get_stat("total_enemies_killed"), 50, "enemies_killed should be accumulated")
	assert_eq(_meta_progress.get_stat("total_facilities_saved"), 3, "facilities_saved should be accumulated")


func test_record_run_result_defeat() -> void:
	var run_data := {
		"difficulty": Constants.Difficulty.NORMAL,
		"statistics": {
			"enemies_killed": 20,
			"facilities_saved": 0,
			"facilities_lost": 5,
			"crews_lost": 3,
			"damage_dealt": 500,
			"damage_taken": 1000
		}
	}

	_meta_progress.record_run_result(run_data, false)

	assert_eq(_meta_progress.get_stat("total_runs"), 1, "total_runs should be 1")
	assert_eq(_meta_progress.get_stat("successful_runs"), 0, "successful_runs should be 0 for defeat")
	assert_eq(_meta_progress.get_stat("total_crews_lost"), 3, "crews_lost should be accumulated")


func test_record_hard_mode_clear() -> void:
	var run_data := {
		"difficulty": Constants.Difficulty.HARD,
		"statistics": {}
	}

	_meta_progress.record_run_result(run_data, true)

	# hard_mode achievement should have progress
	assert_eq(_meta_progress.get_achievement_progress("hard_mode"), 1, "hard_mode achievement should have progress")


func test_record_very_hard_clear_unlocks_nightmare() -> void:
	var run_data := {
		"difficulty": Constants.Difficulty.VERY_HARD,
		"statistics": {}
	}

	_meta_progress.record_run_result(run_data, true)

	assert_true(_meta_progress.is_difficulty_unlocked(Constants.Difficulty.NIGHTMARE), "Nightmare should be unlocked after Very Hard clear")


# ===== STAGE RECORDING TESTS =====

func test_record_stage_result_perfect() -> void:
	var stage_data := {"node_type": Constants.NodeType.BATTLE}
	var result := {"facilities_saved": 5, "facilities_total": 5, "victory": true}

	_meta_progress.record_stage_result(stage_data, result)

	assert_eq(_meta_progress.get_stat("perfect_stages"), 1, "perfect_stages should be 1")


func test_record_stage_result_boss() -> void:
	var stage_data := {"node_type": Constants.NodeType.BOSS}
	var result := {"facilities_saved": 3, "facilities_total": 5, "victory": true}

	_meta_progress.record_stage_result(stage_data, result)

	assert_eq(_meta_progress.get_stat("bosses_defeated"), 1, "bosses_defeated should be 1")


# ===== SPECIAL RECORDING TESTS =====

func test_record_bionic_boss_kill() -> void:
	_meta_progress.record_bionic_boss_kill()
	assert_eq(_meta_progress.get_stat("bionic_boss_kills"), 1, "bionic_boss_kills should be 1")
	assert_eq(_meta_progress.get_achievement_progress("assassin"), 1, "assassin achievement progress should be 1")


func test_record_turret_kill() -> void:
	_meta_progress.record_turret_kill(5)
	assert_eq(_meta_progress.get_stat("turret_kills"), 5, "turret_kills should be 5")
	assert_eq(_meta_progress.get_achievement_progress("turret_master"), 5, "turret_master achievement progress should be 5")


# ===== ACHIEVEMENT REWARD TESTS =====

func test_first_escape_rewards_engineer() -> void:
	var run_data := {
		"difficulty": Constants.Difficulty.NORMAL,
		"statistics": {}
	}

	# Complete first run
	_meta_progress.record_run_result(run_data, true)

	assert_true(_meta_progress.is_achievement_completed("first_escape"), "first_escape should be completed")
	assert_true(_meta_progress.is_class_unlocked("engineer"), "Engineer should be unlocked as reward")


func test_hard_mode_rewards_bionic() -> void:
	# Hard mode achievement requires progress of 1
	_meta_progress.increment_achievement_progress("hard_mode", 1)

	assert_true(_meta_progress.is_achievement_completed("hard_mode"), "hard_mode should be completed")
	assert_true(_meta_progress.is_class_unlocked("bionic"), "Bionic should be unlocked as reward")


# ===== RESET TESTS =====

func test_reset_meta_progress() -> void:
	# Make some changes
	_meta_progress.unlock_class("engineer")
	_meta_progress.record_stat("total_enemies_killed", 100)
	_meta_progress.increment_achievement_progress("turret_master", 50)

	# Reset
	_meta_progress.reset_meta_progress()

	# Verify reset
	assert_false(_meta_progress.is_class_unlocked("engineer"), "Engineer should not be unlocked after reset")
	assert_eq(_meta_progress.get_stat("total_enemies_killed"), 0, "Stats should be reset")
	assert_eq(_meta_progress.get_achievement_progress("turret_master"), 0, "Achievement progress should be reset")

	# Default unlocks should be restored
	assert_true(_meta_progress.is_class_unlocked("guardian"), "Guardian should be unlocked after reset")


# ===== UNLOCK_ALL TESTS =====

func test_unlock_all() -> void:
	_meta_progress.unlock_all()

	assert_true(_meta_progress.is_class_unlocked("engineer"), "Engineer should be unlocked")
	assert_true(_meta_progress.is_class_unlocked("bionic"), "Bionic should be unlocked")
	assert_true(_meta_progress.is_difficulty_unlocked(Constants.Difficulty.NIGHTMARE), "Nightmare should be unlocked")


# ===== SIGNAL TESTS =====

func test_unlock_achieved_signal() -> void:
	watch_signals(_meta_progress)

	_meta_progress.unlock_class("engineer")

	assert_signal_emitted(_meta_progress, "unlock_achieved", "unlock_achieved signal should be emitted")


func test_achievement_completed_signal() -> void:
	watch_signals(_meta_progress)

	_meta_progress.increment_achievement_progress("turret_master", 100)

	assert_signal_emitted(_meta_progress, "achievement_completed", "achievement_completed signal should be emitted")


func test_statistics_updated_signal() -> void:
	watch_signals(_meta_progress)

	_meta_progress.record_stat("total_enemies_killed", 10)

	assert_signal_emitted(_meta_progress, "statistics_updated", "statistics_updated signal should be emitted")


# ===== STAT-BASED ACHIEVEMENT TESTS =====

func test_hundred_kills_achievement() -> void:
	_meta_progress.record_stat("total_enemies_killed", 100)

	assert_true(_meta_progress.is_achievement_completed("hundred_kills"), "hundred_kills should be completed at 100 kills")


func test_thousand_kills_achievement() -> void:
	_meta_progress.record_stat("total_enemies_killed", 1000)

	assert_true(_meta_progress.is_achievement_completed("thousand_kills"), "thousand_kills should be completed at 1000 kills")
