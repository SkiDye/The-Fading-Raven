extends GutTest

## LineOfSight 유닛 테스트


var _grid: TileGrid


func before_each() -> void:
	_grid = TileGrid.new()
	_grid.initialize(10, 10)
	add_child(_grid)


func after_each() -> void:
	_grid.queue_free()


# ===== BASIC LOS TESTS =====

func test_has_los_clear_path() -> void:
	var has_los := _grid.has_line_of_sight(Vector2i(0, 5), Vector2i(9, 5))
	assert_true(has_los, "Should have LOS on clear horizontal path")


func test_has_los_blocked_by_wall() -> void:
	_grid.set_tile_type(Vector2i(5, 5), Constants.TileType.WALL)
	var has_los := _grid.has_line_of_sight(Vector2i(0, 5), Vector2i(9, 5))
	assert_false(has_los, "Should not have LOS through wall")


func test_has_los_diagonal() -> void:
	var has_los := _grid.has_line_of_sight(Vector2i(0, 0), Vector2i(5, 5))
	assert_true(has_los, "Should have LOS on clear diagonal path")


func test_has_los_same_tile() -> void:
	var has_los := _grid.has_line_of_sight(Vector2i(5, 5), Vector2i(5, 5))
	assert_true(has_los, "Should have LOS to same tile")


func test_has_los_adjacent() -> void:
	var has_los := _grid.has_line_of_sight(Vector2i(5, 5), Vector2i(5, 6))
	assert_true(has_los, "Should have LOS to adjacent tile")


# ===== LOS TILES TESTS =====

func test_get_los_tiles_horizontal() -> void:
	var tiles := _grid.get_line_of_sight(Vector2i(0, 5), Vector2i(5, 5))
	assert_eq(tiles.size(), 6, "Should return 6 tiles for horizontal distance 5")
	assert_eq(tiles[0], Vector2i(0, 5), "Should start at from position")
	assert_eq(tiles[-1], Vector2i(5, 5), "Should end at to position")


func test_get_los_tiles_vertical() -> void:
	var tiles := _grid.get_line_of_sight(Vector2i(5, 0), Vector2i(5, 5))
	assert_eq(tiles.size(), 6, "Should return 6 tiles for vertical distance 5")


func test_get_los_tiles_diagonal() -> void:
	var tiles := _grid.get_line_of_sight(Vector2i(0, 0), Vector2i(3, 3))
	assert_gt(tiles.size(), 0, "Should return tiles for diagonal path")
	assert_eq(tiles[0], Vector2i(0, 0), "Should start at from position")
	assert_eq(tiles[-1], Vector2i(3, 3), "Should end at to position")


# ===== COVER TESTS =====

func test_has_los_through_half_cover() -> void:
	_grid.set_tile_type(Vector2i(5, 5), Constants.TileType.COVER_HALF)
	var has_los := _grid.has_line_of_sight(Vector2i(0, 5), Vector2i(9, 5))
	assert_true(has_los, "Should have LOS through half cover")


func test_has_los_blocked_by_full_cover() -> void:
	_grid.set_tile_type(Vector2i(5, 5), Constants.TileType.COVER_FULL)
	var has_los := _grid.has_line_of_sight(Vector2i(0, 5), Vector2i(9, 5))
	assert_false(has_los, "Should not have LOS through full cover")


# ===== VISIBLE TILES TESTS =====

func test_get_visible_tiles_basic() -> void:
	var visible := _grid.get_visible_tiles(Vector2i(5, 5), 3)
	assert_gt(visible.size(), 0, "Should return visible tiles")
	assert_has(visible, Vector2i(5, 5), "Should include origin")


func test_get_visible_tiles_respects_walls() -> void:
	# 벽 뒤의 타일은 보이지 않아야 함
	_grid.set_tile_type(Vector2i(7, 5), Constants.TileType.WALL)

	var visible := _grid.get_visible_tiles(Vector2i(5, 5), 5)

	assert_has(visible, Vector2i(7, 5), "Should include the wall tile itself")
	assert_does_not_have(visible, Vector2i(8, 5), "Should not see behind wall")


func test_get_visible_tiles_range_limit() -> void:
	var visible := _grid.get_visible_tiles(Vector2i(5, 5), 2)

	# 범위 밖 타일은 포함되지 않아야 함
	assert_does_not_have(visible, Vector2i(0, 0), "Should not include tiles outside range")
	assert_does_not_have(visible, Vector2i(9, 9), "Should not include tiles outside range")


# ===== CONE TESTS =====

func test_get_tiles_in_cone_basic() -> void:
	var tiles := _grid._los_calculator.get_tiles_in_cone(
		Vector2i(5, 5),
		Vector2.RIGHT,
		90.0,
		3
	)
	assert_gt(tiles.size(), 0, "Should return tiles in cone")


func test_get_tiles_in_cone_direction() -> void:
	# 오른쪽 방향 원뿔
	var tiles_right := _grid._los_calculator.get_tiles_in_cone(
		Vector2i(5, 5),
		Vector2.RIGHT,
		45.0,
		3
	)

	# 왼쪽 방향 원뿔
	var tiles_left := _grid._los_calculator.get_tiles_in_cone(
		Vector2i(5, 5),
		Vector2.LEFT,
		45.0,
		3
	)

	# 서로 다른 결과여야 함 (대칭이므로 크기는 비슷할 수 있음)
	var has_different := false
	for tile in tiles_right:
		if not tiles_left.has(tile):
			has_different = true
			break

	assert_true(has_different or tiles_right.size() == 0, "Different directions should give different results")


func test_get_tiles_in_cone_narrow() -> void:
	var narrow := _grid._los_calculator.get_tiles_in_cone(
		Vector2i(5, 5),
		Vector2.RIGHT,
		10.0,
		5
	)

	var wide := _grid._los_calculator.get_tiles_in_cone(
		Vector2i(5, 5),
		Vector2.RIGHT,
		90.0,
		5
	)

	assert_lt(narrow.size(), wide.size(), "Narrow cone should have fewer tiles than wide cone")


# ===== CHECK COVER TESTS =====

func test_check_cover_no_cover() -> void:
	var result := _grid._los_calculator.check_cover(Vector2i(0, 5), Vector2i(9, 5))
	assert_false(result.has_cover, "Should have no cover on clear path")
	assert_eq(result.reduction, 0.0, "Should have 0 reduction")


func test_check_cover_with_half_cover() -> void:
	_grid.set_tile_type(Vector2i(5, 5), Constants.TileType.COVER_HALF)
	var result := _grid._los_calculator.check_cover(Vector2i(0, 5), Vector2i(9, 5))
	assert_true(result.has_cover, "Should detect half cover")
	assert_gt(result.reduction, 0.0, "Should have some reduction")


# ===== RAY TESTS =====

func test_get_tiles_along_ray() -> void:
	var tiles := _grid._los_calculator.get_tiles_along_ray(
		Vector2i(5, 5),
		Vector2.RIGHT,
		3
	)
	assert_gt(tiles.size(), 0, "Should return tiles along ray")


func test_get_tiles_along_ray_stops_at_wall() -> void:
	_grid.set_tile_type(Vector2i(7, 5), Constants.TileType.WALL)

	var tiles := _grid._los_calculator.get_tiles_along_ray(
		Vector2i(5, 5),
		Vector2.RIGHT,
		5
	)

	assert_has(tiles, Vector2i(7, 5), "Should include wall tile")
	assert_does_not_have(tiles, Vector2i(8, 5), "Should not include tile behind wall")


# ===== EDGE CASES =====

func test_los_to_grid_edge() -> void:
	var has_los := _grid.has_line_of_sight(Vector2i(5, 5), Vector2i(9, 5))
	assert_true(has_los, "Should have LOS to grid edge")


func test_visible_tiles_at_corner() -> void:
	var visible := _grid.get_visible_tiles(Vector2i(0, 0), 3)
	assert_gt(visible.size(), 0, "Should return some visible tiles at corner")
	# 코너에서는 모든 방향이 가능하지 않으므로 적은 수
	assert_lt(visible.size(), 30, "Corner should have limited visible tiles")


func test_los_zero_direction() -> void:
	var tiles := _grid._los_calculator.get_tiles_along_ray(
		Vector2i(5, 5),
		Vector2.ZERO,
		3
	)
	assert_eq(tiles.size(), 0, "Zero direction should return empty array")
