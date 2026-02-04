extends GutTest

## EnemyUnit 유닛 테스트
## 적 생성, 특수 메카닉, 데미지 처리 등 테스트


var _enemy: EnemyUnit
var _enemy_scene: PackedScene


func before_all() -> void:
	_enemy_scene = load("res://src/entities/enemy/EnemyUnit.tscn")


func before_each() -> void:
	_enemy = _enemy_scene.instantiate()
	add_child(_enemy)


func after_each() -> void:
	if is_instance_valid(_enemy):
		_enemy.queue_free()
	_enemy = null


# ===== INITIALIZATION TESTS =====

func test_enemy_initializes_with_data() -> void:
	var data := _create_test_enemy_data("test_rusher", 1, 10, 2)
	_enemy.initialize(data, Vector2i(5, 5))

	assert_eq(_enemy.enemy_data.id, "test_rusher", "Enemy data should be set")
	assert_eq(_enemy.max_hp, 10, "Max HP should match data")
	assert_eq(_enemy.current_hp, 10, "Current HP should equal max HP")
	assert_eq(_enemy.entry_point, Vector2i(5, 5), "Entry point should be set")
	assert_eq(_enemy.tile_position, Vector2i(5, 5), "Tile position should be set")


func test_enemy_default_state() -> void:
	var data := _create_test_enemy_data("test", 1, 10, 2)
	_enemy.initialize(data, Vector2i(0, 0))

	assert_true(_enemy.is_alive, "Enemy should be alive")
	assert_false(_enemy.has_landed, "Enemy should not be landed yet")
	assert_eq(_enemy.team, 1, "Enemy team should be 1")
	assert_eq(_enemy.current_state, Constants.EntityState.IDLE, "Default state should be IDLE")


func test_enemy_added_to_group() -> void:
	assert_true(_enemy.is_in_group("enemies"), "Enemy should be in 'enemies' group")
	assert_true(_enemy.is_in_group("entities"), "Enemy should be in 'entities' group")


# ===== LANDING TESTS =====

func test_landing_system() -> void:
	var data := _create_test_enemy_data("test", 1, 10, 2)
	_enemy.initialize(data, Vector2i(0, 0))

	var landed := false
	_enemy.landing_completed.connect(func(): landed = true)

	_enemy.start_landing()
	assert_eq(_enemy.current_state, Constants.EntityState.MOVING, "State should be MOVING during landing")

	_enemy.complete_landing()
	assert_true(_enemy.has_landed, "Enemy should be landed")
	assert_true(landed, "Landing signal should be emitted")


# ===== DAMAGE TESTS =====

func test_take_damage_reduces_hp() -> void:
	var data := _create_test_enemy_data("test", 1, 100, 2)
	_enemy.initialize(data, Vector2i(0, 0))

	var actual := _enemy.take_damage(30, Constants.DamageType.PHYSICAL, null)

	assert_eq(actual, 30, "Actual damage should be 30")
	assert_eq(_enemy.current_hp, 70, "HP should be reduced to 70")


func test_enemy_dies_at_zero_hp() -> void:
	var data := _create_test_enemy_data("test", 1, 10, 2)
	_enemy.initialize(data, Vector2i(0, 0))

	var died := false
	_enemy.died.connect(func(): died = true)

	_enemy.take_damage(15, Constants.DamageType.PHYSICAL, null)

	assert_false(_enemy.is_alive, "Enemy should be dead")
	assert_eq(_enemy.current_hp, 0, "HP should be 0")
	assert_true(died, "Died signal should be emitted")


func test_shield_trooper_reduces_energy_damage() -> void:
	var data := _create_test_enemy_data("shield_trooper", 1, 100, 2)
	_enemy.initialize(data, Vector2i(0, 0))

	var actual := _enemy.take_damage(40, Constants.DamageType.ENERGY, null)

	assert_eq(actual, 20, "Shield trooper should reduce energy damage by 50%")
	assert_eq(_enemy.current_hp, 80, "HP should be 80 after reduced damage")


func test_shielded_enemy_immune_to_energy() -> void:
	var data := _create_test_enemy_data("test", 1, 100, 2)
	_enemy.initialize(data, Vector2i(0, 0))
	_enemy.apply_shield_buff()

	var actual := _enemy.take_damage(50, Constants.DamageType.ENERGY, null)

	assert_eq(actual, 0, "Shielded enemy should be immune to energy damage")
	assert_eq(_enemy.current_hp, 100, "HP should remain 100")


func test_physical_damage_not_reduced_by_shield() -> void:
	var data := _create_test_enemy_data("test", 1, 100, 2)
	_enemy.initialize(data, Vector2i(0, 0))
	_enemy.apply_shield_buff()

	var actual := _enemy.take_damage(50, Constants.DamageType.PHYSICAL, null)

	assert_eq(actual, 50, "Physical damage should not be reduced by shield")
	assert_eq(_enemy.current_hp, 50, "HP should be 50")


# ===== STATUS EFFECT TESTS =====

func test_apply_stun() -> void:
	var data := _create_test_enemy_data("test", 1, 100, 2)
	_enemy.initialize(data, Vector2i(0, 0))

	_enemy.apply_stun(2.0)

	assert_true(_enemy.is_stunned, "Enemy should be stunned")
	assert_eq(_enemy.current_state, Constants.EntityState.STUNNED, "State should be STUNNED")


func test_heal() -> void:
	var data := _create_test_enemy_data("test", 1, 100, 2)
	_enemy.initialize(data, Vector2i(0, 0))
	_enemy.take_damage(50, Constants.DamageType.PHYSICAL, null)

	var healed := _enemy.heal(30)

	assert_eq(healed, 30, "Should heal 30 HP")
	assert_eq(_enemy.current_hp, 80, "HP should be 80")


func test_heal_does_not_exceed_max() -> void:
	var data := _create_test_enemy_data("test", 1, 100, 2)
	_enemy.initialize(data, Vector2i(0, 0))
	_enemy.take_damage(20, Constants.DamageType.PHYSICAL, null)

	var healed := _enemy.heal(50)

	assert_eq(healed, 20, "Should only heal 20 (up to max)")
	assert_eq(_enemy.current_hp, 100, "HP should be capped at max")


# ===== SHIELD BUFF TESTS =====

func test_shield_buff_applied_and_removed() -> void:
	var data := _create_test_enemy_data("test", 1, 100, 2)
	_enemy.initialize(data, Vector2i(0, 0))

	assert_false(_enemy.is_shielded(), "Should not be shielded initially")

	_enemy.apply_shield_buff()
	assert_true(_enemy.is_shielded(), "Should be shielded after buff")

	_enemy.remove_shield_buff()
	assert_false(_enemy.is_shielded(), "Should not be shielded after removal")


# ===== SNIPER TESTS =====

func test_sniper_aim_progress() -> void:
	var data := _create_test_enemy_data("sniper", 3, 10, 99, "sniper")
	_enemy.initialize(data, Vector2i(0, 0))
	_enemy.has_landed = true

	assert_eq(_enemy.get_sniper_aim_progress(), 0.0, "Initial aim progress should be 0")


# ===== HACKER TESTS =====

func test_hacker_hack_progress() -> void:
	var data := _create_test_enemy_data("hacker", 2, 10, 1, "hacker")
	_enemy.initialize(data, Vector2i(0, 0))
	_enemy.has_landed = true

	assert_eq(_enemy.get_hack_progress(), 0.0, "Initial hack progress should be 0")


# ===== JUMPER TESTS =====

func test_jumper_can_jump() -> void:
	var data := _create_test_enemy_data("jumper", 2, 20, 4, "jumper")
	_enemy.initialize(data, Vector2i(0, 0))

	assert_true(_enemy.can_jump(), "Jumper should be able to jump")


func test_jumper_cooldown_after_jump() -> void:
	var data := _create_test_enemy_data("jumper", 2, 20, 4, "jumper")
	_enemy.initialize(data, Vector2i(0, 0))

	_enemy.perform_jump(Vector2i(5, 5))

	assert_false(_enemy.can_jump(), "Jumper should not be able to jump during cooldown")
	assert_eq(_enemy.tile_position, Vector2i(5, 5), "Tile position should update after jump")


# ===== BRUTE TESTS =====

func test_brute_knockback_force() -> void:
	var data := _create_test_enemy_data("brute", 3, 60, 8, "brute")
	_enemy.initialize(data, Vector2i(0, 0))

	assert_eq(_enemy.get_knockback_force(), 3.0, "Brute should have 3.0 knockback force")


func test_normal_enemy_knockback_force() -> void:
	var data := _create_test_enemy_data("rusher", 1, 10, 2, "melee_rush")
	_enemy.initialize(data, Vector2i(0, 0))

	assert_eq(_enemy.get_knockback_force(), 1.0, "Normal enemy should have 1.0 knockback force")


# ===== BOSS TESTS =====

func test_is_boss_true_for_boss() -> void:
	var data := _create_test_enemy_data("pirate_captain", 4, 150, 10, "boss_captain")
	data.is_boss = true
	_enemy.initialize(data, Vector2i(0, 0))

	assert_true(_enemy.is_boss(), "Should be identified as boss")


func test_is_boss_false_for_normal() -> void:
	var data := _create_test_enemy_data("rusher", 1, 10, 2)
	_enemy.initialize(data, Vector2i(0, 0))

	assert_false(_enemy.is_boss(), "Should not be identified as boss")


# ===== STORM CORE TESTS =====

func test_storm_core_is_invulnerable() -> void:
	var data := _create_test_enemy_data("storm_core", 4, 999, 5, "boss_storm")
	data.is_boss = true
	_enemy.initialize(data, Vector2i(0, 0))

	var actual := _enemy.take_damage(100, Constants.DamageType.PHYSICAL, null)

	assert_eq(actual, 0, "Storm Core should take 0 damage")
	assert_eq(_enemy.current_hp, 999, "Storm Core HP should remain unchanged")


func test_storm_core_identified() -> void:
	var data := _create_test_enemy_data("storm_core", 4, 999, 5, "boss_storm")
	data.is_boss = true
	_enemy.initialize(data, Vector2i(0, 0))

	assert_true(_enemy.is_storm_core(), "Should be identified as Storm Core")
	assert_true(_enemy.is_boss(), "Storm Core should be a boss")


func test_storm_core_hazard_zones_empty_initially() -> void:
	var data := _create_test_enemy_data("storm_core", 4, 999, 5, "boss_storm")
	data.is_boss = true
	_enemy.initialize(data, Vector2i(0, 0))

	var zones := _enemy.get_active_hazard_zones()
	assert_eq(zones.size(), 0, "Should have no hazard zones initially")


# ===== TARGET MANAGEMENT TESTS =====

func test_set_and_get_target() -> void:
	var data := _create_test_enemy_data("test", 1, 10, 2)
	_enemy.initialize(data, Vector2i(0, 0))

	var mock_target := Node2D.new()
	add_child(mock_target)

	var target_changed := false
	_enemy.target_changed.connect(func(_t): target_changed = true)

	_enemy.set_target(mock_target)

	assert_eq(_enemy.get_target(), mock_target, "Target should be set")
	assert_true(target_changed, "Target changed signal should be emitted")

	mock_target.queue_free()


func test_clear_target() -> void:
	var data := _create_test_enemy_data("test", 1, 10, 2)
	_enemy.initialize(data, Vector2i(0, 0))

	var mock_target := Node2D.new()
	add_child(mock_target)
	_enemy.set_target(mock_target)

	_enemy.clear_target()

	assert_null(_enemy.get_target(), "Target should be cleared")

	mock_target.queue_free()


# ===== UTILITY TESTS =====

func test_get_display_name() -> void:
	var data := _create_test_enemy_data("test_enemy", 1, 10, 2)
	data.display_name = "Test Enemy"
	_enemy.initialize(data, Vector2i(0, 0))

	assert_eq(_enemy.get_display_name(), "Test Enemy", "Display name should match")


func test_get_tier() -> void:
	var data := _create_test_enemy_data("test", 2, 10, 2)
	_enemy.initialize(data, Vector2i(0, 0))

	assert_eq(_enemy.get_tier(), 2, "Tier should match")


func test_get_wave_cost() -> void:
	var data := _create_test_enemy_data("test", 1, 10, 2)
	data.wave_cost = 5
	_enemy.initialize(data, Vector2i(0, 0))

	assert_eq(_enemy.get_wave_cost(), 5, "Wave cost should match")


func test_get_health_ratio() -> void:
	var data := _create_test_enemy_data("test", 1, 100, 2)
	_enemy.initialize(data, Vector2i(0, 0))
	_enemy.take_damage(25, Constants.DamageType.PHYSICAL, null)

	assert_almost_eq(_enemy.get_health_ratio(), 0.75, 0.01, "Health ratio should be 0.75")


# ===== DIFFICULTY SCALING TESTS =====

func test_difficulty_scaling_normal() -> void:
	var data := _create_test_enemy_data("test", 1, 100, 10)
	_enemy.initialize(data, Vector2i(0, 0), Constants.Difficulty.NORMAL, 1)

	assert_eq(_enemy.max_hp, 100, "Normal difficulty HP should be base")


func test_difficulty_scaling_hard() -> void:
	var data := _create_test_enemy_data("test", 1, 100, 10)
	_enemy.initialize(data, Vector2i(0, 0), Constants.Difficulty.HARD, 1)

	assert_eq(_enemy.max_hp, 120, "Hard difficulty HP should be 1.2x")


func test_difficulty_scaling_nightmare() -> void:
	var data := _create_test_enemy_data("test", 1, 100, 10)
	_enemy.initialize(data, Vector2i(0, 0), Constants.Difficulty.NIGHTMARE, 1)

	assert_eq(_enemy.max_hp, 200, "Nightmare difficulty HP should be 2.0x")


func test_wave_scaling() -> void:
	var data := _create_test_enemy_data("test", 1, 100, 10)
	_enemy.initialize(data, Vector2i(0, 0), Constants.Difficulty.NORMAL, 5)

	# Wave 5: 1.0 + (5-1) * 0.05 = 1.2
	assert_eq(_enemy.max_hp, 120, "Wave 5 HP should be 1.2x")


# ===== HELPER FUNCTIONS =====

func _create_test_enemy_data(id: String, tier: int, hp: int, damage: int, ability_id: String = "") -> EnemyData:
	var data := EnemyData.new()
	data.id = id
	data.display_name = id.capitalize()
	data.tier = tier
	data.hp = hp
	data.damage = damage
	data.wave_cost = tier
	data.move_speed = 1.5
	data.attack_speed = 1.0
	data.attack_range = 1.0
	data.ability_id = ability_id
	data.is_boss = (tier == 4)
	return data
