class_name IsometricTileRenderer
extends Node2D

## 아이소메트릭 타일맵 렌더러
## TileGrid 데이터를 기반으로 2.5D 타일맵을 렌더링

const IsometricUtilsClass = preload("res://src/rendering/IsometricUtils.gd")

# ===== SIGNALS =====

signal tile_clicked(tile_pos: Vector2i, elevation: int)
signal tile_hovered(tile_pos: Vector2i, elevation: int)


# ===== CONFIGURATION =====

@export var draw_grid_lines: bool = false
@export var highlight_hovered: bool = true
@export var show_coordinates: bool = false


# ===== TILE COLORS =====

const COLORS = {
	# 바닥 타일
	"floor_top": Color(0.35, 0.4, 0.5),
	"floor_left": Color(0.25, 0.3, 0.4),
	"floor_right": Color(0.3, 0.35, 0.45),

	# 벽
	"wall_top": Color(0.5, 0.55, 0.6),
	"wall_left": Color(0.35, 0.4, 0.45),
	"wall_right": Color(0.4, 0.45, 0.5),

	# 우주 공간 (VOID)
	"void": Color(0.05, 0.05, 0.1, 0.5),

	# 시설
	"facility_top": Color(0.3, 0.5, 0.7),
	"facility_left": Color(0.2, 0.4, 0.6),
	"facility_right": Color(0.25, 0.45, 0.65),

	# 에어락
	"airlock_top": Color(0.6, 0.3, 0.3),
	"airlock_left": Color(0.5, 0.2, 0.2),
	"airlock_right": Color(0.55, 0.25, 0.25),

	# 높은 지형
	"elevated_top": Color(0.45, 0.5, 0.55),
	"elevated_left": Color(0.35, 0.4, 0.45),
	"elevated_right": Color(0.4, 0.45, 0.5),

	# 낮은 지형
	"lowered_top": Color(0.25, 0.3, 0.35),
	"lowered_left": Color(0.18, 0.22, 0.28),
	"lowered_right": Color(0.2, 0.25, 0.3),

	# 엄폐물
	"cover_half_top": Color(0.4, 0.35, 0.3),
	"cover_half_left": Color(0.3, 0.25, 0.2),
	"cover_half_right": Color(0.35, 0.3, 0.25),

	"cover_full_top": Color(0.5, 0.45, 0.4),
	"cover_full_left": Color(0.4, 0.35, 0.3),
	"cover_full_right": Color(0.45, 0.4, 0.35),

	# 그리드 라인
	"grid_line": Color(0.4, 0.45, 0.5, 0.3),

	# 하이라이트
	"highlight": Color(1.0, 1.0, 0.5, 0.3),
	"selection": Color(0.3, 0.8, 0.3, 0.5),
	"move_range": Color(0.3, 0.5, 0.9, 0.3),
	"attack_range": Color(0.9, 0.3, 0.3, 0.3),

	# 진입점
	"entry_point": Color(0.8, 0.2, 0.2, 0.5),
}


# ===== STATE =====

var _tile_grid: Node = null
var _width: int = 0
var _height: int = 0
var _hovered_tile: Vector2i = Vector2i(-1, -1)
var _selected_tiles: Array[Vector2i] = []
var _highlighted_tiles: Dictionary = {}  # Vector2i -> Color
var _fog_of_war_tiles: Dictionary = {}  # Vector2i -> bool (true = fogged)


# ===== LIFECYCLE =====

func _ready() -> void:
	# Node2D는 mouse_filter가 없음 - _input 또는 _unhandled_input 사용
	pass


func _draw() -> void:
	if _tile_grid == null:
		return

	_draw_tiles()

	if draw_grid_lines:
		_draw_grid()

	_draw_highlights()
	_draw_entry_points()


func _process(_delta: float) -> void:
	# 마우스 호버 업데이트
	if highlight_hovered:
		var mouse_pos := get_local_mouse_position()
		var result := IsometricUtilsClass.find_tile_at_screen(mouse_pos)
		var new_hovered: Vector2i = result.position

		if new_hovered != _hovered_tile and _is_valid_tile(new_hovered):
			_hovered_tile = new_hovered
			tile_hovered.emit(_hovered_tile, result.elevation)
			queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var mouse_pos := get_local_mouse_position()
			var result := IsometricUtilsClass.find_tile_at_screen(mouse_pos)
			if _is_valid_tile(result.position):
				tile_clicked.emit(result.position, result.elevation)


# ===== PUBLIC API =====

## TileGrid 설정
func set_tile_grid(grid: Node) -> void:
	_tile_grid = grid
	if grid:
		_width = grid.width if "width" in grid else 10
		_height = grid.height if "height" in grid else 10
	queue_redraw()


## 맵 크기 직접 설정 (TileGrid 없이)
func set_map_size(width: int, height: int) -> void:
	_width = width
	_height = height
	queue_redraw()


## 타일 하이라이트
func highlight_tile(pos: Vector2i, color: Color) -> void:
	_highlighted_tiles[pos] = color
	queue_redraw()


## 타일 하이라이트 제거
func clear_highlight(pos: Vector2i) -> void:
	_highlighted_tiles.erase(pos)
	queue_redraw()


## 모든 하이라이트 제거
func clear_all_highlights() -> void:
	_highlighted_tiles.clear()
	queue_redraw()


## 이동 범위 표시
func show_move_range(tiles: Array[Vector2i]) -> void:
	for tile in tiles:
		_highlighted_tiles[tile] = COLORS.move_range
	queue_redraw()


## 공격 범위 표시
func show_attack_range(tiles: Array[Vector2i]) -> void:
	for tile in tiles:
		_highlighted_tiles[tile] = COLORS.attack_range
	queue_redraw()


## 선택 표시
func set_selected_tiles(tiles: Array[Vector2i]) -> void:
	_selected_tiles = tiles
	queue_redraw()


## Fog of War 설정
func set_fog_of_war(fogged_tiles: Dictionary) -> void:
	_fog_of_war_tiles = fogged_tiles
	queue_redraw()


## 강제 리드로우
func refresh() -> void:
	queue_redraw()


# ===== PRIVATE: DRAWING =====

func _draw_tiles() -> void:
	# 뒤에서 앞으로 그리기 (y가 작은 것부터)
	for y in range(_height):
		for x in range(_width):
			var tile_pos := Vector2i(x, y)
			_draw_single_tile(tile_pos)


func _draw_single_tile(tile_pos: Vector2i) -> void:
	var tile_type: int = _get_tile_type(tile_pos)
	var elevation: int = _get_tile_elevation(tile_pos)

	# Fog of War 체크
	var is_fogged: bool = _fog_of_war_tiles.get(tile_pos, false)

	match tile_type:
		Constants.TileType.VOID:
			_draw_void_tile(tile_pos)
		Constants.TileType.FLOOR:
			_draw_floor_tile(tile_pos, elevation, is_fogged)
		Constants.TileType.WALL:
			_draw_wall_tile(tile_pos, elevation, is_fogged)
		Constants.TileType.FACILITY:
			_draw_facility_tile(tile_pos, elevation, is_fogged)
		Constants.TileType.AIRLOCK:
			_draw_airlock_tile(tile_pos, elevation, is_fogged)
		Constants.TileType.ELEVATED:
			_draw_elevated_tile(tile_pos, is_fogged)
		Constants.TileType.LOWERED:
			_draw_lowered_tile(tile_pos, is_fogged)
		Constants.TileType.COVER_HALF:
			_draw_cover_tile(tile_pos, elevation, false, is_fogged)
		Constants.TileType.COVER_FULL:
			_draw_cover_tile(tile_pos, elevation, true, is_fogged)
		_:
			_draw_floor_tile(tile_pos, elevation, is_fogged)


func _draw_void_tile(tile_pos: Vector2i) -> void:
	var vertices := IsometricUtilsClass.get_tile_vertices(tile_pos, 0)
	draw_colored_polygon(vertices, COLORS.void)


func _draw_floor_tile(tile_pos: Vector2i, elevation: int, is_fogged: bool) -> void:
	var vertices := IsometricUtilsClass.get_tile_vertices(tile_pos, elevation)
	var color: Color = COLORS.floor_top
	if is_fogged:
		color = color.darkened(0.5)
	draw_colored_polygon(vertices, color)

	# 높이가 있으면 측면 그리기
	if elevation > 0:
		_draw_tile_sides(tile_pos, elevation, COLORS.floor_left, COLORS.floor_right, is_fogged)


func _draw_wall_tile(tile_pos: Vector2i, elevation: int, is_fogged: bool) -> void:
	var wall_height: int = 2
	var faces := IsometricUtilsClass.get_cube_faces(tile_pos, elevation, wall_height)

	var top_color: Color = COLORS.wall_top
	var left_color: Color = COLORS.wall_left
	var right_color: Color = COLORS.wall_right

	if is_fogged:
		top_color = top_color.darkened(0.5)
		left_color = left_color.darkened(0.5)
		right_color = right_color.darkened(0.5)

	draw_colored_polygon(faces.left, left_color)
	draw_colored_polygon(faces.right, right_color)
	draw_colored_polygon(faces.top, top_color)


func _draw_facility_tile(tile_pos: Vector2i, elevation: int, is_fogged: bool) -> void:
	# 바닥
	var vertices := IsometricUtilsClass.get_tile_vertices(tile_pos, elevation)
	var floor_color: Color = COLORS.floor_top.darkened(0.1) if is_fogged else COLORS.floor_top
	draw_colored_polygon(vertices, floor_color)

	# 시설 박스
	var facility_height: int = 1
	var faces := IsometricUtilsClass.get_cube_faces(tile_pos, elevation, facility_height)

	var top_color: Color = COLORS.facility_top
	var left_color: Color = COLORS.facility_left
	var right_color: Color = COLORS.facility_right

	if is_fogged:
		top_color = top_color.darkened(0.5)
		left_color = left_color.darkened(0.5)
		right_color = right_color.darkened(0.5)

	draw_colored_polygon(faces.left, left_color)
	draw_colored_polygon(faces.right, right_color)
	draw_colored_polygon(faces.top, top_color)

	# 시설 아이콘 (간단한 마커)
	var center := IsometricUtilsClass.tile_to_screen(tile_pos, elevation + facility_height)
	draw_circle(center, 8, Color.WHITE if not is_fogged else Color.GRAY)


func _draw_airlock_tile(tile_pos: Vector2i, elevation: int, is_fogged: bool) -> void:
	var vertices := IsometricUtilsClass.get_tile_vertices(tile_pos, elevation)
	var color: Color = COLORS.airlock_top
	if is_fogged:
		color = color.darkened(0.5)
	draw_colored_polygon(vertices, color)

	# 위험 표시 (대각선 줄무늬 효과)
	var center := IsometricUtilsClass.tile_to_screen(tile_pos, elevation)
	var stripe_color: Color = Color(0.9, 0.7, 0.0, 0.5) if not is_fogged else Color(0.5, 0.4, 0.0, 0.3)
	for i in range(-2, 3):
		var offset := Vector2(i * 8, i * 4)
		draw_line(
			center + offset + Vector2(-20, -10),
			center + offset + Vector2(20, 10),
			stripe_color, 2.0
		)


func _draw_elevated_tile(tile_pos: Vector2i, is_fogged: bool) -> void:
	var elevation: int = 1
	var faces := IsometricUtilsClass.get_cube_faces(tile_pos, 0, elevation)

	var top_color: Color = COLORS.elevated_top
	var left_color: Color = COLORS.elevated_left
	var right_color: Color = COLORS.elevated_right

	if is_fogged:
		top_color = top_color.darkened(0.5)
		left_color = left_color.darkened(0.5)
		right_color = right_color.darkened(0.5)

	draw_colored_polygon(faces.left, left_color)
	draw_colored_polygon(faces.right, right_color)
	draw_colored_polygon(faces.top, top_color)


func _draw_lowered_tile(tile_pos: Vector2i, is_fogged: bool) -> void:
	# 낮은 지형은 주변보다 아래에 있음
	var vertices := IsometricUtilsClass.get_tile_vertices(tile_pos, -1)
	var color: Color = COLORS.lowered_top
	if is_fogged:
		color = color.darkened(0.5)
	draw_colored_polygon(vertices, color)


func _draw_cover_tile(tile_pos: Vector2i, elevation: int, is_full: bool, is_fogged: bool) -> void:
	# 바닥
	var vertices := IsometricUtilsClass.get_tile_vertices(tile_pos, elevation)
	var floor_color: Color = COLORS.floor_top if not is_fogged else COLORS.floor_top.darkened(0.5)
	draw_colored_polygon(vertices, floor_color)

	# 엄폐물
	var cover_height: int = 2 if is_full else 1
	var faces := IsometricUtilsClass.get_cube_faces(tile_pos, elevation, cover_height)

	var prefix: String = "cover_full" if is_full else "cover_half"
	var top_color: Color = COLORS[prefix + "_top"]
	var left_color: Color = COLORS[prefix + "_left"]
	var right_color: Color = COLORS[prefix + "_right"]

	if is_fogged:
		top_color = top_color.darkened(0.5)
		left_color = left_color.darkened(0.5)
		right_color = right_color.darkened(0.5)

	# 작은 박스로 그리기 (타일 중앙)
	var center := IsometricUtilsClass.tile_to_screen(tile_pos, elevation)
	var half_size := Vector2(16, 8)

	var cover_verts := PackedVector2Array([
		center + Vector2(0, -half_size.y - cover_height * IsometricUtilsClass.TILE_DEPTH),
		center + Vector2(half_size.x, -cover_height * IsometricUtilsClass.TILE_DEPTH),
		center + Vector2(half_size.x, 0),
		center + Vector2(0, half_size.y),
		center + Vector2(-half_size.x, 0),
		center + Vector2(-half_size.x, -cover_height * IsometricUtilsClass.TILE_DEPTH),
	])

	draw_colored_polygon(cover_verts, top_color)


func _draw_tile_sides(tile_pos: Vector2i, elevation: int, left_color: Color, right_color: Color, is_fogged: bool) -> void:
	if is_fogged:
		left_color = left_color.darkened(0.5)
		right_color = right_color.darkened(0.5)

	var faces := IsometricUtilsClass.get_cube_faces(tile_pos, 0, elevation)
	draw_colored_polygon(faces.left, left_color)
	draw_colored_polygon(faces.right, right_color)


func _draw_grid() -> void:
	for y in range(_height):
		for x in range(_width):
			var tile_pos := Vector2i(x, y)
			var vertices := IsometricUtilsClass.get_tile_vertices(tile_pos, _get_tile_elevation(tile_pos))

			# 다이아몬드 외곽선
			for i in range(4):
				var from_pt: Vector2 = vertices[i]
				var to_pt: Vector2 = vertices[(i + 1) % 4]
				draw_line(from_pt, to_pt, COLORS.grid_line, 1.0)

			# 좌표 표시
			if show_coordinates:
				var center := IsometricUtilsClass.tile_to_screen(tile_pos)
				draw_string(
					ThemeDB.fallback_font,
					center - Vector2(10, 5),
					"%d,%d" % [x, y],
					HORIZONTAL_ALIGNMENT_CENTER,
					-1,
					10,
					Color.WHITE
				)


func _draw_highlights() -> void:
	# 하이라이트된 타일
	for tile_pos in _highlighted_tiles:
		var color: Color = _highlighted_tiles[tile_pos]
		var elevation: int = _get_tile_elevation(tile_pos)
		var vertices := IsometricUtilsClass.get_tile_vertices(tile_pos, elevation)
		draw_colored_polygon(vertices, color)

	# 호버 타일
	if highlight_hovered and _is_valid_tile(_hovered_tile):
		var elevation: int = _get_tile_elevation(_hovered_tile)
		var vertices := IsometricUtilsClass.get_tile_vertices(_hovered_tile, elevation)
		draw_colored_polygon(vertices, COLORS.highlight)

	# 선택된 타일
	for tile_pos in _selected_tiles:
		var elevation: int = _get_tile_elevation(tile_pos)
		var vertices := IsometricUtilsClass.get_tile_vertices(tile_pos, elevation)
		draw_colored_polygon(vertices, COLORS.selection)


func _draw_entry_points() -> void:
	if _tile_grid == null:
		return

	var entry_points: Array = []
	if _tile_grid.has_method("get_entry_points"):
		entry_points = _tile_grid.get_entry_points()

	for entry_pos in entry_points:
		var elevation: int = _get_tile_elevation(entry_pos)
		var center := IsometricUtilsClass.tile_to_screen(entry_pos, elevation)

		# 경고 삼각형
		var triangle := PackedVector2Array([
			center + Vector2(0, -20),
			center + Vector2(-15, 10),
			center + Vector2(15, 10),
		])
		draw_colored_polygon(triangle, COLORS.entry_point)

		# 느낌표
		draw_string(
			ThemeDB.fallback_font,
			center + Vector2(-4, 5),
			"!",
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			16,
			Color.WHITE
		)


# ===== PRIVATE: HELPERS =====

func _get_tile_type(pos: Vector2i) -> int:
	if _tile_grid == null:
		return Constants.TileType.FLOOR

	var tile = _tile_grid.get_tile(pos) if _tile_grid.has_method("get_tile") else null
	if tile and "type" in tile:
		return tile.type

	return Constants.TileType.FLOOR


func _get_tile_elevation(pos: Vector2i) -> int:
	if _tile_grid == null:
		return 0

	var tile = _tile_grid.get_tile(pos) if _tile_grid.has_method("get_tile") else null
	if tile and "elevation" in tile:
		return tile.elevation

	# 타입별 기본 높이
	var tile_type := _get_tile_type(pos)
	match tile_type:
		Constants.TileType.ELEVATED:
			return 1
		Constants.TileType.LOWERED:
			return -1
		_:
			return 0


func _is_valid_tile(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < _width and pos.y >= 0 and pos.y < _height
