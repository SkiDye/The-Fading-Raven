extends GutTest

## BehaviorTree 및 AIManager 유닛 테스트


# ===== BEHAVIOR TREE TESTS =====

func test_bt_status_enum() -> void:
	assert_eq(BehaviorTree.Status.SUCCESS, 0)
	assert_eq(BehaviorTree.Status.FAILURE, 1)
	assert_eq(BehaviorTree.Status.RUNNING, 2)


func test_bt_node_base() -> void:
	var node = BehaviorTree.BTNode.new()
	var result = node.tick(null, 0.1)
	assert_eq(result, BehaviorTree.Status.SUCCESS, "Base node should return SUCCESS")


func test_bt_node_add_child() -> void:
	var parent = BehaviorTree.BTNode.new()
	var child = BehaviorTree.BTNode.new()

	var returned = parent.add_child(child)

	assert_eq(parent.children.size(), 1, "Should have one child")
	assert_eq(returned, parent, "add_child should return parent for chaining")


# ===== SELECTOR TESTS =====

func test_bt_selector_returns_first_success() -> void:
	var selector = BehaviorTree.BTSelector.new()

	var fail_node = BehaviorTree.BTAction.new(func(e, d): return BehaviorTree.Status.FAILURE)
	var success_node = BehaviorTree.BTAction.new(func(e, d): return BehaviorTree.Status.SUCCESS)

	selector.children = [fail_node, success_node]

	var result = selector.tick(null, 0.1)
	assert_eq(result, BehaviorTree.Status.SUCCESS, "Selector should return SUCCESS")


func test_bt_selector_returns_failure_when_all_fail() -> void:
	var selector = BehaviorTree.BTSelector.new()

	var fail1 = BehaviorTree.BTAction.new(func(e, d): return BehaviorTree.Status.FAILURE)
	var fail2 = BehaviorTree.BTAction.new(func(e, d): return BehaviorTree.Status.FAILURE)

	selector.children = [fail1, fail2]

	var result = selector.tick(null, 0.1)
	assert_eq(result, BehaviorTree.Status.FAILURE, "Selector should return FAILURE")


func test_bt_selector_stops_on_running() -> void:
	var selector = BehaviorTree.BTSelector.new()
	var call_count: int = 0

	var running_node = BehaviorTree.BTAction.new(func(e, d):
		call_count += 1
		return BehaviorTree.Status.RUNNING
	)
	var success_node = BehaviorTree.BTAction.new(func(e, d):
		call_count += 1
		return BehaviorTree.Status.SUCCESS
	)

	selector.children = [running_node, success_node]

	var result = selector.tick(null, 0.1)
	assert_eq(result, BehaviorTree.Status.RUNNING, "Should return RUNNING")
	assert_eq(call_count, 1, "Should stop at RUNNING node")


# ===== SEQUENCE TESTS =====

func test_bt_sequence_returns_failure_on_first_failure() -> void:
	var sequence = BehaviorTree.BTSequence.new()

	var success_node = BehaviorTree.BTAction.new(func(e, d): return BehaviorTree.Status.SUCCESS)
	var fail_node = BehaviorTree.BTAction.new(func(e, d): return BehaviorTree.Status.FAILURE)

	sequence.children = [success_node, fail_node]

	var result = sequence.tick(null, 0.1)
	assert_eq(result, BehaviorTree.Status.FAILURE, "Sequence should return FAILURE")


func test_bt_sequence_returns_success_when_all_succeed() -> void:
	var sequence = BehaviorTree.BTSequence.new()

	var success1 = BehaviorTree.BTAction.new(func(e, d): return BehaviorTree.Status.SUCCESS)
	var success2 = BehaviorTree.BTAction.new(func(e, d): return BehaviorTree.Status.SUCCESS)

	sequence.children = [success1, success2]

	var result = sequence.tick(null, 0.1)
	assert_eq(result, BehaviorTree.Status.SUCCESS, "Sequence should return SUCCESS")


func test_bt_sequence_stops_on_running() -> void:
	var sequence = BehaviorTree.BTSequence.new()

	var success_node = BehaviorTree.BTAction.new(func(e, d): return BehaviorTree.Status.SUCCESS)
	var running_node = BehaviorTree.BTAction.new(func(e, d): return BehaviorTree.Status.RUNNING)

	sequence.children = [success_node, running_node]

	var result = sequence.tick(null, 0.1)
	assert_eq(result, BehaviorTree.Status.RUNNING, "Should return RUNNING")


# ===== CONDITION TESTS =====

func test_bt_condition_true() -> void:
	var condition = BehaviorTree.BTCondition.new(func(e): return true)
	var result = condition.tick(null, 0.1)
	assert_eq(result, BehaviorTree.Status.SUCCESS, "True condition should return SUCCESS")


func test_bt_condition_false() -> void:
	var condition = BehaviorTree.BTCondition.new(func(e): return false)
	var result = condition.tick(null, 0.1)
	assert_eq(result, BehaviorTree.Status.FAILURE, "False condition should return FAILURE")


func test_bt_condition_with_entity() -> void:
	var mock_entity = {"health": 50}
	var condition = BehaviorTree.BTCondition.new(func(e): return e.health > 0)

	var result = condition.tick(mock_entity, 0.1)
	assert_eq(result, BehaviorTree.Status.SUCCESS, "Should check entity property")


# ===== ACTION TESTS =====

func test_bt_action_executes() -> void:
	var executed: bool = false
	var action = BehaviorTree.BTAction.new(func(e, d):
		executed = true
		return BehaviorTree.Status.SUCCESS
	)

	action.tick(null, 0.1)
	assert_true(executed, "Action should execute")


func test_bt_action_receives_delta() -> void:
	var received_delta: float = 0.0
	var action = BehaviorTree.BTAction.new(func(e, d):
		received_delta = d
		return BehaviorTree.Status.SUCCESS
	)

	action.tick(null, 0.5)
	assert_almost_eq(received_delta, 0.5, 0.001, "Action should receive delta")


# ===== DECORATOR TESTS =====

func test_bt_inverter() -> void:
	var child = BehaviorTree.BTAction.new(func(e, d): return BehaviorTree.Status.SUCCESS)
	var inverter = BehaviorTree.BTInverter.new()
	inverter.children = [child]

	var result = inverter.tick(null, 0.1)
	assert_eq(result, BehaviorTree.Status.FAILURE, "Inverter should flip SUCCESS to FAILURE")


func test_bt_succeeder() -> void:
	var child = BehaviorTree.BTAction.new(func(e, d): return BehaviorTree.Status.FAILURE)
	var succeeder = BehaviorTree.BTSucceeder.new()
	succeeder.children = [child]

	var result = succeeder.tick(null, 0.1)
	assert_eq(result, BehaviorTree.Status.SUCCESS, "Succeeder should always return SUCCESS")


func test_bt_wait() -> void:
	var wait_node = BehaviorTree.BTWait.new(1.0)

	var result1 = wait_node.tick(null, 0.5)
	assert_eq(result1, BehaviorTree.Status.RUNNING, "Should be RUNNING before time")

	var result2 = wait_node.tick(null, 0.6)
	assert_eq(result2, BehaviorTree.Status.SUCCESS, "Should be SUCCESS after time")


# ===== BUILDER HELPER TESTS =====

func test_bt_selector_helper() -> void:
	var selector = BehaviorTree.selector([
		BehaviorTree.action(func(e, d): return BehaviorTree.Status.FAILURE),
		BehaviorTree.action(func(e, d): return BehaviorTree.Status.SUCCESS)
	])

	var result = selector.tick(null, 0.1)
	assert_eq(result, BehaviorTree.Status.SUCCESS, "Helper-built selector should work")


func test_bt_sequence_helper() -> void:
	var sequence = BehaviorTree.sequence([
		BehaviorTree.action(func(e, d): return BehaviorTree.Status.SUCCESS),
		BehaviorTree.action(func(e, d): return BehaviorTree.Status.SUCCESS)
	])

	var result = sequence.tick(null, 0.1)
	assert_eq(result, BehaviorTree.Status.SUCCESS, "Helper-built sequence should work")


func test_bt_condition_helper() -> void:
	var condition = BehaviorTree.condition(func(e): return true)
	var result = condition.tick(null, 0.1)
	assert_eq(result, BehaviorTree.Status.SUCCESS, "Helper-built condition should work")


func test_bt_invert_helper() -> void:
	var inverted = BehaviorTree.invert(
		BehaviorTree.action(func(e, d): return BehaviorTree.Status.SUCCESS)
	)

	var result = inverted.tick(null, 0.1)
	assert_eq(result, BehaviorTree.Status.FAILURE, "Helper-built inverter should work")


# ===== COMPLEX TREE TESTS =====

func test_complex_behavior_tree() -> void:
	# 간단한 AI 시뮬레이션
	var mock_enemy = {
		"current_target": {"position": Vector2(100, 100)},
		"position": Vector2(0, 0),
		"health": 50
	}

	var has_target = BehaviorTree.condition(func(e): return e.current_target != null)
	var has_health = BehaviorTree.condition(func(e): return e.health > 0)

	var attack = BehaviorTree.action(func(e, d):
		return BehaviorTree.Status.SUCCESS
	)

	var chase = BehaviorTree.action(func(e, d):
		return BehaviorTree.Status.RUNNING
	)

	var tree = BehaviorTree.selector([
		BehaviorTree.sequence([has_target, has_health, attack]),
		chase
	])

	var result = tree.tick(mock_enemy, 0.1)
	assert_eq(result, BehaviorTree.Status.SUCCESS, "Complex tree should execute correctly")


# ===== AI MANAGER TESTS =====

var ai_manager: AIManager


func test_ai_manager_creation() -> void:
	ai_manager = AIManager.new()
	add_child(ai_manager)

	assert_not_null(ai_manager, "AIManager should be created")
	assert_true(ai_manager.behavior_trees.size() > 0, "Should have behavior trees")

	ai_manager.queue_free()


func test_ai_manager_has_all_behavior_trees() -> void:
	ai_manager = AIManager.new()
	add_child(ai_manager)

	var expected_behaviors: Array = [
		"melee_rush", "ranged", "jumper", "brute", "sniper",
		"hacker", "shield_trooper", "heavy_trooper",
		"drone_carrier", "shield_generator"
	]

	for behavior_id in expected_behaviors:
		assert_true(
			ai_manager.behavior_trees.has(behavior_id),
			"Should have '%s' behavior tree" % behavior_id
		)

	ai_manager.queue_free()


func test_ai_manager_initialize() -> void:
	ai_manager = AIManager.new()
	add_child(ai_manager)

	var mock_grid = Node2D.new()
	var mock_battle = Node.new()

	ai_manager.initialize(mock_grid, mock_battle)

	assert_true(ai_manager._is_active, "Should be active after initialize")

	mock_grid.queue_free()
	mock_battle.queue_free()
	ai_manager.queue_free()


func test_ai_manager_deactivate_activate() -> void:
	ai_manager = AIManager.new()
	add_child(ai_manager)

	ai_manager.deactivate()
	assert_false(ai_manager._is_active, "Should be inactive after deactivate")

	ai_manager.activate()
	assert_true(ai_manager._is_active, "Should be active after activate")

	ai_manager.queue_free()
