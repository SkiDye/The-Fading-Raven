## TileRenderer - 타일 그리드 렌더링
## 아이소메트릭 타일맵 시각화
extends Node2D
class_name TileRenderer

# ===========================================
# 설정
# ===========================================

const TILE_WIDTH := 64
const TILE_HEIGHT := 32

# 타일 색상
const TILE_COLORS := {
	TileGrid.TileType.VOID: Color(0.05, 0.05, 0.1, 0.5),
	TileGrid.TileType.FLOOR: Color(0.2, 0.2, 0.25, 1.0),
	TileGrid.TileType.WALL: Color(0.1, 0.1, 0.15, 1.0),
	TileGrid.TileType.FACILITY: Color(0.3, 0.5, 0.3, 1.0),
	TileGrid.TileType.AIRLOCK: Color(0.6, 0.3, 0.3, 1.0),
	TileGrid.TileType.ELEVATED: Color(0.25, 0.25, 0.35, 1.0),
	TileGrid.TileType.LOWERED: Color(0.15, 0.15, 0.2, 1.0),
	TileGrid.TileType.COVER: Color(0.3, 0.3, 0.2, 1.0),
}

# 참조
var grid: TileGrid = null
var highlight_tiles: Array[Vector2i] = []
var highlight_color: Color = Color(0.5, 0.8, 0.5, 0.3)


# ===========================================
# 초기화
# ===========================================

func setup(tile_grid: TileGrid) -> void:
	grid = tile_grid
	queue_redraw()


func clear() -> void:
	grid = null
	highlight_tiles.clear()
	queue_redraw()


# ===========================================
# 렌더링
# ===========================================

func _draw() -> void:
	if grid == null:
		return

	# 모든 타일 그리기
	for y in range(grid.height):
		for x in range(grid.width):
			var tile_type := grid.get_tile(x, y)
			var screen_pos := grid_to_screen(Vector2i(x, y))

			# 타일 다이아몬드 그리기
			_draw_tile(screen_pos, tile_type)

			# 시설 아이콘
			if tile_type == TileGrid.TileType.FACILITY:
				_draw_facility_icon(screen_pos, grid.get_facility_at(Vector2i(x, y)))

			# 에어락 아이콘
			if tile_type == TileGrid.TileType.AIRLOCK:
				_draw_airlock_icon(screen_pos)

	# 하이라이트 타일
	for pos in highlight_tiles:
		var screen_pos := grid_to_screen(pos)
		_draw_tile_highlight(screen_pos, highlight_color)


func _draw_tile(screen_pos: Vector2, tile_type: TileGrid.TileType) -> void:
	var color: Color = TILE_COLORS.get(tile_type, TILE_COLORS[TileGrid.TileType.VOID])

	# 아이소메트릭 다이아몬드 형태
	var points := PackedVector2Array([
		screen_pos + Vector2(0, -TILE_HEIGHT / 2),           # 상단
		screen_pos + Vector2(TILE_WIDTH / 2, 0),             # 우측
		screen_pos + Vector2(0, TILE_HEIGHT / 2),            # 하단
		screen_pos + Vector2(-TILE_WIDTH / 2, 0),            # 좌측
	])

	# 채우기
	draw_colored_polygon(points, color)

	# 테두리
	var outline_color := color.lightened(0.2)
	outline_color.a = 0.5
	for i in range(4):
		draw_line(points[i], points[(i + 1) % 4], outline_color, 1.0)

	# 높은 지형 표시
	if tile_type == TileGrid.TileType.ELEVATED:
		var height_offset := Vector2(0, -8)
		var elevated_points := PackedVector2Array()
		for p in points:
			elevated_points.append(p + height_offset)
		draw_colored_polygon(elevated_points, color.lightened(0.1))


func _draw_tile_highlight(screen_pos: Vector2, color: Color) -> void:
	var points := PackedVector2Array([
		screen_pos + Vector2(0, -TILE_HEIGHT / 2),
		screen_pos + Vector2(TILE_WIDTH / 2, 0),
		screen_pos + Vector2(0, TILE_HEIGHT / 2),
		screen_pos + Vector2(-TILE_WIDTH / 2, 0),
	])

	draw_colored_polygon(points, color)


func _draw_facility_icon(screen_pos: Vector2, facility: Dictionary) -> void:
	if facility.is_empty():
		return

	var health_ratio := float(facility.get("health", 0)) / float(facility.get("max_health", 100))

	# 아이콘 색상 (체력에 따라)
	var icon_color: Color
	if health_ratio > 0.6:
		icon_color = Color(0.4, 0.8, 0.4)
	elif health_ratio > 0.3:
		icon_color = Color(0.8, 0.8, 0.3)
	else:
		icon_color = Color(0.8, 0.3, 0.3)

	# 간단한 건물 아이콘
	draw_rect(Rect2(screen_pos - Vector2(8, 12), Vector2(16, 12)), icon_color)
	draw_rect(Rect2(screen_pos - Vector2(4, 16), Vector2(8, 4)), icon_color.lightened(0.2))


func _draw_airlock_icon(screen_pos: Vector2) -> void:
	# 적 스폰 포인트 표시
	var icon_color := Color(0.8, 0.4, 0.4, 0.8)
	draw_circle(screen_pos - Vector2(0, 4), 6, icon_color)

	# 경고 삼각형
	var triangle := PackedVector2Array([
		screen_pos + Vector2(0, -12),
		screen_pos + Vector2(-5, -4),
		screen_pos + Vector2(5, -4),
	])
	draw_colored_polygon(triangle, Color(0.9, 0.3, 0.3))


# ===========================================
# 좌표 변환
# ===========================================

## 그리드 좌표 → 화면 좌표
func grid_to_screen(grid_pos: Vector2i) -> Vector2:
	var x := (grid_pos.x - grid_pos.y) * (TILE_WIDTH / 2)
	var y := (grid_pos.x + grid_pos.y) * (TILE_HEIGHT / 2)
	return Vector2(x, y)


## 화면 좌표 → 그리드 좌표
func screen_to_grid(screen_pos: Vector2) -> Vector2i:
	var x := (screen_pos.x / (TILE_WIDTH / 2) + screen_pos.y / (TILE_HEIGHT / 2)) / 2
	var y := (screen_pos.y / (TILE_HEIGHT / 2) - screen_pos.x / (TILE_WIDTH / 2)) / 2
	return Vector2i(int(round(x)), int(round(y)))


## 월드 좌표 → 그리드 좌표 (카메라 고려)
func world_to_grid(world_pos: Vector2) -> Vector2i:
	var local_pos := to_local(world_pos)
	return screen_to_grid(local_pos)


# ===========================================
# 하이라이트
# ===========================================

## 이동 가능 타일 하이라이트
func show_movement_range(tiles: Array[Vector2i], color: Color = Color(0.3, 0.6, 0.9, 0.3)) -> void:
	highlight_tiles = tiles
	highlight_color = color
	queue_redraw()


## 공격 범위 하이라이트
func show_attack_range(tiles: Array[Vector2i], color: Color = Color(0.9, 0.3, 0.3, 0.3)) -> void:
	highlight_tiles = tiles
	highlight_color = color
	queue_redraw()


## 하이라이트 클리어
func clear_highlight() -> void:
	highlight_tiles.clear()
	queue_redraw()


# ===========================================
# 타일 상호작용
# ===========================================

## 마우스 위치의 그리드 좌표 가져오기
func get_tile_at_mouse() -> Vector2i:
	var mouse_pos := get_global_mouse_position()
	return world_to_grid(mouse_pos)


## 특정 타일이 유효하고 이동 가능한지 확인
func is_valid_move_target(grid_pos: Vector2i) -> bool:
	if grid == null:
		return false
	return grid.is_walkable_v(grid_pos)
