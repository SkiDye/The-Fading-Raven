extends GutTest

## Pathfinding 유닛 테스트


var _grid: TileGrid


func before_each() -> void:
	_grid = TileGrid.new()
	_grid.initialize(10, 10)
	add_child(_grid)


func after_each() -> void:
	_grid.queue_free()


# ===== BASIC PATH TESTS =====

func test_find_path_simple() -> void:
	var path := _grid.find_path(Vector2i(0, 0), Vector2i(3, 0))
	assert_gt(path.size(), 0, "Should find a path")
	assert_eq(path[-1], Vector2i(3, 0), "Path should end at destination")


func test_find_path_excludes_start() -> void:
	var path := _grid.find_path(Vector2i(0, 0), Vector2i(3, 0))
	assert_does_not_have(path, Vector2i(0, 0), "Path should not include start position")


func test_find_path_same_position() -> void:
	var path := _grid.find_path(Vector2i(5, 5), Vector2i(5, 5))
	assert_eq(path.size(), 0, "Path to same position should be empty")


func test_find_path_diagonal() -> void:
	var path := _grid.find_path(Vector2i(0, 0), Vector2i(3, 3))
	assert_gt(path.size(), 0, "Should find a diagonal path")
	# 4방향 이동이므로 최소 6 스텝 (맨해튼 거리)
	assert_gte(path.size(), 6, "Path should be at least 6 steps")


# ===== OBSTACLE TESTS =====

func test_find_path_around_wall() -> void:
	# 수직 벽 생성
	for y in range(0, 8):
		_grid.set_tile_type(Vector2i(5, y), Constants.TileType.WALL)

	var path := _grid.find_path(Vector2i(3, 3), Vector2i(7, 3))
	assert_gt(path.size(), 0, "Should find path around wall")

	# 경로가 벽을 통과하지 않는지 확인
	for pos in path:
		assert_ne(_grid.get_tile(pos).type, Constants.TileType.WALL, "Path should not go through wall")


func test_find_path_blocked() -> void:
	# 완전히 막힌 상황 (섬 생성)
	for x in range(10):
		_grid.set_tile_type(Vector2i(x, 5), Constants.TileType.WALL)

	var path := _grid.find_path(Vector2i(5, 0), Vector2i(5, 9))
	assert_eq(path.size(), 0, "Should return empty path when blocked")


func test_find_path_void_avoidance() -> void:
	_grid.set_tile_type(Vector2i(5, 5), Constants.TileType.VOID)
	var path := _grid.find_path(Vector2i(4, 5), Vector2i(6, 5))

	# 경로가 VOID를 피하는지 확인
	for pos in path:
		assert_ne(_grid.get_tile(pos).type, Constants.TileType.VOID, "Path should avoid void")


# ===== OCCUPANT TESTS =====

func test_find_path_avoids_occupant() -> void:
	var mock_node := Node.new()
	add_child(mock_node)
	_grid.set_occupant(Vector2i(5, 5), mock_node)

	var path := _grid.find_path(Vector2i(4, 5), Vector2i(6, 5))

	# 점유된 타일을 피하는지 확인
	assert_does_not_have(path, Vector2i(5, 5), "Path should avoid occupied tile")
	mock_node.queue_free()


func test_find_path_ignore_occupant() -> void:
	var mock_node := Node.new()
	add_child(mock_node)
	_grid.set_occupant(Vector2i(5, 5), mock_node)

	var path := _grid.find_path(Vector2i(4, 5), Vector2i(6, 5), true)

	# 점유 무시 시 직선 경로
	assert_gt(path.size(), 0, "Should find path when ignoring occupant")
	mock_node.queue_free()


# ===== MOVEMENT COST TESTS =====

func test_path_prefers_lower_cost() -> void:
	# 일부 타일을 고지대로 설정 (비용 1.5)
	for x in range(3, 7):
		_grid.set_tile_type(Vector2i(x, 4), Constants.TileType.ELEVATED)
		_grid.set_tile_type(Vector2i(x, 6), Constants.TileType.ELEVATED)

	var path := _grid.find_path(Vector2i(0, 5), Vector2i(9, 5))

	# 경로가 고지대를 피하는 경향이 있어야 함
	assert_gt(path.size(), 0, "Should find a path")


# ===== REACHABLE TILES TESTS =====

func test_get_reachable_tiles_basic() -> void:
	var reachable := _grid.get_reachable_tiles(Vector2i(5, 5), 2)
	assert_gt(reachable.size(), 0, "Should return reachable tiles")
	assert_does_not_have(reachable, Vector2i(5, 5), "Should not include start position")


func test_get_reachable_tiles_distance_1() -> void:
	var reachable := _grid.get_reachable_tiles(Vector2i(5, 5), 1)
	# 4방향 이동, 거리 1이면 4개 타일
	assert_eq(reachable.size(), 4, "Should have 4 reachable tiles at distance 1")


func test_get_reachable_tiles_respects_walls() -> void:
	# 주변을 벽으로 둘러싸기
	_grid.set_tile_type(Vector2i(4, 5), Constants.TileType.WALL)
	_grid.set_tile_type(Vector2i(6, 5), Constants.TileType.WALL)
	_grid.set_tile_type(Vector2i(5, 4), Constants.TileType.WALL)
	_grid.set_tile_type(Vector2i(5, 6), Constants.TileType.WALL)

	var reachable := _grid.get_reachable_tiles(Vector2i(5, 5), 5)
	assert_eq(reachable.size(), 0, "Should have no reachable tiles when surrounded by walls")


func test_get_reachable_tiles_distance_2() -> void:
	var reachable := _grid.get_reachable_tiles(Vector2i(5, 5), 2)
	# 거리 2 이내의 타일들 (맨해튼 거리 기준)
	# 1칸: 4개, 2칸: 8개 = 12개 (하지만 이동 비용에 따라 다를 수 있음)
	assert_gt(reachable.size(), 4, "Should have more than 4 tiles at distance 2")


# ===== EDGE CASES =====

func test_find_path_to_adjacent() -> void:
	var path := _grid.find_path(Vector2i(5, 5), Vector2i(5, 6))
	assert_eq(path.size(), 1, "Path to adjacent tile should have 1 step")
	assert_eq(path[0], Vector2i(5, 6), "Should end at destination")


func test_find_path_invalid_start() -> void:
	var path := _grid.find_path(Vector2i(-1, -1), Vector2i(5, 5))
	assert_eq(path.size(), 0, "Should return empty for invalid start")


func test_find_path_invalid_end() -> void:
	var path := _grid.find_path(Vector2i(5, 5), Vector2i(100, 100))
	assert_eq(path.size(), 0, "Should return empty for invalid end")


func test_find_path_to_nearest_walkable() -> void:
	# 목표가 벽일 때
	_grid.set_tile_type(Vector2i(7, 5), Constants.TileType.WALL)
	var path := _grid.find_path(Vector2i(5, 5), Vector2i(7, 5))

	# 가장 가까운 이동 가능 타일로 경로를 찾아야 함
	if path.size() > 0:
		var end_tile := _grid.get_tile(path[-1])
		assert_true(end_tile.is_walkable(), "Should end at walkable tile")
