extends GutTest

## TileGrid 유닛 테스트


var _grid: TileGrid


func before_each() -> void:
	_grid = TileGrid.new()
	_grid.initialize(10, 10)
	add_child(_grid)


func after_each() -> void:
	_grid.queue_free()


# ===== INITIALIZATION TESTS =====

func test_initialize_creates_correct_size() -> void:
	assert_eq(_grid.width, 10, "Width should be 10")
	assert_eq(_grid.height, 10, "Height should be 10")
	assert_eq(_grid.tiles.size(), 10, "Should have 10 rows")
	assert_eq(_grid.tiles[0].size(), 10, "Each row should have 10 tiles")


func test_initialize_creates_floor_tiles() -> void:
	var tile := _grid.get_tile(Vector2i(5, 5))
	assert_not_null(tile, "Tile should exist")
	assert_eq(tile.type, Constants.TileType.FLOOR, "Default tile should be FLOOR")


# ===== POSITION VALIDATION TESTS =====

func test_is_valid_position_inside_grid() -> void:
	assert_true(_grid.is_valid_position(Vector2i(0, 0)), "Origin should be valid")
	assert_true(_grid.is_valid_position(Vector2i(5, 5)), "Center should be valid")
	assert_true(_grid.is_valid_position(Vector2i(9, 9)), "Max corner should be valid")


func test_is_valid_position_outside_grid() -> void:
	assert_false(_grid.is_valid_position(Vector2i(-1, 0)), "Negative X should be invalid")
	assert_false(_grid.is_valid_position(Vector2i(0, -1)), "Negative Y should be invalid")
	assert_false(_grid.is_valid_position(Vector2i(10, 0)), "X >= width should be invalid")
	assert_false(_grid.is_valid_position(Vector2i(0, 10)), "Y >= height should be invalid")


# ===== WALKABILITY TESTS =====

func test_is_walkable_floor() -> void:
	_grid.set_tile_type(Vector2i(5, 5), Constants.TileType.FLOOR)
	assert_true(_grid.is_walkable(Vector2i(5, 5)), "Floor should be walkable")


func test_is_walkable_wall() -> void:
	_grid.set_tile_type(Vector2i(5, 5), Constants.TileType.WALL)
	assert_false(_grid.is_walkable(Vector2i(5, 5)), "Wall should not be walkable")


func test_is_walkable_void() -> void:
	_grid.set_tile_type(Vector2i(5, 5), Constants.TileType.VOID)
	assert_false(_grid.is_walkable(Vector2i(5, 5)), "Void should not be walkable")


func test_is_walkable_with_occupant() -> void:
	var mock_node := Node.new()
	add_child(mock_node)
	_grid.set_occupant(Vector2i(5, 5), mock_node)
	assert_false(_grid.is_walkable(Vector2i(5, 5)), "Occupied tile should not be walkable")
	mock_node.queue_free()


func test_is_walkable_ignore_occupant() -> void:
	var mock_node := Node.new()
	add_child(mock_node)
	_grid.set_occupant(Vector2i(5, 5), mock_node)
	assert_true(_grid.is_walkable_ignore_occupant(Vector2i(5, 5)), "Should be walkable when ignoring occupant")
	mock_node.queue_free()


# ===== TILE TYPE TESTS =====

func test_set_tile_type() -> void:
	_grid.set_tile_type(Vector2i(3, 3), Constants.TileType.WALL)
	var tile := _grid.get_tile(Vector2i(3, 3))
	assert_eq(tile.type, Constants.TileType.WALL, "Tile type should be WALL")


func test_set_tile_type_emits_signal() -> void:
	watch_signals(_grid)
	_grid.set_tile_type(Vector2i(3, 3), Constants.TileType.WALL)
	assert_signal_emitted(_grid, "tile_changed", "Should emit tile_changed signal")


# ===== NEIGHBOR TESTS =====

func test_get_neighbors_4_direction() -> void:
	var neighbors := _grid.get_neighbors(Vector2i(5, 5), false)
	assert_eq(neighbors.size(), 4, "Should have 4 neighbors")
	assert_has(neighbors, Vector2i(5, 4), "Should include top neighbor")
	assert_has(neighbors, Vector2i(6, 5), "Should include right neighbor")
	assert_has(neighbors, Vector2i(5, 6), "Should include bottom neighbor")
	assert_has(neighbors, Vector2i(4, 5), "Should include left neighbor")


func test_get_neighbors_8_direction() -> void:
	var neighbors := _grid.get_neighbors(Vector2i(5, 5), true)
	assert_eq(neighbors.size(), 8, "Should have 8 neighbors with diagonal")


func test_get_neighbors_corner() -> void:
	var neighbors := _grid.get_neighbors(Vector2i(0, 0), false)
	assert_eq(neighbors.size(), 2, "Corner should have 2 neighbors")


# ===== OCCUPANCY TESTS =====

func test_set_and_get_occupant() -> void:
	var mock_node := Node.new()
	add_child(mock_node)
	_grid.set_occupant(Vector2i(5, 5), mock_node)
	assert_eq(_grid.get_occupant(Vector2i(5, 5)), mock_node, "Should return the occupant")
	mock_node.queue_free()


func test_clear_occupant() -> void:
	var mock_node := Node.new()
	add_child(mock_node)
	_grid.set_occupant(Vector2i(5, 5), mock_node)
	_grid.clear_occupant(Vector2i(5, 5))
	assert_null(_grid.get_occupant(Vector2i(5, 5)), "Occupant should be null after clearing")
	mock_node.queue_free()


func test_set_occupant_emits_signal() -> void:
	watch_signals(_grid)
	var mock_node := Node.new()
	add_child(mock_node)
	_grid.set_occupant(Vector2i(5, 5), mock_node)
	assert_signal_emitted(_grid, "occupant_changed", "Should emit occupant_changed signal")
	mock_node.queue_free()


# ===== COORDINATE CONVERSION TESTS =====

func test_world_to_tile() -> void:
	var tile_pos := _grid.world_to_tile(Vector2(48.0, 80.0))
	assert_eq(tile_pos, Vector2i(1, 2), "Should convert world to tile correctly")


func test_tile_to_world() -> void:
	var world_pos := _grid.tile_to_world(Vector2i(2, 3))
	# 타일 중심: (2 * 32 + 16, 3 * 32 + 16) = (80, 112)
	assert_eq(world_pos, Vector2(80.0, 112.0), "Should convert tile to world center")


func test_tile_to_world_top_left() -> void:
	var world_pos := _grid.tile_to_world_top_left(Vector2i(2, 3))
	assert_eq(world_pos, Vector2(64.0, 96.0), "Should convert tile to world top-left")


# ===== RANGE QUERY TESTS =====

func test_get_tiles_in_range_circle() -> void:
	var tiles := _grid.get_tiles_in_range(Vector2i(5, 5), 2, "circle")
	assert_gt(tiles.size(), 0, "Should return some tiles")
	assert_has(tiles, Vector2i(5, 5), "Should include center")


func test_get_tiles_in_range_square() -> void:
	var tiles := _grid.get_tiles_in_range(Vector2i(5, 5), 1, "square")
	assert_eq(tiles.size(), 9, "Square range 1 should have 9 tiles")


func test_get_tiles_in_range_diamond() -> void:
	var tiles := _grid.get_tiles_in_range(Vector2i(5, 5), 1, "diamond")
	assert_eq(tiles.size(), 5, "Diamond range 1 should have 5 tiles")


# ===== ELEVATION TESTS =====

func test_get_elevation() -> void:
	var tile := _grid.get_tile(Vector2i(5, 5))
	tile.elevation = 1
	assert_eq(_grid.get_elevation(Vector2i(5, 5)), 1, "Should return correct elevation")


func test_get_elevation_bonus_high_ground() -> void:
	var tile1 := _grid.get_tile(Vector2i(4, 5))
	var tile2 := _grid.get_tile(Vector2i(5, 5))
	tile1.elevation = 1
	tile2.elevation = 0
	var bonus := _grid.get_elevation_bonus(Vector2i(4, 5), Vector2i(5, 5))
	assert_gt(bonus, 0.0, "Should have bonus when attacking from high ground")


func test_get_elevation_bonus_no_bonus() -> void:
	var tile1 := _grid.get_tile(Vector2i(4, 5))
	var tile2 := _grid.get_tile(Vector2i(5, 5))
	tile1.elevation = 0
	tile2.elevation = 1
	var bonus := _grid.get_elevation_bonus(Vector2i(4, 5), Vector2i(5, 5))
	assert_eq(bonus, 0.0, "Should have no bonus when attacking from low ground")


# ===== ENTRY POINT TESTS =====

func test_get_entry_points() -> void:
	var tile1 := _grid.get_tile(Vector2i(0, 0))
	var tile2 := _grid.get_tile(Vector2i(9, 9))
	tile1.is_entry_point = true
	tile2.is_entry_point = true

	var entry_points := _grid.get_entry_points()
	assert_eq(entry_points.size(), 2, "Should have 2 entry points")
	assert_has(entry_points, Vector2i(0, 0), "Should include first entry point")
	assert_has(entry_points, Vector2i(9, 9), "Should include second entry point")
