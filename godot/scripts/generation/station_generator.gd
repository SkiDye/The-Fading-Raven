## StationGenerator - 정거장 레이아웃 생성
## BSP 기반 방 분할 및 연결
extends RefCounted
class_name StationGenerator

# ===========================================
# 생성 설정
# ===========================================

const MIN_ROOM_SIZE := 4
const MAX_ROOM_SIZE := 8
const CORRIDOR_WIDTH := 2

# 방 타입
enum RoomType {
	NORMAL,
	FACILITY,
	AIRLOCK,
	ELEVATED,
}


# ===========================================
# BSP 노드
# ===========================================

class BSPNode:
	var rect: Rect2i
	var left: BSPNode = null
	var right: BSPNode = null
	var room: Rect2i = Rect2i()
	var room_type: int = RoomType.NORMAL

	func _init(r: Rect2i) -> void:
		rect = r

	func is_leaf() -> bool:
		return left == null and right == null


# ===========================================
# 정거장 생성
# ===========================================

## 정거장 레이아웃 생성
static func generate(width: int, height: int, turn: int, difficulty: int) -> TileGrid:
	var grid := TileGrid.new(width, height)

	# BSP 트리 생성
	var root := BSPNode.new(Rect2i(1, 1, width - 2, height - 2))
	_split_node(root, 0)

	# 방 생성
	var rooms := _create_rooms(root)

	# 방을 그리드에 배치
	for room_data in rooms:
		_place_room(grid, room_data)

	# 복도 연결
	_connect_rooms(grid, root)

	# 시설 배치
	_place_facilities(grid, rooms, turn)

	# 에어락 배치
	_place_airlocks(grid, rooms, turn, difficulty)

	# 높은 지형 추가
	_add_elevated_terrain(grid, rooms)

	# 엄폐물 추가
	_add_cover(grid)

	return grid


# ===========================================
# BSP 분할
# ===========================================

static func _split_node(node: BSPNode, depth: int) -> void:
	if depth > 4:
		return

	var rect := node.rect

	# 분할 가능 여부 체크
	if rect.size.x < MIN_ROOM_SIZE * 2 + 2 and rect.size.y < MIN_ROOM_SIZE * 2 + 2:
		return

	# 분할 방향 결정
	var split_horizontal: bool

	if rect.size.x < MIN_ROOM_SIZE * 2 + 2:
		split_horizontal = true
	elif rect.size.y < MIN_ROOM_SIZE * 2 + 2:
		split_horizontal = false
	else:
		# 비율에 따라 결정
		var ratio := float(rect.size.x) / float(rect.size.y)
		if ratio > 1.5:
			split_horizontal = false
		elif ratio < 0.67:
			split_horizontal = true
		else:
			split_horizontal = RngManager.chance(RngManager.STREAM_STATION_LAYOUT, 0.5)

	# 분할 위치
	var min_split: int
	var max_split: int

	if split_horizontal:
		min_split = MIN_ROOM_SIZE + 1
		max_split = rect.size.y - MIN_ROOM_SIZE - 1

		if min_split >= max_split:
			return

		var split := RngManager.range_int(RngManager.STREAM_STATION_LAYOUT, min_split, max_split)

		node.left = BSPNode.new(Rect2i(rect.position.x, rect.position.y, rect.size.x, split))
		node.right = BSPNode.new(Rect2i(rect.position.x, rect.position.y + split, rect.size.x, rect.size.y - split))
	else:
		min_split = MIN_ROOM_SIZE + 1
		max_split = rect.size.x - MIN_ROOM_SIZE - 1

		if min_split >= max_split:
			return

		var split := RngManager.range_int(RngManager.STREAM_STATION_LAYOUT, min_split, max_split)

		node.left = BSPNode.new(Rect2i(rect.position.x, rect.position.y, split, rect.size.y))
		node.right = BSPNode.new(Rect2i(rect.position.x + split, rect.position.y, rect.size.x - split, rect.size.y))

	# 재귀 분할
	_split_node(node.left, depth + 1)
	_split_node(node.right, depth + 1)


# ===========================================
# 방 생성
# ===========================================

static func _create_rooms(node: BSPNode) -> Array[Dictionary]:
	var rooms: Array[Dictionary] = []
	_create_rooms_recursive(node, rooms)
	return rooms


static func _create_rooms_recursive(node: BSPNode, rooms: Array[Dictionary]) -> void:
	if node.is_leaf():
		# 리프 노드에 방 생성
		var rect := node.rect

		var room_w := RngManager.range_int(
			RngManager.STREAM_STATION_LAYOUT,
			MIN_ROOM_SIZE,
			mini(MAX_ROOM_SIZE, rect.size.x - 2)
		)
		var room_h := RngManager.range_int(
			RngManager.STREAM_STATION_LAYOUT,
			MIN_ROOM_SIZE,
			mini(MAX_ROOM_SIZE, rect.size.y - 2)
		)

		var room_x := rect.position.x + RngManager.range_int(
			RngManager.STREAM_STATION_LAYOUT,
			1,
			rect.size.x - room_w - 1
		)
		var room_y := rect.position.y + RngManager.range_int(
			RngManager.STREAM_STATION_LAYOUT,
			1,
			rect.size.y - room_h - 1
		)

		node.room = Rect2i(room_x, room_y, room_w, room_h)

		rooms.append({
			"rect": node.room,
			"type": RoomType.NORMAL,
			"center": Vector2i(room_x + room_w / 2, room_y + room_h / 2),
		})
	else:
		if node.left:
			_create_rooms_recursive(node.left, rooms)
		if node.right:
			_create_rooms_recursive(node.right, rooms)


static func _place_room(grid: TileGrid, room_data: Dictionary) -> void:
	var rect: Rect2i = room_data["rect"]

	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			grid.set_tile(x, y, TileGrid.TileType.FLOOR)


# ===========================================
# 복도 연결
# ===========================================

static func _connect_rooms(grid: TileGrid, node: BSPNode) -> void:
	if node.is_leaf():
		return

	if node.left and node.right:
		var left_center := _get_node_center(node.left)
		var right_center := _get_node_center(node.right)

		_create_corridor(grid, left_center, right_center)

	if node.left:
		_connect_rooms(grid, node.left)
	if node.right:
		_connect_rooms(grid, node.right)


static func _get_node_center(node: BSPNode) -> Vector2i:
	if node.is_leaf() and node.room.size.x > 0:
		return Vector2i(
			node.room.position.x + node.room.size.x / 2,
			node.room.position.y + node.room.size.y / 2
		)

	var rect := node.rect
	return Vector2i(
		rect.position.x + rect.size.x / 2,
		rect.position.y + rect.size.y / 2
	)


static func _create_corridor(grid: TileGrid, from: Vector2i, to: Vector2i) -> void:
	var x := from.x
	var y := from.y

	# L자 복도
	while x != to.x:
		for w in range(CORRIDOR_WIDTH):
			if grid.is_valid(x, y + w):
				grid.set_tile(x, y + w, TileGrid.TileType.FLOOR)
		x += 1 if to.x > x else -1

	while y != to.y:
		for w in range(CORRIDOR_WIDTH):
			if grid.is_valid(x + w, y):
				grid.set_tile(x + w, y, TileGrid.TileType.FLOOR)
		y += 1 if to.y > y else -1


# ===========================================
# 시설 배치
# ===========================================

static func _place_facilities(grid: TileGrid, rooms: Array[Dictionary], turn: int) -> void:
	# 시설 수 결정 (턴에 따라 증가)
	var facility_count := mini(2 + turn / 2, 4)

	# 가장 큰 방들에 시설 배치
	var sorted_rooms := rooms.duplicate()
	sorted_rooms.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var area_a: int = a["rect"].size.x * a["rect"].size.y
		var area_b: int = b["rect"].size.x * b["rect"].size.y
		return area_a > area_b
	)

	for i in range(mini(facility_count, sorted_rooms.size())):
		var room: Dictionary = sorted_rooms[i]
		var center: Vector2i = room["center"]

		grid.set_tile_v(center, TileGrid.TileType.FACILITY)
		room["type"] = RoomType.FACILITY


# ===========================================
# 에어락 배치
# ===========================================

static func _place_airlocks(grid: TileGrid, rooms: Array[Dictionary], turn: int, difficulty: int) -> void:
	# 에어락 수 (난이도와 턴에 따라)
	var base_airlocks := 2
	var turn_bonus := turn / 3

	var diff_config: Dictionary = Balance.get_difficulty_config(difficulty)
	var diff_bonus: int = diff_config.get("extra_airlocks", 0)

	var airlock_count := mini(base_airlocks + turn_bonus + diff_bonus, 6)

	# 가장자리 방에 에어락 배치
	var edge_rooms := rooms.filter(func(r: Dictionary) -> bool:
		var rect: Rect2i = r["rect"]
		return rect.position.x <= 3 or rect.position.y <= 3 or \
			   rect.position.x + rect.size.x >= grid.width - 3 or \
			   rect.position.y + rect.size.y >= grid.height - 3
	)

	if edge_rooms.is_empty():
		edge_rooms = rooms

	var shuffled := RngManager.shuffle(RngManager.STREAM_STATION_LAYOUT, edge_rooms)

	for i in range(mini(airlock_count, shuffled.size())):
		var room: Dictionary = shuffled[i]
		var rect: Rect2i = room["rect"]

		# 방 가장자리에 에어락 배치
		var airlock_pos := _find_airlock_position(grid, rect)
		if airlock_pos != Vector2i(-1, -1):
			grid.set_tile_v(airlock_pos, TileGrid.TileType.AIRLOCK)


static func _find_airlock_position(grid: TileGrid, room_rect: Rect2i) -> Vector2i:
	var candidates: Array[Vector2i] = []

	# 방 가장자리 타일
	for x in range(room_rect.position.x, room_rect.position.x + room_rect.size.x):
		candidates.append(Vector2i(x, room_rect.position.y))
		candidates.append(Vector2i(x, room_rect.position.y + room_rect.size.y - 1))

	for y in range(room_rect.position.y + 1, room_rect.position.y + room_rect.size.y - 1):
		candidates.append(Vector2i(room_rect.position.x, y))
		candidates.append(Vector2i(room_rect.position.x + room_rect.size.x - 1, y))

	# 맵 가장자리에 가까운 위치 우선
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var dist_a := mini(a.x, mini(a.y, mini(grid.width - a.x, grid.height - a.y)))
		var dist_b := mini(b.x, mini(b.y, mini(grid.width - b.x, grid.height - b.y)))
		return dist_a < dist_b
	)

	if candidates.is_empty():
		return Vector2i(-1, -1)

	return candidates[0]


# ===========================================
# 높은 지형
# ===========================================

static func _add_elevated_terrain(grid: TileGrid, rooms: Array[Dictionary]) -> void:
	# 일부 방에 높은 지형 추가
	for room in rooms:
		if room["type"] != RoomType.NORMAL:
			continue

		if not RngManager.chance(RngManager.STREAM_STATION_LAYOUT, 0.3):
			continue

		var rect: Rect2i = room["rect"]

		# 방의 일부를 높은 지형으로
		var elevated_size := Vector2i(
			RngManager.range_int(RngManager.STREAM_STATION_LAYOUT, 2, mini(3, rect.size.x - 1)),
			RngManager.range_int(RngManager.STREAM_STATION_LAYOUT, 2, mini(3, rect.size.y - 1))
		)

		var elevated_pos := Vector2i(
			rect.position.x + RngManager.range_int(RngManager.STREAM_STATION_LAYOUT, 0, rect.size.x - elevated_size.x),
			rect.position.y + RngManager.range_int(RngManager.STREAM_STATION_LAYOUT, 0, rect.size.y - elevated_size.y)
		)

		for y in range(elevated_pos.y, elevated_pos.y + elevated_size.y):
			for x in range(elevated_pos.x, elevated_pos.x + elevated_size.x):
				if grid.get_tile(x, y) == TileGrid.TileType.FLOOR:
					grid.set_tile(x, y, TileGrid.TileType.ELEVATED)


# ===========================================
# 엄폐물
# ===========================================

static func _add_cover(grid: TileGrid) -> void:
	# 복도와 방 경계에 엄폐물 추가
	for y in range(1, grid.height - 1):
		for x in range(1, grid.width - 1):
			if grid.get_tile(x, y) != TileGrid.TileType.FLOOR:
				continue

			# 인접 타일 중 VOID가 있으면 엄폐물 후보
			var adjacent_void := false
			for neighbor in grid.get_neighbors(Vector2i(x, y)):
				if grid.get_tile_v(neighbor) == TileGrid.TileType.VOID:
					adjacent_void = true
					break

			if adjacent_void and RngManager.chance(RngManager.STREAM_STATION_LAYOUT, 0.1):
				grid.set_tile(x, y, TileGrid.TileType.COVER)


# ===========================================
# 검증
# ===========================================

## 모든 시설에 도달 가능한지 확인
static func validate_layout(grid: TileGrid) -> bool:
	if grid.facilities.is_empty() or grid.airlocks.is_empty():
		return false

	var pathfinder := Pathfinder.new(grid)

	# 모든 에어락에서 모든 시설로 경로 존재 확인
	for airlock in grid.airlocks:
		for facility in grid.facilities:
			var facility_pos: Vector2i = facility["position"]
			if not pathfinder.can_reach(airlock, facility_pos):
				return false

	return true
