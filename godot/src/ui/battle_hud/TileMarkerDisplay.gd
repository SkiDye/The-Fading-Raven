class_name TileMarkerDisplay
extends Node2D

## 타일 마커 표시
## 이동 가능한 타일에 핀 마커 표시


const PIN_COLOR := Color(1.0, 1.0, 1.0, 0.8)
const PIN_HOVER_COLOR := Color(1.0, 1.0, 0.5, 1.0)
const PIN_SIZE := 12.0


var _tile_grid: Node  # TileGrid
var _marked_tiles: Array[Vector2i] = []
var _hovered_tile: Vector2i = Vector2i(-1, -1)
var _is_move_mode: bool = false
var _selected_crew: Node


func _ready() -> void:
	_connect_signals()


func _connect_signals() -> void:
	if EventBus:
		EventBus.move_mode_requested.connect(_on_move_mode_requested)
		EventBus.move_mode_ended.connect(_on_move_mode_ended)
		EventBus.crew_deselected.connect(_on_crew_deselected)
		EventBus.tile_hovered.connect(_on_tile_hovered)
		EventBus.move_command_issued.connect(_on_move_command_issued)


func _exit_tree() -> void:
	if EventBus:
		EventBus.disconnect_all_for_node(self)


## TileGrid 설정
func set_tile_grid(grid: Node) -> void:
	_tile_grid = grid


## 이동 가능 타일 마커 표시
func show_move_markers(crew: Node, tiles: Array[Vector2i]) -> void:
	_selected_crew = crew
	_marked_tiles = tiles
	_is_move_mode = true
	queue_redraw()


## 마커 숨기기
func hide_markers() -> void:
	_marked_tiles.clear()
	_is_move_mode = false
	_selected_crew = null
	_hovered_tile = Vector2i(-1, -1)
	queue_redraw()


func _draw() -> void:
	if not _is_move_mode or _marked_tiles.is_empty():
		return

	for tile_pos in _marked_tiles:
		var world_pos := _get_world_position(tile_pos)
		var is_hovered := (tile_pos == _hovered_tile)
		_draw_pin_marker(world_pos, is_hovered)


func _draw_pin_marker(pos: Vector2, is_hovered: bool) -> void:
	var color := PIN_HOVER_COLOR if is_hovered else PIN_COLOR
	var size := PIN_SIZE * (1.2 if is_hovered else 1.0)

	# 핀 머리 (원)
	var head_center := pos + Vector2(0, -size * 1.2)
	var head_radius := size * 0.4
	draw_circle(head_center, head_radius, color)

	# 핀 몸체 (삼각형)
	var tip := pos
	var left := head_center + Vector2(-head_radius * 0.7, head_radius * 0.3)
	var right := head_center + Vector2(head_radius * 0.7, head_radius * 0.3)
	draw_polygon(PackedVector2Array([tip, left, right]), PackedColorArray([color, color, color]))

	# 내부 원 (하이라이트)
	if is_hovered:
		draw_circle(head_center, head_radius * 0.5, Color(1, 1, 1, 1))


func _get_world_position(tile_pos: Vector2i) -> Vector2:
	if _tile_grid and _tile_grid.has_method("tile_to_world"):
		return _tile_grid.tile_to_world(tile_pos)
	return Vector2(tile_pos.x * Constants.TILE_SIZE + Constants.TILE_SIZE / 2,
				   tile_pos.y * Constants.TILE_SIZE + Constants.TILE_SIZE / 2)


# ===== SIGNAL HANDLERS =====

func _on_move_mode_requested(crew: Node) -> void:
	if _tile_grid == null:
		return

	_selected_crew = crew

	# 크루 현재 위치에서 이동 가능한 타일 계산
	var crew_pos := Vector2i.ZERO
	if "tile_position" in crew:
		crew_pos = crew.tile_position
	elif crew.has_method("get_tile_position"):
		crew_pos = crew.get_tile_position()

	# 이동 가능한 타일 가져오기
	var reachable: Array[Vector2i] = []
	if _tile_grid.has_method("get_reachable_tiles"):
		var max_dist: int = 10  # 기본 최대 이동 거리
		reachable = _tile_grid.get_reachable_tiles(crew_pos, max_dist)
	else:
		# 대체: 모든 이동 가능한 인접 타일
		for y in range(_tile_grid.height):
			for x in range(_tile_grid.width):
				var pos := Vector2i(x, y)
				if _tile_grid.is_walkable(pos):
					reachable.append(pos)

	show_move_markers(crew, reachable)


func _on_move_mode_ended() -> void:
	hide_markers()


func _on_crew_deselected() -> void:
	hide_markers()


func _on_tile_hovered(tile_pos: Vector2i) -> void:
	if not _is_move_mode:
		return

	_hovered_tile = tile_pos
	queue_redraw()


func _on_move_command_issued(_crew: Node, _target: Vector2i) -> void:
	hide_markers()
