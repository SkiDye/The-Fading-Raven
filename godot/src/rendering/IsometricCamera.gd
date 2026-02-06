class_name IsometricCamera
extends Camera3D

## 아이소메트릭 뷰 카메라
## Orthographic 투영 + Bad North 스타일 각도

# ===== SIGNALS =====

signal camera_moved(new_position: Vector3)
signal zoom_changed(new_zoom: float)


# ===== CONFIGURATION =====

@export_group("Isometric Settings")
@export var isometric_angle: float = 35.264  # arctan(1/sqrt(2)) ≈ 35.264도
@export var rotation_angle: float = 45.0     # Y축 회전

@export_group("Zoom")
@export var min_zoom: float = 5.0
@export var max_zoom: float = 30.0
@export var zoom_speed: float = 2.0
@export var zoom_smoothing: float = 10.0

@export_group("Pan")
@export var pan_speed: float = 20.0
@export var pan_smoothing: float = 8.0
@export var edge_pan_enabled: bool = true
@export var edge_pan_margin: float = 50.0
@export var edge_pan_speed: float = 15.0

@export_group("Drag Mode")
## "pan" = 마우스 드래그로 이동, "rotate" = 마우스 드래그로 회전
@export var drag_mode: String = "pan"

@export_group("Bounds")
@export var use_bounds: bool = true
@export var bounds_min: Vector2 = Vector2(-50, -50)
@export var bounds_max: Vector2 = Vector2(50, 50)


# ===== STATE =====

var _target_zoom: float = 10.0  # 더 가깝게 시작
var _target_position: Vector3 = Vector3.ZERO
var _target_rotation_y: float = 45.0  # Y축 회전 (기본 45도)
var _orbit_center: Vector3 = Vector3.ZERO  # 공전 중심점
var _orbit_distance: float = 15.0  # 공전 반경
var _is_panning: bool = false
var _pan_start_mouse: Vector2
var _pan_start_position: Vector3


# ===== LIFECYCLE =====

func _ready() -> void:
	_setup_camera()
	_target_zoom = size
	_target_position = global_position
	_target_rotation_y = rotation_angle


func _setup_camera() -> void:
	# Orthographic 투영
	projection = PROJECTION_ORTHOGONAL
	size = _target_zoom

	# 아이소메트릭 각도 설정
	rotation_degrees = Vector3(-isometric_angle, rotation_angle, 0)

	# 기본 위치 (위에서 내려다봄)
	if global_position == Vector3.ZERO:
		global_position = Vector3(10, 12, 10)  # Y 낮춤


func _process(delta: float) -> void:
	_handle_edge_pan(delta)
	_smooth_zoom(delta)
	_smooth_pan(delta)
	_smooth_rotation(delta)


func _unhandled_input(event: InputEvent) -> void:
	_handle_zoom_input(event)
	_handle_pan_input(event)
	_handle_keyboard_pan(event)
	_handle_rotation_input(event)


# ===== ZOOM =====

func _handle_zoom_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_in()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_out()


func zoom_in() -> void:
	_target_zoom = clampf(_target_zoom - zoom_speed, min_zoom, max_zoom)
	zoom_changed.emit(_target_zoom)


func zoom_out() -> void:
	_target_zoom = clampf(_target_zoom + zoom_speed, min_zoom, max_zoom)
	zoom_changed.emit(_target_zoom)


func set_zoom(value: float) -> void:
	_target_zoom = clampf(value, min_zoom, max_zoom)
	zoom_changed.emit(_target_zoom)


func _smooth_zoom(delta: float) -> void:
	size = lerpf(size, _target_zoom, zoom_smoothing * delta)


# ===== ROTATION =====

func _handle_rotation_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_Q:
			rotate_left()
		elif event.keycode == KEY_E:
			rotate_right()


func rotate_left() -> void:
	_target_rotation_y -= 45.0


func rotate_right() -> void:
	_target_rotation_y += 45.0


func _smooth_rotation(delta: float) -> void:
	var current_y: float = rotation_degrees.y
	var new_y: float = lerpf(current_y, _target_rotation_y, pan_smoothing * delta)
	rotation_degrees = Vector3(-isometric_angle, new_y, 0)

	# 공전 위치 업데이트 (맵 중심 기준)
	_update_orbit_position(new_y)


# ===== PAN =====

func _handle_pan_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		# 마우스 왼쪽 또는 중간 버튼으로 드래그
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_is_panning = true
				_pan_start_mouse = event.position
				_pan_start_position = global_position
			else:
				_is_panning = false

	if event is InputEventMouseMotion and _is_panning:
		if drag_mode == "rotate":
			# 회전 모드: X 이동량으로 Y축 회전
			var delta_x: float = event.position.x - _pan_start_mouse.x
			_pan_start_mouse = event.position
			_target_rotation_y += delta_x * 0.3
		else:
			# 패닝 모드: 카메라 이동
			var delta_mouse: Vector2 = event.position - _pan_start_mouse
			var pan_dir := _screen_to_world_direction(delta_mouse)
			_target_position = _pan_start_position - pan_dir * 0.05 * size


func _handle_keyboard_pan(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var move_dir := Vector3.ZERO

		if event.keycode == KEY_W or event.keycode == KEY_UP:
			move_dir += Vector3(-1, 0, -1).normalized()
		if event.keycode == KEY_S or event.keycode == KEY_DOWN:
			move_dir += Vector3(1, 0, 1).normalized()
		if event.keycode == KEY_A or event.keycode == KEY_LEFT:
			move_dir += Vector3(-1, 0, 1).normalized()
		if event.keycode == KEY_D or event.keycode == KEY_RIGHT:
			move_dir += Vector3(1, 0, -1).normalized()

		if move_dir != Vector3.ZERO:
			_target_position += move_dir * pan_speed * 0.1


func _handle_edge_pan(delta: float) -> void:
	if not edge_pan_enabled:
		return

	var viewport := get_viewport()
	if viewport == null:
		return

	var mouse_pos := viewport.get_mouse_position()
	var viewport_size := viewport.get_visible_rect().size
	var move_dir := Vector3.ZERO

	# 상단 가장자리
	if mouse_pos.y < edge_pan_margin:
		move_dir += Vector3(-1, 0, -1).normalized()
	# 하단 가장자리
	elif mouse_pos.y > viewport_size.y - edge_pan_margin:
		move_dir += Vector3(1, 0, 1).normalized()

	# 좌측 가장자리
	if mouse_pos.x < edge_pan_margin:
		move_dir += Vector3(-1, 0, 1).normalized()
	# 우측 가장자리
	elif mouse_pos.x > viewport_size.x - edge_pan_margin:
		move_dir += Vector3(1, 0, -1).normalized()

	if move_dir != Vector3.ZERO:
		_target_position += move_dir.normalized() * edge_pan_speed * delta


func _smooth_pan(delta: float) -> void:
	# 경계 적용
	if use_bounds:
		_target_position.x = clampf(_target_position.x, bounds_min.x, bounds_max.x)
		_target_position.z = clampf(_target_position.z, bounds_min.y, bounds_max.y)

	var new_pos := global_position.lerp(_target_position, pan_smoothing * delta)
	if global_position.distance_to(new_pos) > 0.01:
		global_position = new_pos
		camera_moved.emit(new_pos)


func _screen_to_world_direction(screen_delta: Vector2) -> Vector3:
	# 화면 좌표 변화량을 월드 방향으로 변환 (아이소메트릭 보정)
	var angle_rad := deg_to_rad(rotation_angle)
	var world_x := screen_delta.x * cos(angle_rad) - screen_delta.y * sin(angle_rad)
	var world_z := screen_delta.x * sin(angle_rad) + screen_delta.y * cos(angle_rad)
	return Vector3(world_x, 0, world_z)


# ===== PUBLIC API =====

## 특정 위치로 카메라 이동
func move_to(world_pos: Vector3, instant: bool = false) -> void:
	_target_position = Vector3(world_pos.x, global_position.y, world_pos.z)
	if instant:
		global_position = _target_position


## 특정 타일로 카메라 이동
func focus_on_tile(tile_x: int, tile_y: int, tile_size: float = 1.0) -> void:
	var world_pos := Vector3(tile_x * tile_size, 0, tile_y * tile_size)
	move_to(world_pos)


## 맵 중앙으로 이동
func center_on_map(width: int, height: int, tile_size: float = 1.0) -> void:
	var center := Vector3(width * tile_size * 0.5, 0, height * tile_size * 0.5)
	_orbit_center = center
	_orbit_distance = maxf(width, height) * tile_size * 0.7
	_update_orbit_position(_target_rotation_y)


func _update_orbit_position(y_rotation: float) -> void:
	## 공전 위치 계산 (맵 중심 기준)
	var angle_rad := deg_to_rad(y_rotation)
	var offset := Vector3(
		sin(angle_rad) * _orbit_distance,
		_orbit_distance * 0.8,  # 높이
		cos(angle_rad) * _orbit_distance
	)
	_target_position = _orbit_center + offset
	global_position = _target_position


## 경계 설정
func set_bounds(min_pos: Vector2, max_pos: Vector2) -> void:
	bounds_min = min_pos
	bounds_max = max_pos
	use_bounds = true


## 화면 좌표 → 월드 좌표 (지면 레벨)
func screen_to_world(screen_pos: Vector2) -> Vector3:
	var from := project_ray_origin(screen_pos)
	var dir := project_ray_normal(screen_pos)

	# Y=0 평면과의 교차점
	if abs(dir.y) > 0.001:
		var t := -from.y / dir.y
		return from + dir * t

	return Vector3.ZERO


## 월드 좌표 → 화면 좌표
func world_to_screen(world_pos: Vector3) -> Vector2:
	return unproject_position(world_pos)
