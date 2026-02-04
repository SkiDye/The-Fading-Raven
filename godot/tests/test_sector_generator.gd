extends GutTest

## SectorGenerator 유닛 테스트


var _generator: SectorGenerator


func before_each() -> void:
	_generator = SectorGenerator.new()


func after_each() -> void:
	_generator = null


# ===== SEED REPRODUCIBILITY =====

func test_same_seed_produces_same_result() -> void:
	var seed := 12345

	var sector1 := _generator.generate(seed, Constants.Difficulty.NORMAL)
	var sector2 := _generator.generate(seed, Constants.Difficulty.NORMAL)

	assert_eq(sector1.total_depth, sector2.total_depth, "Same seed should produce same depth")
	assert_eq(sector1.layers.size(), sector2.layers.size(), "Same seed should produce same layer count")

	# 모든 노드 비교
	for layer_idx in range(sector1.layers.size()):
		var layer1: Array = sector1.layers[layer_idx]
		var layer2: Array = sector2.layers[layer_idx]
		assert_eq(layer1.size(), layer2.size(), "Layer %d should have same node count" % layer_idx)

		for node_idx in range(layer1.size()):
			var node1 = layer1[node_idx]
			var node2 = layer2[node_idx]
			assert_eq(node1.id, node2.id, "Node IDs should match")
			assert_eq(node1.node_type, node2.node_type, "Node types should match")


func test_different_seeds_produce_different_results() -> void:
	var sector1 := _generator.generate(11111, Constants.Difficulty.NORMAL)
	var sector2 := _generator.generate(22222, Constants.Difficulty.NORMAL)

	# 완전히 같을 확률은 매우 낮음
	var differences := 0

	for id in sector1.nodes.keys():
		if sector2.nodes.has(id):
			var n1 = sector1.nodes[id]
			var n2 = sector2.nodes[id]
			if n1.node_type != n2.node_type:
				differences += 1

	assert_gt(differences, 0, "Different seeds should produce different maps")


# ===== DAG STRUCTURE =====

func test_start_node_exists() -> void:
	var sector := _generator.generate(12345, Constants.Difficulty.NORMAL)
	var start := sector.get_start_node()

	assert_not_null(start, "Start node should exist")
	assert_eq(start.node_type, Constants.NodeType.START, "Start node should have START type")
	assert_eq(start.layer, 0, "Start node should be at layer 0")


func test_gate_node_exists() -> void:
	var sector := _generator.generate(12345, Constants.Difficulty.NORMAL)
	var gate := sector.get_gate_node()

	assert_not_null(gate, "Gate node should exist")
	assert_eq(gate.node_type, Constants.NodeType.GATE, "Gate node should have GATE type")
	assert_eq(gate.layer, sector.total_depth, "Gate should be at last layer")


func test_all_nodes_are_connected() -> void:
	var sector := _generator.generate(12345, Constants.Difficulty.NORMAL)

	# 모든 노드가 최소 1개의 연결을 가지는지 (마지막 레이어 제외)
	for layer_idx in range(sector.layers.size() - 1):
		var layer: Array = sector.layers[layer_idx]
		for node in layer:
			assert_gt(node.connections_out.size(), 0,
				"Node %s should have at least one outgoing connection" % node.id)


func test_no_isolated_nodes() -> void:
	var sector := _generator.generate(12345, Constants.Difficulty.NORMAL)

	# 모든 노드가 시작점에서 도달 가능한지
	var reachable: Dictionary = {}
	var queue: Array = [sector.get_start_node()]

	while not queue.is_empty():
		var current = queue.pop_front()
		if reachable.has(current.id):
			continue
		reachable[current.id] = true

		for out_id in current.connections_out:
			var out_node = sector.get_node(out_id)
			if out_node:
				queue.append(out_node)

	assert_eq(reachable.size(), sector.nodes.size(),
		"All nodes should be reachable from start")


func test_path_to_gate_exists() -> void:
	var sector := _generator.generate(12345, Constants.Difficulty.NORMAL)

	assert_true(sector.is_path_to_gate_available(),
		"Path from start to gate should exist")


# ===== DIFFICULTY SCALING =====

func test_difficulty_affects_depth() -> void:
	var normal := _generator.generate(12345, Constants.Difficulty.NORMAL)
	var nightmare := _generator.generate(12345, Constants.Difficulty.NIGHTMARE)

	# Nightmare은 더 깊은 맵을 가질 가능성이 높음
	# (같은 시드라도 난이도에 따라 depth_range가 다름)
	assert_true(nightmare.total_depth >= normal.total_depth,
		"Nightmare should have depth >= Normal")


func test_difficulty_score_increases_with_depth() -> void:
	var sector := _generator.generate(12345, Constants.Difficulty.NORMAL)

	var prev_score := 0.0
	for layer_idx in range(1, sector.layers.size()):
		var layer: Array = sector.layers[layer_idx]
		for node in layer:
			if node.node_type == Constants.NodeType.BATTLE:
				assert_gt(node.difficulty_score, prev_score,
					"Difficulty score should increase with depth")
				prev_score = node.difficulty_score
				break


# ===== EVENT PLACEMENT =====

func test_commander_nodes_exist() -> void:
	# 큰 시드 범위에서 커맨더가 나타나는지
	var found_commander := false

	for seed in range(10000, 10010):
		var sector := _generator.generate(seed, Constants.Difficulty.NORMAL)
		for id in sector.nodes:
			if sector.nodes[id].node_type == Constants.NodeType.COMMANDER:
				found_commander = true
				break
		if found_commander:
			break

	assert_true(found_commander, "Commander nodes should appear in some seeds")


func test_equipment_nodes_exist() -> void:
	var found_equipment := false

	for seed in range(10000, 10010):
		var sector := _generator.generate(seed, Constants.Difficulty.NORMAL)
		for id in sector.nodes:
			if sector.nodes[id].node_type == Constants.NodeType.EQUIPMENT:
				found_equipment = true
				break
		if found_equipment:
			break

	assert_true(found_equipment, "Equipment nodes should appear in some seeds")


func test_boss_nodes_exist() -> void:
	var found_boss := false

	for seed in range(10000, 10020):
		var sector := _generator.generate(seed, Constants.Difficulty.NORMAL)
		for id in sector.nodes:
			if sector.nodes[id].node_type == Constants.NodeType.BOSS:
				found_boss = true
				break
		if found_boss:
			break

	assert_true(found_boss, "Boss nodes should appear in some seeds")


# ===== STORM SYSTEM =====

func test_storm_advance() -> void:
	var sector := _generator.generate(12345, Constants.Difficulty.NORMAL)

	assert_eq(sector.storm_depth, -1, "Initial storm depth should be -1")

	sector.advance_storm()
	assert_eq(sector.storm_depth, 0, "Storm should advance to depth 0")

	sector.advance_storm()
	assert_eq(sector.storm_depth, 1, "Storm should advance to depth 1")


func test_storm_blocks_nodes() -> void:
	var sector := _generator.generate(12345, Constants.Difficulty.NORMAL)

	# 스톰을 깊이 1까지 전진
	sector.advance_storm()
	sector.advance_storm()

	# 현재 위치를 레이어 1로 이동
	var layer1: Array = sector.layers[1]
	if not layer1.is_empty():
		sector.current_node_id = layer1[0].id

		var reachable := sector.get_reachable_nodes(sector.current_node_id)

		# 모든 도달 가능 노드는 storm_depth(1) 보다 커야 함
		for node in reachable:
			assert_gt(node.layer, sector.storm_depth,
				"Reachable nodes should be beyond storm front")


# ===== HELPER FUNCTIONS =====

func test_get_node_type_name() -> void:
	assert_eq(SectorGenerator.get_node_type_name(Constants.NodeType.START), "Start")
	assert_eq(SectorGenerator.get_node_type_name(Constants.NodeType.BATTLE), "Battle")
	assert_eq(SectorGenerator.get_node_type_name(Constants.NodeType.GATE), "Gate")


func test_get_node_type_color() -> void:
	var start_color := SectorGenerator.get_node_type_color(Constants.NodeType.START)
	var gate_color := SectorGenerator.get_node_type_color(Constants.NodeType.GATE)

	assert_ne(start_color, gate_color, "Different node types should have different colors")
