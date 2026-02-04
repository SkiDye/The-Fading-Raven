extends GutTest

## BattleController 및 전투 시스템 테스트


var _battle_controller: BattleController
var _damage_calculator: DamageCalculator
var _skill_system: SkillSystem


func before_each() -> void:
	_battle_controller = BattleController.new()
	_battle_controller.name = "BattleController"
	add_child(_battle_controller)

	# 시스템들은 _setup_components에서 자동 생성됨
	await get_tree().process_frame

	_damage_calculator = _battle_controller.damage_calculator
	_skill_system = _battle_controller.skill_system


func after_each() -> void:
	if _battle_controller:
		_battle_controller.queue_free()
	_battle_controller = null
	_damage_calculator = null
	_skill_system = null


# ===== BATTLE CONTROLLER TESTS =====

func test_battle_controller_initialization() -> void:
	assert_not_null(_battle_controller, "BattleController should be created")
	assert_not_null(_battle_controller.damage_calculator, "DamageCalculator should exist")
	assert_not_null(_battle_controller.skill_system, "SkillSystem should exist")
	assert_not_null(_battle_controller.equipment_system, "EquipmentSystem should exist")
	assert_not_null(_battle_controller.raven_system, "RavenSystem should exist")


func test_battle_not_active_initially() -> void:
	assert_false(_battle_controller.is_battle_active, "Battle should not be active initially")
	assert_false(_battle_controller.is_paused, "Battle should not be paused initially")
	assert_false(_battle_controller.is_slow_motion, "Slow motion should not be active initially")


func test_toggle_pause() -> void:
	_battle_controller.is_battle_active = true

	_battle_controller.toggle_pause()
	assert_true(_battle_controller.is_paused, "Battle should be paused after toggle")

	_battle_controller.toggle_pause()
	assert_false(_battle_controller.is_paused, "Battle should be unpaused after second toggle")


func test_slow_motion() -> void:
	_battle_controller.set_slow_motion(true)
	assert_true(_battle_controller.is_slow_motion, "Slow motion should be active")

	_battle_controller.set_slow_motion(false)
	assert_false(_battle_controller.is_slow_motion, "Slow motion should be inactive")


func test_select_squad() -> void:
	var mock_squad := Node2D.new()
	mock_squad.name = "MockSquad"
	mock_squad.set("tile_position", Vector2i(5, 5))
	mock_squad.set("is_alive", true)
	add_child(mock_squad)

	_battle_controller.select_squad(mock_squad)
	assert_eq(_battle_controller.selected_squad, mock_squad, "Squad should be selected")

	_battle_controller.deselect_squad()
	assert_null(_battle_controller.selected_squad, "Squad should be deselected")

	mock_squad.queue_free()


func test_targeting_modes() -> void:
	var mock_squad := Node2D.new()
	mock_squad.name = "MockSquad"
	mock_squad.set("is_alive", true)
	add_child(mock_squad)

	# Skill targeting
	_battle_controller.start_skill_targeting(mock_squad, "shield_bash")
	assert_eq(_battle_controller.targeting_mode, "skill", "Should be in skill targeting mode")

	_battle_controller.cancel_targeting()
	assert_eq(_battle_controller.targeting_mode, "", "Targeting should be cancelled")

	# Equipment targeting
	_battle_controller.start_equipment_targeting(mock_squad)
	assert_eq(_battle_controller.targeting_mode, "equipment", "Should be in equipment targeting mode")

	_battle_controller.cancel_targeting()

	mock_squad.queue_free()


# ===== DAMAGE CALCULATOR TESTS =====

func test_damage_calculator_basic() -> void:
	assert_not_null(_damage_calculator, "DamageCalculator should exist")

	var mock_attacker := Node2D.new()
	mock_attacker.set("tile_position", Vector2i(0, 0))
	mock_attacker.set("team", 0)
	add_child(mock_attacker)

	var mock_defender := Node2D.new()
	mock_defender.set("tile_position", Vector2i(1, 1))
	mock_defender.set("team", 1)
	add_child(mock_defender)

	var result := _damage_calculator.calculate_damage(
		mock_attacker,
		mock_defender,
		10,
		Constants.DamageType.PHYSICAL
	)

	assert_true(result.damage >= 1, "Damage should be at least 1")
	assert_has(result, "is_critical", "Result should have is_critical field")
	assert_has(result, "modifiers", "Result should have modifiers field")

	mock_attacker.queue_free()
	mock_defender.queue_free()


func test_damage_calculator_simple() -> void:
	var mock_attacker := Node2D.new()
	mock_attacker.set("tile_position", Vector2i(0, 0))
	add_child(mock_attacker)

	var mock_defender := Node2D.new()
	mock_defender.set("tile_position", Vector2i(1, 1))
	add_child(mock_defender)

	var damage := _damage_calculator.calculate_damage_simple(
		mock_attacker,
		mock_defender,
		20,
		Constants.DamageType.ENERGY
	)

	assert_true(damage >= 1, "Simple damage should be at least 1")

	mock_attacker.queue_free()
	mock_defender.queue_free()


func test_knockback_calculation() -> void:
	var mock_attacker := Node2D.new()
	add_child(mock_attacker)

	var mock_defender := Node2D.new()
	add_child(mock_defender)

	var knockback := _damage_calculator.calculate_knockback(
		mock_attacker,
		mock_defender,
		2.0
	)

	assert_eq(knockback, 2.0, "Base knockback should be unchanged without traits")

	mock_attacker.queue_free()
	mock_defender.queue_free()


# ===== BATTLE RESULT TESTS =====

func test_battle_result_class() -> void:
	var result := BattleController.BattleResult.new()

	result.victory = true
	result.facilities_saved = 3
	result.facilities_total = 4
	result.credits_earned = 15
	result.enemies_killed = 20

	assert_true(result.victory, "Victory should be true")
	assert_eq(result.facilities_saved, 3, "Facilities saved should be 3")
	assert_eq(result.credits_earned, 15, "Credits earned should be 15")


# ===== INTEGRATION TESTS =====

func test_battle_start_with_empty_data() -> void:
	var empty_station := {}
	var empty_crews: Array = []

	_battle_controller.start_battle(empty_station, empty_crews)

	assert_true(_battle_controller.is_battle_active, "Battle should be active after start")
	assert_eq(_battle_controller.crews.size(), 0, "Should have no crews")
	assert_eq(_battle_controller.enemies_killed, 0, "Should have killed no enemies")


func test_battle_end() -> void:
	_battle_controller.is_battle_active = true

	var result := _battle_controller.end_battle(true)

	assert_false(_battle_controller.is_battle_active, "Battle should not be active after end")
	assert_true(result.victory, "Result should indicate victory")
