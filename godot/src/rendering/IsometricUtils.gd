class_name IsometricUtils
extends RefCounted

## 2.5D 아이소메트릭 좌표 변환 유틸리티
## 2:1 다이아몬드 아이소메트릭 (표준 아이소메트릭)

# ===== CONSTANTS =====

## 타일 크기 (픽셀)
const TILE_WIDTH: int = 64
const TILE_HEIGHT: int = 32  # 2:1 비율
const TILE_DEPTH: int = 16   # 높이 레벨당 픽셀

## 반 타일 (자주 사용)
const HALF_TILE_WIDTH: int = TILE_WIDTH / 2   # 32
const HALF_TILE_HEIGHT: int = TILE_HEIGHT / 2  # 16


# ===== COORDINATE CONVERSION =====

## 타일 좌표 → 화면 좌표 (아이소메트릭)
## [param tile_pos]: 타일 좌표 (x, y)
## [param elevation]: 높이 레벨 (0, 1, 2...)
## [return]: 화면 좌표 (타일 중심)
static func tile_to_screen(tile_pos: Vector2i, elevation: int = 0) -> Vector2:
	var screen_x: float = (tile_pos.x - tile_pos.y) * HALF_TILE_WIDTH
	var screen_y: float = (tile_pos.x + tile_pos.y) * HALF_TILE_HEIGHT
	screen_y -= elevation * TILE_DEPTH
	return Vector2(screen_x, screen_y)


## 화면 좌표 → 타일 좌표 (아이소메트릭)
## [param screen_pos]: 화면 좌표
## [param elevation]: 가정할 높이 레벨
## [return]: 타일 좌표
static func screen_to_tile(screen_pos: Vector2, elevation: int = 0) -> Vector2i:
	# 높이 보정
	var adjusted_y: float = screen_pos.y + elevation * TILE_DEPTH

	# 역변환
	var tile_x: float = (screen_pos.x / HALF_TILE_WIDTH + adjusted_y / HALF_TILE_HEIGHT) / 2.0
	var tile_y: float = (adjusted_y / HALF_TILE_HEIGHT - screen_pos.x / HALF_TILE_WIDTH) / 2.0

	return Vector2i(floori(tile_x), floori(tile_y))


## 타일 좌표 → 화면 좌표 (타일 상단 모서리)
static func tile_to_screen_top(tile_pos: Vector2i, elevation: int = 0) -> Vector2:
	var center := tile_to_screen(tile_pos, elevation)
	return center - Vector2(0, HALF_TILE_HEIGHT)


## 타일 좌표 → 화면 좌표 (타일 바닥 중심)
static func tile_to_screen_floor(tile_pos: Vector2i, elevation: int = 0) -> Vector2:
	return tile_to_screen(tile_pos, elevation)


# ===== DEPTH SORTING =====

## 깊이 정렬용 Z-index 계산
## 뒤에서 앞으로: Y가 클수록 앞, X가 클수록 앞
## [param tile_pos]: 타일 좌표
## [param elevation]: 높이 레벨
## [return]: Z-index 값
static func calculate_z_index(tile_pos: Vector2i, elevation: int = 0) -> int:
	# 기본 깊이: x + y (아이소메트릭에서 앞쪽)
	var base_depth: int = tile_pos.x + tile_pos.y
	# 높이 보정: 높을수록 위에 그려짐
	var height_offset: int = elevation * 100
	return base_depth + height_offset


## Y-sort용 위치 계산
static func calculate_y_sort_position(tile_pos: Vector2i, elevation: int = 0) -> float:
	var screen_pos := tile_to_screen(tile_pos, elevation)
	# Y 좌표가 클수록 앞에 그려짐
	return screen_pos.y + (tile_pos.x + tile_pos.y) * 0.1


# ===== TILE GEOMETRY =====

## 아이소메트릭 타일의 4개 꼭짓점 (다이아몬드)
## [return]: [top, right, bottom, left] 순서
static func get_tile_vertices(tile_pos: Vector2i, elevation: int = 0) -> PackedVector2Array:
	var center := tile_to_screen(tile_pos, elevation)
	return PackedVector2Array([
		center + Vector2(0, -HALF_TILE_HEIGHT),  # top
		center + Vector2(HALF_TILE_WIDTH, 0),    # right
		center + Vector2(0, HALF_TILE_HEIGHT),   # bottom
		center + Vector2(-HALF_TILE_WIDTH, 0),   # left
	])


## 아이소메트릭 큐브(박스)의 면 정점들
## [return]: {"top": [...], "left": [...], "right": [...]}
static func get_cube_faces(tile_pos: Vector2i, elevation: int = 0, height: int = 1) -> Dictionary:
	var top_center := tile_to_screen(tile_pos, elevation + height)
	var bottom_center := tile_to_screen(tile_pos, elevation)

	# 상단 면 (다이아몬드)
	var top_face := PackedVector2Array([
		top_center + Vector2(0, -HALF_TILE_HEIGHT),
		top_center + Vector2(HALF_TILE_WIDTH, 0),
		top_center + Vector2(0, HALF_TILE_HEIGHT),
		top_center + Vector2(-HALF_TILE_WIDTH, 0),
	])

	# 왼쪽 면 (평행사변형)
	var left_face := PackedVector2Array([
		top_center + Vector2(-HALF_TILE_WIDTH, 0),
		top_center + Vector2(0, HALF_TILE_HEIGHT),
		bottom_center + Vector2(0, HALF_TILE_HEIGHT),
		bottom_center + Vector2(-HALF_TILE_WIDTH, 0),
	])

	# 오른쪽 면 (평행사변형)
	var right_face := PackedVector2Array([
		top_center + Vector2(HALF_TILE_WIDTH, 0),
		top_center + Vector2(0, HALF_TILE_HEIGHT),
		bottom_center + Vector2(0, HALF_TILE_HEIGHT),
		bottom_center + Vector2(HALF_TILE_WIDTH, 0),
	])

	return {
		"top": top_face,
		"left": left_face,
		"right": right_face
	}


# ===== MOUSE/INPUT =====

## 마우스 위치가 타일 내부에 있는지 확인
static func is_point_in_tile(point: Vector2, tile_pos: Vector2i, elevation: int = 0) -> bool:
	var vertices := get_tile_vertices(tile_pos, elevation)
	return Geometry2D.is_point_in_polygon(point, vertices)


## 주어진 화면 좌표에서 가장 가까운 타일 찾기 (여러 높이 고려)
static func find_tile_at_screen(screen_pos: Vector2, max_elevation: int = 3) -> Dictionary:
	# 높은 곳부터 검사 (위에 있는 것이 클릭 우선)
	for elev in range(max_elevation, -1, -1):
		var tile_pos := screen_to_tile(screen_pos, elev)
		if is_point_in_tile(screen_pos, tile_pos, elev):
			return {"position": tile_pos, "elevation": elev, "found": true}

	# 못 찾으면 elevation 0 기준
	return {"position": screen_to_tile(screen_pos, 0), "elevation": 0, "found": false}


# ===== CAMERA =====

## 맵 중심 계산
static func get_map_center(width: int, height: int) -> Vector2:
	var center_tile := Vector2i(width / 2, height / 2)
	return tile_to_screen(center_tile, 0)


## 맵 경계 계산 (AABB)
static func get_map_bounds(width: int, height: int, max_elevation: int = 0) -> Rect2:
	# 4개 코너 타일의 화면 좌표
	var top_left := tile_to_screen(Vector2i(0, 0), max_elevation)
	var top_right := tile_to_screen(Vector2i(width - 1, 0), max_elevation)
	var bottom_left := tile_to_screen(Vector2i(0, height - 1), 0)
	var bottom_right := tile_to_screen(Vector2i(width - 1, height - 1), 0)

	var min_x := minf(top_left.x, minf(top_right.x, minf(bottom_left.x, bottom_right.x)))
	var max_x := maxf(top_left.x, maxf(top_right.x, maxf(bottom_left.x, bottom_right.x)))
	var min_y := minf(top_left.y, maxf(top_right.y, minf(bottom_left.y, bottom_right.y)))
	var max_y := maxf(top_left.y, maxf(top_right.y, maxf(bottom_left.y, bottom_right.y)))

	# 패딩 추가
	var padding := Vector2(TILE_WIDTH, TILE_HEIGHT * 2)
	return Rect2(
		Vector2(min_x, min_y) - padding,
		Vector2(max_x - min_x, max_y - min_y) + padding * 2
	)


# ===== DISTANCE =====

## 타일 간 맨해튼 거리
static func tile_distance(from: Vector2i, to: Vector2i) -> int:
	return absi(to.x - from.x) + absi(to.y - from.y)


## 타일 간 유클리드 거리 (화면 좌표 기준)
static func screen_distance(from: Vector2i, to: Vector2i) -> float:
	var screen_from := tile_to_screen(from)
	var screen_to := tile_to_screen(to)
	return screen_from.distance_to(screen_to)
