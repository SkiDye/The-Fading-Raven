## Pathfinder - A* 경로 탐색
## TileGrid 기반 경로 찾기
extends RefCounted
class_name Pathfinder

var _grid: TileGrid
var _astar: AStar2D


func _init(grid: TileGrid) -> void:
	_grid = grid
	_astar = AStar2D.new()
	rebuild()


# ===========================================
# 그리드 빌드
# ===========================================

func rebuild() -> void:
	_astar.clear()

	# 모든 이동 가능 타일을 노드로 추가
	for y in range(_grid.height):
		for x in range(_grid.width):
			if _grid.is_walkable(x, y):
				var id := _pos_to_id(x, y)
				_astar.add_point(id, Vector2(x, y))

	# 연결 설정
	for y in range(_grid.height):
		for x in range(_grid.width):
			if not _grid.is_walkable(x, y):
				continue

			var id := _pos_to_id(x, y)
			var pos := Vector2i(x, y)

			# 4방향 연결
			for neighbor in _grid.get_walkable_neighbors(pos, false):
				var neighbor_id := _pos_to_id(neighbor.x, neighbor.y)
				if _astar.has_point(neighbor_id) and not _astar.are_points_connected(id, neighbor_id):
					# 이동 비용 반영
					var cost := float(_grid.get_move_cost_v(neighbor))
					_astar.connect_points(id, neighbor_id, false)


func _pos_to_id(x: int, y: int) -> int:
	return y * _grid.width + x


func _id_to_pos(id: int) -> Vector2i:
	return Vector2i(id % _grid.width, id / _grid.width)


# ===========================================
# 경로 탐색
# ===========================================

## 최단 경로 찾기
func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if not _grid.is_walkable_v(from) or not _grid.is_walkable_v(to):
		return []

	var from_id := _pos_to_id(from.x, from.y)
	var to_id := _pos_to_id(to.x, to.y)

	if not _astar.has_point(from_id) or not _astar.has_point(to_id):
		return []

	var path_points := _astar.get_point_path(from_id, to_id)

	var result: Array[Vector2i] = []
	for p in path_points:
		result.append(Vector2i(int(p.x), int(p.y)))

	return result


## 경로 길이 (타일 수)
func get_path_length(from: Vector2i, to: Vector2i) -> int:
	var path := find_path(from, to)
	return path.size()


## 경로 비용 (이동 비용 합계)
func get_path_cost(from: Vector2i, to: Vector2i) -> int:
	var path := find_path(from, to)
	if path.is_empty():
		return -1

	var cost := 0
	for pos in path:
		cost += _grid.get_move_cost_v(pos)
	return cost


## 도달 가능 여부
func can_reach(from: Vector2i, to: Vector2i) -> bool:
	return not find_path(from, to).is_empty()


# ===========================================
# 이동 범위
# ===========================================

## 주어진 이동력으로 도달 가능한 모든 타일
func get_reachable_tiles(from: Vector2i, movement_points: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var visited := {}
	var queue: Array[Dictionary] = [{
		"pos": from,
		"cost": 0
	}]

	while not queue.is_empty():
		var current: Dictionary = queue.pop_front()
		var pos: Vector2i = current["pos"]
		var cost: int = current["cost"]

		var key := "%d,%d" % [pos.x, pos.y]
		if visited.has(key):
			continue
		visited[key] = cost

		if pos != from:
			result.append(pos)

		# 이웃 탐색
		for neighbor in _grid.get_walkable_neighbors(pos, false):
			var neighbor_key := "%d,%d" % [neighbor.x, neighbor.y]
			if visited.has(neighbor_key):
				continue

			var move_cost := _grid.get_move_cost_v(neighbor)
			var total_cost := cost + move_cost

			if total_cost <= movement_points:
				queue.append({
					"pos": neighbor,
					"cost": total_cost
				})

	return result


## 주어진 이동력으로 도달 가능한 타일과 비용 맵
func get_reachable_tiles_with_cost(from: Vector2i, movement_points: int) -> Dictionary:
	var result := {}  # Vector2i -> int (cost)
	var visited := {}
	var queue: Array[Dictionary] = [{
		"pos": from,
		"cost": 0
	}]

	while not queue.is_empty():
		var current: Dictionary = queue.pop_front()
		var pos: Vector2i = current["pos"]
		var cost: int = current["cost"]

		var key := "%d,%d" % [pos.x, pos.y]
		if visited.has(key) and visited[key] <= cost:
			continue
		visited[key] = cost

		if pos != from:
			result[pos] = cost

		for neighbor in _grid.get_walkable_neighbors(pos, false):
			var neighbor_key := "%d,%d" % [neighbor.x, neighbor.y]
			var move_cost := _grid.get_move_cost_v(neighbor)
			var total_cost := cost + move_cost

			if total_cost <= movement_points:
				if not visited.has(neighbor_key) or visited[neighbor_key] > total_cost:
					queue.append({
						"pos": neighbor,
						"cost": total_cost
					})

	return result


# ===========================================
# 가장 가까운 타일 찾기
# ===========================================

## 목표에 가장 가까운 도달 가능 타일
func find_closest_reachable(from: Vector2i, to: Vector2i, movement_points: int) -> Vector2i:
	var reachable := get_reachable_tiles(from, movement_points)

	if reachable.is_empty():
		return from

	var closest := reachable[0]
	var closest_dist := _manhattan_distance(closest, to)

	for tile in reachable:
		var dist := _manhattan_distance(tile, to)
		if dist < closest_dist:
			closest = tile
			closest_dist = dist

	return closest


## 조건을 만족하는 가장 가까운 타일
func find_nearest_tile(from: Vector2i, condition: Callable) -> Vector2i:
	var visited := {}
	var queue: Array[Vector2i] = [from]

	while not queue.is_empty():
		var pos: Vector2i = queue.pop_front()

		var key := "%d,%d" % [pos.x, pos.y]
		if visited.has(key):
			continue
		visited[key] = true

		if pos != from and condition.call(pos):
			return pos

		for neighbor in _grid.get_walkable_neighbors(pos, false):
			var neighbor_key := "%d,%d" % [neighbor.x, neighbor.y]
			if not visited.has(neighbor_key):
				queue.append(neighbor)

	return Vector2i(-1, -1)  # 찾지 못함


## 가장 가까운 시설 찾기
func find_nearest_facility(from: Vector2i) -> Vector2i:
	var nearest := Vector2i(-1, -1)
	var nearest_dist := INF

	for facility in _grid.get_intact_facilities():
		var pos: Vector2i = facility["position"]
		var path := find_path(from, pos)
		if not path.is_empty() and path.size() < nearest_dist:
			nearest = pos
			nearest_dist = path.size()

	return nearest


## 가장 가까운 에어락 찾기
func find_nearest_airlock(from: Vector2i) -> Vector2i:
	var nearest := Vector2i(-1, -1)
	var nearest_dist := INF

	for airlock in _grid.airlocks:
		var dist := _manhattan_distance(from, airlock)
		if dist < nearest_dist:
			nearest = airlock
			nearest_dist = dist

	return nearest


# ===========================================
# 유틸리티
# ===========================================

func _manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## 특정 타일의 연결 상태 갱신 (동적 장애물용)
func update_tile(pos: Vector2i) -> void:
	var id := _pos_to_id(pos.x, pos.y)

	# 기존 연결 제거
	if _astar.has_point(id):
		_astar.remove_point(id)

	# 이동 가능하면 다시 추가
	if _grid.is_walkable_v(pos):
		_astar.add_point(id, Vector2(pos.x, pos.y))

		# 이웃과 연결
		for neighbor in _grid.get_walkable_neighbors(pos, false):
			var neighbor_id := _pos_to_id(neighbor.x, neighbor.y)
			if _astar.has_point(neighbor_id):
				_astar.connect_points(id, neighbor_id, false)


## 여러 타일 일괄 갱신
func update_tiles(positions: Array[Vector2i]) -> void:
	for pos in positions:
		update_tile(pos)
