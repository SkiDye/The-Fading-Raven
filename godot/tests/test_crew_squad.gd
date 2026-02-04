extends Node

## CrewSquad 유닛 테스트
## 콘솔에서 실행: res://tests/test_crew_squad.gd


const CREW_SQUAD_SCENE = "res://src/entities/crew/CrewSquad.tscn"


var _test_count: int = 0
var _pass_count: int = 0
var _fail_count: int = 0


func _ready() -> void:
	print("\n========================================")
	print("  CrewSquad Unit Tests")
	print("========================================\n")

	run_all_tests()

	print("\n========================================")
	print("  Results: %d/%d passed" % [_pass_count, _test_count])
	if _fail_count > 0:
		print("  FAILED: %d tests" % _fail_count)
	print("========================================\n")


func run_all_tests() -> void:
	test_squad_creation()
	test_class_stats()
	test_formation_generation()
	test_skill_cooldown()
	test_damage_calculation()
	test_recovery_system()
	test_member_management()


# ===== TEST UTILITIES =====

func assert_true(condition: bool, message: String) -> void:
	_test_count += 1
	if condition:
		_pass_count += 1
		print("  ✓ %s" % message)
	else:
		_fail_count += 1
		print("  ✗ %s" % message)


func assert_false(condition: bool, message: String) -> void:
	assert_true(not condition, message)


func assert_equals(a, b, message: String) -> void:
	assert_true(a == b, "%s (expected %s, got %s)" % [message, str(b), str(a)])


func assert_not_null(obj, message: String) -> void:
	assert_true(obj != null, message)


func create_test_squad(class_id: String = "guardian") -> Node:
	if not ResourceLoader.exists(CREW_SQUAD_SCENE):
		print("  ! CrewSquad scene not found, creating mock")
		return _create_mock_squad(class_id)

	var scene = load(CREW_SQUAD_SCENE)
	var squad = scene.instantiate()
	squad.class_id = class_id
	add_child(squad)
	return squad


func _create_mock_squad(class_id: String) -> Node:
	# 씬 없이 스크립트로 테스트
	var squad = Node2D.new()
	squad.set_script(load("res://src/entities/crew/CrewSquad.gd"))
	squad.class_id = class_id
	add_child(squad)
	return squad


func cleanup_squad(squad: Node) -> void:
	if squad:
		squad.queue_free()


# ===== TESTS =====

func test_squad_creation() -> void:
	print("\n[Test: Squad Creation]")

	var squad = create_test_squad("guardian")
	assert_not_null(squad, "Guardian squad created")
	assert_equals(squad.class_id, "guardian", "Class ID is guardian")
	assert_equals(squad.team, 0, "Team is player (0)")
	cleanup_squad(squad)

	squad = create_test_squad("sentinel")
	assert_equals(squad.class_id, "sentinel", "Sentinel squad created")
	cleanup_squad(squad)

	squad = create_test_squad("ranger")
	assert_equals(squad.class_id, "ranger", "Ranger squad created")
	cleanup_squad(squad)

	squad = create_test_squad("engineer")
	assert_equals(squad.class_id, "engineer", "Engineer squad created")
	cleanup_squad(squad)

	squad = create_test_squad("bionic")
	assert_equals(squad.class_id, "bionic", "Bionic squad created")
	cleanup_squad(squad)


func test_class_stats() -> void:
	print("\n[Test: Class Stats]")

	var squad = create_test_squad("guardian")

	# 기본 스탯 확인
	var damage = squad.get_effective_damage()
	assert_true(damage > 0, "Guardian has positive damage: %d" % damage)

	var move_speed = squad.get_effective_move_speed()
	assert_true(move_speed > 0, "Guardian has positive move speed: %.2f" % move_speed)

	var cooldown = squad.get_effective_cooldown()
	assert_true(cooldown > 0, "Guardian has positive cooldown: %.2f" % cooldown)

	var attack_range = squad.get_effective_attack_range()
	assert_true(attack_range > 0, "Guardian has positive attack range: %.2f" % attack_range)

	cleanup_squad(squad)

	# 바이오닉 스탯 (더 높은 이동속도, 낮은 분대 크기)
	squad = create_test_squad("bionic")
	var bionic_speed = squad.get_effective_move_speed()
	assert_true(bionic_speed > move_speed, "Bionic is faster than Guardian")

	var bionic_size = squad.get_max_squad_size()
	assert_equals(bionic_size, 5, "Bionic squad size is 5")

	cleanup_squad(squad)


func test_formation_generation() -> void:
	print("\n[Test: Formation Generation]")

	var squad = create_test_squad("guardian")
	squad.initialize_squad(1.0)

	assert_equals(squad.formation_type, "line", "Guardian uses line formation")
	assert_true(squad.formation_positions.size() > 0, "Formation positions generated")

	cleanup_squad(squad)

	squad = create_test_squad("ranger")
	squad.initialize_squad(1.0)
	assert_equals(squad.formation_type, "square", "Ranger uses square formation")

	cleanup_squad(squad)

	squad = create_test_squad("bionic")
	squad.initialize_squad(1.0)
	assert_equals(squad.formation_type, "wedge", "Bionic uses wedge formation")

	cleanup_squad(squad)


func test_skill_cooldown() -> void:
	print("\n[Test: Skill Cooldown]")

	var squad = create_test_squad("guardian")
	squad.initialize_squad(1.0)

	# 초기 상태: 스킬 사용 가능
	assert_true(squad.can_use_skill(), "Skill ready initially")
	assert_equals(squad.skill_cooldown_remaining, 0.0, "No cooldown initially")

	# 스킬 사용 (타겟은 방향)
	var result = squad.use_skill(Vector2.RIGHT)
	assert_true(result, "Skill used successfully")

	# 쿨다운 시작
	assert_false(squad.can_use_skill(), "Skill on cooldown after use")
	assert_true(squad.skill_cooldown_remaining > 0, "Cooldown timer started")

	cleanup_squad(squad)


func test_damage_calculation() -> void:
	print("\n[Test: Damage Calculation]")

	# Guardian 실드 테스트
	var squad = create_test_squad("guardian")
	squad.initialize_squad(1.0)
	squad.is_in_combat = false

	var initial_hp = squad.current_hp

	# 에너지 데미지 (실드로 90% 감소)
	var energy_damage = squad._calculate_actual_damage(100, Constants.DamageType.ENERGY, null)
	assert_equals(energy_damage, 10, "Guardian shield reduces energy damage by 90%%")

	# 물리 데미지 (감소 없음)
	var physical_damage = squad._calculate_actual_damage(100, Constants.DamageType.PHYSICAL, null)
	assert_equals(physical_damage, 100, "Physical damage not reduced by shield")

	cleanup_squad(squad)

	# Reinforced Armor 특성 테스트
	squad = create_test_squad("sentinel")
	squad.trait_id = "reinforced_armor"
	squad.initialize_squad(1.0)

	var armor_damage = squad._calculate_actual_damage(100, Constants.DamageType.PHYSICAL, null)
	assert_equals(armor_damage, 75, "Reinforced Armor reduces damage by 25%%")

	cleanup_squad(squad)


func test_recovery_system() -> void:
	print("\n[Test: Recovery System]")

	var squad = create_test_squad("guardian")
	squad.initialize_squad(0.5)  # 50% HP로 시작

	var initial_alive = squad.get_alive_count()
	var max_size = squad.get_max_squad_size()

	assert_true(initial_alive < max_size, "Squad starts with reduced members")
	assert_false(squad.is_recovering, "Not recovering initially")

	# 회복 시작
	squad.start_recovery(null)
	assert_true(squad.is_recovering, "Recovery started")

	# 회복 중단
	squad.stop_recovery()
	assert_false(squad.is_recovering, "Recovery stopped")

	cleanup_squad(squad)


func test_member_management() -> void:
	print("\n[Test: Member Management]")

	var squad = create_test_squad("guardian")
	squad.initialize_squad(1.0)

	var alive_count = squad.get_alive_count()
	var max_size = squad.get_max_squad_size()

	assert_equals(alive_count, max_size, "Full squad at 100%% HP")
	assert_true(squad.members.size() == max_size, "Correct number of members")
	assert_not_null(squad.leader, "Leader assigned")
	assert_true(squad.leader.is_leader, "Leader flag set")

	cleanup_squad(squad)
