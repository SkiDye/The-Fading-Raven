## IsometricCamera - 아이소메트릭 카메라 컨트롤
## 2:1 아이소메트릭 뷰, 줌, 패닝
extends Camera2D
class_name IsometricCamera

# ===========================================
# 설정
# ===========================================

@export var min_zoom: float = 0.5
@export var max_zoom: float = 2.0
@export var zoom_speed: float = 0.1
@export var pan_speed: float = 400.0
@export var edge_pan_margin: int = 50
@export var edge_pan_enabled: bool = true

# 부드러운 이동
@export var smoothing_enabled: bool = true
@export var smoothing_speed: float = 5.0

# 경계
@export var bounds_enabled: bool = true
var bounds: Rect2 = Rect2(-500, -500, 2000, 2000)

# 상태
var target_position: Vector2 = Vector2.ZERO
var target_zoom: Vector2 = Vector2.ONE
var is_dragging: bool = false
var drag_start: Vector2 = Vector2.ZERO

# 선택 시 슬로우 모션
var slow_motion_active: bool = false


# ===========================================
# 초기화
# ===========================================

func _ready() -> void:
	target_position = global_position
	target_zoom = zoom


# ===========================================
# 입력 처리
# ===========================================

func _unhandled_input(event: InputEvent) -> void:
	# 줌
	if event.is_action_pressed("camera_zoom_in"):
		_zoom_camera(zoom_speed)
	elif event.is_action_pressed("camera_zoom_out"):
		_zoom_camera(-zoom_speed)

	# 드래그 패닝
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
			is_dragging = mouse_event.pressed
			if is_dragging:
				drag_start = get_global_mouse_position()

	if event is InputEventMouseMotion and is_dragging:
		var mouse_motion := event as InputEventMouseMotion
		var delta := drag_start - get_global_mouse_position()
		target_position += delta
		drag_start = get_global_mouse_position()


func _process(delta: float) -> void:
	# 엣지 패닝
	if edge_pan_enabled and not is_dragging:
		_handle_edge_pan(delta)

	# 키보드 패닝
	_handle_keyboard_pan(delta)

	# 부드러운 이동
	if smoothing_enabled:
		global_position = global_position.lerp(target_position, smoothing_speed * delta)
		zoom = zoom.lerp(target_zoom, smoothing_speed * delta)
	else:
		global_position = target_position
		zoom = target_zoom

	# 경계 제한
	if bounds_enabled:
		_clamp_to_bounds()


# ===========================================
# 카메라 컨트롤
# ===========================================

func _zoom_camera(amount: float) -> void:
	var new_zoom := target_zoom.x + amount
	new_zoom = clampf(new_zoom, min_zoom, max_zoom)
	target_zoom = Vector2(new_zoom, new_zoom)


func _handle_edge_pan(delta: float) -> void:
	var viewport := get_viewport()
	if not viewport:
		return

	var mouse_pos := viewport.get_mouse_position()
	var screen_size := viewport.get_visible_rect().size

	var pan_direction := Vector2.ZERO

	if mouse_pos.x < edge_pan_margin:
		pan_direction.x = -1
	elif mouse_pos.x > screen_size.x - edge_pan_margin:
		pan_direction.x = 1

	if mouse_pos.y < edge_pan_margin:
		pan_direction.y = -1
	elif mouse_pos.y > screen_size.y - edge_pan_margin:
		pan_direction.y = 1

	if pan_direction != Vector2.ZERO:
		target_position += pan_direction * pan_speed * delta / zoom.x


func _handle_keyboard_pan(delta: float) -> void:
	var pan_direction := Vector2.ZERO

	if Input.is_action_pressed("ui_left"):
		pan_direction.x = -1
	elif Input.is_action_pressed("ui_right"):
		pan_direction.x = 1

	if Input.is_action_pressed("ui_up"):
		pan_direction.y = -1
	elif Input.is_action_pressed("ui_down"):
		pan_direction.y = 1

	if pan_direction != Vector2.ZERO:
		target_position += pan_direction * pan_speed * delta / zoom.x


func _clamp_to_bounds() -> void:
	target_position.x = clampf(target_position.x, bounds.position.x, bounds.end.x)
	target_position.y = clampf(target_position.y, bounds.position.y, bounds.end.y)


# ===========================================
# 공개 API
# ===========================================

## 특정 위치로 카메라 이동
func move_to(world_pos: Vector2, instant: bool = false) -> void:
	target_position = world_pos
	if instant:
		global_position = world_pos


## 특정 노드로 카메라 이동
func focus_on(node: Node2D, instant: bool = false) -> void:
	move_to(node.global_position, instant)


## 줌 레벨 설정
func set_zoom_level(level: float, instant: bool = false) -> void:
	level = clampf(level, min_zoom, max_zoom)
	target_zoom = Vector2(level, level)
	if instant:
		zoom = target_zoom


## 맵 경계 설정
func set_bounds(new_bounds: Rect2) -> void:
	bounds = new_bounds


## 맵 크기로 경계 설정
func set_bounds_from_grid(grid_width: int, grid_height: int, tile_size: Vector2) -> void:
	var map_size := Vector2(grid_width, grid_height) * tile_size
	bounds = Rect2(-tile_size, map_size + tile_size * 2)


# ===========================================
# 슬로우 모션
# ===========================================

func enable_slow_motion() -> void:
	if not slow_motion_active:
		slow_motion_active = true
		Engine.time_scale = Balance.COMBAT["slow_motion_factor"]


func disable_slow_motion() -> void:
	if slow_motion_active:
		slow_motion_active = false
		Engine.time_scale = 1.0


func toggle_slow_motion() -> void:
	if slow_motion_active:
		disable_slow_motion()
	else:
		enable_slow_motion()


# ===========================================
# 좌표 변환 헬퍼
# ===========================================

## 화면 좌표 → 월드 좌표
func screen_to_world(screen_pos: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_pos


## 월드 좌표 → 화면 좌표
func world_to_screen(world_pos: Vector2) -> Vector2:
	return get_canvas_transform() * world_pos
