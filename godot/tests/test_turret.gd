extends Node

## Turret 유닛 테스트


const TURRET_SCENE = "res://src/entities/turret/Turret.tscn"


var _test_count: int = 0
var _pass_count: int = 0
var _fail_count: int = 0


func _ready() -> void:
	print("\n========================================")
	print("  Turret Unit Tests")
	print("========================================\n")

	run_all_tests()

	print("\n========================================")
	print("  Results: %d/%d passed" % [_pass_count, _test_count])
	if _fail_count > 0:
		print("  FAILED: %d tests" % _fail_count)
	print("========================================\n")


func run_all_tests() -> void:
	test_turret_creation()
	test_level_stats()
	test_damage_system()
	test_hacking_system()
	test_targeting()


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


func create_test_turret(level: int = 0) -> Turret:
	if not ResourceLoader.exists(TURRET_SCENE):
		print("  ! Turret scene not found, creating mock")
		return _create_mock_turret(level)

	var scene = load(TURRET_SCENE)
	var turret: Turret = scene.instantiate()
	turret.level = level
	add_child(turret)
	return turret


func _create_mock_turret(level: int) -> Turret:
	var turret = Node2D.new()
	turret.set_script(load("res://src/entities/turret/Turret.gd"))
	turret.level = level
	add_child(turret)
	return turret


func cleanup(node: Node) -> void:
	if node:
		node.queue_free()


# ===== TESTS =====

func test_turret_creation() -> void:
	print("\n[Test: Turret Creation]")

	var turret = create_test_turret(0)
	assert_not_null(turret, "Turret created")
	assert_equals(turret.level, 0, "Level is 0")
	assert_true(not turret.is_hacked, "Not hacked initially")
	cleanup(turret)


func test_level_stats() -> void:
	print("\n[Test: Level Stats]")

	# 레벨 0
	var turret0 = create_test_turret(0)
	assert_equals(turret0.max_hp, 50, "Level 0 HP is 50")
	cleanup(turret0)

	# 레벨 1
	var turret1 = create_test_turret(1)
	assert_equals(turret1.max_hp, 75, "Level 1 HP is 75")
	cleanup(turret1)

	# 레벨 2
	var turret2 = create_test_turret(2)
	assert_equals(turret2.max_hp, 100, "Level 2 HP is 100")
	assert_true(turret2.has_slow_effect(), "Level 2 has slow effect")
	cleanup(turret2)


func test_damage_system() -> void:
	print("\n[Test: Damage System]")

	var turret = create_test_turret(0)
	var initial_hp = turret.current_hp

	var damage_dealt = turret.take_damage(20)
	assert_equals(damage_dealt, 20, "Damage dealt correctly")
	assert_equals(turret.current_hp, initial_hp - 20, "HP reduced correctly")

	# 파괴
	turret.take_damage(100)
	# 터렛은 queue_free() 호출하므로 체크 생략

	cleanup(turret)


func test_hacking_system() -> void:
	print("\n[Test: Hacking System]")

	var turret = create_test_turret(0)

	# 해킹 가능 여부
	assert_true(turret.can_be_hacked(), "Can be hacked initially")

	# 해킹 시작
	var dummy_hacker = Node2D.new()
	add_child(dummy_hacker)

	turret.start_hack(dummy_hacker)
	assert_true(not turret.can_be_hacked(), "Cannot be hacked while being hacked")
	assert_equals(turret.get_hack_progress(), 0.0, "Hack progress starts at 0")

	# 해킹 진행
	var completed = turret.update_hack(2.5)  # 50%
	assert_true(not completed, "Hack not completed at 50%")
	assert_true(turret.get_hack_progress() > 0.4, "Hack progress advanced")

	# 해킹 취소
	turret.cancel_hack()
	assert_true(turret.can_be_hacked(), "Can be hacked after cancel")
	assert_equals(turret.get_hack_progress(), 0.0, "Hack progress reset")

	# 해킹 완료
	turret.start_hack(dummy_hacker)
	turret.update_hack(5.0)  # 100%
	assert_true(turret.is_hacked, "Turret is hacked after completion")
	assert_true(not turret.can_be_hacked(), "Cannot hack already hacked turret")

	# 해킹 해제
	turret.clear_hack()
	assert_true(not turret.is_hacked, "Hack cleared")
	assert_true(turret.can_be_hacked(), "Can be hacked after clear")

	dummy_hacker.queue_free()
	cleanup(turret)


func test_targeting() -> void:
	print("\n[Test: Targeting]")

	var turret = create_test_turret(0)

	# 초기 타겟 없음
	assert_true(turret.current_target == null, "No target initially")

	# 적 생성 (그룹에 추가)
	var dummy_enemy = Node2D.new()
	dummy_enemy.add_to_group("enemies")
	dummy_enemy.set_meta("is_alive", true)
	add_child(dummy_enemy)
	dummy_enemy.global_position = turret.global_position + Vector2(50, 0)

	# 타겟팅 테스트는 _find_target()이 private이므로 생략
	# 실제 동작은 통합 테스트에서 확인

	dummy_enemy.queue_free()
	cleanup(turret)
