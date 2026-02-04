class_name LineOfSight
extends RefCounted

## 브레젠햄 알고리즘 기반 시야선 계산
## [br][br]
## TileGrid와 함께 사용하여 시야선, 가시 영역 등을 계산합니다.

const UtilsClass = preload("res://src/utils/Utils.gd")


# ===== PROPERTIES =====

var grid  # TileGrid - type hint removed to avoid circular reference


# ===== INITIALIZATION =====

func _init(tile_grid) -> void:
	grid = tile_grid


# ===== LINE OF SIGHT =====

## 두 지점 사이에 시야선이 있는지 확인합니다.
## [br][br]
## [param from]: 시작 타일 좌표
## [param to]: 목표 타일 좌표
## [return]: 시야선 존재 여부
func has_los(from: Vector2i, to: Vector2i) -> bool:
	var tiles := get_los_tiles(from, to)

	for tile_pos in tiles:
		if tile_pos == from or tile_pos == to:
			continue

		var tile := grid.get_tile(tile_pos)
		if tile and tile.is_blocking_los():
			return false

	return true


## 두 지점 사이의 시야선 경로를 반환합니다 (브레젠햄 알고리즘).
## [br][br]
## [param from]: 시작 타일 좌표
## [param to]: 목표 타일 좌표
## [return]: 시야선 경로 타일 배열
func get_los_tiles(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []

	var x0 := from.x
	var y0 := from.y
	var x1 := to.x
	var y1 := to.y

	var dx: int = abs(x1 - x0)
	var dy: int = abs(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx - dy

	while true:
		result.append(Vector2i(x0, y0))

		if x0 == x1 and y0 == y1:
			break

		var e2: int = 2 * err

		if e2 > -dy:
			err -= dy
			x0 += sx

		if e2 < dx:
			err += dx
			y0 += sy

	return result


## 주어진 위치에서 볼 수 있는 모든 타일을 반환합니다.
## [br][br]
## [param from]: 시작 타일 좌표
## [param max_range]: 최대 시야 거리
## [return]: 가시 타일 좌표 배열
func get_visible_tiles(from: Vector2i, max_range: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var checked: Dictionary = {}

	# 원형 범위 내 모든 타일 검사
	for y in range(-max_range, max_range + 1):
		for x in range(-max_range, max_range + 1):
			var pos := from + Vector2i(x, y)

			if not grid.is_valid_position(pos):
				continue

			if checked.has(pos):
				continue

			var dist := UtilsClass.euclidean_distance(
				Vector2(from.x, from.y),
				Vector2(pos.x, pos.y)
			)

			if dist > max_range:
				continue

			checked[pos] = true

			if has_los(from, pos):
				result.append(pos)

	return result


## 원뿔 형태의 시야 범위 내 타일을 반환합니다.
## [br][br]
## [param from]: 시작 타일 좌표
## [param direction]: 원뿔 방향 벡터
## [param angle_degrees]: 원뿔 각도 (전체 각도)
## [param max_range]: 최대 거리
## [return]: 원뿔 범위 내 가시 타일 좌표 배열
func get_tiles_in_cone(from: Vector2i, direction: Vector2, angle_degrees: float, max_range: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var half_angle := deg_to_rad(angle_degrees / 2.0)
	var dir_normalized := direction.normalized()

	# 방향이 없으면 빈 배열 반환
	if dir_normalized.length_squared() < 0.001:
		return result

	for y in range(-max_range, max_range + 1):
		for x in range(-max_range, max_range + 1):
			var pos := from + Vector2i(x, y)

			if not grid.is_valid_position(pos) or pos == from:
				continue

			# 방향 벡터 계산
			var to_pos := Vector2(pos.x - from.x, pos.y - from.y).normalized()
			var angle_to_pos := dir_normalized.angle_to(to_pos)

			# 각도 체크
			if abs(angle_to_pos) > half_angle:
				continue

			# 거리 체크
			var dist := UtilsClass.euclidean_distance(
				Vector2(from.x, from.y),
				Vector2(pos.x, pos.y)
			)

			if dist > max_range:
				continue

			# 시야선 체크
			if has_los(from, pos):
				result.append(pos)

	return result


## 직선 방향으로 시야가 닿는 타일들을 반환합니다 (벽에서 멈춤).
## [br][br]
## [param from]: 시작 타일 좌표
## [param direction]: 방향 벡터
## [param max_range]: 최대 거리
## [return]: 시야 경로 타일 좌표 배열
func get_tiles_along_ray(from: Vector2i, direction: Vector2, max_range: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var dir_normalized := direction.normalized()

	if dir_normalized.length_squared() < 0.001:
		return result

	var current := Vector2(from.x + 0.5, from.y + 0.5)  # 타일 중심에서 시작

	for _i in range(max_range * 2):  # 서브스텝
		current += dir_normalized * 0.5
		var tile_pos := Vector2i(int(current.x), int(current.y))

		if not grid.is_valid_position(tile_pos):
			break

		if tile_pos != from and not result.has(tile_pos):
			result.append(tile_pos)

			# 벽에 막히면 중단
			var tile := grid.get_tile(tile_pos)
			if tile and tile.is_blocking_los():
				break

		# 최대 거리 체크
		var dist := UtilsClass.euclidean_distance(
			Vector2(from.x, from.y),
			Vector2(tile_pos.x, tile_pos.y)
		)
		if dist > max_range:
			break

	return result


## 두 지점 사이에 부분 엄폐물이 있는지 확인합니다.
## [br][br]
## [param from]: 공격자 타일 좌표
## [param to]: 타겟 타일 좌표
## [return]: 엄폐 정보 {"has_cover": bool, "reduction": float}
func check_cover(from: Vector2i, to: Vector2i) -> Dictionary:
	var tiles := get_los_tiles(from, to)
	var has_cover := false
	var max_reduction := 0.0

	for tile_pos in tiles:
		# 시작점과 끝점은 제외
		if tile_pos == from or tile_pos == to:
			continue

		var tile := grid.get_tile(tile_pos)
		if tile == null:
			continue

		# 부분 엄폐 체크
		if tile.is_partial_cover():
			has_cover = true
			var reduction: float = tile.get_cover_reduction()
			if reduction > max_reduction:
				max_reduction = reduction

	# 타겟 위치의 엄폐물도 체크
	var target_tile := grid.get_tile(to)
	if target_tile and target_tile.is_partial_cover():
		has_cover = true
		var reduction: float = target_tile.get_cover_reduction()
		if reduction > max_reduction:
			max_reduction = reduction

	return {
		"has_cover": has_cover,
		"reduction": max_reduction
	}
