class_name Pathfinding
extends RefCounted

## A* 경로탐색 구현
## [br][br]
## TileGrid와 함께 사용하여 타일 간 최단 경로를 찾습니다.


# ===== PROPERTIES =====

var grid  # TileGrid - type hint removed to avoid circular reference


# ===== INITIALIZATION =====

func _init(tile_grid) -> void:
	grid = tile_grid


# ===== PATHFINDING =====

## 두 지점 사이의 최단 경로를 찾습니다 (A* 알고리즘).
## [br][br]
## [param from]: 시작 타일 좌표
## [param to]: 목표 타일 좌표
## [param ignore_occupants]: 점유자 무시 여부
## [return]: 경로 타일 배열 (시작점 제외, 목표점 포함). 경로 없으면 빈 배열.
func find_path(from: Vector2i, to: Vector2i, ignore_occupants: bool = false) -> Array[Vector2i]:
	if not grid.is_valid_position(from) or not grid.is_valid_position(to):
		return []

	if from == to:
		return []

	# 목표가 이동 불가면 가장 가까운 이동 가능 타일 찾기
	if not _is_walkable(to, ignore_occupants):
		to = _find_nearest_walkable(to, ignore_occupants)
		if to == Vector2i(-1, -1):
			return []

	var open_set: Array[Vector2i] = [from]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {from: 0.0}
	var f_score: Dictionary = {from: _heuristic(from, to)}

	var iterations := 0
	var max_iterations := grid.width * grid.height * 2  # 무한 루프 방지

	while not open_set.is_empty() and iterations < max_iterations:
		iterations += 1

		# 가장 낮은 f_score를 가진 노드 선택
		var current := _get_lowest_f_score(open_set, f_score)

		if current == to:
			return _reconstruct_path(came_from, current)

		open_set.erase(current)

		for neighbor in grid.get_neighbors(current, false):
			if not _is_walkable(neighbor, ignore_occupants):
				# 목표 지점은 예외로 허용 (도착 지점에 적이 있을 수 있음)
				if neighbor != to:
					continue

			var tile := grid.get_tile(neighbor)
			var movement_cost: float = tile.get_movement_cost() if tile else 1.0
			var tentative_g: float = g_score.get(current, INF) + movement_cost

			if tentative_g < g_score.get(neighbor, INF):
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				f_score[neighbor] = tentative_g + _heuristic(neighbor, to)

				if not neighbor in open_set:
					open_set.append(neighbor)

	# 경로 없음
	return []


## 주어진 위치에서 도달 가능한 모든 타일을 반환합니다.
## [br][br]
## [param from]: 시작 타일 좌표
## [param max_distance]: 최대 이동 거리 (이동 비용 기준)
## [return]: 도달 가능한 타일 좌표 배열
func get_reachable_tiles(from: Vector2i, max_distance: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var visited: Dictionary = {from: 0}
	var queue: Array = [[from, 0]]

	while not queue.is_empty():
		var item: Array = queue.pop_front()
		var current: Vector2i = item[0]
		var dist: int = item[1]

		if dist > 0:
			result.append(current)

		if dist >= max_distance:
			continue

		for neighbor in grid.get_neighbors(current, false):
			if not grid.is_walkable(neighbor):
				continue

			var tile := grid.get_tile(neighbor)
			var cost := int(tile.get_movement_cost()) if tile else 1
			var new_dist := dist + cost

			if new_dist <= max_distance:
				if not visited.has(neighbor) or visited[neighbor] > new_dist:
					visited[neighbor] = new_dist
					queue.append([neighbor, new_dist])

	return result


# ===== PRIVATE METHODS =====

## 타일이 이동 가능한지 확인합니다.
func _is_walkable(pos: Vector2i, ignore_occupants: bool) -> bool:
	if ignore_occupants:
		return grid.is_walkable_ignore_occupant(pos)
	return grid.is_walkable(pos)


## 휴리스틱 함수 (맨해튼 거리).
func _heuristic(a: Vector2i, b: Vector2i) -> float:
	return float(abs(a.x - b.x) + abs(a.y - b.y))


## open_set에서 가장 낮은 f_score를 가진 노드를 반환합니다.
func _get_lowest_f_score(open_set: Array[Vector2i], f_score: Dictionary) -> Vector2i:
	var lowest: Vector2i = open_set[0]
	var lowest_score: float = f_score.get(lowest, INF)

	for node in open_set:
		var score: float = f_score.get(node, INF)
		if score < lowest_score:
			lowest_score = score
			lowest = node

	return lowest


## came_from 딕셔너리에서 경로를 재구성합니다.
func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [current]

	while current in came_from:
		current = came_from[current]
		path.push_front(current)

	# 시작점 제외
	if path.size() > 0:
		path.remove_at(0)

	return path


## 주어진 위치에서 가장 가까운 이동 가능 타일을 찾습니다.
func _find_nearest_walkable(pos: Vector2i, ignore_occupants: bool) -> Vector2i:
	var checked: Dictionary = {}
	var queue: Array[Vector2i] = [pos]

	var iterations := 0
	var max_iterations := grid.width * grid.height

	while not queue.is_empty() and iterations < max_iterations:
		iterations += 1
		var current: Vector2i = queue.pop_front()

		if checked.has(current):
			continue
		checked[current] = true

		if _is_walkable(current, ignore_occupants):
			return current

		for neighbor in grid.get_neighbors(current, false):
			if not checked.has(neighbor):
				queue.append(neighbor)

	return Vector2i(-1, -1)
