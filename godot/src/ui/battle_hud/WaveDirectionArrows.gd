class_name WaveDirectionArrows
extends Control

## 웨이브 방향 화살표 표시
## 적 웨이브가 접근하는 방향을 화면 가장자리에 화살표로 표시


const ARROW_COLOR := Color(1.0, 0.3, 0.3, 0.9)
const ARROW_SIZE := 24.0
const EDGE_MARGIN := 40.0


var _entry_points: Array[Vector2i] = []
var _camera: Camera2D
var _tile_grid: Node  # TileGrid
var _arrows: Dictionary = {}  # entry_point -> arrow_data


func _ready() -> void:
	_connect_signals()


func _connect_signals() -> void:
	if EventBus:
		EventBus.wave_started.connect(_on_wave_started)
		EventBus.wave_ended.connect(_on_wave_ended)
		EventBus.enemy_group_landing.connect(_on_enemy_group_landing)


func _exit_tree() -> void:
	if EventBus:
		EventBus.disconnect_all_for_node(self)


## 초기화
## [param camera]: 메인 카메라
## [param grid]: TileGrid 노드
func initialize(camera: Camera2D, grid: Node) -> void:
	_camera = camera
	_tile_grid = grid


## 진입점 설정
func set_entry_points(points: Array[Vector2i]) -> void:
	_entry_points = points


## 활성 진입점 추가 (적이 접근 중)
func add_active_entry(entry_point: Vector2i, enemy_count: int = 1) -> void:
	_arrows[entry_point] = {
		"position": entry_point,
		"count": enemy_count,
		"pulse": 0.0
	}
	queue_redraw()


## 활성 진입점 제거
func remove_active_entry(entry_point: Vector2i) -> void:
	_arrows.erase(entry_point)
	queue_redraw()


## 모든 활성 진입점 제거
func clear_active_entries() -> void:
	_arrows.clear()
	queue_redraw()


func _process(delta: float) -> void:
	if _arrows.is_empty():
		return

	# 화살표 펄스 애니메이션
	for key in _arrows.keys():
		_arrows[key].pulse = fmod(_arrows[key].pulse + delta * 3.0, TAU)

	queue_redraw()


func _draw() -> void:
	if _arrows.is_empty():
		return

	var viewport_size := get_viewport_rect().size

	for key in _arrows.keys():
		var arrow_data: Dictionary = _arrows[key]
		var entry_pos: Vector2i = arrow_data.position
		var world_pos := _get_world_position(entry_pos)
		var screen_pos := _world_to_screen(world_pos)

		# 화면 내에 있으면 화살표 표시 안함
		if _is_on_screen(screen_pos, viewport_size):
			continue

		# 화면 가장자리 위치 계산
		var edge_pos := _clamp_to_edge(screen_pos, viewport_size)
		var direction := (screen_pos - viewport_size / 2).normalized()

		# 펄스 효과
		var pulse_scale := 1.0 + sin(arrow_data.pulse) * 0.15
		var alpha := 0.7 + sin(arrow_data.pulse) * 0.3

		# 화살표 그리기
		_draw_arrow(edge_pos, direction, pulse_scale, alpha)

		# 적 수 표시
		if arrow_data.count > 1:
			var count_text := "x%d" % arrow_data.count
			var font := ThemeDB.fallback_font
			var font_size := 14
			draw_string(font, edge_pos + Vector2(15, 5), count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, alpha))


func _draw_arrow(pos: Vector2, direction: Vector2, scale: float, alpha: float) -> void:
	var size := ARROW_SIZE * scale
	var perpendicular := Vector2(-direction.y, direction.x)

	# 화살표 포인트
	var tip := pos + direction * size * 0.5
	var left := pos - direction * size * 0.3 + perpendicular * size * 0.4
	var right := pos - direction * size * 0.3 - perpendicular * size * 0.4
	var back := pos - direction * size * 0.3

	var color := ARROW_COLOR
	color.a = alpha

	# 삼각형 화살표
	var points := PackedVector2Array([tip, left, back, right])
	var colors := PackedColorArray([color, color, color, color])
	draw_polygon(points, colors)

	# 외곽선
	var outline_color := Color(1, 1, 1, alpha * 0.5)
	draw_polyline([tip, left, back, right, tip], outline_color, 2.0)


func _get_world_position(tile_pos: Vector2i) -> Vector2:
	if _tile_grid and _tile_grid.has_method("tile_to_world"):
		return _tile_grid.tile_to_world(tile_pos)
	return Vector2(tile_pos.x * Constants.TILE_SIZE, tile_pos.y * Constants.TILE_SIZE)


func _world_to_screen(world_pos: Vector2) -> Vector2:
	if _camera:
		var canvas_transform := get_canvas_transform()
		return canvas_transform * world_pos
	return world_pos


func _is_on_screen(screen_pos: Vector2, viewport_size: Vector2) -> bool:
	return screen_pos.x >= 0 and screen_pos.x <= viewport_size.x and \
		   screen_pos.y >= 0 and screen_pos.y <= viewport_size.y


func _clamp_to_edge(screen_pos: Vector2, viewport_size: Vector2) -> Vector2:
	var center := viewport_size / 2
	var direction := (screen_pos - center).normalized()

	# 화면 가장자리까지의 거리 계산
	var edge_x: float
	var edge_y: float

	if direction.x != 0:
		if direction.x > 0:
			edge_x = (viewport_size.x - EDGE_MARGIN - center.x) / direction.x
		else:
			edge_x = (EDGE_MARGIN - center.x) / direction.x
	else:
		edge_x = INF

	if direction.y != 0:
		if direction.y > 0:
			edge_y = (viewport_size.y - EDGE_MARGIN - center.y) / direction.y
		else:
			edge_y = (EDGE_MARGIN - center.y) / direction.y
	else:
		edge_y = INF

	var t := minf(absf(edge_x), absf(edge_y))
	return center + direction * t


# ===== SIGNAL HANDLERS =====

func _on_wave_started(_wave_num: int, _total: int, _preview: Array) -> void:
	# 웨이브 시작 시 화살표 표시는 enemy_group_landing에서 처리
	pass


func _on_wave_ended(_wave_num: int) -> void:
	clear_active_entries()


func _on_enemy_group_landing(entry_point: Vector2i, count: int) -> void:
	add_active_entry(entry_point, count)
