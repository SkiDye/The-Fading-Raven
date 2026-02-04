extends Node

## CrewMember 유닛 테스트


const CREW_MEMBER_SCENE = "res://src/entities/crew/CrewMember.tscn"


var _test_count: int = 0
var _pass_count: int = 0
var _fail_count: int = 0


func _ready() -> void:
	print("\n========================================")
	print("  CrewMember Unit Tests")
	print("========================================\n")

	run_all_tests()

	print("\n========================================")
	print("  Results: %d/%d passed" % [_pass_count, _test_count])
	if _fail_count > 0:
		print("  FAILED: %d tests" % _fail_count)
	print("========================================\n")


func run_all_tests() -> void:
	test_member_creation()
	test_initialization()
	test_damage_system()
	test_death_and_revive()
	test_attack_system()


# ===== TEST UTILITIES =====

func assert_true(condition: bool, message: String) -> void:
	_test_count += 1
	if condition:
		_pass_count += 1
		print("  ✓ %s" % message)
	else:
		_fail_count += 1
		print("  ✗ %s" % message)


func assert_equals(a, b, message: String) -> void:
	assert_true(a == b, "%s (expected %s, got %s)" % [message, str(b), str(a)])


func assert_not_null(obj, message: String) -> void:
	assert_true(obj != null, message)


func create_test_member() -> CrewMember:
	if not ResourceLoader.exists(CREW_MEMBER_SCENE):
		print("  ! CrewMember scene not found, creating mock")
		return _create_mock_member()

	var scene = load(CREW_MEMBER_SCENE)
	var member: CrewMember = scene.instantiate()
	add_child(member)
	return member


func _create_mock_member() -> CrewMember:
	var member = Node2D.new()
	member.set_script(load("res://src/entities/crew/CrewMember.gd"))
	add_child(member)
	return member


func cleanup(node: Node) -> void:
	if node:
		node.queue_free()


# ===== TESTS =====

func test_member_creation() -> void:
	print("\n[Test: Member Creation]")

	var member = create_test_member()
	assert_not_null(member, "CrewMember created")
	assert_true(member.is_alive, "Member is alive initially")
	cleanup(member)


func test_initialization() -> void:
	print("\n[Test: Initialization]")

	var member = create_test_member()
	member.initialize("guardian", 10, 3, 1.0, Color.BLUE)

	assert_equals(member.class_id, "guardian", "Class ID set correctly")
	assert_equals(member.max_hp, 10, "Max HP set correctly")
	assert_equals(member.current_hp, 10, "Current HP equals max HP")

	cleanup(member)


func test_damage_system() -> void:
	print("\n[Test: Damage System]")

	var member = create_test_member()
	member.initialize("guardian", 10, 3, 1.0, Color.BLUE)

	var initial_hp = member.current_hp
	var damage_dealt = member.take_damage(3)

	assert_equals(damage_dealt, 3, "Damage dealt correctly")
	assert_equals(member.current_hp, initial_hp - 3, "HP reduced correctly")

	# 과도한 데미지
	member.current_hp = 5
	damage_dealt = member.take_damage(10)
	assert_equals(damage_dealt, 5, "Damage capped at current HP")
	assert_equals(member.current_hp, 0, "HP is zero after lethal damage")

	cleanup(member)


func test_death_and_revive() -> void:
	print("\n[Test: Death and Revive]")

	var member = create_test_member()
	member.initialize("guardian", 10, 3, 1.0, Color.BLUE)

	# 사망
	member.take_damage(15)
	assert_true(not member.is_alive, "Member is dead after lethal damage")
	assert_true(not member.visible, "Member is invisible when dead")

	# 부활
	member.revive()
	assert_true(member.is_alive, "Member is alive after revive")
	assert_equals(member.current_hp, member.max_hp, "HP restored to max after revive")
	assert_true(member.visible, "Member is visible after revive")

	cleanup(member)


func test_attack_system() -> void:
	print("\n[Test: Attack System]")

	var member = create_test_member()
	member.initialize("guardian", 10, 3, 1.0, Color.BLUE)

	# 타겟 없음
	assert_true(member.current_target == null, "No target initially")

	# 타겟 설정
	var dummy_target = Node2D.new()
	dummy_target.set_meta("is_alive", true)
	add_child(dummy_target)

	member.set_target(dummy_target)
	assert_equals(member.current_target, dummy_target, "Target set correctly")

	# 타겟 해제
	member.clear_target()
	assert_true(member.current_target == null, "Target cleared")

	cleanup(member)
	dummy_target.queue_free()
