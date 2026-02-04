class_name StationGenerator
extends RefCounted

## BSP 기반 스테이션 레이아웃 생성기
## 동일 시드 -> 동일 레이아웃 생성 보장
## [br][br]
## 사용 예:
## [codeblock]
## var generator = StationGenerator.new()
## var station = generator.generate(12345, 2.5)  # 난이도 점수 2.5
## [/codeblock]

const UtilsClass = preload("res://src/utils/Utils.gd")
const SeededRNGClass = preload("res://src/systems/campaign/SeededRNG.gd")


# ===== INNER CLASSES =====

class FacilityPlacement:
	## 시설 배치 정보
	var facility_id: String
	var position: Vector2i
	var hp: int
	var max_hp: int

	func _init(id: String = "", pos: Vector2i = Vector2i.ZERO) -> void:
		facility_id = id
		position = pos
		hp = 100
		max_hp = 100


class StationLayout:
	## 스테이션 레이아웃 데이터
	var seed: int
	var width: int
	var height: int
	var tiles: Array = []  # 2D array of TileType
	var facilities: Array[FacilityPlacement] = []
	var entry_points: Array[Vector2i] = []
	var deploy_zones: Array[Vector2i] = []  # 크루 배치 가능 영역
	var height_map: Array = []  # 2D array of elevation (-1, 0, 1)

	func get_tile(pos: Vector2i) -> Constants.TileType:
		if not is_valid_position(pos):
			return Constants.TileType.VOID
		return tiles[pos.y][pos.x]

	func set_tile(pos: Vector2i, tile_type: Constants.TileType) -> void:
		if is_valid_position(pos):
			tiles[pos.y][pos.x] = tile_type

	func is_valid_position(pos: Vector2i) -> bool:
		return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height

	func is_walkable(pos: Vector2i) -> bool:
		var tile := get_tile(pos)
		return tile in [
			Constants.TileType.FLOOR,
			Constants.TileType.AIRLOCK,
			Constants.TileType.ELEVATED,
			Constants.TileType.LOWERED,
			Constants.TileType.FACILITY,
			Constants.TileType.COVER_HALF
		]

	func get_elevation(pos: Vector2i) -> int:
		if not is_valid_position(pos):
			return 0
		return height_map[pos.y][pos.x]

	func get_facility_at(pos: Vector2i) -> FacilityPlacement:
		for facility in facilities:
			if facility.position == pos:
				return facility
		return null

	func to_ascii() -> String:
		## 디버그용 ASCII 출력
		var result := ""
		var symbols := {
			Constants.TileType.VOID: " ",
			Constants.TileType.FLOOR: ".",
			Constants.TileType.WALL: "#",
			Constants.TileType.AIRLOCK: "A",
			Constants.TileType.ELEVATED: "^",
			Constants.TileType.LOWERED: "v",
			Constants.TileType.FACILITY: "F",
			Constants.TileType.COVER_HALF: "c",
			Constants.TileType.COVER_FULL: "C"
		}

		for y in range(height):
			for x in range(width):
				var tile: Constants.TileType = tiles[y][x]
				result += symbols.get(tile, "?")
			result += "\n"

		return result


class BSPNode:
	## BSP 트리 노드
	var x: int
	var y: int
	var bsp_width: int
	var bsp_height: int
	var left: BSPNode
	var right: BSPNode
	var room: Rect2i

	func _init(px: int = 0, py: int = 0, pw: int = 0, ph: int = 0) -> void:
		x = px
		y = py
		bsp_width = pw
		bsp_height = ph


# ===== GENERATOR =====

var _rng  # SeededRNG - type hint removed


func generate(seed: int, difficulty_score: float) -> StationLayout:
	## 스테이션 레이아웃 생성
	_rng = SeededRNGClass.new(seed)

	var data := StationLayout.new()
	data.seed = seed

	# 1. 크기 결정
	var size_config := _get_size_config(difficulty_score)
	data.width = size_config.width
	data.height = size_config.height

	# 2. 타일/고도 맵 초기화
	data.tiles = _create_empty_grid(data.width, data.height, Constants.TileType.VOID)
	data.height_map = _create_empty_grid(data.width, data.height, 0)

	# 3. BSP로 방 생성
	var rooms := _generate_bsp_rooms(data.width, data.height)

	# 4. 방을 타일에 적용
	_apply_rooms_to_grid(data, rooms)

	# 5. 복도 연결
	_connect_rooms(data, rooms)

	# 6. 벽 생성
	_generate_walls(data)

	# 7. 시설 배치
	_place_facilities(data, rooms, size_config.facility_count)

	# 8. 진입점 배치
	_place_entry_points(data)

	# 9. 배치 영역 설정
	_setup_deploy_zones(data)

	# 10. 고도 맵 생성
	_generate_height_map(data)

	# 11. 엄폐물 배치
	_place_cover(data)

	return data


func _get_size_config(difficulty_score: float) -> Dictionary:
	## 난이도 점수에 따른 맵 크기 설정
	if difficulty_score < 2.0:
		return {"width": 9, "height": 9, "facility_count": 3}
	elif difficulty_score < 3.0:
		return {"width": 11, "height": 11, "facility_count": 4}
	elif difficulty_score < 4.5:
		return {"width": 13, "height": 13, "facility_count": 5}
	else:
		return {"width": 15, "height": 15, "facility_count": 6}


func _create_empty_grid(w: int, h: int, default_value: Variant) -> Array:
	var grid: Array = []
	for y in range(h):
		var row: Array = []
		for x in range(w):
			row.append(default_value)
		grid.append(row)
	return grid


# ===== BSP ROOM GENERATION =====

func _generate_bsp_rooms(w: int, h: int) -> Array[Rect2i]:
	var root := BSPNode.new(1, 1, w - 2, h - 2)
	_split_node(root, 4)

	var rooms: Array[Rect2i] = []
	_collect_rooms(root, rooms)
	return rooms


func _split_node(node: BSPNode, min_size: int) -> void:
	# 더 이상 분할 불가능하면 방 생성
	if node.bsp_width < min_size * 2 and node.bsp_height < min_size * 2:
		var room_w := _rng.range_int(min_size, maxi(min_size, node.bsp_width - 1))
		var room_h := _rng.range_int(min_size, maxi(min_size, node.bsp_height - 1))
		var room_x := node.x + _rng.range_int(0, maxi(0, node.bsp_width - room_w - 1))
		var room_y := node.y + _rng.range_int(0, maxi(0, node.bsp_height - room_h - 1))
		node.room = Rect2i(room_x, room_y, room_w, room_h)
		return

	# 분할 방향 결정
	var split_h := node.bsp_width > node.bsp_height * 1.25
	if node.bsp_width >= node.bsp_height and not split_h:
		split_h = _rng.chance(0.5)

	if split_h and node.bsp_width >= min_size * 2:
		# 수평 분할
		var split := _rng.range_int(int(node.bsp_width * 0.4), int(node.bsp_width * 0.6))
		node.left = BSPNode.new(node.x, node.y, split, node.bsp_height)
		node.right = BSPNode.new(node.x + split, node.y, node.bsp_width - split, node.bsp_height)
	elif node.bsp_height >= min_size * 2:
		# 수직 분할
		var split := _rng.range_int(int(node.bsp_height * 0.4), int(node.bsp_height * 0.6))
		node.left = BSPNode.new(node.x, node.y, node.bsp_width, split)
		node.right = BSPNode.new(node.x, node.y + split, node.bsp_width, node.bsp_height - split)
	else:
		# 분할 불가, 방 생성
		var room_w := _rng.range_int(min_size, maxi(min_size, node.bsp_width - 1))
		var room_h := _rng.range_int(min_size, maxi(min_size, node.bsp_height - 1))
		var room_x := node.x + _rng.range_int(0, maxi(0, node.bsp_width - room_w - 1))
		var room_y := node.y + _rng.range_int(0, maxi(0, node.bsp_height - room_h - 1))
		node.room = Rect2i(room_x, room_y, room_w, room_h)
		return

	if node.left:
		_split_node(node.left, min_size)
	if node.right:
		_split_node(node.right, min_size)


func _collect_rooms(node: BSPNode, rooms: Array[Rect2i]) -> void:
	if node.room != Rect2i():
		rooms.append(node.room)
	if node.left:
		_collect_rooms(node.left, rooms)
	if node.right:
		_collect_rooms(node.right, rooms)


func _apply_rooms_to_grid(data: StationLayout, rooms: Array[Rect2i]) -> void:
	for room in rooms:
		for y in range(room.position.y, room.position.y + room.size.y):
			for x in range(room.position.x, room.position.x + room.size.x):
				data.set_tile(Vector2i(x, y), Constants.TileType.FLOOR)


func _connect_rooms(data: StationLayout, rooms: Array[Rect2i]) -> void:
	if rooms.size() < 2:
		return

	# 각 방의 중심점
	var centers: Array[Vector2i] = []
	for room in rooms:
		centers.append(Vector2i(
			room.position.x + room.size.x / 2,
			room.position.y + room.size.y / 2
		))

	# MST로 연결 (Prim's algorithm)
	var connected: Array[int] = [0]
	var unconnected: Array[int] = []
	for i in range(1, centers.size()):
		unconnected.append(i)

	while not unconnected.is_empty():
		var best_from := -1
		var best_to := -1
		var best_dist := INF

		for from_idx in connected:
			for to_idx in unconnected:
				var dist := UtilsClass.manhattan_distance(centers[from_idx], centers[to_idx])
				if dist < best_dist:
					best_dist = dist
					best_from = from_idx
					best_to = to_idx

		if best_to != -1:
			_create_corridor(data, centers[best_from], centers[best_to])
			connected.append(best_to)
			unconnected.erase(best_to)


func _create_corridor(data: StationLayout, from: Vector2i, to: Vector2i) -> void:
	var current := from

	# L자형 복도 (수평 -> 수직)
	while current.x != to.x:
		data.set_tile(current, Constants.TileType.FLOOR)
		current.x += 1 if to.x > current.x else -1

	while current.y != to.y:
		data.set_tile(current, Constants.TileType.FLOOR)
		current.y += 1 if to.y > current.y else -1

	data.set_tile(to, Constants.TileType.FLOOR)


func _generate_walls(data: StationLayout) -> void:
	## 바닥 주변에 벽 생성
	for y in range(data.height):
		for x in range(data.width):
			if data.tiles[y][x] != Constants.TileType.VOID:
				continue

			# 인접 타일에 바닥이 있으면 벽
			var has_floor_neighbor := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var nx := x + dx
					var ny := y + dy
					if data.is_valid_position(Vector2i(nx, ny)):
						var neighbor_tile: Constants.TileType = data.tiles[ny][nx]
						if neighbor_tile in [Constants.TileType.FLOOR, Constants.TileType.FACILITY]:
							has_floor_neighbor = true
							break
				if has_floor_neighbor:
					break

			if has_floor_neighbor:
				data.tiles[y][x] = Constants.TileType.WALL


func _place_facilities(data: StationLayout, rooms: Array[Rect2i], count: int) -> void:
	var facility_types := ["housing", "housing", "medical", "armory", "comm_tower", "power_plant"]
	var shuffled: Array = _rng.shuffle(facility_types)

	for i in range(mini(count, rooms.size())):
		var room := rooms[i]
		var facility_id: String = shuffled[i % shuffled.size()]

		var pos := Vector2i(
			room.position.x + room.size.x / 2,
			room.position.y + room.size.y / 2
		)

		data.set_tile(pos, Constants.TileType.FACILITY)

		var placement := FacilityPlacement.new(facility_id, pos)
		data.facilities.append(placement)


func _place_entry_points(data: StationLayout) -> Array[Vector2i]:
	var count := _rng.range_int(2, 4)
	var edges := ["top", "bottom", "left", "right"]
	var used_edges: Array[String] = []

	for i in range(count):
		var edge: String = edges[i % edges.size()]
		if edge in used_edges and _rng.chance(0.7):
			continue

		var pos: Vector2i = _find_entry_point_on_edge(data, edge)
		if pos != Vector2i(-1, -1):
			data.entry_points.append(pos)
			data.set_tile(pos, Constants.TileType.AIRLOCK)
			used_edges.append(edge)

	return data.entry_points


func _find_entry_point_on_edge(data: StationLayout, edge: String) -> Vector2i:
	var candidates: Array[Vector2i] = []

	match edge:
		"top":
			for x in range(data.width):
				if data.tiles[1][x] == Constants.TileType.FLOOR:
					candidates.append(Vector2i(x, 0))
		"bottom":
			for x in range(data.width):
				if data.tiles[data.height - 2][x] == Constants.TileType.FLOOR:
					candidates.append(Vector2i(x, data.height - 1))
		"left":
			for y in range(data.height):
				if data.tiles[y][1] == Constants.TileType.FLOOR:
					candidates.append(Vector2i(0, y))
		"right":
			for y in range(data.height):
				if data.tiles[y][data.width - 2] == Constants.TileType.FLOOR:
					candidates.append(Vector2i(data.width - 1, y))

	if candidates.is_empty():
		return Vector2i(-1, -1)

	return _rng.choice(candidates)


func _setup_deploy_zones(data: StationLayout) -> void:
	## 배치 영역 설정 (시설 근처 바닥)
	for facility in data.facilities:
		var pos: Vector2i = facility.position
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var check_pos: Vector2i = Vector2i(pos.x + dx, pos.y + dy)
				if data.is_valid_position(check_pos):
					var tile: Constants.TileType = data.get_tile(check_pos)
					if tile == Constants.TileType.FLOOR:
						if check_pos not in data.deploy_zones:
							data.deploy_zones.append(check_pos)


func _generate_height_map(data: StationLayout) -> void:
	## 고도 맵 생성 (중앙 고지대, 외곽 저지대)
	var center := Vector2(data.width / 2.0, data.height / 2.0)
	var max_dist := center.length()

	for y in range(data.height):
		for x in range(data.width):
			var tile: Constants.TileType = data.tiles[y][x]
			if tile != Constants.TileType.FLOOR:
				continue

			var dist: float = Vector2(x, y).distance_to(center)
			var ratio: float = dist / max_dist

			if ratio < 0.3 and _rng.chance(0.25):
				data.height_map[y][x] = 1
				data.tiles[y][x] = Constants.TileType.ELEVATED
			elif ratio > 0.7 and _rng.chance(0.15):
				data.height_map[y][x] = -1
				data.tiles[y][x] = Constants.TileType.LOWERED


func _place_cover(data: StationLayout) -> void:
	## 엄폐물 배치 (복도와 방 경계에)
	for y in range(1, data.height - 1):
		for x in range(1, data.width - 1):
			var tile: Constants.TileType = data.tiles[y][x]
			if tile != Constants.TileType.FLOOR:
				continue

			# 벽에 인접하고, 진입점이 보이는 위치에 엄폐물
			var adjacent_wall: bool = false
			for dir in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				var neighbor: Vector2i = Vector2i(x, y) + dir
				if data.is_valid_position(neighbor):
					if data.tiles[neighbor.y][neighbor.x] == Constants.TileType.WALL:
						adjacent_wall = true
						break

			if adjacent_wall and _rng.chance(0.12):
				data.tiles[y][x] = Constants.TileType.COVER_HALF
