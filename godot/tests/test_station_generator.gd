extends GutTest

## StationGenerator 유닛 테스트


var _generator: StationGenerator


func before_each() -> void:
	_generator = StationGenerator.new()


func after_each() -> void:
	_generator = null


# ===== SEED REPRODUCIBILITY =====

func test_same_seed_produces_same_result() -> void:
	var seed := 12345
	var difficulty_score := 2.5

	var station1 := _generator.generate(seed, difficulty_score)
	var station2 := _generator.generate(seed, difficulty_score)

	assert_eq(station1.width, station2.width, "Same seed should produce same width")
	assert_eq(station1.height, station2.height, "Same seed should produce same height")
	assert_eq(station1.facilities.size(), station2.facilities.size(), "Same seed should produce same facility count")
	assert_eq(station1.entry_points.size(), station2.entry_points.size(), "Same seed should produce same entry point count")

	# 타일 비교
	for y in range(station1.height):
		for x in range(station1.width):
			assert_eq(station1.tiles[y][x], station2.tiles[y][x],
				"Tile at (%d, %d) should match" % [x, y])


func test_different_seeds_produce_different_results() -> void:
	var station1 := _generator.generate(11111, 2.5)
	var station2 := _generator.generate(22222, 2.5)

	# 완전히 같을 확률은 매우 낮음
	var differences := 0
	var min_w := mini(station1.width, station2.width)
	var min_h := mini(station1.height, station2.height)

	for y in range(min_h):
		for x in range(min_w):
			if station1.tiles[y][x] != station2.tiles[y][x]:
				differences += 1

	assert_gt(differences, 0, "Different seeds should produce different layouts")


# ===== SIZE SCALING =====

func test_size_increases_with_difficulty() -> void:
	var easy := _generator.generate(12345, 1.5)
	var hard := _generator.generate(12345, 5.0)

	assert_lt(easy.width, hard.width, "Higher difficulty should produce larger maps")
	assert_lt(easy.height, hard.height, "Higher difficulty should produce larger maps")


func test_facility_count_increases_with_difficulty() -> void:
	var easy := _generator.generate(12345, 1.5)
	var hard := _generator.generate(12345, 5.0)

	assert_lt(easy.facilities.size(), hard.facilities.size(),
		"Higher difficulty should have more facilities")


# ===== LAYOUT VALIDITY =====

func test_has_floor_tiles() -> void:
	var station := _generator.generate(12345, 2.5)

	var floor_count := 0
	for y in range(station.height):
		for x in range(station.width):
			if station.tiles[y][x] == Constants.TileType.FLOOR:
				floor_count += 1

	assert_gt(floor_count, 0, "Station should have floor tiles")


func test_has_entry_points() -> void:
	var station := _generator.generate(12345, 2.5)

	assert_gt(station.entry_points.size(), 0, "Station should have entry points")
	assert_lte(station.entry_points.size(), 4, "Station should have at most 4 entry points")


func test_entry_points_are_airlocks() -> void:
	var station := _generator.generate(12345, 2.5)

	for entry in station.entry_points:
		var tile := station.get_tile(entry)
		assert_eq(tile, Constants.TileType.AIRLOCK,
			"Entry point at %s should be AIRLOCK" % str(entry))


func test_entry_points_on_edges() -> void:
	var station := _generator.generate(12345, 2.5)

	for entry in station.entry_points:
		var on_edge := (
			entry.x == 0 or
			entry.x == station.width - 1 or
			entry.y == 0 or
			entry.y == station.height - 1
		)
		assert_true(on_edge, "Entry point %s should be on edge" % str(entry))


func test_has_facilities() -> void:
	var station := _generator.generate(12345, 2.5)

	assert_gt(station.facilities.size(), 0, "Station should have facilities")


func test_facilities_on_floor() -> void:
	var station := _generator.generate(12345, 2.5)

	for facility in station.facilities:
		var tile := station.get_tile(facility.position)
		assert_eq(tile, Constants.TileType.FACILITY,
			"Facility at %s should be on FACILITY tile" % str(facility.position))


func test_has_deploy_zones() -> void:
	var station := _generator.generate(12345, 2.5)

	assert_gt(station.deploy_zones.size(), 0, "Station should have deploy zones")


func test_deploy_zones_are_walkable() -> void:
	var station := _generator.generate(12345, 2.5)

	for zone in station.deploy_zones:
		assert_true(station.is_walkable(zone),
			"Deploy zone at %s should be walkable" % str(zone))


# ===== CONNECTIVITY =====

func test_facilities_are_reachable_from_entry() -> void:
	var station := _generator.generate(12345, 2.5)

	if station.entry_points.is_empty() or station.facilities.is_empty():
		pass_test("No entry points or facilities to test")
		return

	var start := station.entry_points[0]
	var reachable := _flood_fill(station, start)

	for facility in station.facilities:
		# 시설 주변 타일이 도달 가능한지 확인
		var facility_reachable := false
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var check := facility.position + Vector2i(dx, dy)
				if reachable.has(check):
					facility_reachable = true
					break
			if facility_reachable:
				break

		assert_true(facility_reachable,
			"Facility at %s should be reachable from entry" % str(facility.position))


func _flood_fill(station: StationGenerator.StationData, start: Vector2i) -> Dictionary:
	## BFS로 도달 가능한 모든 타일 반환
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [start]

	while not queue.is_empty():
		var current := queue.pop_front()

		if visited.has(current):
			continue
		if not station.is_valid_position(current):
			continue
		if not station.is_walkable(current):
			continue

		visited[current] = true

		# 4방향 탐색
		queue.append(current + Vector2i(1, 0))
		queue.append(current + Vector2i(-1, 0))
		queue.append(current + Vector2i(0, 1))
		queue.append(current + Vector2i(0, -1))

	return visited


# ===== HEIGHT MAP =====

func test_height_map_exists() -> void:
	var station := _generator.generate(12345, 2.5)

	assert_eq(station.height_map.size(), station.height, "Height map should match station height")
	if not station.height_map.is_empty():
		assert_eq(station.height_map[0].size(), station.width, "Height map should match station width")


func test_elevated_tiles_have_positive_height() -> void:
	var station := _generator.generate(12345, 2.5)

	for y in range(station.height):
		for x in range(station.width):
			if station.tiles[y][x] == Constants.TileType.ELEVATED:
				assert_eq(station.height_map[y][x], 1,
					"Elevated tile at (%d, %d) should have height 1" % [x, y])


func test_lowered_tiles_have_negative_height() -> void:
	var station := _generator.generate(12345, 2.5)

	for y in range(station.height):
		for x in range(station.width):
			if station.tiles[y][x] == Constants.TileType.LOWERED:
				assert_eq(station.height_map[y][x], -1,
					"Lowered tile at (%d, %d) should have height -1" % [x, y])


# ===== API FUNCTIONS =====

func test_get_tile() -> void:
	var station := _generator.generate(12345, 2.5)

	# 유효한 위치
	var tile := station.get_tile(Vector2i(5, 5))
	assert_true(tile in [
		Constants.TileType.VOID,
		Constants.TileType.FLOOR,
		Constants.TileType.WALL,
		Constants.TileType.AIRLOCK,
		Constants.TileType.ELEVATED,
		Constants.TileType.LOWERED,
		Constants.TileType.FACILITY,
		Constants.TileType.COVER_HALF,
		Constants.TileType.COVER_FULL
	], "get_tile should return valid TileType")

	# 유효하지 않은 위치
	var void_tile := station.get_tile(Vector2i(-1, -1))
	assert_eq(void_tile, Constants.TileType.VOID, "Invalid position should return VOID")


func test_is_valid_position() -> void:
	var station := _generator.generate(12345, 2.5)

	assert_true(station.is_valid_position(Vector2i(0, 0)), "Origin should be valid")
	assert_true(station.is_valid_position(Vector2i(station.width - 1, station.height - 1)), "Max corner should be valid")
	assert_false(station.is_valid_position(Vector2i(-1, 0)), "Negative x should be invalid")
	assert_false(station.is_valid_position(Vector2i(0, -1)), "Negative y should be invalid")
	assert_false(station.is_valid_position(Vector2i(station.width, 0)), "Beyond width should be invalid")


func test_is_walkable() -> void:
	var station := _generator.generate(12345, 2.5)

	# FLOOR는 이동 가능
	for y in range(station.height):
		for x in range(station.width):
			if station.tiles[y][x] == Constants.TileType.FLOOR:
				assert_true(station.is_walkable(Vector2i(x, y)),
					"FLOOR tile should be walkable")
				break

	# WALL은 이동 불가
	for y in range(station.height):
		for x in range(station.width):
			if station.tiles[y][x] == Constants.TileType.WALL:
				assert_false(station.is_walkable(Vector2i(x, y)),
					"WALL tile should not be walkable")
				break


func test_get_facility_at() -> void:
	var station := _generator.generate(12345, 2.5)

	if station.facilities.is_empty():
		pass_test("No facilities to test")
		return

	var facility := station.facilities[0]
	var found := station.get_facility_at(facility.position)

	assert_not_null(found, "Should find facility at its position")
	assert_eq(found.facility_id, facility.facility_id, "Found facility should match")

	# 빈 위치
	var empty := station.get_facility_at(Vector2i(-100, -100))
	assert_null(empty, "Should return null for position without facility")


func test_to_ascii() -> void:
	var station := _generator.generate(12345, 2.5)

	var ascii := station.to_ascii()

	assert_gt(ascii.length(), 0, "ASCII output should not be empty")
	assert_true(ascii.contains("\n"), "ASCII output should have newlines")

	# 줄 수 확인
	var lines := ascii.split("\n")
	assert_eq(lines.size() - 1, station.height, "ASCII should have correct number of lines")
